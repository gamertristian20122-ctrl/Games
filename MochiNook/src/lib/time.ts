import type { Anchor, Anchors } from './types';

/** Local calendar day as YYYY-MM-DD. */
export function dayKey(date: Date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** Whole days between two YYYY-MM-DD keys (b - a). */
export function daysBetween(a: string, b: string): number {
  const [ay, am, ad] = a.split('-').map(Number);
  const [by, bm, bd] = b.split('-').map(Number);
  const ta = Date.UTC(ay ?? 1970, (am ?? 1) - 1, ad ?? 1);
  const tb = Date.UTC(by ?? 1970, (bm ?? 1) - 1, bd ?? 1);
  return Math.round((tb - ta) / 86_400_000);
}

export function formatClock(minutes: number): string {
  const m = ((Math.round(minutes) % 1440) + 1440) % 1440;
  const h24 = Math.floor(m / 60);
  const mm = String(m % 60).padStart(2, '0');
  const suffix = h24 < 12 ? 'AM' : 'PM';
  const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
  return `${h12}:${mm} ${suffix}`;
}

export function wrapMinutes(minutes: number): number {
  return ((minutes % 1440) + 1440) % 1440;
}

export function minutesNow(date: Date = new Date()): number {
  return date.getHours() * 60 + date.getMinutes();
}

/** Which part of the user's day "now" falls into, based on their anchors. */
export function currentAnchor(anchors: Anchors, now: number): Exclude<Anchor, 'anytime'> {
  const { wake, blockKind, blockStart, blockEnd, bed } = anchors;
  const middayEnd = blockKind === 'none' ? wrapMinutes(bed - 180) : blockEnd;
  const morningEnd = blockKind === 'none' ? wrapMinutes(wake + 180) : blockStart;
  const inRange = (start: number, end: number) =>
    start <= end ? now >= start && now < end : now >= start || now < end;
  if (inRange(wake, morningEnd)) return 'morning';
  if (inRange(morningEnd, middayEnd)) return 'daytime';
  return 'evening';
}

export function greeting(now: number): string {
  if (now < 5 * 60) return 'Hello, night owl';
  if (now < 12 * 60) return 'Good morning';
  if (now < 17 * 60) return 'Good afternoon';
  return 'Good evening';
}
