import { router } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useEffect, useRef, useState } from 'react';
import Animated, { Easing, cancelAnimation, useAnimatedStyle, useSharedValue, withRepeat, withTiming } from 'react-native-reanimated';
import { StyleSheet, View } from 'react-native';
import Svg, { Circle, Line, Path, Rect } from 'react-native-svg';
import { Pet } from '../components/Pet';
import { Room } from '../components/Room';
import { Button, IconButton, Pill, Row, Screen, Segmented, T } from '../components/ui';
import * as repo from '../db/repo';
import { playAmbient, stopAmbient } from '../lib/ambient';
import { cancelNotification, scheduleTimerEnd } from '../lib/notifications';
import { dayKey } from '../lib/time';
import { useApp } from '../state/AppContext';
import type { MotionLevel } from '../theme/motion';
import { useTheme } from '../theme/ThemeContext';
import { radius, space } from '../theme/tokens';

const LENGTHS = [5, 15, 25] as const;

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
  const { c, motionLevel, calm, scheme } = useTheme();
  const { pet, owned, completeFocus, settings, updateSettings } = useApp();

  // Background sound plays only while this screen is open.
  useEffect(() => {
    if (settings.focusSound !== 'off') playAmbient(settings.focusSound).catch(() => undefined);
    return () => stopAmbient();
    // Start once on open with the saved choice; later changes are handled by the switch.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const [minutes, setMinutes] = useState<(typeof LENGTHS)[number]>(15);
  const [session, setSession] = useState<Session | null>(null);
  const [now, setNow] = useState(() => Date.now());
  const [done, setDone] = useState<'finished' | 'early' | null>(null);
  const [finishedAt, setFinishedAt] = useState(0);
  const finishing = useRef(false);
  const decor = owned.filter((o) => o.placed === 1).map((o) => o.item_id);

  const finish = async (s: Session, completed: boolean) => {
    if (finishing.current) return;
    finishing.current = true;
    if (!completed) await cancelNotification(s.notificationId);
    await completeFocus(s.id, completed);
    setSession(null);
    setDone(completed ? 'finished' : 'early');
    setFinishedAt(Date.now());
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
          <Pet
            color={pet.color}
            hat={pet.hat}
            scarf={pet.scarf}
            mood={done === 'finished' ? 'proud' : 'idle'}
            size={140}
            level={motionLevel}
            focus={!!session}
            reaction={done === 'finished' && finishedAt ? { id: finishedAt, type: 'bigHop' } : null}
          />
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
        <GlowRing active={!!session} level={motionLevel} color={c.lavender} />
        <MeltingPie fraction={1 - Math.max(0, Math.min(1, progress))} color={c.lavender} track={c.surfaceAlt} ink={c.inkSoft} />
        <View style={[styles.timeChip, { backgroundColor: c.surface, borderColor: c.border }]}>
          <T variant="heading" accessibilityLiveRegion="polite" accessibilityLabel={`${Math.ceil(remaining / 60000)} minutes left`}>
            {mmss(remaining)}
          </T>
        </View>
      </View>

      <View style={{ marginTop: space.xxl, gap: space.sm }}>
        <T variant="small" style={{ textAlign: 'center' }}>
          Background sound
        </T>
        <Segmented
          options={[
            { value: 'off', label: 'Quiet' },
            { value: 'brown', label: 'Brown noise' },
            { value: 'rain', label: 'Soft rain' },
          ]}
          value={settings.focusSound}
          onChange={(v) => {
            updateSettings({ focusSound: v }).catch(() => undefined);
            if (v === 'off') stopAmbient();
            else playAmbient(v).catch(() => undefined);
          }}
        />
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

/**
 * Time-blindness friendly countdown: a pie that melts away clockwise, so how much
 * time is left can be seen at a glance (like a visual kitchen timer).
 */
function MeltingPie({ fraction, color, track, ink }: { fraction: number; color: string; track: string; ink: string }) {
  const cx = 80;
  const cy = 80;
  const r = 66;
  const f = Math.max(0, Math.min(1, fraction));
  let wedge: React.ReactNode = null;
  if (f >= 0.999) {
    wedge = <Circle cx={cx} cy={cy} r={r} fill={color} />;
  } else if (f > 0.001) {
    // The wedge spans the time LEFT, starting at 12 o'clock and shrinking toward it.
    const angle = f * 2 * Math.PI;
    const x = cx + r * Math.sin(angle);
    const y = cy - r * Math.cos(angle);
    wedge = <Path d={`M${cx} ${cy} L${cx} ${cy - r} A${r} ${r} 0 ${f > 0.5 ? 1 : 0} 1 ${x} ${y} Z`} fill={color} />;
  }
  return (
    <Svg width={160} height={160} viewBox="0 0 160 160">
      <Circle cx={cx} cy={cy} r={r + 6} fill={track} />
      {wedge}
      {Array.from({ length: 12 }, (_, i) => {
        const a = (i / 12) * 2 * Math.PI;
        return (
          <Line
            key={i}
            x1={cx + (r + 1) * Math.sin(a)}
            y1={cy - (r + 1) * Math.cos(a)}
            x2={cx + (r + 5) * Math.sin(a)}
            y2={cy - (r + 5) * Math.cos(a)}
            stroke={ink}
            strokeWidth={i % 3 === 0 ? 2.4 : 1.2}
            strokeLinecap="round"
          />
        );
      })}
      <Circle cx={cx} cy={cy} r={4} fill={ink} />
    </Svg>
  );
}

/** A soft halo that breathes in and out behind the timer while you focus (4s cycle; still when motion is off). */
function GlowRing({ active, level, color }: { active: boolean; level: MotionLevel; color: string }) {
  const v = useSharedValue(0);
  useEffect(() => {
    if (!active || level === 'still') {
      cancelAnimation(v);
      v.value = active ? 0.5 : 0;
      return;
    }
    v.value = withRepeat(withTiming(1, { duration: level === 'calm' ? 3000 : 2000, easing: Easing.inOut(Easing.sin) }), -1, true);
    return () => cancelAnimation(v);
  }, [active, level, v]);
  const style = useAnimatedStyle(() => ({
    opacity: active ? 0.18 + 0.3 * v.value : 0,
    transform: [{ scale: 1 + 0.07 * v.value }],
  }));
  return <Animated.View pointerEvents="none" style={[styles.glow, { borderColor: color }, style]} />;
}

const styles = StyleSheet.create({
  timeChip: { position: 'absolute', bottom: -18, borderRadius: radius.pill, borderWidth: 1, paddingHorizontal: space.md, paddingVertical: 2 },
  glow: { position: 'absolute', top: -12, width: 184, height: 184, borderRadius: 92, borderWidth: 10 },
  stage: { height: 230, borderRadius: radius.xl, borderWidth: 1, overflow: 'hidden', justifyContent: 'flex-end', marginTop: space.lg },
});
