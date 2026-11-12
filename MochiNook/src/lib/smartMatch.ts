import type { LibraryQuest } from './types';

/**
 * "Smart Match": the offline, no-AI way to break a messy task into steps.
 * Used by everyone on the free tier and on phones with too little RAM for the
 * on-device model. It matches the task against the bundled quest library and,
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

/** Breaks one step into smaller pieces without AI. */
export function smallerSteps(stepText: string, authoredTiny?: readonly string[] | null): string[] {
  if (authoredTiny && authoredTiny.length > 0) return [...authoredTiny];
  const base = stepText.replace(/[.!]+$/, '');
  const andParts = base
    .split(/,\s*(?:and\s+|then\s+)?|\s+and then\s+|\s+then\s+|\s+and\s+/i)
    .map((p) => p.trim())
    .filter((p) => p.length > 2);
  if (andParts.length >= 2 && andParts.length <= 5) {
    return andParts.map((p) => p.charAt(0).toUpperCase() + p.slice(1));
  }
  const lowered = base.charAt(0).toLowerCase() + base.slice(1);
  return [
    `Stand up and go to where you'll ${lowered}`,
    'Touch the first thing you need',
    `Do just the first 30 seconds of it`,
    'Check: done? If not, do one more tiny bit',
  ];
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
