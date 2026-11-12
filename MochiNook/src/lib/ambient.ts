import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from 'expo-audio';
import { File, Paths } from 'expo-file-system';
import { synthNoise, wavBytes, type NoiseKind } from './noiseSynth';

/**
 * Background sound for focus sprints. The audio is generated on the phone the first
 * time it's used (see noiseSynth.ts) and cached, so no sound files ship with the app.
 */

const VERSION = 1;
let player: AudioPlayer | null = null;
let current: NoiseKind | null = null;

async function ensureFile(kind: NoiseKind): Promise<string> {
  const file = new File(Paths.cache, `mochinook-${kind}-v${VERSION}.wav`);
  if (!file.exists) {
    await file.write(wavBytes(synthNoise(kind)));
  }
  return file.uri;
}

export async function playAmbient(kind: NoiseKind): Promise<void> {
  if (current === kind && player) {
    player.play();
    return;
  }
  stopAmbient();
  await setAudioModeAsync({ playsInSilentMode: true, interruptionMode: 'mixWithOthers' }).catch(() => undefined);
  const uri = await ensureFile(kind);
  const p = createAudioPlayer({ uri });
  p.loop = true;
  p.volume = 0.6;
  p.play();
  player = p;
  current = kind;
}

export function stopAmbient(): void {
  if (player) {
    player.pause();
    player.remove();
  }
  player = null;
  current = null;
}
