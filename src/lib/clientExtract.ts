import type { MediaFormat, ProbeResult } from '../types';
import {
  detectPlatform,
  extractFacebookId,
  extractInstagramCode,
  extractTiktokId,
  extractYoutubeId,
  shortcodeToMediaId,
} from './platforms';

const DESKTOP_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const MOBILE_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
const IG_APP_ID = '936619743392459';

function decodeEscaped(value: string): string {
  return value
    .replace(/\\u0026/g, '&')
    .replace(/\\u003d/g, '=')
    .replace(/\\u003c/g, '<')
    .replace(/\\u003e/g, '>')
    .replace(/\\\//g, '/')
    .replace(/\\"/g, '"')
    .replace(/\\&/g, '&');
}

function firstGroup(text: string, patterns: RegExp[]): string | null {
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match?.[1]) return decodeEscaped(match[1]);
  }
  return null;
}

function unique(urls: Array<string | null | undefined>): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const url of urls) {
    if (!url || !url.startsWith('http')) continue;
    const clean = decodeEscaped(url);
    if (seen.has(clean)) continue;
    seen.add(clean);
    out.push(clean);
  }
  return out;
}

async function fetchPage(
  url: string,
  headers: Record<string, string> = {},
): Promise<{ url: string; text: string; json?: any }> {
  const res = await fetch(url, {
    headers: {
      'User-Agent': MOBILE_UA,
      Accept: 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,ar;q=0.8',
      ...headers,
    },
    redirect: 'follow',
    signal: AbortSignal.timeout(20000),
  });
  const text = await res.text();
  let json: any;
  try {
    json = JSON.parse(text);
  } catch {
    json = undefined;
  }
  return { url: res.url || url, text, json };
}

function og(text: string, prop: string): string | null {
  return firstGroup(text, [
    new RegExp(`property=["']og:${prop}["'][^>]*content=["']([^"']+)`, 'i'),
    new RegExp(`content=["']([^"']+)["'][^>]*property=["']og:${prop}["']`, 'i'),
  ]);
}

function formatFromHeight(height?: number, ext = 'mp4', extra = ''): string {
  const quality = height ? `${height}p` : 'Video';
  return extra ? `${quality} ${ext.toUpperCase()} · ${extra}` : `${quality} ${ext.toUpperCase()}`;
}

function withHeaders(referer: string, extra?: Record<string, string>): Record<string, string> {
  return {
    'User-Agent': DESKTOP_UA,
    Referer: referer,
    Origin: new URL(referer).origin,
    ...extra,
  };
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
    {
      context: {
        client: {
          clientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          clientVersion: '2.0',
          hl: 'en',
          gl: 'US',
        },
      },
      headers: {
        'User-Agent': DESKTOP_UA,
        'X-YouTube-Client-Name': '85',
        'X-YouTube-Client-Version': '2.0',
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
    } catch (error) {
      lastError = error instanceof Error ? error : new Error('YouTube request failed');
    }
  }
  throw lastError || new Error('YouTube extraction failed');
}

function youtubeFormats(data: any, pageUrl: string): MediaFormat[] {
  const progressive = (data?.streamingData?.formats || []) as any[];
  const adaptive = (data?.streamingData?.adaptiveFormats || []) as any[];
  const out: MediaFormat[] = [];
  const headers = withHeaders('https://www.youtube.com/');

  for (const format of progressive) {
    if (!format.url) continue;
    out.push({
      id: String(format.itag),
      label: formatFromHeight(format.height, String(format.mimeType || '').includes('mp4') ? 'mp4' : 'webm'),
      ext: String(format.mimeType || '').includes('webm') ? 'webm' : 'mp4',
      height: format.height,
      filesize: Number(format.contentLength) || undefined,
      hasAudio: true,
      hasVideo: true,
      watermark: false,
      url: format.url,
      needsMerge: false,
      headers,
    });
  }

  const audio = adaptive
    .filter((format) => format.url && String(format.mimeType || '').startsWith('audio/'))
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
      headers,
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
  const webpageUrl = `https://www.youtube.com/watch?v=${id}`;
  const formats = youtubeFormats(data, webpageUrl);
  if (!formats.length) throw new Error('No downloadable YouTube formats');
  return {
    id,
    title: details.title || 'YouTube video',
    author: details.author,
    thumbnail: thumbs[thumbs.length - 1]?.url,
    duration: Number(details.lengthSeconds) || undefined,
    platform: 'youtube',
    webpageUrl,
    formats,
    source: 'client',
  };
}

