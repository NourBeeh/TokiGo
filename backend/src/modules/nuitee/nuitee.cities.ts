/**
 * City → ISO-2 country table for the Nuitee rates request.
 *
 * The rates endpoint needs the city's country: omitting it makes Nuitee fall
 * back to Egypt and silently return zero stays for every other city (the bug
 * behind the false "no snow" result). Kept as data, away from orchestration.
 */
export const CITY_COUNTRIES: Record<string, string> = {
  cairo: 'EG', 'القاهرة': 'EG', 'القاهره': 'EG', alexandria: 'EG',
  'الاسكندرية': 'EG', 'الإسكندرية': 'EG', hurghada: 'EG', 'الغردقة': 'EG',
  'sharm el sheikh': 'EG', 'شرم الشيخ': 'EG', luxor: 'EG', 'الأقصر': 'EG',
  aswan: 'EG', 'أسوان': 'EG',
  dubai: 'AE', 'دبي': 'AE', 'abu dhabi': 'AE', 'أبوظبي': 'AE',
  riyadh: 'SA', 'الرياض': 'SA', jeddah: 'SA', 'جدة': 'SA', 'جده': 'SA',
  mecca: 'SA', 'مكة': 'SA', medina: 'SA', 'المدينة': 'SA',
  doha: 'QA', 'الدوحة': 'QA', kuwait: 'KW', 'الكويت': 'KW',
  amman: 'JO', 'عمّان': 'JO', 'عمان الأردن': 'JO',
  istanbul: 'TR', 'اسطنبول': 'TR', 'إسطنبول': 'TR',
  london: 'GB', 'لندن': 'GB', paris: 'FR', 'باريس': 'FR',
  rome: 'IT', 'روما': 'IT', milan: 'IT', 'ميلان': 'IT', 'ميلانو': 'IT',
  madrid: 'ES', 'مدريد': 'ES', barcelona: 'ES', 'برشلونة': 'ES',
  berlin: 'DE', 'برلين': 'DE', munich: 'DE', 'ميونخ': 'DE',
  vienna: 'AT', 'فيينا': 'AT', athens: 'GR', 'أثينا': 'GR', 'اثينا': 'GR',
  'new york': 'US', 'نيويورك': 'US', toronto: 'CA', 'تورونتو': 'CA',
  bangkok: 'TH', 'بانكوك': 'TH', singapore: 'SG', 'سنغافورة': 'SG',
  'kuala lumpur': 'MY', 'كوالالمبور': 'MY', tokyo: 'JP', 'طوكيو': 'JP',
  // Discover cities added 2026-10-22.
  dahab: 'EG', nuweiba: 'EG', 'marsa alam': 'EG',
  // Snow destinations with verified real winter inventory.
  gudauri: 'GE', tbilisi: 'GE', shahdag: 'AZ', baku: 'AZ',
  almaty: 'KZ', sarajevo: 'BA', jahorina: 'BA', kopaonik: 'RS',
  rovaniemi: 'FI', tromso: 'NO', oslo: 'NO',
  innsbruck: 'AT', salzburg: 'AT', zermatt: 'CH', chamonix: 'FR',
  bansko: 'BG', borovets: 'BG', zakopane: 'PL',
  aspen: 'US', banff: 'CA', whistler: 'CA',
  sapporo: 'JP', niseko: 'JP', erzurum: 'TR',
};

/** Case/space-insensitive lookup for the country of [city]. */
export function countryFor(city: string): string | undefined {
  return CITY_COUNTRIES[(city || '').trim().toLowerCase()];
}
