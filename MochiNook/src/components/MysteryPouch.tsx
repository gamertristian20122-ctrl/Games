import React, { useState } from 'react';
import { Modal, Pressable, StyleSheet, View } from 'react-native';
import Animated, { Easing, FadeIn, ZoomIn, useAnimatedStyle, useSharedValue, withSequence, withTiming } from 'react-native-reanimated';
import Svg, { Circle, Ellipse, Path } from 'react-native-svg';
import { POUCH_PRICE } from '../data/shop';
import type { PouchPrize } from '../db/repo';
import { notice } from '../lib/dialogs';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { DecorThumb } from './art/DecorArt';
import { Burst } from './art/Particles';
import { PebbleIcon } from './Pebble';
import { PetSvg } from './Pet';
import { Button, Row, T } from './ui';

function PouchArt({ size = 72 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 80 80">
      <Path d="M28 22c-8 8-16 18-16 32 0 12 12 18 28 18s28-6 28-18c0-14-8-24-16-32z" fill="#CDBFE6" stroke="#6B5444" strokeWidth={2.4} strokeLinejoin="round" />
      <Path d="M26 22c4-6 8-10 14-10s10 4 14 10" fill="#E9E1F6" stroke="#6B5444" strokeWidth={2.4} strokeLinejoin="round" />
      <Path d="M26 22q14 6 28 0" fill="none" stroke="#F6B7C6" strokeWidth={3.4} strokeLinecap="round" />
      <Circle cx={40} cy={25} r={3.4} fill="#F3DE9C" stroke="#6B5444" strokeWidth={1.6} />
      <Path d="M40 40l3 6.2 6.8 1-5 4.8 1.2 6.8-6-3.2-6 3.2 1.2-6.8-5-4.8 6.8-1z" fill="#F3DE9C" stroke="#6B5444" strokeWidth={1.4} strokeLinejoin="round" />
      <Ellipse cx={24} cy={46} rx={4} ry={7} fill="#FFFFFF" opacity={0.5} transform="rotate(20 24 46)" />
    </Svg>
  );
}

