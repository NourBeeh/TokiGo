/**
 * CVSS v3.0 / v3.1 base-score calculator.
 * Used only when a feed hands us a vector but no numeric score (common in OSV).
 */
export function cvssV3BaseScore(vector) {
  if (!vector || !/^CVSS:3\.[01]\//.test(vector)) return null;
  const p = Object.fromEntries(
    vector
      .replace(/^CVSS:3\.[01]\//, "")
      .split("/")
      .map((kv) => kv.split(":"))
  );
  const AV = { N: 0.85, A: 0.62, L: 0.55, P: 0.2 }[p.AV];
  const AC = { L: 0.77, H: 0.44 }[p.AC];
  const UI = { N: 0.85, R: 0.62 }[p.UI];
  const changed = p.S === "C";
  const PR = changed
    ? { N: 0.85, L: 0.68, H: 0.5 }[p.PR]
    : { N: 0.85, L: 0.62, H: 0.27 }[p.PR];
  const impactOf = (v) => ({ H: 0.56, L: 0.22, N: 0 }[v] ?? 0);
  const C = impactOf(p.C);
  const I = impactOf(p.I);
  const A = impactOf(p.A);
  if ([AV, AC, UI, PR].some((v) => v == null)) return null;

  const iss = 1 - (1 - C) * (1 - I) * (1 - A);
  const impact = changed
    ? 7.52 * (iss - 0.029) - 3.25 * Math.pow(iss - 0.02, 15)
    : 6.42 * iss;
  const exploitability = 8.22 * AV * AC * PR * UI;
  if (impact <= 0) return 0;
  const raw = changed
    ? Math.min(1.08 * (impact + exploitability), 10)
    : Math.min(impact + exploitability, 10);
  return Math.ceil(raw * 10) / 10;
}
