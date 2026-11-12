import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useEffect, useRef, useState } from 'react';
import { AccessibilityInfo, Pressable, StyleSheet, View } from 'react-native';
import Animated, { FadeIn, FadeOut } from 'react-native-reanimated';
import { Glyph } from '../../components/art/Glyph';
import { MoodFace } from '../../components/art/MoodFace';
import { Icon } from '../../components/Icon';
import { PetCard } from '../../components/PetCard';
import { ANCHOR_LABEL, QuestListItem, SponsorCard } from '../../components/QuestBits';
import { Button, Card, Pill, Row, Screen, SectionTitle, T } from '../../components/ui';
import * as repo from '../../db/repo';
import { tapFeedback } from '../../lib/feedback';
import { COMPANION_AVAILABLE, COMPANION_COMING_SOON } from '../../lib/ai/companion';
import { MOODS, allClearLine, idleLine, spoonSavingLines } from '../../lib/copy';
import { currentAnchor, dayKey, greeting, minutesNow } from '../../lib/time';
import type { Anchor, Energy, QuestWithProgress, StepWithState } from '../../lib/types';
import { useAssistant } from '../../lib/useAssistant';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space } from '../../theme/tokens';

/** Tried in order when the day is shrunk: the first one with a step left is shown. */
const SHRINK_QUESTS = ['water-break', 'hard-day-kit', 'sensory-reset'];

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
  const [checkedIn, setCheckedIn] = useState<boolean | null>(null);
  const [raceMinutesLeft, setRaceMinutesLeft] = useState<number | null>(null);
  const [mood, setMood] = useState<number | null>(null);
  const [skip, setSkip] = useState(0);
  const [showAll, setShowAll] = useState(false);
  const now = minutesNow();
  const today = dayKey();
  const shrunk = settings.shrinkDay === today;

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      (async () => {
        if (shrunk) {
          // "Shrink my day": a single tiny self-care quest, even if it isn't in the routine.
          for (const id of SHRINK_QUESTS) {
            const q = await repo.getQuest(db, id, today);
            if (q && !q.completedToday && q.steps.some((s) => !s.done)) return q;
          }
          return null;
        }
        return null;
      })().then(async (single) => {
        const list = shrunk ? (single ? [single] : []) : await repo.getTodayQuests(db, today);
        if (alive) setQuests(list);
      });
      repo.getCheckins(db, today, today).then((rows) => {
        if (alive) setCheckedIn(rows.length > 0);
      });
      repo.getOpenRace(db).then((r) => {
        if (alive) setRaceMinutesLeft(r ? Math.max(0, Math.ceil((r.started_at + r.minutes * 60_000 - Date.now()) / 60_000)) : null);
      });
      return () => {
        alive = false;
      };
      // dataVersion is a deliberate refetch trigger: it bumps whenever any quest data changes.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [db, today, dataVersion, shrunk]),
  );

  const spoonSaving = settings.energy === 'low';
  // Small lists: plain derivations are plenty fast (and the React Compiler memoizes them).
  const visible = shrunk ? quests : spoonSaving && !showAll ? quests.filter((q) => q.essential === 1) : quests;
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
      <View style={{ paddingTop: space.lg, paddingBottom: space.lg, gap: space.sm, zIndex: 10, elevation: 10 }}>
        <Row style={{ justifyContent: 'space-between', zIndex: 2, elevation: 2 }}>
          <View style={{ flex: 1 }}>
            <T variant="label">{new Date().toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' }).toUpperCase()}</T>
            <T variant="title">{greeting(now)}</T>
          </View>
          <TalkButton />
        </Row>
        <Row gap={space.sm}>
          <OverwhelmedButton />
          <CalmButton />
        </Row>
      </View>
      {shrunk ? (
        <View style={[styles.note, { backgroundColor: c.lavenderSoft, borderColor: c.border, marginTop: 0, marginBottom: space.md }]}>
          <T variant="bodyBold">Your day is shrunk to one tiny thing.</T>
          <T variant="small" color={c.ink}>
            Everything else is safely waiting for tomorrow (or whenever you’re ready).
          </T>
          <Pressable accessibilityRole="button" onPress={() => app.updateSettings({ shrinkDay: null })} hitSlop={8}>
            <T variant="small" color={c.accentInk} style={{ marginTop: 6 }}>
              Bring back my whole day
            </T>
          </Pressable>
        </View>
      ) : null}

      <PetCard line={line} sleepy={welcomeBackLine !== null} />
      {welcomeBackLine ? (
        <Button label="Hi! Let's do one tiny thing" kind="soft" small style={{ marginTop: space.md }} onPress={app.dismissWelcome} />
      ) : null}

      {raceMinutesLeft !== null ? (
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/race')}
          style={[styles.note, { backgroundColor: c.peachSoft, borderColor: c.border }]}
        >
          <Row gap={space.sm}>
            <Glyph name="flag" size={22} />
            <T variant="bodyBold">Friend race in progress</T>
          </Row>
          <T variant="small" color={c.ink}>
            {raceMinutesLeft > 0 ? `About ${raceMinutesLeft} min left. Every step you check off counts!` : 'Time’s up! Tap to see your result.'}
          </T>
        </Pressable>
      ) : null}

      {checkedIn === false && !shrunk ? (
        <Card tone="lavender" style={{ marginTop: space.lg, gap: space.md }}>
          <T variant="heading">How are you arriving today?</T>
          <Row gap={space.xs} style={{ justifyContent: 'space-between' }}>
            {MOODS.map((m) => (
              <Pressable
                key={m.value}
                accessibilityRole="radio"
                accessibilityState={{ selected: mood === m.value }}
                accessibilityLabel={m.word}
                onPress={() => setMood(m.value)}
                style={[styles.mood, { backgroundColor: mood === m.value ? c.surface : 'transparent', borderColor: mood === m.value ? c.lavender : 'transparent' }]}
              >
                <MoodFace mood={m.value} size={34} />
                <T variant="small" color={c.ink}>
                  {m.word}
                </T>
              </Pressable>
            ))}
          </Row>
          <T variant="small" color={c.ink}>
            Spoons today
          </T>
          <Row gap={space.sm}>
            <Pill label="Low" icon="spoon" selected={settings.energy === 'low'} onPress={() => setEnergy('low')} />
            <Pill label="Steady" selected={settings.energy === 'medium'} onPress={() => setEnergy('medium')} />
            <Pill label="High" selected={settings.energy === 'high'} onPress={() => setEnergy('high')} />
          </Row>
          <Button
            label="Save check-in"
            kind="lavender"
            small
            disabled={mood === null}
            onPress={() => {
              if (mood === null) return;
              app.saveCheckin(mood, settings.energy).catch(() => undefined);
              setCheckedIn(true);
            }}
          />
          <Pressable accessibilityRole="button" onPress={() => setCheckedIn(true)} hitSlop={8}>
            <T variant="small" color={c.accentInk}>
              Skip today (totally fine)
            </T>
          </Pressable>
        </Card>
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
                <Glyph name={next.quest.emoji} size={24} />
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
                This one is already a single tiny action.
              </T>
            ) : null}
          </Card>
        </Animated.View>
      ) : (
        <Card tone="accent">
          <T variant="heading">{visible.length === 0 ? 'Nothing on the list yet' : 'All clear for now'}</T>
          <T variant="small" style={{ marginTop: 4 }}>
            {visible.length === 0 ? 'Want to pick a quest or two from the library? No pressure.' : allClearLine}
          </T>
          {visible.length === 0 ? (
            <Button label="Browse quests" kind="soft" small style={{ marginTop: space.md }} onPress={() => router.push('/quests')} />
          ) : null}
        </Card>
      )}

      {shrunk ? null : (
        <>
      <SectionTitle>Spoons today</SectionTitle>
      <Row gap={space.sm}>
        <Pill label="Low" icon="spoon" selected={settings.energy === 'low'} onPress={() => setEnergy('low')} />
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
        </>
      )}
      {shrunk ? null : (
        <Button label="Add a quest of my own" icon="plus" kind="soft" style={{ marginTop: space.xl }} onPress={() => router.push('/custom-quest')} />
      )}

      {/* Free tier only. Calm Mode also hides it: zero clutter. */}
      {!isPro && !calm && !shrunk ? <SponsorCard /> : null}
    </Screen>
  );
}

