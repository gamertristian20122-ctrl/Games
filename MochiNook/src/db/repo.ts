import type { SQLiteDatabase } from 'expo-sqlite';
import { cosmeticKey, seasonalRewards, type CosmeticKind, type SeasonalReward } from '../data/cosmetics';
import { findShopItem } from '../data/shop';
import { weekDays, type Season } from '../lib/season';
import { LIBRARY } from './schema';
import { daysBetween } from '../lib/time';
import type {
  Anchor,
  Anchors,
  Cadence,
  Pet,
  QuestRow,
  QuestWithProgress,
  Settings,
  SharePayload,
  SharedQuest,
  StepRow,
  StepWithState,
} from '../lib/types';

// ---------- settings ----------

export const DEFAULT_ANCHORS: Anchors = {
  wake: 7 * 60,
  blockKind: 'school',
  blockStart: 8 * 60 + 30,
  blockEnd: 15 * 60,
  bed: 22 * 60,
};

export const DEFAULT_SETTINGS: Settings = {
  onboarded: false,
  brainProfiles: [],
  energy: 'medium',
  anchors: DEFAULT_ANCHORS,
  calmMode: false,
  sounds: true,
  haptics: true,
  reminders: true,
  theme: 'system',
  devUnlocked: false,
  devOverride: 'auto',
  mockPro: false,
  lastOpenDay: null,
  tipsGiven: 0,
  lastPatAt: 0,
  lastSnackDay: null,
  lastTuckDay: null,
};

type SettingKey = keyof Settings;

function serialize(value: Settings[SettingKey]): string {
  return JSON.stringify(value);
}

export async function getSettings(db: SQLiteDatabase): Promise<Settings> {
  const rows = await db.getAllAsync<{ key: string; value: string }>('SELECT key, value FROM settings');
  const merged: Settings = { ...DEFAULT_SETTINGS, anchors: { ...DEFAULT_ANCHORS } };
  const target = merged as unknown as Record<string, unknown>;
  for (const { key, value } of rows) {
    if (!(key in DEFAULT_SETTINGS)) continue;
    try {
      const parsed: unknown = JSON.parse(value);
      const fallback = (DEFAULT_SETTINGS as unknown as Record<string, unknown>)[key];
      if (fallback === null || typeof parsed === typeof fallback) target[key] = parsed;
    } catch {
      // Ignore a corrupted value and keep the default.
    }
  }
  merged.anchors = { ...DEFAULT_ANCHORS, ...merged.anchors };
  merged.brainProfiles = Array.isArray(merged.brainProfiles) ? merged.brainProfiles.filter((p) => typeof p === 'string') : [];
  return merged;
}

export async function saveSettings(db: SQLiteDatabase, patch: Partial<Settings>): Promise<void> {
  const entries = Object.entries(patch) as [SettingKey, Settings[SettingKey]][];
  if (entries.length === 0) return;
  await db.withTransactionAsync(async () => {
    for (const [key, value] of entries) {
      await db.runAsync(
        'INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        key,
        serialize(value),
      );
    }
  });
}

// ---------- pet ----------

export async function getPet(db: SQLiteDatabase): Promise<Pet> {
  const row = await db.getFirstAsync<Pet>('SELECT name, xp, affection, color, hat, scarf, room, pebbles FROM pet WHERE id = 1');
  return row ?? { name: 'Mochi', xp: 0, affection: 0, color: 'cream', hat: 'none', scarf: 'none', room: 'sunny', pebbles: 0 };
}

export async function updatePet(db: SQLiteDatabase, patch: Partial<Omit<Pet, 'xp' | 'affection' | 'pebbles'>>): Promise<void> {
  const allowed = ['name', 'color', 'hat', 'scarf', 'room'] as const;
  for (const key of allowed) {
    const value = patch[key];
    if (typeof value === 'string') {
      await db.runAsync(`UPDATE pet SET ${key} = ? WHERE id = 1`, value);
    }
  }
}

