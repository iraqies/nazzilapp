import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { Lang, LibraryItem } from './types';
import { t, type Dict } from './i18n';
import { loadAutoGallery, loadLang, loadLibrary, saveAutoGallery, saveLang, saveLibrary } from './lib/storage';

type AppCtx = {
  ready: boolean;
  lang: Lang;
  d: Dict;
  rtl: boolean;
  setLang: (lang: Lang) => void;
  library: LibraryItem[];
  addItem: (item: LibraryItem) => Promise<void>;
  removeItem: (id: string) => Promise<void>;
  autoGallery: boolean;
  setAutoGallery: (on: boolean) => void;
};

const Ctx = createContext<AppCtx | null>(null);

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);
  const [lang, setLangState] = useState<Lang>('en');
  const [library, setLibrary] = useState<LibraryItem[]>([]);
  const [autoGallery, setAutoGalleryState] = useState(true);

  useEffect(() => {
    (async () => {
      const [savedLang, items, gallery] = await Promise.all([loadLang(), loadLibrary(), loadAutoGallery()]);
      setLangState(savedLang);
      setLibrary(items);
      setAutoGalleryState(gallery);
      setReady(true);
    })();
  }, []);

  const setLang = useCallback((next: Lang) => {
    setLangState(next);
    saveLang(next);
  }, []);

  const addItem = useCallback(async (item: LibraryItem) => {
    setLibrary((prev) => {
      const next = [item, ...prev.filter((x) => x.id !== item.id)].slice(0, 200);
      saveLibrary(next);
      return next;
    });
  }, []);

  const removeItem = useCallback(async (id: string) => {
    setLibrary((prev) => {
      const next = prev.filter((x) => x.id !== id);
      saveLibrary(next);
      return next;
    });
  }, []);

  const setAutoGallery = useCallback((on: boolean) => {
    setAutoGalleryState(on);
    saveAutoGallery(on);
  }, []);

  const value = useMemo<AppCtx>(
    () => ({
      ready,
      lang,
      d: t(lang),
      rtl: lang === 'ar',
      setLang,
      library,
      addItem,
      removeItem,
      autoGallery,
      setAutoGallery,
    }),
    [ready, lang, setLang, library, addItem, removeItem, autoGallery, setAutoGallery],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useApp() {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useApp must be used inside AppProvider');
  return ctx;
}
