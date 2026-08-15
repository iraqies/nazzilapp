import React from 'react';
import {
  ActivityIndicator,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
  type StyleProp,
  type ViewStyle,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { colors, fonts, radius } from '../theme';
import type { LibraryItem, PlatformId } from '../types';
import { formatDuration, platformColor, platformLabel } from '../lib/platforms';

export function Face({ rtl, children }: { rtl: boolean; children: React.ReactNode }) {
  return <View style={{ writingDirection: rtl ? 'rtl' : 'ltr' }}>{children}</View>;
}

export function Type({
  children,
  size = 15,
  color = colors.cream,
  weight = 'medium',
  center,
  rtl,
  style,
  numberOfLines,
}: {
  children: React.ReactNode;
  size?: number;
  color?: string;
  weight?: 'medium' | 'semibold' | 'bold' | 'extra';
  center?: boolean;
  rtl?: boolean;
  style?: object;
  numberOfLines?: number;
}) {
  const font =
    rtl && (weight === 'bold' || weight === 'extra')
      ? fonts.arabicBold
      : rtl
        ? fonts.arabic
        : fonts[weight];
  return (
    <Text
      numberOfLines={numberOfLines}
      style={[
        {
          fontFamily: font,
          fontSize: size,
          color,
          textAlign: center ? 'center' : rtl ? 'right' : 'left',
        },
        style,
      ]}
    >
      {children}
    </Text>
  );
}

export function GoldButton({
  label,
  onPress,
  disabled,
  loading,
}: {
  label: string;
  onPress: () => void;
  disabled?: boolean;
  loading?: boolean;
}) {
  return (
    <Pressable onPress={onPress} disabled={disabled || loading} style={({ pressed }) => [pressed && { opacity: 0.88 }]}>
      <LinearGradient
        colors={disabled ? ['#5A5340', '#3F3A2E'] : [colors.gold, colors.goldDeep]}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.goldBtn}
      >
        {loading ? (
          <ActivityIndicator color={colors.bg} />
        ) : (
          <Text style={styles.goldBtnText}>{label}</Text>
        )}
      </LinearGradient>
    </Pressable>
  );
}

export function GhostButton({
  label,
  onPress,
  color = colors.cream,
}: {
  label: string;
  onPress: () => void;
  color?: string;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.ghostBtn, pressed && { opacity: 0.7 }]}>
      <Text style={[styles.ghostText, { color }]}>{label}</Text>
    </Pressable>
  );
}

export function PlatformTile({
  id,
  title,
  hint,
  onPress,
  rtl,
}: {
  id: PlatformId;
  title: string;
  hint: string;
  onPress: () => void;
  rtl?: boolean;
}) {
  const accent = platformColor(id);
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.tile, pressed && { transform: [{ scale: 0.98 }] }]}>
      <View style={[styles.tileDot, { backgroundColor: accent }]} />
      <Type size={16} weight="bold" rtl={rtl}>
        {title}
      </Type>
      <Type size={12} color={colors.muted} rtl={rtl}>
        {hint}
      </Type>
    </Pressable>
  );
}

export function LibraryCard({
  item,
  onPress,
  rtl,
}: {
  item: LibraryItem;
  onPress: () => void;
  rtl?: boolean;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.libCard, pressed && { opacity: 0.88 }]}>
      {item.thumbnail ? (
        <Image source={{ uri: item.thumbnail }} style={styles.thumb} />
      ) : (
        <View style={[styles.thumb, styles.thumbFallback]}>
          <Text style={{ color: colors.gold, fontSize: 22 }}>▶</Text>
        </View>
      )}
      <View style={styles.badge}>
        <Text style={styles.badgeText}>{platformLabel(item.platform)}</Text>
      </View>
      {!!item.duration && (
        <View style={styles.dur}>
          <Text style={styles.durText}>{formatDuration(item.duration)}</Text>
        </View>
      )}
      <Type size={13} weight="semibold" numberOfLines={2} rtl={rtl} style={{ marginTop: 8 }}>
        {item.title}
      </Type>
    </Pressable>
  );
}

export function SectionTitle({
  title,
  action,
  onAction,
  rtl,
}: {
  title: string;
  action?: string;
  onAction?: () => void;
  rtl?: boolean;
}) {
  return (
    <View style={[styles.sectionRow, rtl && { flexDirection: 'row-reverse' }]}>
      <Type size={18} weight="bold" rtl={rtl}>
        {title}
      </Type>
      {action ? (
        <Pressable onPress={onAction}>
          <Type size={13} color={colors.gold} weight="semibold" rtl={rtl}>
            {action}
          </Type>
        </Pressable>
      ) : null}
    </View>
  );
}

export function TabBar({
  tab,
  onChange,
  labels,
}: {
  tab: 'home' | 'library' | 'settings';
  onChange: (t: 'home' | 'library' | 'settings') => void;
  labels: { home: string; library: string; settings: string };
}) {
  const items = [
    { key: 'home' as const, icon: '⌂', label: labels.home },
    { key: 'library' as const, icon: '▣', label: labels.library },
    { key: 'settings' as const, icon: '⚙', label: labels.settings },
  ];
  return (
    <View style={styles.tabWrap}>
      <View style={styles.tabBar}>
        {items.map((it) => {
          const active = tab === it.key;
          return (
            <Pressable key={it.key} onPress={() => onChange(it.key)} style={styles.tabItem}>
              <Text style={[styles.tabIcon, active && { color: colors.gold }]}>{it.icon}</Text>
              <Text style={[styles.tabLabel, active && { color: colors.gold }]}>{it.label}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

export function ScreenPad({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.pad, style]}>{children}</View>;
}

const styles = StyleSheet.create({
  goldBtn: {
    height: 54,
    borderRadius: radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
  },
  goldBtnText: {
    fontFamily: fonts.extra,
    fontSize: 16,
    color: colors.bg,
    letterSpacing: 0.3,
  },
  ghostBtn: {
    height: 48,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.card,
  },
  ghostText: {
    fontFamily: fonts.semibold,
    fontSize: 14,
  },
  tile: {
    flex: 1,
    minHeight: 92,
    backgroundColor: colors.card,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.line,
    padding: 14,
    gap: 4,
  },
  tileDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginBottom: 6,
  },
  libCard: {
    width: '48%',
    marginBottom: 16,
  },
  thumb: {
    width: '100%',
    aspectRatio: 0.78,
    borderRadius: radius.md,
    backgroundColor: colors.surface,
  },
  thumbFallback: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  badge: {
    position: 'absolute',
    top: 8,
    left: 8,
    backgroundColor: 'rgba(0,0,0,0.62)',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: radius.pill,
  },
  badgeText: {
    color: colors.cream,
    fontSize: 10,
    fontFamily: fonts.semibold,
  },
  dur: {
    position: 'absolute',
    top: 8,
    right: 8,
    backgroundColor: 'rgba(0,0,0,0.62)',
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: radius.pill,
  },
  durText: {
    color: colors.cream,
    fontSize: 10,
    fontFamily: fonts.semibold,
  },
  sectionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  tabWrap: {
    paddingHorizontal: 18,
    paddingBottom: 10,
  },
  tabBar: {
    flexDirection: 'row',
    backgroundColor: '#121722',
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.line,
    paddingVertical: 8,
  },
  tabItem: {
    flex: 1,
    alignItems: 'center',
    gap: 2,
  },
  tabIcon: {
    color: colors.muted,
    fontSize: 16,
  },
  tabLabel: {
    color: colors.muted,
    fontSize: 11,
    fontFamily: fonts.semibold,
  },
  pad: {
    paddingHorizontal: 20,
  },
});
