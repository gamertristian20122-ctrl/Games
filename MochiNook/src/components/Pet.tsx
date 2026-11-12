import React, { useEffect, useState } from 'react';
import Animated, {
  Easing,
  cancelAnimation,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withSequence,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Circle, Ellipse, G, Line, Path, Rect } from 'react-native-svg';
import { findColor } from '../data/cosmetics';

export type PetMood = 'idle' | 'happy' | 'sleepy' | 'proud';

interface Props {
  color: string;
  hat: string;
  scarf: string;
  mood: PetMood;
  size?: number;
  /** When false the pet is a still illustration (Calm Mode / reduce motion). */
  animate: boolean;
  /** Change this number to trigger a happy hop. */
  hopKey?: number;
}

const INK = '#3E3833';

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

function Eyes({ mood, blink }: { mood: PetMood; blink: boolean }) {
  if (mood === 'happy' || mood === 'proud') {
    return (
      <G>
        <Path d="M68 114 Q76 102 84 114" stroke={INK} strokeWidth={4.5} strokeLinecap="round" fill="none" />
        <Path d="M116 114 Q124 102 132 114" stroke={INK} strokeWidth={4.5} strokeLinecap="round" fill="none" />
      </G>
    );
  }
  if (mood === 'sleepy' || blink) {
    return (
      <G>
        <Path d="M68 110 Q76 118 84 110" stroke={INK} strokeWidth={4.5} strokeLinecap="round" fill="none" />
        <Path d="M116 110 Q124 118 132 110" stroke={INK} strokeWidth={4.5} strokeLinecap="round" fill="none" />
      </G>
    );
  }
  return (
    <G>
      <Ellipse cx={76} cy={110} rx={6.5} ry={8.5} fill={INK} />
      <Ellipse cx={124} cy={110} rx={6.5} ry={8.5} fill={INK} />
      <Circle cx={78.5} cy={106.5} r={2.4} fill="#FFFFFF" />
      <Circle cx={126.5} cy={106.5} r={2.4} fill="#FFFFFF" />
    </G>
  );
}

