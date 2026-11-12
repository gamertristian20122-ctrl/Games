import type { LibraryQuest } from './types';

/**
 * "Smart Match": the offline, no-AI way to break a messy task into steps.
 * It matches the task against the bundled quest library and,
 * failing that, builds a literal 5-step starter plan around the user's words.
 */

const STOP_WORDS = new Set([
  'a', 'an', 'the', 'my', 'to', 'and', 'or', 'of', 'for', 'in', 'on', 'at', 'it', 'i', 'me', 'need',
  'have', 'has', 'must', 'should', 'gotta', 'got', 'get', 'do', 'some', 'up', 'just', 'really', 'ugh',
  'before', 'after', 'this', 'that', 'with', 'all', 'so', 'is', 'be', 'today', 'tomorrow', 'now',
]);

export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s'-]/g, ' ')
    .split(/\s+/)
    .map((w) => w.replace(/^['-]+|['-]+$/g, ''))
    .filter((w) => w.length > 1 && !STOP_WORDS.has(w));
}

function stem(word: string): string {
  return word.replace(/(ing|es|s|ed)$/, '');
}

export interface MatchResult {
  quest: LibraryQuest | null;
  score: number;
}

export function bestLibraryMatch(task: string, library: readonly LibraryQuest[]): MatchResult {
  const lower = ` ${task.toLowerCase()} `;
  const words = tokenize(task).map(stem);
  let best: MatchResult = { quest: null, score: 0 };
  for (const quest of library) {
    let score = 0;
    for (const kw of quest.keywords) {
      const k = kw.toLowerCase();
      if (k.includes(' ')) {
        if (lower.includes(k)) score += 3;
      } else if (words.includes(stem(k))) {
        score += 2;
      }
    }
    for (const t of tokenize(quest.title)) {
      if (words.includes(stem(t))) score += 1;
    }
    if (score > best.score) best = { quest, score };
  }
  return best;
}

function cleanTask(task: string): string {
  const trimmed = task.trim().replace(/\s+/g, ' ').replace(/[.!?]+$/, '');
  const withoutFiller = trimmed
    .replace(/^(ugh+|ok+|okay|so|um+)[,\s]+/i, '')
    .replace(/^(i\s+)?(really\s+)?(need|have|gotta|got|must|should)\s+(to\s+)?/i, '');
  const core = withoutFiller.length > 0 ? withoutFiller : trimmed;
  return core.charAt(0).toLowerCase() + core.slice(1);
}

/** Literal, low-pressure starter plan for any task the library doesn't know. */
export function genericSteps(task: string): string[] {
  const t = cleanTask(task) || 'this task';
  return [
    `Go to the place where "${t}" happens`,
    'Get out the one thing you need first',
    'Set a 5-minute timer and do only the very first bit',
    'Pause and look at what is left (it is okay to stop here)',
    'Put away anything you got out',
  ];
}

export function smartBreakdown(task: string, library: readonly LibraryQuest[]): { steps: string[]; matchedTitle: string | null } {
  const match = bestLibraryMatch(task, library);
  if (match.quest && match.score >= 2) {
    const steps = match.quest.steps.map((s) => s.text).slice(0, 6);
    return { steps, matchedTitle: match.quest.title };
  }
  return { steps: genericSteps(task), matchedTitle: null };
}