/** XP, affection and Pebbles only ever go up from progress. */
export async function addProgress(
  db: SQLiteDatabase,
  xp: number,
  affection: number,
  pebbles: number,
): Promise<{ before: number; after: number }> {
  const before = (await getPet(db)).xp;
  await db.runAsync(
    'UPDATE pet SET xp = xp + ?, affection = affection + ?, pebbles = pebbles + ? WHERE id = 1',
    Math.max(0, xp), Math.max(0, affection), Math.max(0, pebbles),
  );
  return { before, after: before + Math.max(0, xp) };
}

// ---------- Pebble shop ----------

export interface OwnedItem {
  item_id: string;
  placed: number;
}

export async function getOwnedItems(db: SQLiteDatabase): Promise<OwnedItem[]> {
  return db.getAllAsync<OwnedItem>('SELECT item_id, placed FROM owned_items ORDER BY acquired_at');
}

export type BuyResult = { ok: true; kind: 'decor' | 'treat' } | { ok: false; reason: 'unknown' | 'owned' | 'pebbles' };

/** Spends Pebbles. Decor is kept (and shown in the room); treats are enjoyed right away. */
export async function buyShopItem(db: SQLiteDatabase, itemId: string): Promise<BuyResult> {
  const item = findShopItem(itemId);
  if (!item) return { ok: false, reason: 'unknown' };
  let result: BuyResult = { ok: false, reason: 'pebbles' };
  await db.withTransactionAsync(async () => {
    if (item.kind === 'decor') {
      const owned = await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM owned_items WHERE item_id = ?', itemId);
      if ((owned?.n ?? 0) > 0) {
        result = { ok: false, reason: 'owned' };
        return;
      }
    }
    const spent = await db.runAsync('UPDATE pet SET pebbles = pebbles - ? WHERE id = 1 AND pebbles >= ?', item.price, item.price);
    if (spent.changes === 0) {
      result = { ok: false, reason: 'pebbles' };
      return;
    }
    if (item.kind === 'decor') {
      await db.runAsync('INSERT INTO owned_items (item_id, placed, acquired_at) VALUES (?, 1, ?)', itemId, Date.now());
    } else {
      await db.runAsync('UPDATE pet SET affection = affection + 5 WHERE id = 1');
    }
    result = { ok: true, kind: item.kind };
  });
  return result;
}

export async function setItemPlaced(db: SQLiteDatabase, itemId: string, placed: boolean): Promise<void> {
  await db.runAsync('UPDATE owned_items SET placed = ? WHERE item_id = ?', placed ? 1 : 0, itemId);
}

// ---------- quests & routine ----------

export function periodFor(cadence: Cadence, today: string): string {
  return cadence === 'daily' ? today : 'open';
}

const QUEST_COLUMNS = 'q.id, q.title, q.emoji, q.category, q.anchor, q.cadence, q.essential, q.invite, q.source';

async function stepsWithState(db: SQLiteDatabase, quest: QuestRow, today: string): Promise<StepWithState[]> {
  const rows = await db.getAllAsync<StepRow & { done: number }>(
    `SELECT s.id, s.quest_id, s.position, s.text, s.timer_minutes, s.tiny,
            CASE WHEN c.step_id IS NULL THEN 0 ELSE 1 END AS done
       FROM quest_steps s
       LEFT JOIN step_completions c ON c.step_id = s.id AND c.period = ?
      WHERE s.quest_id = ?
      ORDER BY s.position, s.id`,
    periodFor(quest.cadence, today),
    quest.id,
  );
  return rows.map((r) => ({ ...r, done: r.done === 1 }));
}

async function lastCompletion(db: SQLiteDatabase, questId: string): Promise<{ day: string; completed_at: number } | null> {
  return db.getFirstAsync<{ day: string; completed_at: number }>(
    'SELECT day, completed_at FROM quest_completions WHERE quest_id = ? ORDER BY completed_at DESC LIMIT 1',
    questId,
  );
}

async function lastCompletionDay(db: SQLiteDatabase, questId: string): Promise<string | null> {
  return (await lastCompletion(db, questId))?.day ?? null;
}

