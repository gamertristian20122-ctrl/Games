import assert from 'node:assert/strict';
import { test } from 'node:test';
import library from '../src/data/quests.json';
import { HATS, PET_COLORS, ROOMS, SCARVES, seasonalRewards } from '../src/data/cosmetics';
import { SHOP_ITEMS } from '../src/data/shop';
import { pickPalette, type Palette } from '../src/theme/tokens';
import { synthNoise, wavBytes } from '../src/lib/noiseSynth';
import { PRIVACY_POLICY, TERMS_OF_USE } from '../src/data/legal';
import { levelFromXp, xpForNextLevel } from '../src/lib/progression';
import { FRICTION_QUESTS, buildFrictionRoutine, buildStarterRoutine } from '../src/lib/routineBuilder';
import { decodeRaceResult, decodeShareCode, encodeRaceResult, encodeShareCode } from '../src/lib/shareCode';
import { SEASON_GLYPH, seasonFor, sprintTiers, weekDays, weekStart } from '../src/lib/season';
import { glyphFor, isGlyphName } from '../src/components/art/glyphNames';
import { CHEERS } from '../src/lib/copy';
import { bestLibraryMatch, canMakeSmaller, genericSteps, magicBreakdown, smallerSteps, smartBreakdown, softenText, splitBrainDump } from '../src/lib/smartMatch';
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
  assert.deepEqual(PET_COLORS.filter((c) => c.free).map((c) => c.id), ['cream', 'peach', 'mint']);
  assert.deepEqual(HATS.filter((c) => c.free).map((c) => c.id), ['none', 'sprout']);
  assert.deepEqual(SCARVES.filter((c) => c.free).map((c) => c.id), ['none']);
  assert.deepEqual(ROOMS.filter((c) => c.free).map((c) => c.id), ['sunny']);
});

test('privacy policy and terms cover what Google Play asks for', () => {
  const all = (d: { sections: { heading: string; paragraphs: string[] }[] }) =>
    d.sections.map((s) => `${s.heading} ${s.paragraphs.join(' ')}`).join(' ');
  const privacy = all(PRIVACY_POLICY);
  for (const must of ['RevenueCat', 'Delete all my data', 'children', 'Notifications', 'contact']) assert.match(privacy, new RegExp(must, 'i'), must);
  const terms = all(TERMS_OF_USE);
  for (const must of ['6.99', '34.99', 'free trial', 'cancel', 'not medical advice']) assert.match(terms, new RegExp(must, 'i'), must);
});

test('seasons, weeks and sprint goals', () => {
  assert.equal(seasonFor(new Date(2026, 10, 12)), 'autumn');
  assert.equal(seasonFor(new Date(2026, 0, 5)), 'winter');
  assert.equal(seasonFor(new Date(2026, 3, 5)), 'spring');
  assert.equal(seasonFor(new Date(2026, 6, 5)), 'summer');
  assert.equal(weekStart('2026-11-12'), '2026-11-09');
  assert.equal(weekStart('2026-11-09'), '2026-11-09');
  assert.equal(weekStart('2026-11-15'), '2026-11-09');
  assert.equal(weekDays('2026-12-28')[6], '2027-01-03');
  const [a, b, c] = sprintTiers('low');
  assert.ok(a < b && b < c && c < sprintTiers('high')[2]);
  for (const s of ['autumn', 'winter', 'spring', 'summer'] as const) {
    assert.deepEqual(seasonalRewards(s).map((r) => r.tier), [1, 2, 3], s);
  }
});

test('race codes round-trip and are sanitized', () => {
  const code = encodeRaceResult({ v: 1, pet: 'Pip', steps: 9, minutes: 15, day: '2026-11-12' });
  assert.deepEqual(decodeRaceResult(code), { v: 1, pet: 'Pip', steps: 9, minutes: 15, day: '2026-11-12' });
  const nasty = decodeRaceResult(encodeRaceResult({ v: 1, pet: '<b>http://x.y</b>', steps: 99999, minutes: 0, day: 'nope' }));
  assert.equal(nasty.steps, 500);
  assert.doesNotMatch(nasty.pet, /[<>:/.]/);
  assert.equal(nasty.day, '');
  assert.throws(() => decodeRaceResult('MN1-abc'), /race code/);
});

test('cheers are preset, short and kind', () => {
  assert.ok(CHEERS.length >= 10);
  for (const c of CHEERS) {
    assert.ok(c.length <= 60, c);
    assert.doesNotMatch(c, /https?:|www\.|@/i);
  }
});

test('every quest uses a custom vector icon, and every legacy emoji maps to one', () => {
  for (const q of LIB) assert.ok(isGlyphName(q.emoji), `${q.id} icon "${q.emoji}" is not a glyph`);
  for (const legacy of ['💧', '🧺', '🍽️', '🛋️', '🗓️', '🧠', '📦', '✨']) assert.notEqual(glyphFor(legacy), undefined);
  assert.equal(glyphFor('🛋️'), 'couch');
  assert.equal(glyphFor('🛋'), 'couch', 'works without the emoji variation selector');
  assert.equal(glyphFor('laundry'), 'sparkle', 'unknown values fall back gently');
  assert.equal(glyphFor(null), 'sparkle');
  for (const g of ['flag', 'books', 'spoon', 'star', 'leaf', 'snowflake', 'blossom', 'sun', 'hand', 'cookie', 'moon', 'tea', 'dango', 'gift']) {
    assert.ok(isGlyphName(g), g);
  }
});

