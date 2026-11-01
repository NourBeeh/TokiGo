/**
 * The world's most famous tourist cities, in fame order.
 *
 * The Discover rail is the traveller's "where next?" cue, and it used to answer
 * with the local market's cities alone (Egypt + the Gulf + a handful of ski
 * resorts). The owner asked for the cities the WORLD thinks of when it thinks
 * of travel (2026-10-30), so this list leads the rail.
 *
 * Every entry was verified against the live provider before it was written
 * down: `scripts/seed-world-cities.js` still re-checks each one at publish time
 * and skips a city the provider has no stays in — a tile that opens an empty
 * search is a broken promise, not content.
 *
 * Fields:
 *   rank        1 = the most famous; also the rail's position.
 *   name        What the traveller sees on the card.
 *   search      What the provider is asked for ("Male" answers for the
 *               Maldives; the card still says "Maldives").
 *   countryCode ISO-2, required by the provider for a city search.
 *   wikiTitle   The enwiki article to read the cover photo from, when it is not
 *               the card's own name.
 *   region      The area the card's "region" line names (the Maldives are
 *               islands, Bali is an island province).
 */
module.exports = [
  { rank: 1, name: 'Paris', search: 'Paris', countryCode: 'FR' },
  { rank: 2, name: 'London', search: 'London', countryCode: 'GB' },
  { rank: 3, name: 'Rome', search: 'Rome', countryCode: 'IT' },
  { rank: 4, name: 'Barcelona', search: 'Barcelona', countryCode: 'ES' },
  { rank: 5, name: 'Amsterdam', search: 'Amsterdam', countryCode: 'NL' },
  { rank: 6, name: 'New York', search: 'New York', countryCode: 'US' },
  { rank: 7, name: 'Tokyo', search: 'Tokyo', countryCode: 'JP' },
  { rank: 8, name: 'Singapore', search: 'Singapore', countryCode: 'SG' },
  { rank: 9, name: 'Bangkok', search: 'Bangkok', countryCode: 'TH' },
  {
    rank: 10,
    name: 'Bali',
    search: 'Bali',
    countryCode: 'ID',
    wikiTitle: 'Bali',
  },
  {
    rank: 11,
    name: 'Maldives',
    search: 'Male',
    countryCode: 'MV',
    wikiTitle: 'Malé',
  },
  { rank: 12, name: 'Prague', search: 'Prague', countryCode: 'CZ' },
  { rank: 13, name: 'Vienna', search: 'Vienna', countryCode: 'AT' },
  { rank: 14, name: 'Lisbon', search: 'Lisbon', countryCode: 'PT' },
  { rank: 15, name: 'Athens', search: 'Athens', countryCode: 'GR' },
  { rank: 16, name: 'Santorini', search: 'Santorini', countryCode: 'GR' },
  { rank: 17, name: 'Venice', search: 'Venice', countryCode: 'IT' },
  { rank: 18, name: 'Madrid', search: 'Madrid', countryCode: 'ES' },
  { rank: 19, name: 'Marrakech', search: 'Marrakech', countryCode: 'MA' },
  { rank: 20, name: 'Cape Town', search: 'Cape Town', countryCode: 'ZA' },
  { rank: 21, name: 'Cancún', search: 'Cancún', countryCode: 'MX' },
  {
    rank: 22,
    name: 'Rio de Janeiro',
    search: 'Rio de Janeiro',
    countryCode: 'BR',
  },
  { rank: 23, name: 'Sydney', search: 'Sydney', countryCode: 'AU' },
  { rank: 24, name: 'Hong Kong', search: 'Hong Kong', countryCode: 'HK' },
];
