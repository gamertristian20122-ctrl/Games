import type { Anchor, Cadence, SharePayload, SharedQuest } from './types';

/**
 * Caregiver share codes: a routine packed into a copy-pasteable string.
 * Entirely offline: no accounts, no servers. Format: "MN1-" + base64url(UTF-8 JSON).
 */

const PREFIX = 'MN1-';
const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

function utf8Encode(str: string): number[] {
  const out: number[] = [];
  for (const ch of str) {
    let cp = ch.codePointAt(0) ?? 0;
    if (cp < 0x80) out.push(cp);
    else if (cp < 0x800) out.push(0xc0 | (cp >> 6), 0x80 | (cp & 63));
    else if (cp < 0x10000) out.push(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    else {
      cp = Math.min(cp, 0x10ffff);
      out.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63));
    }
  }
  return out;
}

function utf8Decode(bytes: number[]): string {
  let out = '';
  let i = 0;
  while (i < bytes.length) {
    const b = bytes[i++] ?? 0;
    let cp: number;
    if (b < 0x80) cp = b;
    else if (b >= 0xf0) cp = ((b & 7) << 18) | (((bytes[i++] ?? 0) & 63) << 12) | (((bytes[i++] ?? 0) & 63) << 6) | ((bytes[i++] ?? 0) & 63);
    else if (b >= 0xe0) cp = ((b & 15) << 12) | (((bytes[i++] ?? 0) & 63) << 6) | ((bytes[i++] ?? 0) & 63);
    else cp = ((b & 31) << 6) | ((bytes[i++] ?? 0) & 63);
    out += String.fromCodePoint(cp);
  }
  return out;
}

function toBase64Url(bytes: number[]): string {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const a = bytes[i] ?? 0;
    const b = bytes[i + 1];
    const c = bytes[i + 2];
    const n = (a << 16) | ((b ?? 0) << 8) | (c ?? 0);
    out += B64[(n >> 18) & 63]! + B64[(n >> 12) & 63]!;
    if (b !== undefined) out += B64[(n >> 6) & 63]!;
    if (c !== undefined) out += B64[n & 63]!;
  }
  return out;
}

function fromBase64Url(text: string): number[] {
  const bytes: number[] = [];
  let buffer = 0;
  let bits = 0;
  for (const ch of text) {
    const v = B64.indexOf(ch);
    if (v < 0) throw new Error('bad character');
    buffer = (buffer << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      bytes.push((buffer >> bits) & 0xff);
    }
  }
  return bytes;
}

export function encodeShareCode(payload: SharePayload): string {
  return PREFIX + toBase64Url(utf8Encode(JSON.stringify(payload)));
}

const ANCHORS: readonly Anchor[] = ['morning', 'daytime', 'evening', 'anytime'];
const CADENCES: readonly Cadence[] = ['daily', 'weekly', 'monthly', 'once'];

function clampMinutes(v: unknown, fallback: number): number {
  return typeof v === 'number' && Number.isFinite(v) ? Math.min(1439, Math.max(0, Math.round(v))) : fallback;
}

/** Parses and validates a share code. Throws a friendly Error when it can't. */
export function decodeShareCode(raw: string): SharePayload {
  const code = raw.trim().replace(/\s+/g, '');
  if (!code.startsWith(PREFIX)) throw new Error("That code doesn't look like a MochiNook code. It should start with MN1-.");
  let data: unknown;
  try {
    data = JSON.parse(utf8Decode(fromBase64Url(code.slice(PREFIX.length))));
  } catch {
    throw new Error('Part of that code seems to be missing. Could you copy it again?');
  }
  if (typeof data !== 'object' || data === null || (data as { v?: unknown }).v !== 1) {
    throw new Error('That code is from a different version of MochiNook.');
  }
  const rawQuests = (data as { quests?: unknown }).quests;
  if (!Array.isArray(rawQuests)) throw new Error('That code has no routine inside it.');

  const quests: SharedQuest[] = [];
  for (const q of rawQuests.slice(0, 80)) {
    if (typeof q !== 'object' || q === null) continue;
    const r = q as Record<string, unknown>;
    const anchor = ANCHORS.includes(r.anchor as Anchor) ? (r.anchor as Anchor) : 'anytime';
    const cadence = CADENCES.includes(r.cadence as Cadence) ? (r.cadence as Cadence) : undefined;
    if (typeof r.id === 'string' && r.id.length > 0 && r.id.length < 64) {
      quests.push({ id: r.id, anchor });
    } else if (typeof r.title === 'string' && Array.isArray(r.steps)) {
      const steps = r.steps.filter((s): s is string => typeof s === 'string' && s.trim().length > 0).map((s) => s.slice(0, 200)).slice(0, 12);
      if (steps.length === 0) continue;
      quests.push({
        id: null,
        title: r.title.slice(0, 80),
        emoji: typeof r.emoji === 'string' ? r.emoji.slice(0, 8) : '✨',
        anchor,
        cadence: cadence ?? 'daily',
        steps,
      });
    }
  }
  if (quests.length === 0) throw new Error('That code has no routine inside it.');

  const a = (data as { anchors?: Record<string, unknown> }).anchors;
  const payload: SharePayload = { v: 1, quests };
  if (a && typeof a === 'object') {
    const kind = a.blockKind === 'school' || a.blockKind === 'work' || a.blockKind === 'none' ? a.blockKind : 'none';
    payload.anchors = {
      wake: clampMinutes(a.wake, 7 * 60),
      blockKind: kind,
      blockStart: clampMinutes(a.blockStart, 9 * 60),
      blockEnd: clampMinutes(a.blockEnd, 15 * 60),
      bed: clampMinutes(a.bed, 22 * 60),
    };
  }
  return payload;
}

// ---------- friend race result codes ----------

const RACE_PREFIX = 'MNR1-';

export interface RaceResult {
  v: 1;
  /** The pet's name (never the person's), so no personal info travels in the code. */
  pet: string;
  steps: number;
  minutes: number;
  day: string;
}

export function encodeRaceResult(r: RaceResult): string {
  return RACE_PREFIX + toBase64Url(utf8Encode(JSON.stringify(r)));
}

export function decodeRaceResult(raw: string): RaceResult {
  const code = raw.trim().replace(/\s+/g, '');
  if (!code.startsWith(RACE_PREFIX)) throw new Error("That doesn't look like a race code. It should start with MNR1-.");
  let data: unknown;
  try {
    data = JSON.parse(utf8Decode(fromBase64Url(code.slice(RACE_PREFIX.length))));
  } catch {
    throw new Error('Part of that race code seems to be missing. Could you copy it again?');
  }
  const d = data as Partial<RaceResult>;
  if (d.v !== 1 || typeof d.steps !== 'number' || typeof d.pet !== 'string') throw new Error('That race code is from a different version of MochiNook.');
  return {
    v: 1,
    pet: d.pet.replace(/[^\p{L}\p{N} '-]/gu, '').slice(0, 20) || 'A friend',
    steps: Math.max(0, Math.min(500, Math.round(d.steps))),
    minutes: typeof d.minutes === 'number' ? Math.max(1, Math.min(60, Math.round(d.minutes))) : 15,
    day: typeof d.day === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d.day) ? d.day : '',
  };
}
