import {
  ANDROID_MIN_API,
  ANDROID_TARGET_API,
  androidApiOf,
  severityFromLabel,
  severityFromScore,
} from "./config.mjs";
import { cvssV3BaseScore } from "./cvss.mjs";

/* ---------------------------------------------------------------- NVD ----- */

export function nvdMetrics(cve) {
  const m = cve.metrics ?? {};
  const entry =
    m.cvssMetricV40?.[0] ??
    m.cvssMetricV31?.[0] ??
    m.cvssMetricV30?.[0] ??
    m.cvssMetricV2?.[0] ??
    null;
  if (!entry) return { score: null, vector: null, severity: "unknown" };
  const data = entry.cvssData ?? {};
  const score = typeof data.baseScore === "number" ? data.baseScore : null;
  const severity =
    severityFromLabel(data.baseSeverity ?? entry.baseSeverity) !== "unknown"
      ? severityFromLabel(data.baseSeverity ?? entry.baseSeverity)
      : severityFromScore(score);
  return { score, vector: data.vectorString ?? null, severity };
}

export function normalizeNvd(cve, fetchedAt) {
  const desc = (cve.descriptions ?? []).find((d) => d.lang === "en")?.value ?? null;
  const { score, vector, severity } = nvdMetrics(cve);
  const cwe = [
    ...new Set(
      (cve.weaknesses ?? []).flatMap((w) =>
        (w.description ?? []).map((d) => d.value).filter((v) => /^CWE-/.test(v))
      )
    ),
  ];
  return {
    id: cve.id,
    source: "nvd",
    aliases: [cve.id],
    summary: desc ? desc.slice(0, 400) : null,
    details: desc,
    published: cve.published ?? null,
    modified: cve.lastModified ?? null,
    cvssScore: score,
    cvssVector: vector,
    severity,
    cwe,
    refs: (cve.references ?? []).map((r) => r.url).filter(Boolean).slice(0, 20),
    fetchedAt,
  };
}

const ZERO_KEYS = new Set(["*", "-", ""]);

/**
 * Which Android API levels a CVE claims to affect, and whether that intersects
 * the range TokiGo is installable on (minSdk..targetSdk).
 */
export function androidImpact(cve) {
  const ranges = [];
  let sawAndroid = false;

  for (const conf of cve.configurations ?? []) {
    const matches = [];
    for (const node of conf.nodes ?? []) {
      for (const m of node.cpeMatch ?? []) {
        if (m.vulnerable === false || !m.criteria) continue;
        matches.push(m);
      }
    }

    const android = matches.filter((m) => /^cpe:2\.3:o:google:android:/.test(m.criteria));
    if (!android.length) continue;

    // NVD also files "third-party app running on Android" as an AND-config with
    // a vulnerable Android OS CPE (e.g. Flash Player, Chrome). Those are not
    // platform CVEs for TokiGo. A genuine OS CVE lists Android on its own (or
    // with a version/range); a wrapped app does not.
    const foreignApplication = matches.some((m) => {
      const p = m.criteria.split(":");
      return p[2] === "a" && !(p[3] === "google" && p[4] === "android");
    });
    const androidIsVersioned = android.some((m) => {
      const v = m.criteria.split(":")[5];
      return (
        !ZERO_KEYS.has(v) ||
        m.versionStartIncluding ||
        m.versionEndIncluding ||
        m.versionStartExcluding ||
        m.versionEndExcluding
      );
    });
    if (foreignApplication && !androidIsVersioned) continue;

    sawAndroid = true;
    for (const m of android) {
      const version = m.criteria.split(":")[5];
      let lo = null;
      let hi = null;

      if (!ZERO_KEYS.has(version)) {
        lo = hi = androidApiOf(version);
      } else {
        lo = m.versionStartIncluding ? androidApiOf(m.versionStartIncluding) : null;
        if (m.versionStartExcluding) {
          const v = androidApiOf(m.versionStartExcluding);
          lo = v == null ? null : v + 1;
        }
        hi = m.versionEndIncluding ? androidApiOf(m.versionEndIncluding) : null;
        if (m.versionEndExcluding) {
          const v = androidApiOf(m.versionEndExcluding);
          hi = v == null ? null : v - 1;
        }
      }

      if (lo == null && hi == null) ranges.push({ generic: true, lo: null, hi: null });
      else ranges.push({ generic: false, lo: lo ?? 0, hi: hi ?? Infinity });
    }
  }

  if (!sawAndroid) return null;

  const inRange = ranges.filter((r) => r.generic || (r.lo <= ANDROID_TARGET_API && r.hi >= ANDROID_MIN_API));
  const generic = inRange.some((r) => r.generic);
  const constrained = inRange.filter((r) => !r.generic);
  const minApi = constrained.length ? Math.min(...constrained.map((r) => r.lo)) : null;
  const maxApi = constrained.length
    ? Math.max(...constrained.map((r) => (Number.isFinite(r.hi) ? r.hi : ANDROID_TARGET_API)))
    : null;

  return {
    reachable: inRange.length > 0,
    generic,
    constrained: constrained.length > 0,
    minApi,
    maxApi,
    matchType: generic && !constrained.length ? "platform-generic" : "platform-os",
    reachability: generic && !constrained.length ? "platform-unconfirmed" : "platform",
  };
}

