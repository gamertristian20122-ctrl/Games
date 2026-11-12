import { router } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useState } from 'react';
import { TextInput, View } from 'react-native';
import { ANCHOR_LABEL, CADENCE_LABEL } from '../components/QuestBits';
import { Button, Card, IconButton, Pill, Row, Screen, SectionTitle, T } from '../components/ui';
import * as repo from '../db/repo';
import type { Anchor, Cadence } from '../lib/types';
import { useAssistant } from '../lib/useAssistant';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space, type as typeScale } from '../theme/tokens';

const EMOJIS = ['✨', '🧹', '📦', '📝', '🛁', '🧺', '🍳', '📞', '💌', '🪴', '🎒', '🧠'];
const MAX_STEPS = 10;

export default function CustomQuest() {
  const db = useSQLiteContext();
  const { c } = useTheme();
  const { touchData } = useApp();
  const assistant = useAssistant();
  const [task, setTask] = useState('');
  const [title, setTitle] = useState('');
  const [invite, setInvite] = useState('');
  const [emoji, setEmoji] = useState('✨');
  const [anchor, setAnchor] = useState<Anchor>('anytime');
  const [cadence, setCadence] = useState<Cadence>('once');
  const [steps, setSteps] = useState<string[]>([]);
  const [note, setNote] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const inputStyle = [
    typeScale.body,
    { color: c.ink, backgroundColor: c.surface, borderColor: c.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: space.md, paddingVertical: space.md, minHeight: 52 },
  ];

  const breakDown = async () => {
    const text = task.trim();
    if (text.length < 3) return;
    const result = assistant.breakDownTask(text);
    setSteps(result.steps);
    if (!title) setTitle(text.length > 40 ? `${text.slice(0, 38)}…` : text.charAt(0).toUpperCase() + text.slice(1));
    if (result.matchedTitle) setNote(`Smart Match borrowed steps from "${result.matchedTitle}". Edit anything you like.`);
    else setNote('Here is a gentle starter plan. Edit the steps so they fit you.');
  };

  const soften = async () => {
    const out = assistant.soften(title || task);
    if (out) setInvite(out);
  };

  const save = async () => {
    const clean = steps.map((s) => s.trim()).filter(Boolean);
    if (clean.length === 0 || saving) return;
    setSaving(true);
    try {
      const id = await repo.createQuest(db, {
        title: title.trim() || task.trim() || 'My quest',
        emoji,
        anchor,
        cadence,
        invite: invite.trim() || 'Want to try this one together? One tiny step at a time.',
        steps: clean,
        source: 'custom',
      });
      touchData();
      router.replace({ pathname: '/quest/[id]', params: { id } });
    } finally {
      setSaving(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md, justifyContent: 'space-between' }}>
        <IconButton icon="close" label="Close" onPress={() => router.back()} />
        <T variant="label">NEW QUEST</T>
        <View style={{ width: 44 }} />
      </Row>

      <T variant="title" style={{ marginTop: space.lg }}>
        What’s the messy task?
      </T>
      <T variant="small" style={{ marginBottom: space.md }}>
        Type it however it lives in your head. Messy is perfect.
      </T>
      <TextInput
        value={task}
        onChangeText={setTask}
        placeholder="ugh clean my whole room before the weekend"
        placeholderTextColor={c.inkSoft}
        multiline
        maxLength={400}
        accessibilityLabel="Messy task"
        style={[inputStyle, { minHeight: 96, textAlignVertical: 'top' }]}
      />
      <T variant="small" style={{ marginTop: space.sm }}>
        Smart Match will find tiny steps from the quest library.
      </T>
      <Button
        label="Break it into tiny steps"
        icon="scissors"
        disabled={task.trim().length < 3}
        style={{ marginTop: space.md }}
        onPress={breakDown}
      />

      {steps.length > 0 ? (
        <>
          {note ? (
            <Card tone="butter" style={{ marginTop: space.lg }}>
              <T variant="small" color={c.ink}>
                {note}
              </T>
            </Card>
          ) : null}

          <SectionTitle>Tiny steps</SectionTitle>
          <View style={{ gap: space.sm }}>
            {steps.map((s, i) => (
              <Row key={i} gap={space.sm}>
                <T variant="bodyBold" style={{ width: 22, textAlign: 'right' }}>
                  {i + 1}
                </T>
                <TextInput
                  value={s}
                  onChangeText={(t) => setSteps((all) => all.map((x, j) => (j === i ? t : x)))}
                  multiline
                  maxLength={200}
                  accessibilityLabel={`Step ${i + 1}`}
                  style={[inputStyle, { flex: 1 }]}
                />
                <IconButton icon="trash" label={`Remove step ${i + 1}`} tone="clear" size={40} onPress={() => setSteps((all) => all.filter((_, j) => j !== i))} />
              </Row>
            ))}
          </View>
          {steps.length < MAX_STEPS ? (
            <Button label="Add a step" icon="plus" kind="soft" small style={{ marginTop: space.md, alignSelf: 'flex-start' }} onPress={() => setSteps((all) => [...all, ''])} />
          ) : null}

          <SectionTitle>Name it</SectionTitle>
          <TextInput value={title} onChangeText={setTitle} maxLength={80} accessibilityLabel="Quest name" placeholder="Room glow-up" placeholderTextColor={c.inkSoft} style={inputStyle} />
          <Row gap={space.sm} style={{ flexWrap: 'wrap', marginTop: space.md }}>
            {EMOJIS.map((e) => (
              <Pill key={e} label={e} selected={emoji === e} onPress={() => setEmoji(e)} />
            ))}
          </Row>

          <SectionTitle>How your pet will invite you</SectionTitle>
          <TextInput
            value={invite}
            onChangeText={setInvite}
            maxLength={160}
            multiline
            accessibilityLabel="Invitation wording"
            placeholder="Want to try this one together?"
            placeholderTextColor={c.inkSoft}
            style={inputStyle}
          />
          <Button
            label="Soften the wording"
            icon="heart"
            kind="soft"
            small
            disabled={(title || task).trim().length === 0}
            style={{ marginTop: space.md, alignSelf: 'flex-start' }}
            onPress={soften}
          />

          <SectionTitle>When does it fit?</SectionTitle>
          <Row gap={space.sm} style={{ flexWrap: 'wrap' }}>
            {(Object.keys(ANCHOR_LABEL) as Anchor[]).map((a) => (
              <Pill key={a} label={ANCHOR_LABEL[a]} selected={anchor === a} onPress={() => setAnchor(a)} />
            ))}
          </Row>
          <Row gap={space.sm} style={{ flexWrap: 'wrap', marginTop: space.md }}>
            {(Object.keys(CADENCE_LABEL) as Cadence[]).map((k) => (
              <Pill key={k} label={CADENCE_LABEL[k]} selected={cadence === k} onPress={() => setCadence(k)} />
            ))}
          </Row>

          <Button
            label={saving ? 'Saving...' : 'Save to my routine'}
            icon="check"
            disabled={saving || steps.every((s) => s.trim().length === 0)}
            style={{ marginTop: space.xxl }}
            onPress={save}
          />
        </>
      ) : null}
    </Screen>
  );
}
