import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { PebbleCount, PebbleIcon } from '../../components/Pebble';
import { SHOP_ITEMS, type ShopItem } from '../../data/shop';
import { confirmAction, notice } from '../../lib/dialogs';
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
  const { pet, isPro, updatePet, tap, owned, buyItem, setDecorPlaced } = useApp();
  const decor = owned.filter((o) => o.placed === 1).map((o) => o.item_id);

  const shopTap = async (item: ShopItem) => {
    tap();
    const have = owned.find((o) => o.item_id === item.id);
    if (have) {
      await setDecorPlaced(item.id, have.placed !== 1);
      return;
    }
    if (pet.pebbles < item.price) {
      notice(
        `${item.price - pet.pebbles} more pebbles`,
        `Every tiny step you check off earns a pebble (and a finished quest earns 3 extra). ${item.name} will be right here waiting.`,
      );
      return;
    }
    const verb = item.kind === 'treat' ? 'Give' : 'Get';
    confirmAction(`${verb} ${item.name}?`, `This uses ${item.price} of your ${pet.pebbles} pebbles.`, `${verb} it`, () => {
      buyItem(item.id)
        .then((r) => {
          if (!r.ok && r.reason === 'pebbles') notice('Almost!', 'You need a few more pebbles for this one.');
        })
        .catch(() => undefined);
    });
  };
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
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="title" style={{ flex: 1 }}>
            {pet.name}’s Nook
          </T>
          <PebbleCount value={pet.pebbles} />
        </Row>
        <T variant="small">Level {level} · dress-up, cozy rooms, and the Pebble shop</T>
      </View>
      <View style={[styles.stage, { borderColor: c.border }]}>
        <Room room={pet.room} muted={calm} dark={scheme === 'dark'} decor={decor} />
        <Pet color={pet.color} hat={pet.hat} scarf={pet.scarf} mood="idle" size={170} animate={motion} />
      </View>

      <SectionTitle right={<PebbleCount value={pet.pebbles} />}>Pebble shop</SectionTitle>
      <T variant="small" style={{ marginBottom: space.md }}>
        Earn 1 pebble for every tiny step and 3 extra for a finished quest. Free for everyone, forever. Tap a room item you own to show or hide it.
      </T>
      <View style={styles.grid}>
        {SHOP_ITEMS.map((item) => {
          const have = owned.find((o) => o.item_id === item.id);
          const affordable = pet.pebbles >= item.price;
          const status = have ? (have.placed === 1 ? 'In your room' : 'Stored away') : null;
          return (
            <Pressable
              key={item.id}
              accessibilityRole="button"
              accessibilityLabel={`${item.name}. ${status ?? `${item.price} pebbles`}. ${item.blurb}`}
              onPress={() => shopTap(item)}
              style={({ pressed }) => [
                styles.tile,
                {
                  backgroundColor: have?.placed === 1 ? c.accentSoft : c.surface,
                  borderColor: have?.placed === 1 ? c.accent : c.border,
                  opacity: pressed ? 0.85 : 1,
                },
              ]}
            >
              <Text style={{ fontSize: 28 }}>{item.emoji}</Text>
              <T variant="small" color={c.ink} numberOfLines={2} style={{ textAlign: 'center' }}>
                {item.name}
              </T>
              {status ? (
                <T variant="label" color={c.accentInk}>
                  {status.toUpperCase()}
                </T>
              ) : (
                <Row gap={4} style={{ opacity: affordable ? 1 : 0.55 }}>
                  <PebbleIcon size={14} />
                  <T variant="small" color={c.ink} style={{ fontFamily: 'AtkinsonHyperlegible_700Bold' }}>
                    {item.price}
                  </T>
                </Row>
              )}
            </Pressable>
          );
        })}
      </View>

      {!isPro ? (
        <View style={{ marginTop: space.lg }}>
          <ProUpsell title="Unlock the whole wardrobe" body="Every hat, scarf, color and room, and no Calm pick card. $5.99/month, cancel any time." />
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
    width: '31.6%',
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
