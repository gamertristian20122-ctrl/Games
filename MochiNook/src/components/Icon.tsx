import React from 'react';
import Svg, { Circle, Path } from 'react-native-svg';

export type IconName =
  | 'home'
  | 'list'
  | 'shirt'
  | 'gear'
  | 'leaf'
  | 'check'
  | 'plus'
  | 'scissors'
  | 'lock'
  | 'heart'
  | 'sparkle'
  | 'chevronRight'
  | 'chevronLeft'
  | 'close'
  | 'clock'
  | 'share'
  | 'wand'
  | 'trash'
  | 'minus';

interface Props {
  name: IconName;
  size?: number;
  color: string;
  strokeWidth?: number;
}

/** Hand-drawn, rounded line icons. Pure SVG so they need no icon font. */
export function Icon({ name, size = 24, color, strokeWidth = 2 }: Props) {
  const common = { stroke: color, strokeWidth, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, fill: 'none' };
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      {name === 'home' && <Path {...common} d="M4 11.5 12 5l8 6.5V19a1.5 1.5 0 0 1-1.5 1.5h-4v-5h-5v5h-4A1.5 1.5 0 0 1 4 19z" />}
      {name === 'list' && (
        <>
          <Path {...common} d="M9 7h11M9 12h11M9 17h11" />
          <Circle cx={4.5} cy={7} r={1.2} fill={color} />
          <Circle cx={4.5} cy={12} r={1.2} fill={color} />
          <Circle cx={4.5} cy={17} r={1.2} fill={color} />
        </>
      )}
      {name === 'shirt' && <Path {...common} d="M8 4 4 6.5l2 4 2-1V20h8V9.5l2 1 2-4L16 4c-.7 1.5-2.2 2.5-4 2.5S8.7 5.5 8 4z" />}
      {name === 'gear' && (
        <>
          <Circle {...common} cx={12} cy={12} r={3} />
          <Path {...common} d="M12 3v2.2M12 18.8V21M3 12h2.2M18.8 12H21M5.6 5.6l1.6 1.6M16.8 16.8l1.6 1.6M5.6 18.4l1.6-1.6M16.8 7.2l1.6-1.6" />
        </>
      )}
      {name === 'leaf' && (
        <>
          <Path {...common} d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14z" />
          <Path {...common} d="M5 19c3-4 6-7 9-9" />
        </>
      )}
      {name === 'check' && <Path {...common} d="m5 12.5 4.5 4.5L19 7.5" />}
      {name === 'plus' && <Path {...common} d="M12 5v14M5 12h14" />}
      {name === 'minus' && <Path {...common} d="M5 12h14" />}
      {name === 'scissors' && (
        <>
          <Circle {...common} cx={6.5} cy={6.5} r={2.5} />
          <Circle {...common} cx={6.5} cy={17.5} r={2.5} />
          <Path {...common} d="M8.6 8 19 18M8.6 16 19 6" />
        </>
      )}
      {name === 'lock' && (
        <>
          <Path {...common} d="M6.5 11h11a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1h-11a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1z" />
          <Path {...common} d="M8.5 11V8a3.5 3.5 0 0 1 7 0v3" />
        </>
      )}
      {name === 'heart' && <Path {...common} d="M12 19.5s-7-4.3-7-9.4A3.9 3.9 0 0 1 12 8a3.9 3.9 0 0 1 7 2.1c0 5.1-7 9.4-7 9.4z" />}
      {name === 'sparkle' && <Path {...common} d="M12 3.5c.6 4.2 2.3 5.9 6.5 6.5-4.2.6-5.9 2.3-6.5 6.5-.6-4.2-2.3-5.9-6.5-6.5 4.2-.6 5.9-2.3 6.5-6.5zM18.5 15.5c.3 1.5 1 2.2 2.5 2.5-1.5.3-2.2 1-2.5 2.5-.3-1.5-1-2.2-2.5-2.5 1.5-.3 2.2-1 2.5-2.5z" />}
      {name === 'chevronRight' && <Path {...common} d="m9.5 5.5 6.5 6.5-6.5 6.5" />}
      {name === 'chevronLeft' && <Path {...common} d="M14.5 5.5 8 12l6.5 6.5" />}
      {name === 'close' && <Path {...common} d="m6.5 6.5 11 11M17.5 6.5l-11 11" />}
      {name === 'clock' && (
        <>
          <Circle {...common} cx={12} cy={12} r={8} />
          <Path {...common} d="M12 7.5V12l3 2" />
        </>
      )}
      {name === 'share' && <Path {...common} d="M12 15V4M8 7.5 12 3.5l4 4M6 11v7.5A1.5 1.5 0 0 0 7.5 20h9a1.5 1.5 0 0 0 1.5-1.5V11" />}
      {name === 'wand' && (
        <>
          <Path {...common} d="m4 20 11-11M13 7l2-2 4 4-2 2z" />
          <Path {...common} d="M7 4v3M5.5 5.5h3M19 14v3M17.5 15.5h3" />
        </>
      )}
      {name === 'trash' && <Path {...common} d="M5 7h14M10 7V5h4v2M7 7l1 12.5h8L17 7M10.5 10.5v6M13.5 10.5v6" />}
    </Svg>
  );
}
