import React, { createContext, useContext, useMemo } from 'react';
import { useColorScheme } from 'react-native';
import { useReducedMotion } from 'react-native-reanimated';
import { useApp } from '../state/AppContext';
import type { MotionLevel } from './motion';
import { pickPalette, type Palette } from './tokens';

interface Theme {
  c: Palette;
  scheme: 'light' | 'dark';
  calm: boolean;
  /** Still (OS reduce motion), calm (Calm Mode) or dopamine. */
  motionLevel: MotionLevel;
  /** False only when the phone's "Reduce motion" setting is on. Calm Mode still moves, gently. */
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
      motionLevel: reduceMotion ? 'still' : settings.calmMode ? 'calm' : 'dopamine',
      motion: !reduceMotion,
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
