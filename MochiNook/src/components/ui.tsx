import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  View,
  type StyleProp,
  type TextProps,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { SafeAreaView, type Edge } from 'react-native-safe-area-context';
import { formatClock, wrapMinutes } from '../lib/time';
import { useApp } from '../state/AppContext';
import { useTheme } from '../theme/ThemeContext';
import { radius, space, type as typeScale } from '../theme/tokens';
import { Glyph, type GlyphName } from './art/Glyph';
import { Icon, type IconName } from './Icon';

// ---------- text ----------

type Variant = keyof typeof typeScale;

export function T({
  variant = 'body',
  color,
  style,
  ...rest
}: TextProps & { variant?: Variant; color?: string; style?: StyleProp<TextStyle> }) {
  const { c } = useTheme();
  const base = typeScale[variant];
  const tint = color ?? (variant === 'small' || variant === 'label' ? c.inkSoft : c.ink);
  return <Text maxFontSizeMultiplier={1.6} {...rest} style={[base, { color: tint }, style]} />;
}

// ---------- layout ----------

export function Screen({
  children,
  scroll = true,
  edges = ['top'],
  contentStyle,
  footer,
}: {
  children: React.ReactNode;
  scroll?: boolean;
  edges?: Edge[];
  contentStyle?: StyleProp<ViewStyle>;
  footer?: React.ReactNode;
}) {
  const { c } = useTheme();
  return (
    <SafeAreaView edges={edges} style={{ flex: 1, backgroundColor: c.bg }}>
      {scroll ? (
        <ScrollView
          contentContainerStyle={[styles.screenContent, contentStyle]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {children}
        </ScrollView>
      ) : (
        <View style={[styles.screenContent, { flex: 1 }, contentStyle]}>{children}</View>
      )}
      {footer}
    </SafeAreaView>
  );
}

export function Card({
  children,
  style,
  tone = 'surface',
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  tone?: 'surface' | 'accent' | 'peach' | 'lavender' | 'butter';
}) {
  const { c, calm } = useTheme();
  const bg =
    tone === 'accent' ? c.accentSoft : tone === 'peach' ? c.peachSoft : tone === 'lavender' ? c.lavenderSoft : tone === 'butter' ? c.butterSoft : c.surface;
  return (
    <View
      style={[
        styles.card,
        { backgroundColor: bg, borderColor: c.border, shadowColor: c.shadow, shadowOpacity: calm ? 0 : 1 },
        style,
      ]}
    >
      {children}
    </View>
  );
}

export function Row({ children, style, gap = space.md }: { children: React.ReactNode; style?: StyleProp<ViewStyle>; gap?: number }) {
  return <View style={[{ flexDirection: 'row', alignItems: 'center', gap }, style]}>{children}</View>;
}

export function Spacer({ size = space.lg }: { size?: number }) {
  return <View style={{ height: size }} />;
}

export function SectionTitle({ children, right }: { children: React.ReactNode; right?: React.ReactNode }) {
  return (
    <Row style={{ justifyContent: 'space-between', marginTop: space.xl, marginBottom: space.md }}>
      <T variant="heading" accessibilityRole="header">
        {children}
      </T>
      {right}
    </Row>
  );
}

// ---------- buttons ----------

type ButtonKind = 'primary' | 'soft' | 'ghost' | 'peach' | 'lavender';

export function Button({
  label,
  onPress,
  kind = 'primary',
  icon,
  disabled,
  style,
  small,
  accessibilityHint,
}: {
  label: string;
  onPress: () => void;
  kind?: ButtonKind;
  icon?: IconName;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
  small?: boolean;
  accessibilityHint?: string;
}) {
  const { c } = useTheme();
  const { tap } = useApp();
  const bg =
    kind === 'primary' ? c.accent : kind === 'soft' ? c.surfaceAlt : kind === 'peach' ? c.peach : kind === 'lavender' ? c.lavender : 'transparent';
  const fg = kind === 'ghost' ? c.accentInk : kind === 'primary' ? c.onAccent : c.ink;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: !!disabled }}
      disabled={disabled}
      onPress={() => {
        tap();
        onPress();
      }}
      style={({ pressed }) => [
        styles.button,
        small && styles.buttonSmall,
        { backgroundColor: bg, opacity: disabled ? 0.45 : pressed ? 0.85 : 1, transform: [{ scale: pressed ? 0.98 : 1 }] },
        kind === 'ghost' && { paddingHorizontal: space.sm },
        style,
      ]}
    >
      {icon ? <Icon name={icon} size={small ? 18 : 20} color={fg} /> : null}
      <Text style={[small ? typeScale.small : typeScale.bodyBold, { color: fg, fontFamily: typeScale.bodyBold.fontFamily }]} maxFontSizeMultiplier={1.4}>
        {label}
      </Text>
    </Pressable>
  );
}