async function withProgress(db: SQLiteDatabase, quest: QuestRow, inRoutine: boolean, today: string): Promise<QuestWithProgress> {
  const last = await lastCompletion(db, quest.id);
  const completedToday = last?.day === today;
  if (quest.cadence !== 'daily' && last && !completedToday) {
    // A new round of a weekly/monthly quest: let go of the previous round's checkmarks.
    await resetOpenRun(db, quest.id, last.completed_at);
  }
  let steps = await stepsWithState(db, quest, today);
  if (quest.cadence !== 'daily' && completedToday) {
    steps = steps.map((s) => ({ ...s, done: true }));
  }
  return {
    ...quest,
    inRoutine,
    steps,
    doneCount: steps.filter((s) => s.done).length,
    completedToday,
  };
}

/** Whether a routine quest belongs on today's list. Missed days are never "overdue"; they just wait. */
export function isDue(cadence: Cadence, lastDone: string | null, today: string): boolean {
  if (lastDone === null || lastDone === today) return true;
  const gap = daysBetween(lastDone, today);
  switch (cadence) {
    case 'daily':
      return true;
    case 'weekly':
      return gap >= 7;
    case 'monthly':
      return gap >= 30;
    case 'once':
      return false;
  }
}

export async function getQuest(db: SQLiteDatabase, id: string, today: string): Promise<QuestWithProgress | null> {
  const row = await db.getFirstAsync<QuestRow & { in_routine: number }>(
    `SELECT ${QUEST_COLUMNS}, CASE WHEN r.quest_id IS NULL THEN 0 ELSE 1 END AS in_routine
       FROM quests q LEFT JOIN routine r ON r.quest_id = q.id WHERE q.id = ?`,
    id,
  );
  if (!row) return null;
  const { in_routine, ...quest } = row;
  return withProgress(db, quest, in_routine === 1, today);
}

const ANCHOR_ORDER: Record<Anchor, number> = { morning: 0, daytime: 1, evening: 2, anytime: 3 };

export async function getTodayQuests(db: SQLiteDatabase, today: string): Promise<QuestWithProgress[]> {
  const rows = await db.getAllAsync<QuestRow & { routine_anchor: Anchor; position: number }>(
    `SELECT ${QUEST_COLUMNS}, r.anchor AS routine_anchor, r.position
       FROM routine r JOIN quests q ON q.id = r.quest_id
      ORDER BY r.position`,
  );
  const result: QuestWithProgress[] = [];
  for (const { routine_anchor, position: _position, ...quest } of rows) {
    const last = await lastCompletionDay(db, quest.id);
    if (!isDue(quest.cadence, last, today)) continue;
    result.push(await withProgress(db, { ...quest, anchor: routine_anchor }, true, today));
  }
  return result.sort((a, b) => ANCHOR_ORDER[a.anchor] - ANCHOR_ORDER[b.anchor]);
}

export async function getAllQuests(db: SQLiteDatabase): Promise<(QuestRow & { inRoutine: boolean; stepCount: number })[]> {
  const rows = await db.getAllAsync<QuestRow & { in_routine: number; step_count: number }>(
    `SELECT ${QUEST_COLUMNS},
            CASE WHEN r.quest_id IS NULL THEN 0 ELSE 1 END AS in_routine,
            (SELECT COUNT(*) FROM quest_steps s WHERE s.quest_id = q.id) AS step_count
       FROM quests q LEFT JOIN routine r ON r.quest_id = q.id
      ORDER BY q.source = 'library', q.created_at DESC, q.title`,
  );
  return rows.map(({ in_routine, step_count, ...q }) => ({ ...q, inRoutine: in_routine === 1, stepCount: step_count }));
}

