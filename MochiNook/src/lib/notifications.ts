import * as Notifications from 'expo-notifications';
import { AndroidImportance } from 'expo-notifications';
import { Platform } from 'react-native';
import { notificationCopy } from './copy';
import type { Anchors } from './types';
import { wrapMinutes } from './time';

/** All notifications are local. Nothing is ever sent to a server. */

const CHANNEL_GENTLE = 'gentle';
const CHANNEL_QUIET = 'quiet';
const ANCHOR_IDS = ['anchor-morning', 'anchor-block-start', 'anchor-block-end', 'anchor-wind-down'] as const;

let quiet = false;

export function setQuietNotifications(value: boolean): void {
  quiet = value;
}

export function configureNotificationHandler(): void {
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: !quiet,
      shouldSetBadge: false,
    }),
  });
}

export async function ensureChannels(): Promise<void> {
  if (Platform.OS !== 'android') return;
  await Notifications.setNotificationChannelAsync(CHANNEL_GENTLE, {
    name: 'Gentle reminders',
    description: 'Soft, optional invitations from your pet.',
    importance: AndroidImportance.DEFAULT,
    vibrationPattern: [0, 120],
    enableVibrate: true,
  });
  await Notifications.setNotificationChannelAsync(CHANNEL_QUIET, {
    name: 'Calm Mode reminders',
    description: 'Silent reminders used while Calm Mode is on.',
    importance: AndroidImportance.LOW,
    sound: null,
    enableVibrate: false,
  });
}

function channel(): string {
  return quiet ? CHANNEL_QUIET : CHANNEL_GENTLE;
}

export async function hasPermission(): Promise<boolean> {
  const current = await Notifications.getPermissionsAsync();
  return current.granted;
}

export async function requestPermission(): Promise<boolean> {
  const current = await Notifications.getPermissionsAsync();
  if (current.granted) return true;
  if (!current.canAskAgain) return false;
  const next = await Notifications.requestPermissionsAsync({
    ios: { allowAlert: true, allowSound: true, allowBadge: false },
  });
  return next.granted;
}

async function scheduleDaily(identifier: string, minutes: number, content: { title: string; body: string }): Promise<void> {
  const m = wrapMinutes(minutes);
  await Notifications.scheduleNotificationAsync({
    identifier,
    content: { ...content, sound: quiet ? undefined : 'default', data: { kind: 'anchor' } },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DAILY,
      hour: Math.floor(m / 60),
      minute: m % 60,
      channelId: channel(),
    },
  });
}

export async function cancelAnchorReminders(): Promise<void> {
  await Promise.all(ANCHOR_IDS.map((id) => Notifications.cancelScheduledNotificationAsync(id).catch(() => undefined)));
}

/** (Re)schedules the four daily anchor invitations. Safe to call any time. */
export async function scheduleAnchorReminders(anchors: Anchors, petName: string): Promise<void> {
  await cancelAnchorReminders();
  if (!(await hasPermission())) return;
  await scheduleDaily('anchor-morning', anchors.wake + 5, notificationCopy.morning(petName));
  if (anchors.blockKind !== 'none') {
    await scheduleDaily('anchor-block-start', anchors.blockStart - 20, notificationCopy.blockStart(petName, anchors.blockKind));
    await scheduleDaily('anchor-block-end', anchors.blockEnd + 30, notificationCopy.blockEnd(petName));
  }
  await scheduleDaily('anchor-wind-down', anchors.bed - 45, notificationCopy.windDown(petName));
}

/** One-off nudge after a timed step (e.g. the 45-minute washer). Returns its id, or null. */
export async function scheduleStepTimer(minutes: number, petName: string, nextStep: string | null, questId: string): Promise<string | null> {
  if (minutes <= 0 || !(await hasPermission())) return null;
  return Notifications.scheduleNotificationAsync({
    content: { ...notificationCopy.timer(petName, nextStep), sound: quiet ? undefined : 'default', data: { kind: 'timer', questId } },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
      seconds: Math.round(minutes * 60),
      repeats: false,
      channelId: channel(),
    },
  });
}

export async function cancelNotification(id: string | null): Promise<void> {
  if (!id) return;
  await Notifications.cancelScheduledNotificationAsync(id).catch(() => undefined);
}

export async function cancelAllReminders(): Promise<void> {
  await Notifications.cancelAllScheduledNotificationsAsync().catch(() => undefined);
}

/** End-of-timer nudge for focus sprints and races, in case the app is in the background. */
export async function scheduleTimerEnd(minutes: number, title: string, body: string): Promise<string | null> {
  if (minutes <= 0 || !(await hasPermission())) return null;
  return Notifications.scheduleNotificationAsync({
    content: { title, body, sound: quiet ? undefined : 'default', data: { kind: 'timer-end' } },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
      seconds: Math.round(minutes * 60),
      repeats: false,
      channelId: channel(),
    },
  });
}
