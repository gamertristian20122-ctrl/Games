import React from 'react';
import { StyleSheet, View } from 'react-native';
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
        <Decor items={decor} />
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

/**
 * Decor sits in the left and right thirds and along the top so it never covers the pet,
 * which stands in the middle of the floor.
 */
function Decor({ items }: { items: readonly string[] }) {
  const has = (id: string) => items.includes(id);
  return (
    <G>
      {has('rug') ? (
        <G>
          <Ellipse cx={180} cy={208} rx={116} ry={19} fill="#FFFDF8" opacity={0.9} />
          {[96, 140, 180, 220, 264].map((x) => (
            <Circle key={x} cx={x} cy={196} r={14} fill="#FFFDF8" opacity={0.9} />
          ))}
        </G>
      ) : null}
      {has('lights') ? (
        <G>
          <Path d="M0 10 Q45 30 90 12 T180 12 T270 12 T360 10" stroke="#8C7B6B" strokeWidth={1.5} fill="none" />
          {[20, 52, 84, 116, 148, 180, 212, 244, 276, 308, 340].map((x, i) => (
            <Circle key={x} cx={x} cy={i % 2 ? 22 : 17} r={4} fill={['#FBE29A', '#F6B7C6', '#BFD8E6'][i % 3]} />
          ))}
        </G>
      ) : null}
      {has('poster') ? (
        <G>
          <Rect x={24} y={36} width={46} height={58} rx={4} fill="#3F4A6B" stroke="#FFFDF8" strokeWidth={4} />
          <Path d="M47 52 l3 6 6.5 1 -4.7 4.6 1.1 6.4 -5.9 -3.1 -5.9 3.1 1.1 -6.4 -4.7 -4.6 6.5 -1 z" fill="#FBE29A" />
          <Circle cx={35} cy={82} r={1.8} fill="#FFFDF8" />
          <Circle cx={60} cy={78} r={1.4} fill="#FFFDF8" />
        </G>
      ) : null}
      {has('books') ? (
        <G>
          <Rect x={70} y={162} width={36} height={9} rx={2} fill="#A8C3A0" />
          <Rect x={73} y={153} width={30} height={9} rx={2} fill="#F6C6A8" />
          <Rect x={70} y={144} width={34} height={9} rx={2} fill="#CDBFE6" />
          <Rect x={75} y={171} width={28} height={8} rx={2} fill="#F3DE9C" />
        </G>
      ) : null}
      {has('fern') ? (
        <G>
          <Path d="M10 196 h24 l-3 20 h-18 z" fill="#E7B48F" />
          <Path d="M22 196 c-12 -10 -16 -24 -10 -32 c4 10 8 20 10 32z M22 196 c12 -10 16 -24 10 -32 c-4 10 -8 20 -10 32z M22 196 c0 -14 0 -26 0 -36" fill="#8DB07F" stroke="#6E9A62" strokeWidth={1.5} />
        </G>
      ) : null}
      {has('plush') ? (
        <G>
          <Ellipse cx={58} cy={214} rx={14} ry={11} fill="#F3E3D3" stroke="#C9AE94" strokeWidth={1.5} />
          <Path d="M47 206 l3 -9 5 6 z M69 206 l-3 -9 -5 6 z" fill="#F3E3D3" stroke="#C9AE94" strokeWidth={1.5} strokeLinejoin="round" />
          <Circle cx={53} cy={212} r={1.6} fill="#3E3833" />
          <Circle cx={63} cy={212} r={1.6} fill="#3E3833" />
        </G>
      ) : null}
      {has('beanbag') ? (
        <G>
          <Path d="M266 206 C262 176 288 160 304 168 C322 160 336 186 330 206 Q298 216 266 206 Z" fill="#CDBFE6" stroke="#9D8CC4" strokeWidth={2} />
          <Path d="M284 184 Q298 176 312 186" stroke="#9D8CC4" strokeWidth={1.5} fill="none" />
        </G>
      ) : null}
      {has('lamp') ? (
        <G>
          <Line x1={340} y1={130} x2={340} y2={176} stroke="#8C7B6B" strokeWidth={3} />
          <Ellipse cx={340} cy={178} rx={12} ry={4} fill="#8C7B6B" />
          <Circle cx={340} cy={122} r={14} fill="#FBF2D5" stroke="#E5CF8A" strokeWidth={2} />
          <Circle cx={346} cy={118} r={11} fill="#F6E7B6" opacity={0.9} />
        </G>
      ) : null}
    </G>
  );
}