async function resolveFinalUrl(url: string): Promise<string> {
  try {
    const page = await fetchPage(url, { 'User-Agent': MOBILE_UA });
    return page.url || url;
  } catch {
    return url;
  }
}

function tiktokFromHtml(html: string): { clean?: string; play?: string; title?: string; author?: string; cover?: string; duration?: number } {
  const uni = html.match(/id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>([^<]+)</);
  if (uni?.[1]) {
    try {
      const json = JSON.parse(uni[1]);
      const item = json?.__DEFAULT_SCOPE__?.['webapp.video-detail']?.itemInfo?.itemStruct;
      if (item?.video) {
        return {
          clean: item.video.downloadAddr || item.video.download_addr,
          play: item.video.playAddr || item.video.play_addr,
          title: item.desc,
          author: item.author?.nickname,
          cover: item.video.cover || item.video.originCover,
          duration: item.video.duration,
        };
      }
    } catch {
      // keep looking
    }
  }
  return {
    clean: firstGroup(html, [/"downloadAddr"\s*:\s*"([^"]+)"/, /"download_addr"\s*:\s*"([^"]+)"/]),
    play: firstGroup(html, [/"playAddr"\s*:\s*"([^"]+)"/, /"play_addr"\s*:\s*"([^"]+)"/]),
    title: og(html, 'title') || firstGroup(html, [/"desc"\s*:\s*"([^"]+)"/]),
    author: firstGroup(html, [/"nickname"\s*:\s*"([^"]+)"/]),
    cover: og(html, 'image'),
  };
}

async function probeTiktok(url: string): Promise<ProbeResult> {
  const resolved = await resolveFinalUrl(url);
  const id = extractTiktokId(resolved);
  const headers = withHeaders('https://www.tiktok.com/');
  const formats: MediaFormat[] = [];
  let title = 'TikTok video';
  let author: string | undefined;
  let cover: string | undefined;
  let duration: number | undefined;

  if (id) {
    const hosts = [
      'api16-normal-c-useast1a.tiktokv.com',
      'api16-normal-c-useast2a.tiktokv.com',
      'api19-normal-c-useast1a.tiktokv.com',
    ];
    for (const host of hosts) {
      try {
        const deviceId = String(Math.floor(10_000_000_000_000_000 + Math.random() * 9_000_000_000_000_000));
        const api =
          `https://${host}/aweme/v1/feed/?aweme_id=${id}` +
          `&version_code=262&app_name=musical_ly&channel=App%20Store&device_platform=iphone` +
          `&device_id=${deviceId}&os_version=16.0`;
        const res = await fetch(api, {
          headers: { 'User-Agent': 'TikTok 26.2.0 rv:262018 (iPhone; iOS 16.0; en_US) Cronet' },
          signal: AbortSignal.timeout(12000),
        });
        if (!res.ok) continue;
        const data = await res.json();
        const item = data?.aweme_list?.[0];
        if (!item?.video) continue;
        const video = item.video;
        const clean = video.download_addr?.url_list?.[0];
        const play = video.play_addr?.url_list?.[0];
        title = item.desc || title;
        author = item.author?.nickname;
        cover = video.origin_cover?.url_list?.[0] || video.cover?.url_list?.[0];
        duration = video.duration ? video.duration / 1000 : undefined;
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
            headers,
          });
        }
        if (play && play !== clean) {
          formats.push({
            id: 'watermark',
            label: 'Standard MP4',
            ext: 'mp4',
            height: video.height,
            hasAudio: true,
            hasVideo: true,
            watermark: true,
            url: play,
            needsMerge: false,
            headers,
          });
        }
        if (formats.length) break;
      } catch {
        // try next host
      }
    }
  }

  if (!formats.length) {
    const page = await fetchPage(resolved, { 'User-Agent': DESKTOP_UA });
    const parsed = tiktokFromHtml(page.text);
    title = parsed.title || title;
    author = parsed.author || author;
    cover = parsed.cover || cover;
    duration = parsed.duration || duration;
    const clean = parsed.clean;
    const play = parsed.play;
    if (clean) {
      formats.push({
        id: 'no-watermark',
        label: 'No watermark MP4',
        ext: 'mp4',
        hasAudio: true,
        hasVideo: true,
        watermark: false,
        url: clean,
        needsMerge: false,
        headers,
      });
    }
    if (play && play !== clean) {
      formats.push({
        id: 'watermark',
        label: 'Standard MP4',
        ext: 'mp4',
        hasAudio: true,
        hasVideo: true,
        watermark: true,
        url: play,
        needsMerge: false,
        headers,
      });
    }
  }

  if (!formats.length) throw new Error('Could not read this TikTok video. Make sure it is public.');
  return {
    id: id || `tiktok-${Date.now()}`,
    title,
    author,
    thumbnail: cover,
    duration,
    platform: 'tiktok',
    webpageUrl: resolved,
    formats,
    source: 'client',
  };
}

