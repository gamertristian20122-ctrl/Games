/**
 * Names of MochiNook's custom icons, plus the mapping from every emoji older
 * versions stored. Kept free of React so tests and data code can use it.
 */
export const GLYPH_NAMES = [
  'drop',
  'pill',
  'toothbrush',
  'sun',
  'sunCloud',
  'moon',
  'shirt',
  'bowl',
  'toast',
  'pan',
  'plate',
  'backpack',
  'headphones',
  'medkit',
  'paw',
  'hanger',
  'polish',
  'scissors',
  'chat',
  'laptop',
  'folder',
  'clipboard',
  'bookOpen',
  'books',
  'notepad',
  'phone',
  'mail',
  'plug',
  'candle',
  'trash',
  'calendar',
  'stretch',
  'hand',
  'rocket',
  'shower',
  'bath',
  'couch',
  'bed',
  'cart',
  'lunchbox',
  'cup',
  'tooth',
  'cheese',
  'fridge',
  'socks',
  'lotion',
  'yarn',
  'teddy',
  'broom',
  'basket',
  'soap',
  'sponge',
  'receipt',
  'coin',
  'plant',
  'bubbles',
  'heart',
  'hourglass',
  'sparkle',
  'star',
  'flag',
  'spoon',
  'sunrise',
  'briefcase',
  'leaf',
  'snowflake',
  'blossom',
  'lightning',
  'cloud',
  'puzzle',
  'rainbow',
  'tea',
  'dango',
  'gift',
  'cookie',
  'check',
  'tray',
  'box',
  'pencil',
  'lamp',
  'pebble',
] as const;

export type GlyphName = (typeof GLYPH_NAMES)[number];

export function isGlyphName(v: string): v is GlyphName {
  return (GLYPH_NAMES as readonly string[]).includes(v);
}

/** Maps every emoji MochiNook has ever stored (library quests, custom quests, share codes) to a glyph. */
export const EMOJI_TO_GLYPH: Record<string, GlyphName> = {
  '💧': 'drop', '💊': 'pill', '🪥': 'toothbrush', '🫧': 'bubbles', '👕': 'shirt', '🍞': 'toast', '🎒': 'backpack',
  '🚀': 'rocket', '🌙': 'moon', '🧦': 'socks', '🔌': 'plug', '📋': 'clipboard', '🕯️': 'candle', '🌛': 'moon',
  '🚿': 'shower', '🍽️': 'plate', '🥣': 'bowl', '🧊': 'fridge', '🗑️': 'trash', '🍜': 'bowl', '🛒': 'cart',
  '🧺': 'basket', '👚': 'shirt', '🛏️': 'bed', '🧹': 'broom', '🗂️': 'tray', '🧼': 'soap', '🧸': 'teddy',
  '🪴': 'plant', '🐾': 'paw', '🥤': 'cup', '🙆': 'stretch', '🎧': 'headphones', '🫶': 'heart', '🌤️': 'sunCloud',
  '🧾': 'receipt', '📁': 'folder', '📞': 'phone', '💬': 'chat', '📬': 'mail', '🪙': 'coin', '🗓️': 'calendar',
  '🏥': 'medkit', '📚': 'books', '⏳': 'hourglass', '💻': 'laptop', '🧶': 'yarn', '📝': 'notepad', '🙋': 'hand',
  '📖': 'bookOpen', '🧴': 'lotion', '💅': 'polish', '🛋️': 'couch', '🛁': 'bath', '🧽': 'sponge', '👗': 'hanger',
  '🍳': 'pan', '🍝': 'bowl', '🥗': 'lunchbox', '🧀': 'cheese', '🦷': 'tooth', '💇': 'scissors', '✨': 'sparkle',
  '📦': 'box', '💌': 'mail', '🧠': 'sparkle', '⭐': 'star', '🏁': 'flag',
};

/** Same map, keyed without the invisible emoji "variation selector" some keyboards add or drop. */
const NORMALIZED: Record<string, GlyphName> = Object.fromEntries(
  Object.entries(EMOJI_TO_GLYPH).map(([k, v]) => [k.replace(/\uFE0F/g, ''), v]),
);

/** Accepts a glyph name (new data) or a legacy emoji (older data) and always returns a glyph. */
export function glyphFor(value: string | null | undefined): GlyphName {
  if (!value) return 'sparkle';
  if (isGlyphName(value)) return value;
  return EMOJI_TO_GLYPH[value] ?? NORMALIZED[value.replace(/\uFE0F/g, '')] ?? 'sparkle';
}
