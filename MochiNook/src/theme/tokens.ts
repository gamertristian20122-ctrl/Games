export interface Palette {
  bg: string;
  surface: string;
  surfaceAlt: string;
  border: string;
  ink: string;
  inkSoft: string;
  /** Primary action fill (buttons, checks). Text on it uses `onAccent`. */
  accent: string;
  accentSoft: string;
  /** Accent used as text on `bg`/`surface` — tuned for AA contrast. */
  accentInk: string;
  onAccent: string;
  peach: string;
  peachSoft: string;
  lavender: string;
  lavenderSoft: string;
  butter: string;
  butterSoft: string;
  sky: string;
  shadow: string;
  overlay: string;
}

const light: Palette = {
  bg: '#FBF5EC',
  surface: '#FFFDF8',
  surfaceAlt: '#F4ECE1',
  border: '#EADFD2',
  ink: '#3E3833',
  inkSoft: '#6B625A',
  accent: '#A8C3A0',
  accentSoft: '#E3EDDF',
  accentInk: '#4F6E4A',
  onAccent: '#2F3A2C',
  peach: '#F6C6A8',
  peachSoft: '#FCE8DB',
  lavender: '#CDBFE6',
  lavenderSoft: '#EEE8F7',
  butter: '#F3DE9C',
  butterSoft: '#FBF2D5',
  sky: '#BFD8E6',
  shadow: 'rgba(92, 70, 50, 0.10)',
  overlay: 'rgba(62, 56, 51, 0.35)',
};

const dark: Palette = {
  bg: '#24201D',
  surface: '#2F2A26',
  surfaceAlt: '#3A342F',
  border: '#4A423B',
  ink: '#F4EDE4',
  inkSoft: '#CBC1B6',
  accent: '#93B18C',
  accentSoft: '#38443A',
  accentInk: '#B5CFAE',
  onAccent: '#1D261B',
  peach: '#D9A88B',
  peachSoft: '#4A3A31',
  lavender: '#AE9FCB',
  lavenderSoft: '#3D3747',
  butter: '#D6C07E',
  butterSoft: '#453E2A',
  sky: '#8FAEC0',
  shadow: 'rgba(0, 0, 0, 0.35)',
  overlay: 'rgba(0, 0, 0, 0.5)',
};

/** Calm Mode: lower saturation, flatter contrast steps, no loud accents. */
const calmLight: Palette = {
  bg: '#F3F1ED',
  surface: '#FAF9F6',
  surfaceAlt: '#ECE9E4',
  border: '#E0DCD5',
  ink: '#423D39',
  inkSoft: '#6A645E',
  accent: '#C3CEBF',
  accentSoft: '#E6EBE4',
  accentInk: '#56664F',
  onAccent: '#343B31',
  peach: '#E3D3C8',
  peachSoft: '#F1E9E3',
  lavender: '#D6D1DF',
  lavenderSoft: '#ECE9F0',
  butter: '#E5DCC1',
  butterSoft: '#F3EFE3',
  sky: '#D3DDE2',
  shadow: 'rgba(60, 55, 50, 0.06)',
  overlay: 'rgba(66, 61, 57, 0.3)',
};

const calmDark: Palette = {
  bg: '#211F1E',
  surface: '#2A2826',
  surfaceAlt: '#33302E',
  border: '#423E3A',
  ink: '#E9E4DE',
  inkSoft: '#BDB6AE',
  accent: '#7F8F7B',
  accentSoft: '#343A33',
  accentInk: '#AEBDA9',
  onAccent: '#1C211B',
  peach: '#B39C8E',
  peachSoft: '#3D3530',
  lavender: '#9D95AC',
  lavenderSoft: '#35323B',
  butter: '#B3A784',
  butterSoft: '#3A3629',
  sky: '#8796A0',
  shadow: 'rgba(0, 0, 0, 0.25)',
  overlay: 'rgba(0, 0, 0, 0.45)',
};

export function pickPalette(scheme: 'light' | 'dark', calm: boolean): Palette {
  if (calm) return scheme === 'dark' ? calmDark : calmLight;
  return scheme === 'dark' ? dark : light;
}

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 48 } as const;
export const radius = { sm: 10, md: 16, lg: 22, xl: 30, pill: 999 } as const;

export const fonts = {
  display: 'Nunito_800ExtraBold',
  heading: 'Nunito_700Bold',
  body: 'AtkinsonHyperlegible_400Regular',
  bodyBold: 'AtkinsonHyperlegible_700Bold',
} as const;

export const type = {
  hero: { fontFamily: fonts.display, fontSize: 30, lineHeight: 36 },
  title: { fontFamily: fonts.display, fontSize: 24, lineHeight: 30 },
  heading: { fontFamily: fonts.heading, fontSize: 19, lineHeight: 25 },
  body: { fontFamily: fonts.body, fontSize: 17, lineHeight: 25 },
  bodyBold: { fontFamily: fonts.bodyBold, fontSize: 17, lineHeight: 25 },
  small: { fontFamily: fonts.body, fontSize: 15, lineHeight: 21 },
  label: { fontFamily: fonts.bodyBold, fontSize: 13, lineHeight: 17, letterSpacing: 0.6 },
} as const;