export async function setRoutine(db: SQLiteDatabase, questIds: readonly string[]): Promise<void> {
  const now = Date.now();
  await db.withTransactionAsync(async () => {
    await db.runAsync('DELETE FROM routine');
    let position = 0;
    for (const id of questIds) {
      const q = await db.getFirstAsync<{ anchor: Anchor }>('SELECT anchor FROM quests WHERE id = ?', id);
      if (!q) continue;
      await db.runAsync('INSERT INTO routine (quest_id, anchor, position, added_at) VALUES (?, ?, ?, ?)', id, q.anchor, position++, now);
    }
  });
}

export async function addToRoutine(db: SQLiteDatabase, questId: string, anchor?: Anchor): Promise<void> {
  const q = await db.getFirstAsync<{ anchor: Anchor }>('SELECT anchor FROM quests WHERE id = ?', questId);
  if (!q) return;
  const max = await db.getFirstAsync<{ m: number | null }>('SELECT MAX(position) AS m FROM routine');
  await db.runAsync(
    'INSERT OR IGNORE INTO routine (quest_id, anchor, position, added_at) VALUES (?, ?, ?, ?)',
    questId,
    anchor ?? q.anchor,
    (max?.m ?? -1) + 1,
    Date.now(),
  );
}

export async function removeFromRoutine(db: SQLiteDatabase, questId: string): Promise<void> {
  await db.runAsync('DELETE FROM routine WHERE quest_id = ?', questId);
}

// ---------- steps ----------

export interface CompleteResult {
  questCompleted: boolean;
}

export async function completeStep(
  db: SQLiteDatabase,
  quest: Pick<QuestRow, 'id' | 'cadence'>,
  stepId: number,
  today: string,
  notificationId: string | null,
): Promise<CompleteResult> {
  const period = periodFor(quest.cadence, today);
  let questCompleted = false;
  await db.withTransactionAsync(async () => {
    await db.runAsync(
      'INSERT OR IGNORE INTO step_completions (step_id, period, completed_at, notification_id) VALUES (?, ?, ?, ?)',
      stepId, period, Date.now(), notificationId,
    );
    const counts = await db.getFirstAsync<{ total: number; done: number }>(
      `SELECT COUNT(*) AS total,
              SUM(CASE WHEN c.step_id IS NULL THEN 0 ELSE 1 END) AS done
         FROM quest_steps s LEFT JOIN step_completions c ON c.step_id = s.id AND c.period = ?
        WHERE s.quest_id = ?`,
      period, quest.id,
    );
    if (counts && counts.total > 0 && counts.done >= counts.total) {
      const already = await db.getFirstAsync<{ n: number }>(
        'SELECT COUNT(*) AS n FROM quest_completions WHERE quest_id = ? AND day = ?', quest.id, today,
      );
      if ((already?.n ?? 0) === 0) {
        await db.runAsync('INSERT INTO quest_completions (quest_id, day, completed_at) VALUES (?, ?, ?)', quest.id, today, Date.now());
        questCompleted = true;
      }
    }
  });
  return { questCompleted };
}

/** Un-checks a step. Returns the timer notification id to cancel, if any. */
export async function uncompleteStep(
  db: SQLiteDatabase,
  quest: Pick<QuestRow, 'id' | 'cadence'>,
  stepId: number,
  today: string,
): Promise<string | null> {
  const period = periodFor(quest.cadence, today);
  const row = await db.getFirstAsync<{ notification_id: string | null }>(
    'SELECT notification_id FROM step_completions WHERE step_id = ? AND period = ?', stepId, period,
  );
  await db.withTransactionAsync(async () => {
    await db.runAsync('DELETE FROM step_completions WHERE step_id = ? AND period = ?', stepId, period);
    await db.runAsync('DELETE FROM quest_completions WHERE quest_id = ? AND day = ?', quest.id, today);
  });
  return row?.notification_id ?? null;
}

/** For weekly/monthly/once quests: clears checkmarks from a finished round so the next round starts fresh. */
async function resetOpenRun(db: SQLiteDatabase, questId: string, upTo: number): Promise<void> {
  await db.runAsync(
    "DELETE FROM step_completions WHERE period = 'open' AND completed_at <= ? AND step_id IN (SELECT id FROM quest_steps WHERE quest_id = ?)",
    upTo,
    questId,
  );
}

