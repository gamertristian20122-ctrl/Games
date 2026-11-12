import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Alert, View } from 'react-native';
import { Icon, type IconName } from '../components/Icon';
import { Pet } from '../components/Pet';
import { Button, Card, IconButton, Row, Screen, T } from '../components/ui';
import { hasEnoughRam } from '../lib/llm';
import { DISPLAY_PRICES, getProPrice, purchasePro, restorePurchases } from '../lib/purchases';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { space } from '../theme/tokens';

const PERKS: { icon: IconName; title: string; body: string }[] = [
  { icon: 'wand', title: 'Private on-device helper', body: 'Type any messy task and get 4–6 tiny, literal steps. Runs 100% on your phone; nothing is uploaded.' },
  { icon: 'shirt', title: 'The whole wardrobe', body: 'Every hat, scarf, and color for your pet.' },
  { icon: 'home', title: 'Cozy room themes', body: 'Rainy Window, Starry Loft, Forest Cabin, and Beach Hut.' },
  { icon: 'leaf', title: 'No sponsor card', body: 'An even quieter home screen.' },
];

export default function Pro() {
  const { c, motion } = useTheme();
  const { isPro, mockStore, updateSettings } = useApp();
  const [price, setPrice] = useState(DISPLAY_PRICES.pro);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    getProPrice().then(setPrice).catch(() => undefined);
  }, []);

  const afterUnlock = () => {
    if (hasEnoughRam()) {
      Alert.alert('Pro is on! 🎉', 'Want to set up the private helper now? It downloads once over Wi-Fi.', [
        { text: 'Later', style: 'cancel', onPress: () => router.back() },
        { text: 'Set it up', onPress: () => router.replace('/helper') },
      ]);
    } else {
      Alert.alert('Pro is on! 🎉', 'Thank you so much. Your pet has a whole new wardrobe to try.', [{ text: 'Yay', onPress: () => router.back() }]);
    }
  };

  const buy = async () => {
    if (busy) return;
    if (mockStore) {
      Alert.alert('Store testing mode', 'Real purchases are not set up yet, so this is a free test unlock. Nothing will be charged.', [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Unlock for testing',
          onPress: async () => {
            await updateSettings({ mockPro: true });
            afterUnlock();
          },
        },
      ]);
      return;
    }
    setBusy(true);
    const result = await purchasePro();
    setBusy(false);
    if (result.status === 'success') afterUnlock();
    else if (result.status === 'error') Alert.alert('No worries', result.message);
  };

  const restore = async () => {
    setBusy(true);
    const res = await restorePurchases();
    setBusy(false);
    if ('error' in res) Alert.alert('Restore', res.error);
    else if (res.isPro) afterUnlock();
    else Alert.alert('Restore', "We didn't find a Pro subscription on this account.");
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ justifyContent: 'flex-end', paddingTop: space.md }}>
        <IconButton icon="close" label="Close" onPress={() => router.back()} />
      </Row>
      <View style={{ alignItems: 'center' }}>
        <Pet color="lavender" hat="wizard" scarf="stripes" mood="happy" size={170} animate={motion} />
        <T variant="hero" style={{ textAlign: 'center', marginTop: space.md }}>
          MochiNook Pro
        </T>
        <T color={c.inkSoft} style={{ textAlign: 'center', marginTop: space.xs }}>
          Everything in Free stays free forever. Pro adds a few extra-cozy things.
        </T>
      </View>

      <View style={{ gap: space.md, marginTop: space.xl }}>
        {PERKS.map((p) => (
          <Row key={p.title} style={{ alignItems: 'flex-start' }}>
            <View style={{ width: 40, height: 40, borderRadius: 20, backgroundColor: c.lavenderSoft, alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={p.icon} size={20} color={c.ink} />
            </View>
            <View style={{ flex: 1 }}>
              <T variant="bodyBold">{p.title}</T>
              <T variant="small">{p.body}</T>
            </View>
          </Row>
        ))}
      </View>

      <Card tone="lavender" style={{ marginTop: space.xl, alignItems: 'center', gap: space.xs }}>
        <T variant="title">{price}/month</T>
        <T variant="small" style={{ textAlign: 'center' }}>
          One simple plan. Cancel any time in your App Store or Google Play settings.
        </T>
      </Card>

      {isPro ? (
        <Button label="You're Pro. Thank you! 💜" kind="soft" style={{ marginTop: space.lg }} onPress={() => router.back()} />
      ) : (
        <Button label={busy ? 'Talking to the store...' : `Start Pro · ${price}/month`} icon="sparkle" disabled={busy} style={{ marginTop: space.lg }} onPress={buy} />
      )}
      <Button label="Restore purchases" kind="ghost" disabled={busy} style={{ marginTop: space.sm }} onPress={restore} />
      <T variant="small" style={{ textAlign: 'center', marginTop: space.md }}>
        Auto-renews monthly until cancelled. Payment is charged to your store account. The on-device helper needs a phone with about 4 GB of memory or more; other phones use Smart Match.
      </T>
    </Screen>
  );
}
