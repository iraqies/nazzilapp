import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Lang, LibraryItem } from '../types';

const LIBRARY_KEY = 'iraqitube.library.v1';
const LANG_KEY = 'iraqitube.lang';
const SERVER_KEY = 'iraqitube.server';
const GALLERY_KEY = 'iraqitube.gallery';

export async function loadLibrary(): Promise<LibraryItem[]> {
  const raw = await AsyncStorage.getItem(LIBRARY_KEY);
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw) as LibraryItem[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export async function saveLibrary(items: LibraryItem[]): Promise<void> {
  await AsyncStorage.setItem(LIBRARY_KEY, JSON.stringify(items));
}

export async function loadLang(): Promise<Lang> {
  const v = await AsyncStorage.getItem(LANG_KEY);
  return v === 'ar' ? 'ar' : 'en';
}

export async function saveLang(lang: Lang): Promise<void> {
  await AsyncStorage.setItem(LANG_KEY, lang);
}

export async function loadServerUrl(): Promise<string | null> {
  return AsyncStorage.getItem(SERVER_KEY);
}

export async function saveServerUrl(url: string): Promise<void> {
  await AsyncStorage.setItem(SERVER_KEY, url);
}

export async function loadAutoGallery(): Promise<boolean> {
  const v = await AsyncStorage.getItem(GALLERY_KEY);
  return v !== '0';
}

export async function saveAutoGallery(on: boolean): Promise<void> {
  await AsyncStorage.setItem(GALLERY_KEY, on ? '1' : '0');
}
