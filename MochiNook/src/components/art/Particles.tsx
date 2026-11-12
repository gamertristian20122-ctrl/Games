import React, { useEffect } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Animated, {
  Easing,
  cancelAnimation,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { TUNING, type MotionLevel } from '../../theme/motion';
import { Glyph } from './Glyph';

/**
 * Tiny celebratory particles. Only transform + opacity are animated (GPU-friendly).
 * A burst is keyed by its id, so a new burst replaces the old one instead of piling up.
 */

export type BurstKind = 'hearts' | 'sparkles' | 'crumbs' | 'confetti';

const CONFETTI = ['#F6B7C6', '#F3DE9C', '#A8C3A0', '#BFD8E6', '#CDBFE6', '#F6C6A8'];

/** Deterministic "random" so renders stay pure and each burst looks a little different. */
function rand(seed: number, i: number, salt: number): number {
  const x = Math.sin(seed * 12.9898 + i * 78.233 + salt * 37.719) * 43758.5453;
  return x - Math.floor(x);
}

interface BurstProps {
  kind: BurstKind;
  level: Exclude<MotionLevel, 'still'>;
  /** Container size, so particles start from the right spots. */
  width: number;
  height: number;
  seed: number;
  count?: number;
  delay?: number;
}

export function Burst({ kind, level, width, height, seed, count, delay = 0 }: BurstProps) {
  const t = TUNING[level];
  const max = kind === 'confetti' ? (level === 'dopamine' ? 14 : 0) : t.particles;
  const n = Math.max(0, Math.min(count ?? max, max));
  if (n === 0) return null;
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      {Array.from({ length: n }, (_, i) => (
        <Particle key={i} i={i} n={n} kind={kind} level={level} width={width} height={height} seed={seed} delay={delay} />
      ))}
    </View>
  );
}

function Particle({
  i,
  n,
  kind,
  level,
  width,
  height,
  seed,
  delay,
}: {
  i: number;
  n: number;
  kind: BurstKind;
  level: Exclude<MotionLevel, 'still'>;
  width: number;
  height: number;
  seed: number;
  delay: number;
}) {
  const p = useSharedValue(0);
  const t = TUNING[level];
  const dur = kind === 'crumbs' ? t.particleMs * 0.6 : kind === 'confetti' ? t.particleMs * 1.3 : t.particleMs;

  useEffect(() => {
    p.value = withDelay(delay + i * (kind === 'confetti' ? 25 : 90), withTiming(1, { duration: dur, easing: Easing.out(Easing.quad) }));
    return () => cancelAnimation(p);
  }, [p, delay, i, kind, dur]);

  // Start points and paths per kind.
  const r1 = rand(seed, i, 1);
  const r2 = rand(seed, i, 2);
  const r3 = rand(seed, i, 3);
  let x0 = width / 2;
  let y0 = height * 0.35;
  let dx = 0;
  let rise = 0;
  let gravity = 0;
  if (kind === 'hearts') {
    x0 = width * (0.3 + 0.4 * r1);
    y0 = height * 0.3;
    dx = (r2 - 0.5) * 50;
    rise = level === 'calm' ? 45 : 70 + 30 * r3;
  } else if (kind === 'sparkles') {
    const a = (i / n) * Math.PI * 2 + r1;
    x0 = width / 2 + Math.cos(a) * width * 0.38;
    y0 = height * 0.48 + Math.sin(a) * height * 0.32;
    dx = Math.cos(a) * 14;
    rise = 18 + 14 * r2;
  } else if (kind === 'crumbs') {
    const a = Math.PI * (1.1 + 0.8 * (i / Math.max(1, n - 1))) + (r1 - 0.5) * 0.4;
    x0 = width / 2;
    y0 = height * 0.66;
    dx = Math.cos(a) * (30 + 20 * r2);
    rise = -Math.sin(a) * (24 + 16 * r3);
    gravity = 36;
  } else {
    const a = -Math.PI / 2 + (r1 - 0.5) * Math.PI * 1.3;
    x0 = width / 2;
    y0 = height * 0.3;
    dx = Math.cos(a) * (70 + 60 * r2);
    rise = -Math.sin(a) * (60 + 40 * r3);
    gravity = 140;
  }
  const spin = (r3 - 0.5) * 720;

  const style = useAnimatedStyle(() => {
    const v = p.value;
    const opacity = v < 0.15 ? v / 0.15 : 1 - (v - 0.15) / 0.85;
    const scale = kind === 'sparkles' ? Math.sin(v * Math.PI) * 1.1 : 0.6 + 0.4 * Math.min(1, v * 3);
    return {
      opacity,
      transform: [
        { translateX: dx * v },
        { translateY: -rise * v + gravity * v * v },
        { rotate: kind === 'confetti' ? `${spin * v}deg` : '0deg' },
        { scale },
      ],
    };
  });

  return (
    <Animated.View style={[styles.particle, { left: x0 - 9, top: y0 - 9 }, style]}>
      {kind === 'hearts' ? <Glyph name="heart" size={18} /> : null}
      {kind === 'sparkles' ? <Glyph name="sparkle" size={18} /> : null}
      {kind === 'crumbs' ? <View style={[styles.crumb, { backgroundColor: i % 2 ? '#DDB98F' : '#F3DE9C' }]} /> : null}
      {kind === 'confetti' ? <View style={[styles.confetti, { backgroundColor: CONFETTI[i % CONFETTI.length] }]} /> : null}
    </Animated.View>
  );
}