/** Replaces one step with several smaller ones, in place. */
export async function replaceStepWithSmaller(db: SQLiteDatabase, step: StepRow, smaller: readonly string[]): Promise<void> {
  const cleaned = smaller.map((s) => s.trim()).filter((s) => s.length > 0).slice(0, 8);
  if (cleaned.length === 0) return;
  await db.withTransactionAsync(async () => {
    const steps = await db.getAllAsync<{ id: number }>(
      'SELECT id FROM quest_steps WHERE quest_id = ? ORDER BY position, id', step.quest_id,
    );
    await db.runAsync('DELETE FROM quest_steps WHERE id = ?', step.id);
    const newIds: number[] = [];
    for (const [i, text] of cleaned.entries()) {
      const isLast = i === cleaned.length - 1;
      const res = await db.runAsync(
        'INSERT INTO quest_steps (quest_id, position, text, timer_minutes, tiny) VALUES (?, 0, ?, ?, NULL)',
        step.quest_id, text, isLast ? step.timer_minutes : null,
      );
      newIds.push(res.lastInsertRowId);
    }
    const ordered: number[] = [];
    for (const s of steps) {
      if (s.id === step.id) ordered.push(...newIds);
      else ordered.push(s.id);
    }
    for (const [position, id] of ordered.entries()) {
      await db.runAsync('UPDATE quest_steps SET position = ? WHERE id = ?', position, id);
    }
  });
}

export async function deleteStep(db: SQLiteDatabase, stepId: number): Promise<void> {
  await db.runAsync('DELETE FROM quest_steps WHERE id = ?', stepId);
}

export async function nextStepText(db: SQLiteDatabase, questId: string, afterPosition: number): Promise<string | null> {
  const row = await db.getFirstAsync<{ text: string }>(
    'SELECT text FROM quest_steps WHERE quest_id = ? AND position > ? ORDER BY position LIMIT 1', questId, afterPosition,
  );
  return row?.text ?? null;
}

// ---------- custom quests ----------

export interface NewQuest {
  title: string;
  emoji: string;
  anchor: Anchor;
  cadence: Cadence;
  invite: string;
  steps: readonly string[];
  source: 'custom' | 'shared';
}

function makeId(prefix: string): string {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}

export async function createQuest(db: SQLiteDatabase, q: NewQuest, addToRoutineToo = true): Promise<string> {
  const id = makeId(q.source);
  const steps = q.steps.map((s) => s.trim()).filter((s) => s.length > 0).slice(0, 12);
  await db.withTransactionAsync(async () => {
    await db.runAsync(
      `INSERT INTO quests (id, title, emoji, category, anchor, cadence, essential, invite, source, created_at)
       VALUES (?, ?, ?, 'home', ?, ?, 0, ?, ?, ?)`,
      id, q.title.trim().slice(0, 80) || 'My quest', q.emoji || '✨', q.anchor, q.cadence, q.invite, q.source, Date.now(),
    );
    for (const [position, text] of steps.entries()) {
      await db.runAsync('INSERT INTO quest_steps (quest_id, position, text) VALUES (?, ?, ?)', id, position, text.slice(0, 200));
    }
  });
  if (addToRoutineToo) await addToRoutine(db, id, q.anchor);
  return id;
}

export async function deleteQuest(db: SQLiteDatabase, questId: string): Promise<void> {
  await db.runAsync("DELETE FROM quests WHERE id = ? AND source != 'library'", questId);
}

// ---------- caregiver share ----------

