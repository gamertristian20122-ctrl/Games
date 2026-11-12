import { Alert, Platform } from 'react-native';

/** A yes/no question that also works on web (where React Native's Alert has no buttons). */
export function confirmAction(
  title: string,
  message: string,
  confirmText: string,
  onConfirm: () => void,
  options: { cancelText?: string; destructive?: boolean } = {},
): void {
  if (Platform.OS === 'web') {
    if (globalThis.confirm?.(`${title}\n\n${message}`)) onConfirm();
    return;
  }
  Alert.alert(title, message, [
    { text: options.cancelText ?? 'Not now', style: 'cancel' },
    { text: confirmText, style: options.destructive ? 'destructive' : 'default', onPress: onConfirm },
  ]);
}

/** A simple notice that also works on web. */
export function notice(title: string, message: string): void {
  if (Platform.OS === 'web') {
    globalThis.alert?.(`${title}\n\n${message}`);
    return;
  }
  Alert.alert(title, message);
}
