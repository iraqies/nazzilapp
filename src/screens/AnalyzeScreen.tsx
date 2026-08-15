import React, { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { GhostButton, GoldButton, Type } from '../components/ui';
import { useApp } from '../context';
import { probeMedia } from '../lib/api';
import { downloadWithProgress, saveToGallery, shareFile, shareLink } from '../lib/download';
import { formatDuration, formatSize, platformLabel } from '../lib/platforms';
import { colors, radius } from '../theme';
import type { LibraryItem, MediaFormat, ProbeResult } from '../types';

export function AnalyzeScreen({
  url,
  onBack,
  onPlay,
}: {
  url: string;
  onBack: () => void;
  onPlay: (item: LibraryItem) => void;
}) {
  const insets = useSafeAreaInsets();
  const { d, rtl, serverUrl, addItem, autoGallery } = useApp();
  const [media, setMedia] = useState<ProbeResult | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [formatId, setFormatId] = useState<string>('');
  const [busy, setBusy] = useState(false);
  const [progress, setProgress] = useState(0);
  const [phase, setPhase] = useState('');
  const [doneItem, setDoneItem] = useState<LibraryItem | null>(null);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const result = await probeMedia(url, serverUrl);
      setMedia(result);
      const preferred =
        result.formats.find((f) => !f.watermark && f.hasVideo) ||
        result.formats.find((f) => f.hasVideo) ||
        result.formats[0];
      setFormatId(preferred?.id || '');
    } catch (e) {
      setError(e instanceof Error ? e.message : d.fetchFail);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [url]);

  const selected = useMemo(
    () => media?.formats.find((f) => f.id === formatId) || media?.formats[0],
    [media, formatId],
  );

  const startDownload = async () => {
    if (!media || !selected) return;
    setBusy(true);
    setProgress(0.02);
    setPhase(d.downloading);
    try {
      const item = await downloadWithProgress(media, selected, serverUrl, setProgress);
      if (autoGallery) {
        setPhase(d.savingGallery);
        try {
          await saveToGallery(item.localUri);
        } catch {
          // permission denied is not fatal
        }
      }
      await addItem(item);
      setDoneItem(item);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch {
      setError(d.downloadFail);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    } finally {
      setBusy(false);
      setPhase('');
    }
  };

  return (
    <View style={[styles.flex, { paddingTop: insets.top }]}>
      <View style={[styles.nav, rtl && { flexDirection: 'row-reverse' }]}>
        <Pressable onPress={onBack} style={styles.back}>
          <Type size={15} color={colors.gold} weight="bold">
            {rtl ? '→' : '←'} {d.back}
          </Type>
        </Pressable>
      </View>

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={colors.gold} size="large" />
          <Type size={14} color={colors.muted} style={{ marginTop: 14 }}>
            {d.fetching}
          </Type>
        </View>
      ) : error && !media ? (
        <View style={styles.center}>
          <Type size={16} weight="bold" center rtl={rtl}>
            {d.fetchFail}
          </Type>
          <Type size={13} color={colors.muted} center rtl={rtl} style={{ marginTop: 8, paddingHorizontal: 28 }}>
            {error}
          </Type>
          <View style={{ width: 200, marginTop: 20 }}>
            <GoldButton label={d.retry} onPress={load} />
          </View>
        </View>
      ) : media ? (
        <ScrollView contentContainerStyle={{ paddingBottom: 40 }} showsVerticalScrollIndicator={false}>
          <View style={styles.coverWrap}>
            {media.thumbnail ? (
              <Image source={{ uri: media.thumbnail }} style={styles.cover} />
            ) : (
              <View style={[styles.cover, styles.coverEmpty]} />
            )}
            <View style={styles.coverShade} />
            <View style={styles.coverMeta}>
              <Type size={11} color={colors.gold} weight="bold">
                {platformLabel(media.platform).toUpperCase()}
                {media.source === 'client' ? ' · DIRECT' : ' · ENGINE'}
              </Type>
            </View>
          </View>

          <View style={styles.body}>
            <Type size={22} weight="extra" rtl={rtl}>
              {media.title}
            </Type>
            <Type size={13} color={colors.muted} rtl={rtl} style={{ marginTop: 8 }}>
              {[media.author, formatDuration(media.duration)].filter(Boolean).join('  ·  ')}
            </Type>

            <Type size={16} weight="bold" rtl={rtl} style={{ marginTop: 22, marginBottom: 10 }}>
              {d.quality}
            </Type>
            {media.formats.map((fmt) => (
              <FormatRow
                key={fmt.id}
                fmt={fmt}
                active={fmt.id === selected?.id}
                rtl={rtl}
                noWatermark={d.noWatermark}
                audioOnly={d.audioOnly}
                sizeUnknown={d.sizeUnknown}
                onPress={() => setFormatId(fmt.id)}
              />
            ))}

            {!!error && (
              <Type size={13} color={colors.crimson} rtl={rtl} style={{ marginTop: 10 }}>
                {error}
              </Type>
            )}

            <View style={{ marginTop: 18 }}>
              <GoldButton label={d.download} onPress={startDownload} loading={busy} />
            </View>
            <View style={{ marginTop: 10 }}>
              <GhostButton label={d.shareLink} onPress={() => shareLink(media.webpageUrl, media.title)} />
            </View>
          </View>
        </ScrollView>
      ) : null}

      <Modal visible={busy || !!doneItem} transparent animationType="fade">
        <View style={styles.modalBg}>
          <View style={styles.sheet}>
            {doneItem ? (
              <>
                <Type size={20} weight="extra" center>
                  {d.done}
                </Type>
                <Type size={13} color={colors.muted} center style={{ marginTop: 8 }}>
                  {d.afterDownload}
                </Type>
                <View style={{ marginTop: 18, gap: 10 }}>
                  <GoldButton
                    label={d.play}
                    onPress={() => {
                      const item = doneItem;
                      setDoneItem(null);
                      onPlay(item);
                    }}
                  />
                  <GhostButton
                    label={d.shareFile}
                    onPress={() => shareFile(doneItem.localUri, doneItem.title)}
                  />
                  <GhostButton
                    label={d.back}
                    onPress={() => {
                      setDoneItem(null);
                      onBack();
                    }}
                  />
                </View>
              </>
            ) : (
              <>
                <ActivityIndicator color={colors.gold} size="large" />
                <Type size={16} weight="bold" center style={{ marginTop: 16 }}>
                  {phase || d.downloading}
                </Type>
                <View style={styles.bar}>
                  <View style={[styles.barFill, { width: `${Math.round(progress * 100)}%` }]} />
                </View>
                <Type size={12} color={colors.muted} center>
                  {Math.round(progress * 100)}%
                </Type>
              </>
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

function FormatRow({
  fmt,
  active,
  onPress,
  rtl,
  noWatermark,
  audioOnly,
  sizeUnknown,
}: {
  fmt: MediaFormat;
  active: boolean;
  onPress: () => void;
  rtl?: boolean;
  noWatermark: string;
  audioOnly: string;
  sizeUnknown: string;
}) {
  const extra = !fmt.hasVideo ? audioOnly : fmt.watermark === false && fmt.label.toLowerCase().includes('watermark')
    ? noWatermark
    : !fmt.watermark && fmt.id.includes('download')
      ? noWatermark
      : '';
  return (
    <Pressable onPress={onPress} style={[styles.fmt, active && styles.fmtOn, rtl && { flexDirection: 'row-reverse' }]}>
      <View style={[styles.radio, active && styles.radioOn]} />
      <View style={{ flex: 1 }}>
        <Type size={15} weight="semibold" rtl={rtl}>
          {fmt.label}
        </Type>
        <Type size={12} color={colors.muted} rtl={rtl}>
          {[extra, formatSize(fmt.filesize) || sizeUnknown].filter(Boolean).join('  ·  ')}
        </Type>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.bg },
  nav: { paddingHorizontal: 16, paddingVertical: 8 },
  back: { paddingVertical: 8 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  coverWrap: { marginHorizontal: 20, borderRadius: radius.lg, overflow: 'hidden' },
  cover: { width: '100%', aspectRatio: 16 / 10, backgroundColor: colors.surface },
  coverEmpty: { backgroundColor: colors.surface2 },
  coverShade: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.15)',
  },
  coverMeta: { position: 'absolute', left: 12, bottom: 12 },
  body: { paddingHorizontal: 20, paddingTop: 16 },
  fmt: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 14,
    borderRadius: radius.md,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.line,
    marginBottom: 8,
  },
  fmtOn: {
    borderColor: colors.gold,
    backgroundColor: colors.goldSoft,
  },
  radio: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: colors.muted,
  },
  radioOn: {
    borderColor: colors.gold,
    backgroundColor: colors.gold,
  },
  modalBg: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.62)',
    justifyContent: 'flex-end',
  },
  sheet: {
    backgroundColor: colors.surface,
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    padding: 24,
    paddingBottom: 36,
  },
  bar: {
    height: 8,
    borderRadius: 8,
    backgroundColor: colors.bg,
    overflow: 'hidden',
    marginVertical: 16,
  },
  barFill: {
    height: '100%',
    backgroundColor: colors.gold,
  },
});
