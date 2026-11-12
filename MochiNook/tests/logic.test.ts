import assert from 'node:assert/strict';
import { test } from 'node:test';
import library from '../src/data/quests.json';
import { HATS, PET_COLORS, ROOMS, SCARVES } from '../src/data/cosmetics';
import { SHOP_ITEMS } from '../src/data/shop';
import { levelFromXp, xpForNextLevel } from '../src/lib/progression';
import { buildStarterRoutine } from '../src/lib/routineBuilder';
import { decodeShareCode, encodeShareCode } from '../src/lib/shareCode';
import { bestLibraryMatch, canMakeSmaller, genericSteps, smallerSteps, smartBreakdown, softenText } from '../src/lib/smartMatch';
import { currentAnchor, daysBetween, formatClock } from '../src/lib/time';
import type { LibraryQuest } from '../src/lib/types';

const LIB = library as LibraryQuest[];
const DEMANDING = /\b(must|have to|right now|immediately|asap)\b/i;

test('quest library: 40+ valid, unique, hyper-literal quests', () => {
  assert.ok(LIB.length >= 40, `only ${LIB.length} quests`);
  const ids = new Set(LIB.map((q) => q.id));
  assert.equal(ids.size, LIB.length, 'duplicate quest ids');
  for (const q of LIB) {
    assert.ok(q.steps.length >= 2 && q.steps.length <= 7, `${q.id} step count`);
    assert.ok(['morning', 'daytime', 'evening', 'anytime'].includes(q.anchor), `${q.id} anchor`);
    assert.ok(['daily', 'weekly', 'monthly', 'once'].includes(q.cadence), `${q.id} cadence`);
    assert.ok(q.invite.trim().endsWith('?') || q.invite.includes('.'), `${q.id} invite`);
    assert.doesNotMatch(q.invite, DEMANDING, `${q.id} invite must be PDA-safe`);
    for (const s of q.steps) {
      assert.ok(s.text.trim().length > 2, `${q.id} empty step`);
      if (s.timerMinutes !== undefined) assert.ok(s.timerMinutes > 0 && s.timerMinutes <= 120);
      if (s.tiny) assert.ok(s.tiny.length >= 2);
    }
  }
});

test('laundry quest has the 45-minute washer timer and the dryer sheet step', () => {
  const laundry = LIB.find((q) => q.id === 'laundry');
  assert.ok(laundry);
  assert.equal(laundry.steps.find((s) => /washer/i.test(s.text))?.timerMinutes, 45);
  assert.ok(laundry.steps.some((s) => /dryer sheet/i.test(s.text)));
  const order = laundry.steps.map((s) => s.text);
  assert.ok(order.findIndex((t) => /dryer sheet/i.test(t)) < order.findIndex((t) => /lint trap/i.test(t)));
});

test('the required starter quests exist', () => {
  for (const id of ['dishes-reset', 'morning-meds', 'morning-teeth', 'bedtime-teeth', 'morning-pack-bag', 'pay-bills', 'tax-docs', 'bedroom-clean']) {
    assert.ok(LIB.some((q) => q.id === id), id);
  }
  const bedroom = LIB.find((q) => q.id === 'bedroom-clean')!;
  const t = bedroom.steps.map((s) => s.text.toLowerCase());
  assert.ok(t.findIndex((x) => x.includes('trash')) < t.findIndex((x) => x.includes('clothes')));
  assert.ok(t.findIndex((x) => x.includes('clothes')) < t.findIndex((x) => x.includes('surface')));
});

