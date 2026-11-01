/**
 * Real city photography for a destination card.
 *
 * The first version of the seeds used one of the city's Nuitee hotel photos as
 * the city cover. That is a real photo, but it is a photo of a ROOM/HOTEL, not
 * the place the card names — a traveller tapping "Cairo" saw a lobby.
 *
 * The second version used the city's Wikipedia/Wikidata P18 image. That fixed
 * the subject, but not the QUALITY: P18 is the entity's canonical image, which
 * for some cities is a montage collage (Istanbul), a portrait crop (Antalya,
 * Baku) or a satellite frame (Amsterdam's Sentinel-2 shot) — the wrong picture
 * for a 4:3 destination tile (user report, 2026-10-30).
 *
 * This module resolves a photo in two steps:
 *
 *   1. city name → enwiki page (redirects followed) → Wikidata P18 →
 *      Commons imageinfo at 1280px.
 *   2. If that photo breaks the tile's rules (portrait, too small, a collage,
 *      a flag/coat of arms, a map, a satellite frame, an extreme panorama),
 *      fall back to a Commons SEARCH for "<city> skyline" / "panorama" and take
 *      the first result that is a real landscape photo naming that city.
 *
 * It returns the image URL plus the attribution the Commons licence requires
 * (author + licence + the file's own page). When every step fails it returns
 * null — the caller then publishes the card with no image, which renders the
 * honest placeholder instead of a misleading photo.
 */
const USER_AGENT =
  'TokiGo/1.0 (destination city photo; +https://tokigo.app)';

const REQUEST_TIMEOUT_MS = 15_000;

/** Cities whose article title differs from the card title. */
const WIKI_TITLE_OVERRIDES = {
  shahdag: 'Shahdag Mountain Resort',
};

/**
 * File names that are never a photo of a place: collages and montages, flags,
 * coats of arms, logos, maps, diagrams, satellite frames, artwork.
 */
const NOT_A_PLACE_PHOTO =
  /montage|collage|\bflag\b|coat[_ ]of[_ ]arms|\blogo\b|\bmap\b|\bmaps\b|seal\b|banner|sentinel|satellite|landsat|diagram|\bchart\b|poster|stamp|banknote|\bcoin\b|goblet|painting|drawing|engraving|industrial|construction|\bcrane\b|\bcranes\b|runway|building site|\bluge\b|amusement|roller coaster|aquarium|\bzoo\b|stadium|\bgolf\b/i;

/** What the tile needs: a landscape photo, wide enough to stay sharp at 640. */
const MIN_WIDTH = 1000;
const MIN_RATIO = 1.15; // anything squarer crops the subject away at 4:3
const MAX_RATIO = 3.2; // a 5:1 band loses the city inside a 4:3 crop

/**
 * The visual terms a searched photo must name in its own file name.
 *
 * A Commons search returns what the corpus calls "a picture near the query",
 * not what the traveller means: "Amsterdam skyline" once surfaced a photo of
 * construction cranes by a building site. Requiring the term in the title keeps
 * the search honest about what it found.
 */
const SEARCH_TERMS = ['skyline', 'panorama', 'view', 'aerial', 'landmark'];

async function apiJson(url) {
  const response = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT, accept: 'application/json' },
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`${response.status} for ${url}`);
  return response.json();
}

function firstPage(payload) {
  return Object.values(payload?.query?.pages ?? {})[0];
}