function videoFormatsFromUrls(
  urls: string[],
  referer: string,
  extras?: { watermark?: boolean; label?: string },
): MediaFormat[] {
  return unique(urls).map((url, index) => ({
    id: `${extras?.label || 'video'}-${index}`,
    label: extras?.watermark === false ? 'No watermark MP4' : index === 0 ? 'Best MP4' : `Video ${index + 1}`,
    ext: 'mp4',
    hasAudio: true,
    hasVideo: true,
    watermark: extras?.watermark ?? false,
    url,
    needsMerge: false,
    headers: withHeaders(referer),
  }));
}

async function probeInstagram(url: string): Promise<ProbeResult> {
  const resolved = await resolveFinalUrl(url);
  const code = extractInstagramCode(resolved);
  const referer = resolved;
  const urls: string[] = [];
  let title = 'Instagram reel';
  let author: string | undefined;
  let cover: string | undefined;

  if (code) {
    const mediaId = shortcodeToMediaId(code);
    try {
      const info = await fetchPage(`https://i.instagram.com/api/v1/media/${mediaId}/info/`, {
        'User-Agent': 'Instagram 192.168.1.2.111 Android (33/13; 420dpi; 1080x1920; Google; Pixel 7; panther; panther; en_US; 458229237)',
        'X-IG-App-ID': IG_APP_ID,
      });
      const item = info.json?.items?.[0];
      if (item) {
        title = item.caption?.text || title;
        author = item.user?.username;
        cover = item.image_versions2?.candidates?.[0]?.url;
        const versions = item.video_versions || [];
        for (const version of versions) if (version.url) urls.push(version.url);
      }
    } catch {
      // next strategy
    }

    if (!urls.length) {
      try {
        const api = await fetchPage(`https://www.instagram.com/p/${code}/?__a=1&__d=dis`, {
          'User-Agent': DESKTOP_UA,
          'X-IG-App-ID': IG_APP_ID,
          Accept: 'application/json',
        });
        const media =
          api.json?.graphql?.shortcode_media ||
          api.json?.items?.[0] ||
          api.json?.data?.xdt_shortcode_media;
        if (media) {
          title = media.edge_media_to_caption?.edges?.[0]?.node?.text || media.caption?.text || title;
          author = media.owner?.username || media.user?.username;
          cover = media.display_url || media.thumbnail_src;
          if (media.video_url) urls.push(media.video_url);
          for (const version of media.video_versions || []) if (version.url) urls.push(version.url);
        }
      } catch {
        // next strategy
      }
    }

    if (!urls.length) {
      const embed = await fetchPage(`https://www.instagram.com/p/${code}/embed/captioned/`, {
        'User-Agent': DESKTOP_UA,
      });
      title = og(embed.text, 'title') || title;
      cover = og(embed.text, 'image') || cover;
      const embedVideo = og(embed.text, 'video') || og(embed.text, 'video:secure_url');
      if (embedVideo) urls.push(embedVideo);
      const versionBlock = embed.text.match(/"video_versions"\s*:\s*(\[[^\]]+\])/);
      if (versionBlock?.[1]) {
        try {
          const parsed = JSON.parse(decodeEscaped(versionBlock[1]));
          for (const version of parsed) if (version.url) urls.push(version.url);
        } catch {
          // ignore
        }
      }
    }
  }

  if (!urls.length) {
    const page = await fetchPage(resolved, { 'User-Agent': DESKTOP_UA, 'X-IG-App-ID': IG_APP_ID });
    title = og(page.text, 'title') || title;
    cover = og(page.text, 'image') || cover;
    author = firstGroup(page.text, [/"username"\s*:\s*"([^"]+)"/]) || author;
    const pageVideo = og(page.text, 'video') || og(page.text, 'video:secure_url');
    if (pageVideo) urls.push(pageVideo);
    const videoUrl = firstGroup(page.text, [/"video_url"\s*:\s*"([^"]+)"/]);
    if (videoUrl) urls.push(videoUrl);
    const versions = [...page.text.matchAll(/"url"\s*:\s*"(https:[^"]+scontent[^"]+\.mp4[^"]*)"/g)];
    for (const match of versions) urls.push(match[1]);
  }

  const formats = videoFormatsFromUrls(urls, referer);
  if (!formats.length) throw new Error('Could not read this Instagram reel. It may be private.');
  return {
    id: code || `ig-${Date.now()}`,
    title,
    author,
    thumbnail: cover,
    platform: 'instagram',
    webpageUrl: resolved,
    formats,
    source: 'client',
  };
}

