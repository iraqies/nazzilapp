import React from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useVideoPlayer, VideoView } from 'expo-video';
import { Type } from '../components/ui';
import { useApp } from '../context';
import { shareFile } from '../lib/download';
import { colors } from '../theme';
import type { LibraryItem } from '../types';

export function PlayerScreen({ item, onBack }: { item: LibraryItem; onBack: () => void }) {
  const insets = useSafeAreaInsets();
  const { d, rtl } = useApp();
  const player = useVideoPlayer(item.localUri, (p) => {
    p.loop = false;
    p.play();
  });

  return (
    <View style={[styles.flex, { paddingTop: insets.top }]}>
      <View style={[styles.nav, rtl && { flexDirection: 'row-reverse' }]}>
        <Pressable onPress={onBack}>
          <Type size={15} color={colors.gold} weight="bold">
            {rtl ? '→' : '←'} {d.back}
          </Type>
        </Pressable>
        <Pressable onPress={() => shareFile(item.localUri, item.title)}>
          <Type size={15} color={colors.cream} weight="bold">
            {d.shareFile}
          </Type>
        </Pressable>
      </View>
      <View style={styles.stage}>
        <VideoView player={player} style={styles.video} contentFit="contain" nativeControls />
      </View>
      <View style={{ padding: 20 }}>
        <Type size={18} weight="bold" rtl={rtl}>
          {item.title}
        </Type>
        <Type size={13} color={colors.muted} rtl={rtl} style={{ marginTop: 6 }}>
          {[item.author, item.quality].filter(Boolean).join('  ·  ')}
        </Type>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: colors.bg },
  nav: {
    paddingHorizontal: 16,
    paddingVertical: 10,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  stage: {
    width: '100%',
    aspectRatio: 16 / 10,
    backgroundColor: '#000',
  },
  video: { width: '100%', height: '100%' },
});
