import { router } from 'expo-router';
import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { currentAnchor, formatClock, minutesNow, wrapMinutes } from '../lib/time';
import type { Anchor, Anchors, QuestWithProgress } from '../lib/types';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { Glyph, type GlyphName } from './art/Glyph';
import { T } from './ui';

interface Props {
  anchors: Anchors;
  quests: QuestWithProgress[];
}

interface Block {
  anchor: Anchor;
  title: string;
  time: string;
  glyph: GlyphName;
}

/**
 * A calm, picture-first view of the day: one vertical line from wake-up to bed,
 * with each quest as a big emoji stop. Built for people who think visually.
 */
export function DayTimeline({ anchors, quests }: Props) {
  const { c } = useTheme();
  const part = currentAnchor(anchors, minutesNow());
  const school = anchors.blockKind !== 'none';
  const blocks: Block[] = [
    { anchor: 'morning', title: 'Morning', time: `Wake up ${formatClock(anchors.wake)}`, glyph: 'sunrise' },
    {
      anchor: 'daytime',
      title: school ? (anchors.blockKind === 'school' ? 'School & after' : 'Work & after') : 'Daytime',
      time: school ? `${formatClock(anchors.blockStart)} – ${formatClock(anchors.blockEnd)}` : `From ${formatClock(wrapMinutes(anchors.wake + 180))}`,
      glyph: school ? (anchors.blockKind === 'school' ? 'backpack' : 'briefcase') : 'sun',
    },
    { anchor: 'evening', title: 'Evening', time: `Wind down ${formatClock(anchors.bed)}`, glyph: 'moon' },
    { anchor: 'anytime', title: 'Whenever it fits', time: 'No set time', glyph: 'bubbles' },
  ];

  return (
    <View style={{ paddingLeft: space.sm }}>
      {blocks.map((b, bi) => {
        const items = quests.filter((q) => q.anchor === b.anchor);
        const isNow = b.anchor === part;
        return (
          <View key={b.anchor}>
            <View style={styles.row}>
              <View style={styles.rail}>
                <View style={[styles.bigDot, { backgroundColor: isNow ? c.accent : c.surfaceAlt, borderColor: isNow ? c.accentInk : c.border }]}>
                  <Glyph name={b.glyph} size={30} />
                </View>
                {bi < blocks.length - 1 || items.length > 0 ? <View style={[styles.line, { backgroundColor: c.border }]} /> : null}
              </View>
              <View style={{ flex: 1, paddingBottom: space.md, paddingTop: 6 }}>
                <T variant="heading">
                  {b.title}
                  {isNow ? '  · now' : ''}
                </T>
                <T variant="small">{b.time}</T>
              </View>
            </View>
            {items.map((q, i) => {
              const done = q.completedToday || (q.steps.length > 0 && q.doneCount >= q.steps.length);
              const lastInBlock = i === items.length - 1 && bi === blocks.length - 1;
              return (
                <Pressable
                  key={q.id}
                  accessibilityRole="button"
                  accessibilityLabel={`${q.title}, ${done ? 'done' : `${q.doneCount} of ${q.steps.length} steps`}`}
                  onPress={() => router.push({ pathname: '/quest/[id]', params: { id: q.id } })}
                  style={({ pressed }) => [styles.row, { opacity: pressed ? 0.8 : 1 }]}
                >
                  <View style={styles.rail}>
                    <View style={[styles.stop, { backgroundColor: done ? c.accent : c.surface, borderColor: done ? c.accent : c.border }]}>
                      <Glyph name={done ? 'check' : q.emoji} size={28} />
                    </View>
                    {!lastInBlock ? <View style={[styles.line, { backgroundColor: c.border }]} /> : null}
                  </View>
                  <View style={[styles.card, { backgroundColor: done ? c.accentSoft : c.surface, borderColor: c.border }]}>
                    <T variant="bodyBold" style={done ? { color: c.inkSoft } : undefined}>
                      {q.title}
                    </T>
                    <T variant="small">{done ? 'Done today' : `${q.doneCount} of ${q.steps.length} tiny steps`}</T>
                  </View>
                </Pressable>
              );
            })}
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: space.md },
  rail: { width: 52, alignItems: 'center' },
  bigDot: { width: 48, height: 48, borderRadius: 24, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  stop: { width: 44, height: 44, borderRadius: 22, borderWidth: 1.5, alignItems: 'center', justifyContent: 'center' },
  line: { width: 3, flex: 1, minHeight: 14, borderRadius: 2, marginVertical: 2 },
  card: { flex: 1, borderWidth: 1, borderRadius: radius.md, padding: space.md, marginBottom: space.sm },
});