export function IconButton({
  icon,
  label,
  onPress,
  tone = 'soft',
  size = 44,
}: {
  icon: IconName;
  label: string;
  onPress: () => void;
  tone?: 'soft' | 'accent' | 'clear';
  size?: number;
}) {
  const { c } = useTheme();
  const { tap } = useApp();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={label}
      hitSlop={8}
      onPress={() => {
        tap();
        onPress();
      }}
      style={({ pressed }) => ({
        width: size,
        height: size,
        borderRadius: size / 2,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: tone === 'accent' ? c.accent : tone === 'soft' ? c.surfaceAlt : 'transparent',
        opacity: pressed ? 0.75 : 1,
      })}
    >
      <Icon name={icon} size={size * 0.48} color={tone === 'accent' ? c.onAccent : c.ink} />
    </Pressable>
  );
}

export function Chip<T extends string>({
  label,
  value,
  selected,
  onSelect,
  sublabel,
  art,
  multi = false,
}: {
  label: string;
  value: T;
  selected: boolean;
  onSelect: (v: T) => void;
  sublabel?: string;
  /** Small illustration shown on the left (a Glyph, spoons, …). */
  art?: React.ReactNode;
  /** Checkbox look and behaviour (pick several) instead of a radio button. */
  multi?: boolean;
}) {
  const { c } = useTheme();
  const { tap } = useApp();
  return (
    <Pressable
      accessibilityRole={multi ? 'checkbox' : 'radio'}
      accessibilityState={multi ? { checked: selected } : { selected }}
      accessibilityLabel={sublabel ? `${label}. ${sublabel}` : label}
      onPress={() => {
        tap();
        onSelect(value);
      }}
      style={({ pressed }) => [
        styles.chip,
        {
          backgroundColor: selected ? c.accentSoft : c.surface,
          borderColor: selected ? c.accent : c.border,
          opacity: pressed ? 0.85 : 1,
        },
      ]}
    >
      <Row gap={space.md}>
        {art ? <View style={{ width: 50, alignItems: 'center' }}>{art}</View> : null}
        <View style={{ flex: 1 }}>
          <T variant="bodyBold">{label}</T>
          {sublabel ? <T variant="small">{sublabel}</T> : null}
        </View>
        <View style={[styles.radio, multi && { borderRadius: 8 }, { borderColor: selected ? c.accentInk : c.border, backgroundColor: selected ? c.accent : 'transparent' }]}>
          {selected ? <Icon name="check" size={16} color={c.onAccent} strokeWidth={2.6} /> : null}
        </View>
      </Row>
    </Pressable>
  );
}

/** Two-or-more option segmented control (like a soft pill switch). */
export function Segmented<V extends string>({
  options,
  value,
  onChange,
}: {
  options: readonly { value: V; label: string }[];
  value: V;
  onChange: (v: V) => void;
}) {
  const { c } = useTheme();
  const { tap } = useApp();
  return (
    <View accessibilityRole="tablist" style={[styles.segTrack, { backgroundColor: c.surfaceAlt, borderColor: c.border }]}>
      {options.map((o) => {
        const selected = o.value === value;
        return (
          <Pressable
            key={o.value}
            accessibilityRole="tab"
            accessibilityState={{ selected }}
            accessibilityLabel={o.label}
            onPress={() => {
              tap();
              onChange(o.value);
            }}
            style={[styles.segItem, selected && { backgroundColor: c.surface, shadowColor: c.shadow, shadowOpacity: 1, shadowRadius: 6, shadowOffset: { width: 0, height: 2 } }]}
          >
            <T variant="small" color={selected ? c.ink : c.inkSoft} style={{ fontFamily: typeScale.bodyBold.fontFamily, textAlign: 'center' }}>
              {o.label}
            </T>
          </Pressable>
        );
      })}
    </View>
  );
}

export function Pill({ label, selected, onPress, icon }: { label: string; selected: boolean; onPress: () => void; icon?: GlyphName }) {
  const { c } = useTheme();
  const { tap } = useApp();
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      accessibilityLabel={label}
      onPress={() => {
        tap();
        onPress();
      }}
      style={[styles.pill, { backgroundColor: selected ? c.accent : c.surfaceAlt, borderColor: selected ? c.accent : c.border }, icon ? { flexDirection: 'row', alignItems: 'center', gap: 6 } : null]}
    >
      {icon ? <Glyph name={icon} size={20} /> : null}
      <T variant="small" color={selected ? c.onAccent : c.ink} style={{ fontFamily: typeScale.bodyBold.fontFamily }}>
        {label}
      </T>
    </Pressable>
  );
}

