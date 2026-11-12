export type BrainProfile = 'adhd' | 'add' | 'autism' | 'audhd' | 'anxiety' | 'other';
export type Energy = 'low' | 'medium' | 'high';
export type Anchor = 'morning' | 'daytime' | 'evening' | 'anytime';
export type Cadence = 'daily' | 'weekly' | 'monthly' | 'once';
export type BlockKind = 'school' | 'work' | 'none';
export type ThemePref = 'system' | 'light' | 'dark';
export type QuestSource = 'library' | 'custom' | 'shared';
export type DevOverride = 'auto' | 'free' | 'pro';

export type QuestCategory =
  | 'morning'
  | 'evening'
  | 'kitchen'
  | 'laundry'
  | 'home'
  | 'body'
  | 'care'
  | 'adulting'
  | 'social'
  | 'school';

export interface LibraryStep {
  text: string;
  timerMinutes?: number;
  tiny?: string[];
}

export interface LibraryQuest {
  id: string;
  title: string;
  emoji: string;
  category: QuestCategory;
  anchor: Anchor;
  cadence: Cadence;
  essential: boolean;
  invite: string;
  keywords: string[];
  steps: LibraryStep[];
}

/** Clock time stored as minutes after midnight (0–1439). */
export type ClockMinutes = number;

export interface Anchors {
  wake: ClockMinutes;
  blockKind: BlockKind;
  blockStart: ClockMinutes;
  blockEnd: ClockMinutes;
  bed: ClockMinutes;
}

export interface Settings {
  onboarded: boolean;
  /** Multi-select from onboarding question 1. */
  brainProfiles: BrainProfile[];
  energy: Energy;
  anchors: Anchors;
  calmMode: boolean;
  sounds: boolean;
  haptics: boolean;
  reminders: boolean;
  theme: ThemePref;
  devUnlocked: boolean;
  devOverride: DevOverride;
  mockPro: boolean;
  lastOpenDay: string | null;
  tipsGiven: number;
  /** Pet care moments (never a hunger meter; just gentle limits so pats stay special). */
  lastPatAt: number;
  lastSnackDay: string | null;
  lastTuckDay: string | null;
}

export interface Pet {
  name: string;
  xp: number;
  affection: number;
  color: string;
  hat: string;
  scarf: string;
  room: string;
  /** Earned with every micro-step; spent in the Nook shop. */
  pebbles: number;
}

export interface QuestRow {
  id: string;
  title: string;
  emoji: string;
  category: QuestCategory;
  anchor: Anchor;
  cadence: Cadence;
  essential: number;
  invite: string;
  source: QuestSource;
}

export interface StepRow {
  id: number;
  quest_id: string;
  position: number;
  text: string;
  timer_minutes: number | null;
  tiny: string | null;
}

export interface StepWithState extends StepRow {
  done: boolean;
}

export interface QuestWithProgress extends QuestRow {
  inRoutine: boolean;
  steps: StepWithState[];
  doneCount: number;
  completedToday: boolean;
}

/** A routine entry inside a caregiver share code. */
export interface SharedQuest {
  /** Library id, or null for a custom quest that travels with its own steps. */
  id: string | null;
  title?: string;
  emoji?: string;
  anchor: Anchor;
  cadence?: Cadence;
  steps?: string[];
}

export interface SharePayload {
  v: 1;
  quests: SharedQuest[];
  anchors?: Anchors;
}
