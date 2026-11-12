/**
 * The Pebble shop: starter room items and treats anyone can earn.
 * Pebbles come only from finishing micro-steps. They can never be bought with money.
 */
export type ShopKind = 'decor' | 'treat';

export interface ShopItem {
  id: string;
  name: string;
  kind: ShopKind;
  price: number;
  blurb: string;
}

export const PEBBLES_PER_STEP = 1;
export const PEBBLES_QUEST_BONUS = 3;

export const SHOP_ITEMS: ShopItem[] = [
  { id: 'fern', name: 'Little Fern', kind: 'decor', price: 10, blurb: 'A leafy friend for the corner.' },
  { id: 'poster', name: 'Star Poster', kind: 'decor', price: 12, blurb: 'A soft starry print for the wall.' },
  { id: 'rug', name: 'Cloud Rug', kind: 'decor', price: 18, blurb: 'Fluffy feet, happy pet.' },
  { id: 'lamp', name: 'Moon Lamp', kind: 'decor', price: 20, blurb: 'A gentle glow for slow evenings.' },
  { id: 'books', name: 'Book Stack', kind: 'decor', price: 22, blurb: 'Cozy stories, stacked just so.' },
  { id: 'lights', name: 'Fairy Lights', kind: 'decor', price: 25, blurb: 'Twinkly, but never blinky.' },
  { id: 'plush', name: 'Kitty Plush', kind: 'decor', price: 28, blurb: 'A tiny buddy for your buddy.' },
  { id: 'beanbag', name: 'Bean Bag', kind: 'decor', price: 32, blurb: 'The comfiest spot in the nook.' },
  { id: 'mochi-treat', name: 'Strawberry Mochi', kind: 'treat', price: 5, blurb: 'A sweet snack. Your pet will be thrilled.' },
  { id: 'cocoa-treat', name: 'Warm Cocoa', kind: 'treat', price: 8, blurb: 'A cozy cup to share.' },
];

export function findShopItem(id: string): ShopItem | undefined {
  return SHOP_ITEMS.find((i) => i.id === id);
}

/** The Cozy Mystery Pouch: a surprise unowned room item or hat. */
export const POUCH_PRICE = 15;
