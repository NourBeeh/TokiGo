/**
 * One country list for the Home seed/maintenance scripts.
 *
 * The destination cards used to store whatever the caller passed: the
 * recommendation feed answers with ISO codes ("EG"), the hand-written city
 * lists with names ("Egypt"). That split published Cairo, Hurghada and Sharm
 * El Sheikh twice — the same city under two country spellings. Every script
 * now resolves both spellings to one code and one display name.
 */

/** The markets the app publishes destinations for. */
const COUNTRIES = [
  { code: 'EG', name: 'Egypt' },
  { code: 'AE', name: 'United Arab Emirates' },
  { code: 'SA', name: 'Saudi Arabia' },
  { code: 'TR', name: 'Turkey' },
  { code: 'QA', name: 'Qatar' },
  { code: 'KW', name: 'Kuwait' },
  { code: 'JO', name: 'Jordan' },
  { code: 'GB', name: 'United Kingdom' },
  { code: 'FR', name: 'France' },
  { code: 'IT', name: 'Italy' },
  { code: 'ES', name: 'Spain' },
  { code: 'DE', name: 'Germany' },
  { code: 'GR', name: 'Greece' },
  { code: 'US', name: 'United States' },
  { code: 'TH', name: 'Thailand' },
  { code: 'SG', name: 'Singapore' },
  { code: 'MY', name: 'Malaysia' },
  { code: 'JP', name: 'Japan' },
  { code: 'GE', name: 'Georgia' },
  { code: 'AZ', name: 'Azerbaijan' },
  { code: 'AT', name: 'Austria' },
  { code: 'FI', name: 'Finland' },
  // The world-famous destinations (scripts/lib/world-cities.js): a card's
  // country line must be a real name, not the ISO code the provider answered
  // with.
  { code: 'NL', name: 'Netherlands' },
  { code: 'ID', name: 'Indonesia' },
  { code: 'MV', name: 'Maldives' },
  { code: 'CZ', name: 'Czechia' },
  { code: 'PT', name: 'Portugal' },
  { code: 'MA', name: 'Morocco' },
  { code: 'ZA', name: 'South Africa' },
  { code: 'MX', name: 'Mexico' },
  { code: 'BR', name: 'Brazil' },
  { code: 'AU', name: 'Australia' },
  { code: 'HK', name: 'Hong Kong' },
  { code: 'KR', name: 'South Korea' },
  { code: 'TW', name: 'Taiwan' },
  { code: 'IN', name: 'India' },
  { code: 'VN', name: 'Vietnam' },
  { code: 'KH', name: 'Cambodia' },
  { code: 'LK', name: 'Sri Lanka' },
  { code: 'OM', name: 'Oman' },
  { code: 'LB', name: 'Lebanon' },
];

const BY_CODE = new Map(COUNTRIES.map((country) => [country.code, country]));

/** Spellings that are not the canonical name but mean the same country. */
const ALIASES = {
  UAE: 'AE',
  KSA: 'SA',
  USA: 'US',
  UK: 'GB',
  'UNITED STATES OF AMERICA': 'US',
  'GREAT BRITAIN': 'GB',
  TURKIYE: 'TR',
  'TÜRKIYE': 'TR',
};

const BY_NAME = new Map();
for (const country of COUNTRIES) {
  BY_NAME.set(country.name.toUpperCase(), country.code);
}
for (const [alias, code] of Object.entries(ALIASES)) {
  BY_NAME.set(alias, code);
}

/** ISO-2 code for a code or a country name; null when unrecognised. */
function countryCodeFor(value) {
  const text = String(value ?? '').trim().toUpperCase();
  if (text.length === 0) return null;
  if (BY_CODE.has(text)) return text;
  return BY_NAME.get(text) ?? null;
}

/** Canonical display name for a code or a name; the trimmed input as a last resort. */
function countryNameFor(value) {
  const code = countryCodeFor(value);
  if (code !== null) return BY_CODE.get(code).name;
  return String(value ?? '').trim();
}

module.exports = { COUNTRIES, countryCodeFor, countryNameFor };
