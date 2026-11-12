import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Animated, { Easing, FadeIn, useAnimatedStyle, useSharedValue, withDelay, withTiming } from 'react-native-reanimated';
import { levelFromXp } from '../lib/progression';
import { useApp, type PetEvent } from '../state/AppContext';
import type { MotionLevel } from '../theme/motion';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { TreatArt } from './art/DecorArt';
import { Glyph, type GlyphName } from './art/Glyph';
import { Icon } from './Icon';
import { PebbleCount, PebbleIcon } from './Pebble';
import { Pet, type PetMood, type PetReaction } from './Pet';
import { Room } from './Room';
import { ProgressBar, Row, T } from './ui';

const PET_SIZE = 150;
const TUCK_MS = 9000;

/** Which body animation each event plays. */
function reactionFor(e: PetEvent): PetReaction | null {
  switch (e.kind) {
    case 'step':
      return { id: e.id, type: 'hop' };
    case 'quest':
    case 'level':
      return { id: e.id, type: 'bigHop' };
    case 'treat':
      return { id: e.id, type: 'snack' };
    case 'reward':
      return { id: e.id, type: 'pop' };
    case 'care':
      return e.care === 'pat' ? { id: e.id, type: 'pat' } : e.care === 'snack' ? { id: e.id, type: 'snack' } : null;
  }
}

function moodFor(e: PetEvent): PetMood {
  if (e.kind === 'level' || e.kind === 'reward') return 'proud';
  if (e.kind === 'treat' || (e.kind === 'care' && e.care === 'snack')) return 'chew';
  if (e.kind === 'care' && e.care === 'tuck') return 'sleepy';
  return 'happy';
}

export function PetCard({ line, sleepy = false }: { line: string; sleepy?: boolean }) {
  const { pet, petEvent, owned, petCare } = useApp();
  const decor = owned.filter((o) => o.placed === 1).map((o) => o.item_id);
  const { c, motion, motionLevel, calm, scheme } = useTheme();
  // The latest moment plays until it has passed, then the pet settles back down.
  const [settledId, setSettledId] = useState(0);
  const lvl = levelFromXp(pet.xp);

  useEffect(() => {
    if (!petEvent) return;
    const ms = petEvent.kind === 'care' && petEvent.care === 'tuck' ? TUCK_MS : petEvent.kind === 'step' ? 2400 : 3600;
    const t = setTimeout(() => setSettledId(petEvent.id), ms);
    return () => clearTimeout(t);
  }, [petEvent]);

  const active = petEvent && petEvent.id !== settledId ? petEvent : null;
  const speech = active ? active.line : line;
  const mood: PetMood = active ? moodFor(active) : sleepy ? 'sleepy' : 'idle';
  const tucked = active?.kind === 'care' && active.care === 'tuck';
  const reaction = active ? reactionFor(active) : null;
  const snack: { id: number; art: 'cookie' | string } | null =
    active?.kind === 'treat' ? { id: active.id, art: active.itemId } : active?.kind === 'care' && active.care === 'snack' ? { id: active.id, art: 'cookie' } : null;
  const badge = active && (active.xp > 0 || active.pebbles > 0) ? active : null;

  return (
    <View style={[styles.card, { borderColor: c.border, backgroundColor: c.surface }]}>
      <View style={styles.stage}>
        <Room room={pet.room} muted={calm} dark={scheme === 'dark'} decor={decor} />
        <NightDim on={tucked} level={motionLevel} />
        <Animated.View
          key={speech}
          entering={motion ? FadeIn.duration(calm ? 420 : 240) : undefined}
          style={[styles.bubble, { backgroundColor: c.surface, borderColor: c.border }]}
          accessibilityLiveRegion="polite"
        >
          <T variant="small" color={c.ink}>
            {speech}
          </T>
        </Animated.View>
        <View style={styles.petSpot}>
          <Pet color={pet.color} hat={pet.hat} scarf={pet.scarf} mood={mood} size={PET_SIZE} level={motionLevel} reaction={reaction} tucked={tucked} />
        </View>
        {snack ? <SnackFlight key={`s${snack.id}`} art={snack.art} level={motionLevel} /> : null}
        {badge ? <RewardBadges key={`b${badge.id}`} xp={badge.xp} pebbles={badge.pebbles} level={motionLevel} /> : null}
      </View>
      <View style={{ padding: space.lg, gap: space.sm }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="heading">{pet.name}</T>
          <Row gap={space.sm}>
            <PebbleCount value={pet.pebbles} />
            <Row gap={4}>
              <Icon name="heart" size={18} color={c.peach} strokeWidth={2.4} />
              <T variant="small">Level {lvl.level}</T>
            </Row>
          </Row>
        </Row>
        <ProgressBar value={lvl.into / lvl.needed} color={c.peach} />
        <T variant="small">
          {lvl.needed - lvl.into} cozy points until level {lvl.level + 1}
        </T>
        <Row gap={space.sm} style={{ marginTop: space.xs }}>
          <CareButton glyph="hand" label="Pat" onPress={() => petCare('pat')} />
          <CareButton glyph="cookie" label="Snack" onPress={() => petCare('snack')} />
          <CareButton glyph="moon" label="Tuck in" onPress={() => petCare('tuck')} />
        </Row>
      </View>
    </View>
  );
}

/** The room lights dim softly while the pet is tucked in. */
function NightDim({ on, level }: { on: boolean; level: MotionLevel }) {
  const v = useSharedValue(on ? 1 : 0);
  useEffect(() => {
    v.value = level === 'still' ? (on ? 1 : 0) : withTiming(on ? 1 : 0, { duration: level === 'calm' ? 1100 : 700, easing: Easing.inOut(Easing.quad) });
  }, [on, level, v]);
  const style = useAnimatedStyle(() => ({ opacity: v.value * 0.32 }));
  return <Animated.View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: '#1E1A33' }, style]} />;
}

