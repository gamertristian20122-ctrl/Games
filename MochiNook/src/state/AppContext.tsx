import { useSQLiteContext } from 'expo-sqlite';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import * as repo from '../db/repo';
import { happyLine, levelUpLine, petCareLines, questDoneLine, welcomeBack } from '../lib/copy';
import { celebrateFeedback, stepFeedback, tapFeedback, type FeedbackPrefs } from '../lib/feedback';
import { migrateDatabase } from '../db/schema';
import {
  cancelAllReminders,
  cancelAnchorReminders,
  cancelNotification,
  requestPermission,
  scheduleAnchorReminders,
  scheduleStepTimer,
  setQuietNotifications,
} from '../lib/notifications';
import { cosmeticKey, isCosmeticFree, isSeasonal, type CosmeticKind } from '../data/cosmetics';
import { PEBBLES_PER_STEP, PEBBLES_QUEST_BONUS, findShopItem } from '../data/shop';
import { SEASON_INFO, seasonFor, sprintTiers, weekStart } from '../lib/season';
import { XP_PER_STEP, XP_QUEST_BONUS, levelFromXp } from '../lib/progression';
import { TEST_TOOLS_ALLOWED, initPurchases, isMockStore } from '../lib/purchases';
import { buildStarterRoutine } from '../lib/routineBuilder';
import { dayKey, daysBetween } from '../lib/time';
import type { Anchors, BrainProfile, Energy, Pet, QuestRow, Settings, StepRow } from '../lib/types';

export type PetEvent =
  | { id: number; kind: 'step'; line: string; pebbles: number }
  | { id: number; kind: 'quest'; line: string; pebbles: number }
  | { id: number; kind: 'level'; line: string; level: number; pebbles: number }
  | { id: number; kind: 'treat'; line: string; pebbles: 0 }
  | { id: number; kind: 'care'; line: string; pebbles: 0 }
  | { id: number; kind: 'reward'; line: string; pebbles: number };

export type CareKind = 'pat' | 'snack' | 'tuck';

type PetEventInput = PetEvent extends infer E ? (E extends PetEvent ? Omit<E, 'id'> : never) : never;

