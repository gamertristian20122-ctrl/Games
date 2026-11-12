import React from 'react';
import Svg, { Circle, Ellipse, G, Line, Path, Rect } from 'react-native-svg';
import { glyphFor, type GlyphName } from './glyphNames';

/**
 * MochiNook's own flat-vector icon set. Every glyph uses the same recipe as the pet:
 * soft pastel fills, a warm brown rounded outline, and a little white highlight.
 * Drawn on a 32×32 grid.
 */

const O = '#6B5444';
const s = { stroke: O, strokeWidth: 1.6, strokeLinejoin: 'round' as const, strokeLinecap: 'round' as const };
const P = {
  sage: '#A8C3A0',
  sageD: '#7E9C76',
  peach: '#F6C6A8',
  peachD: '#E9A27E',
  lav: '#CDBFE6',
  lavD: '#9D8CC4',
  butter: '#F3DE9C',
  butterD: '#E2C25E',
  sky: '#BFD8E6',
  skyD: '#8FAEC0',
  pink: '#F6B7C6',
  cream: '#FFF8EE',
  white: '#FFFDF8',
  wood: '#DDB98F',
  woodD: '#B08C68',
  gray: '#D9D3CC',
  orange: '#F0A774',
};

const shine = (cx: number, cy: number, rx = 2.2, ry = 1.1) => <Ellipse cx={cx} cy={cy} rx={rx} ry={ry} fill="#FFFFFF" opacity={0.7} />;

