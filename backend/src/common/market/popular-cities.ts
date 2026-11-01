/**
 * Popular cities per country.
 *
 * One list, two consumers: the Home recommendation scan (which needs real
 * inventory per market) and the search cache warmer (which needs the city
 * names travellers actually type). Keeping a second copy would let the two
 * drift and silently warm cities nobody searches.
 */
export const COUNTRY_CITIES: Record<string, string[]> = {
  EG: ['Cairo', 'Hurghada', 'Sharm El Sheikh', 'Luxor'],
  AE: ['Dubai', 'Abu Dhabi'],
  SA: ['Riyadh', 'Jeddah'],
  TR: ['Istanbul', 'Antalya'],
  QA: ['Doha'],
  KW: ['Kuwait City'],
  JO: ['Amman'],
  GB: ['London'],
  FR: ['Paris', 'Nice'],
  IT: ['Rome', 'Milan'],
  ES: ['Madrid', 'Barcelona'],
  DE: ['Berlin', 'Munich'],
  GR: ['Athens'],
  US: ['New York', 'Miami'],
  TH: ['Bangkok'],
  SG: ['Singapore'],
  MY: ['Kuala Lumpur'],
  JP: ['Tokyo'],
};
