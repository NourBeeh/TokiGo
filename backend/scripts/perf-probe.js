#!/usr/bin/env node
/**
 * Repeatable backend performance probe.
 *
 * Answers the only question that matters before optimising: "how slow is it
 * really, and how many bytes does the phone actually download?"
 *
 * Every request is sent twice — once with `Accept-Encoding: gzip` and once
 * without — and both the wire size (what the radio carries) and the decoded
 * size (what JSON.parse sees) are reported. That is the only honest way to
 * show the effect of the compression middleware.
 *
 * Usage (from backend/):
 *   node scripts/perf-probe.js                       # http://localhost:3000
 *   BASE_URL=http://127.0.0.1:3100 node scripts/perf-probe.js
 *   RUNS=5 node scripts/perf-probe.js                # more samples
 */

const http = require('http');
const https = require('https');
const zlib = require('zlib');
const { URL } = require('url');

const BASE_URL = (process.env.BASE_URL || 'http://localhost:3000').replace(
  /\/+$/,
  '',
);
const RUNS = Math.max(1, Number(process.env.RUNS) || 3);

/** A date pair far enough in the future to stay valid, unique per run so the
 *  "cold" line is genuinely cold instead of hitting yesterday's cache entry. */
function searchBody(offsetDays) {
  const day = 24 * 60 * 60 * 1000;
  const offset = offsetDays ?? 30 + Math.floor(Math.random() * 120);
  const checkIn = new Date(Date.now() + offset * day).toISOString().slice(0, 10);
  const checkOut = new Date(Date.now() + (offset + 3) * day)
    .toISOString()
    .slice(0, 10);
  return {
    city: 'Cairo',
    country: 'EG',
    checkIn,
    checkOut,
    guests: 2,
    rooms: 1,
    market: 'EG',
  };
}

/**
 * One HTTP call that reports timing plus both sizes.
 * `wireBytes` counts the bytes on the socket; `decodedBytes` counts the JSON.
 */
function request(
  path,
  { method = 'GET', body, gzip = false, follow = 0, accept = 'application/json' } = {},
) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const transport = url.protocol === 'https:' ? https : http;
    const payload = body === undefined ? null : Buffer.from(JSON.stringify(body));

    const headers = { accept };
    if (payload !== null) {
      headers['content-type'] = 'application/json';
      headers['content-length'] = payload.length;
    }
    if (gzip) headers['accept-encoding'] = 'gzip';

    const started = process.hrtime.bigint();
    const req = transport.request(
      {
        protocol: url.protocol,
        hostname: url.hostname,
        port: url.port,
        path: `${url.pathname}${url.search}`,
        method,
        headers,
      },
      (res) => {
        if (
          follow > 0 &&
          res.statusCode >= 300 &&
          res.statusCode < 400 &&
          res.headers.location
        ) {
          res.resume();
          resolve(
            request(new URL(res.headers.location, url).toString(), {
              method,
              body,
              gzip,
              follow: follow - 1,
            }),
          );
          return;
        }
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const ms = Number(process.hrtime.bigint() - started) / 1e6;
          const wire = Buffer.concat(chunks);
          const encoding = res.headers['content-encoding'];
          let decoded = wire;
          try {
            if (encoding === 'gzip') decoded = zlib.gunzipSync(wire);
            else if (encoding === 'br') decoded = zlib.brotliDecompressSync(wire);
            else if (encoding === 'deflate') decoded = zlib.inflateSync(wire);
          } catch {
            decoded = wire;
          }
          resolve({
            status: res.statusCode,
            ms,
            wireBytes: wire.length,
            decodedBytes: decoded.length,
            encoding: encoding || 'identity',
            contentType: res.headers['content-type'] || '',
            cache: res.headers['x-image-cache'] || '',
            location: res.headers.location || '',
          });
        });
      },
    );
    req.on('error', reject);
    req.setTimeout(120_000, () => req.destroy(new Error('probe timeout')));
    if (payload !== null) req.write(payload);
    req.end();
  });
}

const median = (values) => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
};

async function sample(label, path, options = {}) {
  const runs = options.runs ?? RUNS;
  const rows = [];
  for (let i = 0; i < runs; i += 1) {
    rows.push(await request(path, options));
  }
  const last = rows[rows.length - 1];
  return {
    label,
    status: last.status,
    ms: median(rows.map((r) => r.ms)),
    wireBytes: last.wireBytes,
    decodedBytes: last.decodedBytes,
    encoding: last.encoding,
    cache: last.cache,
  };
}

const kb = (bytes) => `${(bytes / 1024).toFixed(1)}KB`;
const pct = (before, after) =>
  before > 0 ? `${Math.round((1 - after / before) * 100)}%` : '—';

function row(result) {
  const saved =
    result.wireBytes < result.decodedBytes
      ? `  (${pct(result.decodedBytes, result.wireBytes)} smaller on the wire)`
      : '';
  return [
    result.label.padEnd(34),
    String(result.status).padEnd(4),
    `${Math.round(result.ms)}ms`.padEnd(8),
    `wire ${kb(result.wireBytes)}`.padEnd(15),
    `json ${kb(result.decodedBytes)}`,
    result.encoding === 'identity' ? '' : ` ${result.encoding}`,
    result.cache ? ` [${result.cache}]` : '',
    saved,
  ].join('');
}

async function main() {
  console.log(`Probing ${BASE_URL} — ${RUNS} sample(s) per line\n`);

  const results = [];
  results.push(await sample('GET /home/sections (gzip)', '/home/sections', { gzip: true }));
  results.push(await sample('GET /home/sections (raw)', '/home/sections'));
  results.push(
    await sample('GET /home/recommended (gzip)', '/home/recommended?limit=6&code=EG', {
      gzip: true,
    }),
  );

  const fresh = searchBody();
  results.push(
    await sample('POST /search/hotels cold (gzip)', '/search/hotels', {
      method: 'POST',
      body: fresh,
      gzip: true,
      runs: 1,
    }),
  );
  results.push(
    await sample('POST /search/hotels warm (gzip)', '/search/hotels', {
      method: 'POST',
      body: fresh,
      gzip: true,
    }),
  );

  const photo = 'https://static.cupid.travel/hotels/491132974.jpg';
  const proxied = `/images/hotel?src=${encodeURIComponent(photo)}&w=480`;
  results.push(await sample('GET /images/hotel w=480 (first)', proxied, { runs: 1 }));
  results.push(await sample('GET /images/hotel w=480 (repeat)', proxied));

  for (const result of results) console.log(row(result));

  // Compare against what the phone used to download: the provider's original.
  // `fetch` mirrors the transport the proxy itself uses.
  const original = await fetch(photo, { headers: { accept: 'image/*' } })
    .then(async (response) =>
      response.ok
        ? { status: response.status, decodedBytes: (await response.arrayBuffer()).byteLength }
        : { status: response.status, decodedBytes: 0 },
    )
    .catch(() => null);
  const proxiedResult = results[results.length - 1];
  if (original !== null && original.status === 200) {
    console.log(
      `\nOriginal provider photo: ${kb(original.decodedBytes)} ` +
        `→ proxied WebP ${kb(proxiedResult.wireBytes)} ` +
        `(${pct(original.decodedBytes, proxiedResult.wireBytes)} smaller)`,
    );
  } else {
    console.log(
      `\nOriginal provider photo unavailable (HTTP ${original?.status ?? 'error'}); ` +
        `proxied WebP is ${kb(proxiedResult.wireBytes)}.`,
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
