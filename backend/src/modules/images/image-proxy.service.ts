import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import * as dns from 'dns';
import * as net from 'net';
import * as path from 'path';
import sharp from 'sharp';

/** Widths the proxy will serve. Anything else snaps to the nearest step. */
const WIDTH_STEPS = [160, 240, 320, 480, 640, 800, 1280] as const;

const DEFAULT_WIDTH = 480;
const MIN_WIDTH = 80;
const MAX_WIDTH = 1600;

/** A slow upstream must never hold a client request open. */
const UPSTREAM_TIMEOUT_MS = 10_000;

/** Refuse absurd originals — the point is to send LESS data, not more. */
const MAX_UPSTREAM_BYTES = 12 * 1024 * 1024;

/** Encoded results live for a week; hotel photos change on a much slower cadence. */
const CACHE_CONTROL =
  'public, max-age=604800, stale-while-revalidate=86400, immutable';

/**
 * What a CDN should do, independent of what the browser does.
 *
 * Cloudflare honours `CDN-Cache-Control`, Fastly/Varnish `Surrogate-Control`;
 * sending both means one deployment works behind either edge. The URL already
 * pins `src`, `w` and `f`, so a cached response can never be wrong for a
 * different request — that is what makes a week-long, immutable edge TTL safe.
 */
const CDN_CACHE_CONTROL = 'public, max-age=604800, immutable';

export const IMAGE_CACHE_CONTROL = CACHE_CONTROL;
export const IMAGE_CDN_CACHE_CONTROL = CDN_CACHE_CONTROL;

const DEFAULT_MAX_CACHE_BYTES = 256 * 1024 * 1024;
const CLEANUP_EVERY_WRITES = 64;

/**
 * Hosts the proxy may fetch. These are the only image sources the app actually
 * receives today. Anything else is redirected to its original URL (the client
 * still shows the image — it just does not get the resize win), which keeps the
 * endpoint safe to expose without turning it into an open fetch proxy.
 */
const DEFAULT_ALLOWED_HOSTS = [
  'static.cupid.travel',
  'images.unsplash.com',
  'loremflickr.com',
  'images.duffel.com',
  'assets.duffel.com',
  // Destination cards use the city's own Commons photo (Wikimedia). Both hosts
  // serve the exact same file: `upload` the original, `thumb` a sized render.
  'upload.wikimedia.org',
  'thumb.wikimedia.org',
];

export interface ProxiedImage {
  bytes: Buffer;
  contentType: string;
  etag: string;
  cacheHit: boolean;
  cacheControl: string;
}

/**
 * Server-side hotel-photo resizer.
 *
 * Nuitee's CDN serves 450–600KB originals and ignores resize query params, so
 * the app used to download ~3MB for six Home cards. This service fetches the
 * original once, re-encodes it as WebP at the requested width and keeps the
 * result on disk. The second request for the same photo is a file read.
 *
 * Failure policy: every recoverable failure returns `null`, and the controller
 * redirects to the original URL. A broken proxy must never break the UI.
 */
@Injectable()
export class ImageProxyService implements OnModuleInit {
  private readonly logger = new Logger(ImageProxyService.name);

  private readonly allowedHosts: Set<string>;
  private readonly cacheDir: string;
  private readonly maxCacheBytes: number;

  /** Concurrent requests for the same key share one upstream fetch. */
  private readonly inFlight = new Map<string, Promise<ProxiedImage | null>>();

  private writesSinceCleanup = 0;
  private cleanupRunning = false;

  constructor() {
    const configured = (process.env.IMAGE_PROXY_HOSTS ?? '')
      .split(',')
      .map((host) => host.trim().toLowerCase())
      .filter(Boolean);
    this.allowedHosts = new Set(
      configured.length > 0 ? configured : DEFAULT_ALLOWED_HOSTS,
    );

    this.cacheDir =
      process.env.IMAGE_CACHE_DIR?.trim() ||
      path.join(process.cwd(), '.cache', 'images');
    this.maxCacheBytes =
      Number(process.env.IMAGE_CACHE_MAX_BYTES) || DEFAULT_MAX_CACHE_BYTES;
  }

