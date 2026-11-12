import { useSQLiteContext } from 'expo-sqlite';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import * as repo from '../db/repo';
import { happyLine, levelUpLine, questDoneLine, welcomeBack } from '../lib/copy';
import { celebrateFeedback, stepFeedback, tapFeedback, type FeedbackPrefs } from '../lib/feedback';
import {
  cancelAnchorReminders,
  cancelNotification,
  requestPermission,
  scheduleAnchorReminders,
  scheduleStepTimer,
  setQuietNotifications,
} from '../lib/notifications';
import { XP_PER_STEP, XP_QUEST_BONUS, levelFromXp } from '../lib/progression';
import { initPurchases, isMockStore } from '../lib/purchases';
import { buildStarterRoutine } from '../lib/routineBuilder';
import { dayKey, daysBetween } from '../lib/time';
import type { Anchors, BrainProfile, Energy, Pet, QuestRow, Settings, StepRow } from '../lib/types';

export type PetEvent =
  | { id: number; kind: 'step'; line: string }
  | { id: number; kind: 'quest'; line: string }
  | { id: number; kind: 'level'; line: string; level: number };

type PetEventInput = PetEvent extends infer E ? (E extends PetEvent ? Omit<E, 'id'> : never) : never;

export interface OnboardingAnswers {
  petName: string;
  brainProfile: BrainProfile;
  energy: Energy;
  anchors: Anchors;
}

interface AppState {
  settings: Settings;
  pet: Pet;
  isPro: boolean;
  proSource: 'store' | 'mock' | 'dev' | 'none';
  mockStore: boolean;
  /** Bumps after any data change; screens include it in their load effects. */
  dataVersion: number;
  welcomeBackLine: string | null;
  petEvent: PetEvent | null;
  feedbackPrefs: FeedbackPrefs;
  updateSettings: (patch: Partial<Settings>) => Promise<void>;
  updatePet: (patch: Partial<Omit<Pet, 'xp' | 'affection'>>) => Promise<void>;
  finishOnboarding: (answers: OnboardingAnswers) => Promise<void>;
  toggleCalm: () => Promise<void>;
  enableReminders: () => Promise<boolean>;
  checkStep: (quest: Pick<QuestRow, 'id' | 'cadence' | 'title'>, step: StepRow) => Promise<void>;
  uncheckStep: (quest: Pick<QuestRow, 'id' | 'cadence'>, step: StepRow) => Promise<void>;
  touchData: () => void;
  dismissWelcome: () => void;
  tap: () => void;
}

const AppContext = createContext<AppState | null>(null);

export function useApp(): AppState {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('useApp must be used inside <AppProvider>');
  return ctx;
}

