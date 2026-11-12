import { magicBreakdown } from '../smartMatch';
import type { LibraryQuest } from '../types';

/**
 * Task splitting: one messy task -> 3 to 5 tiny, literal steps.
 *
 * Today this runs on the offline Smart Match rules (library match, then a gentle template).
 * It is built so an on-device model (for example a small GGUF model run with llama.rn) can be
 * plugged in later WITHOUT touching any screen:
 *
 *   registerTaskSplitter({
 *     id: 'gguf-qwen-0.5b',
 *     isReady: () => model.loaded,
 *     split: (task, { maxSteps, signal }) => model.complete(promptFor(task, maxSteps), { signal }).then(parseLines),
 *   });
 *
 * Screens only ever call `splitTaskIntoSteps()`. Whatever the model returns is cleaned by
 * `normalizeSteps()`, and if it is slow, fails, or gives too few steps, the offline rules answer instead.
 * Nothing ever leaves the phone.
 */

export const MIN_STEPS = 3;
export const MAX_STEPS = 5;
const MAX_STEP_LENGTH = 90;
const DEFAULT_TIMEOUT_MS = 8000;

export interface SplitOptions {
  maxSteps: number;
  /** Aborted when the splitter takes too long; a model runtime should stop generating. */
  signal: AbortSignal;
}

/** Anything that can turn a task into steps: an on-device model, or a test double. */
export interface TaskSplitter {
  id: string;
  /** False while a model is still downloading or loading; the offline rules answer meanwhile. */
  isReady: () => boolean | Promise<boolean>;
  split: (task: string, opts: SplitOptions) => Promise<string[]>;
}

export interface SplitResult {
  steps: string[];
  /** Glyph id for the new quest. */
  icon: string;
  /** Title of the library quest the steps came from, if any. */
  matchedTitle: string | null;
  /** Where the steps came from (handy for the UI note and for debugging). */
  source: 'library' | 'model' | 'template';
}

let splitter: TaskSplitter | null = null;

/** Plug in (or remove, with null) an on-device splitter. */
export function registerTaskSplitter(next: TaskSplitter | null): void {
  splitter = next;
}

export function activeTaskSplitter(): string | null {
  return splitter?.id ?? null;
}

/**
 * Cleans raw step lines from any source: strips numbering and bullets, trims, drops empties
 * and duplicates, shortens rambling lines, and keeps at most `max` steps.
 */
export function normalizeSteps(raw: readonly string[], max = MAX_STEPS): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const line of raw) {
    if (typeof line !== 'string') continue;
    let s = line
      .replace(/^\s*(?:step\s*)?(?:\d+|[a-z])[.):-]\s+/i, '')
      .replace(/^\s*[-*•·>]+\s*/, '')
      .replace(/\s+/g, ' ')
      .trim();
    if (!s) continue;
    if (s.length > MAX_STEP_LENGTH) s = `${s.slice(0, MAX_STEP_LENGTH - 1).trimEnd()}…`;
    s = s.charAt(0).toUpperCase() + s.slice(1);
    const key = s.toLowerCase().replace(/[^a-z0-9]+/g, '');
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(s);
    if (out.length >= max) break;
  }
  return out;
}

function withTimeout<T>(work: (signal: AbortSignal) => Promise<T>, ms: number): Promise<T> {
  const controller = new AbortController();
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => {
      controller.abort();
      reject(new Error('timeout'));
    }, ms);
    work(controller.signal).then(
      (v) => {
        clearTimeout(timer);
        resolve(v);
      },
      (e: unknown) => {
        clearTimeout(timer);
        reject(e instanceof Error ? e : new Error(String(e)));
      },
    );
  });
}

/**
 * The one entry point the UI uses. Order:
 * 1. A close match in the quest library (hand-written steps beat generated ones).
 * 2. The registered on-device splitter, if it's ready and answers in time with 3+ usable steps.
 * 3. The offline gentle template.
 */
export async function splitTaskIntoSteps(
  task: string,
  library: readonly LibraryQuest[],
  opts: { timeoutMs?: number } = {},
): Promise<SplitResult> {
  const text = task.trim();
  const offline = magicBreakdown(text, library);
  if (offline.matchedTitle) return { ...offline, steps: normalizeSteps(offline.steps), source: 'library' };

  const current = splitter;
  if (current && text.length >= 3) {
    try {
      const ready = await current.isReady();
      if (ready) {
        const raw = await withTimeout((signal) => current.split(text, { maxSteps: MAX_STEPS, signal }), opts.timeoutMs ?? DEFAULT_TIMEOUT_MS);
        const steps = normalizeSteps(Array.isArray(raw) ? raw : []);
        if (steps.length >= MIN_STEPS) return { steps, icon: offline.icon, matchedTitle: null, source: 'model' };
      }
    } catch {
      // Slow or broken model: fall through to the offline plan. The user never sees an error.
    }
  }
  return { ...offline, steps: normalizeSteps(offline.steps), source: 'template' };
}
