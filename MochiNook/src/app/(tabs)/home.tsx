import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, { FadeIn } from 'react-native-reanimated';
import { Icon } from '../../components/Icon';
import { PetCard } from '../../components/PetCard';
import { ANCHOR_LABEL, QuestListItem, SponsorCard } from '../../components/QuestBits';
import { Button, Card, Pill, Row, Screen, SectionTitle, T } from '../../components/ui';
import * as repo from '../../db/repo';
import { allClearLine, idleLine, spoonSavingLines } from '../../lib/copy';
import { currentAnchor, dayKey, greeting, minutesNow } from '../../lib/time';
import type { Anchor, Energy, QuestWithProgress, StepWithState } from '../../lib/types';
import { useAssistant } from '../../lib/useAssistant';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space } from '../../theme/tokens';

const ANCHOR_SEQUENCE: Record<Exclude<Anchor, 'anytime'>, Anchor[]> = {
  morning: ['morning', 'anytime', 'daytime', 'evening'],
  daytime: ['daytime', 'anytime', 'evening', 'morning'],
  evening: ['evening', 'anytime', 'daytime', 'morning'],
};

function isFinished(q: QuestWithProgress): boolean {
  return q.completedToday || (q.steps.length > 0 && q.doneCount >= q.steps.length);
}

