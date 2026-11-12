import { router } from 'expo-router';
import React, { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { DECOR, DecorThumb, TreatArt } from '../../components/art/DecorArt';
import { Burst } from '../../components/art/Particles';
import { Glyph } from '../../components/art/Glyph';
import { Icon } from '../../components/Icon';
import { PebbleCount, PebbleIcon } from '../../components/Pebble';
import { Pet, PetSvg, type PetReaction } from '../../components/Pet';
import { ProUpsell } from '../../components/QuestBits';
import { MysteryPouch } from '../../components/MysteryPouch';
import { Room } from '../../components/Room';
import { Button, Row, Screen, Segmented, SectionTitle, T } from '../../components/ui';
import { HATS, PET_COLORS, ROOMS, SCARVES, type Cosmetic, type CosmeticKind } from '../../data/cosmetics';
import { SHOP_ITEMS, findShopItem, type ShopItem } from '../../data/shop';
import { notice } from '../../lib/dialogs';
import { levelFromXp } from '../../lib/progression';
import { SEASON_GLYPH, SEASON_INFO, seasonFor } from '../../lib/season';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space } from '../../theme/tokens';

type Tab = 'decor' | 'wardrobe';
type Preview = { type: 'shop'; id: string } | { type: 'wear'; kind: CosmeticKind; id: string };

const TABS = [
  { value: 'decor', label: 'Room decor' },
  { value: 'wardrobe', label: 'Wardrobe & colors' },
] as const;

const KIND_TITLE: Record<CosmeticKind, string> = { color: 'Colors', hat: 'Hats', scarf: 'Scarves', room: 'Rooms' };

