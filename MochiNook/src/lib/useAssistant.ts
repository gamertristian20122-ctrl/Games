import { useCallback, useMemo, useState } from 'react';
import { LIBRARY } from '../db/schema';
import { useApp } from '../state/AppContext';
import { breakDownWithModel, hasEnoughRam, parseStoredPaths, softenWithModel } from './llm';
import { smallerSteps, smartBreakdown, softenText } from './smartMatch';

export type AssistantMode = 'model' | 'smart';

/**
 * One place that decides HOW a task gets broken down:
 * - Pro + ≥4 GB RAM + model downloaded → private on-device model (loaded, used, unloaded).
 * - Everyone else → Smart Match against the bundled 47-quest library.
 * If the model ever fails, it quietly falls back to Smart Match.
 */
export function useAssistant() {
  const { isPro, settings } = useApp();
  const [busy, setBusy] = useState(false);
  const local = useMemo(() => parseStoredPaths(settings.llmPaths), [settings.llmPaths]);
  const mode: AssistantMode = isPro && hasEnoughRam() && local ? 'model' : 'smart';

  const breakDownTask = useCallback(
    async (task: string): Promise<{ steps: string[]; usedModel: boolean; matchedTitle: string | null }> => {
      setBusy(true);
      try {
        if (mode === 'model' && local) {
          try {
            const steps = await breakDownWithModel(local, task);
            if (steps.length >= 3) return { steps, usedModel: true, matchedTitle: null };
          } catch {
            // fall back below
          }
        }
        const smart = smartBreakdown(task, LIBRARY);
        return { steps: smart.steps, usedModel: false, matchedTitle: smart.matchedTitle };
      } finally {
        setBusy(false);
      }
    },
    [mode, local],
  );

  const smaller = useCallback(
    async (stepText: string, tiny: string | null): Promise<string[]> => {
      let authored: string[] | null = null;
      if (tiny) {
        try {
          const parsed: unknown = JSON.parse(tiny);
          if (Array.isArray(parsed)) authored = parsed.filter((x): x is string => typeof x === 'string');
        } catch {
          authored = null;
        }
      }
      if (authored && authored.length > 0) return authored;
      setBusy(true);
      try {
        if (mode === 'model' && local) {
          try {
            const steps = await breakDownWithModel(local, `Make this one step even smaller: ${stepText}`);
            if (steps.length >= 2) return steps.slice(0, 5);
          } catch {
            // fall back below
          }
        }
        return smallerSteps(stepText, null);
      } finally {
        setBusy(false);
      }
    },
    [mode, local],
  );

  const soften = useCallback(
    async (text: string): Promise<string> => {
      setBusy(true);
      try {
        if (mode === 'model' && local) {
          try {
            const out = await softenWithModel(local, text);
            if (out.length > 5) return out;
          } catch {
            // fall back below
          }
        }
        return softenText(text);
      } finally {
        setBusy(false);
      }
    },
    [mode, local],
  );

  return { mode, busy, breakDownTask, smaller, soften };
}
