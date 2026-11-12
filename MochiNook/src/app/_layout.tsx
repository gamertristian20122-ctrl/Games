import { AtkinsonHyperlegible_400Regular } from '@expo-google-fonts/atkinson-hyperlegible/400Regular';
import { AtkinsonHyperlegible_700Bold } from '@expo-google-fonts/atkinson-hyperlegible/700Bold';
import { Nunito_700Bold } from '@expo-google-fonts/nunito/700Bold';
import { Nunito_800ExtraBold } from '@expo-google-fonts/nunito/800ExtraBold';
import { useFonts } from 'expo-font';
import { SplashScreen, Stack, type ErrorBoundaryProps } from 'expo-router';
import { SQLiteProvider } from 'expo-sqlite';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect } from 'react';
import { Pressable, Text, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { PebblePop } from '../components/Pebble';
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
        <Stack.Screen name="legal" options={{ animation: 'slide_from_right' }} />
        <Stack.Screen name="focus" options={{ animation: 'slide_from_bottom' }} />
        <Stack.Screen name="race" options={{ animation: 'slide_from_right' }} />
      </Stack>
      <PebblePop />
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

/** Friendly crash screen (Expo Router shows this instead of a blank screen). */
export function ErrorBoundary({ retry }: ErrorBoundaryProps) {
  return (
    <View style={{ flex: 1, backgroundColor: '#FBF5EC', alignItems: 'center', justifyContent: 'center', padding: 24, gap: 16 }}>
      <Text style={{ fontSize: 48 }}>🫧</Text>
      <Text style={{ fontSize: 22, fontWeight: '800', color: '#3E3833', textAlign: 'center' }}>Oops, something got tangled.</Text>
      <Text style={{ fontSize: 17, color: '#6B625A', textAlign: 'center' }}>
        Your data is safe on your phone. Want to try again?
      </Text>
      <Pressable
        accessibilityRole="button"
        onPress={retry}
        style={{ backgroundColor: '#A8C3A0', borderRadius: 999, paddingHorizontal: 28, minHeight: 52, justifyContent: 'center' }}
      >
        <Text style={{ fontSize: 17, fontWeight: '700', color: '#2F3A2C' }}>Try again</Text>
      </Pressable>
    </View>
  );
}