/** Slow drifting "z Z z" while the pet is tucked in. Static letters when motion is off. */
export function Zzz({ level, size }: { level: MotionLevel; size: number }) {
  if (level === 'still') {
    return (
      <View pointerEvents="none" style={[styles.zzzStill, { left: size * 0.72, top: size * 0.05 }]}>
        <Text style={[styles.z, { fontSize: 14 }]}>z</Text>
        <Text style={[styles.z, { fontSize: 20 }]}>Z</Text>
      </View>
    );
  }
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      {[0, 1, 2].map((i) => (
        <ZLetter key={i} i={i} level={level} size={size} />
      ))}
    </View>
  );
}

function ZLetter({ i, level, size }: { i: number; level: Exclude<MotionLevel, 'still'>; size: number }) {
  const p = useSharedValue(0);
  const dur = level === 'calm' ? 4200 : 3000;
  useEffect(() => {
    p.value = withDelay(i * (dur / 3), withRepeat(withTiming(1, { duration: dur, easing: Easing.inOut(Easing.sin) }), -1, false));
    return () => cancelAnimation(p);
  }, [p, i, dur]);
  const style = useAnimatedStyle(() => ({
    opacity: Math.sin(p.value * Math.PI),
    transform: [{ translateY: -46 * p.value }, { translateX: 10 * Math.sin(p.value * Math.PI * 2) }],
  }));
  return (
    <Animated.View style={[{ position: 'absolute', left: size * 0.68 + i * 12, top: size * 0.1 }, style]}>
      <Text style={[styles.z, { fontSize: 18 + i * 6 }]}>{i === 1 ? 'Z' : 'z'}</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  particle: { position: 'absolute', width: 18, height: 18, alignItems: 'center', justifyContent: 'center' },
  crumb: { width: 6, height: 6, borderRadius: 3 },
  confetti: { width: 7, height: 11, borderRadius: 2 },
  zzzStill: { position: 'absolute', flexDirection: 'row', alignItems: 'flex-end', gap: 2 },
  z: {
    color: '#7E6BB0',
    fontFamily: 'Nunito_800ExtraBold',
    textShadowColor: 'rgba(255,255,255,0.8)',
    textShadowRadius: 3,
    textShadowOffset: { width: 0, height: 0 },
  },
});
