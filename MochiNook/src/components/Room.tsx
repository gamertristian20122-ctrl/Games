import React from 'react';
import { StyleSheet, View } from 'react-native';
import { DecorLayer } from './art/DecorArt';
import Svg, { Circle, Defs, Ellipse, G, Line, LinearGradient, Path, Rect, Stop } from 'react-native-svg';

interface Props {
  room: string;
  /** Pebble-shop decor to draw in the room (ids from data/shop.ts). */
  decor?: readonly string[];
  /** Calm Mode / dark: wash the room down so it never competes with the content. */
  muted: boolean;
  dark: boolean;
}

/** Cozy room backdrops drawn in SVG. viewBox is 360×240; the floor line sits at y=178. */
export function Room({ room, muted, dark, decor = [] }: Props) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <Svg width="100%" height="100%" viewBox="0 0 360 240" preserveAspectRatio="xMidYMid slice">
        <Scene room={room} />
        <DecorLayer items={decor} />
        {muted || dark ? <Rect x={0} y={0} width={360} height={240} fill={dark ? '#1E1A17' : '#F3F1ED'} opacity={dark ? (muted ? 0.62 : 0.45) : 0.45} /> : null}
      </Svg>
    </View>
  );
}

function Scene({ room }: { room: string }) {
  switch (room) {
    case 'rainy':
      return (
        <G>
          <Rect width={360} height={240} fill="#DCE6EC" />
          <Rect x={226} y={28} width={98} height={92} rx={12} fill="#AFC4D2" stroke="#F3F6F8" strokeWidth={8} />
          <Line x1={275} y1={28} x2={275} y2={120} stroke="#F3F6F8" strokeWidth={5} />
          {[240, 256, 290, 306, 248, 300].map((x, i) => (
            <Line key={i} x1={x} y1={40 + (i % 3) * 22} x2={x - 4} y2={52 + (i % 3) * 22} stroke="#EAF1F5" strokeWidth={2.5} strokeLinecap="round" />
          ))}
          <Rect x={0} y={178} width={360} height={62} fill="#C7D3DA" />
          <Ellipse cx={180} cy={204} rx={120} ry={18} fill="#B4C3CC" />
          <Rect x={30} y={120} width={40} height={58} rx={6} fill="#E9DCCB" />
          <Path d="M30 120 h40 l-6 -16 h-28 z" fill="#F3E7D7" />
        </G>
      );
    case 'starry':
      return (
        <G>
          <Defs>
            <LinearGradient id="night" x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0" stopColor="#B7AAD6" />
              <Stop offset="1" stopColor="#DCD3EE" />
            </LinearGradient>
          </Defs>
          <Rect width={360} height={240} fill="url(#night)" />
          <Circle cx={290} cy={50} r={20} fill="#FBF2D5" />
          <Circle cx={298} cy={44} r={18} fill="#BFB2DC" />
          {[
            [40, 30], [90, 60], [150, 26], [210, 70], [250, 22], [330, 96], [20, 96], [120, 100],
          ].map(([x, y], i) => (
            <Circle key={i} cx={x} cy={y} r={i % 2 ? 1.8 : 2.6} fill="#FFFDF8" />
          ))}
          <Rect x={0} y={178} width={360} height={62} fill="#CBBFE2" />
          <Rect x={18} y={150} width={92} height={28} rx={10} fill="#E9E2F6" />
          <Rect x={24} y={140} width={30} height={16} rx={6} fill="#F7F3FC" />
        </G>
      );
    case 'forest':
      return (
        <G>
          <Rect width={360} height={240} fill="#E2EBDC" />
          {[0, 1, 2, 3, 4, 5, 6, 7].map((i) => (
            <Line key={i} x1={i * 48 + 10} y1={0} x2={i * 48 + 10} y2={178} stroke="#D4E0CC" strokeWidth={14} />
          ))}
          <Rect x={232} y={30} width={90} height={80} rx={10} fill="#BFD8B3" stroke="#C8A27C" strokeWidth={7} />
          <Path d="M250 104 l14 -40 14 40 z M276 104 l12 -30 12 30 z" fill="#8DB07F" />
          <Rect x={0} y={178} width={360} height={62} fill="#D7B997" />
          {[0, 1, 2, 3].map((i) => (
            <Line key={i} x1={0} y1={192 + i * 14} x2={360} y2={192 + i * 14} stroke="#C9A985" strokeWidth={2} />
          ))}
          <Rect x={34} y={140} width={22} height={38} rx={5} fill="#E8C9A6" />
          <Path d="M45 140 c-16 -18 -10 -34 0 -40 c10 6 16 22 0 40z" fill="#9CC48E" />
        </G>
      );
    case 'beach':
      return (
        <G>
          <Rect width={360} height={240} fill="#D9EAF2" />
          <Circle cx={70} cy={56} r={22} fill="#FBE7A6" />
          <Path d="M0 150 Q90 136 180 150 T360 150 V178 H0 Z" fill="#B8D6E4" />
          <Rect x={0} y={178} width={360} height={62} fill="#F3E2C2" />
          <Path d="M270 178 V96" stroke="#C9A27C" strokeWidth={6} strokeLinecap="round" />
          <Path d="M270 98 c-30 -6 -44 6 -50 14 c18 -10 34 -10 50 -14z M270 98 c30 -6 44 6 50 14 c-18 -10 -34 -10 -50 -14z M270 98 c-8 -24 -26 -30 -36 -30 c16 6 28 16 36 30z" fill="#9CC48E" />
          <Ellipse cx={62} cy={206} rx={14} ry={6} fill="#F6C6A8" />
        </G>
      );
    case 'sunny':
    default:
      return (
        <G>
          <Rect width={360} height={240} fill="#FBEBD9" />
          <Rect x={232} y={26} width={92} height={90} rx={14} fill="#CFE6EE" stroke="#FFFDF8" strokeWidth={8} />
          <Circle cx={292} cy={58} r={14} fill="#FBE29A" />
          <Path d="M232 96 Q260 84 290 96 T324 92 V116 H232 Z" fill="#BFD8B3" />
          <Rect x={0} y={178} width={360} height={62} fill="#EBD3B8" />
          <Ellipse cx={180} cy={206} rx={128} ry={20} fill="#F4C9B0" />
          <Ellipse cx={180} cy={206} rx={100} ry={13} fill="#F8DCC9" />
          <Rect x={30} y={140} width={26} height={38} rx={6} fill="#F1B79B" />
          <Path d="M43 140 c-14 -10 -12 -28 0 -34 c12 6 14 24 0 34z" fill="#A8C3A0" />
        </G>
      );
  }
}