// Action words that can safely start a micro-step. Ambiguous words that are often
// adjectives too ("clean clothes", "dry socks") are left out on purpose.
const ACTION_VERBS = new Set([
  'add', 'apply', 'ask', 'book', 'breathe', 'brush', 'call', 'carry', 'charge', 'check', 'choose', 'close', 'comb', 'cook',
  'count', 'drink', 'drop', 'dust', 'eat', 'email', 'empty', 'feed', 'fill', 'find', 'finish', 'floss', 'fold', 'get', 'give',
  'go', 'grab', 'hang', 'hold', 'lay', 'lift', 'load', 'lock', 'look', 'make', 'mop', 'move', 'open', 'pack', 'pay', 'pick',
  'plug', 'pour', 'press', 'print', 'pull', 'push', 'put', 'read', 'reply', 'rest', 'rinse', 'roll', 'run', 'save', 'scrub',
  'search', 'send', 'set', 'shake', 'sit', 'soap', 'sort', 'spit', 'spray', 'squeeze', 'stack', 'stand', 'start', 'step',
  'stretch', 'sweep', 'swallow', 'take', 'tap', 'tell', 'text', 'throw', 'tie', 'toss', 'touch', 'turn', 'type', 'unload',
  'unlock', 'unpack', 'vacuum', 'walk', 'wash', 'wear', 'wipe', 'write',
]);

const SEPARATOR = /(,\s*(?:and\s+|then\s+)?|\s+and then\s+|\s+then\s+|\s+and\s+)/i;

function capitalize(t: string): string {
  return t.charAt(0).toUpperCase() + t.slice(1);
}

/** Splits "Do A, then B and C" only where a real action word starts the next part. */
function splitOnActions(text: string): string[] | null {
  const pieces = text.replace(/[.!]+$/, '').split(SEPARATOR);
  const parts: string[] = [pieces[0] ?? ''];
  for (let i = 1; i < pieces.length; i += 2) {
    const sep = pieces[i] ?? '';
    const next = (pieces[i + 1] ?? '').trim();
    const firstWord = next.split(/\s+/)[0]?.toLowerCase() ?? '';
    if (ACTION_VERBS.has(firstWord)) parts.push(next);
    else parts[parts.length - 1] += sep + next;
  }
  const clean = parts.map((p) => p.trim()).filter((p) => p.length > 2);
  return clean.length >= 2 && clean.length <= 5 ? clean.map(capitalize) : null;
}

function parseTiny(tiny: string | readonly string[] | null | undefined): string[] | null {
  if (!tiny) return null;
  if (Array.isArray(tiny)) return tiny.length > 0 ? [...tiny] : null;
  try {
    const parsed: unknown = JSON.parse(tiny as string);
    if (Array.isArray(parsed)) {
      const list = parsed.filter((x): x is string => typeof x === 'string' && x.trim().length > 0);
      return list.length > 0 ? list : null;
    }
  } catch {
    // fall through
  }
  return null;
}

/**
 * Smaller pieces for one step, or null when the step is already one simple action.
 * Uses hand-written micro-steps first, then a careful split on "and"/"then".
 * Never invents wording around the step, so it can't produce broken sentences.
 */
export function smallerSteps(stepText: string, tiny?: string | readonly string[] | null): string[] | null {
  return parseTiny(tiny) ?? splitOnActions(stepText);
}

/** True when "Make it smaller" has something real to offer for this step. */
export function canMakeSmaller(stepText: string, tiny?: string | readonly string[] | null): boolean {
  return smallerSteps(stepText, tiny) !== null;
}

