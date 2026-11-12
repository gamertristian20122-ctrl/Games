/** Gentle pet progression. XP only ever goes up; there is nothing to lose. */

export const XP_PER_STEP = 5;
export const XP_QUEST_BONUS = 15;

/** XP needed to go from `level` to `level + 1`. */
export function xpForNextLevel(level: number): number {
  return 40 + (level - 1) * 20;
}

export interface LevelInfo {
  level: number;
  /** XP earned inside the current level. */
  into: number;
  /** XP needed to finish the current level. */
  needed: number;
}

export function levelFromXp(totalXp: number): LevelInfo {
  let level = 1;
  let remaining = Math.max(0, Math.floor(totalXp));
  while (remaining >= xpForNextLevel(level)) {
    remaining -= xpForNextLevel(level);
    level += 1;
  }
  return { level, into: remaining, needed: xpForNextLevel(level) };
}
