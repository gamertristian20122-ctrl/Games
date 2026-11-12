import React, { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { levelFromXp } from '../lib/progression';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { Icon } from './Icon';
import { PebbleCount } from './Pebble';
import { Pet, type PetMood } from './Pet';
import { Room } from './Room';
import { ProgressBar, Row, T } from './ui';

export function PetCard({ line, sleepy = false }: { line: string; sleepy?: boolean }) {
  const { pet, petEvent, owned } = useApp();
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
  const mood: PetMood = active ? (active.kind === 'level' ? 'proud' : 'happy') : sleepy ? 'sleepy' : 'idle';

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
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { borderRadius: radius.xl, borderWidth: 1, overflow: 'hidden' },
  stage: { height: 232, justifyContent: 'flex-end', alignItems: 'center' },
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
