import React, { useCallback, useEffect, useState } from 'react';
import {
  Keyboard,
  Pressable,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { LinearGradient } from 'expo-linear-gradient';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { GoldButton, LibraryCard, PlatformTile, SectionTitle, Type } from '../components/ui';
import { useApp } from '../context';
import { isSupportedUrl } from '../lib/platforms';
import { colors, fonts, radius } from '../theme';
import type { LibraryItem, PlatformId } from '../types';

const EXAMPLES: Record<PlatformId, string> = {
  youtube: 'https://www.youtube.com/shorts/',
  instagram: 'https://www.instagram.com/reel/',
  tiktok: 'https://www.tiktok.com/',
  facebook: 'https://www.facebook.com/reel/',
  unknown: '',
};

export function HomeScreen({
  onAnalyze,
  onOpenItem,
  onSeeLibrary,
}: {
  onAnalyze: (url: string) => void;
  onOpenItem: (item: LibraryItem) => void;
  onSeeLibrary: () => void;
}) {
  const { d, rtl, library } = useApp();
  const insets = useSafeAreaInsets();
  const [url, setUrl] = useState('');
  const [clip, setClip] = useState<string | null>(null);
  const [error, setError] = useState('');

  const scanClipboard = useCallback(async () => {
    try {
      const value = (await Clipboard.getStringAsync()).trim();
      if (value && isSupportedUrl(value)) setClip(value);
    } catch {
      // clipboard unavailable
    }
  }, []);

  useEffect(() => {
    scanClipboard();
  }, [scanClipboard]);

  const submit = (value = url) => {
    const next = value.trim();
    if (!next) {
      setError(d.invalidUrl);
      return;
    }
    if (!isSupportedUrl(next)) {
      setError(d.unknownPlatform);
      return;
    }
    setError('');
    Keyboard.dismiss();
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onAnalyze(next);
  };

  const paste = async () => {
    const value = (await Clipboard.getStringAsync()).trim();
    if (value) {
      setUrl(value);
      setError('');
      if (isSupportedUrl(value)) submit(value);
    }
  };

  return (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={{ paddingTop: insets.top + 8, paddingBottom: 120 }}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.heroWrap}>
        <LinearGradient
          colors={['rgba(228,184,74,0.18)', 'rgba(226,61,74,0.08)', 'transparent']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.heroGlow}
        />
        <View style={[styles.topRow, rtl && { flexDirection: 'row-reverse' }]}>
          <View style={styles.mark}>
            <Type size={13} weight="extra" color={colors.bg} center>
              IT
            </Type>
          </View>
          <View style={[styles.live, styles.liveOn]}>
            <View style={[styles.liveDot, { backgroundColor: colors.success }]} />
            <Type size={11} color={colors.success} weight="semibold">
              {d.engineReady}
            </Type>
          </View>
        </View>

        <Type size={12} color={colors.gold} weight="semibold" center style={{ letterSpacing: 1.6, marginTop: 22 }}>
          {d.eyebrow}
        </Type>
        <Type size={40} weight="extra" center rtl={rtl} style={{ marginTop: 8 }}>
          {d.appName}
        </Type>
        <Type size={15} color={colors.muted} center rtl={rtl} style={{ marginTop: 8, paddingHorizontal: 28 }}>
          {d.tagline}
        </Type>
      </View>

      <View style={styles.pad}>
        <View style={styles.inputCard}>
          <TextInput
            value={url}
            onChangeText={(v) => {
              setUrl(v);
              setError('');
            }}
            placeholder={d.pastePlaceholder}
            placeholderTextColor={colors.dim}
            autoCapitalize="none"
            autoCorrect={false}
            keyboardType="url"
            returnKeyType="go"
            onSubmitEditing={() => submit()}
            style={[styles.input, { textAlign: rtl ? 'right' : 'left' }]}
          />
          <View style={[styles.inputActions, rtl && { flexDirection: 'row-reverse' }]}>
            <Pressable onPress={paste} style={styles.mini}>
              <Type size={13} color={colors.gold} weight="bold">
                {d.paste}
              </Type>
            </Pressable>
            {url ? (
              <Pressable onPress={() => setUrl('')} style={styles.mini}>
                <Type size={13} color={colors.muted} weight="semibold">
                  {d.clear}
                </Type>
              </Pressable>
            ) : null}
          </View>
        </View>
        {!!error && (
          <Type size={13} color={colors.crimson} rtl={rtl} style={{ marginTop: 8 }}>
            {error}
          </Type>
        )}
        <View style={{ marginTop: 14 }}>
          <GoldButton label={d.go} onPress={() => submit()} />
        </View>

        {clip && clip !== url ? (
          <Pressable
            onPress={() => {
              setUrl(clip);
              submit(clip);
            }}
            style={styles.clipCard}
          >
            <Type size={12} color={colors.gold} weight="semibold" rtl={rtl}>
              {d.clipboardFound}
            </Type>
            <Type size={13} color={colors.cream} numberOfLines={1} rtl={rtl} style={{ marginTop: 4 }}>
              {clip}
            </Type>
            <Type size={12} color={colors.gold} weight="bold" rtl={rtl} style={{ marginTop: 6 }}>
              {d.useLink}
            </Type>
          </Pressable>
        ) : null}

        <View style={styles.tip}>
          <Type size={13} color={colors.muted} rtl={rtl}>
            {d.shareToMe}
          </Type>
        </View>

        <SectionTitle title={d.platforms} rtl={rtl} />
        <View style={styles.grid}>
          <PlatformTile id="youtube" title={d.youtube} hint={d.youtubeHint} rtl={rtl} onPress={() => setUrl(EXAMPLES.youtube)} />
          <PlatformTile id="instagram" title={d.instagram} hint={d.instagramHint} rtl={rtl} onPress={() => setUrl(EXAMPLES.instagram)} />
        </View>
        <View style={[styles.grid, { marginTop: 10 }]}>
          <PlatformTile id="tiktok" title={d.tiktok} hint={d.tiktokHint} rtl={rtl} onPress={() => setUrl(EXAMPLES.tiktok)} />
          <PlatformTile id="facebook" title={d.facebook} hint={d.facebookHint} rtl={rtl} onPress={() => setUrl(EXAMPLES.facebook)} />
        </View>

        <View style={styles.how}>
          <Type size={16} weight="bold" rtl={rtl}>
            {d.howTitle}
          </Type>
          {[d.step1, d.step2, d.step3].map((step, i) => (
            <View key={step} style={[styles.step, rtl && { flexDirection: 'row-reverse' }]}>
              <View style={styles.stepNum}>
                <Type size={12} weight="extra" color={colors.bg} center>
                  {i + 1}
                </Type>
              </View>
              <Type size={13} color={colors.muted} rtl={rtl} style={{ flex: 1 }}>
                {step}
              </Type>
            </View>
          ))}
        </View>

        <SectionTitle title={d.recent} action={library.length ? d.seeAll : undefined} onAction={onSeeLibrary} rtl={rtl} />
        {library.length === 0 ? (
          <Type size={13} color={colors.dim} rtl={rtl}>
            {d.emptyRecent}
          </Type>
        ) : (
          <View style={styles.recentRow}>
            {library.slice(0, 4).map((item) => (
              <LibraryCard key={item.id} item={item} onPress={() => onOpenItem(item)} rtl={rtl} />
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  heroWrap: { paddingHorizontal: 20, marginBottom: 18 },
  heroGlow: {
    position: 'absolute',
    left: -40,
    right: -40,
    top: -20,
    height: 220,
    borderRadius: 220,
  },
  topRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  mark: {
    width: 36,
    height: 36,
    borderRadius: 12,
    backgroundColor: colors.gold,
    alignItems: 'center',
    justifyContent: 'center',
  },
  live: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: radius.pill,
    maxWidth: '72%',
  },
  liveOn: { backgroundColor: 'rgba(61,220,151,0.1)' },
  liveOff: { backgroundColor: colors.card },
  liveDot: { width: 7, height: 7, borderRadius: 4 },
  pad: { paddingHorizontal: 20 },
  inputCard: {
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: 'rgba(228,184,74,0.28)',
    paddingHorizontal: 14,
    paddingTop: 12,
    paddingBottom: 8,
  },
  input: {
    minHeight: 52,
    color: colors.cream,
    fontFamily: fonts.medium,
    fontSize: 15,
  },
  inputActions: { flexDirection: 'row', gap: 8, paddingBottom: 6 },
  mini: { paddingVertical: 6, paddingHorizontal: 4 },
  clipCard: {
    marginTop: 14,
    padding: 14,
    borderRadius: radius.md,
    backgroundColor: colors.goldSoft,
    borderWidth: 1,
    borderColor: 'rgba(228,184,74,0.25)',
  },
  tip: {
    marginTop: 16,
    marginBottom: 22,
    padding: 14,
    borderRadius: radius.md,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.line,
  },
  grid: { flexDirection: 'row', gap: 10 },
  how: {
    marginTop: 22,
    marginBottom: 26,
    padding: 16,
    borderRadius: radius.lg,
    backgroundColor: colors.surface,
    gap: 12,
  },
  step: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  stepNum: {
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: colors.gold,
    alignItems: 'center',
    justifyContent: 'center',
  },
  recentRow: { flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between' },
});
