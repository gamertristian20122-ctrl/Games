import React from 'react';
import Svg, { Circle, Ellipse, G, Line, Path, Rect } from 'react-native-svg';

/**
 * Pebble-shop art. Each item is drawn ONCE, in room coordinates (360×240 room viewBox,
 * floor at y=178). The room renders it in place and the shop thumbnail crops to `box`,
 * so what you buy is exactly what appears in the room.
 */

const O = '#6B5444';
const s = { stroke: O, strokeWidth: 2, strokeLinejoin: 'round' as const, strokeLinecap: 'round' as const };

interface DecorDef {
  /** [x, y, width, height] crop for the shop thumbnail. */
  box: [number, number, number, number];
  /** Drawn behind the pet (floor items) or on the wall. */
  art: () => React.JSX.Element;
}

export const DECOR: Record<string, DecorDef> = {
  rug: {
    box: [56, 168, 248, 60],
    art: () => (
      <G>
        <Path
          d="M80 214c-16 0-22-16-8-22 0-12 18-16 28-8 6-10 24-10 30-2 8-8 26-8 32 0 8-6 24-6 30 2 8-6 24-4 28 6 12-4 26 4 22 16 14 6 8 22-8 22z"
          fill="#FFFDF8"
          {...s}
          strokeWidth={1.8}
        />
        <Path d="M96 204h168" stroke="#BFD8E6" strokeWidth={2} strokeLinecap="round" strokeDasharray="2 8" />
      </G>
    ),
  },
  lights: {
    box: [0, 0, 190, 40],
    art: () => (
      <G>
        <Path d="M0 10 Q45 30 90 12 T180 12 T270 12 T360 10" stroke={O} strokeWidth={1.6} fill="none" />
        {[20, 52, 84, 116, 148, 180, 212, 244, 276, 308, 340].map((x, i) => (
          <G key={x}>
            <Rect x={x - 2} y={(i % 2 ? 22 : 17) - 8} width={4} height={4} rx={1} fill={O} />
            <Path
              d={`M${x} ${(i % 2 ? 22 : 17) - 4}c4 0 5 4 5 7a5 5 0 0 1-10 0c0-3 1-7 5-7z`}
              fill={['#F3DE9C', '#F6B7C6', '#BFD8E6'][i % 3]}
              stroke={O}
              strokeWidth={1.2}
            />
          </G>
        ))}
      </G>
    ),
  },
  poster: {
    box: [16, 28, 62, 74],
    art: () => (
      <G>
        <Rect x={24} y={36} width={46} height={58} rx={4} fill="#3F4A6B" stroke="#FFFDF8" strokeWidth={4} />
        <Rect x={22} y={34} width={50} height={62} rx={5} fill="none" {...s} strokeWidth={1.6} />
        <Path d="M47 50l3.3 6.8 7.4 1.1-5.4 5.2 1.3 7.4-6.6-3.5-6.6 3.5 1.3-7.4-5.4-5.2 7.4-1.1z" fill="#F3DE9C" stroke={O} strokeWidth={1.2} strokeLinejoin="round" />
        <Circle cx={34} cy={82} r={1.8} fill="#FFFDF8" />
        <Circle cx={60} cy={78} r={1.4} fill="#FFFDF8" />
        <Path d="M54 86a4 4 0 1 0 4-6 3 3 0 1 1-4 6z" fill="#F3DE9C" />
      </G>
    ),
  },
  books: {
    box: [62, 134, 52, 50],
    art: () => (
      <G>
        <Rect x={75} y={170} width={28} height={8} rx={2} fill="#F3DE9C" {...s} strokeWidth={1.6} />
        <Rect x={70} y={161} width={36} height={9} rx={2} fill="#A8C3A0" {...s} strokeWidth={1.6} />
        <Rect x={73} y={152} width={30} height={9} rx={2} fill="#F6C6A8" {...s} strokeWidth={1.6} />
        <Rect x={70} y={143} width={34} height={9} rx={2} fill="#CDBFE6" {...s} strokeWidth={1.6} />
        <Path d="M76 147.5h6M78 156.5h5M76 165.5h8" stroke="#FFFDF8" strokeWidth={1.6} strokeLinecap="round" />
      </G>
    ),
  },
  fern: {
    box: [2, 150, 42, 72],
    art: () => (
      <G>
        <Path d="M22 196c-12-10-16-24-10-32 4 10 8 20 10 32zM22 196c12-10 16-24 10-32-4 10-8 20-10 32zM22 196c-4-14-2-26 0-36 2 10 4 22 0 36z" fill="#A8C3A0" {...s} strokeWidth={1.6} />
        <Path d="M9 196h26l-3 20H12z" fill="#F6C6A8" {...s} strokeWidth={1.8} />
        <Path d="M11 202h22" stroke="#E9A27E" strokeWidth={1.6} />
      </G>
    ),
  },
  plush: {
    box: [36, 190, 44, 38],
    art: () => (
      <G>
        <Path d="M47 207l3-10 6 6zM69 207l-3-10-6 6z" fill="#F3E3D3" {...s} strokeWidth={1.6} />
        <Ellipse cx={58} cy={214} rx={15} ry={11} fill="#F3E3D3" {...s} strokeWidth={1.8} />
        <Circle cx={52.5} cy={212} r={1.7} fill={O} />
        <Circle cx={63.5} cy={212} r={1.7} fill={O} />
        <Path d="M56.5 216.5q1.5 1.5 3 0" stroke={O} strokeWidth={1.2} fill="none" strokeLinecap="round" />
        <Ellipse cx={49} cy={216} rx={2.4} ry={1.3} fill="#F6B7C6" />
        <Ellipse cx={67} cy={216} rx={2.4} ry={1.3} fill="#F6B7C6" />
      </G>
    ),
  },
  beanbag: {
    box: [256, 156, 84, 62],
    art: () => (
      <G>
        <Path d="M266 206C262 176 288 160 304 168c18-8 32 18 26 38q-32 10-64 0z" fill="#CDBFE6" {...s} />
        <Path d="M284 186q14-8 28 2" stroke="#9D8CC4" strokeWidth={1.8} fill="none" strokeLinecap="round" />
        <Ellipse cx={286} cy={178} rx={6} ry={3} fill="#FFFFFF" opacity={0.55} transform="rotate(-20 286 178)" />
      </G>
    ),
  },
  lamp: {
    box: [318, 100, 42, 84],
    art: () => (
      <G>
        <Circle cx={340} cy={120} r={20} fill="#FBF2D5" opacity={0.45} />
        <Line x1={340} y1={132} x2={340} y2={176} stroke={O} strokeWidth={3} strokeLinecap="round" />
        <Ellipse cx={340} cy={178} rx={12} ry={4} fill="#B08C68" {...s} strokeWidth={1.6} />
        <Path d="M352 112a13 13 0 1 1-12-12 10 10 0 0 0 12 12z" fill="#F3DE9C" {...s} strokeWidth={1.8} />
      </G>
    ),
  },
};

