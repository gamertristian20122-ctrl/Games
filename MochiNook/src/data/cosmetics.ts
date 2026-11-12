import type { Season } from '../lib/season';

export type CosmeticKind = 'color' | 'hat' | 'scarf' | 'room';

/** Seasonal items are earned (by everyone, Free or Pro) through weekly Mochi Sprints and kept forever. */
export interface SeasonalTag {
  season?: Season;
  tier?: 1 | 2 | 3;
}

export interface PetColor {
  id: string;
  name: string;
  body: string;
  outline: string;
  blush: string;
  ear: string;
  free: boolean;
  season?: Season;
  tier?: 1 | 2 | 3;
}

export interface Cosmetic extends SeasonalTag {
  id: string;
  name: string;
  free: boolean;
}

export const PET_COLORS: PetColor[] = [
  { id: 'cream', name: 'Mochi Cream', body: '#FFF8EE', outline: '#DEC8B2', blush: '#F6B0A0', ear: '#FCE6DA', free: true },
  { id: 'peach', name: 'Peach Bun', body: '#FDE1D0', outline: '#E3B79C', blush: '#F29C8C', ear: '#FBD0BC', free: true },
  { id: 'lavender', name: 'Lavender Puff', body: '#ECE3F8', outline: '#C2B2DD', blush: '#F2A7B8', ear: '#E0D3F3', free: false },
  { id: 'mint', name: 'Matcha Mint', body: '#E2F0DD', outline: '#A9C6A1', blush: '#F2AFA2', ear: '#D3E8CC', free: false },
  { id: 'sky', name: 'Cloud Blue', body: '#E1EEF6', outline: '#A9C4D6', blush: '#F2AFB4', ear: '#D2E4EF', free: false },
  { id: 'butter', name: 'Butter Toast', body: '#FBF0CC', outline: '#DCC88A', blush: '#F3AA94', ear: '#F6E5AE', free: false },
  { id: 'strawberry', name: 'Strawberry Milk', body: '#FCE0E6', outline: '#E3AEBA', blush: '#EE8EA2', ear: '#F9CDD6', free: false },
  { id: 'sesame', name: 'Black Sesame', body: '#5B534D', outline: '#3E3833', blush: '#C98A86', ear: '#6E655E', free: false },
  { id: 'pumpkin', name: 'Pumpkin Spice', body: '#FBD9B6', outline: '#DDA472', blush: '#F09A84', ear: '#F8C99C', free: false, season: 'autumn', tier: 1 },
  { id: 'frost', name: 'Frosty Mint', body: '#E6F3F4', outline: '#A6CBCF', blush: '#F2AFB8', ear: '#D6EBED', free: false, season: 'winter', tier: 1 },
  { id: 'sakura', name: 'Sakura Puff', body: '#FDE4EC', outline: '#E4AFC0', blush: '#EE8FA8', ear: '#F9D2DE', free: false, season: 'spring', tier: 1 },
  { id: 'lemonade', name: 'Lemonade', body: '#FDF4C4', outline: '#DDCB7C', blush: '#F3A994', ear: '#F9EAA2', free: false, season: 'summer', tier: 1 },
];

export const HATS: Cosmetic[] = [
  { id: 'none', name: 'No hat', free: true },
  { id: 'sprout', name: 'Little Sprout', free: true },
  { id: 'beanie', name: 'Cozy Beanie', free: false },
  { id: 'flowers', name: 'Flower Crown', free: false },
  { id: 'party', name: 'Party Hat', free: false },
  { id: 'wizard', name: 'Starry Wizard', free: false },
  { id: 'frog', name: 'Froggy Hood', free: false },
  { id: 'bow', name: 'Ribbon Bow', free: false },
  { id: 'acorn', name: 'Acorn Cap', free: false, season: 'autumn', tier: 3 },
  { id: 'earmuffs', name: 'Fluffy Earmuffs', free: false, season: 'winter', tier: 3 },
  { id: 'blossom', name: 'Blossom Clip', free: false, season: 'spring', tier: 3 },
  { id: 'sunhat', name: 'Straw Sunhat', free: false, season: 'summer', tier: 3 },
];

export const SCARVES: Cosmetic[] = [
  { id: 'none', name: 'No scarf', free: true },
  { id: 'sage', name: 'Sage Knit', free: false },
  { id: 'peach', name: 'Peach Knit', free: false },
  { id: 'stripes', name: 'Lavender Stripes', free: false },
  { id: 'butter', name: 'Butter Bandana', free: false },
  { id: 'maple', name: 'Maple Scarf', free: false, season: 'autumn', tier: 2 },
  { id: 'snowy', name: 'Snowy Scarf', free: false, season: 'winter', tier: 2 },
  { id: 'petal', name: 'Petal Scarf', free: false, season: 'spring', tier: 2 },
  { id: 'sunny', name: 'Sunny Stripes', free: false, season: 'summer', tier: 2 },
];

export const ROOMS: Cosmetic[] = [
  { id: 'sunny', name: 'Sunny Nook', free: true },
  { id: 'rainy', name: 'Rainy Window', free: false },
  { id: 'starry', name: 'Starry Loft', free: false },
  { id: 'forest', name: 'Forest Cabin', free: false },
  { id: 'beach', name: 'Beach Hut', free: false },
];

export function findColor(id: string): PetColor {
  return PET_COLORS.find((c) => c.id === id) ?? PET_COLORS[0]!;
}

export function isCosmeticFree(kind: CosmeticKind, id: string): boolean {
  const list = kind === 'color' ? PET_COLORS : kind === 'hat' ? HATS : kind === 'scarf' ? SCARVES : ROOMS;
  return list.find((c) => c.id === id)?.free ?? false;
}

export function isSeasonal(kind: CosmeticKind, id: string): boolean {
  const list = kind === 'color' ? PET_COLORS : kind === 'hat' ? HATS : kind === 'scarf' ? SCARVES : ROOMS;
  return list.find((c) => c.id === id)?.season !== undefined;
}

export const PET_NAMES = ['Mochi', 'Pip', 'Bean', 'Dumpling', 'Biscuit'] as const;

export interface SeasonalReward {
  kind: 'color' | 'hat' | 'scarf';
  id: string;
  name: string;
  tier: 1 | 2 | 3;
}

/** The three rewards a season's Sprints unlock, in tier order. */
export function seasonalRewards(season: Season): SeasonalReward[] {
  const out: SeasonalReward[] = [];
  for (const c of PET_COLORS) if (c.season === season && c.tier) out.push({ kind: 'color', id: c.id, name: c.name, tier: c.tier });
  for (const c of SCARVES) if (c.season === season && c.tier) out.push({ kind: 'scarf', id: c.id, name: c.name, tier: c.tier });
  for (const c of HATS) if (c.season === season && c.tier) out.push({ kind: 'hat', id: c.id, name: c.name, tier: c.tier });
  return out.sort((a, b) => a.tier - b.tier);
}

/** Key used to store an earned cosmetic (ids repeat across kinds, e.g. color "peach" and scarf "peach"). */
export function cosmeticKey(kind: CosmeticKind, id: string): string {
  return `${kind}:${id}`;
}