export interface OnboardingAnswers {
  petName: string;
  brainProfiles: BrainProfile[];
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
  updatePet: (patch: Partial<Omit<Pet, 'xp' | 'affection' | 'pebbles'>>) => Promise<void>;
  /** Owned Pebble-shop decor, with whether each is shown in the room. */
  owned: repo.OwnedItem[];
  buyItem: (itemId: string) => Promise<repo.BuyResult>;
  setDecorPlaced: (itemId: string, placed: boolean) => Promise<void>;
  finishOnboarding: (answers: OnboardingAnswers) => Promise<void>;
  toggleCalm: () => Promise<void>;
  enableReminders: () => Promise<boolean>;
  checkStep: (quest: Pick<QuestRow, 'id' | 'cadence' | 'title'>, step: StepRow) => Promise<void>;
  uncheckStep: (quest: Pick<QuestRow, 'id' | 'cadence'>, step: StepRow) => Promise<void>;
  touchData: () => void;
  /** Earned seasonal cosmetics, as "kind:id" keys. */
  ownedCosmetics: string[];
  /** Whether the pet may wear an item: free, earned, or (non-seasonal) Pro. */
  canWear: (kind: CosmeticKind, id: string) => boolean;
  petCare: (kind: CareKind) => Promise<boolean>;
  saveCheckin: (mood: number, energy: Energy) => Promise<void>;
  completeFocus: (sessionId: number, completed: boolean) => Promise<void>;
  completeRace: (raceId: number) => Promise<number>;
  /** Re-checks this week's Sprint Stars and grants any newly reached seasonal rewards. */
  syncSprint: () => Promise<void>;
  /** Erases every bit of local data and starts fresh at onboarding. */
  deleteAllData: () => Promise<void>;
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
  // checkStep is defined before syncSprint; this ref lets it trigger a sprint check after a quest.
  const syncSprintRef = useRef<() => Promise<void>>(async () => undefined);
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
    async (patch: Partial<Omit<Pet, 'xp' | 'affection' | 'pebbles'>>) => {
      const before = await repo.getPet(db);
      await repo.updatePet(db, patch);
      const after = await repo.getPet(db);
      setPet(after);
      // Reminders carry the pet's name, so reschedule them after a rename.
      if (after.name !== before.name) {
        const s = await repo.getSettings(db);
        if (s.onboarded && s.reminders) await scheduleAnchorReminders(s.anchors, after.name).catch(() => undefined);
      }
    },
    [db],
  );

  const [owned, setOwned] = useState<repo.OwnedItem[]>([]);
  useEffect(() => {
    repo.getOwnedItems(db).then(setOwned).catch(() => undefined);
  }, [db]);

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
      await repo.setRoutine(db, buildStarterRoutine(a.brainProfiles, a.energy, a.anchors.blockKind));
      const patch: Partial<Settings> = {
        onboarded: true,
        brainProfiles: a.brainProfiles,
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
      const pebbles = PEBBLES_PER_STEP + (questCompleted ? PEBBLES_QUEST_BONUS : 0);
      const { before, after } = await repo.addProgress(db, gained, questCompleted ? 3 : 1, pebbles);
      const levelBefore = levelFromXp(before).level;
      const levelAfter = levelFromXp(after).level;
      setPet(await repo.getPet(db));
      setDataVersion((v) => v + 1);
      if (levelAfter > levelBefore) {
        celebrateFeedback(feedbackPrefs);
        emit({ kind: 'level', line: levelUpLine(current.name, levelAfter), level: levelAfter, pebbles });
      } else if (questCompleted) {
        celebrateFeedback(feedbackPrefs);
        emit({ kind: 'quest', line: questDoneLine(after), pebbles });
        setTimeout(() => {
          syncSprintRef.current().catch(() => undefined);
        }, 2600);
      } else {
        stepFeedback(feedbackPrefs);
        emit({ kind: 'step', line: happyLine(after), pebbles });
      }
    },
    [db, emit, feedbackPrefs],
  );

  const buyItem = useCallback(
    async (itemId: string) => {
      const result = await repo.buyShopItem(db, itemId);
      if (result.ok) {
        const [p, items] = await Promise.all([repo.getPet(db), repo.getOwnedItems(db)]);
        setPet(p);
        setOwned(items);
        celebrateFeedback(feedbackPrefs);
        if (result.kind === 'treat') {
          const name = findShopItem(itemId)?.name.toLowerCase() ?? 'treat';
          emit({ kind: 'treat', line: `Yum! Thank you for the ${name}! 💕`, pebbles: 0 });
        }
      }
      return result;
    },
    [db, emit, feedbackPrefs],
  );

  const setDecorPlaced = useCallback(
    async (itemId: string, placed: boolean) => {
      await repo.setItemPlaced(db, itemId, placed);
      setOwned(await repo.getOwnedItems(db));
    },
    [db],
  );

  const [ownedCosmetics, setOwnedCosmetics] = useState<string[]>([]);
  useEffect(() => {
    repo.getOwnedCosmetics(db).then(setOwnedCosmetics).catch(() => undefined);
  }, [db]);

  const syncSprint = useCallback(async () => {
    const s = await repo.getSettings(db);
    const today = dayKey();
    const stats = await repo.getSprintStats(db, weekStart(today));
    const earned = await repo.syncSeasonRewards(db, seasonFor(), stats.stars, sprintTiers(s.energy));
    if (earned.length > 0) {
      setOwnedCosmetics(await repo.getOwnedCosmetics(db));
      const last = earned[earned.length - 1]!;
      celebrateFeedback(feedbackPrefs);
      emit({ kind: 'reward', line: `Sprint reward unlocked: ${last.name}! ${SEASON_INFO[seasonFor()].emoji} It’s yours to keep.`, pebbles: 0 });
    }
  }, [db, emit, feedbackPrefs]);

  useEffect(() => {
    syncSprintRef.current = syncSprint;
  }, [syncSprint]);

  const award = useCallback(
    async (pebbles: number, xp: number, line: string) => {
      await repo.addProgress(db, xp, 1, pebbles);
      setPet(await repo.getPet(db));
      celebrateFeedback(feedbackPrefs);
      emit({ kind: 'reward', line, pebbles });
      await syncSprint();
    },
    [db, emit, feedbackPrefs, syncSprint],
  );

  const completeFocus = useCallback(
    async (sessionId: number, completed: boolean) => {
      await repo.finishFocus(db, sessionId, completed);
      await award(completed ? 3 : 1, completed ? 10 : 3, completed ? 'Focus sprint done! We did that side by side. 📚' : 'Stopping early still counts. Nice work showing up. 💛');
    },
    [db, award],
  );

  const completeRace = useCallback(
    async (raceId: number) => {
      const steps = await repo.finishRace(db, raceId);
      await award(2, 5, steps > 0 ? `Race finished with ${steps} tiny ${steps === 1 ? 'step' : 'steps'}! 🏁` : 'Race finished! Showing up is the whole point. 🏁');
      return steps;
    },
    [db, award],
  );

  const saveCheckin = useCallback(
    async (mood: number, energy: Energy) => {
      await repo.saveCheckin(db, dayKey(), mood, energy);
      await repo.saveSettings(db, { energy });
      setSettings(await repo.getSettings(db));
      setDataVersion((v) => v + 1);
    },
    [db],
  );

  /** Gentle limits keep care moments special. There is no hunger meter and nothing to neglect. */
  const petCare = useCallback(
    async (kind: CareKind) => {
      const s = await repo.getSettings(db);
      const today = dayKey();
      const now = Date.now();
      const pick = (list: readonly string[]) => list[now % list.length]!;
      let allowed = false;
      if (kind === 'pat' && now - s.lastPatAt > 60 * 60 * 1000) {
        allowed = true;
        await repo.saveSettings(db, { lastPatAt: now });
      } else if (kind === 'snack' && s.lastSnackDay !== today) {
        allowed = true;
        await repo.saveSettings(db, { lastSnackDay: today });
      } else if (kind === 'tuck' && s.lastTuckDay !== today) {
        allowed = true;
        await repo.saveSettings(db, { lastTuckDay: today });
      }
      setSettings(await repo.getSettings(db));
      if (allowed) {
        await repo.addProgress(db, 0, 1, 0);
        setPet(await repo.getPet(db));
        stepFeedback(feedbackPrefs);
        emit({ kind: 'care', line: pick(petCareLines[kind]), pebbles: 0 });
      } else {
        emit({ kind: 'care', line: petCareLines.rested, pebbles: 0 });
      }
      return allowed;
    },
    [db, emit, feedbackPrefs],
  );

  const deleteAllData = useCallback(async () => {
    await cancelAllReminders();
    await repo.deleteAllData(db);
    await migrateDatabase(db);
    const [s, p, items] = await Promise.all([repo.getSettings(db), repo.getPet(db), repo.getOwnedItems(db)]);
    setSettings(s);
    setPet(p);
    setOwned(items);
    setOwnedCosmetics([]);
    setWelcomeBackLine(null);
    setPetEvent(null);
    setDataVersion((v) => v + 1);
  }, [db]);

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
    const override = TEST_TOOLS_ALLOWED && settings.devUnlocked ? settings.devOverride : 'auto';
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
      owned,
      buyItem,
      setDecorPlaced,
      finishOnboarding,
      toggleCalm,
      enableReminders,
      checkStep,
      uncheckStep,
      touchData,
      ownedCosmetics,
      canWear: (kind: CosmeticKind, id: string) => {
        if (isCosmeticFree(kind, id) || ownedCosmetics.includes(cosmeticKey(kind, id))) return true;
        return isPro && !isSeasonal(kind, id);
      },
      petCare,
      saveCheckin,
      completeFocus,
      completeRace,
      syncSprint,
      deleteAllData,
      dismissWelcome: () => setWelcomeBackLine(null),
      tap: () => tapFeedback(feedbackPrefs),
    };
  }, [
    settings, pet, storePro, dataVersion, welcomeBackLine, petEvent, feedbackPrefs, updateSettings, updatePet, owned, buyItem, setDecorPlaced,
    finishOnboarding, toggleCalm, enableReminders, checkStep, uncheckStep, touchData, deleteAllData,
    ownedCosmetics, petCare, saveCheckin, completeFocus, completeRace, syncSprint,
  ]);

  // Render nothing until settings and pet are loaded from SQLite (a few milliseconds).
  if (!settings || !pet) return null;
  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}
