import React from 'react';
import Svg, { Ellipse, Path } from 'react-native-svg';

const O = '#5B4A3E';

/** Five little mochi faces for the daily check-in. None of them is "bad"; they just describe. */
export function MoodFace({ mood, size = 36 }: { mood: number; size?: number }) {
  const body = ['#E6E1F2', '#E3ECF3', '#FFF8EE', '#FDEBDD', '#FCE3E8'][Math.max(0, Math.min(4, mood - 1))]!;
  return (
    <Svg width={size} height={size} viewBox="0 0 40 40">
      <Path d="M20 6c10 0 16 6.5 16 15 0 7.5-6.5 13-16 13S4 28.5 4 21C4 12.5 10 6 20 6z" fill={body} stroke="#C9B8A6" strokeWidth={1.6} />
      {mood === 1 ? (
        <>
          <Path d="M12 18l3 1.5M28 18l-3 1.5" stroke={O} strokeWidth={2} strokeLinecap="round" />
          <Path d="M14 27c2-2 4 0 6-2s4 0 6-2" stroke={O} strokeWidth={1.8} strokeLinecap="round" fill="none" />
          <Path d="M31 12q-1.5 3 0 4q1.5-1 0-4z" fill="#BFD8E6" stroke="#8FAEC0" strokeWidth={0.8} />
        </>
      ) : null}
      {mood === 2 ? (
        <>
          <Ellipse cx={14.5} cy={19.5} rx={1.8} ry={2.2} fill={O} />
          <Ellipse cx={25.5} cy={19.5} rx={1.8} ry={2.2} fill={O} />
          <Path d="M16 27q4-3 8 0" stroke={O} strokeWidth={1.8} strokeLinecap="round" fill="none" />
        </>
      ) : null}
      {mood === 3 ? (
        <>
          <Ellipse cx={14.5} cy={19.5} rx={1.8} ry={2.2} fill={O} />
          <Ellipse cx={25.5} cy={19.5} rx={1.8} ry={2.2} fill={O} />
          <Path d="M16.5 26.5h7" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
        </>
      ) : null}
      {mood === 4 ? (
        <>
          <Ellipse cx={14.5} cy={19.5} rx={1.8} ry={2.2} fill={O} />
          <Ellipse cx={25.5} cy={19.5} rx={1.8} ry={2.2} fill={O} />
          <Path d="M16 25.5q4 3.5 8 0" stroke={O} strokeWidth={1.8} strokeLinecap="round" fill="none" />
          <Ellipse cx={11} cy={24} rx={2.6} ry={1.4} fill="#F6B0A0" opacity={0.7} />
          <Ellipse cx={29} cy={24} rx={2.6} ry={1.4} fill="#F6B0A0" opacity={0.7} />
        </>
      ) : null}
      {mood === 5 ? (
        <>
          <Path d="M12 20q2.5-3 5 0M23 20q2.5-3 5 0" stroke={O} strokeWidth={2} strokeLinecap="round" fill="none" />
          <Path d="M15.5 24.5h9q-1 5-4.5 5t-4.5-5z" fill="#C9706B" stroke={O} strokeWidth={1.5} strokeLinejoin="round" />
          <Ellipse cx={10.5} cy={24} rx={2.8} ry={1.5} fill="#F6B0A0" opacity={0.85} />
          <Ellipse cx={29.5} cy={24} rx={2.8} ry={1.5} fill="#F6B0A0" opacity={0.85} />
        </>
      ) : null}
    </Svg>
  );
}
