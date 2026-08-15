from __future__ import annotations

import os
import uuid
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

try:
    import yt_dlp
except ImportError as exc:  # pragma: no cover
    raise SystemExit("Install server deps: pip install -r server/requirements.txt") from exc

ROOT = Path(__file__).resolve().parent
COOKIES = ROOT / "cookies.txt"
CACHE = ROOT / ".cache"
CACHE.mkdir(exist_ok=True)

app = FastAPI(title="IraqiTube Engine", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ProbeIn(BaseModel):
    url: str = Field(min_length=8, max_length=2000)


def detect_platform(url: str) -> str:
    host = (urlparse(url).hostname or "").lower()
    if "youtu" in host:
        return "youtube"
    if "instagram" in host:
        return "instagram"
    if "tiktok" in host:
        return "tiktok"
    if "facebook" in host or "fb.watch" in host or host.endswith("fb.com"):
        return "facebook"
    return "unknown"


def base_opts(url: str, download: bool = False) -> dict[str, Any]:
    opts: dict[str, Any] = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": not download,
        "socket_timeout": 20,
        "retries": 2,
        "extractor_retries": 2,
        "cachedir": str(CACHE),
        "http_headers": {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/128.0.0.0 Safari/537.36"
            )
        },
    }
    if COOKIES.exists():
        opts["cookiefile"] = str(COOKIES)
    if "tiktok" in url.lower():
        opts["extractor_args"] = {"tiktok": {"api_hostname": ["api16-normal-c-useast1a.tiktokv.com"]}}
    return opts


def _note(fmt: dict[str, Any]) -> str:
    return " ".join(
        str(fmt.get(k) or "")
        for k in ("format_note", "format_id", "format", "more_re", "dynamic_range")
    ).lower()


def has_watermark(fmt: dict[str, Any]) -> bool:
    note = _note(fmt)
    if "no watermark" in note or "download_addr" in note:
        return False
    if "watermark" in note:
        return True
    return False


def pick_formats(info: dict[str, Any], platform: str) -> list[dict[str, Any]]:
    raw = list(info.get("formats") or [])
    out: list[dict[str, Any]] = []
    seen: set[str] = set()

    def add(item: dict[str, Any]) -> None:
        key = f"{item['id']}-{item['label']}"
        if key in seen:
            return
        seen.add(key)
        out.append(item)

    add(
        {
            "id": "bv*+ba/b",
            "label": "Best available",
            "ext": info.get("ext") or "mp4",
            "height": info.get("height"),
            "filesize": info.get("filesize") or info.get("filesize_approx"),
            "hasAudio": True,
            "hasVideo": True,
            "watermark": False if platform == "tiktok" else False,
            "url": None,
            "needsMerge": True,
        }
    )

    if platform == "tiktok":
        add(
            {
                "id": "download/best",
                "label": "No watermark",
                "ext": "mp4",
                "height": info.get("height"),
                "filesize": None,
                "hasAudio": True,
                "hasVideo": True,
                "watermark": False,
                "url": None,
                "needsMerge": True,
            }
        )

    progressive: list[dict[str, Any]] = []
    audio_only: list[dict[str, Any]] = []

    for fmt in raw:
        proto = (fmt.get("protocol") or "")
        if proto.startswith("mhtml") or proto == "mhtml":
            continue
        url = fmt.get("url")
        vcodec = fmt.get("vcodec") or "none"
        acodec = fmt.get("acodec") or "none"
        ext = fmt.get("ext") or "mp4"
        if ext in {"mhtml", "sbv", "srt", "vtt", "json"}:
            continue
        height = fmt.get("height")
        filesize = fmt.get("filesize") or fmt.get("filesize_approx")
        fid = str(fmt.get("format_id") or "")
        if vcodec != "none" and acodec != "none" and url:
            progressive.append(fmt)
            add(
                {
                    "id": fid,
                    "label": f"{height}p {ext.upper()}" if height else f"Video {ext.upper()}",
                    "ext": ext,
                    "height": height,
                    "filesize": filesize,
                    "hasAudio": True,
                    "hasVideo": True,
                    "watermark": has_watermark(fmt),
                    "url": url,
                    "needsMerge": False,
                }
            )
        elif vcodec == "none" and acodec != "none" and url:
            audio_only.append(fmt)

    audio_only.sort(key=lambda f: f.get("abr") or f.get("tbr") or 0, reverse=True)
    if audio_only:
        a = audio_only[0]
        add(
            {
                "id": str(a.get("format_id")),
                "label": "Audio only",
                "ext": a.get("ext") or "m4a",
                "height": None,
                "filesize": a.get("filesize") or a.get("filesize_approx"),
                "hasAudio": True,
                "hasVideo": False,
                "watermark": False,
                "url": a.get("url"),
                "needsMerge": False,
            }
        )

    progressive.sort(key=lambda f: f.get("height") or 0, reverse=True)
    return out[:12]


