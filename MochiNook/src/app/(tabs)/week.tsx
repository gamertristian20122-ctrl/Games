import { router, useFocusEffect } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import React, { useCallback, useState } from 'react';
import { Pressable, Share, StyleSheet, View } from 'react-native';
import { Glyph } from '../../components/art/Glyph';
import { MoodFace } from '../../components/art/MoodFace';
import { Icon } from '../../components/Icon';
import { Button, Card, ProgressBar, Row, Screen, SectionTitle, T } from '../../components/ui';
import { cosmeticKey, seasonalRewards } from '../../data/cosmetics';
import * as repo from '../../db/repo';
import { CHEERS, MOODS, cheerMessage } from '../../lib/copy';
import { SEASON_GLYPH, SEASON_INFO, seasonFor, sprintTiers, weekDays, weekStart } from '../../lib/season';
import { dayKey } from '../../lib/time';
import { useApp } from '../../state/AppContext';
import { useTheme } from '../../theme/ThemeContext';
import { radius, space } from '../../theme/tokens';

const DAY_LETTERS = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

export default function Week() {
  const db = useSQLiteContext();
  const { c } = useTheme();
  const app = useApp();
  const { settings, pet, ownedCosmetics, dataVersion, syncSprint, tap } = app;
  const today = dayKey();
  const start = weekStart(today);
  const days = weekDays(start);
  const season = seasonFor();
  const info = SEASON_INFO[season];
  const tiers = sprintTiers(settings.energy);
  const rewards = seasonalRewards(season);
  const [stats, setStats] = useState<repo.SprintStats | null>(null);
  const [checkins, setCheckins] = useState<repo.Checkin[]>([]);

  useFocusEffect(
    useCallback(() => {
      let alive = true;
      (async () => {
        await syncSprint();
        const [s, ch] = await Promise.all([repo.getSprintStats(db, start), repo.getCheckins(db, start, days[6]!)]);
        if (alive) {
          setStats(s);
          setCheckins(ch);
        }
      })().catch(() => undefined);
      return () => {
        alive = false;
      };
      // dataVersion is a deliberate refetch trigger.
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [db, start, dataVersion]),
  );

  const stars = stats?.stars ?? 0;
  const top = tiers[2];
  const nextTier = tiers.find((t) => stars < t);

  const sendCheer = (cheer: string) => {
    tap();
    Share.share({ message: cheerMessage(cheer, pet.name) }).catch(() => undefined);
  };

  return (
    <Screen>
      <View style={{ paddingTop: space.lg }}>
        <Row gap={6}>
          <Glyph name={SEASON_GLYPH[season]} size={18} />
          <T variant="label">{info.name.toUpperCase()} SEASON</T>
        </Row>
        <T variant="title">This week</T>
      </View>

      <Card tone="butter" style={{ marginTop: space.lg, gap: space.md }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <T variant="heading">Mochi Sprint</T>
          <Row gap={6}>
            <Glyph name="star" size={24} />
            <T variant="heading">{stars}</T>
          </Row>
        </Row>
        <ProgressBar value={Math.min(1, stars / top)} height={14} color={c.butter} />
        <T variant="small" color={c.ink}>
          {nextTier !== undefined
            ? `${nextTier - stars} more ${nextTier - stars === 1 ? 'star' : 'stars'} to the next reward. Goals are matched to your ${settings.energy === 'medium' ? 'steady' : settings.energy} energy.`
            : 'Every reward this week is yours! Anything more is pure bonus.'}
        </T>
        <View style={{ gap: space.sm }}>
          {rewards.map((r) => {
            const earned = ownedCosmetics.includes(cosmeticKey(r.kind, r.id));
            const goal = tiers[r.tier - 1]!;
            return (
              <Row key={r.id} style={[styles.reward, { backgroundColor: earned ? c.accentSoft : c.surface, borderColor: c.border }]}>
                <View style={[styles.tierBadge, { backgroundColor: earned ? c.accent : c.surfaceAlt }]}>
                  {earned ? <Icon name="check" size={16} color={c.onAccent} strokeWidth={2.6} /> : <T variant="label" color={c.ink}>{goal}</T>}
                </View>
                <View style={{ flex: 1 }}>
                  <T variant="bodyBold">{r.name}</T>
                  <T variant="small">{earned ? 'Earned. It’s yours forever.' : `Reach ${goal} stars · ${r.kind}`}</T>
                </View>
              </Row>
            );
          })}
        </View>
        <T variant="small" color={c.ink}>
          Stars come from finished quests, focus sprints and friend races. A new sprint starts every Monday. Missing a goal never costs you anything.
        </T>
      </Card>

      <SectionTitle>Your week</SectionTitle>
      <Card>
        <Row gap={0} style={{ justifyContent: 'space-between' }}>
          {days.map((d, i) => {
            const n = stats?.perDay[i] ?? 0;
            const mood = MOODS.find((m) => m.value === checkins.find((x) => x.day === d)?.mood);
            const isToday = d === today;
            return (
              <View
                key={d}
                style={[styles.day, isToday && { backgroundColor: c.accentSoft }]}
                accessible
                accessibilityLabel={`${d}: ${n} stars${mood ? `, felt ${mood.word}` : ''}`}
              >
                <T variant="label" color={isToday ? c.accentInk : c.inkSoft}>
                  {DAY_LETTERS[i]}
                </T>
                {mood ? <MoodFace mood={mood.value} size={26} /> : <View style={[styles.emptyFace, { borderColor: c.border }]} />}
                {n > 0 ? (
                  <Row gap={2}>
                    <Glyph name="star" size={13} />
                    <T variant="small" color={c.ink}>
                      {n}
                    </T>
                  </Row>
                ) : (
                  <T variant="small"> </T>
                )}
              </View>
            );
          })}
        </Row>
        <T variant="small" style={{ marginTop: space.md }}>
          Faces come from your daily check-in on the Today tab. Empty days are completely fine.
        </T>
      </Card>

      <SectionTitle>Do it together</SectionTitle>
      <View style={{ gap: space.md }}>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/focus')}
          style={({ pressed }) => [styles.action, { backgroundColor: c.lavenderSoft, borderColor: c.border, opacity: pressed ? 0.85 : 1 }]}
        >
          <Glyph name="books" size={38} />
          <View style={{ flex: 1 }}>
            <T variant="bodyBold">Body-double focus</T>
            <T variant="small">{pet.name} works right beside you for 5, 15 or 25 minutes. +1 star.</T>
          </View>
          <Icon name="chevronRight" size={20} color={c.inkSoft} />
        </Pressable>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/race')}
          style={({ pressed }) => [styles.action, { backgroundColor: c.peachSoft, borderColor: c.border, opacity: pressed ? 0.85 : 1 }]}
        >
          <Glyph name="flag" size={38} />
          <View style={{ flex: 1 }}>
            <T variant="bodyBold">15-minute friend race</T>
            <T variant="small">Both race when it suits you, then swap result codes. No accounts, no strangers. +1 star.</T>
          </View>
          <Icon name="chevronRight" size={20} color={c.inkSoft} />
        </Pressable>
      </View>

      <SectionTitle>Send a cheer</SectionTitle>
      <T variant="small" style={{ marginBottom: space.md }}>
        Pick a kind message to send a friend through any app. Cheers are preset on purpose, so they’re always friendly.
      </T>
      <View style={styles.cheers}>
        {CHEERS.map((cheer) => (
          <Pressable
            key={cheer}
            accessibilityRole="button"
            accessibilityLabel={`Send cheer: ${cheer}`}
            onPress={() => sendCheer(cheer)}
            style={({ pressed }) => [styles.cheer, { backgroundColor: c.surface, borderColor: c.border, opacity: pressed ? 0.8 : 1 }]}
          >
            <T variant="small" color={c.ink}>
              {/* The sent message keeps its emoji; the in-app button stays plain and calm. */}
              {cheer.replace(/\s*[\u{1F300}-\u{1FAFF}\u2600-\u27BF]\uFE0F?/gu, '')}
            </T>
          </Pressable>
        ))}
      </View>
      <Button label="Share MochiNook with a friend" icon="share" kind="soft" style={{ marginTop: space.lg }} onPress={() => sendCheer('Want to be cozy-productive with me? I use MochiNook 🍡')} />
    </Screen>
  );
}

const styles = StyleSheet.create({
  reward: { borderWidth: 1, borderRadius: radius.md, padding: space.md },
  tierBadge: { width: 34, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  day: { alignItems: 'center', gap: 4, paddingVertical: space.sm, borderRadius: radius.sm, width: 38 },
  action: { flexDirection: 'row', alignItems: 'center', gap: space.md, borderWidth: 1, borderRadius: radius.lg, padding: space.lg, minHeight: 84 },
  emptyFace: { width: 22, height: 22, borderRadius: 11, borderWidth: 1.5, borderStyle: 'dashed', marginVertical: 2 },
  cheers: { flexDirection: 'row', flexWrap: 'wrap', gap: space.sm },
  cheer: { borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: space.md, paddingVertical: space.sm + 2, minHeight: 44, justifyContent: 'center' },
});
