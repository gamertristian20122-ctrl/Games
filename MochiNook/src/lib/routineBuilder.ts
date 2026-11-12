import type { BlockKind, BrainProfile, Energy, Friction } from './types';

/**
 * Picks the starter routine (library quest ids) from the onboarding answers.
 * Kept small on purpose: a short list that feels doable beats a full one.
 */
export function buildStarterRoutine(profiles: readonly BrainProfile[], energy: Energy, blockKind: BlockKind): string[] {
  const ids: string[] = [
    'morning-water',
    'morning-meds',
    'morning-teeth',
    'bedtime-teeth',
    'bedtime-charge',
    'dishes-reset',
    'laundry',
    'pay-bills',
  ];

  if (energy === 'low') {
    ids.push('hard-day-kit', 'water-break');
  }
  if (energy === 'medium' || energy === 'high') {
    ids.push('morning-dress', 'morning-pack-bag', 'bedtime-tomorrow', 'bedtime-wind-down', 'desk-tidy', 'shower', 'reply-messages');
  }
  if (energy === 'high') {
    ids.push('bedroom-clean', 'grocery-run', 'money-peek', 'wiggle-stretch');
  }

  const has = (p: BrainProfile) => profiles.includes(p);
  if (has('adhd') || has('add') || has('audhd')) ids.push('morning-launch', 'focus-sprint');
  if (has('autism') || has('audhd')) ids.push('sensory-reset', 'bedtime-tomorrow');
  if (has('anxiety')) ids.push('hard-day-kit', 'step-outside');

  if (blockKind === 'school') ids.push('homework-start');
  if (blockKind === 'work') ids.push('work-start');

  return Array.from(new Set(ids));
}

/** A small, kind core every new routine starts with. */
const CORE = ['morning-water', 'morning-meds', 'morning-teeth', 'bedtime-teeth', 'dishes-reset', 'laundry'];

/** Starter quests matched to what's hardest right now (first-launch welcome, step 3). */
export const FRICTION_QUESTS: Record<Friction, string[]> = {
  starting: ['focus-sprint', 'work-start', 'desk-tidy', 'reply-messages'],
  time: ['morning-launch', 'bedtime-tomorrow', 'calendar-check', 'focus-sprint'],
  sensory: ['sensory-reset', 'step-outside', 'wiggle-stretch', 'hard-day-kit'],
  bedtime: ['bedtime-wind-down', 'bedtime-charge', 'bedtime-pajamas', 'bedtime-tomorrow'],
};

export function buildFrictionRoutine(friction: Friction | null): string[] {
  return Array.from(new Set([...CORE, ...(friction ? FRICTION_QUESTS[friction] : [])]));
}
