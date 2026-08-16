import type { PlatformId } from '../types';

const YT =
  /(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?.*?v=|shorts\/|embed\/|live\/|clip\/)|youtu\.be\/)/i;
const IG = /(?:https?:\/\/)?(?:www\.|m\.)?(?:instagram\.com|l\.instagram\.com)\//i;
const TT =
  /(?:https?:\/\/)?(?:www\.|vm\.|vt\.|m\.)?tiktok\.com\//i;
const FB =
  /(?:https?:\/\/)?(?:www\.|m\.|web\.)?(?:facebook\.com|fb\.watch|fb\.com)\//i;

export function detectPlatform(url: string): PlatformId {
  const u = url.trim();
  if (YT.test(u)) return 'youtube';
  if (IG.test(u)) return 'instagram';
  if (TT.test(u)) return 'tiktok';
  if (FB.test(u)) return 'facebook';
  return 'unknown';
}

export function isSupportedUrl(value: string): boolean {
  return detectPlatform(value) !== 'unknown';
}

export function extractYoutubeId(url: string): string | null {
  const patterns = [
    /(?:v=|\/shorts\/|\/embed\/|\/live\/|youtu\.be\/)([A-Za-z0-9_-]{11})/,
  ];
  for (const p of patterns) {
    const m = url.match(p);
    if (m?.[1]) return m[1];
  }
  return null;
}

export function extractTiktokId(url: string): string | null {
  const m = url.match(/\/video\/(\d+)/);
  if (m?.[1]) return m[1];
  const photo = url.match(/\/photo\/(\d+)/);
  return photo?.[1] ?? null;
}

export function extractInstagramCode(url: string): string | null {
  const m = url.match(/instagram\.com\/(?:reel|reels|p|tv)\/([A-Za-z0-9_-]+)/i);
  return m?.[1] ?? null;
}

export function extractFacebookId(url: string): string | null {
  const patterns = [/\/reel\/(\d+)/i, /\/videos\/(\d+)/i, /[?&]v=(\d+)/, /\/watch\/(\d+)/];
  for (const p of patterns) {
    const m = url.match(p);
    if (m?.[1]) return m[1];
  }
  return null;
}

export function shortcodeToMediaId(shortcode: string): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
  let n = 0n;
  for (const char of shortcode) {
    const i = alphabet.indexOf(char);
    if (i < 0) continue;
    n = n * 64n + BigInt(i);
  }
  return n.toString();
}

export function formatDuration(seconds?: number): string {
  if (!seconds || seconds <= 0) return '';
  const s = Math.round(seconds);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = s % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
  return `${m}:${String(r).padStart(2, '0')}`;
}

export function formatSize(bytes?: number): string {
  if (!bytes || bytes <= 0) return '';
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

export function platformLabel(id: PlatformId): string {
  switch (id) {
    case 'youtube':
      return 'YouTube';
    case 'instagram':
      return 'Instagram';
    case 'tiktok':
      return 'TikTok';
    case 'facebook':
      return 'Facebook';
    default:
      return 'Video';
  }
}

export function platformColor(id: PlatformId): string {
  switch (id) {
    case 'youtube':
      return '#FF3B30';
    case 'instagram':
      return '#E1306C';
    case 'tiktok':
      return '#25F4EE';
    case 'facebook':
      return '#1877F2';
    default:
      return '#E4B84A';
  }
}

export function sanitizeFilename(name: string): string {
  return name.replace(/[<>:"/\\|?*\u0000-\u001F]/g, '').trim().slice(0, 80) || 'iraqi-tube';
}
