import { useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import * as repo from '../db/repo';
import { dayKey } from '../lib/time';
import type { QuestWithProgress, StepWithState } from '../lib/types';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';
import { Glyph } from './art/Glyph';
import { Icon } from './Icon';
import { PetSvg, type PetMood } from './Pet';
import { Row, T } from './ui';

/**
 * A live preview of the home-screen widget: the pet's current mood and today's single
 * next step, with a working check button. It mirrors exactly what the widget will show.
 */
export function WidgetPreview() {
  const db = useSQLiteContext();
  const { c } = useTheme();
  const { pet, settings, dataVersion, checkStep, petEvent } = useApp();
  const [next, setNext] = useState<{ quest: QuestWithProgress; step: StepWithState } | null>(null);
  const [allDone, setAllDone] = useState(false);

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      repo.getTodayQuests(db, dayKey()).then((qs) => {
        if (!alive) return;
        for (const q of qs) {
          const step = q.steps.find((s) => !s.done);
          if (step && !q.completedToday) {
            setNext({ quest: q, step });
            setAllDone(false);
            return;
          }
        }
        setNext(null);
        setAllDone(qs.length > 0);
      });
      return () => {
        alive = false;
      };
      // dataVersion: refresh after a step is checked anywhere.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [db, dataVersion]),
  );

  const mood: PetMood = settings.shrinkDay === dayKey() ? 'sleepy' : allDone ? 'proud' : petEvent?.kind === 'step' ? 'happy' : 'idle';
  const text = next ? next.step.text : allDone ? 'All clear. Rest counts too.' : 'Nothing planned. That’s okay.';

  return (
    <View style={{ gap: space.md }}>
      <Row gap={space.md} style={{ alignItems: 'flex-start' }}>
        {/* Small 2×2 widget */}
        <View style={[styles.small, { backgroundColor: c.surface, borderColor: c.border }]} accessible accessibilityLabel={`Small widget preview: ${text}`}>
          <PetSvg color={pet.color} hat={pet.hat} scarf={pet.scarf} mood={mood} size={70} />
          <T variant="small" color={c.ink} numberOfLines={3} style={{ textAlign: 'center', fontSize: 12, lineHeight: 15 }}>
            {text}
          </T>
        </View>
        {/* Medium 4×2 widget */}
        <View style={[styles.medium, { backgroundColor: c.surface, borderColor: c.border }]}>
          <PetSvg color={pet.color} hat={pet.hat} scarf={pet.scarf} mood={mood} size={64} />
          <View style={{ flex: 1, gap: 2 }}>
            <T variant="label" color={c.accentInk}>
              NEXT TINY STEP
            </T>
            <T variant="bodyBold" numberOfLines={2} style={{ fontSize: 14, lineHeight: 18 }}>
              {text}
            </T>
            {next ? (
              <Row gap={4}>
                <Glyph name={next.quest.emoji} size={14} />
                <T variant="small" numberOfLines={1} style={{ fontSize: 12 }}>
                  {next.quest.title}
                </T>
              </Row>
            ) : null}
          </View>
          {next ? (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={`I did it: ${next.step.text}`}
              onPress={() => checkStep(next.quest, next.step)}
              style={({ pressed }) => [styles.check, { backgroundColor: c.accent, opacity: pressed ? 0.8 : 1 }]}
            >
              <Icon name="check" size={20} color={c.onAccent} strokeWidth={2.8} />
            </Pressable>
          ) : null}
        </View>
      </Row>
      <T variant="small">
        Preview of the home-screen widget, live from your real data. Tap the check to try it. The widget itself is coming in a future update (Android doesn’t
        support lock-screen widgets on most phones).
      </T>
    </View>
  );
}

const styles = StyleSheet.create({
  small: { width: 110, height: 140, borderRadius: radius.lg, borderWidth: 1, alignItems: 'center', justifyContent: 'center', padding: space.sm, gap: 2 },
  medium: { flex: 1, height: 140, borderRadius: radius.lg, borderWidth: 1, flexDirection: 'row', alignItems: 'center', gap: space.sm, padding: space.sm },
  check: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
});
