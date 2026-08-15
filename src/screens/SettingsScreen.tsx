import React, { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Switch, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { GhostButton, Type } from '../components/ui';
import { useApp } from '../context';
import { colors, fonts, radius } from '../theme';

export function SettingsScreen() {
  const insets = useSafeAreaInsets();
  const { d, rtl, lang, setLang, serverUrl, setServerUrl, serverOk, refreshServer, autoGallery, setAutoGallery } =
    useApp();
  const [draft, setDraft] = useState(serverUrl);

  return (
    <ScrollView
      style={styles.flex}
      contentContainerStyle={{ paddingTop: insets.top + 8, paddingBottom: 140, paddingHorizontal: 20 }}
    >
      <Type size={28} weight="extra" rtl={rtl}>
        {d.settings}
      </Type>

      <Type size={13} color={colors.muted} weight="semibold" rtl={rtl} style={styles.label}>
        {d.language}
      </Type>
      <View style={[styles.row, rtl && { flexDirection: 'row-reverse' }]}>
        <Pressable onPress={() => setLang('en')} style={[styles.chip, lang === 'en' && styles.chipOn]}>
          <Type size={14} weight="bold" color={lang === 'en' ? colors.bg : colors.cream}>
            {d.english}
          </Type>
        </Pressable>
        <Pressable onPress={() => setLang('ar')} style={[styles.chip, lang === 'ar' && styles.chipOn]}>
          <Type size={14} weight="bold" color={lang === 'ar' ? colors.bg : colors.cream}>
            {d.arabic}
          </Type>
        </Pressable>
      </View>

      <Type size={13} color={colors.muted} weight="semibold" rtl={rtl} style={styles.label}>
        {d.server}
      </Type>
      <Type size={13} color={colors.dim} rtl={rtl} style={{ marginBottom: 10 }}>
        {d.serverHint}
      </Type>
      <View style={[styles.status, serverOk ? styles.ok : styles.off]}>
        <Type size={13} weight="semibold" color={serverOk ? colors.success : colors.muted} rtl={rtl}>
          {serverOk ? d.serverOn : d.serverOff}
        </Type>
      </View>
      <TextInput
        value={draft}
        onChangeText={setDraft}
        onEndEditing={() => setServerUrl(draft.trim() || serverUrl)}
        autoCapitalize="none"
        autoCorrect={false}
        style={[styles.field, { textAlign: rtl ? 'right' : 'left' }]}
        placeholder={d.serverUrl}
        placeholderTextColor={colors.dim}
      />
      <View style={{ marginTop: 10 }}>
        <GhostButton
          label={d.checkServer}
          onPress={() => {
            setServerUrl(draft.trim() || serverUrl);
            refreshServer();
          }}
        />
      </View>

      <View style={[styles.toggle, rtl && { flexDirection: 'row-reverse' }]}>
        <View style={{ flex: 1 }}>
          <Type size={15} weight="bold" rtl={rtl}>
            {d.saveGalleryToggle}
          </Type>
          <Type size={12} color={colors.muted} rtl={rtl} style={{ marginTop: 4 }}>
            {d.saveGalleryHint}
          </Type>
        </View>
        <Switch
          value={autoGallery}
          onValueChange={setAutoGallery}
          trackColor={{ true: colors.goldDeep, false: colors.surface2 }}
          thumbColor={autoGallery ? colors.gold : colors.muted}
        />
      </View>

      <Type size={13} color={colors.muted} weight="semibold" rtl={rtl} style={styles.label}>
        {d.about}
      </Type>
      <Type size={14} color={colors.cream} rtl={rtl}>
        {d.aboutBody}
      </Type>
      <Type size={13} color={colors.dim} rtl={rtl} style={{ marginTop: 12 }}>
        {d.legal}
      </Type>
      <Type size={12} color={colors.dim} rtl={rtl} style={{ marginTop: 18 }}>
        {d.version}
      </Type>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  label: { marginTop: 26, marginBottom: 10 },
  row: { flexDirection: 'row', gap: 10 },
  chip: {
    paddingHorizontal: 16,
    height: 40,
    borderRadius: radius.pill,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
  },
  chipOn: { backgroundColor: colors.gold, borderColor: colors.gold },
  status: {
    padding: 12,
    borderRadius: radius.md,
    marginBottom: 10,
  },
  ok: { backgroundColor: 'rgba(61,220,151,0.1)' },
  off: { backgroundColor: colors.card },
  field: {
    height: 50,
    borderRadius: radius.md,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.line,
    color: colors.cream,
    paddingHorizontal: 14,
    fontFamily: fonts.medium,
  },
  toggle: {
    marginTop: 26,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 14,
    borderRadius: radius.lg,
    backgroundColor: colors.card,
    borderWidth: 1,
    borderColor: colors.line,
  },
});
