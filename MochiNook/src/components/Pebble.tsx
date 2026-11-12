import React, { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, { FadeIn, FadeOut, useAnimatedStyle, useSharedValue, withSequence, withSpring, withTiming } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Ellipse, Path } from 'react-native-svg';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { T } from './ui';

/** A smooth river pebble. */
export function PebbleIcon({ size = 18 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path d="M4 14.5C4 9 8.5 5 13.5 5S21 8.5 21 12.5 17.5 20 12 20 4 18.5 4 14.5z" fill="#B9C9C2" stroke="#7F968C" strokeWidth={1.6} />
      <Ellipse cx={10.5} cy={10} rx={3.2} ry={1.6} fill="#FFFFFF" opacity={0.65} transform="rotate(-18 10.5 10)" />
    </Svg>
  );
}

export function PebbleCount({ value }: { value: number }) {
  const { c } = useTheme();
  return (
    <View
      style={[styles.count, { backgroundColor: c.surfaceAlt }]}
      accessible
      accessibilityLabel={`${value} pebbles`}
    >
      <PebbleIcon size={16} />
      <T variant="small" color={c.ink} style={{ fontFamily: 'AtkinsonHyperlegible_700Bold' }}>
        {value}
      </T>
    </View>
  );
}

/**
 * "+1 pebble" pop that floats up near the top of the screen after each micro-step.
 * In Calm Mode it simply appears and disappears, with no motion.
 */
export function PebblePop() {
  const { petEvent } = useApp();
  const { c, motion } = useTheme();
  const insets = useSafeAreaInsets();
  const [hiddenId, setHiddenId] = useState(0);
  const lift = useSharedValue(0);
  const scale = useSharedValue(1);

  const amount = petEvent && petEvent.pebbles > 0 ? petEvent.pebbles : 0;
  const id = petEvent?.id ?? 0;

  useEffect(() => {
    if (!amount) return;
    if (motion) {
      lift.value = 0;
      scale.value = 0.6;
      scale.value = withSequence(withSpring(1.15, { damping: 6, stiffness: 260 }), withSpring(1, { damping: 10 }));
      lift.value = withTiming(-26, { duration: 1300 });
    }
    const t = setTimeout(() => setHiddenId(id), 1500);
    return () => clearTimeout(t);
  }, [id, amount, motion, lift, scale]);

  const style = useAnimatedStyle(() => ({ transform: [{ translateY: lift.value }, { scale: scale.value }] }));
  if (!petEvent || amount === 0 || id === hiddenId) return null;

  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFill, { alignItems: 'center', paddingTop: insets.top + space.xxl }]}>
      <Animated.View
        key={id}
        entering={motion ? FadeIn.duration(150) : undefined}
        exiting={motion ? FadeOut.duration(200) : undefined}
        style={[styles.pop, { backgroundColor: c.surface, borderColor: c.border, shadowColor: c.shadow }, motion ? style : null]}
        accessibilityLiveRegion="polite"
        accessibilityLabel={`Plus ${petEvent.pebbles} ${petEvent.pebbles === 1 ? 'pebble' : 'pebbles'}`}
      >
        <PebbleIcon size={22} />
        <T variant="bodyBold">+{petEvent.pebbles}</T>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  count: { flexDirection: 'row', alignItems: 'center', gap: 5, borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 4 },
  pop: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderRadius: radius.pill,
    borderWidth: 1,
    paddingHorizontal: space.lg,
    paddingVertical: space.sm,
    shadowOffset: { width: 0, height: 6 },
    shadowRadius: 16,
    shadowOpacity: 1,
    elevation: 4,
  },
});