export function Pet({ color, hat, scarf, mood, size = 200, animate, hopKey = 0 }: Props) {
  const col = findColor(color);
  const [blink, setBlink] = useState(false);
  const float = useSharedValue(0);
  const hop = useSharedValue(0);
  const squish = useSharedValue(1);

  // Idle float: slow, small, and only when motion is allowed.
  useEffect(() => {
    if (!animate) {
      cancelAnimation(float);
      float.value = 0;
      return;
    }
    float.value = withRepeat(withTiming(-5, { duration: 1800, easing: Easing.inOut(Easing.sin) }), -1, true);
    return () => cancelAnimation(float);
  }, [animate, float]);

  // Happy hop when a step is completed.
  useEffect(() => {
    if (!animate || hopKey === 0) return;
    squish.value = withSequence(withTiming(0.92, { duration: 110 }), withSpring(1, { damping: 7, stiffness: 180 }));
    hop.value = withSequence(withTiming(-16, { duration: 160, easing: Easing.out(Easing.quad) }), withSpring(0, { damping: 9, stiffness: 160 }));
  }, [hopKey, animate, hop, squish]);

  // Gentle blink every few seconds.
  useEffect(() => {
    if (!animate || mood !== 'idle') return;
    let timer: ReturnType<typeof setTimeout>;
    const schedule = () => {
      timer = setTimeout(() => {
        setBlink(true);
        timer = setTimeout(() => {
          setBlink(false);
          schedule();
        }, 140);
      }, 3200 + Math.random() * 2400);
    };
    schedule();
    return () => clearTimeout(timer);
  }, [animate, mood]);

  const style = useAnimatedStyle(() => ({
    transform: [{ translateY: float.value + hop.value }, { scaleY: squish.value }, { scaleX: 2 - squish.value }],
  }));

  const showBlink = blink && animate && mood === 'idle';
  const h = size * 0.95;
  return (
    <Animated.View
      style={[{ width: size, height: h }, style]}
      accessible
      accessibilityRole="image"
      accessibilityLabel={mood === 'sleepy' ? 'Your pet, cozy and sleepy' : mood === 'idle' ? 'Your pet, smiling' : 'Your pet, very happy'}
    >
      <Svg width={size} height={h} viewBox="0 0 200 190">
        <Ellipse cx={100} cy={176} rx={60} ry={7} fill="#5C4632" opacity={0.12} />
        <Circle cx={58} cy={60} r={17} fill={col.ear} stroke={col.outline} strokeWidth={3} />
        <Circle cx={142} cy={60} r={17} fill={col.ear} stroke={col.outline} strokeWidth={3} />
        <Path
          d="M100 46 C152 46 180 82 180 120 C180 154 150 172 100 172 C50 172 20 154 20 120 C20 82 48 46 100 46 Z"
          fill={col.body}
          stroke={col.outline}
          strokeWidth={3}
        />
        <Ellipse cx={74} cy={74} rx={16} ry={8} fill="#FFFFFF" opacity={col.id === 'sesame' ? 0.12 : 0.5} transform="rotate(-18 74 74)" />
        <Ellipse cx={58} cy={128} rx={12} ry={6.5} fill={col.blush} opacity={mood === 'idle' ? 0.6 : 0.85} />
        <Ellipse cx={142} cy={128} rx={12} ry={6.5} fill={col.blush} opacity={mood === 'idle' ? 0.6 : 0.85} />
        <G>{col.id === 'sesame' ? <EyesLight mood={mood} blink={showBlink} /> : <Eyes mood={mood} blink={showBlink} />}</G>
        {mood === 'happy' || mood === 'proud' ? (
          <Path d="M90 124 Q100 140 110 124 Z" fill="#C9706B" stroke={col.id === 'sesame' ? '#F4EDE4' : INK} strokeWidth={2.5} strokeLinejoin="round" />
        ) : (
          <Path d="M93 126 Q100 132 107 126" stroke={col.id === 'sesame' ? '#F4EDE4' : INK} strokeWidth={3.5} strokeLinecap="round" fill="none" />
        )}
        <Scarf id={scarf} />
        <Hat id={hat} />
        {mood === 'sleepy' ? (
          <G>
            <Path d="M154 40 h10 l-10 10 h10" stroke="#9D8CC4" strokeWidth={3} strokeLinecap="round" strokeLinejoin="round" fill="none" />
            <Path d="M170 22 h7 l-7 7 h7" stroke="#B6A6D8" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" fill="none" />
          </G>
        ) : null}
        {mood === 'proud' ? (
          <G>
            <Path d="M28 44 l3 7 7 1 -5 5 1 7 -6 -3 -6 3 1 -7 -5 -5 7 -1 z" fill="#FBE29A" />
            <Path d="M168 70 l2 5 5 .7 -3.6 3.5 .9 5 -4.3 -2.3 -4.3 2.3 .9 -5 -3.6 -3.5 5 -.7 z" fill="#F6B7C6" />
          </G>
        ) : null}
      </Svg>
    </Animated.View>
  );
}

/** Eyes in a light ink for the dark "Black Sesame" coat. */
function EyesLight({ mood, blink }: { mood: PetMood; blink: boolean }) {
  const light = '#F4EDE4';
  if (mood === 'happy' || mood === 'proud') {
    return (
      <G>
        <Path d="M68 114 Q76 102 84 114" stroke={light} strokeWidth={4.5} strokeLinecap="round" fill="none" />
        <Path d="M116 114 Q124 102 132 114" stroke={light} strokeWidth={4.5} strokeLinecap="round" fill="none" />
      </G>
    );
  }
  if (mood === 'sleepy' || blink) {
    return (
      <G>
        <Path d="M68 110 Q76 118 84 110" stroke={light} strokeWidth={4.5} strokeLinecap="round" fill="none" />
        <Path d="M116 110 Q124 118 132 110" stroke={light} strokeWidth={4.5} strokeLinecap="round" fill="none" />
      </G>
    );
  }
  return (
    <G>
      <Ellipse cx={76} cy={110} rx={6.5} ry={8.5} fill={light} />
      <Ellipse cx={124} cy={110} rx={6.5} ry={8.5} fill={light} />
      <Circle cx={78.5} cy={106.5} r={2.4} fill={INK} />
      <Circle cx={126.5} cy={106.5} r={2.4} fill={INK} />
    </G>
  );
}
