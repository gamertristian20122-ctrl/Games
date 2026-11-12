import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import sponsors from '../data/sponsors.json';
import { dayKey } from '../lib/time';
import type { QuestWithProgress, StepWithState } from '../lib/types';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { Icon } from './Icon';
import { Button, Card, IconButton, Row, T } from './ui';

export const ANCHOR_LABEL = {
  morning: 'Morning',
  daytime: 'Daytime',
  evening: 'Evening',
  anytime: 'Anytime',
} as const;

export const CADENCE_LABEL = {
  daily: 'Every day',
  weekly: 'About once a week',
  monthly: 'About once a month',
  once: 'Just once',
} as const;

/** Soft progress dots instead of a scary percentage. */
export function StepDots({ total, done }: { total: number; done: number }) {
  const { c } = useTheme();
  return (
    <Row gap={5} style={{ flexWrap: 'wrap' }}>
      {Array.from({ length: total }, (_, i) => (
        <View key={i} style={{ width: 9, height: 9, borderRadius: 5, backgroundColor: i < done ? c.accent : c.surfaceAlt, borderWidth: 1, borderColor: i < done ? c.accent : c.border }} />
      ))}
    </Row>
  );
}

export function QuestListItem({ quest }: { quest: QuestWithProgress }) {
  const { c } = useTheme();
  const { tap } = useApp();
  const total = quest.steps.length;
  const finished = quest.completedToday || (total > 0 && quest.doneCount >= total);
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${quest.title}. ${finished ? 'Done today' : `${quest.doneCount} of ${total} steps done`}`}
      onPress={() => {
        tap();
        router.push({ pathname: '/quest/[id]', params: { id: quest.id } });
      }}
      style={({ pressed }) => [
        styles.questItem,
        { backgroundColor: finished ? c.accentSoft : c.surface, borderColor: c.border, opacity: pressed ? 0.85 : 1 },
      ]}
    >
      <View style={[styles.emojiBubble, { backgroundColor: finished ? c.surface : c.surfaceAlt }]}>
        <Text style={{ fontSize: 24 }}>{quest.emoji}</Text>
      </View>
      <View style={{ flex: 1, gap: 6 }}>
        <T variant="bodyBold" numberOfLines={2}>
          {quest.title}
        </T>
        {finished ? <T variant="small" color={c.accentInk}>Done today. Lovely.</T> : <StepDots total={total} done={quest.doneCount} />}
      </View>
      {finished ? <Icon name="check" color={c.accentInk} size={22} strokeWidth={2.6} /> : <Icon name="chevronRight" color={c.inkSoft} size={20} />}
    </Pressable>
  );
}

export function StepItem({
  step,
  onToggle,
  onSmaller,
  onLongPress,
  disabled,
}: {
  step: StepWithState;
  onToggle: () => void;
  onSmaller: () => void;
  onLongPress?: () => void;
  disabled?: boolean;
}) {
  const { c } = useTheme();
  return (
    <View style={[styles.step, { backgroundColor: step.done ? c.accentSoft : c.surface, borderColor: c.border }]}>
      <Pressable
        accessibilityRole="checkbox"
        accessibilityState={{ checked: step.done, disabled: !!disabled }}
        accessibilityLabel={step.text}
        accessibilityHint={step.done ? 'Tap to uncheck' : 'Tap to check off this step'}
        onPress={onToggle}
        onLongPress={onLongPress}
        disabled={disabled}
        style={({ pressed }) => [{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: space.md, opacity: pressed ? 0.8 : 1, paddingVertical: space.md }]}
      >
        <View style={[styles.box, { borderColor: step.done ? c.accent : c.inkSoft, backgroundColor: step.done ? c.accent : 'transparent' }]}>
          {step.done ? <Icon name="check" size={18} color={c.onAccent} strokeWidth={2.8} /> : null}
        </View>
        <View style={{ flex: 1, gap: 4 }}>
          <T style={step.done ? { textDecorationLine: 'line-through', color: c.inkSoft } : undefined}>{step.text}</T>
          {step.timer_minutes ? (
            <Row gap={4}>
              <Icon name="clock" size={14} color={c.accentInk} />
              <T variant="small" color={c.accentInk}>
                I’ll nudge you in {step.timer_minutes} min
              </T>
            </Row>
          ) : null}
        </View>
      </Pressable>
      {!step.done ? <IconButton icon="scissors" label={`Break "${step.text}" into smaller steps`} onPress={onSmaller} tone="clear" size={40} /> : null}
    </View>
  );
}

export function SponsorCard() {
  const { c } = useTheme();
  const list = sponsors as { id: string; title: string; body: string; tag: string }[];
  const day = Number(dayKey().replace(/-/g, ''));
  const s = list[day % list.length]!;
  return (
    <View style={[styles.sponsor, { backgroundColor: c.lavenderSoft, borderColor: c.border }]} accessibilityLabel={`Sponsored calm pick: ${s.title}. ${s.body}`}>
      <Row style={{ justifyContent: 'space-between' }}>
        <T variant="label" color={c.inkSoft}>
          CALM SPONSOR · {s.tag.toUpperCase()}
        </T>
        <Pressable accessibilityRole="button" accessibilityLabel="Hide sponsor cards with Pro" onPress={() => router.push('/pro')} hitSlop={10}>
          <T variant="small" color={c.accentInk}>
            Hide
          </T>
        </Pressable>
      </Row>
      <T variant="bodyBold" style={{ marginTop: 6 }}>
        {s.title}
      </T>
      <T variant="small">{s.body}</T>
    </View>
  );
}

export function ProBadge() {
  const { c } = useTheme();
  return (
    <View style={{ backgroundColor: c.lavender, borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2 }}>
      <T variant="label" color={c.ink}>
        PRO
      </T>
    </View>
  );
}

export function ProUpsell({ title, body }: { title: string; body: string }) {
  return (
    <Card tone="lavender">
      <T variant="heading">{title}</T>
      <T variant="small" style={{ marginTop: 4, marginBottom: space.md }}>
        {body}
      </T>
      <Button label="See MochiNook Pro" kind="lavender" icon="sparkle" onPress={() => router.push('/pro')} small />
    </Card>
  );
}

const styles = StyleSheet.create({
  questItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: space.md,
    borderRadius: radius.md,
    borderWidth: 1,
    padding: space.md,
    minHeight: 72,
  },
  emojiBubble: { width: 48, height: 48, borderRadius: 24, alignItems: 'center', justifyContent: 'center' },
  step: { flexDirection: 'row', alignItems: 'center', borderRadius: radius.md, borderWidth: 1, paddingLeft: space.md, paddingRight: space.xs, minHeight: 64 },
  box: { width: 30, height: 30, borderRadius: 10, borderWidth: 2.2, alignItems: 'center', justifyContent: 'center' },
  sponsor: { borderRadius: radius.md, borderWidth: 1, padding: space.lg, marginTop: space.xl },
});
