# MochiNook

A cozy virtual pet that works as an executive-function helper for ADHD, autistic, AuDHD and overwhelmed brains.
Tiny literal steps, gentle invitations, and no streaks or guilt.

- **Expo SDK 58** · TypeScript (strict) · Expo Router · `expo-dev-client` · New Architecture (always on in SDK 58)
- **Android** `com.mochinook.app` (minSdk 26) · **iOS** `com.mochinook.app` (iOS 17.0+)
- Everything is stored on the phone in SQLite. There are no accounts and no servers.

## Run it (development build)

Expo Go can't run this app because it uses native modules (on-device AI, RevenueCat, SQLite). Use a development build instead:

```bash
npm install
npx expo prebuild          # makes the ios/ and android/ folders
npx expo run:android       # or: npx expo run:ios   (needs a Mac)
```

You don't have a Mac or Android Studio? Build in the cloud:

```bash
npx eas-cli@latest build --profile development --platform android   # gives you an APK to install
npx expo start --dev-client
```

## Checks

```bash
npm run typecheck   # TypeScript, strict
npm run lint        # Expo ESLint config (incl. React Compiler rules)
npm test            # 23 tests: quest library, share codes, Smart Match, and every SQLite query
npx expo-doctor     # dependency + config checks
```

## How the app is laid out

```
src/app/              screens (Expo Router)
  onboarding.tsx      name the pet + 3-question quiz + reminder opt-in
  (tabs)/home.tsx     pet card, "Today's single next step", spoons, today's plan, sponsor card
  (tabs)/quests.tsx   my routine + the 47-quest library
  (tabs)/nook.tsx     wardrobe & rooms (Pro items locked on Free)
  (tabs)/settings.tsx Calm Mode, sounds, times, Pro, tip jar, share code, dev toggle
  quest/[id].tsx      check off steps, "Break into smaller steps"
  custom-quest.tsx    messy task -> tiny steps (on-device AI or Smart Match)
  pro.tsx, tip-jar.tsx, share.tsx, helper.tsx
src/components/       Pet (SVG + Reanimated), Room backdrops, UI kit, icons
src/data/             quests.json (47 quests), sponsors.json, cosmetics
src/db/               SQLite schema/migrations + every query (repo.ts)
src/lib/              notifications, purchases, llm, smart match, share codes, copy
src/theme/            color tokens (light, dark, calm light, calm dark), type scale
tests/                Node tests (run the real SQL against Node's built-in SQLite)
```

## Free vs Pro

| | Free | Pro ($5.99/month, the only plan) |
|---|---|---|
| Onboarding routine, 47 quests, reminders, pet growth | ✅ | ✅ |
| Breaking tasks down | Smart Match (offline, keyword-based) | Private on-device AI (phones with ≥ 4 GB RAM) |
| Wardrobe & rooms | 2 colors, 1 hat, 1 room | Everything |
| Calm Sponsor card | Shown (static, local, never a video or pop-up) | Hidden |

Tips ($2.99 / $4.99 / $9.99) are one-time, unlock nothing, and are always optional.

## Setting up real payments (RevenueCat)

Until you add keys, the app runs in **store testing mode**: buying Pro or tipping shows a "nothing will be charged" test dialog.

1. Make products in the stores:
   - Subscription `mochinook_pro_monthly` at $5.99/month
   - Consumable in-app products `mochinook_tip_small` ($2.99), `mochinook_tip_medium` ($4.99), `mochinook_tip_large` ($9.99)
2. In RevenueCat: add an entitlement called `pro`, attach the subscription to it, and put it in the **current offering** as the **Monthly** package.
   Set the tip products as consumables.
3. Paste your public SDK keys into `app.json` → `expo.extra.revenueCat.appleApiKey` / `googleApiKey`, then rebuild.

> App Store and Google Play developer accounts must be owned by an adult (18+). A parent or guardian can own the account and the payouts.

**Hidden developer toggle:** Settings → tap the version number 5 times → "Force Free / Force Pro / Real status".

## On-device AI (Pro)

- Uses `react-native-executorch` with the quantized **Qwen 2.5 0.5B** model from its built-in model list.
- Only offered when Pro is on **and** the phone reports about 4 GB of RAM or more (threshold 3.5 GiB, because "4 GB" phones report a little less).
  Other phones use Smart Match automatically.
- Downloaded only when the user taps **Download** (Settings → On-device helper), with a warning when not on Wi-Fi. Progress shows as "Teaching your pet new tricks...".
- The model is **loaded only while breaking down one task, then disposed right away** (`src/lib/llm.ts → withSession`). Anonymous download telemetry is turned off.

## Notifications (all local)

- Up to four gentle daily nudges, set from the user's times: wake-up, before school/work, after school/work, and wind-down.
- Step timers: checking off "Load the washer..." schedules the 45-minute "move it to the dryer" nudge, and unchecking it cancels the nudge.
- Calm Mode switches reminders to a silent channel.

## Credits

- Fonts: [Nunito](https://fonts.google.com/specimen/Nunito) and [Atkinson Hyperlegible](https://fonts.google.com/specimen/Atkinson+Hyperlegible), both SIL Open Font License 1.1 (free for commercial apps).
- The pet, rooms, icons, app icon and chime sounds are original and were made for this project.
