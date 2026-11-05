import { SOURCES } from "./config.mjs";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function fetchJson(url, { method = "GET", body, headers = {}, retries = 4, timeoutMs = 120_000 } = {}) {
  let lastErr;
  for (let attempt = 0; attempt <= retries; attempt++) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetch(url, {
        method,
        headers: {
          "user-agent": "TokiGo-VulnDB/1.0 (+https://github.com/tokigo)",
          accept: "application/json",
          ...(body ? { "content-type": "application/json" } : {}),
          ...headers,
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: ctrl.signal,
      });
      if (res.status === 429 || res.status === 503) {
        const wait = Number(res.headers.get("retry-after") || 0) * 1000 || 6000 * (attempt + 1);
        lastErr = new Error(`HTTP ${res.status} from ${url}`);
        await sleep(wait);
        continue;
      }
      if (!res.ok) {
        const text = await res.text().catch(() => "");
        throw new Error(`HTTP ${res.status} from ${url}: ${text.slice(0, 200)}`);
      }
      return await res.json();
    } catch (err) {
      lastErr = err;
      if (attempt === retries) break;
      await sleep(1000 * 2 ** attempt);
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastErr;
}

/* ------------------------------------------------------------------ NVD --- */

const NVD_PAGE = 2000;

/**
 * Stream every NVD CVE whose CPE matches the Android OS platform.
 * NVD allows 5 req/30s without an API key and 50 req/30s with one.
 */
export async function* nvdAndroidPages({ apiKey, lastModStart, lastModEnd } = {}) {
  const key = apiKey || process.env.NVD_API_KEY;
  const gapMs = key ? 700 : 6500;
  const params = new URLSearchParams({
    virtualMatchString: "cpe:2.3:o:google:android",
    resultsPerPage: String(NVD_PAGE),
  });
  if (lastModStart) {
    params.set("lastModStartDate", lastModStart);
    if (lastModEnd) params.set("lastModEndDate", lastModEnd);
  }

  let startIndex = 0;
  let total = Infinity;
  while (startIndex < total) {
    params.set("startIndex", String(startIndex));
    const data = await fetchJson(`${SOURCES.nvd}?${params}`, {
      headers: key ? { apiKey: key } : {},
      retries: 3,
    });
    total = data.totalResults ?? 0;
    yield { total, startIndex, vulnerabilities: data.vulnerabilities ?? [] };
    startIndex += NVD_PAGE;
    if (startIndex < total) await sleep(gapMs);
  }
}

export async function nvdByCve(cveId, apiKey) {
  const key = apiKey || process.env.NVD_API_KEY;
  const data = await fetchJson(`${SOURCES.nvd}?cveId=${encodeURIComponent(cveId)}`, {
    headers: key ? { apiKey: key } : {},
  });
  return data.vulnerabilities?.[0]?.cve ?? null;
}

/* ------------------------------------------------------------------ OSV --- */

const OSV_BATCH = 500;

/** Resolve vulnerabilities for [{name, ecosystem, version}] using OSV. */
export async function osvQueryBatch(queries) {
  const out = [];
  for (let i = 0; i < queries.length; i += OSV_BATCH) {
    const chunk = queries.slice(i, i + OSV_BATCH);
    const data = await fetchJson(SOURCES.osvQuery, {
      method: "POST",
      body: { queries: chunk },
    });
    out.push(...(data.results ?? []));
    if (i + OSV_BATCH < queries.length) await sleep(500);
  }
  return out;
}

export async function osvVuln(id) {
  return fetchJson(`${SOURCES.osvVuln}/${encodeURIComponent(id)}`);
}

/* ------------------------------------------------------------------ KEV --- */

export async function cisaKev() {
  return fetchJson(SOURCES.kev);
}

/* ------------------------------------------------------- Android bulletins -- */

/**
 * Android Security Bulletin index. Used to tag platform CVEs with the bulletin
 * month so the report can show "patched in <month>" guidance.
 */
export async function androidBulletinIndex() {
  try {
    const res = await fetch("https://source.android.com/docs/security/bulletin", {
      headers: { "user-agent": "TokiGo-VulnDB/1.0" },
    });
    if (!res.ok) return [];
    const html = await res.text();
    const out = [];
    const re = /href="(\/docs\/security\/bulletin\/(\d{4}-\d{2}-\d{2}))"[^>]*>([^<]*)</g;
    let m;
    while ((m = re.exec(html))) out.push({ url: `https://source.android.com${m[1]}`, id: m[2] });
    return out;
  } catch {
    return [];
  }
}
