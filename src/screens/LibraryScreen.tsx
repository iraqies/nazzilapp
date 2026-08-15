import React, { useState } from 'react';
import { Alert, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { LibraryCard, Type } from '../components/ui';
import { useApp } from '../context';
import { deleteLocal, shareFile } from '../lib/download';
import { colors, radius } from '../theme';
import type { LibraryItem } from '../types';

export function LibraryScreen({ onOpen }: { onOpen: (item: LibraryItem) => void }) {
  const insets = useSafeAreaInsets();
  const { d, rtl, library, removeItem } = useApp();
  const [picked, setPicked] = useState<LibraryItem | null>(null);

  const remove = async (item: LibraryItem) => {
    await deleteLocal(item.localUri);
    await removeItem(item.id);
    setPicked(null);
  };

  const confirmRemove = (item: LibraryItem) => {
    Alert.alert(d.delete, item.title, [
      { text: d.cancel, style: 'cancel' },
      { text: d.delete, style: 'destructive', onPress: () => remove(item) },
    ]);
  };

  return (
    <View style={[styles.flex, { paddingTop: insets.top + 8 }]}>
      <View style={styles.head}>
        <Type size={28} weight="extra" rtl={rtl}>
          {d.library}
        </Type>
        <Type size={13} color={colors.muted} rtl={rtl} style={{ marginTop: 4 }}>
          {library.length}
        </Type>
      </View>
      <ScrollView contentContainerStyle={styles.grid} showsVerticalScrollIndicator={false}>
        {library.length === 0 ? (
          <View style={styles.empty}>
            <Type size={18} weight="bold" center rtl={rtl}>
              {d.emptyLibrary}
            </Type>
            <Type size={13} color={colors.muted} center rtl={rtl} style={{ marginTop: 8 }}>
              {d.emptyLibraryHint}
            </Type>
          </View>
        ) : (
          library.map((item) => (
            <LibraryCard
              key={item.id}
              item={item}
              rtl={rtl}
              onPress={() => setPicked(item)}
            />
          ))
        )}
      </ScrollView>

      {picked ? (
        <View style={styles.sheet}>
          <Type size={16} weight="bold" numberOfLines={2} rtl={rtl}>
            {picked.title}
          </Type>
          <Type size={12} color={colors.muted} rtl={rtl} style={{ marginTop: 4 }}>
            {picked.quality}
          </Type>
          <View style={[styles.actions, rtl && { flexDirection: 'row-reverse' }]}>
            <Pressable
              style={styles.act}
              onPress={() => {
                const item = picked;
                setPicked(null);
                onOpen(item);
              }}
            >
              <Type size={13} weight="bold" color={colors.gold}>
                {d.play}
              </Type>
            </Pressable>
            <Pressable style={styles.act} onPress={() => shareFile(picked.localUri, picked.title)}>
              <Type size={13} weight="bold" color={colors.cream}>
                {d.shareFile}
              </Type>
            </Pressable>
            <Pressable style={styles.act} onPress={() => confirmRemove(picked)}>
              <Type size={13} weight="bold" color={colors.crimson}>
                {d.delete}
              </Type>
            </Pressable>
          </View>
          <Pressable onPress={() => setPicked(null)} style={{ alignItems: 'center', marginTop: 8 }}>
            <Type size={13} color={colors.muted}>
              {d.cancel}
            </Type>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  head: { paddingHorizontal: 20, marginBottom: 12 },
  grid: {
    paddingHorizontal: 20,
    paddingBottom: 160,
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  empty: { width: '100%', paddingTop: 80, paddingHorizontal: 20 },
  sheet: {
    position: 'absolute',
    left: 12,
    right: 12,
    bottom: 92,
    backgroundColor: colors.surface,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: colors.line,
    padding: 16,
  },
  actions: { flexDirection: 'row', gap: 8, marginTop: 14 },
  act: {
    flex: 1,
    height: 42,
    borderRadius: radius.pill,
    backgroundColor: colors.card,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
