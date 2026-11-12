import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useState } from 'react';
import { ActionSheetIOS, Alert, Platform, Text, View } from 'react-native';
import { ANCHOR_LABEL, CADENCE_LABEL, StepDots, StepItem } from '../../components/QuestBits';
import { Button, Card, IconButton, Row, Screen, Spacer, T } from '../../components/ui';
import * as repo from '../../db/repo';
import { dayKey } from '../../lib/time';
import type { QuestWithProgress, StepWithState } from '../../lib/types';
import { useAssistant } from '../../lib/useAssistant';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { space } from '../../theme/tokens';

export default function QuestScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const db = useSQLiteContext();
  const { c } = useTheme();
  const app = useApp();
  const assistant = useAssistant();
  const [quest, setQuest] = useState<QuestWithProgress | null | undefined>(undefined);

  const load = useCallback(async () => {
    if (typeof id !== 'string') {
      setQuest(null);
      return;
    }
    setQuest(await repo.getQuest(db, id, dayKey()));
  }, [db, id]);

  useFocusEffect(
    useCallback(() => {
      load().catch(() => setQuest(null));
      // app.dataVersion is a deliberate refetch trigger.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [load, app.dataVersion]),
  );

  if (quest === undefined) return <Screen>{null}</Screen>;
  if (quest === null) {
    return (
      <Screen>
        <Spacer size={space.xxl} />
        <T variant="title">This quest wandered off</T>
        <T variant="small">It may have been removed. That’s okay.</T>
        <Button label="Back" kind="soft" style={{ marginTop: space.lg }} onPress={() => router.back()} />
      </Screen>
    );
  }

  const total = quest.steps.length;
  const finished = quest.completedToday || (total > 0 && quest.doneCount >= total);
  const splittable = quest.steps.find((s) => !s.done && assistant.canMakeSmaller(s.text, s.tiny));

  const toggle = async (step: StepWithState) => {
    if (step.done) await app.uncheckStep(quest, step);
    else await app.checkStep(quest, step);
  };

  const smaller = async (step: StepWithState) => {
    const parts = assistant.smaller(step.text, step.tiny);
    if (!parts) return;
    await repo.replaceStepWithSmaller(db, step, parts);
    app.touchData();
  };

  const removeStep = (step: StepWithState) => {
    if (total <= 1) return;
    repo.deleteStep(db, step.id).then(app.touchData).catch(() => undefined);
  };

  const stepMenu = (step: StepWithState) => {
    const canSplit = !step.done && assistant.canMakeSmaller(step.text, step.tiny);
    const buttons: { text: string; style?: 'cancel' | 'destructive'; onPress?: () => void }[] = [];
    if (canSplit) buttons.push({ text: 'Break into smaller steps', onPress: () => smaller(step).catch(() => undefined) });
    if (total > 1) buttons.push({ text: 'Remove this step', style: 'destructive', onPress: () => removeStep(step) });
    buttons.push({ text: 'Never mind', style: 'cancel' });
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        {
          options: buttons.map((b) => b.text),
          destructiveButtonIndex: buttons.findIndex((b) => b.style === 'destructive'),
          cancelButtonIndex: buttons.length - 1,
          title: step.text,
        },
        (i) => buttons[i]?.onPress?.(),
      );
    } else {
      Alert.alert(step.text, canSplit ? undefined : 'This step is already a single tiny action.', buttons);
    }
  };

  const toggleRoutine = async () => {
    if (quest.inRoutine) await repo.removeFromRoutine(db, quest.id);
    else await repo.addToRoutine(db, quest.id);
    app.touchData();
  };

  const deleteCustom = () => {
    Alert.alert('Delete this quest?', 'It will be gone from your phone. Your pet keeps every point it earned.', [
      { text: 'Keep it', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await repo.deleteQuest(db, quest.id);
          app.touchData();
          router.back();
        },
      },
    ]);
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md, justifyContent: 'space-between' }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
        <T variant="label">
          {ANCHOR_LABEL[quest.anchor].toUpperCase()} · {CADENCE_LABEL[quest.cadence].toUpperCase()}
        </T>
      </Row>

      <View style={{ alignItems: 'flex-start', gap: space.sm, marginTop: space.lg }}>
        <Text style={{ fontSize: 44 }} accessibilityElementsHidden>
          {quest.emoji}
        </Text>
        <T variant="title" accessibilityRole="header">
          {quest.title}
        </T>
        <T color={c.inkSoft}>{quest.invite}</T>
        <StepDots total={total} done={quest.doneCount} />
      </View>

      {finished ? (
        <Card tone="accent" style={{ marginTop: space.lg }}>
          <T variant="heading">All done today 🌱</T>
          <T variant="small">You finished every step. That’s a whole quest! Rest is part of the routine too.</T>
        </Card>
      ) : null}

      <View style={{ gap: space.sm, marginTop: space.xl }}>
        {quest.steps.map((s) => (
          <StepItem
            key={s.id}
            step={s}
            onToggle={() => toggle(s)}
            onSmaller={assistant.canMakeSmaller(s.text, s.tiny) ? () => smaller(s) : undefined}
            onLongPress={() => stepMenu(s)}
            disabled={finished && quest.cadence !== 'daily'}
          />
        ))}
      </View>
      <T variant="small" style={{ marginTop: space.sm }}>
        Tip: press and hold a step for more options.
      </T>

      {splittable ? (
        <Button
          label="Break into smaller steps"
          icon="scissors"
          kind="lavender"
          style={{ marginTop: space.xl }}
          onPress={() => smaller(splittable)}
          accessibilityHint={`Splits "${splittable.text}" into tinier pieces`}
        />
      ) : null}
      <Button
        label={quest.inRoutine ? 'Remove from my routine' : 'Add to my routine'}
        icon={quest.inRoutine ? 'minus' : 'plus'}
        kind="soft"
        style={{ marginTop: space.md }}
        onPress={toggleRoutine}
      />
      {quest.source !== 'library' ? (
        <Button label="Delete this quest" icon="trash" kind="ghost" style={{ marginTop: space.sm }} onPress={deleteCustom} />
      ) : null}
    </Screen>
  );
}
