import { router } from 'expo-router';
import React, { useState } from 'react';
import { View } from 'react-native';
import Animated, { FadeInRight } from 'react-native-reanimated';
import { Pet } from '../components/Pet';
import { Button, Chip, Pill, ProgressBar, Row, Screen, Spacer, T, TimeStepper } from '../components/ui';
import { PET_NAMES } from '../data/cosmetics';
import { DEFAULT_ANCHORS } from '../db/repo';
import type { Anchors, BlockKind, BrainProfile, Energy } from '../lib/types';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { space } from '../theme/tokens';

const PROFILES: { value: BrainProfile; label: string; sub: string; emoji: string }[] = [
  { value: 'adhd', label: 'ADHD', sub: 'Starting is the hard part. Timers and tiny wins help.', emoji: '⚡' },
  { value: 'autism', label: 'Autism', sub: 'I like things clear, literal, and predictable.', emoji: '🧩' },
  { value: 'audhd', label: 'Both (AuDHD)', sub: 'A little of each, depending on the day.', emoji: '🌈' },
  { value: 'overwhelmed', label: 'Just overwhelmed', sub: "Life is a lot right now. That's reason enough.", emoji: '🫧' },
];

const ENERGY: { value: Energy; label: string; sub: string; emoji: string }[] = [
  { value: 'low', label: 'Low', sub: 'Spoon-Saving Mode: only the essentials.', emoji: '🥄' },
  { value: 'medium', label: 'Medium', sub: 'A gentle, steady routine.', emoji: '🥄🥄' },
  { value: 'high', label: 'High', sub: 'Ready for a few bonus quests.', emoji: '🥄🥄🥄' },
];

const TOTAL_STEPS = 5;

export default function Onboarding() {
  const { c, motion } = useTheme();
  const { finishOnboarding, enableReminders, updateSettings, settings } = useApp();
  const [step, setStep] = useState(0);
  const [petName, setPetName] = useState<string>(PET_NAMES[0]);
  const [profile, setProfile] = useState<BrainProfile | null>(null);
  const [energy, setEnergy] = useState<Energy | null>(null);
  const [anchors, setAnchors] = useState<Anchors>(DEFAULT_ANCHORS);
  const [saving, setSaving] = useState(false);

  const setBlock = (blockKind: BlockKind) => setAnchors((a) => ({ ...a, blockKind }));

  const finish = async (wantsReminders: boolean) => {
    if (!profile || !energy || saving) return;
    setSaving(true);
    try {
      if (!wantsReminders) await updateSettings({ reminders: false });
      await finishOnboarding({ petName, brainProfile: profile, energy, anchors });
      if (wantsReminders) await enableReminders();
      router.replace('/home');
    } finally {
      setSaving(false);
    }
  };

  const enter = motion ? FadeInRight.duration(260) : undefined;

  return (
    <Screen edges={['top', 'bottom']}>
      <View style={{ paddingTop: space.lg, gap: space.sm }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="label">{step === 0 ? 'HELLO' : step <= 3 ? `QUESTION ${step} OF 3` : 'LAST BIT'}</T>
          {step > 0 ? (
            <Button label="Back" kind="ghost" small onPress={() => setStep((s) => s - 1)} />
          ) : settings.onboarded ? (
            <Button label="Cancel" kind="ghost" small onPress={() => router.back()} />
          ) : null}
        </Row>
        <ProgressBar value={(step + 1) / TOTAL_STEPS} height={6} />
      </View>

      <View style={{ alignItems: 'center', marginTop: space.lg }}>
        <Pet color="cream" hat="sprout" scarf="none" mood={step === 4 ? 'happy' : 'idle'} size={step === 0 ? 170 : 110} animate={motion} hopKey={step} />
      </View>

      <Animated.View key={step} entering={enter} style={{ gap: space.md }}>
        {step === 0 && (
          <>
            <T variant="hero">Hi! I’m your new companion.</T>
            <T color={c.inkSoft}>
              I help with the stuff that’s hard to start, one tiny step at a time. No streaks, no guilt, ever. What should you call me?
            </T>
            <Row gap={space.sm} style={{ flexWrap: 'wrap', marginTop: space.sm }}>
              {PET_NAMES.map((n) => (
                <Pill key={n} label={n} selected={petName === n} onPress={() => setPetName(n)} />
              ))}
            </Row>
            <Spacer size={space.md} />
            <Button label={`Nice to meet you, ${petName}`} onPress={() => setStep(1)} />
          </>
        )}

        {step === 1 && (
          <>
            <T variant="title">Which of these sounds like your brain?</T>
            <T variant="small">This only shapes your starter routine. You can change everything later.</T>
            {PROFILES.map((p) => (
              <Chip key={p.value} value={p.value} label={p.label} sublabel={p.sub} emoji={p.emoji} selected={profile === p.value} onSelect={setProfile} />
            ))}
            <Button label="Next" disabled={!profile} onPress={() => setStep(2)} />
          </>
        )}

        {step === 2 && (
          <>
            <T variant="title">How many spoons do you have these days?</T>
            <T variant="small">Spoons = energy. Low is completely okay. You can switch any day from the home screen.</T>
            {ENERGY.map((e) => (
              <Chip key={e.value} value={e.value} label={e.label} sublabel={e.sub} emoji={e.emoji} selected={energy === e.value} onSelect={setEnergy} />
            ))}
            <Button label="Next" disabled={!energy} onPress={() => setStep(3)} />
          </>
        )}

        {step === 3 && (
          <>
            <T variant="title">What do your days roughly look like?</T>
            <T variant="small">Rough guesses are perfect. I’ll use these to place quests at helpful times.</T>
            <TimeStepper label="Wake up" minutes={anchors.wake} onChange={(wake) => setAnchors((a) => ({ ...a, wake }))} />
            <T variant="bodyBold" style={{ marginTop: space.sm }}>
              Daytime block
            </T>
            <Row gap={space.sm} style={{ flexWrap: 'wrap' }}>
              <Pill label="School" selected={anchors.blockKind === 'school'} onPress={() => setBlock('school')} />
              <Pill label="Work" selected={anchors.blockKind === 'work'} onPress={() => setBlock('work')} />
              <Pill label="Neither" selected={anchors.blockKind === 'none'} onPress={() => setBlock('none')} />
            </Row>
            {anchors.blockKind !== 'none' ? (
              <>
                <TimeStepper label="Starts" minutes={anchors.blockStart} onChange={(blockStart) => setAnchors((a) => ({ ...a, blockStart }))} />
                <TimeStepper label="Ends" minutes={anchors.blockEnd} onChange={(blockEnd) => setAnchors((a) => ({ ...a, blockEnd }))} />
              </>
            ) : null}
            <TimeStepper label="Wind-down / bed" minutes={anchors.bed} onChange={(bed) => setAnchors((a) => ({ ...a, bed }))} />
            <Button label="Build my gentle routine" onPress={() => setStep(4)} />
          </>
        )}

        {step === 4 && (
          <>
            <T variant="title">Want me to send soft little nudges?</T>
            <T color={c.inkSoft}>
              Things like “Wind-down time is close. Want to brush teeth together?” Four a day at most, plus laundry timers. Always optional, always kind.
            </T>
            <Spacer size={space.sm} />
            <Button label={saving ? 'Setting up your nook...' : 'Yes, nudge me gently'} icon="heart" disabled={saving} onPress={() => finish(true)} />
            <Button label="Maybe later" kind="soft" disabled={saving} onPress={() => finish(false)} />
          </>
        )}
      </Animated.View>
    </Screen>
  );
}
