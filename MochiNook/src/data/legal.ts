/**
 * Privacy Policy and Terms of Use. This is the single source of truth: the in-app
 * Legal screen renders it, and `npm run legal` exports the same text to
 * docs/privacy-policy.html and docs/terms.html for the Google Play listing.
 */

export interface LegalSection {
  heading: string;
  paragraphs: string[];
}

export interface LegalDoc {
  title: string;
  updated: string;
  intro: string;
  sections: LegalSection[];
}

export const LEGAL_UPDATED = 'November 12, 2026';

export const PRIVACY_POLICY: LegalDoc = {
  title: 'MochiNook Privacy Policy',
  updated: LEGAL_UPDATED,
  intro:
    'The short version: everything you put into MochiNook stays on your phone. There are no accounts, no ads, no analytics, and nothing is sold or shared.',
  sections: [
    {
      heading: 'What stays on your phone',
      paragraphs: [
        'Your routine, quests, checkmarks, onboarding answers (like your brain profile, energy level, and daily times), daily mood check-ins, focus sessions, races, your pet, Pebbles, shop items, and settings are saved only in MochiNook’s private storage on your device.',
        'We never receive this information. It is removed when you use “Delete all my data” in Settings or uninstall the app.',
      ],
    },
    {
      heading: 'What leaves your phone',
      paragraphs: [
        'Purchases. If you buy MochiNook Plus or leave a tip, the payment is handled by Google Play. MochiNook uses RevenueCat to confirm purchases, which receives an anonymous app user ID, your purchase receipts, and basic device information (such as the operating system version). RevenueCat’s privacy policy is at revenuecat.com/privacy, and Google’s is at policies.google.com/privacy.',
        'Nothing else. MochiNook has no analytics, no advertising SDKs, no crash-reporting service, and no tracking.',
      ],
    },
    {
      heading: 'Notifications',
      paragraphs: [
        'Reminders are scheduled locally on your phone. There is no push-notification server, and you can turn reminders off any time in Settings.',
      ],
    },
    {
      heading: 'Share codes, race codes, and cheers',
      paragraphs: [
        'A share code contains your routine and, if you choose, your daily times. It is created on your phone and only goes wherever you decide to send it. We never see it.',
        'Friend race result codes contain only your pet’s name, your step count, the race length, and the date. Cheers are preset messages sent through your phone’s own share menu. Neither goes through any MochiNook server.',
      ],
    },
    {
      heading: 'Calm picks',
      paragraphs: [
        'The small card at the bottom of the home screen is static text built into the app. It contains no links, tracking, or ad network, and Plus hides it.',
      ],
    },
    {
      heading: 'Children and teens',
      paragraphs: [
        'MochiNook is designed to be safe for teens. It does not collect personal information from anyone, including children under 13. It has no chat, no accounts, and no way for strangers to contact you; anything shared with friends goes through apps you already use.',
      ],
    },
    {
      heading: 'Deleting your data',
      paragraphs: [
        'Open Settings → Delete all my data. This erases everything MochiNook saved on your phone and cancels its reminders. Uninstalling the app does the same.',
        'Deleting data does not cancel a subscription. You can cancel MochiNook Plus in the Google Play Store under Payments & subscriptions.',
      ],
    },
    {
      heading: 'Changes and contact',
      paragraphs: [
        'If this policy changes, the new version will appear in the app and on this page with a new date.',
        'Questions? Use the developer email shown on MochiNook’s Google Play page.',
      ],
    },
  ],
};

export const TERMS_OF_USE: LegalDoc = {
  title: 'MochiNook Terms of Use',
  updated: LEGAL_UPDATED,
  intro: 'By using MochiNook you agree to these simple terms.',
  sections: [
    {
      heading: 'A helper, not medical care',
      paragraphs: [
        'MochiNook is a friendly routine helper. It is not medical advice, diagnosis, or treatment for ADHD, autism, anxiety, or any other condition. If you are in crisis or feel unsafe, contact your local emergency number or a crisis line right away.',
      ],
    },
    {
      heading: 'MochiNook Plus',
      paragraphs: [
        'Plus is a subscription at the price shown in the app (in the United States, US$6.99 per month or US$34.99 per year; local prices may differ). New subscribers may get a 7-day free trial; if you cancel before the trial ends, you are not charged. After that it renews automatically through Google Play until you cancel. Cancel any time in the Google Play Store under Payments & subscriptions. Cancelling stops the next renewal; you keep Plus until the end of the period you paid for.',
      ],
    },
    {
      heading: 'Tips',
      paragraphs: [
        'Tips are optional one-time payments to support development. They do not unlock features. Refunds follow Google Play’s refund policy.',
      ],
    },
    {
      heading: 'Pebbles',
      paragraphs: ['Pebbles are earned only by completing steps. They have no money value and cannot be bought, sold, or exchanged.'],
    },
    {
      heading: 'Your content',
      paragraphs: [
        'Quests and routines you create belong to you and stay on your device. Please do not put anything into share codes that you would not want the receiver to see.',
      ],
    },
    {
      heading: 'The fine print',
      paragraphs: [
        'MochiNook is provided “as is”, without warranties. We may update the app and these terms; the latest version is always in the app.',
      ],
    },
  ],
};