  onModuleInit(): void {
    // Best-effort: a read-only filesystem only disables caching, never boot.
    void this.ensureCacheDir().catch(() => undefined);
  }

  /** Whether [src] is a host we are willing to fetch ourselves. */
  isAllowed(src: string): boolean {
    const parsed = parseHttpsUrl(src);
    if (parsed === null) return false;
    const host = parsed.hostname.toLowerCase();
    if (isBlockedHostname(host)) return false;
    return this.allowedHosts.has(host) || hasAllowedSuffix(host, this.allowedHosts);
  }

  /** Normalizes a requested width onto one of the cached steps. */
  normalizeWidth(raw?: string | number): number {
    const parsed =
      typeof raw === 'number' ? raw : Number.parseInt(String(raw ?? ''), 10);
    if (!Number.isFinite(parsed) || parsed <= 0) return DEFAULT_WIDTH;
    const clamped = Math.min(Math.max(Math.round(parsed), MIN_WIDTH), MAX_WIDTH);
    let best: number = WIDTH_STEPS[0];
    for (const step of WIDTH_STEPS) {
      if (Math.abs(step - clamped) < Math.abs(best - clamped)) best = step;
    }
    return best;
  }

  async proxy(
    src: string,
    widthInput?: string | number,
    format: 'webp' | 'jpeg' = 'webp',
  ): Promise<ProxiedImage | null> {
    if (!this.isAllowed(src)) return null;

    const parsed = parseHttpsUrl(src);
    if (parsed === null) return null;

    // Resolve first: an allowlisted hostname that points at a private address
    // (DNS rebinding) is still refused.
    if (!(await resolvesToPublicAddress(parsed.hostname))) {
      this.logger.warn(`Image proxy refused private host: ${parsed.hostname}`);
      return null;
    }

    const width = this.normalizeWidth(widthInput);
    const key = sha256(`${src}|${width}|${format}`);
    const file = path.join(this.cacheDir, `${key}.${format}`);

    const cached = await this.readCache(file, format);
    if (cached !== null) {
      return { ...cached, cacheHit: true, cacheControl: CACHE_CONTROL };
    }

    const pending = this.inFlight.get(key);
    if (pending !== undefined) return pending;

    const job = this.fetchAndResize(src, width, format, file).finally(() => {
      this.inFlight.delete(key);
    });
    this.inFlight.set(key, job);
    return job;
  }

  private async fetchAndResize(
    src: string,
    width: number,
    format: 'webp' | 'jpeg',
    file: string,
  ): Promise<ProxiedImage | null> {
    try {
      const response = await fetch(src, {
        headers: { accept: 'image/*' },
        // Redirects are not followed: a redirect could point at an internal
        // address that the allowlist never saw. The client falls back to the
        // original URL instead.
        redirect: 'manual',
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      });
      if (!response.ok) return null;

      const contentType = response.headers.get('content-type') ?? '';
      if (!contentType.startsWith('image/')) return null;

      const declared = Number(response.headers.get('content-length'));
      if (Number.isFinite(declared) && declared > MAX_UPSTREAM_BYTES) {
        return null;
      }

      const original = Buffer.from(await response.arrayBuffer());
      if (original.length === 0 || original.length > MAX_UPSTREAM_BYTES) {
        return null;
      }

      const pipeline = sharp(original, { failOn: 'none' })
        .rotate()
        .resize({ width, withoutEnlargement: true });
      const bytes =
        format === 'jpeg'
          ? await pipeline.jpeg({ quality: 78, progressive: true }).toBuffer()
          : await pipeline.webp({ quality: 72, effort: 4 }).toBuffer();

      const encoded: ProxiedImage = {
        bytes,
        contentType: format === 'jpeg' ? 'image/jpeg' : 'image/webp',
        etag: `"${sha256(bytes)}"`,
        cacheHit: false,
        cacheControl: CACHE_CONTROL,
      };

      await this.writeCache(file, bytes);
      return encoded;
    } catch (error) {
      // A dead upstream, a corrupt photo or an unsupported format: the caller
      // redirects to the original and the app keeps working.
      this.logger.debug(
        `Image proxy miss for ${src}: ${(error as Error).message}`,
      );
      return null;
    }
  }

