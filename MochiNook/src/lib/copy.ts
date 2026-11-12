/**
 * Every word the pet says. House style (PDA-safe):
 * - Invite, never instruct. Questions and "we" over commands.
 * - Always leave an exit ("or not, that's okay too").
 * - Never mention streaks, misses, or what wasn't done.
 */

function pick<T>(list: readonly T[], seed: number): T {
  return list[Math.abs(Math.floor(seed)) % list.length]!;
}

export const idleLines = [
  'I like hanging out with you.',
  'No rush. Want to pick one tiny thing together?',
  "I'm just here being cozy. Join me whenever.",
  'Small steps still count as steps.',
  "Whatever today looks like, I'm glad you're here.",
  'Want to see what our next tiny win could be?',
  "Resting is allowed. I'll be right here.",
] as const;

export const happyLines = [
  'Ooh, that made me so happy!',
  'Look at us go!',
  'That was a real win. I felt it!',
  'Yay! I just did a little wiggle.',
  'Nice! My battery is filling up.',
  "You did that! I'm so proud of us.",
] as const;

export const questDoneLines = [
  'We finished the whole thing! I am doing a happy spin.',
  'Quest complete! That deserves a cozy break.',
  'All done! Future-you says thank you.',
] as const;

export const spoonSavingLines = [
  "Spoon-Saving Mode is on. Just the essentials today. Everything else will wait patiently.",
  'Low-spoon day? We can keep it tiny. Even one step is plenty.',
] as const;

export function welcomeBack(name: string, daysAway: number): string {
  if (daysAway >= 7) {
    return `Welcome back! ${name} took a long cozy nap while you were away. Ready for one tiny win today?`;
  }
  return `Welcome back! I took a cozy nap while you were away. Ready for one tiny win today?`;
}

export function idleLine(seed: number): string {
  return pick(idleLines, seed);
}

export function happyLine(seed: number): string {
  return pick(happyLines, seed);
}

export function questDoneLine(seed: number): string {
  return pick(questDoneLines, seed);
}

export function levelUpLine(name: string, level: number): string {
  return `${name} grew a little cozier and reached level ${level}!`;
}

export const allClearLine = "That's everything on today's list. Anything more is a bonus, and resting counts too.";

export const notificationCopy = {
  morning: (name: string) => ({
    title: `${name} is waking up ☀️`,
    body: 'Want to start with one sip of water together? Totally optional.',
  }),
  blockStart: (name: string, kind: 'school' | 'work') => ({
    title: kind === 'school' ? 'School time is close 🎒' : 'Work block is close 💼',
    body: `Want to do a quick launch-pad check with ${name}? Keys, phone, bag.`,
  }),
  blockEnd: (name: string) => ({
    title: `${name} saved you a cozy spot 🧶`,
    body: 'Want to do one tiny reset together? Or just rest, that counts too.',
  }),
  windDown: (name: string) => ({
    title: 'Wind-down time is close 🌙',
    body: `Want to brush teeth together so ${name} can get cozy?`,
  }),
  timer: (name: string, nextStep: string | null) => ({
    title: `${name} has a gentle nudge ⏲️`,
    body: nextStep
      ? `Your timer's done. Want to try the next step together? "${nextStep}"`
      : "Your timer's done. Want to see what's next together?",
  }),
};

/**
 * Cheers: the ONLY things friends can send each other. Preset phrases mean there is
 * no free typing, so nothing unsafe can be written and nothing needs moderating.
 */
export const CHEERS = [
  'Proud of you! 🌱',
  'You’ve got this. One tiny step at a time.',
  'Rest counts too. 💛',
  'Sending you a cozy blanket of good vibes 🧶',
  'Small wins are real wins! ✨',
  'Want to do a focus sprint together later?',
  'Thinking of you today 🫶',
  'Drink some water for me! 💧',
  'Your pace is the right pace.',
  'Whatever today looks like, you’re doing enough.',
  'Race you tomorrow? 🏁',
  'Thank you for being my friend 🌸',
] as const;

export function cheerMessage(cheer: string, petName: string): string {
  return `${cheer}\n\n(A MochiNook cheer from ${petName} 🍡)`;
}

export const petCareLines = {
  pat: ['That tickles!', 'Ahh, pats are the best.', 'Hehe, thank you!', 'I feel so loved right now.'],
  snack: ['Yum! A tiny snack, just what I needed.', 'Crunch crunch… delicious!', 'Thank you for sharing!'],
  tuck: ['Goodnight… thanks for tucking me in', 'So cozy. Sweet dreams to you too.', 'Zzz… see you tomorrow'],
  rested: 'I’m all cozy right now. Thank you for checking on me!',
};

/** Daily check-in moods: gentle words, no "bad" option. */
export const MOODS = [
  { value: 1, word: 'Rough' },
  { value: 2, word: 'Low' },
  { value: 3, word: 'Okay' },
  { value: 4, word: 'Good' },
  { value: 5, word: 'Great' },
] as const;