const GLYPHS: Record<GlyphName, () => React.JSX.Element> = {
  drop: () => (
    <G>
      <Path d="M16 4.5C16 4.5 7.5 14 7.5 19.5a8.5 8.5 0 0 0 17 0C24.5 14 16 4.5 16 4.5z" fill={P.sky} {...s} />
      {shine(12.5, 17, 1.4, 2.4)}
    </G>
  ),
  pill: () => (
    <G transform="rotate(-35 16 16)">
      <Path d="M16 11.5h-5a4.5 4.5 0 0 0 0 9h5z" fill={P.peach} {...s} />
      <Path d="M16 11.5h5a4.5 4.5 0 0 1 0 9h-5z" fill={P.white} {...s} />
      {shine(10, 14)}
    </G>
  ),
  toothbrush: () => (
    <G transform="rotate(-35 16 16)">
      <Rect x={4} y={14} width={17} height={4} rx={2} fill={P.sage} {...s} />
      <Rect x={20} y={13} width={8} height={6} rx={1.5} fill={P.white} {...s} />
      <Path d="M21.5 13v-3M24 13v-3M26.5 13v-3" stroke={P.skyD} strokeWidth={1.8} strokeLinecap="round" />
    </G>
  ),
  sun: () => (
    <G>
      {[0, 45, 90, 135, 180, 225, 270, 315].map((a) => {
        const r = (a * Math.PI) / 180;
        return <Line key={a} x1={16 + Math.cos(r) * 9.5} y1={16 + Math.sin(r) * 9.5} x2={16 + Math.cos(r) * 13} y2={16 + Math.sin(r) * 13} stroke={P.butterD} strokeWidth={2} strokeLinecap="round" />;
      })}
      <Circle cx={16} cy={16} r={7} fill={P.butter} {...s} />
      {shine(13.5, 13.5)}
    </G>
  ),
  sunCloud: () => (
    <G>
      <Circle cx={12} cy={12} r={6} fill={P.butter} {...s} />
      <Path d="M10 25h13a4.5 4.5 0 0 0 0-9 6 6 0 0 0-11.4 1.7A3.7 3.7 0 0 0 10 25z" fill={P.white} {...s} />
    </G>
  ),
  moon: () => (
    <G>
      <Path d="M20 5.5a10.5 10.5 0 1 0 6.5 18.6A9 9 0 0 1 20 5.5z" fill={P.butter} {...s} />
      <Circle cx={12} cy={13} r={1.3} fill={P.butterD} />
      <Circle cx={15} cy={21} r={1} fill={P.butterD} />
    </G>
  ),
  shirt: () => (
    <G>
      <Path d="M11 5.5 5 9l2.6 5 2.4-1.2V26h12V12.8l2.4 1.2L27 9l-6-3.5c-.8 1.8-2.6 3-5 3s-4.2-1.2-5-3z" fill={P.sky} {...s} />
      <Path d="M13 6c.8 1.2 1.8 1.8 3 1.8s2.2-.6 3-1.8" fill="none" {...s} />
    </G>
  ),
  bowl: () => (
    <G>
      <Path d="M12 6.5c-1 1.5 1 2.5 0 4M16 5.5c-1 1.5 1 2.5 0 4M20 6.5c-1 1.5 1 2.5 0 4" fill="none" stroke={P.skyD} strokeWidth={1.6} strokeLinecap="round" />
      <Path d="M5 14h22a11 11 0 0 1-22 0z" fill={P.peach} {...s} />
      <Path d="M9 14c2-2 4 1 6-1s4 1 6-1 3 1 5 0" fill="none" stroke={P.butterD} strokeWidth={1.6} strokeLinecap="round" />
    </G>
  ),
  toast: () => (
    <G>
      <Path d="M8 26V14a6 6 0 0 1 0-1.5C8 8.5 11.6 6 16 6s8 2.5 8 6.5a6 6 0 0 1 0 1.5v12z" fill={P.wood} {...s} />
      <Path d="M11 23.5V14.5c-1-1.5 0-5 5-5s6 3.5 5 5v9z" fill={P.cream} />
    </G>
  ),
  pan: () => (
    <G>
      <Rect x={22} y={14.5} width={9} height={3} rx={1.5} fill={P.woodD} {...s} />
      <Circle cx={13} cy={16} r={10} fill={P.gray} {...s} />
      <Path d="M8 15c0-3 3-5 5.5-4.5S19 12 18.5 15s-2 5-5 5S8 18 8 15z" fill={P.white} />
      <Circle cx={13.5} cy={15} r={2.8} fill={P.butter} stroke={P.butterD} strokeWidth={1} />
    </G>
  ),
  plate: () => (
    <G>
      <Ellipse cx={16} cy={17} rx={12} ry={9} fill={P.white} {...s} />
      <Ellipse cx={16} cy={17} rx={7.5} ry={5.5} fill="none" stroke={P.gray} strokeWidth={1.4} />
      <Path d="M27.5 5v6M26 5v4.5M29 5v4.5M27.5 11v4" fill="none" stroke={O} strokeWidth={1.3} strokeLinecap="round" />
    </G>
  ),
  backpack: () => (
    <G>
      <Path d="M12 8V6.5a4 4 0 0 1 8 0V8" fill="none" {...s} />
      <Rect x={7} y={8} width={18} height={19} rx={6} fill={P.sage} {...s} />
      <Rect x={11} y={17} width={10} height={7} rx={2.5} fill={P.sageD} {...s} />
      {shine(11, 12, 1.8, 1)}
    </G>
  ),
  headphones: () => (
    <G>
      <Path d="M6 19v-3a10 10 0 0 1 20 0v3" fill="none" {...s} strokeWidth={2.2} />
      <Rect x={4} y={17} width={7} height={10} rx={3} fill={P.lav} {...s} />
      <Rect x={21} y={17} width={7} height={10} rx={3} fill={P.lav} {...s} />
    </G>
  ),
  medkit: () => (
    <G>
      <Path d="M12 9V7h8v2" fill="none" {...s} />
      <Rect x={5} y={9} width={22} height={17} rx={4} fill={P.white} {...s} />
      <Path d="M14 13h4v3h3v4h-3v3h-4v-3h-3v-4h3z" fill={P.pink} {...s} strokeWidth={1.2} />
    </G>
  ),
  paw: () => (
    <G>
      <Path d="M16 16c-4.5 0-8 4-8 7 0 2.5 2.5 3.5 4.5 3 1.5-.3 2.3-1 3.5-1s2 .7 3.5 1c2 .5 4.5-.5 4.5-3 0-3-3.5-7-8-7z" fill={P.peach} {...s} />
      <Ellipse cx={8} cy={13} rx={2.5} ry={3} fill={P.peach} {...s} />
      <Ellipse cx={13} cy={8.5} rx={2.5} ry={3} fill={P.peach} {...s} />
      <Ellipse cx={19} cy={8.5} rx={2.5} ry={3} fill={P.peach} {...s} />
      <Ellipse cx={24} cy={13} rx={2.5} ry={3} fill={P.peach} {...s} />
    </G>
  ),
  hanger: () => (
    <G>
      <Path d="M16 11V9.5a2.5 2.5 0 1 0-2.5-2.5" fill="none" {...s} />
      <Path d="M16 11 4 21.5c-1 .9-.4 2.5 1 2.5h22c1.4 0 2-1.6 1-2.5z" fill={P.pink} {...s} />
      <Path d="M8 21h16" stroke={P.white} strokeWidth={1.4} strokeLinecap="round" />
    </G>
  ),
  polish: () => (
    <G>
      <Rect x={12.5} y={4} width={7} height={9} rx={1.5} fill={P.lavD} {...s} />
      <Rect x={9} y={12.5} width={14} height={15} rx={4} fill={P.pink} {...s} />
      {shine(13, 17, 1.4, 2.2)}
    </G>
  ),
  scissors: () => (
    <G>
      <Circle cx={9} cy={22} r={4} fill={P.lav} {...s} />
      <Circle cx={23} cy={22} r={4} fill={P.lav} {...s} />
      <Path d="M11.5 19 21 5M20.5 19 11 5" fill="none" stroke={O} strokeWidth={2} strokeLinecap="round" />
    </G>
  ),
  chat: () => (
    <G>
      <Path d="M6 7h20a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H14l-6 4.5V23H6a3 3 0 0 1-3-3V10a3 3 0 0 1 3-3z" fill={P.lav} {...s} />
      <Circle cx={11} cy={15} r={1.6} fill={O} />
      <Circle cx={16} cy={15} r={1.6} fill={O} />
      <Circle cx={21} cy={15} r={1.6} fill={O} />
    </G>
  ),
  laptop: () => (
    <G>
      <Rect x={6} y={7} width={20} height={14} rx={2} fill={P.sky} {...s} />
      <Path d="M3 23h26l-2 3H5z" fill={P.gray} {...s} />
      {shine(10, 10, 2, 1)}
    </G>
  ),
  folder: () => (
    <G>
      <Path d="M4 9a2 2 0 0 1 2-2h6l2.5 2.5H26a2 2 0 0 1 2 2V24a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z" fill={P.butter} {...s} />
      <Path d="M4 13h24" stroke={P.butterD} strokeWidth={1.4} />
    </G>
  ),
  clipboard: () => (
    <G>
      <Rect x={6} y={6} width={20} height={22} rx={3} fill={P.wood} {...s} />
      <Rect x={9} y={9} width={14} height={16} rx={1.5} fill={P.white} {...s} strokeWidth={1.2} />
      <Rect x={12} y={4} width={8} height={4.5} rx={1.5} fill={P.gray} {...s} />
      <Path d="M12 14h8M12 18h8M12 22h5" stroke={P.skyD} strokeWidth={1.5} strokeLinecap="round" />
    </G>
  ),
  bookOpen: () => (
    <G>
      <Path d="M16 9c-3-2.5-7-3-11-2v17c4-1 8-.5 11 2 3-2.5 7-3 11-2V7c-4-1-8-.5-11 2z" fill={P.white} {...s} />
      <Path d="M16 9v17" {...s} />
      <Path d="M8 11.5c2 0 4 .4 5.5 1.2M8 15.5c2 0 4 .4 5.5 1.2M18.5 12.7c1.5-.8 3.5-1.2 5.5-1.2M18.5 16.7c1.5-.8 3.5-1.2 5.5-1.2" stroke={P.lavD} strokeWidth={1.2} strokeLinecap="round" />
    </G>
  ),
  books: () => (
    <G>
      <Rect x={5} y={21} width={22} height={5.5} rx={1.5} fill={P.sage} {...s} />
      <Rect x={7} y={15.5} width={19} height={5.5} rx={1.5} fill={P.peach} {...s} />
      <Rect x={5.5} y={10} width={20} height={5.5} rx={1.5} fill={P.lav} {...s} />
      <Rect x={8} y={4.5} width={16} height={5.5} rx={1.5} fill={P.butter} {...s} />
    </G>
  ),
  notepad: () => (
    <G>
      <Rect x={5} y={6} width={17} height={21} rx={2.5} fill={P.white} {...s} />
      <Path d="M8.5 11h10M8.5 15h10M8.5 19h6" stroke={P.skyD} strokeWidth={1.4} strokeLinecap="round" />
      <G transform="rotate(35 24 17)">
        <Rect x={22} y={6} width={4.5} height={17} rx={1} fill={P.butter} {...s} />
        <Path d="M22 23h4.5l-2.25 4z" fill={P.wood} {...s} />
      </G>
    </G>
  ),
  phone: () => (
    <G>
      <Path d="M9 5.5c-2 .3-4 2.5-3.5 5.5 1.2 7.5 7.8 14.5 15.5 15.5 3 .4 5-1.5 5.3-3.5l.2-1.2-5.5-3-2.5 2.5c-3-1.2-5.8-4-7-7l2.5-2.5-3-5.5z" fill={P.sage} {...s} />
      {shine(9, 9, 1, 1.8)}
    </G>
  ),
  mail: () => (
    <G>
      <Rect x={4} y={8} width={24} height={17} rx={3} fill={P.white} {...s} />
      <Path d="M4.5 9.5 16 18l11.5-8.5" fill="none" {...s} />
      <Path d="M16 21.5c-.8-.7-2.5-1.8-2.5-3 0-.8.6-1.3 1.3-1.3.5 0 .9.3 1.2.7.3-.4.7-.7 1.2-.7.7 0 1.3.5 1.3 1.3 0 1.2-1.7 2.3-2.5 3z" fill={P.pink} />
    </G>
  ),
  plug: () => (
    <G>
      <Path d="M12 4v5M20 4v5" stroke={O} strokeWidth={2.2} strokeLinecap="round" />
      <Path d="M8 9h16v5a8 8 0 0 1-16 0z" fill={P.gray} {...s} />
      <Path d="M16 22v3.5c0 1.5 1 2.5 2.5 2.5H23" fill="none" stroke={P.skyD} strokeWidth={2.2} strokeLinecap="round" />
    </G>
  ),
  candle: () => (
    <G>
      <Path d="M16 4c2.5 3 3.5 5 3.5 6.5a3.5 3.5 0 0 1-7 0C12.5 9 13.5 7 16 4z" fill={P.butter} stroke={P.peachD} strokeWidth={1.4} strokeLinejoin="round" />
      <Rect x={11} y={14} width={10} height={14} rx={2} fill={P.cream} {...s} />
      <Path d="M11 18c2 1 3-1 5 0s3-1 5 0" fill="none" stroke={P.pink} strokeWidth={1.4} />
    </G>
  ),
  trash: () => (
    <G>
      <Rect x={6} y={7} width={20} height={4} rx={2} fill={P.sageD} {...s} />
      <Path d="M8 11h16l-1.5 15a2 2 0 0 1-2 1.8h-9a2 2 0 0 1-2-1.8z" fill={P.sage} {...s} />
      <Path d="M13 15v8M16 15v8M19 15v8" stroke={P.sageD} strokeWidth={1.4} strokeLinecap="round" />
      <Path d="M13 7V5.5h6V7" fill="none" {...s} />
    </G>
  ),
  calendar: () => (
    <G>
      <Rect x={5} y={7} width={22} height={20} rx={3} fill={P.white} {...s} />
      <Path d="M5 10a3 3 0 0 1 3-3h16a3 3 0 0 1 3 3v3H5z" fill={P.peach} {...s} />
      <Path d="M11 5v4M21 5v4" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
      <Circle cx={11} cy={18} r={1.4} fill={P.skyD} />
      <Circle cx={16} cy={18} r={1.4} fill={P.skyD} />
      <Circle cx={21} cy={18} r={1.4} fill={P.pink} />
      <Circle cx={11} cy={22.5} r={1.4} fill={P.skyD} />
      <Circle cx={16} cy={22.5} r={1.4} fill={P.skyD} />
    </G>
  ),
  stretch: () => (
    <G>
      <Path d="M8.5 20 4.5 11.5M23.5 20l4-8.5" stroke={O} strokeWidth={2.2} strokeLinecap="round" />
      <Ellipse cx={4.3} cy={10.5} rx={2.2} ry={2.2} fill={P.cream} {...s} />
      <Ellipse cx={27.7} cy={10.5} rx={2.2} ry={2.2} fill={P.cream} {...s} />
      <Path d="M16 13.5c5.8 0 8.5 3.8 8.5 7.8 0 3.8-3.4 6.2-8.5 6.2s-8.5-2.4-8.5-6.2c0-4 2.7-7.8 8.5-7.8z" fill={P.cream} {...s} />
      <Path d="M12.8 20.2q1-1.4 2 0M17.2 20.2q1-1.4 2 0" fill="none" stroke={O} strokeWidth={1.4} strokeLinecap="round" />
      <Ellipse cx={11.3} cy={22.6} rx={1.5} ry={0.9} fill={P.pink} />
      <Ellipse cx={20.7} cy={22.6} rx={1.5} ry={0.9} fill={P.pink} />
    </G>
  ),
  hand: () => (
    <G>
      <Path d="M10 17V9a1.8 1.8 0 0 1 3.6 0v6V6.5a1.8 1.8 0 0 1 3.6 0V15V8a1.8 1.8 0 0 1 3.6 0v8.5V12a1.8 1.8 0 0 1 3.6 0v7c0 5-3.5 8.5-8.3 8.5-3 0-5-1.5-6.6-3.8L6 19.5a1.9 1.9 0 0 1 3-2.2z" fill={P.peach} {...s} />
    </G>
  ),
  rocket: () => (
    <G>
      <Path d="M16 3.5c4 3 6 7.5 6 12.5v6h-12v-6c0-5 2-9.5 6-12.5z" fill={P.lav} {...s} />
      <Circle cx={16} cy={13} r={2.8} fill={P.sky} {...s} />
      <Path d="M10 18l-4 4v3h4M22 18l4 4v3h-4" fill={P.pink} {...s} />
      <Path d="M13 22c0 3 1.5 5 3 6.5 1.5-1.5 3-3.5 3-6.5z" fill={P.butter} stroke={P.peachD} strokeWidth={1.4} strokeLinejoin="round" />
    </G>
  ),
  shower: () => (
    <G>
      <Path d="M9 3v4" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
      <Path d="M2 13a10 6 0 0 1 20 0z" fill={P.gray} {...s} />
      {[[5, 16], [9, 18], [13, 16], [17, 18], [7, 23], [11, 25], [15, 23], [19, 25]].map(([x, y]) => (
        <Path key={`${x}-${y}`} d={`M${x} ${y}q-1 2 0 3q1-1 0-3z`} fill={P.sky} stroke={P.skyD} strokeWidth={1} />
      ))}
    </G>
  ),
  bath: () => (
    <G>
      <Circle cx={11} cy={9} r={2.5} fill={P.white} stroke={P.skyD} strokeWidth={1.2} />
      <Circle cx={16} cy={6.5} r={2} fill={P.white} stroke={P.skyD} strokeWidth={1.2} />
      <Circle cx={20} cy={10} r={3} fill={P.white} stroke={P.skyD} strokeWidth={1.2} />
      <Path d="M3 14h26v3a8 8 0 0 1-8 8H11a8 8 0 0 1-8-8z" fill={P.white} {...s} />
      <Path d="M8 25l-1.5 3M24 25l1.5 3" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
      <Path d="M3 14h26" stroke={P.sky} strokeWidth={3} />
    </G>
  ),
  couch: () => (
    <G>
      <Rect x={6} y={8} width={20} height={11} rx={4} fill={P.lav} {...s} />
      <Rect x={2.5} y={14} width={7} height={11} rx={3} fill={P.lav} {...s} />
      <Rect x={22.5} y={14} width={7} height={11} rx={3} fill={P.lav} {...s} />
      <Rect x={8} y={18} width={16} height={6} rx={2} fill={P.lavD} {...s} />
      <Path d="M6 25v2.5M26 25v2.5" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
    </G>
  ),
  bed: () => (
    <G>
      <Path d="M4 8v19M28 16v11" stroke={P.woodD} strokeWidth={2.4} strokeLinecap="round" />
      <Rect x={6} y={12} width={8} height={5} rx={2.5} fill={P.white} {...s} />
      <Path d="M4 17h20a4 4 0 0 1 4 4v2H4z" fill={P.sky} {...s} />
      <Path d="M4 23h24" stroke={P.woodD} strokeWidth={2.4} strokeLinecap="round" />
    </G>
  ),
  cart: () => (
    <G>
      <Path d="M3 6h3.5l3 14h14l3-10H8" fill="none" {...s} />
      <Path d="M8.8 10h17.7l-3 10H10.5z" fill={P.sage} {...s} />
      <Circle cx={12} cy={25} r={2.2} fill={P.gray} {...s} />
      <Circle cx={22} cy={25} r={2.2} fill={P.gray} {...s} />
    </G>
  ),
  lunchbox: () => (
    <G>
      <Rect x={4} y={11} width={24} height={15} rx={4} fill={P.white} {...s} />
      <Rect x={3} y={8} width={26} height={5} rx={2.5} fill={P.sage} {...s} />
      <Circle cx={11} cy={19} r={3} fill={P.peach} />
      <Rect x={16} y={16} width={8} height={6} rx={2} fill={P.butter} />
    </G>
  ),
  cup: () => (
    <G>
      <Path d="M18 9l3-6" stroke={P.pink} strokeWidth={2.4} strokeLinecap="round" />
      <Path d="M8 9h16l-2 17a2 2 0 0 1-2 1.8h-8a2 2 0 0 1-2-1.8z" fill={P.sky} {...s} />
      <Path d="M8.6 14h14.8" stroke={P.white} strokeWidth={1.6} />
    </G>
  ),
  tooth: () => (
    <G>
      <Path d="M10 5c3 0 4 1.5 6 1.5S19 5 22 5c3 0 5 2.5 5 6 0 4-2 6-2.5 10-.4 3-1 6-3 6s-2.5-4-3.5-6.5c-.4-1-1.6-1-2 0C15 23 14.5 27 12.5 27s-2.6-3-3-6C9 17 7 15 7 11c0-3.5 1.5-6 3-6z" fill={P.white} {...s} />
      {shine(12, 10, 1.4, 2)}
    </G>
  ),
  cheese: () => (
    <G>
      <Path d="M4 21 25 9l3 3v12H4z" fill={P.butter} {...s} />
      <Path d="M4 21h24" stroke={P.butterD} strokeWidth={1.4} />
      <Circle cx={12} cy={17.5} r={1.6} fill={P.butterD} />
      <Circle cx={20} cy={14} r={1.3} fill={P.butterD} />
      <Circle cx={18} cy={23} r={1.4} fill={P.butterD} />
    </G>
  ),
  fridge: () => (
    <G>
      <Rect x={8} y={3.5} width={16} height={25} rx={3} fill={P.sky} {...s} />
      <Path d="M8 12.5h16" {...s} />
      <Path d="M11.5 7v3M11.5 16v5" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
      {shine(19, 7, 1.6, 0.9)}
    </G>
  ),
  socks: () => (
    <G>
      <Path d="M10 4h9v12l3.5 3.5a4 4 0 0 1-5.6 5.6L10 18.5z" fill={P.pink} {...s} />
      <Path d="M10 8h9M10 11.5h9" stroke={P.white} strokeWidth={1.6} />
    </G>
  ),
  lotion: () => (
    <G>
      <Path d="M14 4h5M16.5 4v5" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
      <Rect x={13} y={8} width={7} height={4} rx={1} fill={P.gray} {...s} />
      <Rect x={9} y={12} width={15} height={16} rx={4} fill={P.sage} {...s} />
      <Rect x={12} y={17} width={9} height={6} rx={1.5} fill={P.white} />
    </G>
  ),
  yarn: () => (
    <G>
      <Path d="M22 22l7 5M24.5 19.5l6 6.5" stroke={P.woodD} strokeWidth={1.6} strokeLinecap="round" />
      <Circle cx={15} cy={16} r={10} fill={P.lav} {...s} />
      <Path d="M7 12c5 1 10 6 13 12M9 8c4 2 10 8 14 14M6 18c4 0 8 3 10 7.5M12 6.5c4 3 9 9 12 14" fill="none" stroke={P.lavD} strokeWidth={1.3} />
    </G>
  ),
  teddy: () => (
    <G>
      <Circle cx={8.5} cy={9} r={4} fill={P.wood} {...s} />
      <Circle cx={23.5} cy={9} r={4} fill={P.wood} {...s} />
      <Circle cx={16} cy={17} r={10} fill={P.wood} {...s} />
      <Ellipse cx={16} cy={21} rx={4.5} ry={3.5} fill={P.cream} />
      <Circle cx={12.5} cy={15} r={1.3} fill={O} />
      <Circle cx={19.5} cy={15} r={1.3} fill={O} />
      <Ellipse cx={16} cy={19.5} rx={1.4} ry={1} fill={O} />
    </G>
  ),
  broom: () => (
    <G>
      <Path d="M23 3 15 17" stroke={P.woodD} strokeWidth={2.4} strokeLinecap="round" />
      <Path d="M11 15.5l7 4-2.5 8.5-9.5-5.5z" fill={P.butter} {...s} />
      <Path d="M9.5 24l3-6M12.5 25.5l3-6" stroke={P.butterD} strokeWidth={1.3} />
    </G>
  ),
  basket: () => (
    <G>
      <Path d="M9 12c1-4 4-5 7-5s6 1 7 5" fill={P.peach} {...s} />
      <Path d="M5 12h22l-2.5 14a2 2 0 0 1-2 1.6h-13a2 2 0 0 1-2-1.6z" fill={P.wood} {...s} />
      <Path d="M8 17h16M8.8 22h14.4M12 12v15M16 12v15M20 12v15" stroke={P.woodD} strokeWidth={1.2} />
    </G>
  ),
  soap: () => (
    <G>
      <Rect x={5} y={13} width={20} height={12} rx={5} fill={P.pink} {...s} />
      <Circle cx={22} cy={8} r={3} fill={P.white} stroke={P.skyD} strokeWidth={1.2} />
      <Circle cx={27} cy={12} r={2} fill={P.white} stroke={P.skyD} strokeWidth={1.2} />
      {shine(10, 16.5, 2.5, 1.1)}
    </G>
  ),
  sponge: () => (
    <G>
      <Rect x={5} y={9} width={22} height={6} rx={2} fill={P.sage} {...s} />
      <Rect x={5} y={15} width={22} height={10} rx={2.5} fill={P.butter} {...s} />
      <Circle cx={10} cy={20} r={1.2} fill={P.butterD} />
      <Circle cx={16} cy={18.5} r={1} fill={P.butterD} />
      <Circle cx={21} cy={21} r={1.3} fill={P.butterD} />
    </G>
  ),
  receipt: () => (
    <G>
      <Path d="M8 4h16v24l-2.7-2-2.6 2-2.7-2-2.7 2-2.6-2L8 28z" fill={P.white} {...s} />
      <Path d="M11.5 10h9M11.5 14h9M11.5 18h5" stroke={P.skyD} strokeWidth={1.5} strokeLinecap="round" />
    </G>
  ),
  coin: () => (
    <G>
      <Circle cx={16} cy={16} r={11} fill={P.butter} {...s} />
      <Circle cx={16} cy={16} r={7} fill="none" stroke={P.butterD} strokeWidth={1.4} />
      <Path d="M14 12.5h3.5a2 2 0 0 1 0 4h-3a2 2 0 0 0 0 4H18" fill="none" stroke={P.butterD} strokeWidth={1.4} strokeLinecap="round" />
      {shine(11, 10)}
    </G>
  ),
  plant: () => (
    <G>
      <Path d="M16 17c-5 0-8-4-8-9 5 0 8 4 8 9zM16 17c5 0 8-4 8-9-5 0-8 4-8 9z" fill={P.sage} {...s} />
      <Path d="M16 17V11" {...s} />
      <Path d="M8 17h16l-2 10.5H10z" fill={P.peach} {...s} />
    </G>
  ),
  bubbles: () => (
    <G>
      <Circle cx={12} cy={18} r={7.5} fill={P.sky} {...s} />
      <Circle cx={22} cy={10} r={5} fill={P.lav} {...s} />
      <Circle cx={23.5} cy={23} r={3.5} fill={P.pink} {...s} />
      {shine(9.5, 15.5, 2, 1.1)}
    </G>
  ),
  heart: () => (
    <G>
      <Path d="M16 27S4 19.8 4 11.7A6.2 6.2 0 0 1 16 8.4a6.2 6.2 0 0 1 12 3.3C28 19.8 16 27 16 27z" fill={P.pink} {...s} />
      {shine(10, 11.5)}
    </G>
  ),
  hourglass: () => (
    <G>
      <Path d="M7 4h18M7 28h18" stroke={P.woodD} strokeWidth={2.4} strokeLinecap="round" />
      <Path d="M9 4.5h14c0 6-7 8.5-7 11.5S23 21.5 23 27.5H9C9 21.5 16 19 16 16S9 10.5 9 4.5z" fill={P.sky} {...s} />
      <Path d="M12 25.5h8c-1-2.5-3-4-4-4s-3 1.5-4 4zM12.5 8h7c-.8 2-2.5 3-3.5 3.5-1-.5-2.7-1.5-3.5-3.5z" fill={P.butter} />
    </G>
  ),
  sparkle: () => (
    <G>
      <Path d="M14 4c.8 5.5 3 7.7 8.5 8.5C17 13.3 14.8 15.5 14 21c-.8-5.5-3-7.7-8.5-8.5C11 11.7 13.2 9.5 14 4z" fill={P.butter} {...s} />
      <Path d="M24 18c.4 2.6 1.4 3.6 4 4-2.6.4-3.6 1.4-4 4-.4-2.6-1.4-3.6-4-4 2.6-.4 3.6-1.4 4-4z" fill={P.pink} {...s} strokeWidth={1.3} />
    </G>
  ),
  star: () => (
    <G>
      <Path d="M16 4l3.6 7.4 8 1.2-5.8 5.6 1.4 8L16 22.4l-7.2 3.8 1.4-8-5.8-5.6 8-1.2z" fill={P.butter} {...s} />
      {shine(13.5, 12, 1.6, 0.9)}
    </G>
  ),
  flag: () => (
    <G>
      <Path d="M7 28V4" stroke={P.woodD} strokeWidth={2.2} strokeLinecap="round" />
      <Path d="M7.5 5h18v13h-18z" fill={P.cream} {...s} />
      {[0, 1, 2].map((r) =>
        [0, 1, 2].map((c) =>
          (r + c) % 2 === 0 ? <Rect key={`${r}${c}`} x={7.5 + c * 6} y={5 + r * 4.33} width={6} height={4.33} fill={P.lavD} /> : null,
        ),
      )}
      <Path d="M7.5 5h18v13h-18z" fill="none" {...s} />
    </G>
  ),
  spoon: () => (
    <G transform="rotate(35 16 16)">
      <Ellipse cx={16} cy={9} rx={5} ry={6.5} fill={P.gray} {...s} />
      <Rect x={14.5} y={14.5} width={3} height={14} rx={1.5} fill={P.peach} {...s} />
      {shine(14.5, 7, 1.2, 2)}
    </G>
  ),
  sunrise: () => (
    <G>
      <Path d="M7 21a9 9 0 0 1 18 0z" fill={P.butter} {...s} />
      <Path d="M16 6v3M7 10l2 2M25 10l-2 2M3 16h3M26 16h3" stroke={P.butterD} strokeWidth={2} strokeLinecap="round" />
      <Path d="M3 21h26M8 25.5h16" stroke={P.skyD} strokeWidth={2} strokeLinecap="round" />
    </G>
  ),
  briefcase: () => (
    <G>
      <Path d="M12 9V6.5h8V9" fill="none" {...s} />
      <Rect x={4} y={9} width={24} height={17} rx={3.5} fill={P.wood} {...s} />
      <Path d="M4 16h24" stroke={P.woodD} strokeWidth={1.4} />
      <Rect x={14} y={14} width={4} height={4} rx={1} fill={P.butter} {...s} strokeWidth={1.2} />
    </G>
  ),
  leaf: () => (
    <G>
      <Path d="M16 3l2.2 5 4.3-2-1 5.2 5.5-.5-3 4.3 4 2.5-5.5 1.2 1.5 4.3-4.8-2.2L16 25l-3.2-4.2L8 23l1.5-4.3L4 17.5l4-2.5-3-4.3 5.5.5-1-5.2 4.3 2z" fill={P.orange} {...s} />
      <Path d="M16 13v16" stroke={P.woodD} strokeWidth={1.8} strokeLinecap="round" />
    </G>
  ),
  snowflake: () => (
    <G>
      {[0, 60, 120].map((a) => (
        <G key={a} transform={`rotate(${a} 16 16)`}>
          <Path d="M16 3v26M12.5 6.5 16 9.5l3.5-3M12.5 25.5 16 22.5l3.5 3" fill="none" stroke={P.skyD} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
        </G>
      ))}
      <Circle cx={16} cy={16} r={2.5} fill={P.white} stroke={P.skyD} strokeWidth={1.4} />
    </G>
  ),
  blossom: () => (
    <G>
      {[0, 72, 144, 216, 288].map((a) => {
        const r = ((a - 90) * Math.PI) / 180;
        return <Circle key={a} cx={16 + Math.cos(r) * 6.5} cy={16 + Math.sin(r) * 6.5} r={5.2} fill={P.pink} {...s} />;
      })}
      <Circle cx={16} cy={16} r={3.4} fill={P.butter} {...s} />
    </G>
  ),
  lightning: () => (
    <G>
      <Path d="M18 3 7 18h7.5L12 29l13-16h-8z" fill={P.butter} {...s} />
    </G>
  ),
  cloud: () => (
    <G>
      <Path d="M8 24h16a5.5 5.5 0 0 0 .8-10.9A8 8 0 0 0 9.5 12.5 5.8 5.8 0 0 0 8 24z" fill={P.white} {...s} />
      <Path d="M11 19.5h10" stroke={P.sky} strokeWidth={1.6} strokeLinecap="round" />
    </G>
  ),
  puzzle: () => (
    <G>
      <Path d="M6 9h6a3 3 0 1 1 6 0h6v6a3 3 0 1 1 0 6v6h-6a3 3 0 1 0-6 0H6v-6a3 3 0 1 0 0-6z" fill={P.sage} {...s} />
      {shine(10, 12.5)}
    </G>
  ),
  rainbow: () => (
    <G>
      <Path d="M3 24a13 13 0 0 1 26 0" fill="none" stroke={P.pink} strokeWidth={3.4} strokeLinecap="round" />
      <Path d="M7 24a9 9 0 0 1 18 0" fill="none" stroke={P.butter} strokeWidth={3.4} strokeLinecap="round" />
      <Path d="M11 24a5 5 0 0 1 10 0" fill="none" stroke={P.sage} strokeWidth={3.4} strokeLinecap="round" />
      <Ellipse cx={5.5} cy={25} rx={4} ry={2.5} fill={P.white} {...s} />
      <Ellipse cx={26.5} cy={25} rx={4} ry={2.5} fill={P.white} {...s} />
    </G>
  ),
  tea: () => (
    <G>
      <Path d="M12 6c-1 1.5 1 2.5 0 4M17 5c-1 1.5 1 2.5 0 4" fill="none" stroke={P.skyD} strokeWidth={1.6} strokeLinecap="round" />
      <Path d="M24 15h1.5a3.5 3.5 0 0 1 0 7H23" fill="none" {...s} />
      <Path d="M5 12h19v7a8 8 0 0 1-8 8h-3a8 8 0 0 1-8-8z" fill={P.sage} {...s} />
      <Path d="M3 28h24" stroke={O} strokeWidth={1.8} strokeLinecap="round" />
    </G>
  ),
  dango: () => (
    <G>
      <Path d="M6 28 26 6" stroke={P.woodD} strokeWidth={2} strokeLinecap="round" />
      <Circle cx={21} cy={11} r={4.5} fill={P.pink} {...s} />
      <Circle cx={15.5} cy={16.5} r={4.5} fill={P.cream} {...s} />
      <Circle cx={10} cy={22} r={4.5} fill={P.sage} {...s} />
    </G>
  ),
  gift: () => (
    <G>
      <Rect x={5} y={13} width={22} height={14} rx={2.5} fill={P.peach} {...s} />
      <Rect x={4} y={9} width={24} height={5} rx={2} fill={P.peachD} {...s} />
      <Path d="M16 9v18" stroke={P.lav} strokeWidth={3.4} />
      <Path d="M16 9c-2-4-7-5-7-2s5 2 7 2zM16 9c2-4 7-5 7-2s-5 2-7 2z" fill={P.lav} {...s} />
    </G>
  ),
  cookie: () => (
    <G>
      <Circle cx={16} cy={16} r={11} fill={P.wood} {...s} />
      <Circle cx={12} cy={12} r={1.8} fill={P.woodD} />
      <Circle cx={19} cy={11} r={1.5} fill={P.woodD} />
      <Circle cx={20.5} cy={19} r={1.9} fill={P.woodD} />
      <Circle cx={12.5} cy={20} r={1.5} fill={P.woodD} />
    </G>
  ),
  check: () => (
    <G>
      <Circle cx={16} cy={16} r={11.5} fill={P.sage} {...s} />
      <Path d="M10.5 16.5l3.8 3.8 7.5-8" fill="none" stroke={P.white} strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round" />
    </G>
  ),
  tray: () => (
    <G>
      <Rect x={9} y={5} width={14} height={11} rx={1.5} fill={P.white} {...s} transform="rotate(-6 16 10)" />
      <Path d="M4 16h7l2 3h6l2-3h7v8a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3z" fill={P.sky} {...s} />
    </G>
  ),
  box: () => (
    <G>
      <Path d="M4 11 16 6l12 5v13l-12 5-12-5z" fill={P.wood} {...s} />
      <Path d="M4 11l12 5 12-5M16 16v13" fill="none" {...s} />
      <Path d="M9.5 8.7l12 5" stroke={P.butter} strokeWidth={2.4} />
    </G>
  ),
  pencil: () => (
    <G transform="rotate(40 16 16)">
      <Rect x={13} y={3} width={6} height={20} rx={1.2} fill={P.butter} {...s} />
      <Path d="M13 23h6l-3 6z" fill={P.wood} {...s} />
      <Rect x={13} y={3} width={6} height={4} rx={1.2} fill={P.pink} {...s} />
    </G>
  ),
  lamp: () => (
    <G>
      <Path d="M10 4h12l3 10H7z" fill={P.butter} {...s} />
      <Path d="M16 14v10" stroke={O} strokeWidth={1.8} />
      <Path d="M10 27h12" stroke={O} strokeWidth={2.4} strokeLinecap="round" />
    </G>
  ),
  pebble: () => (
    <G>
      <Path d="M5 18.5C5 12 10.5 7 17 7s10 4.5 10 9.5S22.5 26 15.5 26 5 23.5 5 18.5z" fill="#B9C9C2" stroke="#7F968C" strokeWidth={1.8} />
      <Ellipse cx={13} cy={12.5} rx={4} ry={2} fill="#FFFFFF" opacity={0.65} transform="rotate(-18 13 12.5)" />
    </G>
  ),
};

export { GLYPH_NAMES, glyphFor, isGlyphName, type GlyphName } from './glyphNames';

export function Glyph({ name, size = 28 }: { name: GlyphName | string; size?: number }) {
  const g = GLYPHS[glyphFor(name)];
  return (
    <Svg width={size} height={size} viewBox="0 0 32 32">
      {g()}
    </Svg>
  );
}
