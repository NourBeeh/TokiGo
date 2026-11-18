import * as dns from 'dns';
import * as net from 'net';

/** Hard ceiling for an upstream original. */
export const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
/** A slow upstream must never hold a request open. */
export const IMAGE_FETCH_TIMEOUT_MS = 10_000;

export interface FetchedImage {
  bytes: Buffer;
  contentType: string;
}

export function parseHttpsUrl(value: string): URL | null {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url : null;
  } catch {
    return null;
  }
}

/** Localhost, link-local and bare IP literals are never valid image hosts. */
export function isBlockedHostname(host: string): boolean {
  if (host === 'localhost' || host.endsWith('.localhost')) return true;
  if (host.endsWith('.local') || host.endsWith('.internal')) return true;
  return net.isIP(host) !== 0;
}

/**
 * Fetch an image from an authorized provider URL with SSRF protection:
 *  - HTTPS only, no credentials in the URL;
 *  - DNS resolution must land on public addresses (DNS-rebind safe);
 *  - redirects are NOT followed — an untrusted redirect must never reach an
 *    internal address. The caller can decide how to handle a 3xx.
 */
export async function fetchAuthorizedImage(
  src: string,
): Promise<FetchedImage | null> {
  const parsed = parseHttpsUrl(src);
  if (parsed === null || parsed.username || parsed.password) return null;
  if (isBlockedHostname(parsed.hostname.toLowerCase())) return null;
  if (!(await resolvesToPublicAddress(parsed.hostname))) return null;

  const response = await fetch(src, {
    headers: { accept: 'image/*' },
    redirect: 'manual',
    signal: AbortSignal.timeout(IMAGE_FETCH_TIMEOUT_MS),
  });

  // A redirect is left to the caller: following it would defeat the allowlist.
  if (response.status >= 300 && response.status < 400) return null;
  if (!response.ok) return null;

  const contentType = response.headers.get('content-type') ?? '';
  if (!contentType.startsWith('image/')) return null;

  const declared = Number(response.headers.get('content-length'));
  if (Number.isFinite(declared) && declared > MAX_IMAGE_BYTES) return null;

  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) return null;
  return { bytes, contentType };
}

async function resolvesToPublicAddress(hostname: string): Promise<boolean> {
  try {
    const addresses = await dns.promises.lookup(hostname, { all: true });
    if (addresses.length === 0) return false;
    return addresses.every(({ address }) => !isPrivateAddress(address));
  } catch {
    return false;
  }
}

function isPrivateAddress(address: string): boolean {
  if (net.isIPv4(address)) {
    const [a, b] = address.split('.').map(Number);
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    if (a >= 224) return true;
    return false;
  }
  if (net.isIPv6(address)) {
    const normalized = address.toLowerCase();
    if (normalized === '::1' || normalized === '::') return true;
    if (normalized.startsWith('fc') || normalized.startsWith('fd')) return true;
    if (
      normalized.startsWith('fe8') ||
      normalized.startsWith('fe9') ||
      normalized.startsWith('fea') ||
      normalized.startsWith('feb')
    ) {
      return true;
    }
    if (normalized.startsWith('::ffff:')) {
      return isPrivateAddress(normalized.slice('::ffff:'.length));
    }
  }
  return false;
}