/** All placed decor, drawn in room coordinates (used inside <Room>). */
export function DecorLayer({ items }: { items: readonly string[] }) {
  return (
    <G>
      {Object.entries(DECOR)
        .filter(([id]) => items.includes(id))
        .map(([id, d]) => (
          <G key={id}>{d.art()}</G>
        ))}
    </G>
  );
}

/** Shop thumbnail: the exact room drawing, cropped to the item. */
export function DecorThumb({ id, size = 56 }: { id: string; size?: number }) {
  const d = DECOR[id];
  if (!d) return null;
  const [x, y, w, h] = d.box;
  return (
    <Svg width={size} height={size} viewBox={`${x} ${y} ${w} ${h}`} preserveAspectRatio="xMidYMid meet">
      {d.art()}
    </Svg>
  );
}

/** Treats are enjoyed, not kept: drawn on a 40×40 grid and shown next to the pet when given. */
export function TreatArt({ id, size = 44 }: { id: string; size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 40 40">
      {id === 'cocoa-treat' ? (
        <G>
          <Path d="M14 8c-1 2 1 3 0 5M20 6c-1 2 1 3 0 5" fill="none" stroke="#8FAEC0" strokeWidth={1.6} strokeLinecap="round" />
          <Path d="M29 19h2a4 4 0 0 1 0 8h-3" fill="none" {...s} strokeWidth={1.8} />
          <Path d="M8 16h22v9a9 9 0 0 1-9 9h-4a9 9 0 0 1-9-9z" fill="#F6C6A8" {...s} strokeWidth={1.8} />
          <Ellipse cx={19} cy={16.5} rx={10.5} ry={2.4} fill="#B08C68" />
          <Rect x={13} y={13} width={5} height={4.5} rx={1.4} fill="#FFFDF8" {...s} strokeWidth={1.2} />
          <Rect x={19.5} y={12.5} width={5} height={4.5} rx={1.4} fill="#FFFDF8" {...s} strokeWidth={1.2} transform="rotate(14 22 15)" />
        </G>
      ) : (
        <G>
          <Ellipse cx={20} cy={31} rx={16} ry={5} fill="#FFFDF8" {...s} strokeWidth={1.8} />
          <Path d="M8 28c0-8 5-13 12-13s12 5 12 13c-3 2-21 2-24 0z" fill="#FCE3E8" {...s} strokeWidth={1.8} />
          <Path d="M20 15c-1-3-4-5-7-4 1 3 4 5 7 4zM20 15c1-3 4-5 7-4-1 3-4 5-7 4z" fill="#A8C3A0" {...s} strokeWidth={1.4} />
          <Path d="M15 16c0-3 2-5 5-5s5 2 5 5c-1 3-3 5-5 6-2-1-4-3-5-6z" fill="#EE8EA2" {...s} strokeWidth={1.6} />
          <Circle cx={18.5} cy={15.5} r={0.7} fill="#FFFDF8" />
          <Circle cx={21.5} cy={17.5} r={0.7} fill="#FFFDF8" />
          <Ellipse cx={13} cy={24} rx={2.6} ry={1.3} fill="#FFFFFF" opacity={0.7} />
        </G>
      )}
    </Svg>
  );
}