async function probeFacebook(url: string): Promise<ProbeResult> {
  const resolved = await resolveFinalUrl(url);
  const id = extractFacebookId(resolved);
  const pages = unique([
    resolved,
    id ? `https://www.facebook.com/reel/${id}` : '',
    id ? `https://m.facebook.com/reel/${id}` : '',
    `https://www.facebook.com/plugins/video.php?href=${encodeURIComponent(resolved)}`,
  ]);

  let title = 'Facebook reel';
  let cover: string | undefined;
  const urls: string[] = [];

  for (const pageUrl of pages) {
    try {
      const page = await fetchPage(pageUrl, { 'User-Agent': DESKTOP_UA });
      title = og(page.text, 'title') || title;
      cover = og(page.text, 'image') || cover;
      const found = unique([
        firstGroup(page.text, [/"browser_native_hd_url"\s*:\s*"([^"]+)"/]),
        firstGroup(page.text, [/"playable_url_quality_hd"\s*:\s*"([^"]+)"/]),
        firstGroup(page.text, [/"browser_native_sd_url"\s*:\s*"([^"]+)"/]),
        firstGroup(page.text, [/"playable_url"\s*:\s*"([^"]+)"/]),
        og(page.text, 'video:secure_url'),
        og(page.text, 'video'),
      ]);
      urls.push(...found);
      if (urls.length) break;
    } catch {
      // try next page shape
    }
  }

  const formats = videoFormatsFromUrls(urls, 'https://www.facebook.com/');
  if (!formats.length) throw new Error('Could not read this Facebook reel. It may be private.');
  return {
    id: id || `fb-${Date.now()}`,
    title,
    thumbnail: cover,
    platform: 'facebook',
    webpageUrl: resolved,
    formats,
    source: 'client',
  };
}

export async function probeClient(url: string): Promise<ProbeResult> {
  const platform = detectPlatform(url);
  if (platform === 'youtube') return probeYoutube(url);
  if (platform === 'tiktok') return probeTiktok(url);
  if (platform === 'instagram') return probeInstagram(url);
  if (platform === 'facebook') return probeFacebook(url);
  throw new Error('This link is not from a supported app yet.');
}
