import { Platform, Share } from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import type { LibraryItem, MediaFormat, ProbeResult } from '../types';
import { sanitizeFilename } from './platforms';
import { streamUrl } from './api';

export type ProgressFn = (ratio: number) => void;

function downloadDir(): string {
  return FileSystem.documentDirectory || FileSystem.cacheDirectory || '';
}

export function resolveDownloadUrl(media: ProbeResult, format: MediaFormat): string {
  if (Platform.OS === 'web' || !format.url || format.needsMerge) {
    return streamUrl(media.webpageUrl, format.id);
  }
  return format.url;
}

function toItem(media: ProbeResult, format: MediaFormat, localUri: string): LibraryItem {
  return {
    id: `${media.id}-${Date.now()}`,
    title: media.title,
    author: media.author,
    platform: media.platform,
    thumbnail: media.thumbnail,
    localUri,
    quality: format.label,
    ext: format.ext || 'mp4',
    createdAt: Date.now(),
    duration: media.duration,
    sourceUrl: media.webpageUrl,
  };
}

export async function downloadWithProgress(
  media: ProbeResult,
  format: MediaFormat,
  onProgress?: ProgressFn,
): Promise<LibraryItem> {
  const source = resolveDownloadUrl(media, format);
  const ext = format.ext || 'mp4';
  const filename = `${sanitizeFilename(media.title)}-${Date.now()}.${ext}`;

  if (Platform.OS === 'web') {
    if (typeof window !== 'undefined') {
      const a = document.createElement('a');
      a.href = source;
      a.download = filename;
      a.target = '_blank';
      a.rel = 'noreferrer';
      document.body.appendChild(a);
      a.click();
      a.remove();
    }
    onProgress?.(1);
    return toItem(media, format, source);
  }

  const dest = `${downloadDir()}${filename}`;
  const callback: FileSystem.DownloadProgressCallback = ({
    totalBytesWritten,
    totalBytesExpectedToWrite,
  }) => {
    if (totalBytesExpectedToWrite > 0) {
      onProgress?.(totalBytesWritten / totalBytesExpectedToWrite);
    } else {
      onProgress?.(Math.min(0.95, totalBytesWritten / (12 * 1024 * 1024)));
    }
  };

  const resumable = FileSystem.createDownloadResumable(
    source,
    dest,
    { headers: format.headers },
    callback,
  );
  const result = await resumable.downloadAsync();
  if (!result || result.status < 200 || result.status >= 300) {
    throw new Error('Download failed');
  }
  onProgress?.(1);
  return toItem(media, format, result.uri);
}

export { saveToGallery } from './gallery';

export async function shareFile(localUri: string, title?: string): Promise<void> {
  if (Platform.OS === 'web') {
    await Share.share({ message: localUri, title });
    return;
  }
  const Sharing = await import('expo-sharing');
  const available = await Sharing.isAvailableAsync();
  if (available) {
    await Sharing.shareAsync(localUri, {
      dialogTitle: title || 'Share video',
      mimeType: localUri.endsWith('.m4a') || localUri.endsWith('.mp3') ? 'audio/*' : 'video/mp4',
    });
    return;
  }
  await Share.share({ url: localUri, title, message: title });
}

export async function shareLink(url: string, title?: string): Promise<void> {
  await Share.share({ message: title ? `${title}\n${url}` : url, url, title });
}

export async function deleteLocal(uri: string): Promise<void> {
  if (Platform.OS === 'web') return;
  if (!uri.startsWith('file:')) return;
  try {
    await FileSystem.deleteAsync(uri, { idempotent: true });
  } catch {
    // already gone
  }
}
