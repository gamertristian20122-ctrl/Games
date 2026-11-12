import React, { createContext, useContext, useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { useReducedMotion } from 'react-native-reanimated';
import { useApp } from '../state/AppContext';
import { pickPalette, type Palette } from './tokens';

interface Theme {
  c: Palette;
  scheme: 'light' | 'dark';
  calm: boolean;
  /** False in Calm Mode or when the OS "reduce motion" setting is on. */
  motion: boolean;
}

const ThemeContext = createContext<Theme | null>(null);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const { settings } = useApp();
  const system = useColorScheme();
  const reduceMotion = useReducedMotion();
  const scheme: 'light' | 'dark' = settings.theme === 'system' ? (system === 'dark' ? 'dark' : 'light') : settings.theme;
  const value = useMemo<Theme>(
    () => ({
      c: pickPalette(scheme, settings.calmMode),
      scheme,
      calm: settings.calmMode,
      motion: !settings.calmMode && !reduceMotion,
    }),
    [scheme, settings.calmMode, reduceMotion],
  );
  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme(): Theme {
  const t = useContext(ThemeContext);
  if (!t) throw new Error('useTheme must be used inside <ThemeProvider>');
  return t;
}
