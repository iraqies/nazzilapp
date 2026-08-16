import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, StatusBar, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import * as Linking from 'expo-linking';
import { useFonts, PlusJakartaSans_500Medium, PlusJakartaSans_600SemiBold, PlusJakartaSans_700Bold, PlusJakartaSans_800ExtraBold } from '@expo-google-fonts/plus-jakarta-sans';
import { IBMPlexSansArabic_600SemiBold, IBMPlexSansArabic_700Bold } from '@expo-google-fonts/ibm-plex-sans-arabic';
import { AppProvider, useApp } from './src/context';
import { TabBar } from './src/components/ui';
import { HomeScreen } from './src/screens/HomeScreen';
import { AnalyzeScreen } from './src/screens/AnalyzeScreen';
import { LibraryScreen } from './src/screens/LibraryScreen';
import { PlayerScreen } from './src/screens/PlayerScreen';
import { SettingsScreen } from './src/screens/SettingsScreen';
import { isSupportedUrl } from './src/lib/platforms';
import { colors } from './src/theme';
import type { LibraryItem, Route, TabName } from './src/types';

function Shell() {
  const { ready, d } = useApp();
  const [route, setRoute] = useState<Route>({ name: 'tabs', tab: 'home' });

  const openUrl = useCallback((incoming: string | null) => {
    if (!incoming) return;
    let candidate = incoming;
    try {
      const parsed = Linking.parse(incoming);
      const q = parsed.queryParams || {};
      const shared = (q.url || q.text || q.body) as string | string[] | undefined;
      const value = Array.isArray(shared) ? shared[0] : shared;
      if (value) candidate = value;
    } catch {
      // keep raw
    }
    const match = candidate.match(/https?:\/\/\S+/);
    const url = match?.[0] || candidate;
    if (isSupportedUrl(url)) {
      setRoute({ name: 'analyze', url });
    }
  }, []);

  useEffect(() => {
    Linking.getInitialURL().then(openUrl);
    const sub = Linking.addEventListener('url', ({ url }) => openUrl(url));
    return () => sub.remove();
  }, [openUrl]);

  if (!ready) {
    return (
      <View style={styles.boot}>
        <ActivityIndicator color={colors.gold} />
      </View>
    );
  }

  if (route.name === 'analyze') {
    return (
      <AnalyzeScreen
        url={route.url}
        onBack={() => setRoute({ name: 'tabs', tab: 'home' })}
        onPlay={(item) => setRoute({ name: 'player', item })}
      />
    );
  }

  if (route.name === 'player') {
    return (
      <PlayerScreen
        item={route.item}
        onBack={() => setRoute({ name: 'tabs', tab: 'library' })}
      />
    );
  }

  const tab = route.tab;
  const openItem = (item: LibraryItem) => setRoute({ name: 'player', item });

  return (
    <View style={styles.flex}>
      <View style={styles.flex}>
        {tab === 'home' && (
          <HomeScreen
            onAnalyze={(url) => setRoute({ name: 'analyze', url })}
            onOpenItem={openItem}
            onSeeLibrary={() => setRoute({ name: 'tabs', tab: 'library' })}
          />
        )}
        {tab === 'library' && <LibraryScreen onOpen={openItem} />}
        {tab === 'settings' && <SettingsScreen />}
      </View>
      <TabBar
        tab={tab}
        onChange={(next: TabName) => setRoute({ name: 'tabs', tab: next })}
        labels={{ home: d.home, library: d.library, settings: d.settings }}
      />
    </View>
  );
}

export default function App() {
  const [fontsLoaded, fontError] = useFonts({
    PlusJakartaSans_500Medium,
    PlusJakartaSans_600SemiBold,
    PlusJakartaSans_700Bold,
    PlusJakartaSans_800ExtraBold,
    IBMPlexSansArabic_600SemiBold,
    IBMPlexSansArabic_700Bold,
  });
  const [fontWaitDone, setFontWaitDone] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => setFontWaitDone(true), 2500);
    return () => clearTimeout(timer);
  }, []);

  if (!fontsLoaded && !fontError && !fontWaitDone) {
    return (
      <View style={styles.boot}>
        <ActivityIndicator color={colors.gold} />
        <View style={{ height: 12 }} />
        <Text style={{ color: colors.muted, marginTop: 12 }}>IraqiTube</Text>
      </View>
    );
  }

  return (
    <SafeAreaProvider>
      <StatusBar barStyle="light-content" backgroundColor={colors.bg} />
      <AppProvider>
        <View style={styles.root}>
          <Shell />
        </View>
      </AppProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: colors.bg },
  flex: { flex: 1, backgroundColor: colors.bg },
  boot: {
    flex: 1,
    backgroundColor: colors.bg,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
