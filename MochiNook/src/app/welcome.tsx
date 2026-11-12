import { router, useLocalSearchParams } from 'expo-router';
import React, { useRef, useState } from 'react';
import { Pressable, StyleSheet, Switch, TextInput, View } from 'react-native';
import Animated, { Easing, FadeIn, useAnimatedStyle, useSharedValue, withSequence, withTiming } from 'react-native-reanimated';
import { EggBottom, EggTop } from '../components/art/Egg';
import { Glyph, type GlyphName } from '../components/art/Glyph';
import { Burst } from '../components/art/Particles';
import { Icon } from '../components/Icon';
import { Pet, type PetReaction } from '../components/Pet';
import { PlusPaywall } from '../components/PlusPaywall';
import { Button, Pill, Row, Screen, T } from '../components/ui';
import { PET_COLORS, PET_NAMES, findColor } from '../data/cosmetics';
import { LIBRARY } from '../db/schema';
import { checkPetName } from '../lib/nameSafety';
import { FRICTION_QUESTS } from '../lib/routineBuilder';
import type { Friction } from '../lib/types';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space, type as typeScale } from '../theme/tokens';

const STARTER_COLORS = PET_COLORS.filter((c) => c.free);

const FRICTIONS: { id: Friction; title: string; sub: string; glyph: GlyphName }[] = [
  { id: 'starting', title: 'Starting tasks', sub: 'I know what to do, I just can’t begin.', glyph: 'rocket' },
  { id: 'time', title: 'Time blindness', sub: 'Time slips away and things sneak up on me.', glyph: 'hourglass' },
  { id: 'sensory', title: 'Sensory overload', sub: 'Noise, lights and busy days drain me fast.', glyph: 'headphones' },
  { id: 'bedtime', title: 'Bedtime wind-down', sub: 'Getting to sleep (and off my phone) is hard.', glyph: 'moon' },
];

const STEPS = 4;

/**
 * First-launch welcome (4 short steps, every one skippable):
 * 1 privacy promise · 2 hatch + color + name · 3 what's hardest (pre-loads Today) · 4 soft Plus preview.
 * Replayable from Settings.
 */