test('starter routine only references real quests, without duplicates', () => {
  for (const profile of ['adhd', 'add', 'autism', 'audhd', 'anxiety', 'other'] as const) {
    for (const energy of ['low', 'medium', 'high'] as const) {
      for (const block of ['school', 'work', 'none'] as const) {
        const ids = buildStarterRoutine([profile, 'other'], energy, block);
        assert.equal(new Set(ids).size, ids.length);
        for (const id of ids) assert.ok(LIB.some((q) => q.id === id), `${id} missing`);
      }
    }
  }
  assert.ok(buildStarterRoutine(['anxiety'], 'low', 'none').includes('hard-day-kit'));
  assert.ok(buildStarterRoutine(['add'], 'medium', 'school').includes('focus-sprint'));
  assert.ok(buildStarterRoutine(['adhd'], 'medium', 'school').includes('homework-start'));
  assert.ok(buildStarterRoutine(['autism'], 'high', 'work').includes('sensory-reset'));
  const combo = buildStarterRoutine(['adhd', 'autism', 'anxiety'], 'medium', 'none');
  for (const id of ['focus-sprint', 'sensory-reset', 'step-outside']) assert.ok(combo.includes(id), id);
  assert.ok(buildStarterRoutine(['adhd'], 'low', 'none').length < buildStarterRoutine(['adhd'], 'high', 'none').length);
});

test('progression only goes up and levels gently', () => {
  assert.deepEqual(levelFromXp(0), { level: 1, into: 0, needed: 40 });
  assert.equal(levelFromXp(39).level, 1);
  assert.equal(levelFromXp(40).level, 2);
  assert.equal(levelFromXp(40 + 60).level, 3);
  assert.equal(xpForNextLevel(3), 80);
  assert.equal(levelFromXp(-50).level, 1);
});

test('share codes round-trip, including emoji and custom quests', () => {
  const payload = {
    v: 1 as const,
    quests: [
      { id: 'laundry', anchor: 'anytime' as const },
      { id: null, title: 'Feed Mr. Whiskers 🐱', emoji: '🐱', anchor: 'morning' as const, cadence: 'daily' as const, steps: ['Open the can', 'Fill the bowl — just half'] },
    ],
    anchors: { wake: 420, blockKind: 'school' as const, blockStart: 510, blockEnd: 900, bed: 1320 },
  };
  const code = encodeShareCode(payload);
  assert.match(code, /^MN1-[A-Za-z0-9_-]+$/);
  assert.deepEqual(decodeShareCode(`  ${code}\n`), payload);
});

test('share codes reject junk with friendly messages', () => {
  assert.throws(() => decodeShareCode('hello'), /MN1-/);
  assert.throws(() => decodeShareCode('MN1-@@@'), /missing/);
  assert.throws(() => decodeShareCode(encodeShareCode({ v: 1, quests: [] })), /no routine/);
  const sneaky = decodeShareCode(
    encodeShareCode({ v: 1, quests: [{ id: 'x', anchor: 'nope' as never }], anchors: { wake: 99999, blockKind: 'party' as never, blockStart: -5, blockEnd: 60, bed: 1 } }),
  );
  assert.equal(sneaky.quests[0]!.anchor, 'anytime');
  assert.equal(sneaky.anchors!.wake, 1439);
  assert.equal(sneaky.anchors!.blockStart, 0);
  assert.equal(sneaky.anchors!.blockKind, 'none');
});

test('Smart Match finds the right library quest', () => {
  assert.equal(bestLibraryMatch('ugh I need to do laundry', LIB).quest?.id, 'laundry');
  assert.equal(bestLibraryMatch('pay my rent and phone bill', LIB).quest?.id, 'pay-bills');
  assert.equal(bestLibraryMatch('call the dentist to book an appointment', LIB).quest?.id, 'doctor-call');
  const r = smartBreakdown('wash the dishes', LIB);
  assert.equal(r.matchedTitle, 'Dishes & Kitchen Reset');
  assert.ok(r.steps.length >= 4 && r.steps.length <= 6);
});

test('Smart Match falls back to a literal, gentle starter plan', () => {
  const r = smartBreakdown('assemble the IKEA bookshelf', LIB);
  assert.equal(r.matchedTitle, null);
  assert.equal(r.steps.length, 5);
  assert.ok(r.steps[0]!.includes('assemble the IKEA bookshelf'));
  for (const s of genericSteps('I really need to finish my essay!!')) assert.doesNotMatch(s, DEMANDING);
});

