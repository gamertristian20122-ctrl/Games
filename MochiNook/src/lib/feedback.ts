import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from 'expo-audio';
import * as Haptics from 'expo-haptics';

/** Soft sensory feedback. Calm Mode turns all of it off. */

export interface FeedbackPrefs {
  calm: boolean;
  sounds: boolean;
  haptics: boolean;
}

const players: { pop: AudioPlayer | null; levelup: AudioPlayer | null } = { pop: null, levelup: null };
let audioReady = false;

async function ensureAudio(): Promise<void> {
  if (audioReady) return;
  audioReady = true;
  // Respect the silent switch and never interrupt the user's music or podcasts.
  await setAudioModeAsync({ playsInSilentMode: false, interruptionMode: 'mixWithOthers' }).catch(() => undefined);
  players.pop = createAudioPlayer(require('../../assets/sounds/pop.wav'));
  players.levelup = createAudioPlayer(require('../../assets/sounds/levelup.wav'));
  players.pop.volume = 0.5;
  players.levelup.volume = 0.5;
}

async function play(which: 'pop' | 'levelup'): Promise<void> {
  await ensureAudio();
  const p = players[which];
  if (!p) return;
  await p.seekTo(0).catch(() => undefined);
  p.play();
}

export function stepFeedback(prefs: FeedbackPrefs): void {
  if (prefs.calm) return;
  if (prefs.haptics) Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => undefined);
  if (prefs.sounds) play('pop').catch(() => undefined);
}

export function celebrateFeedback(prefs: FeedbackPrefs): void {
  if (prefs.calm) return;
  if (prefs.haptics) Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => undefined);
  if (prefs.sounds) play('levelup').catch(() => undefined);
}

export function tapFeedback(prefs: FeedbackPrefs): void {
  if (prefs.calm || !prefs.haptics) return;
  Haptics.selectionAsync().catch(() => undefined);
}
