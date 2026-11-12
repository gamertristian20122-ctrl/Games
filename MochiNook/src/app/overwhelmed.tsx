import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Animated, { Easing, SlideInDown, useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Pet } from '../components/Pet';
import { Button, T } from '../components/ui';
import { dayKey } from '../lib/time';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { pickPalette, radius, space } from '../theme/tokens';

/** 4-4-6 breathing: in for 4, hold for 4, out for 6. A longer exhale tells the body it's safe. */
const PHASES = [
  { id: 'in', label: 'Breathe in', seconds: 4 },
  { id: 'hold', label: 'Hold', seconds: 4 },
  { id: 'out', label: 'Breathe out', seconds: 6 },
] as const;

/**
 * The "Overwhelmed?" drawer: always low-stimulation (calm colors whatever the setting),
 * a slow breathing guide with the pet, and a one-tap "Shrink my day".
 */
export default function Overwhelmed() {
  const { pet, settings, updateSettings, tap } = useApp();
  const { scheme, motionLevel } = useTheme();
  const c = pickPalette(scheme, true);
  const insets = useSafeAreaInsets();
  const [tick, setTick] = useState(0);
  const breath = useSharedValue(0);
  const shrunk = settings.shrinkDay === dayKey();

  // One shared clock: phase and countdown are derived from elapsed seconds.
  useEffect(() => {
    const t = setInterval(() => setTick((n) => n + 1), 1000);
    return () => clearInterval(t);
  }, []);
  const cycle = tick % 14;
  const phaseIndex = cycle < 4 ? 0 : cycle < 8 ? 1 : 2;
  const phase = PHASES[phaseIndex]!;
  const left = phaseIndex === 0 ? 4 - cycle : phaseIndex === 1 ? 8 - cycle : 14 - cycle;
  const breaths = Math.floor(tick / 14);

  useEffect(() => {
    if (motionLevel === 'still') return;
    if (phase.id === 'in') breath.value = withTiming(1, { duration: 4000, easing: Easing.inOut(Easing.sin) });
    if (phase.id === 'out') breath.value = withTiming(0, { duration: 6000, easing: Easing.inOut(Easing.sin) });
  }, [phase.id, motionLevel, breath]);

  const ringStyle = useAnimatedStyle(() => ({
    transform: [{ scale: 0.78 + 0.32 * breath.value }],
    opacity: 0.35 + 0.35 * breath.value,
  }));
  const petStyle = useAnimatedStyle(() => ({ transform: [{ scale: 0.94 + 0.1 * breath.value }] }));

  const shrink = async () => {
    tap();
    await updateSettings({ shrinkDay: shrunk ? null : dayKey() });
    router.back();
  };

  return (
    <View style={[StyleSheet.absoluteFill, { backgroundColor: c.overlay }]}>
      <Pressable accessibilityRole="button" accessibilityLabel="Close" style={{ flex: 1 }} onPress={() => router.back()} />
      <Animated.View
        entering={motionLevel !== 'still' ? SlideInDown.duration(motionLevel === 'calm' ? 520 : 380) : undefined}
        style={[styles.sheet, { backgroundColor: c.bg, paddingBottom: insets.bottom + space.lg }]}
        accessibilityViewIsModal
      >
        <View style={[styles.handle, { backgroundColor: c.border }]} />
        <T variant="title" style={{ textAlign: 'center' }}>
          Let’s slow everything down.
        </T>
        <T variant="small" style={{ textAlign: 'center' }}>
          Nothing needs doing right now. Just breathe with {pet.name}.
        </T>

        <View style={styles.breathe}>
          <Animated.View style={[styles.ring, { backgroundColor: c.lavenderSoft, borderColor: c.lavender }, motionLevel === 'still' ? null : ringStyle]} />
          <Animated.View style={motionLevel === 'still' ? null : petStyle}>
            <Pet color={pet.color} hat={pet.hat} scarf={pet.scarf} mood={phase.id === 'out' ? 'sleepy' : 'idle'} size={130} level={motionLevel === 'still' ? 'still' : 'calm'} tappable={false} />
          </Animated.View>
        </View>

        <View accessibilityLiveRegion="polite" style={{ alignItems: 'center' }}>
          <T variant="hero">{phase.label}</T>
          <T variant="title" color={c.inkSoft}>
            {left}
          </T>
          <T variant="small">{breaths > 0 ? `${breaths} slow ${breaths === 1 ? 'breath' : 'breaths'}. You’re doing it.` : 'In for 4 · hold for 4 · out for 6'}</T>
        </View>

        <Button
          label={shrunk ? 'Bring back my whole day' : 'Shrink my day'}
          icon={shrunk ? 'list' : 'leaf'}
          style={{ marginTop: space.lg }}
          onPress={shrink}
          accessibilityHint={shrunk ? 'Shows all of today’s quests again' : 'Hides everything except one tiny self-care step until tomorrow'}
        />
        <T variant="small" style={{ textAlign: 'center' }}>
          {shrunk
            ? 'Your day is shrunk to one tiny self-care step.'
            : 'Hides everything except one tiny self-care step until tomorrow. Nothing is lost.'}
        </T>
        <Button label="I feel a little better" kind="ghost" onPress={() => router.back()} />
        <T variant="small" style={{ textAlign: 'center', marginTop: space.xs }}>
          If you ever feel unsafe, please reach out to someone you trust or your local emergency number.
        </T>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  sheet: { borderTopLeftRadius: radius.xl, borderTopRightRadius: radius.xl, paddingHorizontal: space.xl, paddingTop: space.md, gap: space.sm },
  handle: { alignSelf: 'center', width: 44, height: 5, borderRadius: 3, marginBottom: space.sm },
  breathe: { height: 200, alignItems: 'center', justifyContent: 'center', marginVertical: space.sm },
  ring: { position: 'absolute', width: 190, height: 190, borderRadius: 95, borderWidth: 3 },
});
