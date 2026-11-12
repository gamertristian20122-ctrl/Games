import { router } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useState } from 'react';
import { Pressable, TextInput, View } from 'react-native';
import { GLYPH_NAMES, Glyph, glyphFor, type GlyphName } from '../components/art/Glyph';
import { ANCHOR_LABEL, CADENCE_LABEL, ProBadge, ProUpsell } from '../components/QuestBits';
import { Button, Card, IconButton, Pill, Row, Screen, SectionTitle, Segmented, T } from '../components/ui';
import * as repo from '../db/repo';
import { LIBRARY } from '../db/schema';
import { magicBreakdown, splitBrainDump, type BrainDumpItem } from '../lib/smartMatch';
import type { Anchor, Cadence } from '../lib/types';
import { useAssistant } from '../lib/useAssistant';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space, type as typeScale } from '../theme/tokens';

const QUICK_ICONS: GlyphName[] = ['sparkle', 'broom', 'box', 'notepad', 'bath', 'basket', 'pan', 'phone', 'mail', 'plant', 'backpack', 'books', 'calendar', 'heart', 'laptop', 'paw'];
const MODES = [
  { value: 'one', label: 'One task' },
  { value: 'dump', label: 'Brain dump' },
] as const;
const MAX_STEPS = 10;

export default function CustomQuest() {
  const db = useSQLiteContext();
  const { c } = useTheme();
  const { touchData, isPro, tap } = useApp();
  const [mode, setMode] = useState<'one' | 'dump'>('one');
  const [allIcons, setAllIcons] = useState(false);
  const [dump, setDump] = useState('');
  const [dumpItems, setDumpItems] = useState<BrainDumpItem[]>([]);
  const [addedCount, setAddedCount] = useState<number | null>(null);
  const assistant = useAssistant();
  const [task, setTask] = useState('');
  const [title, setTitle] = useState('');
  const [invite, setInvite] = useState('');
  const [emoji, setEmoji] = useState<GlyphName>('sparkle');
  const [anchor, setAnchor] = useState<Anchor>('anytime');
  const [cadence, setCadence] = useState<Cadence>('once');
  const [steps, setSteps] = useState<string[]>([]);
  const [note, setNote] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const inputStyle = [
    typeScale.body,
    { color: c.ink, backgroundColor: c.surface, borderColor: c.border, borderWidth: 1, borderRadius: radius.md, paddingHorizontal: space.md, paddingVertical: space.md, minHeight: 52 },
  ];

  /** Magic Break Down: 3–5 ultra-tiny starter steps for any task title. */
  const breakDown = async () => {
    const text = task.trim();
    if (text.length < 3) return;
    tap();
    const result = magicBreakdown(text, LIBRARY);
    setSteps(result.steps);
    setEmoji(glyphFor(result.icon));
    if (!title) setTitle(text.length > 40 ? `${text.slice(0, 38)}…` : text.charAt(0).toUpperCase() + text.slice(1));
    if (result.matchedTitle) setNote(`Borrowed tiny steps from "${result.matchedTitle}". Edit anything you like.`);
    else setNote('Here is a gentle starter plan. Edit the steps so they fit you.');
  };

  const splitDump = () => {
    tap();
    setAddedCount(null);
    setDumpItems(splitBrainDump(dump, LIBRARY));
  };

  const addAll = async () => {
    if (saving || dumpItems.length === 0) return;
    setSaving(true);
    try {
      for (const item of dumpItems) {
        await repo.createQuest(db, {
          title: item.title,
          emoji: item.icon,
          anchor: 'anytime',
          cadence: 'once',
          invite: 'Want to try this one together? One tiny step at a time.',
          steps: item.steps,
          source: 'custom',
        });
      }
      touchData();
      setAddedCount(dumpItems.length);
      setDumpItems([]);
      setDump('');
    } finally {
      setSaving(false);
    }
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

      <View style={{ marginTop: space.lg }}>
        <Segmented options={MODES} value={mode} onChange={setMode} />
      </View>

      {mode === 'dump' ? (
        <View style={{ marginTop: space.lg, gap: space.md }}>
          <Row gap={space.sm}>
            <T variant="title">Brain-Dump Splitter</T>
            <ProBadge />
          </Row>
          <T variant="small">
            Pour out everything on your mind, as messy as you like. Each thing becomes its own tiny-step quest. It all happens on your phone, offline.
          </T>
          {!isPro ? (
            <ProUpsell title="Part of MochiNook Plus" body="Try it free for 7 days. One task at a time stays free forever, with Magic Break Down." />
          ) : (
            <>
              <TextInput
                value={dump}
                onChangeText={(t) => {
                  setDump(t);
                  setAddedCount(null);
                }}
                placeholder={'laundry, call the dentist and pay rent\nugh homework\ntake a shower'}
                placeholderTextColor={c.inkSoft}
                multiline
                maxLength={1200}
                accessibilityLabel="Brain dump"
                style={[inputStyle, { minHeight: 140, textAlignVertical: 'top' }]}
              />
              <Button label="Split my brain dump" icon="scissors" disabled={dump.trim().length < 3} onPress={splitDump} />
              {addedCount !== null ? (
                <Card tone="accent">
                  <T variant="bodyBold">Added {addedCount} {addedCount === 1 ? 'quest' : 'quests'} to your routine.</T>
                  <T variant="small">They wait under Anytime on Today. Do them in any order, or not at all today.</T>
                </Card>
              ) : null}
              {dumpItems.map((item, i) => (
                <Card key={`${item.title}-${i}`} style={{ gap: space.sm }}>
                  <Row>
                    <Glyph name={item.icon} size={30} />
                    <T variant="bodyBold" style={{ flex: 1 }}>
                      {item.title}
                    </T>
                    <IconButton icon="close" label={`Remove ${item.title}`} tone="clear" size={36} onPress={() => setDumpItems((all) => all.filter((_, j) => j !== i))} />
                  </Row>
                  {item.steps.map((s, j) => (
                    <T key={j} variant="small" color={c.ink}>
                      {j + 1}. {s}
                    </T>
                  ))}
                </Card>
              ))}
              {dumpItems.length > 0 ? (
                <Button label={saving ? 'Adding…' : `Add all ${dumpItems.length} quests`} icon="plus" disabled={saving} onPress={addAll} />
              ) : null}
            </>
          )}
        </View>
      ) : (
        <>
      <T variant="title" style={{ marginTop: space.lg }}>
        What’s the task?
      </T>
      <T variant="small" style={{ marginBottom: space.md }}>
        Type it however it lives in your head. Messy is perfect.
      </T>
      <TextInput
        value={task}
        onChangeText={setTask}
        placeholder="Clean room, Do homework, Take a shower…"
        placeholderTextColor={c.inkSoft}
        multiline
        maxLength={400}
        accessibilityLabel="Messy task"
        style={[inputStyle, { minHeight: 96, textAlignVertical: 'top' }]}
      />
      <T variant="small" style={{ marginTop: space.sm }}>
        Magic Break Down turns it into 3–5 ultra-tiny starter steps, offline.
      </T>
      <Button label="Magic Break Down" icon="wand" disabled={task.trim().length < 3} style={{ marginTop: space.md }} onPress={breakDown} />

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

          <SectionTitle>Name it and pick an icon</SectionTitle>
          <TextInput value={title} onChangeText={setTitle} maxLength={80} accessibilityLabel="Quest name" placeholder="Room glow-up" placeholderTextColor={c.inkSoft} style={inputStyle} />
          <Row gap={space.sm} style={{ flexWrap: 'wrap', marginTop: space.md }}>
            {(allIcons ? GLYPH_NAMES.filter((g) => g !== 'pebble') : Array.from(new Set([emoji, ...QUICK_ICONS]))).map((g) => (
              <Pressable
                key={g}
                accessibilityRole="radio"
                accessibilityState={{ selected: emoji === g }}
                accessibilityLabel={`Icon: ${g}`}
                onPress={() => setEmoji(g)}
                style={{
                  width: 52,
                  height: 52,
                  borderRadius: 26,
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: emoji === g ? c.accentSoft : c.surface,
                  borderWidth: 2,
                  borderColor: emoji === g ? c.accent : c.border,
                }}
              >
                <Glyph name={g} size={30} />
              </Pressable>
            ))}
          </Row>
          <Button
            label={allIcons ? 'Fewer icons' : `Show all ${GLYPH_NAMES.length - 1} icons`}
            kind="ghost"
            small
            style={{ alignSelf: 'flex-start', marginTop: space.sm }}
            onPress={() => setAllIcons((v) => !v)}
          />

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
        </>
      )}
    </Screen>
  );
}
