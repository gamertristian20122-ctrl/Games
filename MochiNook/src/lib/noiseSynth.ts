/**
 * Ambient sound, generated in code (no audio files ship with the app).
 * React Native has no Web Audio API, so we synthesize the samples ourselves and
 * write a small looping WAV to the app's cache the first time it's needed.
 */

export type NoiseKind = 'brown' | 'rain';

/** Small, fast, seeded PRNG so the sound is identical every time (and testable). */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * Returns `seconds` of seamless-looping mono samples in [-1, 1].
 * The last half-second is cross-faded into the start so the loop has no click.
 */
export function synthNoise(kind: NoiseKind, seconds = 12, sampleRate = 22050, seed = 7): Float32Array {
  const n = Math.round(seconds * sampleRate);
  const fade = Math.round(0.5 * sampleRate);
  const total = n + fade;
  const raw = new Float32Array(total);
  const rnd = mulberry32(seed);

  if (kind === 'brown') {
    // Brown(ian) noise: integrated white noise. Deep and soft, like a distant waterfall.
    let b = 0;
    for (let i = 0; i < total; i++) {
      b = (b + 0.02 * (rnd() * 2 - 1)) / 1.02;
      raw[i] = b * 3.2;
    }
  } else {
    // Soft rain: gently low-passed noise with a slow swell, plus sparse quiet droplets.
    let lp = 0;
    let lp2 = 0;
    let drop = 0;
    let dropPhase = 0;
    let dropFreq = 0;
    for (let i = 0; i < total; i++) {
      const w = rnd() * 2 - 1;
      lp += 0.18 * (w - lp);
      lp2 += 0.5 * (lp - lp2);
      const swell = 0.75 + 0.25 * Math.sin((2 * Math.PI * i) / (sampleRate * 6));
      if (drop < 0.001 && rnd() < 9 / sampleRate) {
        drop = 0.12 + 0.12 * rnd();
        dropFreq = 1400 + 2200 * rnd();
        dropPhase = 0;
      }
      dropPhase += (2 * Math.PI * dropFreq) / sampleRate;
      const droplet = drop * Math.sin(dropPhase);
      drop *= 0.9965;
      raw[i] = lp2 * 1.6 * swell + droplet * 0.35;
    }
  }

  // Seamless loop: blend the tail into the head.
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    if (i < fade) {
      const t = i / fade;
      out[i] = raw[i]! * t + raw[n + i]! * (1 - t);
    } else {
      out[i] = raw[i]!;
    }
  }
  // Normalise to a gentle level so it never startles.
  let peak = 0;
  for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(out[i]!));
  const gain = peak > 0 ? 0.45 / peak : 0;
  for (let i = 0; i < n; i++) out[i] = out[i]! * gain;
  return out;
}

/** Packs samples into a 16-bit mono PCM WAV file. */
export function wavBytes(samples: Float32Array, sampleRate = 22050): Uint8Array {
  const dataLen = samples.length * 2;
  const buf = new ArrayBuffer(44 + dataLen);
  const v = new DataView(buf);
  const str = (o: number, s: string) => {
    for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i));
  };
  str(0, 'RIFF');
  v.setUint32(4, 36 + dataLen, true);
  str(8, 'WAVE');
  str(12, 'fmt ');
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); // PCM
  v.setUint16(22, 1, true); // mono
  v.setUint32(24, sampleRate, true);
  v.setUint32(28, sampleRate * 2, true);
  v.setUint16(32, 2, true);
  v.setUint16(34, 16, true);
  str(36, 'data');
  v.setUint32(40, dataLen, true);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]!));
    v.setInt16(44 + i * 2, Math.round(s * 32767), true);
  }
  return new Uint8Array(buf);
}