  private async readCache(
    file: string,
    format: 'webp' | 'jpeg',
  ): Promise<Omit<ProxiedImage, 'cacheHit' | 'cacheControl'> | null> {
    try {
      const bytes = await fs.readFile(file);
      if (bytes.length === 0) return null;
      // Touch mtime so the LRU cleanup keeps recently used photos.
      const now = new Date();
      void fs.utimes(file, now, now).catch(() => undefined);
      return {
        bytes,
        contentType: format === 'jpeg' ? 'image/jpeg' : 'image/webp',
        etag: `"${sha256(bytes)}"`,
      };
    } catch {
      return null;
    }
  }

  private async writeCache(file: string, bytes: Buffer): Promise<void> {
    try {
      await this.ensureCacheDir();
      // Atomic replace: a reader never sees a half-written image.
      const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
      await fs.writeFile(tmp, bytes);
      await fs.rename(tmp, file);
      this.writesSinceCleanup += 1;
      if (this.writesSinceCleanup >= CLEANUP_EVERY_WRITES) {
        this.writesSinceCleanup = 0;
        void this.cleanup();
      }
    } catch (error) {
      this.logger.debug(
        `Image cache write failed (${file}): ${(error as Error).message}`,
      );
    }
  }

  private async ensureCacheDir(): Promise<void> {
    await fs.mkdir(this.cacheDir, { recursive: true });
  }

  /** Size-bounded LRU: drop the oldest files until the directory fits. */
  private async cleanup(): Promise<void> {
    if (this.cleanupRunning) return;
    this.cleanupRunning = true;
    try {
      const names = await fs.readdir(this.cacheDir);
      const files = await Promise.all(
        names.map(async (name) => {
          const full = path.join(this.cacheDir, name);
          try {
            const stat = await fs.stat(full);
            return { full, size: stat.size, mtimeMs: stat.mtimeMs };
          } catch {
            return null;
          }
        }),
      );
      const alive = files.filter(
        (entry): entry is { full: string; size: number; mtimeMs: number } =>
          entry !== null,
      );
      let total = alive.reduce((sum, entry) => sum + entry.size, 0);
      if (total <= this.maxCacheBytes) return;

      alive.sort((a, b) => a.mtimeMs - b.mtimeMs);
      for (const entry of alive) {
        if (total <= this.maxCacheBytes) break;
        try {
          await fs.unlink(entry.full);
          total -= entry.size;
        } catch {
          // Another request may have removed it first.
        }
      }
    } catch (error) {
      this.logger.debug(`Image cache cleanup failed: ${(error as Error).message}`);
    } finally {
      this.cleanupRunning = false;
    }
  }
}

function parseHttpsUrl(value: string): URL | null {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:') return null;
    return url;
  } catch {
    return null;
  }
}

function hasAllowedSuffix(host: string, allowed: Set<string>): boolean {
  for (const candidate of allowed) {
    if (host.endsWith(`.${candidate}`)) return true;
  }
  return false;
}

/** Localhost, link-local and bare IP literals are never valid image hosts. */
function isBlockedHostname(host: string): boolean {
  if (host === 'localhost' || host.endsWith('.localhost')) return true;
  if (host.endsWith('.local') || host.endsWith('.internal')) return true;
  return net.isIP(host) !== 0;
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
    if (normalized.startsWith('fe8') || normalized.startsWith('fe9')) return true;
    if (normalized.startsWith('fea') || normalized.startsWith('feb')) return true;
    if (normalized.startsWith('::ffff:')) {
      return isPrivateAddress(normalized.slice('::ffff:'.length));
    }
  }
  return false;
}

function sha256(input: string | Buffer): string {
  return createHash('sha256').update(input).digest('hex');
}
