import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { Icon } from '../../components/Icon';
import { Pet } from '../../components/Pet';
import { ProUpsell } from '../../components/QuestBits';
import { Room } from '../../components/Room';
import { Row, Screen, SectionTitle, T } from '../../components/ui';
import { HATS, PET_COLORS, ROOMS, SCARVES, type Cosmetic, type CosmeticKind } from '../../data/cosmetics';
import { levelFromXp } from '../../lib/progression';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space } from '../../theme/tokens';

export default function Nook() {
  const { pet, isPro, updatePet, tap } = useApp();
  const { c, motion, calm, scheme } = useTheme();
  const level = levelFromXp(pet.xp).level;

  const choose = (kind: CosmeticKind, item: Cosmetic) => {
    tap();
    if (!item.free && !isPro) {
      router.push('/pro');
      return;
    }
    const key = kind === 'color' ? 'color' : kind;
    updatePet({ [key]: item.id }).catch(() => undefined);
  };

  const selectedId = (kind: CosmeticKind) => (kind === 'color' ? pet.color : kind === 'hat' ? pet.hat : kind === 'scarf' ? pet.scarf : pet.room);

  const section = (kind: CosmeticKind, title: string, items: Cosmetic[], swatch?: (id: string) => string) => (
    <>
      <SectionTitle>{title}</SectionTitle>
      <View style={styles.grid}>
        {items.map((item) => {
          const selected = selectedId(kind) === item.id;
          const locked = !item.free && !isPro;
          return (
            <Pressable
              key={item.id}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              accessibilityLabel={`${item.name}${locked ? ', Pro' : ''}${selected ? ', wearing' : ''}`}
              onPress={() => choose(kind, item)}
              style={({ pressed }) => [
                styles.tile,
                {
                  backgroundColor: selected ? c.accentSoft : c.surface,
                  borderColor: selected ? c.accent : c.border,
                  opacity: pressed ? 0.85 : 1,
                },
              ]}
            >
              {swatch ? <View style={[styles.swatch, { backgroundColor: swatch(item.id), borderColor: c.border }]} /> : null}
              <T variant="small" color={c.ink} numberOfLines={2} style={{ textAlign: 'center' }}>
                {item.name}
              </T>
              {locked ? (
                <View style={[styles.lock, { backgroundColor: c.lavender }]}>
                  <Icon name="lock" size={12} color={c.ink} strokeWidth={2.4} />
                </View>
              ) : null}
            </Pressable>
          );
        })}
      </View>
    </>
  );

  return (
    <Screen>
      <View style={{ paddingTop: space.lg }}>
        <T variant="title">{pet.name}’s Nook</T>
        <T variant="small">Level {level} · dress-up and cozy rooms</T>
      </View>
      <View style={[styles.stage, { borderColor: c.border }]}>
        <Room room={pet.room} muted={calm} dark={scheme === 'dark'} />
        <Pet color={pet.color} hat={pet.hat} scarf={pet.scarf} mood="idle" size={170} animate={motion} />
      </View>

      {!isPro ? (
        <View style={{ marginTop: space.lg }}>
          <ProUpsell title="Unlock the whole wardrobe" body="Every hat, scarf, color and room, and no sponsor card. $5.99/month, cancel any time." />
        </View>
      ) : null}

      {section('color', 'Colors', PET_COLORS, (id) => PET_COLORS.find((p) => p.id === id)?.body ?? '#FFF')}
      {section('hat', 'Hats', HATS)}
      {section('scarf', 'Scarves', SCARVES)}
      {section('room', 'Rooms', ROOMS)}
      <Row style={{ marginTop: space.xl }}>
        <T variant="small">Everything you unlock stays yours to mix and match. Nothing ever runs out.</T>
      </Row>
    </Screen>
  );
}

const styles = StyleSheet.create({
  stage: { height: 250, borderRadius: radius.xl, borderWidth: 1, overflow: 'hidden', alignItems: 'center', justifyContent: 'flex-end', marginTop: space.lg, paddingBottom: 8 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: space.sm },
  tile: {
    width: '31%',
    flexGrow: 1,
    minHeight: 84,
    borderRadius: radius.md,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
    padding: space.sm,
    gap: 6,
  },
  swatch: { width: 30, height: 30, borderRadius: 15, borderWidth: 1 },
  lock: { position: 'absolute', top: 6, right: 6, width: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
});
