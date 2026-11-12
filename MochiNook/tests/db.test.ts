import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as repo from '../src/db/repo';
import { LIBRARY, migrateDatabase } from '../src/db/schema';
import { createTestDb } from './testDb';

async function freshDb() {
  const db = createTestDb();
  await migrateDatabase(db);
  return db;
}

test('migration seeds the library once and is safe to re-run', async () => {
  const db = await freshDb();
  await migrateDatabase(db);
  const q = await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM quests');
  assert.equal(q?.n, LIBRARY.length);
  const s = await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM quest_steps');
  assert.equal(s?.n, LIBRARY.reduce((sum, x) => sum + x.steps.length, 0));
  assert.equal((await repo.getPet(db)).name, 'Mochi');
});

test('settings round-trip and ignore corrupted values', async () => {
  const db = await freshDb();
  assert.equal((await repo.getSettings(db)).onboarded, false);
  await repo.saveSettings(db, { onboarded: true, calmMode: true, anchors: { ...repo.DEFAULT_ANCHORS, wake: 360 } });
  await db.runAsync("INSERT INTO settings (key, value) VALUES ('energy', 'not json')");
  const s = await repo.getSettings(db);
  assert.equal(s.onboarded, true);
  assert.equal(s.calmMode, true);
  assert.equal(s.anchors.wake, 360);
  assert.equal(s.energy, 'medium');
});

test('completing every step finishes a daily quest and awards XP', async () => {
  const db = await freshDb();
  await repo.setRoutine(db, ['morning-water', 'laundry']);
  const today = '2026-11-12';
  const quests = await repo.getTodayQuests(db, today);
  assert.deepEqual(quests.map((q) => q.id).sort(), ['laundry', 'morning-water']);
  const water = quests.find((q) => q.id === 'morning-water')!;
  let last = { questCompleted: false };
  for (const step of water.steps) last = await repo.completeStep(db, water, step.id, today, null);
  assert.equal(last.questCompleted, true);
  const again = await repo.getQuest(db, 'morning-water', today);
  assert.equal(again?.completedToday, true);
  assert.equal(again?.doneCount, water.steps.length);
  // Next day it is fresh again: no streak, no penalty.
  const tomorrow = await repo.getQuest(db, 'morning-water', '2026-11-13');
  assert.equal(tomorrow?.doneCount, 0);
  const xp = await repo.addProgress(db, 20, 2, 4);
  assert.deepEqual(xp, { before: 0, after: 20 });
  assert.equal((await repo.getPet(db)).pebbles, 4);
});

test('weekly quests keep progress across days, rest after finishing, and come back a week later', async () => {
  const db = await freshDb();
  await repo.setRoutine(db, ['laundry']);
  const laundry = (await repo.getQuest(db, 'laundry', '2026-11-10'))!;
  await repo.completeStep(db, laundry, laundry.steps[0]!.id, '2026-11-10', null);
  assert.equal((await repo.getQuest(db, 'laundry', '2026-11-11'))?.doneCount, 1, 'progress carries over to the next day');
  for (const s of laundry.steps.slice(1)) await repo.completeStep(db, laundry, s.id, '2026-11-11', null);
  assert.equal((await repo.getTodayQuests(db, '2026-11-11')).length, 1, 'shown as done today');
  assert.equal((await repo.getTodayQuests(db, '2026-11-13')).length, 0, 'resting mid-week');
  const nextWeek = await repo.getTodayQuests(db, '2026-11-18');
  assert.equal(nextWeek.length, 1);
  assert.equal(nextWeek[0]!.doneCount, 0, 'fresh checkmarks for the new round');
});

test('unchecking returns the timer notification id to cancel', async () => {
  const db = await freshDb();
  const laundry = (await repo.getQuest(db, 'laundry', '2026-11-12'))!;
  const washer = laundry.steps.find((s) => s.timer_minutes === 45)!;
  await repo.completeStep(db, laundry, washer.id, '2026-11-12', 'notif-123');
  assert.equal(await repo.uncompleteStep(db, laundry, washer.id, '2026-11-12'), 'notif-123');
  assert.equal((await repo.getQuest(db, 'laundry', '2026-11-12'))?.doneCount, 0);
});

test('breaking a step into smaller ones keeps order and the timer', async () => {
  const db = await freshDb();
  const laundry = (await repo.getQuest(db, 'laundry', '2026-11-12'))!;
  const washer = laundry.steps[1]!;
  await repo.replaceStepWithSmaller(db, washer, ['Put clothes in', 'Add one cap of detergent', 'Press start']);
  const after = (await repo.getQuest(db, 'laundry', '2026-11-12'))!;
  assert.deepEqual(after.steps.slice(0, 5).map((s) => s.text), [
    laundry.steps[0]!.text,
    'Put clothes in',
    'Add one cap of detergent',
    'Press start',
    laundry.steps[2]!.text,
  ]);
  assert.equal(after.steps[3]!.timer_minutes, 45);
  assert.equal(after.steps[1]!.timer_minutes, null);
  assert.deepEqual(after.steps.map((s) => s.position), after.steps.map((_, i) => i));
});

