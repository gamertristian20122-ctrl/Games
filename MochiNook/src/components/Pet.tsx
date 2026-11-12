import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Animated, {
  Easing,
  cancelAnimation,
  useAnimatedProps,
  useAnimatedStyle,
  useSharedValue,
  withDelay,
  withRepeat,
  withSequence,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import Svg, { Circle, Ellipse, G, Line, Path, Rect } from 'react-native-svg';
import { findColor } from '../data/cosmetics';
import { TUNING, press, settle, type MotionLevel } from '../theme/motion';
import { Burst, Zzz, type BurstKind } from './art/Particles';

export type PetMood = 'idle' | 'happy' | 'sleepy' | 'proud' | 'chew';
export type PetReactionType = 'hop' | 'bigHop' | 'pat' | 'snack' | 'pop' | 'squish';
export interface PetReaction {
  id: number;
  type: PetReactionType;
}

const INK = '#3E3833';
const AnimatedEllipse = Animated.createAnimatedComponent(Ellipse);
const AnimatedCircle = Animated.createAnimatedComponent(Circle);

/** Shared values that drive the face (eyes, ears, cheeks) on the UI thread. */
interface FaceAnim {
  eyeOpen: SharedValue<number>;
  earL: SharedValue<number>;
  earR: SharedValue<number>;
  blush: SharedValue<number>;
}

function Hat({ id }: { id: string }) {
  switch (id) {
    case 'sprout':
      return (
        <G>
          <Path d="M100 50 C100 40 101 32 100 24" stroke="#6E9A62" strokeWidth={4} strokeLinecap="round" fill="none" />
          <Path d="M100 30 C90 18 76 20 74 28 C84 34 94 34 100 30 Z" fill="#9CC48E" stroke="#6E9A62" strokeWidth={2} />
          <Path d="M100 26 C108 12 124 12 127 20 C118 28 108 29 100 26 Z" fill="#B3D5A6" stroke="#6E9A62" strokeWidth={2} />
        </G>
      );
    case 'beanie':
      return (
        <G>
          <Path d="M44 78 C44 30 156 30 156 78 Z" fill="#F4B9A0" stroke="#D99579" strokeWidth={2.5} />
          <Rect x={40} y={70} width={120} height={16} rx={8} fill="#F8CDB9" stroke="#D99579" strokeWidth={2.5} />
          {[56, 72, 88, 104, 120, 136].map((x) => (
            <Line key={x} x1={x + 4} y1={73} x2={x + 4} y2={83} stroke="#E3A68D" strokeWidth={2} strokeLinecap="round" />
          ))}
          <Circle cx={100} cy={34} r={11} fill="#FCE3D6" stroke="#D99579" strokeWidth={2.5} />
        </G>
      );
    case 'flowers':
      return (
        <G>
          <Path d="M52 64 Q100 36 148 64" stroke="#8DB07F" strokeWidth={4} fill="none" strokeLinecap="round" />
          {[
            [56, 60, '#F6B7C6'],
            [76, 49, '#FBE29A'],
            [100, 45, '#CDBFE6'],
            [124, 49, '#F6B7C6'],
            [144, 60, '#FBE29A'],
          ].map(([x, y, fill]) => (
            <G key={`${x}`}>
              {[0, 72, 144, 216, 288].map((a) => {
                const r = (Number(a) * Math.PI) / 180;
                return <Circle key={a} cx={Number(x) + Math.cos(r) * 6} cy={Number(y) + Math.sin(r) * 6} r={5} fill={String(fill)} />;
              })}
              <Circle cx={Number(x)} cy={Number(y)} r={3.5} fill="#F4D06F" />
            </G>
          ))}
        </G>
      );
    case 'party':
      return (
        <G>
          <Path d="M78 56 L100 6 L122 56 Z" fill="#BFD8E6" stroke="#8FAEC0" strokeWidth={2.5} strokeLinejoin="round" />
          <Path d="M85 40 L115 40 M91 26 L109 26" stroke="#F6B7C6" strokeWidth={4} strokeLinecap="round" />
          <Circle cx={100} cy={7} r={7} fill="#FBE29A" stroke="#D9BE62" strokeWidth={2} />
        </G>
      );
    case 'wizard':
      return (
        <G>
          <Path d="M66 60 L108 -2 L132 60 Z" fill="#B6A6D8" stroke="#8F7FB5" strokeWidth={2.5} strokeLinejoin="round" />
          <Ellipse cx={100} cy={60} rx={52} ry={9} fill="#C9BCE6" stroke="#8F7FB5" strokeWidth={2.5} />
          <Path d="M100 30 l2.5 5 5.5 .8 -4 3.9 1 5.5 -5 -2.6 -5 2.6 1 -5.5 -4 -3.9 5.5 -.8 z" fill="#FBE29A" />
          <Circle cx={116} cy={44} r={2.5} fill="#FBE29A" />
          <Circle cx={92} cy={48} r={2} fill="#FBE29A" />
        </G>
      );
    case 'frog':
      return (
        <G>
          <Path d="M36 92 C34 44 166 44 164 92 C150 76 50 76 36 92 Z" fill="#A9CF98" stroke="#7FA86F" strokeWidth={2.5} />
          <Circle cx={70} cy={50} r={15} fill="#A9CF98" stroke="#7FA86F" strokeWidth={2.5} />
          <Circle cx={130} cy={50} r={15} fill="#A9CF98" stroke="#7FA86F" strokeWidth={2.5} />
          <Circle cx={70} cy={50} r={7} fill="#FFFDF8" />
          <Circle cx={130} cy={50} r={7} fill="#FFFDF8" />
          <Circle cx={71} cy={51} r={3.5} fill={INK} />
          <Circle cx={131} cy={51} r={3.5} fill={INK} />
        </G>
      );
    case 'bow':
      return (
        <G>
          <Path d="M132 52 C118 36 112 58 132 58 Z" fill="#F6B7C6" stroke="#D98EA0" strokeWidth={2.5} strokeLinejoin="round" />
          <Path d="M132 52 C146 36 152 58 132 58 Z" fill="#F6B7C6" stroke="#D98EA0" strokeWidth={2.5} strokeLinejoin="round" />
          <Circle cx={132} cy={55} r={5} fill="#F9CCD7" stroke="#D98EA0" strokeWidth={2} />
        </G>
      );
    case 'acorn':
      return (
        <G>
          <Path d="M52 70 C52 34 148 34 148 70 Z" fill="#B88456" stroke="#8C5E36" strokeWidth={2.5} />
          <Path d="M60 62 h80 M66 52 h68 M76 43 h48" stroke="#9C6B42" strokeWidth={2} strokeLinecap="round" />
          <Path d="M100 38 C100 28 104 22 110 20" stroke="#6E4A2A" strokeWidth={4} strokeLinecap="round" fill="none" />
        </G>
      );
    case 'earmuffs':
      return (
        <G>
          <Path d="M50 62 C50 22 150 22 150 62" stroke="#A6CBCF" strokeWidth={6} fill="none" strokeLinecap="round" />
          <Circle cx={50} cy={66} r={17} fill="#FFFDF8" stroke="#A6CBCF" strokeWidth={3} />
          <Circle cx={150} cy={66} r={17} fill="#FFFDF8" stroke="#A6CBCF" strokeWidth={3} />
          <Circle cx={50} cy={66} r={7} fill="#E6F3F4" />
          <Circle cx={150} cy={66} r={7} fill="#E6F3F4" />
        </G>
      );
    case 'blossom':
      return (
        <G>
          {[0, 72, 144, 216, 288].map((a) => {
            const r = (a * Math.PI) / 180;
            return <Circle key={a} cx={134 + Math.cos(r) * 8} cy={50 + Math.sin(r) * 8} r={7} fill="#F9C5D5" stroke="#E4A3B8" strokeWidth={1.5} />;
          })}
          <Circle cx={134} cy={50} r={4.5} fill="#F4D06F" />
          <Path d="M116 44 q-6 -10 -2 -16" stroke="#8DB07F" strokeWidth={3} strokeLinecap="round" fill="none" />
        </G>
      );
    case 'sunhat':
      return (
        <G>
          <Ellipse cx={100} cy={58} rx={70} ry={13} fill="#F1D9A4" stroke="#C9A762" strokeWidth={2.5} />
          <Path d="M66 58 C66 26 134 26 134 58 Z" fill="#F6E3B4" stroke="#C9A762" strokeWidth={2.5} />
          <Path d="M67 52 Q100 60 133 52" stroke="#F6B7C6" strokeWidth={6} fill="none" />
        </G>
      );
    default:
      return null;
  }
}

function Scarf({ id }: { id: string }) {
  if (id === 'none') return null;
  const palette: Record<string, [string, string]> = {
    sage: ['#A8C3A0', '#7E9C76'],
    peach: ['#F6C6A8', '#D99F7F'],
    stripes: ['#CDBFE6', '#9D8CC4'],
    butter: ['#F3DE9C', '#C9B15F'],
    maple: ['#E9A06A', '#B9703F'],
    snowy: ['#F4F8FA', '#A6CBCF'],
    petal: ['#F9C5D5', '#D98EA0'],
    sunny: ['#FBE29A', '#D9BE62'],
  };
  const [fill, stroke] = palette[id] ?? palette.sage!;
  return (
    <G>
      <Path d="M30 138 Q100 162 170 138 L172 154 Q100 178 28 154 Z" fill={fill} stroke={stroke} strokeWidth={2.5} strokeLinejoin="round" />
      <Path d="M128 156 L140 186 L124 188 L116 160 Z" fill={fill} stroke={stroke} strokeWidth={2.5} strokeLinejoin="round" />
      {id === 'stripes' || id === 'sunny' ? (
        <G>
          <Path d="M56 146 L58 162 M84 151 L85 168 M116 151 L115 168 M144 146 L142 162" stroke="#FFFDF8" strokeWidth={4} strokeLinecap="round" />
        </G>
      ) : (
        <Path d="M40 148 Q100 168 160 148" stroke={stroke} strokeWidth={1.5} strokeDasharray="3 5" fill="none" />
      )}
    </G>
  );
}


// ---------- face parts (static or animated) ----------

function OpenEyes({ ink, shine, anim }: { ink: string; shine: string; anim?: FaceAnim }) {
  if (!anim) {
    return (
      <G>
        <Ellipse cx={76} cy={110} rx={6.5} ry={8.5} fill={ink} />
        <Ellipse cx={124} cy={110} rx={6.5} ry={8.5} fill={ink} />
        <Circle cx={78.5} cy={106.5} r={2.4} fill={shine} />
        <Circle cx={126.5} cy={106.5} r={2.4} fill={shine} />
      </G>
    );
  }
  return (
    <G>
      <AnimEye cx={76} ink={ink} anim={anim} />
      <AnimEye cx={124} ink={ink} anim={anim} />
      <AnimShine cx={78.5} fill={shine} anim={anim} />
      <AnimShine cx={126.5} fill={shine} anim={anim} />
    </G>
  );
}

/** Blink = squash the eye ellipse vertically (ry 8.5 → ~0.85). */
function AnimEye({ cx, ink, anim }: { cx: number; ink: string; anim: FaceAnim }) {
  const props = useAnimatedProps(() => ({ ry: 8.5 * Math.max(0.1, anim.eyeOpen.value) }));
  return <AnimatedEllipse cx={cx} cy={110} rx={6.5} ry={8.5} fill={ink} animatedProps={props} />;
}

function AnimShine({ cx, fill, anim }: { cx: number; fill: string; anim: FaceAnim }) {
  const props = useAnimatedProps(() => ({ opacity: anim.eyeOpen.value > 0.55 ? 1 : 0 }));
  return <AnimatedCircle cx={cx} cy={106.5} r={2.4} fill={fill} animatedProps={props} />;
}

function Ear({ cx, side, fill, stroke, anim }: { cx: number; side: -1 | 1; fill: string; stroke: string; anim?: FaceAnim }) {
  if (!anim) return <Circle cx={cx} cy={60} r={17} fill={fill} stroke={stroke} strokeWidth={3} />;
  return <AnimEar cx={cx} side={side} fill={fill} stroke={stroke} anim={anim} />;
}

/** Ear twitch: a tiny hop up-and-out. */
function AnimEar({ cx, side, fill, stroke, anim }: { cx: number; side: -1 | 1; fill: string; stroke: string; anim: FaceAnim }) {
  const props = useAnimatedProps(() => {
    const v = side === -1 ? anim.earL.value : anim.earR.value;
    return { cy: 60 - 5 * v, cx: cx + side * 2.5 * v };
  });
  return <AnimatedCircle cx={cx} cy={60} r={17} fill={fill} stroke={stroke} strokeWidth={3} animatedProps={props} />;
}

function Blush({ cx, fill, base, anim }: { cx: number; fill: string; base: number; anim?: FaceAnim }) {
  if (!anim) return <Ellipse cx={cx} cy={128} rx={12} ry={6.5} fill={fill} opacity={base} />;
  return <AnimBlush cx={cx} fill={fill} base={base} anim={anim} />;
}

/** Happy blush: cheeks glow pinker and a little wider. */
function AnimBlush({ cx, fill, base, anim }: { cx: number; fill: string; base: number; anim: FaceAnim }) {
  const props = useAnimatedProps(() => ({
    opacity: Math.min(1, base + 0.4 * anim.blush.value),
    rx: 12 + 4 * anim.blush.value,
    ry: 6.5 + 1.5 * anim.blush.value,
  }));
  return <AnimatedEllipse cx={cx} cy={128} rx={12} ry={6.5} fill={fill} opacity={base} animatedProps={props} />;
}

function ClosedEyes({ ink, happy }: { ink: string; happy: boolean }) {
  const d = happy ? ['M68 114 Q76 102 84 114', 'M116 114 Q124 102 132 114'] : ['M68 110 Q76 118 84 110', 'M116 110 Q124 118 132 110'];
  return (
    <G>
      <Path d={d[0]!} stroke={ink} strokeWidth={4.5} strokeLinecap="round" fill="none" />
      <Path d={d[1]!} stroke={ink} strokeWidth={4.5} strokeLinecap="round" fill="none" />
    </G>
  );
}

/** The pet as a drawing. Pass `anim` to let the face blink, twitch and blush on the UI thread. */
export function PetSvg({
  color,
  hat,
  scarf,
  mood,
  size,
  anim,
}: {
  color: string;
  hat: string;
  scarf: string;
  mood: PetMood;
  size: number;
  anim?: FaceAnim;
}) {
  const col = findColor(color);
  const dark = col.id === 'sesame';
  const ink = dark ? '#F4EDE4' : INK;
  const shine = dark ? INK : '#FFFFFF';
  const h = size * 0.95;
  const happy = mood === 'happy' || mood === 'proud' || mood === 'chew';
  const blushBase = mood === 'idle' || mood === 'sleepy' ? 0.6 : 0.85;
  return (
    <Svg width={size} height={h} viewBox="0 0 200 190">
      <Ellipse cx={100} cy={176} rx={60} ry={7} fill="#5C4632" opacity={0.12} />
      <Ear cx={58} side={-1} fill={col.ear} stroke={col.outline} anim={anim} />
      <Ear cx={142} side={1} fill={col.ear} stroke={col.outline} anim={anim} />
      <Path
        d="M100 46 C152 46 180 82 180 120 C180 154 150 172 100 172 C50 172 20 154 20 120 C20 82 48 46 100 46 Z"
        fill={col.body}
        stroke={col.outline}
        strokeWidth={3}
      />
      <Ellipse cx={74} cy={74} rx={16} ry={8} fill="#FFFFFF" opacity={dark ? 0.12 : 0.5} transform="rotate(-18 74 74)" />
      <Blush cx={58} fill={col.blush} base={blushBase} anim={anim} />
      <Blush cx={142} fill={col.blush} base={blushBase} anim={anim} />
      {mood === 'idle' ? <OpenEyes ink={ink} shine={shine} anim={anim} /> : <ClosedEyes ink={ink} happy={happy} />}
      {mood === 'chew' ? (
        <Ellipse cx={100} cy={129} rx={6} ry={4.5} fill="#C9706B" stroke={ink} strokeWidth={2.2} />
      ) : happy ? (
        <Path d="M90 124 Q100 140 110 124 Z" fill="#C9706B" stroke={ink} strokeWidth={2.5} strokeLinejoin="round" />
      ) : (
        <Path d="M93 126 Q100 132 107 126" stroke={ink} strokeWidth={3.5} strokeLinecap="round" fill="none" />
      )}
      <Scarf id={scarf} />
      <Hat id={hat} />
      {mood === 'proud' ? (
        <G>
          <Path d="M28 44 l3 7 7 1 -5 5 1 7 -6 -3 -6 3 1 -7 -5 -5 7 -1 z" fill="#FBE29A" />
          <Path d="M168 70 l2 5 5 .7 -3.6 3.5 .9 5 -4.3 -2.3 -4.3 2.3 .9 -5 -3.6 -3.5 5 -.7 z" fill="#F6B7C6" />
        </G>
      ) : null}
    </Svg>
  );
}

/** A soft quilted blanket that slides over the lower half of the pet when tucked in. */
function Blanket({ size }: { size: number }) {
  return (
    <Svg width={size} height={size * 0.42} viewBox="0 0 200 84">
      <Path d="M14 30 Q100 6 186 30 L190 76 Q100 92 10 76 Z" fill="#CDBFE6" stroke="#9D8CC4" strokeWidth={3} strokeLinejoin="round" />
      <Path d="M14 30 Q100 6 186 30 L186 40 Q100 18 14 40 Z" fill="#E9E1F6" stroke="#9D8CC4" strokeWidth={2} strokeLinejoin="round" />
      <Line x1={70} y1={34} x2={66} y2={80} stroke="#B6A6D8" strokeWidth={2} strokeDasharray="4 5" />
      <Line x1={130} y1={34} x2={134} y2={80} stroke="#B6A6D8" strokeWidth={2} strokeDasharray="4 5" />
      <Rect x={92} y={50} width={16} height={16} rx={4} fill="#F6B7C6" opacity={0.8} transform="rotate(45 100 58)" />
    </Svg>
  );
}

// ---------- the living pet ----------

interface Props {
  color: string;
  hat: string;
  scarf: string;
  mood: PetMood;
  size?: number;
  /** still (Reduce motion) · calm · dopamine. */
  level: MotionLevel;
  /** Change the id to play a reaction. A new reaction interrupts the previous one. */
  reaction?: PetReaction | null;
  /** Blanket on, sleepy, z's floating. */
  tucked?: boolean;
  /** Body-double focus: gentle rhythmic bob. */
  focus?: boolean;
  /** Tap-to-squish (on by default). */
  tappable?: boolean;
  onTap?: () => void;
}

const BURST_FOR: Record<PetReactionType, BurstKind> = {
  hop: 'sparkles',
  bigHop: 'confetti',
  pat: 'hearts',
  snack: 'crumbs',
  pop: 'sparkles',
  squish: 'hearts',
};

export function Pet({ color, hat, scarf, mood, size = 200, level, reaction = null, tucked = false, focus = false, tappable = true, onTap }: Props) {
  const t = level === 'still' ? null : TUNING[level];
  const h = size * 0.95;

  const breathe = useSharedValue(0);
  const sx = useSharedValue(1);
  const sy = useSharedValue(1);
  const rot = useSharedValue(0);
  const hopY = useSharedValue(0);
  const bob = useSharedValue(0);
  const blanket = useSharedValue(tucked ? 1 : 0);
  const eyeOpen = useSharedValue(1);
  const earL = useSharedValue(0);
  const earR = useSharedValue(0);
  const blush = useSharedValue(0);
  const anim: FaceAnim = { eyeOpen, earL, earR, blush };
  const [tap, setTap] = useState<PetReaction | null>(null);

  // Breathing: a slow squash-and-stretch so the mochi feels alive.
  useEffect(() => {
    if (!t) {
      cancelAnimation(breathe);
      breathe.value = 0;
      return;
    }
    breathe.value = 0;
    breathe.value = withRepeat(withTiming(1, { duration: t.breatheMs / 2, easing: Easing.inOut(Easing.sin) }), -1, true);
    return () => cancelAnimation(breathe);
  }, [t, breathe]);

  // Focus pose: a gentle rhythmic bob while working side by side.
  useEffect(() => {
    if (!t || !focus) {
      cancelAnimation(bob);
      bob.value = 0;
      return;
    }
    bob.value = withRepeat(withTiming(-3, { duration: level === 'calm' ? 2400 : 1600, easing: Easing.inOut(Easing.sin) }), -1, true);
    return () => cancelAnimation(bob);
  }, [t, focus, level, bob]);

  // Organic blinks every few seconds, plus the occasional ear twitch.
  useEffect(() => {
    if (!t) return;
    let blinkTimer: ReturnType<typeof setTimeout>;
    let earTimer: ReturnType<typeof setTimeout>;
    const scheduleBlink = () => {
      blinkTimer = setTimeout(() => {
        eyeOpen.value = withSequence(withTiming(0.1, { duration: 70 }), withTiming(1, { duration: 130 }));
        scheduleBlink();
      }, t.blinkMinMs + Math.random() * (t.blinkMaxMs - t.blinkMinMs));
    };
    const scheduleEar = () => {
      earTimer = setTimeout(() => {
        const ear = Math.random() < 0.5 ? earL : earR;
        ear.value = withSequence(withTiming(1, { duration: 90 }), withTiming(0, { duration: level === 'calm' ? 320 : 180 }));
        scheduleEar();
      }, 6000 + Math.random() * 6000);
    };
    scheduleBlink();
    scheduleEar();
    return () => {
      clearTimeout(blinkTimer);
      clearTimeout(earTimer);
    };
  }, [t, level, eyeOpen, earL, earR]);

  // Tucked in: the blanket slides up and the body settles a little.
  useEffect(() => {
    if (!t) {
      blanket.value = tucked ? 1 : 0;
      return;
    }
    blanket.value = withTiming(tucked ? 1 : 0, { duration: level === 'calm' ? 900 : 600, easing: Easing.out(Easing.cubic) });
  }, [tucked, t, level, blanket]);

  /** Runs a reaction on the UI thread. Assigning new animations cancels running ones, so nothing queues up. */
  const run = (type: PetReactionType) => {
    if (!t || level === 'still') {
      return;
    }
    const lv = level;
    blush.value = withSequence(withTiming(1, { duration: 150 }), withDelay(type === 'pat' ? 1400 : 600, withTiming(0, { duration: 700 })));
    switch (type) {
      case 'squish':
        sx.value = withSequence(press(t.squishX, lv), settle(1, lv));
        sy.value = withSequence(press(t.squishY, lv), settle(1, lv));
        break;
      case 'pop':
        sx.value = withSequence(press(1.1, lv, 90), settle(1, lv));
        sy.value = withSequence(press(1.1, lv, 90), settle(1, lv));
        hopY.value = withSequence(press(t.hop * 0.5, lv, 120), settle(0, lv));
        break;
      case 'hop':
      case 'bigHop': {
        const up = type === 'bigHop' ? t.hop * 1.4 : t.hop;
        const air = lv === 'calm' ? 260 : 170;
        // anticipation squash → jump → squash on landing → spring back
        sy.value = withSequence(press(0.94, lv, 70), withTiming(1.04, { duration: air }), press(lv === 'calm' ? 0.93 : 0.86, lv, 80), settle(1, lv));
        sx.value = withSequence(press(1.04, lv, 70), withTiming(0.97, { duration: air }), press(lv === 'calm' ? 1.05 : 1.12, lv, 80), settle(1, lv));
        hopY.value = withSequence(
          withTiming(0, { duration: 70 }),
          withTiming(up, { duration: air, easing: Easing.out(Easing.quad) }),
          withTiming(0, { duration: air * 0.9, easing: Easing.in(Easing.quad) }),
          withTiming(0, { duration: 80 }),
        );
        break;
      }
      case 'pat':
        rot.value = withSequence(
          withTiming(-3, { duration: lv === 'calm' ? 320 : 180, easing: Easing.out(Easing.quad) }),
          withTiming(2, { duration: lv === 'calm' ? 360 : 220, easing: Easing.inOut(Easing.quad) }),
          settle(0, lv, 400),
        );
        sy.value = withSequence(press(0.96, lv, 160), settle(1, lv));
        break;
      case 'snack': {
        // Wait for the snack to arrive, then three happy chews.
        const chew = (n: number) =>
          withSequence(withTiming(n, { duration: lv === 'calm' ? 220 : 140 }), withTiming(1, { duration: lv === 'calm' ? 220 : 140 }));
        sy.value = withDelay(650, withSequence(chew(0.93), chew(0.95), chew(0.93), settle(1, lv)));
        sx.value = withDelay(650, withSequence(chew(1.05), chew(1.04), chew(1.05), settle(1, lv)));
        break;
      }
    }
  };

  useEffect(() => {
    if (reaction) run(reaction.type);
    // Only a NEW reaction id should start an animation.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reaction?.id]);

  const onPress = () => {
    run('squish');
    setTap({ id: Date.now(), type: 'squish' });
    onTap?.();
  };

  const bx = t?.breatheX ?? 0;
  const by = t?.breatheY ?? 0;
  const bodyStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: hopY.value + bob.value },
      { rotate: `${rot.value}deg` },
      { scaleX: (1 - breathe.value * bx) * sx.value },
      { scaleY: (1 + breathe.value * by) * sy.value },
    ],
  }));
  const blanketStyle = useAnimatedStyle(() => ({
    opacity: blanket.value,
    transform: [{ translateY: (1 - blanket.value) * 26 }],
  }));

  const body = (
    <Animated.View style={[{ width: size, height: h, transformOrigin: '50% 100%' }, bodyStyle]}>
      <PetSvg color={color} hat={hat} scarf={scarf} mood={tucked ? 'sleepy' : mood} size={size} anim={t ? anim : undefined} />
    </Animated.View>
  );

  return (
    <View style={{ width: size, height: h }}>
      {tappable ? (
        <Pressable accessibilityRole="button" accessibilityLabel="Squish your pet" accessibilityHint="A gentle squish. Just for fun." onPress={onPress}>
          {body}
        </Pressable>
      ) : (
        body
      )}
      <Animated.View pointerEvents="none" style={[styles.blanket, { top: h * 0.56, width: size, height: size * 0.42 }, blanketStyle]}>
        <Blanket size={size} />
      </Animated.View>
      {tucked ? <Zzz level={level} size={size} /> : null}
      {t && level !== 'still' && reaction ? (
        <Burst
          key={`r${reaction.id}`}
          kind={BURST_FOR[reaction.type]}
          level={level}
          width={size}
          height={h}
          seed={reaction.id}
          delay={reaction.type === 'snack' ? 650 : reaction.type === 'hop' || reaction.type === 'bigHop' ? 250 : 0}
        />
      ) : null}
      {t && level !== 'still' && tap ? (
        <Burst key={`t${tap.id}`} kind={level === 'dopamine' ? 'sparkles' : 'hearts'} level={level} width={size} height={h} seed={tap.id} count={level === 'dopamine' ? 3 : 1} />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  blanket: { position: 'absolute', left: 0 },
});
