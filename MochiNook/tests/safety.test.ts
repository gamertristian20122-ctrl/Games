import assert from 'node:assert/strict';
import { test } from 'node:test';
import library from '../src/data/quests.json';
import { decodeRaceResult, encodeRaceResult } from '../src/lib/shareCode';
import { checkPetName, cleanPetName, isUnsafeName, safePetName } from '../src/lib/nameSafety';
import { normalizeSteps, registerTaskSplitter, splitTaskIntoSteps, type TaskSplitter } from '../src/lib/ai/taskSplitter';
import { PET_NAMES } from '../src/data/cosmetics';
import type { LibraryQuest } from '../src/lib/types';

const LIB = library as LibraryQuest[];

// ---------- name safety ----------

test('name filter: cozy and tricky-but-innocent names are allowed', () => {
  const fine = [
    ...PET_NAMES,
    'Dumpling', 'Peacock', 'Cassie', 'Bass', 'Classy', 'Grape', 'Scunthorpe', 'Shiitake', 'Butters', 'Cocker Spaniel',
    'Dickens', 'Assassin', 'Spicy', 'Raccoon', 'Cocoon', 'Hello Kitty', 'Therapist', 'Pebbles 2', 'Cumin', 'Sussex',
    'Analise', 'Zoë', 'Nazira', 'Heroine', 'Something', 'Thorny', 'Swanky', 'Torpedo', 'Moss', 'Hoot', 'Mochi-Bean', "D'Artagnan",
  ];
  for (const n of fine) assert.equal(isUnsafeName(n), false, `should allow "${n}"`);
});

test('name filter: profanity, slurs and sneaky spellings are blocked', () => {
  const bad = [
    'fuck', 'FUUUCK', 'f u c k', 'f.u.c.k', 'fück', 'f​uck', 'sh1t', '$hit', 'a55', 'asss', 'aaass', 'asshat', 'dickhead',
    'b1tch', 'phuck', 'n1gga', 'cunt', 'KYS', 'kill', 'stupid', 'Big Fuckface', 's3xy', 'r4pe', 'c0ck', 'p0rn', 'Hitler', 'wh0re', 'd i c k',
  ];
  for (const n of bad) assert.equal(isUnsafeName(n), true, `should block "${n}"`);
});

test('name filter: cleaning, empty names and gentle messages', () => {
  assert.equal(cleanPetName('  Mo​chi!!  🍡  '), 'Mochi');
  assert.equal(cleanPetName('A very very long name that keeps going').length <= 20, true);
  const empty = checkPetName('  !!! ');
  assert.equal(empty.ok, false);
  assert.equal(!empty.ok && empty.reason, 'empty');
  const unkind = checkPetName('sh1thead');
  assert.equal(unkind.ok, false);
  if (!unkind.ok) {
    assert.equal(unkind.reason, 'unkind');
    // Zero-shame copy: never scolds or repeats the word.
    assert.doesNotMatch(unkind.message, /bad|naughty|not allowed|inappropriate|sh/i);
  }
  assert.deepEqual(checkPetName(' Biscuit '), { ok: true, name: 'Biscuit' });
  assert.equal(safePetName('fuck'), 'Dumpling');
  assert.equal(safePetName('Noodle'), 'Noodle');
});

test('race codes: a friend’s pet name goes through the same filter', () => {
  const clean = decodeRaceResult(encodeRaceResult({ v: 1, pet: 'Noodle', steps: 4, minutes: 15, day: '2026-11-12' }));
  assert.equal(clean.pet, 'Noodle');
  const rude = decodeRaceResult(encodeRaceResult({ v: 1, pet: 'b1tch', steps: 4, minutes: 15, day: '2026-11-12' }));
  assert.equal(rude.pet, 'A friend');
});

// ---------- task splitter (future on-device model hook) ----------

test('normalizeSteps cleans numbering, bullets, duplicates and long lines', () => {
  const out = normalizeSteps(['1. open the laptop', '- Open the laptop', '  ', '2) find the essay doc', '• write one sentence', `${'x'.repeat(200)}`, 'extra', 'more']);
  assert.deepEqual(out.slice(0, 3), ['Open the laptop', 'Find the essay doc', 'Write one sentence']);
  assert.equal(out.length, 5);
  assert.ok(out[3].length <= 90 && out[3].endsWith('…'));
});

test('splitTaskIntoSteps: library match wins, template otherwise (no model)', async () => {
  registerTaskSplitter(null);
  const shower = await splitTaskIntoSteps('take a shower', LIB);
  assert.equal(shower.source, 'library');
  assert.ok(shower.steps.length >= 3 && shower.steps.length <= 5);
  const odd = await splitTaskIntoSteps('assemble my new desk', LIB);
  assert.equal(odd.source, 'template');
  assert.ok(odd.steps.length >= 3 && odd.steps.length <= 5);
});

test('splitTaskIntoSteps: a registered on-device splitter is used and normalized', async () => {
  const fake: TaskSplitter = {
    id: 'test-model',
    isReady: () => true,
    split: async () => ['1. Put the desk box on the floor', '2. Open the box', '3. Find the instruction sheet', '4. Lay out the screws', '5. Do step one only', '6. Celebrate'],
  };
  registerTaskSplitter(fake);
  try {
    const res = await splitTaskIntoSteps('assemble my new desk', LIB);
    assert.equal(res.source, 'model');
    assert.equal(res.steps.length, 5);
    assert.equal(res.steps[0], 'Put the desk box on the floor');
    // Curated library steps still beat the model.
    assert.equal((await splitTaskIntoSteps('take a shower', LIB)).source, 'library');
  } finally {
    registerTaskSplitter(null);
  }
});

test('splitTaskIntoSteps: slow, failing, unready or thin models fall back quietly', async () => {
  const cases: TaskSplitter[] = [
    { id: 'slow', isReady: () => true, split: (_t, { signal }) => new Promise((resolve) => signal.addEventListener('abort', () => resolve(['late']))) },
    { id: 'broken', isReady: () => true, split: async () => { throw new Error('model crashed'); } },
    { id: 'loading', isReady: async () => false, split: async () => ['a', 'b', 'c'] },
    { id: 'thin', isReady: () => true, split: async () => ['Just one step'] },
  ];
  try {
    for (const s of cases) {
      registerTaskSplitter(s);
      const res = await splitTaskIntoSteps('assemble my new desk', LIB, { timeoutMs: 50 });
      assert.equal(res.source, 'template', s.id);
      assert.ok(res.steps.length >= 3, s.id);
    }
  } finally {
    registerTaskSplitter(null);
  }
});
