import { useCallback } from 'react';
import { LIBRARY } from '../db/schema';
import { canMakeSmaller, smallerSteps, smartBreakdown, softenText } from './smartMatch';

/**
 * Breaks tasks down with Smart Match: fully offline, matched against the
 * bundled quest library, with a literal starter plan as the fallback.
 */
export function useAssistant() {
  const breakDownTask = useCallback(
    (task: string): { steps: string[]; matchedTitle: string | null } => smartBreakdown(task, LIBRARY),
    [],
  );
  const smaller = useCallback((stepText: string, tiny: string | null): string[] | null => smallerSteps(stepText, tiny), []);
  const soften = useCallback((text: string): string => softenText(text), []);
  return { breakDownTask, smaller, soften, canMakeSmaller };
}