test('smaller steps: hand-written first, careful splits second, never invented text', () => {
  assert.deepEqual(smallerSteps('x', ['a', 'b']), ['a', 'b']);
  assert.deepEqual(smallerSteps('x', JSON.stringify(['a', 'b'])), ['a', 'b']);
  assert.deepEqual(smallerSteps('Grab a towel and clean clothes, then walk to the bathroom'), ['Grab a towel and clean clothes', 'Walk to the bathroom']);
  assert.deepEqual(smallerSteps('Spit, rinse the brush, and put it back'), ['Spit', 'Rinse the brush', 'Put it back']);
  // Your bug report: a single action has nothing smaller to offer.
  assert.equal(smallerSteps('Walk to the bathroom sink'), null);
  assert.equal(canMakeSmaller('Walk to the bathroom sink'), false);
  assert.equal(smallerSteps('Vacuum the hallway'), null);
  assert.equal(smallerSteps('Pick one: pasta, a rice bowl, a sandwich, or a frozen meal'), null);
});

test('every library step is either one simple action or has natural micro-steps', () => {
  let withTiny = 0;
  for (const q of LIB) {
    for (const s of q.steps) {
      const parts = smallerSteps(s.text, s.tiny);
      if (s.tiny) withTiny += 1;
      if (!parts) continue;
      assert.ok(parts.length >= 2 && parts.length <= 5, `${q.id}: ${s.text}`);
      for (const p of parts) {
        assert.ok(p.length > 2 && p.length <= 80, `${q.id}: "${p}"`);
        assert.doesNotMatch(p, /where you'll|go to where/i, `${q.id}: template text leaked: "${p}"`);
        assert.notEqual(p.toLowerCase(), s.text.toLowerCase(), `${q.id}: micro-step repeats the step`);
      }
    }
  }
  assert.ok(withTiny >= 100, `only ${withTiny} steps have micro-steps`);
});

test('softenText turns demands into invitations', () => {
  const out = softenText('You must clean your room NOW!');
  assert.doesNotMatch(out, DEMANDING);
  assert.match(out, /^Want to clean your room/);
  assert.equal(softenText('Want to go for a walk?'), 'Want to go for a walk?');
});

test('time helpers', () => {
  assert.equal(formatClock(0), '12:00 AM');
  assert.equal(formatClock(13 * 60 + 5), '1:05 PM');
  assert.equal(formatClock(-15), '11:45 PM');
  assert.equal(daysBetween('2026-02-27', '2026-03-02'), 3);
  const a = { wake: 420, blockKind: 'school' as const, blockStart: 510, blockEnd: 900, bed: 1320 };
  assert.equal(currentAnchor(a, 450), 'morning');
  assert.equal(currentAnchor(a, 600), 'daytime');
  assert.equal(currentAnchor(a, 1200), 'evening');
  assert.equal(currentAnchor(a, 120), 'evening');
});

test('Pebble shop has 8–10 starter items, all earnable', () => {
  assert.ok(SHOP_ITEMS.length >= 8 && SHOP_ITEMS.length <= 10);
  assert.equal(new Set(SHOP_ITEMS.map((i) => i.id)).size, SHOP_ITEMS.length);
  for (const i of SHOP_ITEMS) assert.ok(i.price > 0 && i.price <= 40, i.id);
  assert.ok(SHOP_ITEMS.some((i) => i.kind === 'treat'));
});

test('free tier has a starter look; everything else is Pro', () => {
  assert.deepEqual(PET_COLORS.filter((c) => c.free).map((c) => c.id), ['cream', 'peach']);
  assert.deepEqual(HATS.filter((c) => c.free).map((c) => c.id), ['none', 'sprout']);
  assert.deepEqual(SCARVES.filter((c) => c.free).map((c) => c.id), ['none']);
  assert.deepEqual(ROOMS.filter((c) => c.free).map((c) => c.id), ['sunny']);
});
