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
npm test            # 44 tests: quest library, share codes, Smart Match, and every SQLite query
npx expo-doctor     # dependency + config checks
```

## How the app is laid out

```
src/app/              screens (Expo Router)
  welcome.tsx         first launch: privacy promise, hatch + name, friction triage, Plus preview
  onboarding.tsx      "Fine-tune my routine": brain, energy and daily times
  overwhelmed.tsx     calming drawer: 4-4-6 breathing + Shrink my day
  (tabs)/home.tsx     pet card, "Today's single next step", spoons, today's plan, sponsor card
  (tabs)/quests.tsx   my routine + the 47-quest library
  (tabs)/week.tsx     weekly Mochi Sprint, seasonal rewards, check-in pattern, cheers
  (tabs)/nook.tsx     wardrobe & rooms (Plus items locked on Free), Pebble shop, Mystery Pouch
  focus.tsx, race.tsx body-double focus timer, 15-minute friend race (codes)
  (tabs)/settings.tsx sensory style, sounds, times, Plus, tip jar, share code, widget preview, dev toggle
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

## Free vs Plus

| | Free | Plus ($6.99/month or $34.99/year, 7-day free trial) |
|---|---|---|
| Onboarding routine, 47 quests, reminders, pet growth | ✅ | ✅ |
| Magic Break Down (one task → 3–5 tiny steps, offline) | ✅ | ✅ |
| Brain-Dump Splitter (messy list → many quests, offline) | — | ✅ |
| Overwhelmed drawer, Shrink my day, focus timer + brown noise / rain | ✅ | ✅ |
| Cozy Mystery Pouch (15 pebbles) | ✅ | ✅ |
| Wardrobe & rooms | 2 colors, 1 hat, 1 room | Everything |
| Calm pick card (static, local text; labelled SPONSORED only for real paid placements) | Shown | Hidden |
| Pebbles (1 per step, +3 per quest) and the Pebble shop | ✅ | ✅ |

Tips ($2.99 / $4.99 / $9.99) are one-time, unlock nothing, and are always optional.

## Setting up real payments (RevenueCat)

Until you add keys, the app runs in **store testing mode**: buying Plus or tipping shows a "nothing will be charged" test dialog.

1. Make products in the stores:
   - Subscriptions `mochinook_plus_monthly` ($6.99/month) and `mochinook_plus_annual` ($34.99/year), each with a 7-day free-trial offer
   - Consumable in-app products `mochinook_tip_small` ($2.99), `mochinook_tip_medium` ($4.99), `mochinook_tip_large` ($9.99)
2. In RevenueCat: add an entitlement called `pro`, attach both subscriptions to it, and put them in the **current offering** as the **Monthly** and **Annual** packages. The paywall shows "Start my 7-day free trial" automatically when the store reports a free trial.
   Set the tip products as consumables.
3. Paste your public SDK keys into `app.json` → `expo.extra.revenueCat.appleApiKey` / `googleApiKey`, then rebuild.

> App Store and Google Play developer accounts must be owned by an adult (18+). A parent or guardian can own the account and the payouts.

**Hidden developer toggle:** Settings → tap the version number 5 times → "Force Free / Force Plus / Real status".
It (and free test purchases) only exist in development builds or builds without store keys. Once the RevenueCat keys are in `app.json`, they are switched off completely.

## On-device AI

Not in this version. The earlier `react-native-executorch` setup is in git history (commit `ac80948`) if you want to bring it back.

## Motion & sensory style

Dumpling's animations run on the UI thread (Reanimated) and only use `transform` and `opacity`, anchored at the bottom center so squishes sit on the rug. Every animation is interruptible: a new tap replaces the running one instead of queueing.

| | Phone "Reduce motion" on | Calm | Dopamine |
|---|---|---|---|
| Breathing, blinks, ear twitches | off (still) | slow & small | full |
| Tap-to-squish, hops, pat lean, chewing | expressions only | gentle ease-out | springy overshoot |
| Hearts / sparkles / crumbs | none | 1–2 | up to 6 |
| Confetti on quests & level-ups | none | none | yes |
| Marimba chimes & haptics | per setting | off | on |

Tuning lives in `src/theme/motion.ts`; the chimes are synthesized WAVs in `assets/sounds/` (React Native has no Web Audio API).

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
3. **Release build (AAB + your own key):** Play needs an Android App Bundle signed with your upload key.
   Your key (`mochinook-upload.jks`) was made in a Claude session and handed to you; it is **never** stored in this repo.
   `plugins/withReleaseSigning.js` signs release builds with it when these are set:
   ```bash
   export ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_STORE_FILE=/path/to/mochinook-upload.jks
   export ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_KEY_ALIAS=mochinook-upload
   export ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_STORE_PASSWORD=...   # from your key instructions file
   export ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_KEY_PASSWORD=...
   npx expo prebuild --platform android
   cd android && ./gradlew bundleRelease   # -> app/build/outputs/bundle/release/app-release.aab
   ```
   Without them, release builds fall back to the shared debug key (fine for testing, not for Play).
   Turn on **Play App Signing** when you upload.
4. **Privacy policy URL:** run `npm run legal`, then host `docs/privacy-policy.html` publicly (for example with GitHub Pages) and paste its URL into Play Console. The same text is in the app under Settings → Privacy policy & terms.
5. **Data safety form** (matches what the app really does):
   - Data collected: **Purchase history** and **Device or other IDs** (RevenueCat's anonymous app user ID), used for app functionality (verifying purchases). Not shared with third parties for their own use. Encrypted in transit: yes.
   - Everything else (routines, onboarding answers, pet): **not collected**, because it never leaves the phone.
   - Users can delete their data in the app (Settings → Delete all my data).
6. **Ads declaration:** "No ads". The Calm pick cards are unpaid text built into the app.
7. **Target audience:** 13+ age groups. MochiNook has no chat or contact between users.
8. **Content rating questionnaire, store listing, screenshots, feature graphic** in Play Console.
