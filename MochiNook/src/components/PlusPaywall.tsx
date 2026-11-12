import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Alert, Pressable, StyleSheet, View } from 'react-native';
import { getPlusOffer, purchasePlus, restorePurchases, type PlusOffer, type PlusPlan } from '../lib/purchases';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { Glyph, type GlyphName } from './art/Glyph';
import { Button, Row, T } from './ui';

export const PLUS_PERKS: { glyph: GlyphName; title: string; body: string }[] = [
  {
    glyph: 'notepad',
    title: 'Brain-Dump Splitter',
    body: 'Pour out a messy list and get a separate tiny-step quest for each thing. Works 100% offline; nothing leaves your phone.',
  },
  { glyph: 'hanger', title: 'The whole wardrobe', body: 'Every hat, scarf and color for your mochi.' },
  { glyph: 'couch', title: 'Every cozy room', body: 'Rainy Window, Starry Loft, Forest Cabin and Beach Hut.' },
  { glyph: 'leaf', title: 'An even quieter home', body: 'Hides the Calm pick card for zero clutter.' },
];

/**
 * The MochiNook Plus offer: annual (best value) or monthly, each with a 7-day free trial.
 * `footer` lets the welcome flow add its "Continue with Free Version" link.
 */
export function PlusPaywall({ onUnlocked, footer }: { onUnlocked: () => void; footer?: React.ReactNode }) {
  const { c } = useTheme();
  const { isPro, mockStore, updateSettings, tap } = useApp();
  const [offer, setOffer] = useState<PlusOffer | null>(null);
  const [plan, setPlan] = useState<PlusPlan>('annual');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    getPlusOffer().then(setOffer).catch(() => undefined);
  }, []);

  const trial = offer?.trial[plan] ?? false;
  const price = plan === 'annual' ? (offer?.annual ?? '$34.99') : (offer?.monthly ?? '$6.99');

  const buy = async () => {
    if (busy) return;
    if (mockStore) {
      Alert.alert('Store testing mode', 'Real purchases are not set up yet, so this is a free test unlock. Nothing will be charged.', [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Unlock for testing',
          onPress: async () => {
            await updateSettings({ mockPro: true });
            onUnlocked();
          },
        },
      ]);
      return;
    }
    setBusy(true);
    const result = await purchasePlus(plan);
    setBusy(false);
    if (result.status === 'success') onUnlocked();
    else if (result.status === 'error') Alert.alert('No worries', result.message);
  };

  const restore = async () => {
    setBusy(true);
    const res = await restorePurchases();
    setBusy(false);
    if ('error' in res) Alert.alert('Restore', res.error);
    else if (res.isPro) onUnlocked();
    else Alert.alert('Restore', "We didn't find a Plus subscription on this account.");
  };

  return (
    <View style={{ gap: space.md }}>
      {PLUS_PERKS.map((p) => (
        <Row key={p.title} style={{ alignItems: 'flex-start' }}>
          <View style={[styles.perkIcon, { backgroundColor: c.lavenderSoft }]}>
            <Glyph name={p.glyph} size={26} />
          </View>
          <View style={{ flex: 1 }}>
            <T variant="bodyBold">{p.title}</T>
            <T variant="small">{p.body}</T>
          </View>
        </Row>
      ))}

      {isPro ? (
        <Button label="You have Plus. Thank you!" kind="soft" style={{ marginTop: space.md }} onPress={onUnlocked} />
      ) : (
        <>
          <View style={{ gap: space.sm, marginTop: space.md }}>
            <PlanCard
              selected={plan === 'annual'}
              title={`Yearly · ${offer?.annual ?? '$34.99'}`}
              sub="Just $2.92 a month, billed once a year."
              note="SAVE 58%"
              onPress={() => {
                tap();
                setPlan('annual');
              }}
            />
            <PlanCard
              selected={plan === 'monthly'}
              title={`Monthly · ${offer?.monthly ?? '$6.99'}`}
              sub="Billed every month. Cancel any time."
              onPress={() => {
                tap();
                setPlan('monthly');
              }}
            />
          </View>
          <Button
            label={busy ? 'Talking to the store...' : trial ? 'Start my 7-day free trial' : `Get Plus · ${price}`}
            icon="sparkle"
            disabled={busy}
            onPress={buy}
          />
          <T variant="small" style={{ textAlign: 'center' }}>
            {trial
              ? `Free for 7 days, then ${price} per ${plan === 'annual' ? 'year' : 'month'}. Cancel before the trial ends and you won’t be charged.`
              : `${price} per ${plan === 'annual' ? 'year' : 'month'}.`}{' '}
            Renews automatically until cancelled in Google Play → Payments & subscriptions.
          </T>
          <Button label="Restore purchases" kind="ghost" small disabled={busy} onPress={restore} />
        </>
      )}
      {footer}
      <Row gap={space.lg} style={{ justifyContent: 'center' }}>
        <Button label="Privacy" kind="ghost" small onPress={() => router.push({ pathname: '/legal', params: { doc: 'privacy' } })} />
        <Button label="Terms" kind="ghost" small onPress={() => router.push({ pathname: '/legal', params: { doc: 'terms' } })} />
      </Row>
    </View>
  );
}

function PlanCard({ selected, title, sub, note, onPress }: { selected: boolean; title: string; sub: string; note?: string; onPress: () => void }) {
  const { c } = useTheme();
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={`${title}, ${sub}${note ? `, ${note}` : ''}`}
      onPress={onPress}
      style={[styles.plan, { backgroundColor: selected ? c.lavenderSoft : c.surface, borderColor: selected ? c.lavender : c.border }]}
    >
      <View style={{ flex: 1 }}>
        <Row gap={space.sm}>
          <T variant="bodyBold">{title}</T>
          {note ? (
            <View style={[styles.save, { backgroundColor: c.butter }]}>
              <T variant="label" color={c.onPastel}>
                {note}
              </T>
            </View>
          ) : null}
        </Row>
        <T variant="small">{sub}</T>
      </View>
      <View style={[styles.radio, { borderColor: selected ? c.ink : c.border, backgroundColor: selected ? c.lavender : 'transparent' }]} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  perkIcon: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
  plan: { flexDirection: 'row', alignItems: 'center', gap: space.md, borderWidth: 2, borderRadius: radius.md, padding: space.lg },
  save: { borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2 },
  radio: { width: 24, height: 24, borderRadius: 12, borderWidth: 2 },
});