/** The Cozy Mystery Pouch card at the top of the Pebble shop: shakes, pops, and reveals a surprise. */
export function MysteryPouch({ onWear }: { onWear: (hatId: string) => void }) {
  const { c, motionLevel } = useTheme();
  const { pet, openPouch, tap } = useApp();
  const [opening, setOpening] = useState(false);
  const [prize, setPrize] = useState<PouchPrize | null>(null);
  const [burst, setBurst] = useState(0);
  const shake = useSharedValue(0);
  const pop = useSharedValue(1);

  const style = useAnimatedStyle(() => ({ transform: [{ rotate: `${shake.value}deg` }, { scale: pop.value }] }));
  const affordable = pet.pebbles >= POUCH_PRICE;

  const open = async () => {
    if (opening) return;
    tap();
    if (!affordable) {
      notice(`${POUCH_PRICE - pet.pebbles} more pebbles`, 'Every tiny step you check off earns a pebble. The pouch will wait right here.');
      return;
    }
    setOpening(true);
    const still = motionLevel === 'still';
    const calm = motionLevel === 'calm';
    if (!still) {
      const a = calm ? 5 : 12;
      const d = calm ? 120 : 70;
      shake.set(
        withSequence(
        withTiming(-a, { duration: d }),
        withTiming(a, { duration: d }),
        withTiming(-a, { duration: d }),
        withTiming(a, { duration: d }),
          withTiming(-a / 2, { duration: d }),
          withTiming(0, { duration: d }),
        ),
      );
    }
    // Let the anticipation play, then pop open.
    setTimeout(
      async () => {
        const r = await openPouch();
        if (!still) {
          pop.set(withSequence(withTiming(1.25, { duration: 140, easing: Easing.out(Easing.quad) }), withTiming(1, { duration: calm ? 400 : 260 })));
          setBurst((b) => b + 1);
        }
        setOpening(false);
        if (r.ok) setPrize(r.prize);
        else if (r.reason === 'empty') notice('You’ve collected everything!', 'There’s nothing new left in the pouch right now. Your pebbles are safe.');
        else notice('Almost!', 'You need a few more pebbles for the pouch.');
      },
      still ? 0 : calm ? 760 : 460,
    );
  };

  return (
    <View style={[styles.card, { backgroundColor: c.lavenderSoft, borderColor: c.lavender }]}>
      <Pressable accessibilityRole="button" accessibilityLabel={`Open the Cozy Mystery Pouch for ${POUCH_PRICE} pebbles`} onPress={open} disabled={opening}>
        <Animated.View style={[{ transformOrigin: '50% 100%' }, style]}>
          <PouchArt />
        </Animated.View>
        {burst > 0 && motionLevel !== 'still' ? <Burst key={burst} kind={motionLevel === 'dopamine' ? 'confetti' : 'sparkles'} level={motionLevel} width={72} height={72} seed={burst} /> : null}
      </Pressable>
      <View style={{ flex: 1, gap: 4 }}>
        <T variant="bodyBold">Cozy Mystery Pouch</T>
        <T variant="small" color={c.ink}>
          A surprise room item or hat you don’t have yet.
        </T>
        <Row gap={space.sm} style={{ marginTop: 4 }}>
          <Button label={opening ? 'Opening…' : 'Open'} small kind="lavender" disabled={opening} onPress={open} />
          <Row gap={4} style={{ opacity: affordable ? 1 : 0.6 }}>
            <PebbleIcon size={16} />
            <T variant="bodyBold" color={c.ink}>
              {POUCH_PRICE}
            </T>
          </Row>
        </Row>
      </View>

      <Modal visible={prize !== null} transparent animationType="fade" onRequestClose={() => setPrize(null)}>
        <View style={[styles.backdrop, { backgroundColor: c.overlay }]}>
          {prize ? (
            <Animated.View
              entering={motionLevel === 'still' ? undefined : motionLevel === 'calm' ? FadeIn.duration(400) : ZoomIn.springify().damping(13)}
              style={[styles.reveal, { backgroundColor: c.surface, borderColor: c.border }]}
              accessibilityViewIsModal
              accessibilityLiveRegion="polite"
            >
              <T variant="label">YOU FOUND</T>
              <View style={[styles.prizeArt, { backgroundColor: c.butterSoft }]}>
                {prize.kind === 'decor' ? <DecorThumb id={prize.id} size={90} /> : <PetSvg color={pet.color} hat={prize.id} scarf="none" mood="happy" size={100} />}
                {motionLevel !== 'still' ? <Burst key={`r${burst}`} kind="sparkles" level={motionLevel} width={120} height={120} seed={burst + 99} /> : null}
              </View>
              <T variant="title" style={{ textAlign: 'center' }}>
                {prize.name}!
              </T>
              <T variant="small" style={{ textAlign: 'center' }}>
                {prize.kind === 'decor' ? 'It’s already in your room. Tap it in the shop any time to hide it.' : 'It’s yours to keep, in the Wardrobe.'}
              </T>
              {prize.kind === 'hat' ? (
                <Button
                  label="Put it on"
                  onPress={() => {
                    onWear(prize.id);
                    setPrize(null);
                  }}
                  style={{ alignSelf: 'stretch' }}
                />
              ) : null}
              <Button label="Yay!" kind={prize.kind === 'hat' ? 'soft' : 'primary'} onPress={() => setPrize(null)} style={{ alignSelf: 'stretch' }} />
            </Animated.View>
          ) : null}
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  card: { flexDirection: 'row', alignItems: 'center', gap: space.md, borderWidth: 1.5, borderRadius: radius.lg, padding: space.md, marginTop: space.lg },
  backdrop: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: space.xl },
  reveal: { width: '100%', maxWidth: 360, alignItems: 'center', gap: space.md, borderWidth: 1, borderRadius: radius.xl, padding: space.xl },
  prizeArt: { width: 130, height: 130, borderRadius: 65, alignItems: 'center', justifyContent: 'center' },
});
