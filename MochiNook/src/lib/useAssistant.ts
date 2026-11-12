import { useCallback, useState } from 'react';
import { LIBRARY } from '../db/schema';
import { smallerSteps, smartBreakdown, softenText } from './smartMatch';

/**
 * Breaks tasks down with Smart Match: fully offline, matched against the
 * bundled quest library, with a literal starter plan as the fallback.
 */
export function useAssistant() {
  const [busy, setBusy] = useState(false);

  const breakDownTask = useCallback(async (task: string): Promise<{ steps: string[]; matchedTitle: string | null }> => {
    setBusy(true);
    try {
      return smartBreakdown(task, LIBRARY);
    } finally {
      setBusy(false);
    }
  }, []);

  const smaller = useCallback(async (stepText: string, tiny: string | null): Promise<string[]> => {
    let authored: string[] | null = null;
    if (tiny) {
      try {
        const parsed: unknown = JSON.parse(tiny);
        if (Array.isArray(parsed)) authored = parsed.filter((x): x is string => typeof x === 'string');
      } catch {
        authored = null;
      }
    }
    return smallerSteps(stepText, authored);
  }, []);

  const soften = useCallback(async (text: string): Promise<string> => softenText(text), []);

  return { busy, breakDownTask, smaller, soften };
}
