import Constants from 'expo-constants';
import { Platform } from 'react-native';
import type { MediaFormat, ProbeResult } from '../types';
import { detectPlatform } from './platforms';
import { probeClient } from './clientExtract';

export function defaultServerUrl(): string {
  const hostUri =
    Constants.expoConfig?.hostUri ||
    (Constants as { linkingUri?: string }).linkingUri ||
    '';
  const host = String(hostUri)
    .replace(/^\w+:\/\//, '')
    .split(':')[0]
    .split('/')[0];

  if (host && host !== 'localhost' && host !== '127.0.0.1' && host !== 'exp.host') {
    return `http://${host}:8787`;
  }
  if (Platform.OS === 'android') {
    return 'http://10.0.2.2:8787';
  }
  return 'http://127.0.0.1:8787';
}

export async function checkServer(serverUrl: string): Promise<boolean> {
  try {
    const res = await fetch(`${serverUrl.replace(/\/$/, '')}/health`, {
      signal: AbortSignal.timeout(4000),
    });
    return res.ok;
  } catch {
    return false;
  }
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

export async function probeServer(url: string, serverUrl: string): Promise<ProbeResult> {
  const res = await fetch(`${serverUrl.replace(/\/$/, '')}/api/probe`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url }),
    signal: AbortSignal.timeout(45000),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ detail: 'Probe failed' }));
    throw new Error(err.detail || err.message || 'Probe failed');
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

export function streamUrl(serverUrl: string, pageUrl: string, formatId: string): string {
  const base = serverUrl.replace(/\/$/, '');
  return `${base}/api/stream?url=${encodeURIComponent(pageUrl)}&format_id=${encodeURIComponent(formatId)}`;
}

export async function probeMedia(url: string, serverUrl: string): Promise<ProbeResult> {
  const trimmed = url.trim();
  try {
    return await probeServer(trimmed, serverUrl);
  } catch (serverError) {
    try {
      return await probeClient(trimmed);
    } catch {
      throw serverError instanceof Error ? serverError : new Error('Could not read this link');
    }
  }
}
