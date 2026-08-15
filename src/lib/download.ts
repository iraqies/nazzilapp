import { Platform } from 'react-native';
import * as FileSystem from 'expo-file-system/legacy';
import * as MediaLibrary from 'expo-media-library';
import * as Sharing from 'expo-sharing';
import { Share } from 'react-native';
import type { LibraryItem, MediaFormat, ProbeResult } from '../types';
import { sanitizeFilename } from './platforms';
import { streamUrl } from './api';

export type ProgressFn = (ratio: number) => void;

function downloadDir(): string {
  return FileSystem.documentDirectory || FileSystem.cacheDirectory || '';
}

export function resolveDownloadUrl(
  media: ProbeResult,
  format: MediaFormat,
  serverUrl: string,
): string {
  if (format.url && !format.needsMerge) return format.url;
  return streamUrl(serverUrl, media.webpageUrl, format.id);
}

export async function downloadToLibrary(
  media: ProbeResult,
  format: MediaFormat,
  serverUrl: string,
  onProgress?: ProgressFn,
): Promise<LibraryItem> {
  const source = resolveDownloadUrl(media, format, serverUrl);
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
    return {
      id: `${media.id}-${Date.now()}`,
      title: media.title,
      author: media.author,
      platform: media.platform,
      thumbnail: media.thumbnail,
      localUri: source,
      quality: format.label,
      ext,
      createdAt: Date.now(),
      duration: media.duration,
      sourceUrl: media.webpageUrl,
    };
  }

  const dest = `${downloadDir()}${filename}`;
  const result = await FileSystem.downloadAsync(source, dest, {
    sessionType: FileSystem.FileSystemSessionType.BACKGROUND,
  });

  if (result.status < 200 || result.status >= 300) {
    throw new Error(`Download HTTP ${result.status}`);
  }

  onProgress?.(1);

  return {
    id: `${media.id}-${Date.now()}`,
    title: media.title,
    author: media.author,
    platform: media.platform,
    thumbnail: media.thumbnail,
    localUri: result.uri,
    quality: format.label,
    ext,
    createdAt: Date.now(),
    duration: media.duration,
    sourceUrl: media.webpageUrl,
  };
}

export async function downloadWithProgress(
  media: ProbeResult,
  format: MediaFormat,
  serverUrl: string,
  onProgress?: ProgressFn,
): Promise<LibraryItem> {
  const source = resolveDownloadUrl(media, format, serverUrl);
  const ext = format.ext || 'mp4';
  const filename = `${sanitizeFilename(media.title)}-${Date.now()}.${ext}`;

  if (Platform.OS === 'web') {
    return downloadToLibrary(media, format, serverUrl, onProgress);
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

  const resumable = FileSystem.createDownloadResumable(source, dest, {}, callback);
  const result = await resumable.downloadAsync();
  if (!result || result.status < 200 || result.status >= 300) {
    throw new Error('Download failed');
  }
  onProgress?.(1);

  return {
    id: `${media.id}-${Date.now()}`,
    title: media.title,
    author: media.author,
    platform: media.platform,
    thumbnail: media.thumbnail,
    localUri: result.uri,
    quality: format.label,
    ext,
    createdAt: Date.now(),
    duration: media.duration,
    sourceUrl: media.webpageUrl,
  };
}

export async function saveToGallery(localUri: string): Promise<void> {
  if (Platform.OS === 'web') return;
  const perm = await MediaLibrary.requestPermissionsAsync();
  if (!perm.granted) throw new Error('permission');
  await MediaLibrary.createAssetAsync(localUri);
}

export async function shareFile(localUri: string, title?: string): Promise<void> {
  if (Platform.OS === 'web') {
    await Share.share({ message: localUri, title });
    return;
  }
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