test('custom quests: create, route, delete; library quests cannot be deleted', async () => {
  const db = await freshDb();
  const id = await repo.createQuest(db, {
    title: 'Room glow-up',
    emoji: '🧹',
    anchor: 'evening',
    cadence: 'once',
    invite: 'Want to try?',
    steps: ['Grab a bag', '', '  Pick up 5 things  '],
    source: 'custom',
  });
  const q = (await repo.getQuest(db, id, '2026-11-12'))!;
  assert.equal(q.inRoutine, true);
  assert.deepEqual(q.steps.map((s) => s.text), ['Grab a bag', 'Pick up 5 things']);
  await repo.deleteQuest(db, 'laundry');
  assert.ok(await repo.getQuest(db, 'laundry', '2026-11-12'));
  await repo.deleteQuest(db, id);
  assert.equal(await repo.getQuest(db, id, '2026-11-12'), null);
});

test('caregiver export → import into a second phone', async () => {
  const parent = await freshDb();
  await repo.setRoutine(parent, ['morning-meds', 'dishes-reset']);
  await repo.createQuest(parent, { title: 'Feed Biscuit', emoji: '🐶', anchor: 'morning', cadence: 'daily', invite: 'x', steps: ['Scoop food', 'Fresh water'], source: 'custom' });
  const exported = await repo.exportRoutine(parent);
  assert.equal(exported.length, 3);

  const kid = await freshDb();
  await repo.setRoutine(kid, ['morning-meds']);
  const added = await repo.importShared(kid, { v: 1, quests: [...exported, { id: 'not-a-real-quest', anchor: 'anytime' }] });
  assert.equal(added, 2, 'skips duplicates and unknown ids');
  const titles = (await repo.getTodayQuests(kid, '2026-11-12')).map((q) => q.title).sort();
  assert.deepEqual(titles, ['Dishes & Kitchen Reset', 'Feed Biscuit', 'Meds & Vitamins']);
});

test('isDue never treats a missed day as overdue pressure', () => {
  assert.equal(repo.isDue('daily', '2026-01-01', '2026-11-12'), true);
  assert.equal(repo.isDue('weekly', '2026-11-10', '2026-11-12'), false);
  assert.equal(repo.isDue('weekly', '2026-11-05', '2026-11-12'), true);
  assert.equal(repo.isDue('monthly', '2026-10-20', '2026-11-12'), false);
  assert.equal(repo.isDue('once', '2026-11-01', '2026-11-12'), false);
  assert.equal(repo.isDue('once', null, '2026-11-12'), true);
});

test('the chosen pet name is saved and read back everywhere', async () => {
  const db = await freshDb();
  await repo.updatePet(db, { name: 'Pip' });
  assert.equal((await repo.getPet(db)).name, 'Pip');
  // Re-running migrations (every app launch) must never reset it.
  await migrateDatabase(db);
  assert.equal((await repo.getPet(db)).name, 'Pip');
});

test('Pebble shop: buy decor once, toggle it, treats are consumed, no debt', async () => {
  const db = await freshDb();
  assert.deepEqual(await repo.buyShopItem(db, 'fern'), { ok: false, reason: 'pebbles' });
  await repo.addProgress(db, 0, 0, 30);
  assert.deepEqual(await repo.buyShopItem(db, 'fern'), { ok: true, kind: 'decor' });
  assert.deepEqual(await repo.buyShopItem(db, 'fern'), { ok: false, reason: 'owned' });
  assert.equal((await repo.getPet(db)).pebbles, 20);
  assert.deepEqual((await repo.getOwnedItems(db)).map((o) => ({ ...o })), [{ item_id: 'fern', placed: 1 }]);
  await repo.setItemPlaced(db, 'fern', false);
  assert.equal((await repo.getOwnedItems(db))[0]!.placed, 0);
  const before = (await repo.getPet(db)).affection;
  assert.deepEqual(await repo.buyShopItem(db, 'mochi-treat'), { ok: true, kind: 'treat' });
  assert.deepEqual(await repo.buyShopItem(db, 'mochi-treat'), { ok: true, kind: 'treat' });
  const pet = await repo.getPet(db);
  assert.equal(pet.pebbles, 10);
  assert.equal(pet.affection, before + 10);
  assert.deepEqual(await repo.buyShopItem(db, 'beanbag'), { ok: false, reason: 'pebbles' });
  assert.equal((await repo.getPet(db)).pebbles, 10);
  assert.deepEqual(await repo.buyShopItem(db, 'not-real'), { ok: false, reason: 'unknown' });
});