/**
 * "Talk with Dumpling": a placeholder for a future on-device chat companion (Plus).
 * For now it shows a soft "coming soon" toast. See src/lib/ai/companion.ts.
 */
function TalkButton() {
  const { c, motionLevel } = useTheme();
  const { pet, feedbackPrefs } = useApp();
  const [toast, setToast] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => () => {
    if (timer.current) clearTimeout(timer.current);
  }, []);
  const onPress = () => {
    tapFeedback(feedbackPrefs);
    if (COMPANION_AVAILABLE) return;
    setToast(true);
    AccessibilityInfo.announceForAccessibility(COMPANION_COMING_SOON);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setToast(false), 2800);
  };
  const fade = motionLevel !== 'still';
  return (
    <View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Talk with ${pet.name}`}
        accessibilityHint="Coming soon in MochiNook Plus"
        onPress={onPress}
        hitSlop={6}
        style={({ pressed }) => [styles.talk, { backgroundColor: c.lavenderSoft, borderColor: c.lavender, opacity: pressed ? 0.8 : 1 }]}
      >
        <Glyph name="chat" size={26} />
      </Pressable>
      {toast ? (
        <Animated.View
          entering={fade ? FadeIn.duration(180) : undefined}
          exiting={fade ? FadeOut.duration(220) : undefined}
          pointerEvents="none"
          style={[styles.toast, { backgroundColor: c.ink, shadowColor: c.shadow }]}
        >
          <T variant="small" color={c.bg} style={{ fontFamily: 'AtkinsonHyperlegible_700Bold' }}>
            Coming soon in MochiNook Plus
          </T>
          <T variant="small" color={c.bg}>
            Chatting with {pet.name}, right on your phone.
          </T>
        </Animated.View>
      ) : null}
    </View>
  );
}

function OverwhelmedButton() {
  const { c } = useTheme();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Overwhelmed?"
      accessibilityHint="Opens a calm breathing space and lets you shrink today to one tiny step"
      onPress={() => router.push('/overwhelmed')}
      style={({ pressed }) => [styles.calm, { backgroundColor: c.lavenderSoft, borderColor: c.lavender, opacity: pressed ? 0.8 : 1 }]}
    >
      <Glyph name="bubbles" size={22} />
      <T variant="small" color={c.ink} style={{ fontFamily: 'AtkinsonHyperlegible_700Bold' }}>
        Overwhelmed?
      </T>
    </Pressable>
  );
}

function CalmButton() {
  const { c, calm } = useTheme();
  const { toggleCalm } = useApp();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={calm ? 'Calm Mode is on' : 'Dopamine Mode is on'}
      accessibilityHint="Switches between Calm (gentle and quiet) and Dopamine (bouncy, sparkly, with chimes)"
      onPress={() => toggleCalm()}
      style={({ pressed }) => [
        styles.calm,
        { backgroundColor: calm ? c.accent : c.surface, borderColor: calm ? c.accent : c.border, opacity: pressed ? 0.8 : 1 },
      ]}
    >
      {calm ? <Icon name="leaf" size={20} color={c.onAccent} /> : <Glyph name="sparkle" size={22} />}
      <T variant="small" color={calm ? c.onAccent : c.ink} style={{ fontFamily: 'AtkinsonHyperlegible_700Bold' }}>
        {calm ? 'Calm' : 'Dopamine'}
      </T>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  talk: { width: 52, height: 52, borderRadius: 26, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center' },
  toast: {
    position: 'absolute',
    top: 60,
    right: 0,
    width: 264,
    zIndex: 10,
    borderRadius: radius.md,
    paddingHorizontal: space.md,
    paddingVertical: space.sm,
    shadowOpacity: 1,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: 4 },
    elevation: 6,
  },
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
  mood: { alignItems: 'center', borderRadius: radius.md, borderWidth: 1.5, paddingVertical: space.sm, flex: 1, minHeight: 64 },
});
