import { Platform } from 'react-native';
import Constants from 'expo-constants';
import type { MediaFormat, ProbeResult } from '../types';
import { detectPlatform } from './platforms';
import { probeClient } from './clientExtract';

export function engineUrl(): string {
  if (Platform.OS === 'web' && typeof window !== 'undefined' && window.location?.hostname) {
    const protocol = window.location.protocol === 'https:' ? 'https:' : 'http:';
    return `${protocol}//${window.location.hostname}:8787`;
  }
  const hostUri = Constants.expoConfig?.hostUri || '';
  const host = String(hostUri)
    .replace(/^\w+:\/\//, '')
    .split(':')[0]
    .split('/')[0];
  if (host && host !== 'localhost' && host !== '127.0.0.1') {
    return `http://${host}:8787`;
  }
  return 'http://127.0.0.1:8787';
}

export function streamUrl(pageUrl: string, formatId: string): string {
  return `${engineUrl()}/api/stream?url=${encodeURIComponent(pageUrl)}&format_id=${encodeURIComponent(formatId)}`;
}

type ServerProbe = {
  id: string;
  title: string;
  author?: string;
  thumbnail?: string;
  duration?: number;
  platform: ProbeResult['platform'];
  webpage_url: string;
  formats: MediaFormat[];
};

async function probeServer(url: string): Promise<ProbeResult> {
  const res = await fetch(`${engineUrl()}/api/probe`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url }),
    signal: AbortSignal.timeout(45000),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Could not load this video' }));
    throw new Error(err.detail || err.message || 'Could not load this video');
  }
  const data = (await res.json()) as ServerProbe;
  return {
    id: data.id,
    title: data.title,
    author: data.author,
    thumbnail: data.thumbnail,
    duration: data.duration,
    platform: data.platform || detectPlatform(url),
    webpageUrl: data.webpage_url || url,
    formats: data.formats || [],
    source: 'server',
  };
}

function friendlyError(error: unknown): Error {
  const raw = error instanceof Error ? error.message : '';
  if (/abort|timeout|network|failed to fetch|network request failed/i.test(raw)) {
    return new Error('Could not reach the download engine. Keep IraqiTube running on the computer.');
  }
  if (raw && !/public/i.test(raw)) return error instanceof Error ? error : new Error(raw);
  return new Error('Could not load this video. Tap Try again.');
}

export async function probeMedia(url: string): Promise<ProbeResult> {
  const trimmed = url.trim();
  try {
    return await probeServer(trimmed);
  } catch (serverError) {
    if (Platform.OS !== 'web') {
      try {
        return await probeClient(trimmed);
      } catch {
        throw friendlyError(serverError);
      }
    }
    throw friendlyError(serverError);
  }
}
