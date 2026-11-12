import React, { useEffect, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { levelFromXp } from '../lib/progression';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { TreatArt } from './art/DecorArt';
import { Glyph, type GlyphName } from './art/Glyph';
import { Icon } from './Icon';
import { PebbleCount } from './Pebble';
import { Pet, type PetMood } from './Pet';
import { Room } from './Room';
import { ProgressBar, Row, T } from './ui';

export function PetCard({ line, sleepy = false }: { line: string; sleepy?: boolean }) {
  const { pet, petEvent, owned, petCare } = useApp();
  const decor = owned.filter((o) => o.placed === 1).map((o) => o.item_id);
  const { c, motion, calm, scheme } = useTheme();
  // The latest celebration shows until its little moment has passed, then the pet settles back down.
  const [settledId, setSettledId] = useState(0);
  const lvl = levelFromXp(pet.xp);

  useEffect(() => {
    if (!petEvent) return;
    const t = setTimeout(() => setSettledId(petEvent.id), petEvent.kind === 'step' ? 2200 : 3600);
    return () => clearTimeout(t);
  }, [petEvent]);

  const active = petEvent && petEvent.id !== settledId ? petEvent : null;
  const speech = active ? active.line : line;
  const mood: PetMood = active
    ? active.kind === 'level' || active.kind === 'reward'
      ? 'proud'
      : active.kind === 'care' && active.line.includes('night')
        ? 'sleepy'
        : 'happy'
    : sleepy
      ? 'sleepy'
      : 'idle';

  return (
    <View style={[styles.card, { borderColor: c.border, backgroundColor: c.surface }]}>
      <View style={styles.stage}>
        <Room room={pet.room} muted={calm} dark={scheme === 'dark'} decor={decor} />
        <Animated.View
          key={speech}
          entering={motion ? FadeIn.duration(220) : undefined}
          exiting={motion ? FadeOut.duration(120) : undefined}
          style={[styles.bubble, { backgroundColor: c.surface, borderColor: c.border }]}
          accessibilityLiveRegion="polite"
        >
          <T variant="small" color={c.ink}>
            {speech}
          </T>
        </Animated.View>
        {active?.kind === 'treat' ? (
          <View style={styles.treatSpot}>
            <TreatArt id={active.itemId} size={48} />
          </View>
        ) : null}
        <View style={styles.petSpot}>
          <Pet color={pet.color} hat={pet.hat} scarf={pet.scarf} mood={mood} size={150} animate={motion} hopKey={petEvent?.id ?? 0} />
        </View>
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

function CareButton({ glyph, label, onPress }: { glyph: GlyphName; label: string; onPress: () => void }) {
  const { c } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${label} your pet`}
      onPress={onPress}
      style={({ pressed }) => [styles.care, { backgroundColor: c.surfaceAlt, opacity: pressed ? 0.75 : 1 }]}
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
  treatSpot: { position: 'absolute', bottom: 10, right: '20%' },
  petSpot: { marginBottom: 6 },
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
