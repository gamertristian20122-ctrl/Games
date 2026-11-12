import * as Clipboard from 'expo-clipboard';
import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useState } from 'react';
import { Alert, Share, TextInput, View } from 'react-native';
import { Button, Card, IconButton, Pill, Row, Screen, SectionTitle, T, ToggleRow } from '../components/ui';
import * as repo from '../db/repo';
import { LIBRARY } from '../db/schema';
import { decodeShareCode, encodeShareCode } from '../lib/shareCode';
import type { SharePayload } from '../lib/types';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space, type as typeScale } from '../theme/tokens';

export default function ShareScreen() {
  const db = useSQLiteContext();
  const { c } = useTheme();
  const app = useApp();
  const [mode, setMode] = useState<'send' | 'receive'>('send');
  const [includeTimes, setIncludeTimes] = useState(true);
  const [code, setCode] = useState('');
  const [input, setInput] = useState('');
  const [preview, setPreview] = useState<SharePayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [useTimes, setUseTimes] = useState(true);

  const build = useCallback(async () => {
    const quests = await repo.exportRoutine(db);
    setCode(encodeShareCode({ v: 1, quests, ...(includeTimes ? { anchors: app.settings.anchors } : {}) }));
  }, [db, includeTimes, app.settings.anchors]);

  useFocusEffect(
    useCallback(() => {
      build().catch(() => undefined);
      // app.dataVersion is a deliberate refetch trigger.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [build, app.dataVersion]),
  );

  const copy = async () => {
    await Clipboard.setStringAsync(code);
    Alert.alert('Copied', 'Paste it in a message to whoever you want to share with.');
  };

  const shareCode = () => {
    Share.share({ message: `Here's my MochiNook routine. Open MochiNook → Settings → Caregiver share code → Receive, and paste:\n\n${code}` }).catch(() => undefined);
  };

  const pasteFromClipboard = async () => {
    const text = await Clipboard.getStringAsync();
    const match = text.match(/MN1-[A-Za-z0-9_-]+/);
    setInput(match ? match[0] : text);
    setPreview(null);
    setError(null);
  };

  const check = () => {
    try {
      setPreview(decodeShareCode(input));
      setError(null);
    } catch (e) {
      setPreview(null);
      setError(e instanceof Error ? e.message : 'That code did not work.');
    }
  };

  const apply = async () => {
    if (!preview) return;
    const added = await repo.importShared(db, preview);
    if (useTimes && preview.anchors) await app.updateSettings({ anchors: preview.anchors });
    app.touchData();
    Alert.alert('Routine added 🌱', added > 0 ? `${added} ${added === 1 ? 'quest was' : 'quests were'} added to your routine.` : 'You already had all of these. Nothing changed.', [
      { text: 'Lovely', onPress: () => router.back() },
    ]);
  };

  const titleFor = (q: SharePayload['quests'][number]) =>
    q.id ? (LIBRARY.find((l) => l.id === q.id)?.title ?? 'A quest from a newer version') : (q.title ?? 'Custom quest');

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
      </Row>
      <T variant="title" style={{ marginTop: space.md }}>
        Caregiver share code
      </T>
      <T variant="small">
        A parent, partner, or friend can set up a routine on their phone and send it as a code. No accounts, no cloud: the code itself carries the routine.
      </T>
      <Row gap={space.sm} style={{ marginTop: space.lg }}>
        <Pill label="Send my routine" selected={mode === 'send'} onPress={() => setMode('send')} />
        <Pill label="Receive a routine" selected={mode === 'receive'} onPress={() => setMode('receive')} />
      </Row>

      {mode === 'send' ? (
        <>
          <Card style={{ marginTop: space.lg }}>
            <ToggleRow label="Include my daily times" hint="Wake, school/work, and wind-down." value={includeTimes} onChange={setIncludeTimes} />
          </Card>
          <SectionTitle>Your code</SectionTitle>
          <View style={{ backgroundColor: c.surfaceAlt, borderRadius: radius.md, padding: space.md }}>
            <T variant="small" color={c.ink} selectable style={{ fontFamily: typeScale.body.fontFamily }}>
              {code}
            </T>
          </View>
          <Row gap={space.sm} style={{ marginTop: space.md }}>
            <Button label="Copy" icon="check" kind="soft" small style={{ flex: 1 }} onPress={copy} />
            <Button label="Share" icon="share" small style={{ flex: 1 }} onPress={shareCode} />
          </Row>
        </>
      ) : (
        <>
          <SectionTitle>Paste a code</SectionTitle>
          <TextInput
            value={input}
            onChangeText={(t) => {
              setInput(t);
              setPreview(null);
              setError(null);
            }}
            placeholder="MN1-..."
            placeholderTextColor={c.inkSoft}
            autoCapitalize="none"
            autoCorrect={false}
            multiline
            accessibilityLabel="Share code"
            style={[typeScale.small, { color: c.ink, backgroundColor: c.surface, borderColor: c.border, borderWidth: 1, borderRadius: radius.md, padding: space.md, minHeight: 90, textAlignVertical: 'top' }]}
          />
          <Row gap={space.sm} style={{ marginTop: space.md }}>
            <Button label="Paste" kind="soft" small style={{ flex: 1 }} onPress={pasteFromClipboard} />
            <Button label="Check code" small style={{ flex: 1 }} disabled={input.trim().length < 6} onPress={check} />
          </Row>
          {error ? (
            <Card tone="peach" style={{ marginTop: space.md }}>
              <T variant="small" color={c.ink}>
                {error}
              </T>
            </Card>
          ) : null}
          {preview ? (
            <Card tone="accent" style={{ marginTop: space.lg, gap: space.sm }}>
              <T variant="heading">This code holds {preview.quests.length} quests</T>
              {preview.quests.slice(0, 12).map((q, i) => (
                <T key={i} variant="small" color={c.ink}>
                  • {titleFor(q)}
                </T>
              ))}
              {preview.quests.length > 12 ? <T variant="small">…and {preview.quests.length - 12} more</T> : null}
              {preview.anchors ? <ToggleRow label="Use their daily times too" value={useTimes} onChange={setUseTimes} /> : null}
              <Button label="Add to my routine" icon="plus" onPress={apply} />
              <T variant="small">Nothing gets removed. New quests are added next to yours.</T>
            </Card>
          ) : null}
        </>
      )}
    </Screen>
  );
}