test('upgrading a v1.0.0 database keeps progress and adds pebbles + micro-steps', async () => {
  const db = createTestDb();
  // Recreate exactly what v1.0.0 left on a phone: schema v1, library v1, no micro-steps on most steps.
  await db.execAsync(`
    CREATE TABLE settings (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
    CREATE TABLE pet (id INTEGER PRIMARY KEY NOT NULL CHECK (id = 1), name TEXT NOT NULL, xp INTEGER NOT NULL DEFAULT 0,
      affection INTEGER NOT NULL DEFAULT 0, color TEXT NOT NULL DEFAULT 'cream', hat TEXT NOT NULL DEFAULT 'none',
      scarf TEXT NOT NULL DEFAULT 'none', room TEXT NOT NULL DEFAULT 'sunny');
    CREATE TABLE quests (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, emoji TEXT NOT NULL, category TEXT NOT NULL,
      anchor TEXT NOT NULL, cadence TEXT NOT NULL, essential INTEGER NOT NULL DEFAULT 0, invite TEXT NOT NULL,
      source TEXT NOT NULL, created_at INTEGER NOT NULL);
    CREATE TABLE quest_steps (id INTEGER PRIMARY KEY AUTOINCREMENT, quest_id TEXT NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
      position INTEGER NOT NULL, text TEXT NOT NULL, timer_minutes INTEGER, tiny TEXT);
    CREATE TABLE routine (quest_id TEXT PRIMARY KEY NOT NULL, anchor TEXT NOT NULL, position INTEGER NOT NULL, added_at INTEGER NOT NULL);
    CREATE TABLE step_completions (step_id INTEGER NOT NULL, period TEXT NOT NULL, completed_at INTEGER NOT NULL, notification_id TEXT,
      PRIMARY KEY (step_id, period));
    CREATE TABLE quest_completions (id INTEGER PRIMARY KEY AUTOINCREMENT, quest_id TEXT NOT NULL, day TEXT NOT NULL, completed_at INTEGER NOT NULL);
    PRAGMA user_version = 1;
    INSERT INTO settings (key, value) VALUES ('library_version', '1');
    INSERT INTO pet (id, name, xp) VALUES (1, 'Pip', 77);
    INSERT INTO quests VALUES ('bedtime-teeth', 'Brush Teeth (Night)', '🌙', 'evening', 'evening', 'daily', 1, 'x', 'library', 0);
    INSERT INTO quest_steps (quest_id, position, text) VALUES ('bedtime-teeth', 3, 'Spit, rinse the brush, and put it back');
    INSERT INTO quest_steps (quest_id, position, text) VALUES ('bedtime-teeth', 0, 'Walk to the bathroom sink');
  `);
  await migrateDatabase(db);
  const pet = await repo.getPet(db);
  assert.equal(pet.name, 'Pip');
  assert.equal(pet.xp, 77);
  assert.equal(pet.pebbles, 0);
  const q = (await repo.getQuest(db, 'bedtime-teeth', '2026-11-12'))!;
  const spit = q.steps.find((s) => s.text.startsWith('Spit'))!;
  const walk = q.steps.find((s) => s.text.startsWith('Walk'))!;
  assert.ok(spit.tiny && JSON.parse(spit.tiny).length === 3, 'micro-steps backfilled');
  assert.equal(walk.tiny, null, 'single actions stay single');
  assert.equal((await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM quests'))?.n, LIBRARY.length, 'new quests added');
});

test('delete all my data erases everything and starts fresh', async () => {
  const db = await freshDb();
  await repo.updatePet(db, { name: 'Pip' });
  await repo.addProgress(db, 50, 5, 20);
  await repo.buyShopItem(db, 'fern');
  await repo.saveSettings(db, { onboarded: true, brainProfiles: ['adhd'] });
  await repo.createQuest(db, { title: 'Secret', emoji: '✨', anchor: 'anytime', cadence: 'once', invite: 'x', steps: ['a'], source: 'custom' });
  await repo.deleteAllData(db);
  await migrateDatabase(db);
  const pet = await repo.getPet(db);
  assert.deepEqual([pet.name, pet.xp, pet.pebbles], ['Mochi', 0, 0]);
  assert.equal((await repo.getSettings(db)).onboarded, false);
  assert.equal((await repo.getOwnedItems(db)).length, 0);
  assert.equal((await db.getFirstAsync<{ n: number }>("SELECT COUNT(*) AS n FROM quests WHERE source != 'library'"))?.n, 0);
  assert.equal((await db.getFirstAsync<{ n: number }>('SELECT COUNT(*) AS n FROM quests'))?.n, LIBRARY.length, 'library re-seeded');
});