/** Rule-based gentle rewrite: turns a demand into an invitation. */
export function softenText(text: string): string {
  let t = text.trim().replace(/\s+/g, ' ').replace(/[.!]+$/, '');
  if (t.length === 0) return t;
  t = t
    .replace(/\b(right now|asap|immediately|now)\b/gi, '')
    .replace(/\b(you|i)\s+(must|have to|need to|should|gotta)\s+/gi, '')
    .replace(/^(must|have to|need to|should|gotta|don't forget to|remember to)\s+/i, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
  if (/\?$/.test(t)) return t;
  const lowered = t.charAt(0).toLowerCase() + t.slice(1);
  return `Want to ${lowered} together? Only if it feels okay.`;
}

// ---------- Magic Break Down & Brain-Dump Splitter (offline, no AI) ----------

/** Share of the user's meaningful words that the quest's keywords or title contain. */
function coverage(task: string, quest: LibraryQuest): number {
  const words = tokenize(task).map(stem);
  if (words.length === 0) return 0;
  const vocab = new Set<string>();
  for (const kw of quest.keywords) for (const w of tokenize(kw)) vocab.add(stem(w));
  for (const w of tokenize(quest.title)) vocab.add(stem(w));
  return words.filter((w) => vocab.has(w)).length / words.length;
}

export interface MagicResult {
  steps: string[];
  /** Icon of the library quest it matched, so the new quest gets a fitting picture. */
  icon: string;
  matchedTitle: string | null;
}

/**
 * Turns one task title into 3–5 ultra-tiny starter steps.
 * Uses the matching library quest and expands its first step into hand-written
 * micro-steps when it has them, so the very first thing to do is as small as possible.
 */
export function magicBreakdown(title: string, library: readonly LibraryQuest[]): MagicResult {
  const match = bestLibraryMatch(title, library);
  // At least half of the task's meaningful words must belong to the matched quest, so
  // "take a shower" matches the Shower Quest but "assemble my new desk" doesn't become a desk tidy.
  if (match.quest && match.score >= 2 && coverage(title, match.quest) >= 0.5) {
    const [first, ...rest] = match.quest.steps;
    const opening = first?.tiny && first.tiny.length > 0 ? first.tiny : first ? [first.text] : [];
    const steps = [...opening, ...rest.map((s) => s.text)].slice(0, 5);
    return { steps, icon: match.quest.emoji, matchedTitle: match.quest.title };
  }
  const t = cleanTask(title) || 'this task';
  return {
    steps: [
      `Go to the place where "${t}" happens`,
      'Get out the one thing you need first',
      'Do only the very first 2 minutes',
      'Pause and decide: keep going, or stop here (both are fine)',
    ],
    icon: 'sparkle',
    matchedTitle: null,
  };
}

export interface BrainDumpItem {
  title: string;
  steps: string[];
  icon: string;
}

const FILLER = /^(and|also|then|plus|oh|ugh+|um+|ok|okay|so|maybe|i need to|i have to|i should|i gotta|need to|have to|gotta|should|must|remember to|don't forget to|dont forget to|pls|please)\b[\s,:-]*/i;

function capitalizeFirst(t: string): string {
  return t.charAt(0).toUpperCase() + t.slice(1);
}

/**
 * Brain-Dump Splitter: pour out a messy list ("laundry, call mom and the dentist, ugh homework")
 * and get one tidy quest per thing, each with tiny starter steps. Fully offline.
 */
export function splitBrainDump(text: string, library: readonly LibraryQuest[], max = 8): BrainDumpItem[] {
  const parts = text
    .split(/\n|;|,|•|·|\s-\s|\.\s+|\band also\b|\balso\b|\bplus\b|\band then\b|\bthen\b/i)
    .flatMap((p) => p.split(/\s+and\s+(?=(?:call|email|text|clean|do|wash|pay|book|buy|get|make|finish|study|reply|take|go|feed|water|fold|vacuum|tidy|cook|send|write|read|pack|empty|walk)\b)/i))
    .map((p) => {
      let t = p.replace(/^[\s*\-•\d.)]+/, '').trim();
      for (let i = 0; i < 3; i++) t = t.replace(FILLER, '').trim();
      return t.replace(/[.!?]+$/, '').replace(/\s+/g, ' ');
    })
    .filter((p) => p.length >= 3 && /[a-z]/i.test(p));
  const seen = new Set<string>();
  const items: BrainDumpItem[] = [];
  for (const p of parts) {
    // "do laundry" and "laundry" are the same task: compare the meaningful words only.
    const key = tokenize(p).join(' ') || p.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    const magic = magicBreakdown(p, library);
    items.push({ title: capitalizeFirst(p).slice(0, 60), steps: magic.steps, icon: magic.icon });
    if (items.length >= max) break;
  }
  return items;
}
