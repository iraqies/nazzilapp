export type PlatformId = 'youtube' | 'instagram' | 'tiktok' | 'facebook' | 'unknown';

export type MediaFormat = {
  id: string;
  label: string;
  ext: string;
  height?: number;
  filesize?: number;
  hasAudio: boolean;
  hasVideo: boolean;
  watermark: boolean;
  url?: string;
  needsMerge: boolean;
};

export type ProbeResult = {
  id: string;
  title: string;
  author?: string;
  thumbnail?: string;
  duration?: number;
  platform: PlatformId;
  webpageUrl: string;
  formats: MediaFormat[];
  source: 'server' | 'client';
};

export type LibraryItem = {
  id: string;
  title: string;
  author?: string;
  platform: PlatformId;
  thumbnail?: string;
  localUri: string;
  quality: string;
  ext: string;
  createdAt: number;
  duration?: number;
  sourceUrl: string;
};

export type Lang = 'en' | 'ar';

export type TabName = 'home' | 'library' | 'settings';

export type Route =
  | { name: 'tabs'; tab: TabName }
  | { name: 'analyze'; url: string }
  | { name: 'player'; item: LibraryItem };