export async function exportRoutine(db: SQLiteDatabase): Promise<SharedQuest[]> {
  const rows = await db.getAllAsync<QuestRow & { routine_anchor: Anchor }>(
    `SELECT ${QUEST_COLUMNS}, r.anchor AS routine_anchor FROM routine r JOIN quests q ON q.id = r.quest_id ORDER BY r.position`,
  );
  const out: SharedQuest[] = [];
  for (const { routine_anchor, ...q } of rows) {
    if (q.source === 'library') {
      out.push({ id: q.id, anchor: routine_anchor });
    } else {
      const steps = await db.getAllAsync<{ text: string }>(
        'SELECT text FROM quest_steps WHERE quest_id = ? ORDER BY position', q.id,
      );
      out.push({ id: null, title: q.title, emoji: q.emoji, anchor: routine_anchor, cadence: q.cadence, steps: steps.map((s) => s.text) });
    }
  }
  return out;
}

/** Merges a shared routine into this one. Returns how many quests were added. */
export async function importShared(db: SQLiteDatabase, payload: SharePayload): Promise<number> {
  const knownIds = new Set(LIBRARY.map((q) => q.id));
  let added = 0;
  for (const q of payload.quests) {
    if (q.id !== null) {
      if (!knownIds.has(q.id)) continue;
      const exists = await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM routine WHERE quest_id = ?', q.id);
      if ((exists?.n ?? 0) > 0) continue;
      await addToRoutine(db, q.id, q.anchor);
      added += 1;
    } else if (q.title && q.steps && q.steps.length > 0) {
      await createQuest(db, {
        title: q.title,
        emoji: q.emoji ?? '✨',
        anchor: q.anchor,
        cadence: q.cadence ?? 'daily',
        invite: 'A quest someone who cares about you shared. Want to try it together?',
        steps: q.steps,
        source: 'shared',
      });
      added += 1;
    }
  }
  return added;
}

// ---------- delete all data ----------

/** Erases everything MochiNook stored. Run migrateDatabase afterwards to re-seed the library. */
export async function deleteAllData(db: SQLiteDatabase): Promise<void> {
  await db.withTransactionAsync(async () => {
    for (const table of [
      'step_completions', 'quest_completions', 'routine', 'quest_steps', 'quests', 'owned_items', 'pet', 'settings',
      'focus_sessions', 'checkins', 'races', 'owned_cosmetics',
    ]) {
      await db.runAsync(`DELETE FROM ${table}`);
    }
  });
}

// ---------- focus timer (body doubling) ----------

export async function startFocus(db: SQLiteDatabase, minutes: number, day: string): Promise<number> {
  const r = await db.runAsync('INSERT INTO focus_sessions (day, started_at, minutes, completed) VALUES (?, ?, ?, 0)', day, Date.now(), minutes);
  return r.lastInsertRowId;
}

export async function finishFocus(db: SQLiteDatabase, id: number, completed: boolean): Promise<void> {
  await db.runAsync('UPDATE focus_sessions SET completed = ? WHERE id = ?', completed ? 1 : 0, id);
}

// ---------- daily check-in ----------

export interface Checkin {
  day: string;
  mood: number;
  energy: string;
}

export async function saveCheckin(db: SQLiteDatabase, day: string, mood: number, energy: string): Promise<void> {
  await db.runAsync(
    `INSERT INTO checkins (day, mood, energy, created_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(day) DO UPDATE SET mood = excluded.mood, energy = excluded.energy`,
    day, Math.max(1, Math.min(5, Math.round(mood))), energy, Date.now(),
  );
}

export async function getCheckins(db: SQLiteDatabase, fromDay: string, toDay: string): Promise<Checkin[]> {
  return db.getAllAsync<Checkin>('SELECT day, mood, energy FROM checkins WHERE day >= ? AND day <= ? ORDER BY day', fromDay, toDay);
}

// ---------- friend race (15 minutes, async via codes) ----------

export async function startRace(db: SQLiteDatabase, minutes: number, day: string): Promise<{ id: number; startedAt: number }> {
  const startedAt = Date.now();
  const r = await db.runAsync('INSERT INTO races (day, started_at, minutes) VALUES (?, ?, ?)', day, startedAt, minutes);
  return { id: r.lastInsertRowId, startedAt };
}