export default function Home() {
  const db = useSQLiteContext();
  const { c, calm, motion } = useTheme();
  const app = useApp();
  const { settings, isPro, dataVersion, welcomeBackLine } = app;
  const assistant = useAssistant();
  const [quests, setQuests] = useState<QuestWithProgress[]>([]);
  const [skip, setSkip] = useState(0);
  const [showAll, setShowAll] = useState(false);
  const now = minutesNow();
  const today = dayKey();

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      repo.getTodayQuests(db, today).then((q) => {
        if (alive) setQuests(q);
      });
      return () => {
        alive = false;
      };
      // dataVersion is a deliberate refetch trigger: it bumps whenever any quest data changes.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [db, today, dataVersion]),
  );

  const spoonSaving = settings.energy === 'low';
  // Small lists: plain derivations are plenty fast (and the React Compiler memoizes them).
  const visible = spoonSaving && !showAll ? quests.filter((q) => q.essential === 1) : quests;
  const part = currentAnchor(settings.anchors, now);
  const order = ANCHOR_SEQUENCE[part];
  const ordered = [...visible].sort((a, b) => order.indexOf(a.anchor) - order.indexOf(b.anchor));
  const candidates = ordered
    .filter((q) => !isFinished(q))
    .map((q) => ({ quest: q, step: q.steps.find((s) => !s.done) }))
    .filter((x): x is { quest: QuestWithProgress; step: StepWithState } => x.step !== undefined);
  const next = candidates.length > 0 ? candidates[skip % candidates.length] : undefined;
  const grouped = order
    .map((anchor) => ({ anchor, items: visible.filter((q) => q.anchor === anchor) }))
    .filter((g) => g.items.length > 0);

  const doneCount = visible.filter(isFinished).length;
  const line = welcomeBackLine ?? (spoonSaving ? spoonSavingLines[0] : idleLine(new Date().getDate() + now / 97));

  const setEnergy = (energy: Energy) => {
    app.updateSettings({ energy }).catch(() => undefined);
    setShowAll(false);
  };

  const makeSmaller = async (step: StepWithState) => {
    const parts = assistant.smaller(step.text, step.tiny);
    if (!parts) return;
    await repo.replaceStepWithSmaller(db, step, parts);
    app.touchData();
  };

  return (
    <Screen>
      <Row style={{ justifyContent: 'space-between', paddingTop: space.lg, paddingBottom: space.lg }}>
        <View style={{ flex: 1 }}>
          <T variant="label">{new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' }).toUpperCase()}</T>
          <T variant="title">{greeting(now)}</T>
        </View>
        <CalmButton />
      </Row>

      <PetCard line={line} sleepy={welcomeBackLine !== null} />
      {welcomeBackLine ? (
        <Button label="Hi! Let's do one tiny thing" kind="soft" small style={{ marginTop: space.md }} onPress={app.dismissWelcome} />
      ) : null}

      <SectionTitle>Today’s single next step</SectionTitle>
      {next ? (
        <Animated.View key={`${next.step.id}`} entering={motion ? FadeIn.duration(250) : undefined}>
          <Card tone="accent" style={{ gap: space.md }}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`Open quest ${next.quest.title}`}
              onPress={() => router.push({ pathname: '/quest/[id]', params: { id: next.quest.id } })}
            >
              <Row gap={space.sm}>
                <Text style={{ fontSize: 18 }}>{next.quest.emoji}</Text>
                <T variant="small" color={c.accentInk} style={{ flex: 1 }}>
                  {next.quest.title} · step {next.quest.steps.indexOf(next.step) + 1} of {next.quest.steps.length}
                </T>
              </Row>
            </Pressable>
            <T variant="heading" style={{ fontSize: 22, lineHeight: 29 }}>
              {next.step.text}
            </T>
            <Button label="I did it!" icon="check" onPress={() => app.checkStep(next.quest, next.step)} />
            <Row gap={space.sm}>
              {assistant.canMakeSmaller(next.step.text, next.step.tiny) ? (
                <Button label="Make it smaller" icon="scissors" kind="soft" small style={{ flex: 1 }} onPress={() => makeSmaller(next.step)} />
              ) : null}
              <Button label="Not this one" kind="soft" small style={{ flex: 1 }} onPress={() => setSkip((s) => s + 1)} />
            </Row>
            {!assistant.canMakeSmaller(next.step.text, next.step.tiny) ? (
              <T variant="small" color={c.accentInk}>
                This one is already a single tiny action. ✨
              </T>
            ) : null}
          </Card>
        </Animated.View>
      ) : (
        <Card tone="accent">
          <T variant="heading">{visible.length === 0 ? 'Nothing on the list yet' : 'All clear for now ✨'}</T>
          <T variant="small" style={{ marginTop: 4 }}>
            {visible.length === 0 ? 'Want to pick a quest or two from the library? No pressure.' : allClearLine}
          </T>
          {visible.length === 0 ? (
            <Button label="Browse quests" kind="soft" small style={{ marginTop: space.md }} onPress={() => router.push('/quests')} />
          ) : null}
        </Card>
      )}

      <SectionTitle>Spoons today</SectionTitle>
      <Row gap={space.sm}>
        <Pill label="🥄 Low" selected={settings.energy === 'low'} onPress={() => setEnergy('low')} />
        <Pill label="Steady" selected={settings.energy === 'medium'} onPress={() => setEnergy('medium')} />
        <Pill label="High" selected={settings.energy === 'high'} onPress={() => setEnergy('high')} />
      </Row>
      {spoonSaving ? (
        <View style={[styles.note, { backgroundColor: c.butterSoft, borderColor: c.border }]}>
          <T variant="small" color={c.ink}>
            {showAll ? 'Showing everything. The essentials are still the only ones that matter today.' : spoonSavingLines[0]}
          </T>
          <Pressable accessibilityRole="button" onPress={() => setShowAll((v) => !v)} hitSlop={8}>
            <T variant="small" color={c.accentInk} style={{ marginTop: 6 }}>
              {showAll ? 'Back to essentials only' : 'Show everything anyway'}
            </T>
          </Pressable>
        </View>
      ) : null}

      <SectionTitle
        right={
          visible.length > 0 ? (
            <T variant="small">
              {doneCount} of {visible.length} done
            </T>
          ) : undefined
        }
      >
        Today’s gentle plan
      </SectionTitle>
      <View style={{ gap: space.lg }}>
        {grouped.map((g) => (
          <View key={g.anchor} style={{ gap: space.sm }}>
            <T variant="label">{ANCHOR_LABEL[g.anchor].toUpperCase()}</T>
            {g.items.map((q) => (
              <QuestListItem key={q.id} quest={q} />
            ))}
          </View>
        ))}
      </View>
      <Button label="Add a quest of my own" icon="plus" kind="soft" style={{ marginTop: space.xl }} onPress={() => router.push('/custom-quest')} />

      {/* Free tier only. Calm Mode also hides it: zero clutter. */}
      {!isPro && !calm ? <SponsorCard /> : null}
    </Screen>
  );
}

function CalmButton() {
  const { c, calm } = useTheme();
  const { toggleCalm } = useApp();
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityState={{ checked: calm }}
      accessibilityLabel="Calm Mode"
      accessibilityHint="Stops animations, sounds and vibration, and softens colors"
      onPress={() => toggleCalm()}
      style={({ pressed }) => [
        styles.calm,
        { backgroundColor: calm ? c.accent : c.surface, borderColor: calm ? c.accent : c.border, opacity: pressed ? 0.8 : 1 },
      ]}
    >
      <Icon name="leaf" size={20} color={calm ? c.onAccent : c.accentInk} />
      <T variant="small" color={calm ? c.onAccent : c.ink} style={{ fontFamily: 'AtkinsonHyperlegible_700Bold' }}>
        {calm ? 'Calm on' : 'Calm'}
      </T>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  calm: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    paddingHorizontal: space.md + 2,
    minHeight: 44,
  },
  note: { borderRadius: radius.md, borderWidth: 1, padding: space.md, marginTop: space.md },
});
