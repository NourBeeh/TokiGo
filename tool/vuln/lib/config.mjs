import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const ROOT = path.resolve(HERE, "..", "..", "..");

export const DATA_DIR = path.join(ROOT, "tool", "vuln", "data");
export const DB_PATH = path.join(DATA_DIR, "tokigo-vuln.db");
export const LATEST_JSON = path.join(DATA_DIR, "latest.json");
export const REPORT_DIR = path.join(ROOT, "docs", "security");

export const PUBSPEC = path.join(ROOT, "pubspec.yaml");
export const PUBSPEC_LOCK = path.join(ROOT, "pubspec.lock");
export const BACKEND_PKG = path.join(ROOT, "backend", "package.json");
export const BACKEND_LOCK = path.join(ROOT, "backend", "package-lock.json");
export const ANDROID_DIR = path.join(ROOT, "android");

/**
 * The Android API range TokiGo can actually be installed on.
 * Derived from android/app/build.gradle.kts -> flutter.minSdkVersion / flutter.targetSdkVersion.
 * Override with TOKIGO_ANDROID_MIN_API / TOKIGO_ANDROID_TARGET_API.
 */
export const ANDROID_MIN_API = Number(process.env.TOKIGO_ANDROID_MIN_API || 24); // Android 7.0
export const ANDROID_TARGET_API = Number(process.env.TOKIGO_ANDROID_TARGET_API || 36); // Android 16

export const SEVERITY_ORDER = ["critical", "high", "medium", "low", "unknown"];

export const SOURCES = {
  nvd: "https://services.nvd.nist.gov/rest/json/cves/2.0",
  osvQuery: "https://api.osv.dev/v1/querybatch",
  osvVuln: "https://api.osv.dev/v1/vulns",
  kev: "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json",
};

export function severityFromScore(score) {
  if (typeof score !== "number" || Number.isNaN(score) || score <= 0) return "unknown";
  if (score >= 9.0) return "critical";
  if (score >= 7.0) return "high";
  if (score >= 4.0) return "medium";
  return "low";
}

/** Map GHSA / OSV textual severities onto our four buckets. */
export function severityFromLabel(label) {
  if (!label) return "unknown";
  switch (String(label).toUpperCase()) {
    case "CRITICAL":
      return "critical";
    case "HIGH":
      return "high";
    case "MODERATE":
    case "MEDIUM":
      return "medium";
    case "LOW":
      return "low";
    default:
      return "unknown";
  }
}

/** Android release -> API level. Keys are normalised (no trailing .0). */
const API_BY_RELEASE = {
  "1.0": 1, "1.1": 2, "1.5": 3, "1.6": 4,
  "2.0": 5, "2.1": 7, "2.2": 8, "2.3": 9, "2.3.3": 10,
  "3.0": 11, "3.1": 12, "3.2": 13,
  "4.0": 14, "4.0.3": 15, "4.1": 16, "4.2": 17, "4.3": 18, "4.4": 19,
  "5.0": 21, "5.1": 22, "6.0": 23,
  "7.0": 24, "7.1": 25, "8.0": 26, "8.1": 27, "9": 28,
  "10": 29, "11": 30, "12": 31, "12.1": 32, "13": 33, "14": 34, "15": 35, "16": 36,
};

export function androidApiOf(release) {
  if (!release) return null;
  const raw = String(release).trim();
  if (API_BY_RELEASE[raw] != null) return API_BY_RELEASE[raw];
  const norm = raw.replace(/\.0$/, "");
  if (API_BY_RELEASE[norm] != null) return API_BY_RELEASE[norm];

  const parts = norm.split(".").map(Number);
  if (!Number.isFinite(parts[0])) return null;
  const major = parts[0];
  const minor = Number.isFinite(parts[1]) ? parts[1] : 0;

  // Exact major.minor, then major-only, then the closest lower known minor.
  if (API_BY_RELEASE[`${major}.${minor}`] != null) return API_BY_RELEASE[`${major}.${minor}`];
  if (API_BY_RELEASE[`${major}`] != null) return API_BY_RELEASE[`${major}`];

  const candidates = Object.entries(API_BY_RELEASE)
    .map(([k, api]) => ({ k, api, major: Number(k.split(".")[0]), minor: Number(k.split(".")[1] ?? 0) }))
    .filter((e) => e.major === major && e.minor <= minor)
    .sort((a, b) => b.minor - a.minor);
  return candidates[0]?.api ?? null;
}

export function apiLabel(api) {
  if (api == null) return "?";
  const names = {
    24: "7.0", 25: "7.1", 26: "8.0", 27: "8.1", 28: "9", 29: "10", 30: "11",
    31: "12", 32: "12L", 33: "13", 34: "14", 35: "15", 36: "16",
  };
  return `API ${api}${names[api] ? ` (Android ${names[api]})` : ""}`;
}
