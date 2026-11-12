import { AtkinsonHyperlegible_400Regular } from '@expo-google-fonts/atkinson-hyperlegible/400Regular';
import { AtkinsonHyperlegible_700Bold } from '@expo-google-fonts/atkinson-hyperlegible/700Bold';
import { Nunito_700Bold } from '@expo-google-fonts/nunito/700Bold';
import { Nunito_800ExtraBold } from '@expo-google-fonts/nunito/800ExtraBold';
import { useFonts } from 'expo-font';
import { SplashScreen, Stack } from 'expo-router';
import { SQLiteProvider } from 'expo-sqlite';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { DATABASE_NAME, migrateDatabase } from '../db/schema';
import { configureNotificationHandler, ensureChannels } from '../lib/notifications';
import { AppProvider } from '../state/AppContext';
import { ThemeProvider, useTheme } from '../theme/ThemeContext';
import { fonts } from '../theme/tokens';

SplashScreen.preventAutoHideAsync().catch(() => undefined);
configureNotificationHandler();
ensureChannels().catch(() => undefined);

function Navigator() {
  const { c, scheme } = useTheme();
  useEffect(() => {
    SplashScreen.hideAsync().catch(() => undefined);
  }, []);
  return (
    <>
      <StatusBar style={scheme === 'dark' ? 'light' : 'dark'} />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: c.bg },
          animation: 'fade',
          headerStyle: { backgroundColor: c.bg },
          headerTintColor: c.ink,
          headerTitleStyle: { fontFamily: fonts.heading },
          headerShadowVisible: false,
        }}
      >
        <Stack.Screen name="index" />
        <Stack.Screen name="onboarding" options={{ gestureEnabled: false }} />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="quest/[id]" options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="custom-quest" options={{ animation: 'slide_from_bottom' }} />
        <Stack.Screen name="pro" options={{ presentation: 'modal', animation: 'slide_from_bottom' }} />
        <Stack.Screen name="tip-jar" options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="share" options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="helper" options={{ animation: 'slide_from_right' }} />
      </Stack>
    </>
  );
}

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    [fonts.display]: Nunito_800ExtraBold,
    [fonts.heading]: Nunito_700Bold,
    [fonts.body]: AtkinsonHyperlegible_400Regular,
    [fonts.bodyBold]: AtkinsonHyperlegible_700Bold,
  });

  // If fonts somehow fail we still start: the system font is a fine fallback.
  if (!fontsLoaded && !fontError) return null;

  return (
    <SafeAreaProvider>
      <SQLiteProvider databaseName={DATABASE_NAME} onInit={migrateDatabase}>
        <AppProvider>
          <ThemeProvider>
            <Navigator />
          </ThemeProvider>
        </AppProvider>
      </SQLiteProvider>
    </SafeAreaProvider>
  );
}
