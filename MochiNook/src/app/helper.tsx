import { router } from 'expo-router';
import React, { useEffect, useState } from 'react';
import { Alert, View } from 'react-native';
import { Pet } from '../components/Pet';
import { ProUpsell } from '../components/QuestBits';
import { Button, Card, IconButton, ProgressBar, Row, Screen, T } from '../components/ui';
import {
  MODEL_LABEL,
  cancelDownload,
  connectionKind,
  deleteModelFiles,
  deviceRamBytes,
  downloadModel,
  getDownloadState,
  hasEnoughRam,
  markReady,
  modelFilesPresent,
  parseStoredPaths,
  subscribeDownload,
  type DownloadState,
} from '../lib/llm';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { space } from '../theme/tokens';

function gb(bytes: number | null): string {
  return bytes === null ? 'unknown' : `${(bytes / 1024 ** 3).toFixed(1)} GB`;
}

export default function Helper() {
  const { c, motion } = useTheme();
  const { isPro, settings, updateSettings } = useApp();
  const [dl, setDl] = useState<DownloadState>(getDownloadState());
  const [checked, setChecked] = useState(false);
  const capable = hasEnoughRam();
  const local = parseStoredPaths(settings.llmPaths);

  useEffect(() => subscribeDownload(setDl), []);

  // Make sure a "ready" model still exists on disk (the OS can clear app storage).
  useEffect(() => {
    let alive = true;
    modelFilesPresent(local).then((ok) => {
      if (!alive) return;
      if (ok) markReady();
      else if (settings.llmPaths) updateSettings({ llmPaths: null }).catch(() => undefined);
      setChecked(true);
    });
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settings.llmPaths]);

  const start = async () => {
    const net = await connectionKind();
    if (net === 'offline') {
      Alert.alert("You're offline", 'The helper needs internet just once to download. Want to try again when you are connected?');
      return;
    }
    const go = async () => {
      const paths = await downloadModel();
      if (paths) await updateSettings({ llmPaths: paths });
    };
    if (net !== 'wifi') {
      Alert.alert(
        'Heads up: no Wi-Fi',
        'This is a big download (a few hundred MB) and may use your mobile data. Want to wait for Wi-Fi instead?',
        [
          { text: 'Wait for Wi-Fi', style: 'cancel' },
          { text: 'Download anyway', onPress: () => go().catch(() => undefined) },
        ],
      );
      return;
    }
    await go();
  };

  const remove = () => {
    Alert.alert('Remove the helper?', 'This frees up storage. Smart Match keeps working, and you can download again any time.', [
      { text: 'Keep it', style: 'cancel' },
      {
        text: 'Remove',
        style: 'destructive',
        onPress: async () => {
          await deleteModelFiles(local);
          await updateSettings({ llmPaths: null });
        },
      },
    ]);
  };

  const ready = !!local && dl.status !== 'downloading';

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
      </Row>
      <View style={{ alignItems: 'center', marginTop: space.md }}>
        <Pet color="sky" hat="wizard" scarf="none" mood={dl.status === 'downloading' ? 'happy' : 'idle'} size={140} animate={motion} />
      </View>
      <T variant="title" style={{ marginTop: space.md }}>
        On-device helper
      </T>
      <T color={c.inkSoft}>
        A tiny AI that lives on your phone. It turns messy tasks into 4–6 literal micro-steps and rewrites to-dos in a softer voice. Nothing you type ever
        leaves your device.
      </T>

      {!isPro ? (
        <View style={{ marginTop: space.lg, gap: space.md }}>
          <ProUpsell title="Part of MochiNook Pro" body="Until then, Smart Match breaks tasks down using the 47 built-in quests. It works great offline too." />
        </View>
      ) : !capable ? (
        <Card tone="butter" style={{ marginTop: space.lg }}>
          <T variant="heading">Smart Match mode</T>
          <T variant="small" color={c.ink} style={{ marginTop: 4 }}>
            This phone has {gb(deviceRamBytes())} of memory. The helper needs about 4 GB to run smoothly, so MochiNook uses Smart Match instead, so your phone
            stays fast and cool. You still get every other Pro perk.
          </T>
        </Card>
      ) : (
        <Card style={{ marginTop: space.lg, gap: space.md }}>
          <T variant="label">MODEL · {MODEL_LABEL.toUpperCase()}</T>
          {dl.status === 'downloading' ? (
            <>
              <T variant="bodyBold">Teaching your pet new tricks...</T>
              <ProgressBar value={dl.progress} height={14} color={c.lavender} />
              <T variant="small">{Math.round(dl.progress * 100)}% · you can leave this screen, it keeps going while the app is open.</T>
              <Button label="Pause download" kind="soft" small onPress={cancelDownload} />
            </>
          ) : ready ? (
            <>
              <T variant="bodyBold">Ready ✨</T>
              <T variant="small">
                The helper wakes up only when you ask it to break down a task, then goes straight back to sleep to save battery and memory.
              </T>
              <Button label="Try it on a messy task" icon="wand" onPress={() => router.push('/custom-quest')} />
              <Button label="Remove download" kind="ghost" small onPress={remove} />
            </>
          ) : (
            <>
              {dl.status === 'error' ? (
                <T variant="small" color={c.ink}>
                  The download paused ({dl.message}). It will pick up where it left off.
                </T>
              ) : null}
              <T variant="small">Downloads once (a few hundred MB), best on Wi-Fi. Phone memory: {gb(deviceRamBytes())}.</T>
              <Button label={dl.status === 'error' ? 'Resume download' : 'Download helper'} icon="sparkle" disabled={!checked} onPress={start} />
            </>
          )}
        </Card>
      )}
    </Screen>
  );
}
