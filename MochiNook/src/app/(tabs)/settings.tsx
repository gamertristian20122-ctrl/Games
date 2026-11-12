import Constants from 'expo-constants';
import { router } from 'expo-router';
import React, { useRef, useState } from 'react';
import { Alert, Pressable, TextInput, View } from 'react-native';
import { Button, Card, Divider, LinkRow, Pill, Row, Screen, Segmented, SectionTitle, T, TimeStepper, ToggleRow } from '../../components/ui';
import { PET_NAMES } from '../../data/cosmetics';
import { confirmAction } from '../../lib/dialogs';
import { TEST_TOOLS_ALLOWED, restorePurchases } from '../../lib/purchases';
import type { Anchors, DevOverride } from '../../lib/types';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space, type as typeScale } from '../../theme/tokens';

export default function SettingsScreen() {
  const app = useApp();
  const { settings, pet, isPro, proSource, mockStore } = app;
  const { c } = useTheme();
  // Drafts are null until the user edits; then they hold the unsaved value.
  const [anchorDraft, setAnchorDraft] = useState<Anchors | null>(null);
  const [nameDraft, setNameDraft] = useState<string | null>(null);
  const anchors = anchorDraft ?? settings.anchors;
  const name = nameDraft ?? pet.name;
  const setAnchors = (update: (a: Anchors) => Anchors) => setAnchorDraft(update(anchors));
  const setName = (n: string) => setNameDraft(n);
  const taps = useRef<number[]>([]);
  const version = Constants.expoConfig?.version ?? '1.0.0';

  const anchorsChanged = anchorDraft !== null && JSON.stringify(anchorDraft) !== JSON.stringify(settings.anchors);

  const onVersionTap = () => {
    if (!TEST_TOOLS_ALLOWED) return;
    const now = Date.now();
    taps.current = [...taps.current.filter((t) => now - t < 3000), now];
    if (taps.current.length >= 5) {
      taps.current = [];
      const unlocked = !settings.devUnlocked;
      app.updateSettings({ devUnlocked: unlocked, devOverride: unlocked ? settings.devOverride : 'auto' }).catch(() => undefined);
      Alert.alert(unlocked ? 'Developer tools on' : 'Developer tools off', unlocked ? 'You can now flip between Free and Pro for testing.' : 'Back to normal.');
    }
  };

  const saveName = () => {
    const trimmed = name.trim().slice(0, 20);
    if (trimmed.length > 0 && trimmed !== pet.name) app.updatePet({ name: trimmed }).catch(() => undefined);
    setNameDraft(null);
  };

  const onReminders = async (on: boolean) => {
    if (!on) {
      await app.updateSettings({ reminders: false });
      return;
    }
    const ok = await app.enableReminders();
    if (!ok) {
      Alert.alert('Notifications are off', 'To get gentle nudges, allow notifications for MochiNook in your phone settings. No pressure at all.');
    }
  };

  const onDeleteAll = () => {
    const run = async () => {
      await app.deleteAllData();
      router.replace('/onboarding');
    };
    const message = `This erases your routine, custom quests, ${pet.name}, Pebbles, shop items and settings from this phone, and cancels reminders. It can’t be undone. A Pro subscription keeps running until you cancel it in Google Play.`;
    confirmAction('Delete all your data?', message, 'Delete everything', () => run().catch(() => undefined), {
      cancelText: 'Keep everything',
      destructive: true,
    });
  };

  const onRestore = async () => {
    const res = await restorePurchases();
    if ('error' in res) Alert.alert('Restore', res.error);
    else Alert.alert('Restore', res.isPro ? 'Pro is back. Welcome home!' : "We didn't find a Pro subscription on this account.");
  };

  return (
    <Screen>
      <View style={{ paddingTop: space.lg }}>
        <T variant="title">Settings</T>
      </View>
      {mockStore ? (
        <Card tone="butter" style={{ marginTop: space.md }}>
          <T variant="label" color={c.ink}>
            TEST BUILD
          </T>
          <T variant="small" color={c.ink}>
            Store keys aren’t set yet, so purchases are free test unlocks. Add the RevenueCat keys before publishing.
          </T>
        </Card>
      ) : null}

      <SectionTitle>Comfort</SectionTitle>
      <Card style={{ paddingVertical: space.sm }}>
        <View style={{ paddingVertical: space.md, gap: space.sm }}>
          <T variant="bodyBold">Sensory style</T>
          <Segmented
            options={[
              { value: 'calm', label: 'Calm' },
              { value: 'dopamine', label: 'Dopamine' },
            ]}
            value={settings.calmMode ? 'calm' : 'dopamine'}
            onChange={(v) => app.updateSettings({ calmMode: v === 'calm' })}
          />
          <T variant="small">
            {settings.calmMode
              ? 'Calm: slow, gentle motion, soft colors, no sounds or vibration, no Calm pick card.'
              : 'Dopamine: bouncy, squishy motion, sparkles and confetti, soft marimba chimes.'}
          </T>
          <T variant="small">If your phone’s “Reduce motion” setting is on, {pet.name} always stays still.</T>
        </View>
        <Divider />
        <ToggleRow label="Soft sounds" hint="Marimba chimes in Dopamine Mode (Calm is always silent)." value={settings.sounds} onChange={(sounds) => app.updateSettings({ sounds })} />
        <Divider />
        <ToggleRow label="Gentle vibration" value={settings.haptics} onChange={(haptics) => app.updateSettings({ haptics })} />
        <Divider />
        <View style={{ paddingVertical: space.md, gap: space.sm }}>
          <T variant="bodyBold">Look</T>
          <Row gap={space.sm}>
            <Pill label="Match phone" selected={settings.theme === 'system'} onPress={() => app.updateSettings({ theme: 'system' })} />
            <Pill label="Light" selected={settings.theme === 'light'} onPress={() => app.updateSettings({ theme: 'light' })} />
            <Pill label="Dark" selected={settings.theme === 'dark'} onPress={() => app.updateSettings({ theme: 'dark' })} />
          </Row>
        </View>
      </Card>

      <SectionTitle>Your pet</SectionTitle>
      <Card style={{ gap: space.md }}>
        <T variant="bodyBold">Name</T>
        <TextInput
          value={name}
          onChangeText={setName}
          onBlur={saveName}
          onSubmitEditing={saveName}
          maxLength={20}
          returnKeyType="done"
          accessibilityLabel="Pet name"
          placeholderTextColor={c.inkSoft}
          style={[typeScale.body, { color: c.ink, backgroundColor: c.surfaceAlt, borderRadius: radius.sm, paddingHorizontal: space.md, minHeight: 48 }]}
        />
        <Row gap={space.sm} style={{ flexWrap: 'wrap' }}>
          {PET_NAMES.map((n) => (
            <Pill
              key={n}
              label={n}
              selected={pet.name === n}
              onPress={() => {
                setNameDraft(null);
                app.updatePet({ name: n }).catch(() => undefined);
              }}
            />
          ))}
        </Row>
      </Card>

      <SectionTitle>Your day</SectionTitle>
      <Card>
        <TimeStepper label="Wake up" minutes={anchors.wake} onChange={(wake) => setAnchors((a) => ({ ...a, wake }))} />
        <Row gap={space.sm} style={{ flexWrap: 'wrap', paddingVertical: space.sm }}>
          <Pill label="School" selected={anchors.blockKind === 'school'} onPress={() => setAnchors((a) => ({ ...a, blockKind: 'school' }))} />
          <Pill label="Work" selected={anchors.blockKind === 'work'} onPress={() => setAnchors((a) => ({ ...a, blockKind: 'work' }))} />
          <Pill label="Neither" selected={anchors.blockKind === 'none'} onPress={() => setAnchors((a) => ({ ...a, blockKind: 'none' }))} />
        </Row>
        {anchors.blockKind !== 'none' ? (
          <>
            <TimeStepper label="Starts" minutes={anchors.blockStart} onChange={(blockStart) => setAnchors((a) => ({ ...a, blockStart }))} />
            <TimeStepper label="Ends" minutes={anchors.blockEnd} onChange={(blockEnd) => setAnchors((a) => ({ ...a, blockEnd }))} />
          </>
        ) : null}
        <TimeStepper label="Wind-down" minutes={anchors.bed} onChange={(bed) => setAnchors((a) => ({ ...a, bed }))} />
        {anchorsChanged ? <Button label="Save my day" small style={{ marginTop: space.md }} onPress={() => {
              app.updateSettings({ anchors }).catch(() => undefined);
              setAnchorDraft(null);
            }} /> : null}
        <Divider />
        <ToggleRow label="Gentle reminders" hint="Up to four soft nudges a day, plus step timers." value={settings.reminders} onChange={onReminders} />
      </Card>

      <SectionTitle>MochiNook Pro</SectionTitle>
      <Card tone="lavender" style={{ paddingVertical: space.sm }}>
        <LinkRow
          icon="sparkle"
          label={isPro ? 'Pro is on. Thank you!' : 'Get Pro · $5.99/month'}
          hint="Full wardrobe, all rooms, no Calm pick card."
          onPress={() => router.push('/pro')}
        />
        <Divider />
        <LinkRow icon="clock" label="Restore purchases" onPress={onRestore} />
      </Card>

      <SectionTitle>Share & support</SectionTitle>
      <Card style={{ paddingVertical: space.sm }}>
        <LinkRow icon="share" label="Caregiver share code" hint="Send or receive a routine. No accounts needed." onPress={() => router.push('/share')} />
        <Divider />
        <LinkRow icon="heart" label="Tip jar" hint="Support the 14-year-old solo dev." onPress={() => router.push('/tip-jar')} />
        <Divider />
        <LinkRow icon="list" label="Rebuild my starter routine" hint="Retake the 3-question quiz." onPress={() => router.push('/onboarding')} />
      </Card>

      <SectionTitle>Privacy</SectionTitle>
      <Card style={{ paddingVertical: space.sm }}>
        <LinkRow
          icon="lock"
          label="Privacy policy & terms"
          hint="Everything stays on your phone. No accounts, ads, or tracking."
          onPress={() => router.push({ pathname: '/legal', params: { doc: 'privacy' } })}
        />
        <Divider />
        <LinkRow icon="trash" label="Delete all my data" hint="Erase everything MochiNook saved on this phone." onPress={onDeleteAll} />
      </Card>

      {TEST_TOOLS_ALLOWED && settings.devUnlocked ? (
        <>
          <SectionTitle>Developer tools</SectionTitle>
          <Card tone="butter" style={{ gap: space.md }}>
            <T variant="small" color={c.ink}>
              Store: {mockStore ? 'testing mode (no real charges)' : 'live RevenueCat'} · Pro source: {proSource}
            </T>
            <Row gap={space.sm}>
              {(['auto', 'free', 'pro'] as DevOverride[]).map((o) => (
                <Pill
                  key={o}
                  label={o === 'auto' ? 'Real status' : o === 'free' ? 'Force Free' : 'Force Pro'}
                  selected={settings.devOverride === o}
                  onPress={() => app.updateSettings({ devOverride: o })}
                />
              ))}
            </Row>
            {mockStore ? (
              <Button
                label={settings.mockPro ? 'Cancel test Pro purchase' : 'Simulate Pro purchase'}
                kind="soft"
                small
                onPress={() => app.updateSettings({ mockPro: !settings.mockPro })}
              />
            ) : null}
          </Card>
        </>
      ) : null}

      <Pressable onPress={onVersionTap} accessibilityRole="text" accessibilityLabel={`MochiNook version ${version}`} style={{ marginTop: space.xxl, alignItems: 'center', padding: space.md }}>
        <T variant="small">MochiNook {version}</T>
        <T variant="small">Made with care. Your data stays on your phone.</T>
      </Pressable>
    </Screen>
  );
}
