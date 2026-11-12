# MochiNook

A cozy virtual pet that works as an executive-function helper for ADHD, autistic, AuDHD and overwhelmed brains.
Tiny literal steps, gentle invitations, and no streaks or guilt.

- **Expo SDK 58** · TypeScript (strict) · Expo Router · `expo-dev-client` · New Architecture (always on in SDK 58)
- **Android** `com.mochinook.app` (minSdk 26) · **iOS** `com.mochinook.app` (iOS 17.0+)
- Everything is stored on the phone in SQLite. There are no accounts and no servers.

## Run it (development build)

Expo Go can't run this app because it uses native modules (RevenueCat, SQLite, notifications). Use a development build instead:

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
npm test            # 29 tests: quest library, share codes, Smart Match, and every SQLite query
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
  custom-quest.tsx    messy task -> tiny steps (Smart Match)
  pro.tsx, tip-jar.tsx, share.tsx
src/components/       Pet (SVG + Reanimated), Room backdrops, UI kit, icons
src/data/             quests.json (47 quests), sponsors.json, cosmetics
src/db/               SQLite schema/migrations + every query (repo.ts)
src/lib/              notifications, purchases, smart match, share codes, copy
src/theme/            color tokens (light, dark, calm light, calm dark), type scale
tests/                Node tests (run the real SQL against Node's built-in SQLite)
```

## Free vs Pro

| | Free | Pro ($5.99/month, the only plan) |
|---|---|---|
| Onboarding routine, 47 quests, reminders, pet growth | ✅ | ✅ |
| Breaking tasks down (Smart Match, offline) | ✅ | ✅ |
| Wardrobe & rooms | 2 colors, 1 hat, 1 room | Everything |
| Calm pick card (static, local text; labelled SPONSORED only for real paid placements) | Shown | Hidden |
| Pebbles (1 per step, +3 per quest) and the Pebble shop | ✅ | ✅ |

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
It (and free test purchases) only exist in development builds or builds without store keys. Once the RevenueCat keys are in `app.json`, they are switched off completely.

## On-device AI

Not in this version. The earlier `react-native-executorch` setup is in git history (commit `ac80948`) if you want to bring it back.

## Notifications (all local)

- Up to four gentle daily nudges, set from the user's times: wake-up, before school/work, after school/work, and wind-down.
- Step timers: checking off "Load the washer..." schedules the 45-minute "move it to the dryer" nudge, and unchecking it cancels the nudge.
- Calm Mode switches reminders to a silent channel.

## Credits

- Fonts: [Nunito](https://fonts.google.com/specimen/Nunito) and [Atkinson Hyperlegible](https://fonts.google.com/specimen/Atkinson+Hyperlegible), both SIL Open Font License 1.1 (free for commercial apps).
- The pet, rooms, icons, app icon and chime sounds are original and were made for this project.

## Launching on Google Play

The code side is ready. These steps need you (and a parent or guardian as the account owner):

1. **Google Play developer account** (owner must be 18+), then create the app with package `com.mochinook.app`.
2. **RevenueCat keys:** follow "Setting up real payments" above. Until the keys are in, the app shows a **TEST BUILD** banner in Settings and purchases are free test unlocks.
3. **Release build (AAB + your own key):** Play needs an Android App Bundle signed with your upload key. The easiest way is Expo's cloud build, which creates and safely stores the key for you:
   ```bash
   npx eas-cli@latest login
   npx eas-cli@latest build --platform android --profile production   # makes the .aab
   ```
   Turn on **Play App Signing** when you upload. Never lose the upload key: updates must be signed with the same one.
4. **Privacy policy URL:** run `npm run legal`, then host `docs/privacy-policy.html` publicly (for example with GitHub Pages) and paste its URL into Play Console. The same text is in the app under Settings → Privacy policy & terms.
5. **Data safety form** (matches what the app really does):
   - Data collected: **Purchase history** and **Device or other IDs** (RevenueCat's anonymous app user ID), used for app functionality (verifying purchases). Not shared with third parties for their own use. Encrypted in transit: yes.
   - Everything else (routines, onboarding answers, pet): **not collected**, because it never leaves the phone.
   - Users can delete their data in the app (Settings → Delete all my data).
6. **Ads declaration:** "No ads". The Calm pick cards are unpaid text built into the app.
7. **Target audience:** 13+ age groups. MochiNook has no chat or contact between users.
8. **Content rating questionnaire, store listing, screenshots, feature graphic** in Play Console.