export function AppProvider({ children }: { children: React.ReactNode }) {
  const db = useSQLiteContext();
  const [settings, setSettings] = useState<Settings | null>(null);
  const [pet, setPet] = useState<Pet | null>(null);
  const [storePro, setStorePro] = useState(false);
  const [dataVersion, setDataVersion] = useState(0);
  const [welcomeBackLine, setWelcomeBackLine] = useState<string | null>(null);
  const [petEvent, setPetEvent] = useState<PetEvent | null>(null);
  const eventId = useRef(0);
  const settingsRef = useRef<Settings | null>(null);
  useEffect(() => {
    settingsRef.current = settings;
  }, [settings]);

  // Initial load + "welcome back" check (no streaks, no guilt — just a warm hello).
  useEffect(() => {
    let alive = true;
    (async () => {
      const [s, p] = await Promise.all([repo.getSettings(db), repo.getPet(db)]);
      const today = dayKey();
      if (s.onboarded && s.lastOpenDay && daysBetween(s.lastOpenDay, today) >= 2) {
        setWelcomeBackLine(welcomeBack(p.name, daysBetween(s.lastOpenDay, today)));
      }
      if (s.lastOpenDay !== today) await repo.saveSettings(db, { lastOpenDay: today });
      setQuietNotifications(s.calmMode);
      if (alive) {
        setSettings({ ...s, lastOpenDay: today });
        setPet(p);
      }
    })();
    return () => {
      alive = false;
    };
  }, [db]);

  useEffect(() => {
    let cleanup: (() => void) | undefined;
    initPurchases(setStorePro)
      .then((fn) => {
        cleanup = fn;
      })
      .catch(() => undefined);
    return () => cleanup?.();
  }, []);

  const touchData = useCallback(() => setDataVersion((v) => v + 1), []);

  const updateSettings = useCallback(
    async (patch: Partial<Settings>) => {
      await repo.saveSettings(db, patch);
      // Read back from SQLite so back-to-back updates never overwrite each other.
      const next = await repo.getSettings(db);
      setSettings(next);
      if ('calmMode' in patch) setQuietNotifications(next.calmMode);
      const remindersTouched = 'anchors' in patch || 'calmMode' in patch || 'reminders' in patch;
      if (remindersTouched && next.onboarded) {
        const name = (await repo.getPet(db)).name;
        if (next.reminders) await scheduleAnchorReminders(next.anchors, name).catch(() => undefined);
        else await cancelAnchorReminders().catch(() => undefined);
      }
    },
    [db],
  );

  const updatePet = useCallback(
    async (patch: Partial<Omit<Pet, 'xp' | 'affection'>>) => {
      await repo.updatePet(db, patch);
      setPet(await repo.getPet(db));
    },
    [db],
  );

  const enableReminders = useCallback(async () => {
    const granted = await requestPermission().catch(() => false);
    if (granted) {
      await repo.saveSettings(db, { reminders: true });
      const s = await repo.getSettings(db);
      setSettings(s);
      const name = (await repo.getPet(db)).name;
      await scheduleAnchorReminders(s.anchors, name).catch(() => undefined);
    }
    return granted;
  }, [db]);

  const finishOnboarding = useCallback(
    async (a: OnboardingAnswers) => {
      await repo.updatePet(db, { name: a.petName });
      await repo.setRoutine(db, buildStarterRoutine(a.brainProfile, a.energy, a.anchors.blockKind));
      const patch: Partial<Settings> = {
        onboarded: true,
        brainProfile: a.brainProfile,
        energy: a.energy,
        anchors: a.anchors,
      };
      await repo.saveSettings(db, patch);
      const s = await repo.getSettings(db);
      setSettings(s);
      setPet(await repo.getPet(db));
      setDataVersion((v) => v + 1);
      if (s.reminders) await scheduleAnchorReminders(s.anchors, a.petName).catch(() => undefined);
    },
    [db],
  );

  const feedbackPrefs = useMemo<FeedbackPrefs>(
    () => ({ calm: settings?.calmMode ?? false, sounds: settings?.sounds ?? true, haptics: settings?.haptics ?? true }),
    [settings?.calmMode, settings?.sounds, settings?.haptics],
  );

  const toggleCalm = useCallback(async () => {
    const s = settingsRef.current;
    if (!s) return;
    await updateSettings({ calmMode: !s.calmMode });
  }, [updateSettings]);

  const emit = useCallback((e: PetEventInput) => {
    eventId.current += 1;
    setPetEvent({ ...e, id: eventId.current });
  }, []);

  const checkStep = useCallback(
    async (quest: Pick<QuestRow, 'id' | 'cadence' | 'title'>, step: StepRow) => {
      const today = dayKey();
      const current = await repo.getPet(db);
      let notificationId: string | null = null;
      if (step.timer_minutes && settingsRef.current?.reminders) {
        const next = await repo.nextStepText(db, quest.id, step.position);
        notificationId = await scheduleStepTimer(step.timer_minutes, current.name, next, quest.id).catch(() => null);
      }
      const { questCompleted } = await repo.completeStep(db, quest, step.id, today, notificationId);
      const gained = XP_PER_STEP + (questCompleted ? XP_QUEST_BONUS : 0);
      const { before, after } = await repo.addXp(db, gained, questCompleted ? 3 : 1);
      const levelBefore = levelFromXp(before).level;
      const levelAfter = levelFromXp(after).level;
      setPet(await repo.getPet(db));
      setDataVersion((v) => v + 1);
      if (levelAfter > levelBefore) {
        celebrateFeedback(feedbackPrefs);
        emit({ kind: 'level', line: levelUpLine(current.name, levelAfter), level: levelAfter });
      } else if (questCompleted) {
        celebrateFeedback(feedbackPrefs);
        emit({ kind: 'quest', line: questDoneLine(after) });
      } else {
        stepFeedback(feedbackPrefs);
        emit({ kind: 'step', line: happyLine(after) });
      }
    },
    [db, emit, feedbackPrefs],
  );

  const uncheckStep = useCallback(
    async (quest: Pick<QuestRow, 'id' | 'cadence'>, step: StepRow) => {
      const notificationId = await repo.uncompleteStep(db, quest, step.id, dayKey());
      await cancelNotification(notificationId);
      setDataVersion((v) => v + 1);
    },
    [db],
  );

  const value = useMemo<AppState | null>(() => {
    if (!settings || !pet) return null;
    const override = settings.devUnlocked ? settings.devOverride : 'auto';
    let isPro: boolean;
    let proSource: AppState['proSource'];
    if (override === 'pro') {
      isPro = true;
      proSource = 'dev';
    } else if (override === 'free') {
      isPro = false;
      proSource = 'none';
    } else if (storePro) {
      isPro = true;
      proSource = 'store';
    } else if (isMockStore && settings.mockPro) {
      isPro = true;
      proSource = 'mock';
    } else {
      isPro = false;
      proSource = 'none';
    }
    return {
      settings,
      pet,
      isPro,
      proSource,
      mockStore: isMockStore,
      dataVersion,
      welcomeBackLine,
      petEvent,
      feedbackPrefs,
      updateSettings,
      updatePet,
      finishOnboarding,
      toggleCalm,
      enableReminders,
      checkStep,
      uncheckStep,
      touchData,
      dismissWelcome: () => setWelcomeBackLine(null),
      tap: () => tapFeedback(feedbackPrefs),
    };
  }, [
    settings, pet, storePro, dataVersion, welcomeBackLine, petEvent, feedbackPrefs, updateSettings, updatePet,
    finishOnboarding, toggleCalm, enableReminders, checkStep, uncheckStep, touchData,
  ]);

  // Render nothing until settings and pet are loaded from SQLite (a few milliseconds).
  if (!settings || !pet) return null;
  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}