export default function Nook() {
  const { pet, isPro, updatePet, tap, owned, buyItem, setDecorPlaced, canWear } = useApp();
  const { c, motionLevel, calm, scheme } = useTheme();
  const [tab, setTab] = useState<Tab>('decor');
  const [preview, setPreview] = useState<Preview | null>(null);
  const [buying, setBuying] = useState(false);
  // Celebration pops: on the pet when trying on / equipping, and sparkles where a room item lands.
  const [petPop, setPetPop] = useState<PetReaction | null>(null);
  const [decorFx, setDecorFx] = useState<{ id: number; item: string } | null>(null);
  const [stageW, setStageW] = useState(0);
  const pop = () => setPetPop((p) => ({ id: (p?.id ?? 0) + 1, type: 'pop' }));
  const sparkleAt = (item: string) => setDecorFx((d) => ({ id: (d?.id ?? 0) + 1, item }));
  const season = seasonFor();
  const level = levelFromXp(pet.xp).level;

  // ----- what the room viewport shows (live preview overrides) -----
  const placed = owned.filter((o) => o.placed === 1).map((o) => o.item_id);
  const previewItem = preview?.type === 'shop' ? findShopItem(preview.id) : undefined;
  const decor = previewItem?.kind === 'decor' && !placed.includes(previewItem.id) ? [...placed, previewItem.id] : placed;
  const wearPreview = preview?.type === 'wear' ? preview : null;
  const look = {
    color: wearPreview?.kind === 'color' ? wearPreview.id : pet.color,
    hat: wearPreview?.kind === 'hat' ? wearPreview.id : pet.hat,
    scarf: wearPreview?.kind === 'scarf' ? wearPreview.id : pet.scarf,
    room: wearPreview?.kind === 'room' ? wearPreview.id : pet.room,
  };

  // ----- shop -----
  const shopTap = (item: ShopItem) => {
    tap();
    const have = owned.find((o) => o.item_id === item.id);
    if (have) {
      setPreview(null);
      if (have.placed !== 1) sparkleAt(item.id);
      setDecorPlaced(item.id, have.placed !== 1).catch(() => undefined);
      return;
    }
    setPreview({ type: 'shop', id: item.id });
    if (item.kind === 'decor') sparkleAt(item.id);
    else pop();
  };

  const buyPreviewed = async () => {
    if (!previewItem || buying) return;
    setBuying(true);
    const r = await buyItem(previewItem.id);
    setBuying(false);
    if (r.ok) {
      if (previewItem.kind === 'decor') sparkleAt(previewItem.id);
      pop();
      setPreview(null);
    }
    else if (r.reason === 'pebbles') notice('Almost!', 'You need a few more pebbles for this one.');
  };

  // ----- wardrobe -----
  const lists: Record<CosmeticKind, Cosmetic[]> = { color: PET_COLORS, hat: HATS, scarf: SCARVES, room: ROOMS };
  const current = (kind: CosmeticKind) => (kind === 'color' ? pet.color : kind === 'hat' ? pet.hat : kind === 'scarf' ? pet.scarf : pet.room);

  const wearTap = (kind: CosmeticKind, item: Cosmetic) => {
    tap();
    pop();
    if (canWear(kind, item.id)) {
      setPreview(null);
      updatePet({ [kind]: item.id }).catch(() => undefined);
      return;
    }
    setPreview({ type: 'wear', kind, id: item.id });
  };

  const previewWear = wearPreview ? lists[wearPreview.kind].find((i) => i.id === wearPreview.id) : undefined;

  return (
    <Screen scroll={false} contentStyle={{ paddingBottom: 0 }}>
      <Row style={{ justifyContent: 'space-between', paddingTop: space.lg }}>
        <View style={{ flex: 1 }}>
          <T variant="title">{pet.name}’s Nook</T>
          <T variant="small">Level {level} · try anything on before you choose</T>
        </View>
        <PebbleCount value={pet.pebbles} />
      </Row>

      {/* Live viewport: stays put while the lists below scroll. */}
      <View style={[styles.stage, { borderColor: c.border }]} onLayout={(e) => setStageW(e.nativeEvent.layout.width)}>
        <Room room={look.room} muted={calm} dark={scheme === 'dark'} decor={decor} />
        <View style={styles.petSpot}>
          <Pet color={look.color} hat={look.hat} scarf={look.scarf} mood={preview ? 'happy' : 'idle'} size={150} level={motionLevel} reaction={petPop} />
        </View>
        {decorFx && motionLevel !== 'still' && stageW > 0 ? <DecorSparkle key={decorFx.id} item={decorFx.item} stageW={stageW} seed={decorFx.id} level={motionLevel} /> : null}
        {previewItem?.kind === 'treat' ? (
          <View style={styles.treatSpot}>
            <TreatArt id={previewItem.id} size={50} />
          </View>
        ) : null}
        {preview ? (
          <View style={[styles.previewTag, { backgroundColor: c.surface, borderColor: c.border }]}>
            <T variant="label" color={c.ink}>
              PREVIEW
            </T>
          </View>
        ) : null}
      </View>

      {preview ? (
        <View style={[styles.actionBar, { backgroundColor: c.surface, borderColor: c.border }]} accessibilityLiveRegion="polite">
          <View style={{ flex: 1 }}>
            <T variant="bodyBold">{previewItem?.name ?? previewWear?.name}</T>
            <T variant="small">
              {previewItem
                ? pet.pebbles >= previewItem.price
                  ? `${previewItem.price} pebbles · you have ${pet.pebbles}`
                  : `${previewItem.price - pet.pebbles} more pebbles to go`
                : previewWear?.season
                  ? `Earned in ${SEASON_INFO[previewWear.season].name} Sprints`
                  : 'Part of MochiNook Plus'}
            </T>
          </View>
          {previewItem ? (
            <Button
              label={previewItem.kind === 'treat' ? 'Give it' : 'Get it'}
              small
              disabled={buying || pet.pebbles < previewItem.price}
              onPress={buyPreviewed}
            />
          ) : previewWear?.season ? (
            <Button label="See Sprint" small onPress={() => router.push('/week')} />
          ) : (
            <Button label="Unlock" kind="lavender" small onPress={() => router.push('/pro')} />
          )}
          <Pressable accessibilityRole="button" accessibilityLabel="Stop previewing" onPress={() => setPreview(null)} hitSlop={10} style={{ padding: 4 }}>
            <Icon name="close" size={20} color={c.inkSoft} />
          </Pressable>
        </View>
      ) : null}

      <View style={{ marginTop: space.md }}>
        <Segmented
          options={TABS}
          value={tab}
          onChange={(t) => {
            setTab(t);
            setPreview(null);
          }}
        />
      </View>

      {/* key={tab}: each tab gets its own list, so switching always starts at the top. */}
      <ScrollView key={tab} style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: space.xxxl }} showsVerticalScrollIndicator={false}>
        {tab === 'decor' ? (
          <>
            <MysteryPouch
              onWear={(hatId) => {
                pop();
                updatePet({ hat: hatId }).catch(() => undefined);
              }}
            />
            <T variant="small" style={{ marginTop: space.lg }}>
              Earn 1 pebble per tiny step (+3 for a whole quest). Tap anything to see it in the room first. Tap items you own to show or hide them.
            </T>
            <View style={[styles.grid, { marginTop: space.md }]}>
              {SHOP_ITEMS.map((item) => {
                const have = owned.find((o) => o.item_id === item.id);
                const shown = have?.placed === 1;
                const active = preview?.type === 'shop' && preview.id === item.id;
                return (
                  <Pressable
                    key={item.id}
                    accessibilityRole="button"
                    accessibilityState={{ selected: shown || active }}
                    accessibilityLabel={`${item.name}. ${have ? (shown ? 'In your room' : 'Stored away') : `${item.price} pebbles`}. ${item.blurb}`}
                    onPress={() => shopTap(item)}
                    style={({ pressed }) => [
                      styles.tile,
                      {
                        backgroundColor: shown ? c.accentSoft : c.surface,
                        borderColor: active ? c.lavender : shown ? c.accent : c.border,
                        borderWidth: active ? 2.5 : 1.5,
                        opacity: pressed ? 0.85 : 1,
                      },
                    ]}
                  >
                    <View style={[styles.thumb, { backgroundColor: c.surfaceAlt }]}>
                      {item.kind === 'decor' ? <DecorThumb id={item.id} size={54} /> : <TreatArt id={item.id} size={50} />}
                    </View>
                    <T variant="small" color={c.ink} numberOfLines={2} style={{ textAlign: 'center' }}>
                      {item.name}
                    </T>
                    {have ? (
                      <T variant="label" color={shown ? c.accentInk : c.inkSoft}>
                        {shown ? 'IN ROOM' : 'STORED'}
                      </T>
                    ) : (
                      <Row gap={4} style={{ opacity: pet.pebbles >= item.price ? 1 : 0.55 }}>
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
          </>
        ) : (
          <>
            {(['color', 'hat', 'scarf', 'room'] as CosmeticKind[]).map((kind) => (
              <View key={kind}>
                <SectionTitle>{KIND_TITLE[kind]}</SectionTitle>
                <View style={styles.grid}>
                  {lists[kind]
                    // Seasonal items appear during their season, or once earned.
                    .filter((item) => !item.season || item.season === season || canWear(kind, item.id))
                    .map((item) => {
                      const wearing = current(kind) === item.id;
                      const locked = !canWear(kind, item.id);
                      const active = wearPreview?.kind === kind && wearPreview.id === item.id;
                      return (
                        <Pressable
                          key={item.id}
                          accessibilityRole="button"
                          accessibilityState={{ selected: wearing }}
                          accessibilityLabel={`${item.name}${locked ? (item.season ? ', Sprint reward' : ', Plus') : ''}${wearing ? ', wearing' : ''}`}
                          onPress={() => wearTap(kind, item)}
                          style={({ pressed }) => [
                            styles.tile,
                            {
                              backgroundColor: wearing ? c.accentSoft : c.surface,
                              borderColor: active ? c.lavender : wearing ? c.accent : c.border,
                              borderWidth: active ? 2.5 : 1.5,
                              opacity: pressed ? 0.85 : 1,
                            },
                          ]}
                        >
                          <View style={[styles.thumb, { backgroundColor: c.surfaceAlt, opacity: locked ? 0.75 : 1 }]}>
                            {kind === 'room' ? (
                              <View style={styles.roomThumb}>
                                <Room room={item.id} muted={false} dark={false} />
                              </View>
                            ) : (
                              <PetSvg
                                color={kind === 'color' ? item.id : 'cream'}
                                hat={kind === 'hat' ? item.id : 'none'}
                                scarf={kind === 'scarf' ? item.id : 'none'}
                                mood="idle"
                                size={58}
                              />
                            )}
                          </View>
                          <T variant="small" color={c.ink} numberOfLines={2} style={{ textAlign: 'center' }}>
                            {item.name}
                          </T>
                          {locked ? (
                            <View style={[styles.badge, { backgroundColor: item.season ? c.butter : c.lavender }]}>
                              {item.season ? (
                                <Glyph name={SEASON_GLYPH[item.season]} size={14} />
                              ) : (
                                <Icon name="lock" size={12} color={c.ink} strokeWidth={2.4} />
                              )}
                            </View>
                          ) : null}
                        </Pressable>
                      );
                    })}
                </View>
              </View>
            ))}
            {!isPro ? (
              <View style={{ marginTop: space.xl }}>
                <ProUpsell title="Unlock the whole wardrobe" body="Every hat, scarf, color and room, and no Calm pick card. 7-day free trial, then $6.99/month or $34.99/year." />
              </View>
            ) : null}
          </>
        )}
      </ScrollView>
    </Screen>
  );
}

const STAGE_H = 210;

/** Sparkles exactly where a room item appears (maps the room's 360×240 "slice" viewBox onto the stage). */
function DecorSparkle({ item, stageW, seed, level }: { item: string; stageW: number; seed: number; level: 'calm' | 'dopamine' }) {
  const def = DECOR[item];
  if (!def) return null;
  const scale = Math.max(stageW / 360, STAGE_H / 240);
  const offX = (stageW - 360 * scale) / 2;
  const offY = (STAGE_H - 240 * scale) / 2;
  const [x, y, w, h] = def.box;
  const cx = (x + w / 2) * scale + offX;
  const cy = (y + h / 2) * scale + offY;
  const box = 90;
  return (
    <View pointerEvents="none" style={{ position: 'absolute', left: cx - box / 2, top: cy - box / 2, width: box, height: box }}>
      <Burst kind="sparkles" level={level} width={box} height={box} seed={seed} />
    </View>
  );
}

const styles = StyleSheet.create({
  stage: {
    height: STAGE_H,
    borderRadius: radius.xl,
    borderWidth: 1,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'flex-end',
    marginTop: space.md,
  },
  petSpot: { marginBottom: 4 },
  treatSpot: { position: 'absolute', bottom: 12, right: '22%' },
  previewTag: { position: 'absolute', top: space.sm, left: space.sm, borderRadius: radius.pill, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 3 },
  actionBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.sm,
    borderWidth: 1,
    borderRadius: radius.md,
    padding: space.sm,
    paddingLeft: space.md,
    marginTop: space.sm,
  },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: space.sm },
  tile: {
    width: '31.6%',
    minHeight: 120,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    padding: space.sm,
    gap: 4,
  },
  thumb: { width: 64, height: 64, borderRadius: 32, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
  roomThumb: { width: 64, height: 64 },
  badge: { position: 'absolute', top: 6, right: 6, width: 22, height: 22, borderRadius: 11, alignItems: 'center', justifyContent: 'center' },
});
