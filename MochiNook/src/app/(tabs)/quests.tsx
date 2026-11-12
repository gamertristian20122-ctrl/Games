import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Icon } from '../../components/Icon';
import { ANCHOR_LABEL, CADENCE_LABEL } from '../../components/QuestBits';
import { Button, Pill, Row, Screen, SectionTitle, T } from '../../components/ui';
import { DayTimeline } from '../../components/DayTimeline';
import * as repo from '../../db/repo';
import { dayKey } from '../../lib/time';
import type { QuestCategory, QuestRow, QuestWithProgress } from '../../lib/types';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space } from '../../theme/tokens';

type Item = QuestRow & { inRoutine: boolean; stepCount: number };

const CATEGORY_LABEL: Record<QuestCategory, string> = {
  morning: 'Morning resets',
  evening: 'Bedtime resets',
  kitchen: 'Kitchen & food',
  laundry: 'Laundry',
  home: 'Home & tidying',
  body: 'Body & senses',
  care: 'Care & kindness',
  adulting: 'Adulting',
  social: 'People',
  school: 'School & work',
};

const CATEGORY_ORDER: QuestCategory[] = ['morning', 'evening', 'kitchen', 'laundry', 'home', 'body', 'care', 'adulting', 'social', 'school'];

export default function Quests() {
  const db = useSQLiteContext();
  const { dataVersion, touchData, settings } = useApp();
  const [tab, setTab] = useState<'day' | 'mine' | 'library'>('day');
  const [items, setItems] = useState<Item[]>([]);
  const [today, setToday] = useState<QuestWithProgress[]>([]);

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      repo.getAllQuests(db).then((rows) => {
        if (alive) setItems(rows);
      });
      repo.getTodayQuests(db, dayKey()).then((rows) => {
        if (alive) setToday(rows);
      });
      return () => {
        alive = false;
      };
      // dataVersion is a deliberate refetch trigger.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [db, dataVersion]),
  );

  const mine = useMemo(() => items.filter((i) => i.inRoutine), [items]);
  const custom = useMemo(() => items.filter((i) => i.source !== 'library' && !i.inRoutine), [items]);
  const library = useMemo(() => {
    const lib = items.filter((i) => i.source === 'library');
    return CATEGORY_ORDER.map((cat) => ({ cat, items: lib.filter((i) => i.category === cat) })).filter((g) => g.items.length > 0);
  }, [items]);

  const toggle = async (item: Item) => {
    if (item.inRoutine) await repo.removeFromRoutine(db, item.id);
    else await repo.addToRoutine(db, item.id);
    touchData();
  };

  return (
    <Screen>
      <View style={{ paddingTop: space.lg }}>
        <T variant="title">Quests</T>
        <T variant="small">Pick what belongs in your days. Add or remove anything, any time.</T>
      </View>
      <Row gap={space.sm} style={{ marginTop: space.lg }}>
        <Pill label="My day" selected={tab === 'day'} onPress={() => setTab('day')} />
        <Pill label={`Routine (${mine.length})`} selected={tab === 'mine'} onPress={() => setTab('mine')} />
        <Pill label="Library" selected={tab === 'library'} onPress={() => setTab('library')} />
      </Row>
      <Button label="Make my own quest" icon="wand" kind="lavender" style={{ marginTop: space.lg }} onPress={() => router.push('/custom-quest')} />

      {tab === 'day' ? (
        <View style={{ marginTop: space.xl }}>
          {today.length === 0 ? <T variant="small">Nothing planned today. Add a quest from the library whenever you like.</T> : null}
          <DayTimeline anchors={settings.anchors} quests={today} />
        </View>
      ) : tab === 'mine' ? (
        <>
          <SectionTitle>In my routine</SectionTitle>
          {mine.length === 0 ? <T variant="small">Nothing here yet. The library has lots of tiny-step quests to borrow.</T> : null}
          <View style={{ gap: space.sm }}>
            {mine.map((q) => (
              <QuestRowItem key={q.id} item={q} onToggle={() => toggle(q)} />
            ))}
          </View>
          {custom.length > 0 ? (
            <>
              <SectionTitle>Saved, but resting</SectionTitle>
              <View style={{ gap: space.sm }}>
                {custom.map((q) => (
                  <QuestRowItem key={q.id} item={q} onToggle={() => toggle(q)} />
                ))}
              </View>
            </>
          ) : null}
        </>
      ) : (
        library.map((g) => (
          <View key={g.cat}>
            <SectionTitle>{CATEGORY_LABEL[g.cat]}</SectionTitle>
            <View style={{ gap: space.sm }}>
              {g.items.map((q) => (
                <QuestRowItem key={q.id} item={q} onToggle={() => toggle(q)} />
              ))}
            </View>
          </View>
        ))
      )}
    </Screen>
  );
}

function QuestRowItem({ item, onToggle }: { item: Item; onToggle: () => void }) {
  const { c } = useTheme();
  const { tap } = useApp();
  return (
    <View style={[styles.row, { backgroundColor: c.surface, borderColor: c.border }]}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`${item.title}, ${item.stepCount} steps, ${CADENCE_LABEL[item.cadence]}`}
        onPress={() => {
          tap();
          router.push({ pathname: '/quest/[id]', params: { id: item.id } });
        }}
        style={({ pressed }) => ({ flex: 1, flexDirection: 'row', alignItems: 'center', gap: space.md, opacity: pressed ? 0.8 : 1 })}
      >
        <Text style={{ fontSize: 24 }}>{item.emoji}</Text>
        <View style={{ flex: 1 }}>
          <T variant="bodyBold" numberOfLines={2}>
            {item.title}
          </T>
          <T variant="small">
            {item.stepCount} tiny steps · {ANCHOR_LABEL[item.anchor]} · {CADENCE_LABEL[item.cadence]}
          </T>
        </View>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={item.inRoutine ? `Remove ${item.title} from my routine` : `Add ${item.title} to my routine`}
        onPress={() => {
          tap();
          onToggle();
        }}
        hitSlop={6}
        style={[styles.toggle, { backgroundColor: item.inRoutine ? c.accent : c.surfaceAlt }]}
      >
        <Icon name={item.inRoutine ? 'check' : 'plus'} size={20} color={item.inRoutine ? c.onAccent : c.ink} strokeWidth={2.4} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: space.md, borderWidth: 1, borderRadius: radius.md, padding: space.md, minHeight: 68 },
  toggle: { width: 44, height: 44, borderRadius: 22, alignItems: 'center', justifyContent: 'center' },
});
