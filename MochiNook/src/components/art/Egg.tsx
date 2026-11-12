import React from 'react';
import Svg, { Circle, Ellipse, G, Path } from 'react-native-svg';

const STROKE = '#C9B39C';

/** Zig-zag line where the shell splits. */
const SEAM = 'L24 70 L36 80 L48 68 L60 80 L72 68 L84 80 L96 70 L108 78';

/** Top piece of the shell (flies away on hatching). */
export function EggTop({ size }: { size: number }) {
  return (
    <Svg width={size} height={size * (140 / 120)} viewBox="0 0 120 140">
      <Path d={`M12 78 C13 50 32 8 60 8 C88 8 107 50 108 78 L96 70 L84 80 L72 68 L60 80 L48 68 L36 80 L24 70 Z`} fill="#FFF8EE" stroke={STROKE} strokeWidth={3} strokeLinejoin="round" />
      <Ellipse cx={44} cy={30} rx={10} ry={5} fill="#FFFFFF" opacity={0.8} transform="rotate(-25 44 30)" />
      <Circle cx={74} cy={40} r={4} fill="#F6C6A8" />
      <Circle cx={50} cy={56} r={3} fill="#CDBFE6" />
      <Circle cx={88} cy={60} r={3.5} fill="#A8C3A0" />
    </Svg>
  );
}

/** Bottom piece of the shell, with cracks that grow as the egg is tapped (0–3). */
export function EggBottom({ size, cracks }: { size: number; cracks: number }) {
  return (
    <Svg width={size} height={size * (140 / 120)} viewBox="0 0 120 140">
      <Path d={`M12 78 ${SEAM} C108 116 86 132 60 132 C34 132 12 116 12 88 Z`} fill="#FFF8EE" stroke={STROKE} strokeWidth={3} strokeLinejoin="round" />
      <Circle cx={40} cy={100} r={4} fill="#BFD8E6" />
      <Circle cx={78} cy={108} r={3.5} fill="#F6B7C6" />
      <Circle cx={60} cy={120} r={2.5} fill="#F3DE9C" />
      <G>
        {cracks >= 1 ? <Path d="M48 68 L52 60 L48 52" stroke="#9C8670" strokeWidth={2.4} fill="none" strokeLinecap="round" strokeLinejoin="round" /> : null}
        {cracks >= 2 ? <Path d="M72 68 L70 58 L76 50 L73 42" stroke="#9C8670" strokeWidth={2.4} fill="none" strokeLinecap="round" strokeLinejoin="round" /> : null}
      </G>
    </Svg>
  );
}
