import type { BlockKind, BrainProfile, Energy } from './types';

/**
 * Picks the starter routine (library quest ids) from the onboarding answers.
 * Kept small on purpose: a short list that feels doable beats a full one.
 */
export function buildStarterRoutine(profile: BrainProfile, energy: Energy, blockKind: BlockKind): string[] {
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

  if (profile === 'adhd' || profile === 'audhd') ids.push('morning-launch', 'focus-sprint');
  if (profile === 'autism' || profile === 'audhd') ids.push('sensory-reset', 'bedtime-tomorrow');
  if (profile === 'overwhelmed') ids.push('hard-day-kit', 'reply-messages');

  if (blockKind === 'school') ids.push('homework-start');
  if (blockKind === 'work') ids.push('work-start');

  return Array.from(new Set(ids));
}
