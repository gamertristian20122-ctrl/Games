import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from 'expo-audio';
import * as Haptics from 'expo-haptics';

/**
 * Soft sensory feedback.
 * - Calm Mode: silent and still-to-the-touch (no sounds, no vibration).
 * - Dopamine Mode: little synthesized marimba chimes and light haptics.
 * The chimes are synthesized offline into tiny WAV files (React Native has no Web Audio API).
 */

export interface FeedbackPrefs {
  calm: boolean;
  sounds: boolean;
  haptics: boolean;
}

export type Sfx = 'note' | 'chord' | 'levelup' | 'heart' | 'squish' | 'chew' | 'lullaby' | 'pop';

const SOURCES = {
  note1: require('../../assets/sounds/note1.wav'),
  note2: require('../../assets/sounds/note2.wav'),
  note3: require('../../assets/sounds/note3.wav'),
  note4: require('../../assets/sounds/note4.wav'),
  note5: require('../../assets/sounds/note5.wav'),
  chord: require('../../assets/sounds/chord.wav'),
  levelup: require('../../assets/sounds/levelup.wav'),
  heart: require('../../assets/sounds/heart.wav'),
  squish: require('../../assets/sounds/squish.wav'),
  chew: require('../../assets/sounds/chew.wav'),
  lullaby: require('../../assets/sounds/lullaby.wav'),
  pop: require('../../assets/sounds/pop.wav'),
} as const;

type SourceKey = keyof typeof SOURCES;

const players = new Map<SourceKey, AudioPlayer>();
let audioReady = false;
let noteIndex = 0;

async function ensureAudio(): Promise<void> {
  if (audioReady) return;
  audioReady = true;
  // Respect the silent switch and never interrupt the user's music or podcasts.
  await setAudioModeAsync({ playsInSilentMode: false, interruptionMode: 'mixWithOthers' }).catch(() => undefined);
}

function player(key: SourceKey): AudioPlayer {
  let p = players.get(key);
  if (!p) {
    p = createAudioPlayer(SOURCES[key]);
    p.volume = 0.55;
    players.set(key, p);
  }
  return p;
}

async function playKey(key: SourceKey): Promise<void> {
  await ensureAudio();
  const p = player(key);
  // Restarting the same short sound instead of layering keeps rapid taps from stacking up.
  await p.seekTo(0).catch(() => undefined);
  p.play();
}

/** Plays a chime. Each "note" walks up a gentle pentatonic scale so repeated check-offs sound musical. */
export function playSfx(sfx: Sfx, prefs: FeedbackPrefs): void {
  if (prefs.calm || !prefs.sounds) return;
  let key: SourceKey;
  if (sfx === 'note') {
    noteIndex = (noteIndex % 5) + 1;
    key = `note${noteIndex}` as SourceKey;
  } else {
    key = sfx;
  }
  playKey(key).catch(() => undefined);
}

export function haptic(kind: 'light' | 'success' | 'select', prefs: FeedbackPrefs): void {
  if (prefs.calm || !prefs.haptics) return;
  const run =
    kind === 'success'
      ? Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success)
      : kind === 'light'
        ? Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light)
        : Haptics.selectionAsync();
  run.catch(() => undefined);
}

export function stepFeedback(prefs: FeedbackPrefs): void {
  haptic('light', prefs);
  playSfx('note', prefs);
}

export function celebrateFeedback(prefs: FeedbackPrefs, sfx: Sfx = 'chord'): void {
  haptic('success', prefs);
  playSfx(sfx, prefs);
}

export function tapFeedback(prefs: FeedbackPrefs): void {
  haptic('select', prefs);
}