/** A snack floats in from the side toward the pet's mouth, then is happily eaten. */
function SnackFlight({ art, level }: { art: string; level: MotionLevel }) {
  const p = useSharedValue(level === 'still' ? 1 : 0);
  useEffect(() => {
    if (level === 'still') return;
    p.value = withTiming(1, { duration: level === 'calm' ? 900 : 620, easing: Easing.out(Easing.cubic) });
  }, [level, p]);
  const style = useAnimatedStyle(() => {
    const v = p.value;
    return {
      opacity: level === 'still' ? 1 : v < 0.85 ? 1 : 1 - (v - 0.85) / 0.15,
      transform: [
        { translateX: 120 * (1 - v) },
        { translateY: -50 * Math.sin(v * Math.PI) },
        { scale: level === 'still' ? 1 : 1 - 0.45 * Math.max(0, (v - 0.7) / 0.3) },
      ],
    };
  });
  return (
    <Animated.View pointerEvents="none" style={[styles.snack, level === 'still' ? styles.snackStill : null, style]}>
      {art === 'cookie' ? <Glyph name="cookie" size={30} /> : <TreatArt id={art} size={40} />}
    </Animated.View>
  );
}

/** "+5 cozy points" and "+1 pebble" rise from the pet and fade out. */
function RewardBadges({ xp, pebbles, level }: { xp: number; pebbles: number; level: MotionLevel }) {
  const { c } = useTheme();
  const p = useSharedValue(level === 'still' ? 0.4 : 0);
  useEffect(() => {
    if (level === 'still') return;
    p.value = withDelay(200, withTiming(1, { duration: level === 'calm' ? 2200 : 1500, easing: Easing.out(Easing.quad) }));
  }, [level, p]);
  const style = useAnimatedStyle(() => {
    const v = p.value;
    return {
      opacity: level === 'still' ? 1 : v < 0.15 ? v / 0.15 : v > 0.7 ? 1 - (v - 0.7) / 0.3 : 1,
      transform: [{ translateY: -(level === 'calm' ? 26 : 44) * v }],
    };
  });
  return (
    <Animated.View pointerEvents="none" style={[styles.badges, style]} accessibilityLiveRegion="polite">
      {xp > 0 ? (
        <View style={[styles.badge, { backgroundColor: c.surface, borderColor: c.border }]}>
          <Glyph name="heart" size={16} />
          <T variant="label" color={c.ink}>
            +{xp} COZY
          </T>
        </View>
      ) : null}
      {pebbles > 0 ? (
        <View style={[styles.badge, { backgroundColor: c.surface, borderColor: c.border }]}>
          <PebbleIcon size={16} />
          <T variant="label" color={c.ink}>
            +{pebbles} {pebbles === 1 ? 'PEBBLE' : 'PEBBLES'}
          </T>
        </View>
      ) : null}
    </Animated.View>
  );
}

function CareButton({ glyph, label, onPress }: { glyph: GlyphName; label: string; onPress: () => void }) {
  const { c } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${label} your pet`}
      onPress={onPress}
      style={({ pressed }) => [styles.care, { backgroundColor: c.surfaceAlt, opacity: pressed ? 0.75 : 1, transform: [{ scale: pressed ? 0.96 : 1 }] }]}
    >
      <Glyph name={glyph} size={22} />
      <T variant="small" color={c.ink}>
        {label}
      </T>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  care: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6, borderRadius: radius.pill, minHeight: 44 },
  card: { borderRadius: radius.xl, borderWidth: 1, overflow: 'hidden' },
  stage: { height: 232, justifyContent: 'flex-end', alignItems: 'center' },
  petSpot: { marginBottom: 6 },
  snack: { position: 'absolute', bottom: 58, left: '50%', marginLeft: 6 },
  snackStill: { marginLeft: 70, bottom: 14 },
  badges: { position: 'absolute', bottom: 130, flexDirection: 'row', gap: 6 },
  badge: { flexDirection: 'row', alignItems: 'center', gap: 4, borderRadius: radius.pill, borderWidth: 1, paddingHorizontal: 8, paddingVertical: 3 },
  bubble: {
    position: 'absolute',
    top: space.md,
    left: space.md,
    right: space.md,
    borderRadius: radius.md,
    borderWidth: 1,
    paddingHorizontal: space.md,
    paddingVertical: space.sm + 2,
  },
});
