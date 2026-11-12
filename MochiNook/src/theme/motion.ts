import { Easing, withSpring, withTiming } from 'react-native-reanimated';

/**
 * How much the app moves.
 * - still:    the phone's "Reduce motion" setting is on. No movement at all, only expression changes.
 * - calm:     Calm Mode. Slow, small, ease-out motion; few particles; no overshoot.
 * - dopamine: Dopamine Mode. Springy overshoot, richer sparkles and confetti.
 */
export type MotionLevel = 'still' | 'calm' | 'dopamine';

export interface MotionTuning {
  breatheY: number;
  breatheX: number;
  breatheMs: number;
  squishX: number;
  squishY: number;
  hop: number;
  /** Max particles per burst. */
  particles: number;
  /** Particle rise duration. */
  particleMs: number;
  blinkMinMs: number;
  blinkMaxMs: number;
}

export const TUNING: Record<Exclude<MotionLevel, 'still'>, MotionTuning> = {
  calm: {
    breatheY: 0.018,
    breatheX: 0.012,
    breatheMs: 4600,
    squishX: 1.08,
    squishY: 0.91,
    hop: -7,
    particles: 2,
    particleMs: 2200,
    blinkMinMs: 4200,
    blinkMaxMs: 6500,
  },
  dopamine: {
    breatheY: 0.035,
    breatheX: 0.025,
    breatheMs: 3200,
    squishX: 1.18,
    squishY: 0.82,
    hop: -14,
    particles: 6,
    particleMs: 1500,
    blinkMinMs: 3000,
    blinkMaxMs: 5000,
  },
};

const EASE_OUT = Easing.out(Easing.cubic);

/**
 * Move a value to `to` in the level's style: a springy bounce in Dopamine Mode,
 * a smooth ease-out (no overshoot) in Calm Mode.
 */
export function settle(to: number, level: MotionLevel, ms = 420): number {
  'worklet';
  if (level === 'dopamine') return withSpring(to, { stiffness: 380, damping: 14, mass: 0.9 });
  return withTiming(to, { duration: ms, easing: EASE_OUT });
}

/** Quick move toward a pose (the "squash" before the spring back). */
export function press(to: number, level: MotionLevel, ms = 110): number {
  'worklet';
  return withTiming(to, { duration: level === 'calm' ? ms * 1.8 : ms, easing: EASE_OUT });
}
