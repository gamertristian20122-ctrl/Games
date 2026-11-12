import type { Energy } from './types';

/** Seasons follow the Northern-Hemisphere calendar months. Rewards earned in any season are kept forever. */
export type Season = 'autumn' | 'winter' | 'spring' | 'summer';

export const SEASON_INFO: Record<Season, { name: string; emoji: string; months: string }> = {
  autumn: { name: 'Cozy Autumn', emoji: '🍂', months: 'September–November' },
  winter: { name: 'Snowy Winter', emoji: '❄️', months: 'December–February' },
  spring: { name: 'Blossom Spring', emoji: '🌸', months: 'March–May' },
  summer: { name: 'Sunny Summer', emoji: '☀️', months: 'June–August' },
};

export function seasonFor(date: Date = new Date()): Season {
  const m = date.getMonth() + 1;
  if (m >= 9 && m <= 11) return 'autumn';
  if (m === 12 || m <= 2) return 'winter';
  if (m <= 5) return 'spring';
  return 'summer';
}

/** Monday of the week containing `day` (YYYY-MM-DD), as YYYY-MM-DD. */
export function weekStart(day: string): string {
  const [y, m, d] = day.split('-').map(Number);
  const date = new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, d ?? 1));
  const offset = (date.getUTCDay() + 6) % 7; // Monday = 0
  date.setUTCDate(date.getUTCDate() - offset);
  return date.toISOString().slice(0, 10);
}

/** The 7 day keys of the week that starts on `start`. */
export function weekDays(start: string): string[] {
  const [y, m, d] = start.split('-').map(Number);
  return Array.from({ length: 7 }, (_, i) => new Date(Date.UTC(y ?? 1970, (m ?? 1) - 1, (d ?? 1) + i)).toISOString().slice(0, 10));
}

/**
 * Sprint Star goals for the week, matched to the user's energy.
 * Goals only unlock things; missing one costs nothing (no demotion, ever).
 */
export function sprintTiers(energy: Energy): [number, number, number] {
  if (energy === 'low') return [3, 7, 12];
  if (energy === 'high') return [7, 16, 28];
  return [5, 12, 20];
}
