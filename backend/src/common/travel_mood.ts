export const TRAVEL_MOODS = [
  'shopping',
  'beach',
  'snow',
  'nature',
  'city',
] as const;

export type TravelMood = (typeof TRAVEL_MOODS)[number];