def thumbnail_of(info: dict[str, Any]) -> str | None:
    if info.get("thumbnail"):
        return info["thumbnail"]
    thumbs = info.get("thumbnails") or []
    if thumbs:
        return thumbs[-1].get("url")
    return None


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "engine": "yt-dlp", "app": "IraqiTube"}


@app.post("/api/probe")
def probe(body: ProbeIn) -> dict[str, Any]:
    url = body.url.strip()
    if not url.startswith("http"):
        raise HTTPException(400, "A full http(s) link is required")
    platform = detect_platform(url)
    try:
        with yt_dlp.YoutubeDL(base_opts(url, download=False)) as ydl:
            info = ydl.extract_info(url, download=False)
    except yt_dlp.utils.DownloadError as exc:
        raise HTTPException(400, str(exc).split("\n")[-1][:280]) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(500, f"Engine error: {exc}") from exc

    if not info:
        raise HTTPException(400, "No media found")
    if info.get("is_live"):
        raise HTTPException(400, "Live streams cannot be saved")

    if info.get("_type") == "playlist" and info.get("entries"):
        info = info["entries"][0] or info

    return {
        "id": str(info.get("id") or "media"),
        "title": info.get("title") or "Untitled",
        "author": info.get("uploader") or info.get("channel") or info.get("creator"),
        "thumbnail": thumbnail_of(info),
        "duration": info.get("duration"),
        "platform": platform,
        "webpage_url": info.get("webpage_url") or url,
        "formats": pick_formats(info, platform),
    }


@app.get("/api/stream")
def stream(
    url: str = Query(..., min_length=8),
    format_id: str = Query("bv*+ba/b"),
):
    if not url.startswith("http"):
        raise HTTPException(400, "A full http(s) link is required")

    outtmpl = str(CACHE / f"{uuid.uuid4().hex}.%(ext)s")

    opts = base_opts(url, download=True)
    opts.update(
        {
            "format": format_id,
            "outtmpl": outtmpl,
            "merge_output_format": "mp4",
            "skip_download": False,
        }
    )

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=True)
            prepared = ydl.prepare_filename(info)
    except yt_dlp.utils.DownloadError as exc:
        raise HTTPException(400, str(exc).split("\n")[-1][:280]) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(500, f"Download error: {exc}") from exc

    path = Path(prepared)
    if not path.exists():
        matches = list(CACHE.glob(Path(outtmpl).name.split(".%(ext)s")[0] + ".*"))
        if matches:
            path = matches[0]
    if not path.exists():
        raise HTTPException(500, "File was not written")

    media = "audio/mp4" if path.suffix in {".m4a", ".mp3", ".aac"} else "video/mp4"
    filename = f"{(info or {}).get('title', 'iraqi-tube')}{path.suffix}"
    safe = "".join(c for c in filename if c not in '<>:"/\\|?*')

    return FileResponse(
        path,
        media_type=media,
        filename=safe,
        background=None,
    )


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("IRAQITUBE_PORT", "8787"))
    uvicorn.run(app, host="0.0.0.0", port=port, log_level="info")