export default function Welcome() {
  const { replay } = useLocalSearchParams<{ replay?: string }>();
  const { c, motionLevel } = useTheme();
  const { finishWelcome, settings, pet } = useApp();
  const replaying = replay === '1' || settings.onboarded;
  const [step, setStep] = useState(0);
  const [cracks, setCracks] = useState(0);
  const [hatched, setHatched] = useState(false);
  const [color, setColor] = useState(replaying && findColor(pet.color).free ? pet.color : 'cream');
  const [name, setName] = useState(replaying ? pet.name : '');
  const [friction, setFriction] = useState<Friction | null>(null);
  const [reminders, setReminders] = useState(true);
  const [reaction, setReaction] = useState<PetReaction | null>(null);
  const [saving, setSaving] = useState(false);
  const lastTap = useRef(0);
  // Empty or symbols-only falls back to Dumpling; unkind words are gently refused.
  const nameCheck = checkPetName(name);
  const petName = nameCheck.ok ? nameCheck.name : 'Dumpling';
  const nameBlocked = !nameCheck.ok && nameCheck.reason === 'unkind';

  const shake = useSharedValue(0);
  const lid = useSharedValue(0);
  const eggStyle = useAnimatedStyle(() => ({ transform: [{ rotate: `${shake.value}deg` }] }));
  const lidStyle = useAnimatedStyle(() => ({
    opacity: 1 - lid.value,
    transform: [{ translateY: -60 * lid.value }, { translateX: 30 * lid.value }, { rotate: `${-35 * lid.value}deg` }],
  }));
  const shellStyle = useAnimatedStyle(() => ({ opacity: 1 - lid.value }));

  const go = (n: number) => {
    // A quick double-tap must never skip a step.
    const now = Date.now();
    if (now - lastTap.current < 450) return;
    lastTap.current = now;
    setStep(n);
  };

  const tapEgg = () => {
    if (hatched) return;
    const next = cracks + 1;
    if (motionLevel !== 'still') {
      const amp = motionLevel === 'calm' ? 4 : 9;
      shake.value = withSequence(
        withTiming(-amp, { duration: 60 }),
        withTiming(amp, { duration: 90 }),
        withTiming(-amp / 2, { duration: 80 }),
        withTiming(0, { duration: 70 }),
      );
    }
    if (next >= 3) {
      setCracks(3);
      setHatched(true);
      lid.value = motionLevel === 'still' ? 1 : withTiming(1, { duration: motionLevel === 'calm' ? 900 : 600, easing: Easing.out(Easing.cubic) });
      setReaction({ id: Date.now(), type: 'bigHop' });
    } else {
      setCracks(next);
    }
  };

  const finish = async () => {
    if (saving) return;
    setSaving(true);
    try {
      await finishWelcome({ petName: petName, color, friction, wantsReminders: reminders });
      router.replace('/home');
    } finally {
      setSaving(false);
    }
  };

  const skipAll = async () => {
    if (replaying) {
      router.back();
      return;
    }
    await finishWelcome({ petName: petName, color, friction, wantsReminders: false });
    router.replace('/home');
  };

  const preview = friction ? FRICTION_QUESTS[friction].map((id) => LIBRARY.find((q) => q.id === id)).filter((q) => q !== undefined) : [];

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ justifyContent: 'space-between', paddingTop: space.md }}>
        <View accessible accessibilityLabel={`Step ${step + 1} of ${STEPS}`} style={{ flexDirection: 'row', gap: 6 }}>
          {Array.from({ length: STEPS }, (_, i) => (
            <View key={i} style={[styles.dot, { backgroundColor: i <= step ? c.accent : c.surfaceAlt, width: i === step ? 22 : 8 }]} />
          ))}
        </View>
        <Pressable accessibilityRole="button" onPress={skipAll} hitSlop={10}>
          <T variant="small" color={c.accentInk}>
            {replaying ? 'Close' : 'Skip setup'}
          </T>
        </Pressable>
      </Row>

      {step === 0 ? (
        <Animated.View entering={motionLevel !== 'still' ? FadeIn.duration(400) : undefined} style={{ alignItems: 'center', gap: space.lg, marginTop: space.xxl }}>
          <View style={{ height: 170, justifyContent: 'flex-end' }}>
            <EggBottom size={120} cracks={0} />
            <View style={StyleSheet.absoluteFill}>
              <View style={{ marginTop: 170 - 140 }}>
                <EggTop size={120} />
              </View>
            </View>
          </View>
          <T variant="hero" style={{ textAlign: 'center' }}>
            Welcome to MochiNook
          </T>
          <T color={c.inkSoft} style={{ textAlign: 'center' }}>
            A cozy companion for brains that find starting, switching and stopping hard. One tiny step at a time, with zero guilt.
          </T>
          <View style={[styles.privacy, { backgroundColor: c.accentSoft, borderColor: c.accent }]}>
            <Icon name="lock" size={18} color={c.accentInk} />
            <T variant="bodyBold" color={c.accentInk}>
              100% private & on-device
            </T>
          </View>
          <T variant="small" style={{ textAlign: 'center' }}>
            No account. No ads tracking you. Everything stays on this phone and works offline.
          </T>
          <Button label="Hatch your mochi" icon="sparkle" style={{ alignSelf: 'stretch', marginTop: space.md }} onPress={() => go(1)} />
        </Animated.View>
      ) : null}

      {step === 1 ? (
        <View style={{ gap: space.md, marginTop: space.lg }}>
          <T variant="title" style={{ textAlign: 'center' }}>
            {hatched ? 'Hello, little one!' : 'Tap the egg to hatch it'}
          </T>
          <View style={styles.hatchStage}>
            {hatched ? (
              <View style={{ position: 'absolute', bottom: 0 }}>
                <Pet color={color} hat="none" scarf="none" mood="happy" size={150} level={motionLevel} reaction={reaction} />
              </View>
            ) : null}
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={hatched ? 'Your mochi hatched' : `Tap to hatch, ${3 - cracks} taps to go`}
              onPress={tapEgg}
              disabled={hatched}
              style={{ position: 'absolute', bottom: 0 }}
            >
              <Animated.View style={[{ transformOrigin: '50% 100%' }, eggStyle]}>
                <Animated.View style={shellStyle}>
                  <EggBottom size={130} cracks={cracks} />
                </Animated.View>
                <Animated.View style={[StyleSheet.absoluteFill, lidStyle]}>
                  <EggTop size={130} />
                </Animated.View>
              </Animated.View>
            </Pressable>
            {hatched && motionLevel !== 'still' ? (
              <Burst key="hatch" kind={motionLevel === 'dopamine' ? 'confetti' : 'sparkles'} level={motionLevel} width={300} height={200} seed={7} />
            ) : null}
          </View>
          {!hatched ? (
            <T variant="small" style={{ textAlign: 'center' }}>
              {cracks === 0 ? 'Give it a gentle tap.' : cracks === 1 ? 'Something’s wiggling…' : 'One more!'}
            </T>
          ) : (
            <Animated.View entering={motionLevel !== 'still' ? FadeIn.duration(500).delay(300) : undefined} style={{ gap: space.md }}>
              <T variant="bodyBold">Pick a color</T>
              <Row gap={space.md} style={{ justifyContent: 'center' }}>
                {STARTER_COLORS.map((col) => (
                  <Pressable
                    key={col.id}
                    accessibilityRole="radio"
                    accessibilityState={{ selected: color === col.id }}
                    accessibilityLabel={col.name}
                    onPress={() => {
                      setColor(col.id);
                      setReaction({ id: Date.now(), type: 'pop' });
                    }}
                    style={[styles.swatch, { backgroundColor: col.body, borderColor: color === col.id ? c.accentInk : col.outline, borderWidth: color === col.id ? 3 : 1.5 }]}
                  />
                ))}
              </Row>
              <T variant="bodyBold">Give your mochi a name</T>
              <TextInput
                value={name}
                onChangeText={setName}
                placeholder="Dumpling"
                placeholderTextColor={c.inkSoft}
                maxLength={20}
                accessibilityLabel="Mochi name"
                style={[typeScale.body, styles.input, { color: c.ink, backgroundColor: c.surface, borderColor: c.border }]}
              />
              <Row gap={space.sm} style={{ flexWrap: 'wrap' }}>
                {['Dumpling', ...PET_NAMES.filter((n) => n !== 'Dumpling')].map((n) => (
                  <Pill key={n} label={n} selected={(petName) === n} onPress={() => setName(n)} />
                ))}
              </Row>
              {nameBlocked && !nameCheck.ok ? (
                <T variant="small" color={c.ink} accessibilityLiveRegion="polite">
                  {nameCheck.message}
                </T>
              ) : null}
              <Button label={nameBlocked ? 'Pick a name' : `Hi, ${petName}!`} disabled={nameBlocked} onPress={() => go(2)} />
            </Animated.View>
          )}
        </View>
      ) : null}

      {step === 2 ? (
        <View style={{ gap: space.md, marginTop: space.lg }}>
          <T variant="title">What’s been hardest lately?</T>
          <T variant="small">Pick one. {petName} will fill your Today tab with tiny quests that help. You can change everything later.</T>
          {FRICTIONS.map((f) => {
            const selected = friction === f.id;
            return (
              <Pressable
                key={f.id}
                accessibilityRole="radio"
                accessibilityState={{ selected }}
                accessibilityLabel={`${f.title}. ${f.sub}`}
                onPress={() => setFriction(f.id)}
                style={[styles.friction, { backgroundColor: selected ? c.accentSoft : c.surface, borderColor: selected ? c.accent : c.border }]}
              >
                <View style={[styles.frictionIcon, { backgroundColor: c.surfaceAlt }]}>
                  <Glyph name={f.glyph} size={30} />
                </View>
                <View style={{ flex: 1 }}>
                  <T variant="bodyBold">{f.title}</T>
                  <T variant="small">{f.sub}</T>
                </View>
              </Pressable>
            );
          })}
          {preview.length > 0 ? (
            <View style={[styles.previewBox, { backgroundColor: c.butterSoft, borderColor: c.border }]}>
              <T variant="label" color={c.ink}>
                ADDING TO YOUR TODAY
              </T>
              <Row gap={space.sm} style={{ flexWrap: 'wrap', marginTop: space.sm }}>
                {preview.map((q) => (
                  <Row key={q.id} gap={4} style={[styles.chip, { backgroundColor: c.surface }]}>
                    <Glyph name={q.emoji} size={18} />
                    <T variant="small" color={c.ink}>
                      {q.title}
                    </T>
                  </Row>
                ))}
              </Row>
            </View>
          ) : null}
          <Row style={{ paddingVertical: space.sm }}>
            <View style={{ flex: 1 }}>
              <T variant="bodyBold">Gentle reminders</T>
              <T variant="small">Up to four soft nudges a day. Always optional.</T>
            </View>
            <Switch
              accessibilityLabel="Gentle reminders"
              value={reminders}
              onValueChange={setReminders}
              trackColor={{ false: c.border, true: c.accent }}
              thumbColor={c.surface}
            />
          </Row>
          <Button label={friction ? 'Fill my Today' : 'Keep it simple for now'} onPress={() => go(3)} />
        </View>
      ) : null}

      {step === 3 ? (
        <View style={{ gap: space.md, marginTop: space.lg }}>
          <View style={{ alignItems: 'center' }}>
            <Pet color={color} hat="wizard" scarf="none" mood="happy" size={120} level={motionLevel} />
          </View>
          <T variant="title" style={{ textAlign: 'center' }}>
            Want a little extra?
          </T>
          <T variant="small" style={{ textAlign: 'center' }}>
            MochiNook is free, forever. Plus is an optional bonus that helps a solo developer keep building.
          </T>
          <PlusPaywall
            onUnlocked={finish}
            footer={
              <Pressable accessibilityRole="button" onPress={finish} disabled={saving} style={{ alignItems: 'center', padding: space.md }}>
                <T variant="bodyBold" color={c.accentInk}>
                  {saving ? 'Setting up your nook…' : 'Continue with Free Version'}
                </T>
              </Pressable>
            }
          />
        </View>
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  dot: { height: 8, borderRadius: 4 },
  privacy: { flexDirection: 'row', alignItems: 'center', gap: space.sm, borderRadius: radius.pill, borderWidth: 1.5, paddingHorizontal: space.lg, paddingVertical: space.sm },
  hatchStage: { height: 190, alignItems: 'center', justifyContent: 'flex-end' },
  swatch: { width: 52, height: 52, borderRadius: 26 },
  input: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: space.md, minHeight: 52 },
  friction: { flexDirection: 'row', alignItems: 'center', gap: space.md, borderWidth: 1.5, borderRadius: radius.md, padding: space.md },
  frictionIcon: { width: 52, height: 52, borderRadius: 26, alignItems: 'center', justifyContent: 'center' },
  previewBox: { borderRadius: radius.md, borderWidth: 1, padding: space.md },
  chip: { borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 4 },
});
