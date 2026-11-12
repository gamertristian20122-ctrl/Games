import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Alert, Pressable, StyleSheet, View } from 'react-native';
import { Glyph, type GlyphName } from '../components/art/Glyph';
import { Pet } from '../components/Pet';
import { Card, IconButton, Row, Screen, T } from '../components/ui';
import { DISPLAY_PRICES, getTipPrices, purchaseTip, type TipSize } from '../lib/purchases';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';

const TIPS: { size: TipSize; glyph: GlyphName; name: string; note: string }[] = [
  { size: 'small', glyph: 'tea' as const, name: 'A cup of tea', note: 'Keeps the late-night coding cozy.' },
  { size: 'medium', glyph: 'dango' as const, name: 'A plate of mochi', note: 'Fuels a whole new quest pack.' },
  { size: 'large', glyph: 'gift' as const, name: 'A care package', note: 'Helps pay for app store fees and test phones.' },
];

export default function TipJar() {
  const { c, motion } = useTheme();
  const { mockStore, settings, updateSettings } = useApp();
  const [prices, setPrices] = useState<Record<TipSize, string>>(DISPLAY_PRICES.tips);
  const [busy, setBusy] = useState<TipSize | null>(null);
  const [hop, setHop] = useState(0);

  useEffect(() => {
    getTipPrices().then(setPrices).catch(() => undefined);
  }, []);

  const thank = async () => {
    await updateSettings({ tipsGiven: settings.tipsGiven + 1 });
    setHop((h) => h + 1);
    Alert.alert('Thank you so much', 'You just made a solo dev\'s whole week. Your pet is doing a happy dance.');
  };

  const tip = async (size: TipSize) => {
    if (busy) return;
    if (mockStore) {
      Alert.alert('Store testing mode', 'Real tips are not set up yet, so this is a test. Nothing will be charged.', [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Test tip', onPress: () => thank() },
      ]);
      return;
    }
    setBusy(size);
    const res = await purchaseTip(size);
    setBusy(null);
    if (res.status === 'success') await thank();
    else if (res.status === 'error') Alert.alert('No worries', res.message);
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
      </Row>
      <View style={{ alignItems: 'center', marginTop: space.md }}>
        <Pet color="butter" hat="party" scarf="none" mood={hop > 0 ? 'happy' : 'idle'} size={150} animate={motion} hopKey={hop} />
        <T variant="title" style={{ textAlign: 'center', marginTop: space.md }}>
          Support the 14-Year-Old Solo Dev
        </T>
      </View>
      <Card tone="butter" style={{ marginTop: space.lg }}>
        <T color={c.ink}>
          Hi! I’m building MochiNook on my own. There are no pop-up ads and your data never leaves your phone. Tips are one-time and totally
          optional. They don’t unlock anything, they just help me keep building.
        </T>
        {settings.tipsGiven > 0 ? (
          <T variant="small" color={c.ink} style={{ marginTop: space.sm }}>
            You’ve tipped {settings.tipsGiven} {settings.tipsGiven === 1 ? 'time' : 'times'}. Thank you, truly.
          </T>
        ) : null}
      </Card>
      <View style={{ gap: space.md, marginTop: space.xl }}>
        {TIPS.map((t) => (
          <Pressable
            key={t.size}
            accessibilityRole="button"
            accessibilityLabel={`Tip ${prices[t.size]}: ${t.name}`}
            disabled={busy !== null}
            onPress={() => tip(t.size)}
            style={({ pressed }) => [styles.tip, { backgroundColor: c.surface, borderColor: c.border, opacity: pressed || busy === t.size ? 0.7 : 1 }]}
          >
            <Glyph name={t.glyph} size={40} />
            <View style={{ flex: 1 }}>
              <T variant="bodyBold">{t.name}</T>
              <T variant="small">{t.note}</T>
            </View>
            <View style={[styles.price, { backgroundColor: c.butter }]}>
              <T variant="bodyBold" color={c.ink}>
                {busy === t.size ? '...' : prices[t.size]}
              </T>
            </View>
          </Pressable>
        ))}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  tip: { flexDirection: 'row', alignItems: 'center', gap: space.md, borderWidth: 1, borderRadius: radius.lg, padding: space.lg, minHeight: 80 },
  price: { borderRadius: radius.pill, paddingHorizontal: space.md, paddingVertical: space.sm },
});