test('every season and shop item has art', () => {
  for (const s of ['autumn', 'winter', 'spring', 'summer'] as const) assert.ok(isGlyphName(SEASON_GLYPH[s]));
  const decorIds = ['rug', 'lights', 'poster', 'books', 'fern', 'plush', 'beanbag', 'lamp'];
  assert.deepEqual(SHOP_ITEMS.filter((i) => i.kind === 'decor').map((i) => i.id).sort(), decorIds.sort());
});

test('friction triage pre-loads real, matching starter quests', () => {
  for (const f of ['starting', 'time', 'sensory', 'bedtime'] as const) {
    const ids = buildFrictionRoutine(f);
    assert.equal(new Set(ids).size, ids.length);
    for (const id of ids) assert.ok(LIB.some((q) => q.id === id), `${f}: ${id}`);
    for (const id of FRICTION_QUESTS[f]) assert.ok(ids.includes(id));
  }
  assert.ok(buildFrictionRoutine('sensory').includes('sensory-reset'));
  assert.ok(buildFrictionRoutine('bedtime').includes('bedtime-wind-down'));
  assert.ok(buildFrictionRoutine(null).length >= 5, 'skipping still gives a gentle core');
});

test('Magic Break Down gives 3–5 tiny starter steps', () => {
  for (const title of ['Clean room', 'Do homework', 'Take a shower', 'do the laundry', 'assemble my new desk']) {
    const r = magicBreakdown(title, LIB);
    assert.ok(r.steps.length >= 3 && r.steps.length <= 5, `${title}: ${r.steps.length}`);
    for (const s of r.steps) assert.ok(s.length > 2 && s.length < 120);
  }
  const shower = magicBreakdown('Take a shower', LIB);
  assert.equal(shower.steps[0], 'Grab a towel', 'opens with the tiniest possible step');
  assert.equal(shower.icon, 'shower');
  assert.equal(magicBreakdown('Clean room', LIB).icon, 'broom');
  assert.equal(magicBreakdown('assemble my new desk', LIB).matchedTitle, null);
});

test('Brain-Dump Splitter turns a messy list into separate quests', () => {
  const items = splitBrainDump('ugh I need to do laundry, call the dentist and pay rent\nalso homework!!\n- take a shower\nlaundry', LIB);
  assert.deepEqual(items.map((i) => i.title), ['Do laundry', 'Call the dentist', 'Pay rent', 'Homework', 'Take a shower']);
  for (const i of items) assert.ok(i.steps.length >= 3 && i.steps.length <= 5, i.title);
  assert.equal(items.find((i) => i.title === 'Pay rent')?.icon, 'receipt');
  assert.deepEqual(splitBrainDump('   ,, ;; ', LIB), []);
  assert.equal(splitBrainDump(Array.from({ length: 20 }, (_, i) => `task number ${i}`).join(', '), LIB).length, 8);
});

test('ambient noise is generated in code, loops seamlessly and stays gentle', () => {
  for (const kind of ['brown', 'rain'] as const) {
    const s = synthNoise(kind, 2, 8000);
    assert.equal(s.length, 16000);
    let peak = 0;
    for (const v of s) {
      assert.ok(Number.isFinite(v));
      peak = Math.max(peak, Math.abs(v));
    }
    assert.ok(peak <= 0.4501 && peak > 0.3, `${kind} peak ${peak}`);
    assert.ok(Math.abs(s[s.length - 1]! - s[0]!) < 0.05, `${kind} loop seam`);
  }
  // Brown noise is smooth (low frequencies): neighbouring samples barely differ.
  const brown = synthNoise('brown', 1, 8000);
  let diff = 0;
  for (let i = 1; i < brown.length; i++) diff += Math.abs(brown[i]! - brown[i - 1]!);
  assert.ok(diff / brown.length < 0.05, 'over 6x smoother than white noise (~0.3)');
  const wav = wavBytes(new Float32Array([0, 0.5, -0.5]), 8000);
  assert.equal(String.fromCharCode(...wav.slice(0, 4)), 'RIFF');
  assert.equal(String.fromCharCode(...wav.slice(8, 12)), 'WAVE');
  assert.equal(wav.length, 44 + 6);
});

test('every text/background pair meets WCAG AA (4.5:1) in light, dark, calm light and calm dark', () => {
  const lum = (hex: string) => {
    const n = parseInt(hex.slice(1), 16);
    const ch = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
      const c = v / 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * ch[0]! + 0.7152 * ch[1]! + 0.0722 * ch[2]!;
  };
  const ratio = (a: string, b: string) => {
    const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p) as [number, number];
    return (x + 0.05) / (y + 0.05);
  };
  const pairs: [keyof Palette, keyof Palette][] = [
    ['ink', 'bg'], ['ink', 'surface'], ['ink', 'surfaceAlt'], ['inkSoft', 'bg'], ['inkSoft', 'surface'], ['inkSoft', 'surfaceAlt'],
    ['accentInk', 'bg'], ['accentInk', 'surface'], ['accentInk', 'accentSoft'], ['onAccent', 'accent'],
    ['ink', 'accentSoft'], ['ink', 'lavenderSoft'], ['ink', 'peachSoft'], ['ink', 'butterSoft'],
    ['inkSoft', 'lavenderSoft'], ['inkSoft', 'accentSoft'], ['inkSoft', 'butterSoft'],
    ['onPastel', 'lavender'], ['onPastel', 'butter'], ['onPastel', 'peach'],
  ];
  for (const [scheme, calm] of [['light', false], ['dark', false], ['light', true], ['dark', true]] as const) {
    const p = pickPalette(scheme, calm);
    for (const [fg, bg] of pairs) {
      const r = ratio(p[fg], p[bg]);
      assert.ok(r >= 4.5, `${scheme}${calm ? '+calm' : ''}: ${fg} on ${bg} is ${r.toFixed(2)}`);
    }
  }
});
