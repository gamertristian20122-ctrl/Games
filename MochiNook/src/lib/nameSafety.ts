/**
 * Name safety filter for the companion's name.
 *
 * Runs fully offline and is always on (names show up in notifications, race codes and
 * screenshots, and MochiNook is used by kids and in classrooms).
 *
 * How it works:
 * 1. Clean the name: keep letters, numbers, spaces, ' and -, max 20 characters.
 * 2. For checking only, normalize it: lower case, strip accents, undo leetspeak (0→o, 3→e, $→s, ph→f…).
 * 3. Two lists:
 *    - ANYWHERE roots are long and unambiguous, so they are blocked even inside other words ("xfuckx").
 *    - WORD roots hide inside innocent words (class, peacock, grape, Scunthorpe), so they are only
 *      blocked as a whole word, optionally with a rude suffix (-s, -head, -face, -hole…).
 *    Stretched letters ("fuuuck") and spaced-out letters ("f u c k") are caught too.
 *
 * The word lists are ROT13-encoded so this file isn't a wall of swear words to read through.
 */

export type NameCheck = { ok: true; name: string } | { ok: false; reason: 'empty' | 'unkind'; message: string };

export const NAME_MAX = 20;

/** Gentle, zero-shame copy shown when a name can't be used. */
export const UNSAFE_NAME_MESSAGE = 'Let’s pick a different name for your mochi. Here are some cozy ideas.';

function rot13(s: string): string {
  return s.replace(/[a-z]/g, (ch) => String.fromCharCode(((ch.charCodeAt(0) - 97 + 13) % 26) + 97));
}

function decodeList(encoded: string): string[] {
  return encoded.split(',').map(rot13);
}

const ANYWHERE = decodeList(
  'shpx,shx,spx,fuvg,ovgpu,ovngpu,juber,fyhg,avtt,avtn,sntt,snttbg,cbea,qvyqb,cravf,intvan,uvgyre,wvmm,obyybpx,ergneq,' +
    'xvyylbhefrys,zbgures,pbpxfhpx,oybjwbo,unaqwbo,obare,crqbcu,encvfg,zbyrfg,onfgneq,qhzonff,wnpxnff,nffubyr,nefrubyr,' +
    'qvpxurnq,gjng,pyvg,frzra,fcrez,betnfz,jrgonpx,genaal,vaprfg,ahqr,anxrq,frkl,obbof,gvggvrf,gvggl,chffvrf,zvys,' +
    'uragnv,pbpnvar,fhvpvqr,frysunez,anmvf',
);

const WORD = decodeList(
  'nff,nefr,pbpx,qvpx,phag,phz,gvgf,obbo,encr,encrq,nany,nahf,frk,chffl,snt,ubr,ubzb,xlf,xxx,avt,cvff,qlxr,fcvp,pbba,' +
    'tbbx,puvax,xvxr,wnc,cnxv,arteb,zrgu,crqb,ubeal,jnax,urebva,anmv,xvyy,qvr,qrnq,ungr,fghcvq,vqvbg,ybfre,htyl',
);

/** Real words that contain an ANYWHERE root by accident (plain text: they're harmless). */
const ALLOW = new Set(['shiitake', 'shitake', 'therapist', 'therapists', 'scunthorpe', 'penistone', 'clitheroe', 'matsushita', 'snaked']);

/** Suffixes that turn a WORD root into a rude compound ("dickhead", "asshat"). */
const SUFFIXES = ['', 's', 'es', 'z', 'ing', 'head', 'face', 'hole', 'bag', 'wad', 'hat', 'sucker', 'lord'];

const LEET: Record<string, string> = {
  '0': 'o',
  '1': 'i',
  '!': 'i',
  '|': 'i',
  '3': 'e',
  '4': 'a',
  '@': 'a',
  '5': 's',
  $: 's',
  '7': 't',
  '+': 't',
  '8': 'b',
  '9': 'g',
};

/** Keeps the characters a pet name may use and trims it to NAME_MAX. */
export function cleanPetName(raw: string): string {
  return raw
    .normalize('NFC')
    .replace(/[​-‍⁠﻿]/g, '') // invisible characters people use to sneak words past filters
    .replace(/[^\p{L}\p{M}\p{N} '’-]/gu, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, NAME_MAX)
    .trim();
}

/** Lower-case, accent-free, leet-free words used only for matching (never shown). */
function tokens(raw: string): string[] {
  const base = raw
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[​-‍⁠﻿]/g, '');
  const unleet = Array.from(base, (ch) => LEET[ch] ?? ch)
    .join('')
    .replace(/ph/g, 'f');
  return unleet.split(/[^a-z]+/).filter(Boolean);
}

/** "fuuuck" -> "fuck", "aaass" -> "as". */
function squeeze(s: string): string {
  return s.replace(/(.)\1+/g, '$1');
}

function hitsAnywhere(word: string): boolean {
  if (ALLOW.has(word)) return false;
  const sq = squeeze(word);
  return ANYWHERE.some((root) => word.includes(root) || (squeeze(root) === root && sq.includes(root)));
}

function hitsWord(word: string): boolean {
  const sq = squeeze(word);
  const stretched = sq !== word;
  return WORD.some((root) =>
    SUFFIXES.some((suf) => {
      const target = root + suf;
      return word === target || (stretched && sq === squeeze(target));
    }),
  );
}

/** True when the name contains profanity, sexual words, slurs or mean words. */
export function isUnsafeName(raw: string): boolean {
  const words = tokens(raw);
  if (words.length === 0) return false;
  const candidates = [...words];
  // Spaced-out or dotted letters ("f u c k", "a.s.s") join back into one word.
  if (words.length > 1 && words.every((w) => w.length <= 2)) candidates.push(words.join(''));
  return candidates.some((w) => hitsAnywhere(w) || hitsWord(w));
}

/** Cleans and checks a name typed by the user. */
export function checkPetName(raw: string): NameCheck {
  const name = cleanPetName(raw);
  if (!name) return { ok: false, reason: 'empty', message: 'Your mochi needs a name. Any cozy word works!' };
  if (isUnsafeName(name) || isUnsafeName(raw)) return { ok: false, reason: 'unkind', message: UNSAFE_NAME_MESSAGE };
  return { ok: true, name };
}

/** A safe name to store or display, falling back when the input is empty or not okay (used for race codes). */
export function safePetName(raw: string, fallback = 'Dumpling'): string {
  const res = checkPetName(raw);
  return res.ok ? res.name : fallback;
}
