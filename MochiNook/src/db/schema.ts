import type { SQLiteDatabase } from 'expo-sqlite';
import libraryJson from '../data/quests.json';
import type { LibraryQuest } from '../lib/types';

export const DATABASE_NAME = 'mochinook.db';
export const LIBRARY: readonly LibraryQuest[] = libraryJson as LibraryQuest[];

/** Bump when quests are added to quests.json; new ones are inserted, user edits are kept. */
const LIBRARY_VERSION = 1;
const SCHEMA_VERSION = 1;

const SCHEMA_V1 = `
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS pet (
  id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1),
  name TEXT NOT NULL,
  xp INTEGER NOT NULL DEFAULT 0,
  affection INTEGER NOT NULL DEFAULT 0,
  color TEXT NOT NULL DEFAULT 'cream',
  hat TEXT NOT NULL DEFAULT 'none',
  scarf TEXT NOT NULL DEFAULT 'none',
  room TEXT NOT NULL DEFAULT 'sunny'
);
CREATE TABLE IF NOT EXISTS quests (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  emoji TEXT NOT NULL,
  category TEXT NOT NULL,
  anchor TEXT NOT NULL,
  cadence TEXT NOT NULL,
  essential INTEGER NOT NULL DEFAULT 0,
  invite TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS quest_steps (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quest_id TEXT NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  text TEXT NOT NULL,
  timer_minutes INTEGER,
  tiny TEXT
);
CREATE INDEX IF NOT EXISTS idx_steps_quest ON quest_steps (quest_id, position);
CREATE TABLE IF NOT EXISTS routine (
  quest_id TEXT PRIMARY KEY NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
  anchor TEXT NOT NULL,
  position INTEGER NOT NULL,
  added_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS step_completions (
  step_id INTEGER NOT NULL REFERENCES quest_steps(id) ON DELETE CASCADE,
  period TEXT NOT NULL,
  completed_at INTEGER NOT NULL,
  notification_id TEXT,
  PRIMARY KEY (step_id, period)
);
CREATE TABLE IF NOT EXISTS quest_completions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  quest_id TEXT NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
  day TEXT NOT NULL,
  completed_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_quest_completions ON quest_completions (quest_id, day);
`;

export async function seedLibrary(db: SQLiteDatabase, library: readonly LibraryQuest[] = LIBRARY): Promise<void> {
  const now = Date.now();
  await db.withTransactionAsync(async () => {
    for (const q of library) {
      const res = await db.runAsync(
        `INSERT OR IGNORE INTO quests (id, title, emoji, category, anchor, cadence, essential, invite, source, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'library', ?)`,
        q.id, q.title, q.emoji, q.category, q.anchor, q.cadence, q.essential ? 1 : 0, q.invite, now,
      );
      if (res.changes === 0) continue;
      let position = 0;
      for (const s of q.steps) {
        await db.runAsync(
          'INSERT INTO quest_steps (quest_id, position, text, timer_minutes, tiny) VALUES (?, ?, ?, ?, ?)',
          q.id, position++, s.text, s.timerMinutes ?? null, s.tiny ? JSON.stringify(s.tiny) : null,
        );
      }
    }
  });
}

/** Runs on every launch (SQLiteProvider onInit). Safe to run repeatedly. */
export async function migrateDatabase(db: SQLiteDatabase): Promise<void> {
  await db.execAsync('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
  const row = await db.getFirstAsync<{ user_version: number }>('PRAGMA user_version');
  const current = row?.user_version ?? 0;
  if (current < 1) {
    await db.execAsync(SCHEMA_V1);
    await db.execAsync(`PRAGMA user_version = ${SCHEMA_VERSION}`);
  }
  const lib = await db.getFirstAsync<{ value: string }>("SELECT value FROM settings WHERE key = 'library_version'");
  if (Number(lib?.value ?? 0) < LIBRARY_VERSION) {
    await seedLibrary(db);
    await db.runAsync(
      "INSERT INTO settings (key, value) VALUES ('library_version', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
      String(LIBRARY_VERSION),
    );
  }
  await db.runAsync("INSERT OR IGNORE INTO pet (id, name) VALUES (1, 'Mochi')");
}
