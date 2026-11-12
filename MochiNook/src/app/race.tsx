import * as Clipboard from 'expo-clipboard';
import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useEffect, useState } from 'react';
import { Share, TextInput, View } from 'react-native';
import { Glyph } from '../components/art/Glyph';
import { Button, Card, IconButton, ProgressBar, Row, Screen, SectionTitle, T } from '../components/ui';
import * as repo from '../db/repo';
import { scheduleTimerEnd } from '../lib/notifications';
import { decodeRaceResult, encodeRaceResult, type RaceResult } from '../lib/shareCode';
import { dayKey } from '../lib/time';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space, type as typeScale } from '../theme/tokens';

const RACE_MINUTES = 15;

function mmss(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/**
 * A 15-minute "who can check off more tiny steps" race between friends.
 * Each person races on their own phone whenever it suits them, then they swap
 * result codes. No accounts, no server, no contact with strangers.
 */
export default function Race() {
  const db = useSQLiteContext();
  const { c } = useTheme();
  const { pet, completeRace, dataVersion } = useApp();
  const [open, setOpen] = useState<{ id: number; started_at: number; minutes: number } | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const [mine, setMine] = useState<RaceResult | null>(null);
  const [friendInput, setFriendInput] = useState('');
  const [friend, setFriend] = useState<RaceResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  useFocusEffect(
    useCallback(() => {
      repo.getOpenRace(db).then(setOpen).catch(() => undefined);
      // dataVersion: refresh when steps are checked elsewhere.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [db, dataVersion]),
  );

  useEffect(() => {
    if (!open) return;
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, [open]);

  const endsAt = open ? open.started_at + open.minutes * 60_000 : 0;
  const timeUp = open !== null && now >= endsAt;

  const start = async () => {
    const r = await repo.startRace(db, RACE_MINUTES, dayKey());
    await scheduleTimerEnd(RACE_MINUTES, 'Race time’s up! 🏁', `Open MochiNook to see how many tiny steps you and ${pet.name} did.`).catch(() => null);
    setMine(null);
    setNow(Date.now());
    setOpen({ id: r.id, started_at: r.startedAt, minutes: RACE_MINUTES });
  };

  const finish = async () => {
    if (!open) return;
    const steps = await completeRace(open.id);
    setMine({ v: 1, pet: pet.name, steps, minutes: open.minutes, day: dayKey() });
    setOpen(null);
  };

  const code = mine ? encodeRaceResult(mine) : '';

  const compare = () => {
    try {
      setFriend(decodeRaceResult(friendInput));
      setError(null);
    } catch (e) {
      setFriend(null);
      setError(e instanceof Error ? e.message : 'That code did not work.');
    }
  };

  const paste = async () => {
    const text = await Clipboard.getStringAsync();
    const match = text.match(/MNR1-[A-Za-z0-9_-]+/);
    setFriendInput(match ? match[0] : text);
    setFriend(null);
    setError(null);
  };

  const verdict = (a: number, b: number, friendPet: string) => {
    if (a === b) return `A tie! You and ${friendPet}’s human both did ${a}. Perfect teamwork.`;
    return a > b
      ? `You did ${a - b} more! Both of you showed up, and that's the real win.`
      : `${friendPet}’s human did ${b - a} more. You both still won a Sprint Star.`;
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
      </Row>
      <View style={{ alignItems: 'center', gap: space.sm, marginTop: space.md }}>
        <Glyph name="flag" size={64} />
        <T variant="title" style={{ textAlign: 'center' }}>
          15-minute friend race
        </T>
        <T color={c.inkSoft} style={{ textAlign: 'center' }}>
          See who can check off more tiny steps in 15 minutes. Race whenever it suits you, then swap codes with a friend you know.
        </T>
      </View>

      {open && !timeUp ? (
        <Card tone="peach" style={{ marginTop: space.xl, gap: space.md, alignItems: 'center' }}>
          <T variant="hero" accessibilityLiveRegion="polite">
            {mmss(endsAt - now)}
          </T>
          <View style={{ alignSelf: 'stretch' }}>
            <ProgressBar value={1 - (endsAt - now) / (open.minutes * 60_000)} color={c.peach} />
          </View>
          <T variant="small" color={c.ink} style={{ textAlign: 'center' }}>
            Every tiny step you check off counts. Go go go (gently)!
          </T>
          <Button label="Go check off steps" icon="check" style={{ alignSelf: 'stretch' }} onPress={() => router.navigate('/home')} />
        </Card>
      ) : null}

      {open && timeUp ? (
        <Card tone="peach" style={{ marginTop: space.xl, gap: space.md }}>
          <T variant="heading">Time’s up!</T>
          <Button label="See my result" icon="sparkle" onPress={finish} />
        </Card>
      ) : null}

      {!open && !mine ? <Button label={`Start my ${RACE_MINUTES}-minute race`} icon="clock" style={{ marginTop: space.xl }} onPress={start} /> : null}

      {mine ? (
        <>
          <Card tone="accent" style={{ marginTop: space.xl, gap: space.sm }}>
            <T variant="heading">
              You did {mine.steps} tiny {mine.steps === 1 ? 'step' : 'steps'}!
            </T>
            <T variant="small" color={c.ink}>
              Send this result code to your friend. It only contains your pet’s name and your step count.
            </T>
            <View style={{ backgroundColor: c.surface, borderRadius: radius.sm, padding: space.md }}>
              <T variant="small" color={c.ink} selectable>
                {code}
              </T>
            </View>
            <Row gap={space.sm}>
              <Button label="Copy" kind="soft" small style={{ flex: 1 }} onPress={() => Clipboard.setStringAsync(code).catch(() => undefined)} />
              <Button
                label="Share"
                icon="share"
                small
                style={{ flex: 1 }}
                onPress={() => Share.share({ message: `My MochiNook race result 🏁 Paste it in Week → Friend race:\n\n${code}` }).catch(() => undefined)}
              />
            </Row>
          </Card>
          <Button label="Race again" kind="soft" style={{ marginTop: space.md }} onPress={start} />
        </>
      ) : null}

      <SectionTitle>Compare with a friend</SectionTitle>
      <TextInput
        value={friendInput}
        onChangeText={(t) => {
          setFriendInput(t);
          setFriend(null);
          setError(null);
        }}
        placeholder="Paste their MNR1-… code"
        placeholderTextColor={c.inkSoft}
        autoCapitalize="none"
        autoCorrect={false}
        accessibilityLabel="Friend's race code"
        style={[typeScale.small, { color: c.ink, backgroundColor: c.surface, borderColor: c.border, borderWidth: 1, borderRadius: radius.md, padding: space.md, minHeight: 52 }]}
      />
      <Row gap={space.sm} style={{ marginTop: space.md }}>
        <Button label="Paste" kind="soft" small style={{ flex: 1 }} onPress={paste} />
        <Button label="Compare" small style={{ flex: 1 }} disabled={friendInput.trim().length < 6} onPress={compare} />
      </Row>
      {error ? (
        <Card tone="peach" style={{ marginTop: space.md }}>
          <T variant="small" color={c.ink}>
            {error}
          </T>
        </Card>
      ) : null}
      {friend ? (
        <Card style={{ marginTop: space.md, gap: space.sm }}>
          <Row style={{ justifyContent: 'space-around' }}>
            <View style={{ alignItems: 'center' }}>
              <T variant="label">YOU ({pet.name.toUpperCase()})</T>
              <T variant="hero">{mine?.steps ?? '–'}</T>
            </View>
            <View style={{ alignItems: 'center' }}>
              <T variant="label">{friend.pet.toUpperCase()}</T>
              <T variant="hero">{friend.steps}</T>
            </View>
          </Row>
          <T variant="small" color={c.ink} style={{ textAlign: 'center' }}>
            {mine ? verdict(mine.steps, friend.steps, friend.pet) : `${friend.pet}’s human did ${friend.steps} steps. Start your race to compare!`}
          </T>
        </Card>
      ) : null}
    </Screen>
  );
}
