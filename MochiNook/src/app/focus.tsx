import { router } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useEffect, useRef, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Circle, Rect } from 'react-native-svg';
import { Pet } from '../components/Pet';
import { Room } from '../components/Room';
import { Button, IconButton, Pill, Row, Screen, T } from '../components/ui';
import * as repo from '../db/repo';
import { cancelNotification, scheduleTimerEnd } from '../lib/notifications';
import { dayKey } from '../lib/time';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';

const LENGTHS = [5, 15, 25] as const;
const RING = 2 * Math.PI * 54;

interface Session {
  id: number;
  startedAt: number;
  minutes: number;
  notificationId: string | null;
}

function mmss(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/** Body doubling: the pet "works" beside you, which makes starting and staying easier for many ADHD brains. */
export default function Focus() {
  const db = useSQLiteContext();
  const { c, motion, calm, scheme } = useTheme();
  const { pet, owned, completeFocus } = useApp();
  const [minutes, setMinutes] = useState<(typeof LENGTHS)[number]>(15);
  const [session, setSession] = useState<Session | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const [done, setDone] = useState<'finished' | 'early' | null>(null);
  const finishing = useRef(false);
  const decor = owned.filter((o) => o.placed === 1).map((o) => o.item_id);

  const finish = async (s: Session, completed: boolean) => {
    if (finishing.current) return;
    finishing.current = true;
    if (!completed) await cancelNotification(s.notificationId);
    await completeFocus(s.id, completed);
    setSession(null);
    setDone(completed ? 'finished' : 'early');
    finishing.current = false;
  };

  useEffect(() => {
    if (!session) return;
    const timer = setInterval(() => {
      const t = Date.now();
      setNow(t);
      if (t >= session.startedAt + session.minutes * 60_000) {
        clearInterval(timer);
        finish(session, true).catch(() => undefined);
      }
    }, 1000);
    return () => clearInterval(timer);
    // finish is stable enough for this timer; re-running on every render would reset the interval.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session]);

  const start = async () => {
    const id = await repo.startFocus(db, minutes, dayKey());
    const notificationId = await scheduleTimerEnd(minutes, `${pet.name} says: time’s up! 📚`, 'Your focus sprint is done. Want to stretch and drink some water?').catch(() => null);
    setDone(null);
    setNow(Date.now());
    setSession({ id, startedAt: Date.now(), minutes, notificationId });
  };

  const remaining = session ? session.startedAt + session.minutes * 60_000 - now : minutes * 60_000;
  const progress = session ? 1 - remaining / (session.minutes * 60_000) : 0;

  return (
    <Screen edges={['top', 'bottom']}>
      <Row style={{ paddingTop: space.md, justifyContent: 'space-between' }}>
        <IconButton icon="chevronLeft" label="Back" onPress={() => router.back()} />
        <T variant="label">BODY-DOUBLE FOCUS</T>
        <View style={{ width: 44 }} />
      </Row>

      <View style={[styles.stage, { borderColor: c.border }]}>
        <Room room={pet.room} muted={calm} dark={scheme === 'dark'} decor={decor} />
        <View style={{ alignItems: 'center' }}>
          <Pet color={pet.color} hat={pet.hat} scarf={pet.scarf} mood={done === 'finished' ? 'proud' : 'idle'} size={140} animate={motion && !session} />
          <Svg width={150} height={46} viewBox="0 0 150 46" style={{ marginTop: -26 }}>
            <Rect x={8} y={20} width={134} height={10} rx={4} fill="#C9A27C" />
            <Rect x={52} y={4} width={46} height={18} rx={3} fill="#BFD8E6" stroke="#8FAEC0" strokeWidth={2} />
            <Rect x={46} y={20} width={58} height={4} rx={2} fill="#8FAEC0" />
            <Rect x={18} y={30} width={6} height={16} fill="#B08C68" />
            <Rect x={126} y={30} width={6} height={16} fill="#B08C68" />
          </Svg>
        </View>
      </View>

      <View style={{ alignItems: 'center', marginTop: space.xl }}>
        <Svg width={140} height={140} viewBox="0 0 140 140">
          <Circle cx={70} cy={70} r={54} stroke={c.surfaceAlt} strokeWidth={12} fill="none" />
          <Circle
            cx={70}
            cy={70}
            r={54}
            stroke={c.lavender}
            strokeWidth={12}
            fill="none"
            strokeLinecap="round"
            strokeDasharray={`${RING}`}
            strokeDashoffset={RING * (1 - Math.max(0, Math.min(1, progress)))}
            transform="rotate(-90 70 70)"
          />
        </Svg>
        <View style={StyleSheet.absoluteFill} pointerEvents="none">
          <View style={{ height: 140, alignItems: 'center', justifyContent: 'center' }}>
            <T variant="title" accessibilityLiveRegion="polite">
              {mmss(remaining)}
            </T>
          </View>
        </View>
      </View>

      {session ? (
        <>
          <T style={{ textAlign: 'center', marginTop: space.lg }} color={c.inkSoft}>
            I’m working right here next to you. Just one thing at a time.
          </T>
          <Button label="Stop early (that still counts)" kind="soft" style={{ marginTop: space.xl }} onPress={() => finish(session, false)} />
        </>
      ) : (
        <>
          {done ? (
            <T variant="heading" style={{ textAlign: 'center', marginTop: space.lg }}>
              {done === 'finished' ? 'We did it! +3 pebbles and a Sprint Star.' : 'Showing up counts. +1 pebble.'}
            </T>
          ) : (
            <T style={{ textAlign: 'center', marginTop: space.lg }} color={c.inkSoft}>
              Pick a length. {pet.name} will sit with you and nudge you when time’s up.
            </T>
          )}
          <Row gap={space.sm} style={{ justifyContent: 'center', marginTop: space.lg }}>
            {LENGTHS.map((m) => (
              <Pill key={m} label={`${m} min`} selected={minutes === m} onPress={() => setMinutes(m)} />
            ))}
          </Row>
          <Button label={done ? 'Another sprint' : 'Start focusing together'} icon="clock" style={{ marginTop: space.xl }} onPress={start} />
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  stage: { height: 230, borderRadius: radius.xl, borderWidth: 1, overflow: 'hidden', justifyContent: 'flex-end', marginTop: space.lg },
});