/* ---------------------------------------------------------------- OSV ----- */

export function normalizeOsv(vuln, fetchedAt) {
  const sev = (vuln.severity ?? [])
    .map((s) => (s.type?.startsWith("CVSS") ? cvssV3BaseScore(s.score) : null))
    .find((v) => typeof v === "number");
  const label =
    vuln.database_specific?.severity ??
    vuln.affected?.[0]?.database_specific?.severity ??
    null;

  let score = typeof sev === "number" ? sev : null;
  let severity = label ? severityFromLabel(label) : severityFromScore(score);
  if (severity === "unknown" && score != null) severity = severityFromScore(score);
  if (score == null && severity !== "unknown") {
    // keep textual severity; synthesise a representative score for ordering only
    score = { critical: 9.5, high: 8.0, medium: 5.5, low: 2.5 }[severity] ?? null;
  }

  const cwe = [
    ...new Set(
      (vuln.database_specific?.cwe_ids ?? []).filter((c) => /^CWE-/.test(c))
    ),
  ];

  return {
    id: vuln.id,
    source: "osv",
    aliases: [vuln.id, ...(vuln.aliases ?? [])],
    summary: vuln.summary ?? null,
    details: vuln.details ?? null,
    published: vuln.published ?? null,
    modified: vuln.modified ?? null,
    cvssScore: score,
    cvssVector: vuln.severity?.[0]?.score ?? null,
    severity,
    cwe,
    refs: (vuln.references ?? []).map((r) => r.url).filter(Boolean).slice(0, 20),
    fetchedAt,
  };
}

/** First fixed version that is greater than the installed one. */
export function fixedVersionFor(vuln, name, version) {
  const candidates = [];
  for (const affected of vuln.affected ?? []) {
    if (affected.package?.name !== name) continue;
    for (const range of affected.ranges ?? []) {
      for (const ev of range.events ?? []) {
        if (ev.fixed) candidates.push(ev.fixed);
      }
    }
    if (affected.database_specific?.fixed) candidates.push(affected.database_specific.fixed);
  }
  const greater = candidates.filter((v) => compareVersions(v, version) > 0);
  greater.sort(compareVersions);
  return greater[0] ?? null;
}

export function compareVersions(a, b) {
  const pa = String(a).split(/[.+-]/).map((x) => (isNaN(Number(x)) ? x : Number(x)));
  const pb = String(b).split(/[.+-]/).map((x) => (isNaN(Number(x)) ? x : Number(x)));
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const x = pa[i] ?? 0;
    const y = pb[i] ?? 0;
    if (typeof x === "number" && typeof y === "number") {
      if (x !== y) return x - y;
    } else {
      const s = String(x).localeCompare(String(y));
      if (s !== 0) return s;
    }
  }
  return 0;
}