/** Plain text out of the HTML fragments Commons stores in extmetadata. */
function plainText(html) {
  return decodeEntities(String(html ?? '').replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

function decodeEntities(text) {
  return text
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&nbsp;/g, ' ');
}

/**
 * Commons sometimes repeats the placeholder author ("Unknown authorUnknown
 * author") because the field is a concatenation. Collapse it.
 */
function cleanCredit(value) {
  const text = plainText(value);
  if (!text) return '';
  return text.replace(/Unknown authorUnknown author/gi, 'Unknown author');
}

/** Drops the analytics query Commons appends to its thumbnail URLs. */
function withoutQuery(url) {
  try {
    const parsed = new URL(url);
    parsed.search = '';
    return parsed.toString();
  } catch (_) {
    return url;
  }
}

/** Accent- and case-insensitive form, for matching a city inside a file name. */
function normalise(text) {
  return String(text ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

/**
 * Is [info] a photo this tile can show?
 *
 * @param {any} info Commons imageinfo entry (needs width/height).
 * @param {string} title File title (without the `File:` prefix).
 * @param {{ strict?: boolean }} [options] `strict: false` keeps any landscape
 *   photo that is not a map/flag — the last resort before "no photo at all".
 */
function isUsablePhoto(info, title, options = {}) {
  const width = Number(info?.width);
  const height = Number(info?.height);
  if (!Number.isFinite(width) || !Number.isFinite(height)) return false;
  if (NOT_A_PLACE_PHOTO.test(title)) return false;
  if (width < MIN_WIDTH) return false;
  // Portrait: a 4:3 tile would crop the subject out of the frame.
  if (width <= height) return false;
  if (options.strict === false) return true;
  const ratio = width / height;
  return ratio >= MIN_RATIO && ratio <= MAX_RATIO;
}

/** One Commons response entry → the shape the callers store. */
function toPhoto(info) {
  const meta = info?.extmetadata ?? {};
  return {
    imageUrl: withoutQuery(info.thumburl ?? info.url),
    imageSource: info.descriptionurl ?? null,
    imageCredit: cleanCredit(meta.Artist?.value) || 'Wikimedia Commons',
    imageLicense: plainText(meta.LicenseShortName?.value) || null,
  };
}

/** Commons `imageinfo` for one `File:` title (size + licence + 1280px thumb). */
async function imageInfo(fileTitle) {
  const query = new URLSearchParams({
    action: 'query',
    format: 'json',
    prop: 'imageinfo',
    iiprop: 'size|extmetadata|url',
    iiurlwidth: '1280',
    titles: fileTitle,
  });
  const payload = await apiJson(
    `https://commons.wikimedia.org/w/api.php?${query}`,
  );
  return firstPage(payload)?.imageinfo?.[0] ?? null;
}

/** The entity's canonical image (Wikidata P18), with its Commons metadata. */
async function canonicalImage(wikiTitle) {
  const resolveQuery = new URLSearchParams({
    action: 'query',
    format: 'json',
    redirects: '1',
    titles: wikiTitle,
  });
  const resolved = await apiJson(
    `https://en.wikipedia.org/w/api.php?${resolveQuery}`,
  );
  const page = firstPage(resolved);
  if (!page || page.missing !== undefined) return null;

  const entityQuery = new URLSearchParams({
    action: 'wbgetentities',
    format: 'json',
    sites: 'enwiki',
    titles: page.title,
    props: 'claims',
  });
  const entities = await apiJson(
    `https://www.wikidata.org/w/api.php?${entityQuery}`,
  );
  const entity = Object.values(entities?.entities ?? {})[0];
  const file = entity?.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
  if (!file) return null;

  const info = await imageInfo(`File:${file}`);
  return info ? { file, info } : null;
}

/**
 * Commons search for a real photo of [city].
 *
 * "skyline" first (a destination tile is a city tile), then "panorama", then
 * "view". A result only counts when the CITY is named in its file name: a
 * search for "Cancún panorama" otherwise returns holiday snapshots from an
 * unrelated Flickr album, which is how a destination tile ends up captioned
 * "The Farter".
 */
async function searchedPhoto(city, strict = true) {
  const token = normalise(city).split(/[\s,]+/)[0];
  if (!token) return null;

  for (const term of SEARCH_TERMS) {
    const query = new URLSearchParams({
      action: 'query',
      format: 'json',
      generator: 'search',
      gsrsearch: `${city} ${term}`,
      gsrnamespace: '6',
      gsrlimit: '20',
      prop: 'imageinfo',
      iiprop: 'size|extmetadata|url',
      iiurlwidth: '1280',
    });
    let payload;
    try {
      payload = await apiJson(
        `https://commons.wikimedia.org/w/api.php?${query}`,
      );
    } catch (_) {
      continue;
    }
    let best = null;
    for (const page of Object.values(payload?.query?.pages ?? {})) {
      const info = page?.imageinfo?.[0];
      const title = String(page?.title ?? '').replace(/^File:/, '');
      if (!info) continue;
      const folded = normalise(title);
      // The photo must name the city AND the term that found it.
      if (!folded.includes(token)) continue;
      if (!folded.includes(term)) continue;
      if (!isUsablePhoto(info, title, { strict })) continue;
      // Resolution stands in for "a real camera photo": within one search term
      // the biggest file is the one shot for the view, not a stray snapshot.
      if (!best || Number(info.width) > Number(best.info.width)) {
        best = { file: title, info };
      }
    }
    if (best) return best;
  }
  return null;
}

/**
 * The real photo of [city], or null when Wikipedia/Wikidata/Commons do not
 * provide one that this tile can show honestly.
 *
 * @param {string} city Display name ("Sharm El Sheikh").
 * @param {{ wikiTitle?: string }} [options] Article override.
 * @returns {Promise<null | {
 *   imageUrl: string,
 *   imageSource: string | null,
 *   imageCredit: string,
 *   imageLicense: string | null,
 *   imageFile: string,
 * }>}
 */
async function cityImageFor(city, options = {}) {
  const name = String(city ?? '').trim();
  if (!name) return null;
  const wikiTitle =
    options.wikiTitle || WIKI_TITLE_OVERRIDES[name.toLowerCase()] || name;

  try {
    const canonical = await canonicalImage(wikiTitle);

    // 1) The entity's own image, when it IS a photo of the place.
    if (
      canonical &&
      isUsablePhoto(canonical.info, String(canonical.file ?? ''), {
        strict: true,
      })
    ) {
      return { ...toPhoto(canonical.info), imageFile: canonical.file };
    }

    // 2) A Commons skyline/panorama photo of this city.
    const searched = await searchedPhoto(wikiTitle, true);
    if (searched) {
      return { ...toPhoto(searched.info), imageFile: searched.file };
    }

    // 3) Last resorts, weakest first — still never a portrait, flag or map.
    if (
      canonical &&
      isUsablePhoto(canonical.info, String(canonical.file ?? ''), {
        strict: false,
      })
    ) {
      return { ...toPhoto(canonical.info), imageFile: canonical.file };
    }
    const loose = await searchedPhoto(wikiTitle, false);
    if (loose) return { ...toPhoto(loose.info), imageFile: loose.file };

    return null;
  } catch (error) {
    console.warn(`city photo unavailable for ${name}: ${error.message}`);
    return null;
  }
}

module.exports = {
  cityImageFor,
  isUsablePhoto,
  WIKI_TITLE_OVERRIDES,
};
