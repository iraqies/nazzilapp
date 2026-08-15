import type { MediaFormat, ProbeResult } from '../types';
import {
  detectPlatform,
  extractTiktokId,
  extractYoutubeId,
} from './platforms';

function formatFromHeight(height?: number, ext = 'mp4', extra = ''): string {
  const q = height ? `${height}p` : 'Video';
  return extra ? `${q} ${ext.toUpperCase()} · ${extra}` : `${q} ${ext.toUpperCase()}`;
}

async function youtubePlayer(videoId: string): Promise<any> {
  const clients = [
    {
      context: {
        client: {
          clientName: 'ANDROID',
          clientVersion: '20.10.38',
          androidSdkVersion: 34,
          hl: 'en',
          gl: 'US',
        },
      },
      headers: {
        'User-Agent': 'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
        'X-YouTube-Client-Name': '3',
        'X-YouTube-Client-Version': '20.10.38',
      },
    },
    {
      context: {
        client: {
          clientName: 'IOS',
          clientVersion: '19.45.4',
          deviceMake: 'Apple',
          deviceModel: 'iPhone16,2',
          osName: 'iOS',
          osVersion: '18.1.0.22B83',
          hl: 'en',
          gl: 'US',
        },
      },
      headers: {
        'User-Agent': 'com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X)',
        'X-YouTube-Client-Name': '5',
        'X-YouTube-Client-Version': '19.45.4',
      },
    },
  ];

  let lastError: Error | null = null;
  for (const client of clients) {
    try {
      const res = await fetch('https://www.youtube.com/youtubei/v1/player?prettyPrint=false', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...client.headers,
        },
        body: JSON.stringify({
          context: client.context,
          videoId,
          contentCheckOk: true,
          racyCheckOk: true,
        }),
        signal: AbortSignal.timeout(15000),
      });
      if (!res.ok) {
        lastError = new Error(`YouTube player ${res.status}`);
        continue;
      }
      const data = await res.json();
      const status = data?.playabilityStatus?.status;
      if (status && status !== 'OK') {
        lastError = new Error(data?.playabilityStatus?.reason || 'Video is not playable');
        continue;
      }
      if (data?.streamingData) return data;
      lastError = new Error('No streams on this client');
    } catch (e) {
      lastError = e instanceof Error ? e : new Error('YouTube request failed');
    }
  }
  throw lastError || new Error('YouTube extraction failed');
}

function youtubeFormats(data: any): MediaFormat[] {
  const progressive = (data?.streamingData?.formats || []) as any[];
  const adaptive = (data?.streamingData?.adaptiveFormats || []) as any[];
  const out: MediaFormat[] = [];

  for (const f of progressive) {
    if (!f.url) continue;
    out.push({
      id: String(f.itag),
      label: formatFromHeight(f.height, f.mimeType?.includes('mp4') ? 'mp4' : 'webm'),
      ext: f.mimeType?.includes('webm') ? 'webm' : 'mp4',
      height: f.height,
      filesize: Number(f.contentLength) || undefined,
      hasAudio: true,
      hasVideo: true,
      watermark: false,
      url: f.url,
      needsMerge: false,
    });
  }

  const audio = adaptive
    .filter((f) => f.url && String(f.mimeType || '').startsWith('audio/'))
    .sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0))[0];

  if (audio?.url) {
    out.push({
      id: `audio-${audio.itag}`,
      label: 'Audio M4A',
      ext: 'm4a',
      filesize: Number(audio.contentLength) || undefined,
      hasAudio: true,
      hasVideo: false,
      watermark: false,
      url: audio.url,
      needsMerge: false,
    });
  }

  out.sort((a, b) => (b.height || 0) - (a.height || 0));
  return out;
}

async function probeYoutube(url: string): Promise<ProbeResult> {
  const id = extractYoutubeId(url);
  if (!id) throw new Error('Invalid YouTube link');
  const data = await youtubePlayer(id);
  const details = data.videoDetails || {};
  const thumbs = details.thumbnail?.thumbnails || [];
  const formats = youtubeFormats(data);
  if (!formats.length) throw new Error('No downloadable YouTube formats');
  return {
    id,
    title: details.title || 'YouTube video',
    author: details.author,
    thumbnail: thumbs[thumbs.length - 1]?.url,
    duration: Number(details.lengthSeconds) || undefined,
    platform: 'youtube',
    webpageUrl: `https://www.youtube.com/watch?v=${id}`,
    formats,
    source: 'client',
  };
}

async function resolveTiktokUrl(url: string): Promise<string> {
  if (/\/video\/\d+/.test(url)) return url;
  try {
    const res = await fetch(url, { method: 'GET', redirect: 'follow', signal: AbortSignal.timeout(12000) });
    return res.url || url;
  } catch {
    return url;
  }
}

async function probeTiktok(url: string): Promise<ProbeResult> {
  const resolved = await resolveTiktokUrl(url);
  const id = extractTiktokId(resolved);
  if (!id) throw new Error('Could not read this TikTok link');

  const deviceId = String(Math.floor(10_000_000_000_000_000 + Math.random() * 9_000_000_000_000_000));
  const api =
    `https://api16-normal-c-useast1a.tiktokv.com/aweme/v1/feed/?aweme_id=${id}` +
    `&version_code=262&app_name=musical_ly&channel=App%20Store&device_platform=iphone` +
    `&device_id=${deviceId}&os_version=16.0`;

  const res = await fetch(api, {
    headers: {
      'User-Agent': 'TikTok 26.2.0 rv:262018 (iPhone; iOS 16.0; en_US) Cronet',
    },
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error('TikTok lookup failed');
  const data = await res.json();
  const item = data?.aweme_list?.[0];
  if (!item) throw new Error('TikTok video not found');

  const video = item.video || {};
  const clean = video.download_addr?.url_list?.[0] || video.play_addr?.url_list?.[0];
  const watermarked = video.play_addr?.url_list?.[0];
  const cover =
    video.origin_cover?.url_list?.[0] ||
    video.cover?.url_list?.[0] ||
    video.dynamic_cover?.url_list?.[0];

  const formats: MediaFormat[] = [];
  if (clean) {
    formats.push({
      id: 'no-watermark',
      label: 'No watermark MP4',
      ext: 'mp4',
      height: video.height,
      hasAudio: true,
      hasVideo: true,
      watermark: false,
      url: clean,
      needsMerge: false,
    });
  }
  if (watermarked && watermarked !== clean) {
    formats.push({
      id: 'watermark',
      label: 'Standard MP4',
      ext: 'mp4',
      height: video.height,
      hasAudio: true,
      hasVideo: true,
      watermark: true,
      url: watermarked,
      needsMerge: false,
    });
  }
  if (!formats.length) throw new Error('No TikTok video URL');

  return {
    id,
    title: item.desc || 'TikTok video',
    author: item.author?.nickname,
    thumbnail: cover,
    duration: video.duration ? video.duration / 1000 : undefined,
    platform: 'tiktok',
    webpageUrl: resolved,
    formats,
    source: 'client',
  };
}

export async function probeClient(url: string): Promise<ProbeResult> {
  const platform = detectPlatform(url);
  if (platform === 'youtube') return probeYoutube(url);
  if (platform === 'tiktok') return probeTiktok(url);
  throw new Error('This platform needs the IraqiTube server');
}