// ---------- feedback ----------

export function ProgressBar({ value, height = 10, color }: { value: number; height?: number; color?: string }) {
  const { c } = useTheme();
  const pct = Math.max(0, Math.min(1, value));
  return (
    <View
      accessibilityRole="progressbar"
      accessibilityValue={{ min: 0, max: 100, now: Math.round(pct * 100) }}
      style={{ height, borderRadius: height, backgroundColor: c.surfaceAlt, overflow: 'hidden' }}
    >
      <View style={{ width: `${pct * 100}%`, height: '100%', borderRadius: height, backgroundColor: color ?? c.accent }} />
    </View>
  );
}

export function ToggleRow({
  label,
  hint,
  value,
  onChange,
}: {
  label: string;
  hint?: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  const { c } = useTheme();
  return (
    <Row style={{ paddingVertical: space.md }}>
      <View style={{ flex: 1 }}>
        <T variant="bodyBold">{label}</T>
        {hint ? <T variant="small">{hint}</T> : null}
      </View>
      <Switch
        accessibilityLabel={label}
        value={value}
        onValueChange={onChange}
        trackColor={{ false: c.border, true: c.accent }}
        thumbColor={c.surface}
        ios_backgroundColor={c.border}
      />
    </Row>
  );
}

export function LinkRow({ label, hint, icon, onPress }: { label: string; hint?: string; icon: IconName; onPress: () => void }) {
  const { c } = useTheme();
  const { tap } = useApp();
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={hint ? `${label}. ${hint}` : label}
      onPress={() => {
        tap();
        onPress();
      }}
      style={({ pressed }) => ({ opacity: pressed ? 0.7 : 1, paddingVertical: space.md })}
    >
      <Row>
        <View style={[styles.linkIcon, { backgroundColor: c.surfaceAlt }]}>
          <Icon name={icon} size={20} color={c.ink} />
        </View>
        <View style={{ flex: 1 }}>
          <T variant="bodyBold">{label}</T>
          {hint ? <T variant="small">{hint}</T> : null}
        </View>
        <Icon name="chevronRight" size={20} color={c.inkSoft} />
      </Row>
    </Pressable>
  );
}

export function Divider() {
  const { c } = useTheme();
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.border }} />;
}

/** Big, thumb-friendly time picker: no tiny wheels, 15-minute steps. */
export function TimeStepper({ label, minutes, onChange }: { label: string; minutes: number; onChange: (m: number) => void }) {
  const { c } = useTheme();
  return (
    <Row style={{ paddingVertical: space.sm }}>
      <T variant="bodyBold" style={{ flex: 1 }}>
        {label}
      </T>
      <IconButton icon="minus" label={`${label} 15 minutes earlier`} size={40} onPress={() => onChange(wrapMinutes(minutes - 15))} />
      <View
        style={[styles.timeBox, { backgroundColor: c.surfaceAlt }]}
        accessible
        accessibilityLabel={`${label}: ${formatClock(minutes)}`}
      >
        <T variant="bodyBold">{formatClock(minutes)}</T>
      </View>
      <IconButton icon="plus" label={`${label} 15 minutes later`} size={40} onPress={() => onChange(wrapMinutes(minutes + 15))} />
    </Row>
  );
}

export const styles = StyleSheet.create({
  screenContent: { paddingHorizontal: space.xl - 4, paddingBottom: space.xxxl },
  card: {
    borderRadius: radius.lg,
    borderWidth: 1,
    padding: space.lg + 2,
    shadowOffset: { width: 0, height: 6 },
    shadowRadius: 18,
    elevation: 0,
  },
  button: {
    minHeight: 54,
    borderRadius: radius.pill,
    paddingHorizontal: space.xl,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: space.sm,
  },
  buttonSmall: { minHeight: 44, paddingHorizontal: space.lg },
  chip: { borderWidth: 1.5, borderRadius: radius.md, padding: space.lg },
  radio: { width: 26, height: 26, borderRadius: 13, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
  segTrack: { flexDirection: 'row', borderRadius: radius.pill, borderWidth: 1, padding: 4, gap: 4 },
  segItem: { flex: 1, minHeight: 42, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', paddingHorizontal: space.sm },
  pill: { borderRadius: radius.pill, borderWidth: 1, paddingHorizontal: space.lg, paddingVertical: space.sm + 2, minHeight: 44, justifyContent: 'center' },
  linkIcon: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center' },
  timeBox: { minWidth: 104, paddingVertical: space.sm, borderRadius: radius.sm, alignItems: 'center' },
});