/** Counts the micro-steps checked off during the race window and records the result. */
export async function finishRace(db: SQLiteDatabase, id: number, now: number = Date.now()): Promise<number> {
  const race = await db.getFirstAsync<{ started_at: number; minutes: number }>('SELECT started_at, minutes FROM races WHERE id = ?', id);
  if (!race) return 0;
  const end = Math.min(now, race.started_at + race.minutes * 60_000);
  const row = await db.getFirstAsync<{ n: number }>(
    'SELECT COUNT(*) AS n FROM step_completions WHERE completed_at >= ? AND completed_at <= ?',
    race.started_at, end,
  );
  const steps = row?.n ?? 0;
  await db.runAsync('UPDATE races SET steps = ? WHERE id = ?', steps, id);
  return steps;
}

export async function getOpenRace(db: SQLiteDatabase): Promise<{ id: number; started_at: number; minutes: number } | null> {
  return db.getFirstAsync<{ id: number; started_at: number; minutes: number }>(
    'SELECT id, started_at, minutes FROM races WHERE steps IS NULL ORDER BY id DESC LIMIT 1',
  );
}

// ---------- weekly Mochi Sprint ----------

export interface SprintStats {
  stars: number;
  quests: number;
  focus: number;
  races: number;
  /** Stars per day of the week, Monday first. */
  perDay: number[];
}

/** Sprint Stars: 1 per finished quest, focus session, or friend race this week. Nothing is ever taken away. */
export async function getSprintStats(db: SQLiteDatabase, start: string): Promise<SprintStats> {
  const days = weekDays(start);
  const end = days[6]!;
  const perDay = days.map(() => 0);
  const bump = (rows: { day: string; n: number }[]) => {
    for (const r of rows) {
      const i = days.indexOf(r.day);
      if (i >= 0) perDay[i] = (perDay[i] ?? 0) + r.n;
    }
  };
  const q = await db.getAllAsync<{ day: string; n: number }>(
    'SELECT day, COUNT(*) AS n FROM quest_completions WHERE day >= ? AND day <= ? GROUP BY day', start, end,
  );
  const f = await db.getAllAsync<{ day: string; n: number }>(
    'SELECT day, COUNT(*) AS n FROM focus_sessions WHERE completed = 1 AND day >= ? AND day <= ? GROUP BY day', start, end,
  );
  const r = await db.getAllAsync<{ day: string; n: number }>(
    'SELECT day, COUNT(*) AS n FROM races WHERE steps IS NOT NULL AND day >= ? AND day <= ? GROUP BY day', start, end,
  );
  bump(q);
  bump(f);
  bump(r);
  const sum = (rows: { n: number }[]) => rows.reduce((a, b) => a + b.n, 0);
  return { stars: perDay.reduce((a, b) => a + b, 0), quests: sum(q), focus: sum(f), races: sum(r), perDay };
}

export async function getOwnedCosmetics(db: SQLiteDatabase): Promise<string[]> {
  const rows = await db.getAllAsync<{ cosmetic_key: string }>('SELECT cosmetic_key FROM owned_cosmetics');
  return rows.map((r) => r.cosmetic_key);
}

export async function grantCosmetic(db: SQLiteDatabase, kind: CosmeticKind, id: string, source: string): Promise<boolean> {
  const r = await db.runAsync(
    'INSERT OR IGNORE INTO owned_cosmetics (cosmetic_key, source, acquired_at) VALUES (?, ?, ?)',
    cosmeticKey(kind, id), source, Date.now(),
  );
  return r.changes > 0;
}

/** Grants this season's rewards for every tier reached. Returns the newly earned ones. */
export async function syncSeasonRewards(
  db: SQLiteDatabase,
  season: Season,
  stars: number,
  tiers: readonly [number, number, number],
): Promise<SeasonalReward[]> {
  const earned: SeasonalReward[] = [];
  for (const reward of seasonalRewards(season)) {
    if (stars >= tiers[reward.tier - 1]!) {
      if (await grantCosmetic(db, reward.kind, reward.id, `sprint-${season}`)) earned.push(reward);
    }
  }
  return earned;
}
