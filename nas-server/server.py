"""OpenRide Local NAS library: read-only video catalog with HTTP range streaming.

A small server intended for a trusted home LAN. No accounts, no WAN exposure.
"""
from __future__ import annotations

import hashlib
import json
import mimetypes
import os
import re
import subprocess
import threading
from collections import Counter
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(os.getenv("VIDEO_ROOT", "/videos")).resolve()
CACHE = Path(os.getenv("CACHE_ROOT", "/cache")).resolve()
PORT = int(os.getenv("PORT", "8765"))
DO_PROBE = os.getenv("PROBE_DURATION", "true").lower() in ("true", "1", "yes")
VIDEO_EXTS = {".mp4", ".m4v", ".mkv", ".mov", ".webm", ".avi", ".ts"}
MIME_TYPES = {
    ".mp4": "video/mp4", ".m4v": "video/x-m4v", ".mkv": "video/x-matroska",
    ".mov": "video/quicktime", ".webm": "video/webm", ".avi": "video/x-msvideo",
    ".ts": "video/mp2t",
}
_THUMB_SEMAPHORE = threading.BoundedSemaphore(2)
_PROBE_CACHE: dict[tuple[str, int, int], int | None] = {}
_PROBE_LOCK = threading.Lock()


def video_id(relative_path: str) -> str:
    return hashlib.sha256(relative_path.encode("utf-8")).hexdigest()[:24]


def pretty_title(stem: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"[_]+", " ", stem)).strip()


def read_sidecar(video: Path) -> dict:
    for sidecar in (video.with_suffix(video.suffix + ".json"), video.with_suffix(".json")):
        if sidecar.is_file() and not sidecar.is_symlink():
            try:
                value = json.loads(sidecar.read_text(encoding="utf-8"))
                if isinstance(value, dict):
                    return value
            except (ValueError, OSError, UnicodeDecodeError):
                pass
    return {}


def probe_duration(video: Path, stats: os.stat_result) -> int | None:
    if not DO_PROBE:
        return None
    key = (str(video), stats.st_mtime_ns, stats.st_size)
    with _PROBE_LOCK:
        if key in _PROBE_CACHE:
            return _PROBE_CACHE[key]
    seconds = None
    try:
        proc = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", str(video)],
            capture_output=True, text=True, timeout=7, check=False,
        )
        if proc.returncode == 0:
            value = float(proc.stdout.strip())
            if value >= 0 and value < 2592000:
                seconds = round(value)
    except (FileNotFoundError, ValueError, subprocess.TimeoutExpired):
        pass
    with _PROBE_LOCK:
        if len(_PROBE_CACHE) > 4000:
            _PROBE_CACHE.clear()
        _PROBE_CACHE[key] = seconds
    return seconds


def scan_classes() -> tuple[list[dict], dict[str, Path]]:
    items = []
    paths = {}
    if not ROOT.is_dir():
        return items, paths
    try:
        candidates = ROOT.rglob("*")
        for video in candidates:
            if video.is_symlink() or not video.is_file() or video.suffix.lower() not in VIDEO_EXTS:
                continue
            rel = video.relative_to(ROOT)
            if any(part.startswith(".") for part in rel.parts):
                continue
            try:
                stat = video.stat()
                if not video.resolve().is_relative_to(ROOT):
                    continue
                sidecar = read_sidecar(video)
            except OSError:
                continue
            rel_str = rel.as_posix()
            id_ = video_id(rel_str)
            parent = rel.parent.as_posix() if rel.parent != Path(".") else ""
            category = rel.parts[0] if len(rel.parts) > 1 else "Unsorted"
            duration = sidecar.get("duration_seconds")
            if not isinstance(duration, (int, float)) or duration < 0:
                duration = probe_duration(video, stat)
            tags = sidecar.get("tags", [])
            if not isinstance(tags, list):
                tags = []
            items.append({
                "id": id_,
                "source": "local",
                "title": str(sidecar.get("title") or pretty_title(video.stem)),
                "collection": parent,
                "category": category,
                "instructor": str(sidecar.get("instructor") or ""),
                "description": str(sidecar.get("description") or ""),
                "difficulty": str(sidecar.get("difficulty") or ""),
                "tags": [str(t) for t in tags],
                "duration_seconds": int(duration) if duration is not None else None,
                "filename": video.name,
                "size_bytes": stat.st_size,
                "modified_utc": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
                "playback_url": f"/api/v1/classes/{id_}/video",
                "thumbnail_url": f"/api/v1/classes/{id_}/thumbnail",
            })
            paths[id_] = video
    except (PermissionError, OSError):
        # Health endpoint indicates when the video root is missing or unreadable.
        pass
    items.sort(key=lambda i: (i["collection"].casefold(), i["title"].casefold()))
    return items, paths


def choose_poster(video: Path) -> Path | None:
    for candidate in (
        video.with_suffix(video.suffix + ".jpg"), video.with_suffix(".jpg"),
        video.with_suffix(".png"), video.with_suffix(".webp"),
        video.parent / "cover.jpg", video.parent / "poster.jpg",
        video.parent / "cover.png", video.parent / "poster.png",
    ):
        if candidate.is_file() and not candidate.is_symlink() and candidate.resolve().is_relative_to(ROOT):
            return candidate
    return None


def thumbnail_for(video: Path, id_: str) -> Path | None:
    poster = choose_poster(video)
    if poster:
        return poster
    try:
        stat = video.stat()
        CACHE.mkdir(exist_ok=True, parents=True)
        thumbs = CACHE / "thumbs"
        thumbs.mkdir(exist_ok=True)
        dest = thumbs / f"{id_}-{stat.st_size}-{stat.st_mtime_ns}.jpg"
        if dest.is_file() and dest.stat().st_size > 0:
            return dest
        with _THUMB_SEMAPHORE:
            if dest.is_file() and dest.stat().st_size > 0:
                return dest
            tmp = thumbs / f"{id_}-{threading.get_ident()}.jpg"
            try:
                result = subprocess.run(
                    ["ffmpeg", "-hide_banner", "-loglevel", "error", "-ss", "5", "-i", str(video),
                     "-frames:v", "1", "-vf", "scale=480:-2", "-q:v", "4", "-y", str(tmp)],
                    capture_output=True, timeout=25, check=False,
                )
                if result.returncode == 0 and tmp.is_file() and tmp.stat().st_size > 0:
                    tmp.replace(dest)
                    return dest
            except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                pass
            finally:
                tmp.unlink(missing_ok=True)
    except (OSError, ValueError):
        pass
    return None


INDEX_HTML = """<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>OpenRide Local - NAS Library</title>
<style>
:root{font-family:system-ui,-apple-system,sans-serif;color-scheme:dark}*{box-sizing:border-box}
body{background:#121821;color:#eef2f8;max-width:1140px;margin:0 auto;padding:28px 20px}
h1{font-size:2rem;margin:0 0 6px}p{color:#a7b5c9}a{color:#9ed4ff}
.box{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin:25px 0}
input,select{background:#1f2c3c;border:1px solid #3a4a60;color:white;border-radius:9px;padding:12px;font-size:1rem}
input{min-width:260px;flex:1}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:17px}
.card{background:#202c3b;border:1px solid #34445a;border-radius:12px;overflow:hidden}
.card img{display:block;width:100%;aspect-ratio:16/9;object-fit:cover;background:#17202c}
.card .body{padding:13px}.card h3{margin:0 0 7px;font-size:1.03rem}.card .meta{color:#a8b7c9;font-size:.84rem;line-height:1.5}
.card a{display:inline-block;margin-top:10px;color:#9ed4ff}.muted{color:#9aaabe}
</style></head><body><h1>OpenRide Local</h1>
<p>Read-only cycling class library on your NAS. This preview does not record rides; the OpenRide Android app will do that.</p>
<div class="box"><input id="filter" placeholder="Search videos or instructors" aria-label="Search videos">
<select id="group" aria-label="Filter by folder"><option value="">All folders</option></select></div>
<p id="summary">Loading your library...</p><div class="grid" id="classes"></div>
<script>
let all=[];
const escapeText=x=>String(x??'');
async function load(){const res=await fetch('/api/v1/classes');if(!res.ok)throw Error(res.status);const data=await res.json();all=data.classes;
const groups=[...new Set(all.map(x=>x.collection || 'Unsorted'))].sort();const s=document.getElementById('group');
for(const g of groups){let o=document.createElement('option');o.value=g;o.textContent=g;s.appendChild(o)}render()}
function render(){const q=document.getElementById('filter').value.toLowerCase(),g=document.getElementById('group').value;
const rows=all.filter(x=>(!g||(x.collection||'Unsorted')===g)&&((x.title+' '+x.instructor+' '+x.collection).toLowerCase().includes(q)));
document.getElementById('summary').textContent=`${rows.length} class(es) shown / ${all.length} total`;
const host=document.getElementById('classes');host.replaceChildren();
for(const c of rows){const card=document.createElement('article');card.className='card';
const img=document.createElement('img');img.loading='lazy';img.src=c.thumbnail_url;img.alt='Thumbnail for '+c.title;img.onerror=()=>{img.style.display='none'};card.appendChild(img);
const body=document.createElement('div');body.className='body';const h=document.createElement('h3');h.textContent=c.title;body.appendChild(h);
const info=document.createElement('div');info.className='meta';info.textContent=[c.collection,c.instructor,c.duration_seconds?Math.round(c.duration_seconds/60)+' min':''].filter(Boolean).join(' / ');body.appendChild(info);
const a=document.createElement('a');a.href=c.playback_url;a.textContent='Play file';a.target='_blank';a.rel='noreferrer';body.appendChild(a);card.appendChild(body);host.appendChild(card)}
}
document.getElementById('filter').addEventListener('input',render);document.getElementById('group').addEventListener('change',render);
load().catch(err=>{document.getElementById('summary').textContent='Cannot load library: '+err.message});
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "OpenRideLocal/0.1"

    def _common_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Range, Content-Type")
        self.send_header("Cache-Control", "no-store")

    def _send(self, body: bytes, content_type: str, code: int = 200, head: bool = False):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self._common_headers()
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def _json(self, obj: dict, code: int = 200, head: bool = False):
        self._send(json.dumps(obj, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8", code, head)

    def do_OPTIONS(self):
        self.send_response(204)
        self._common_headers()
        self.end_headers()

    def do_GET(self):
        self.handle_read(head=False)

    def do_HEAD(self):
        self.handle_read(head=True)

    def handle_read(self, head: bool):
        path = urlsplit(self.path).path
        if path == "/":
            self._send(INDEX_HTML.encode("utf-8"), "text/html; charset=utf-8", head=head)
            return
        if path == "/healthz":
            self._json({"status": "ok" if ROOT.is_dir() else "missing_library", "video_root_exists": ROOT.is_dir()}, head=head)
            return
        if path == "/api/v1/classes":
            classes, _ = scan_classes()
            self._json({"api_version": 1, "source": "local", "count": len(classes), "classes": classes}, head=head)
            return
        if path == "/api/v1/groups":
            classes, _ = scan_classes()
            counts = Counter(c["collection"] or "Unsorted" for c in classes)
            self._json({"groups": [{"name": group, "count": count} for group, count in sorted(counts.items())]}, head=head)
            return
        m = re.fullmatch(r"/api/v1/classes/([0-9a-f]{24})/(video|thumbnail)", path)
        if not m:
            self._json({"error": "not_found"}, 404, head)
            return
        id_, kind = m.groups()
        _, by_id = scan_classes()
        video = by_id.get(id_)
        if video is None:
            self._json({"error": "class_not_found"}, 404, head)
            return
        if kind == "thumbnail":
            poster = thumbnail_for(video, id_)
            if not poster:
                self._json({"error": "thumbnail_unavailable"}, 404, head)
                return
            self._send_file(poster, head, is_video=False)
        else:
            self._send_file(video, head, is_video=True)

    def _send_file(self, path: Path, head: bool, is_video: bool):
        try:
            size = path.stat().st_size
            if not size:
                self._json({"error": "empty_file"}, 404, head)
                return
            start, end = 0, size - 1
            range_header = self.headers.get("Range") if is_video else None
            status = 200
            if range_header:
                match = re.fullmatch(r"bytes=(\d*)-(\d*)", range_header.strip())
                if match and (match.group(1) or match.group(2)):
                    first, last = match.groups()
                    if first:
                        start = int(first)
                        end = min(int(last), size - 1) if last else size - 1
                    else:
                        count = int(last)
                        start = max(size - count, 0)
                        end = size - 1
                    if start > end or start >= size:
                        self.send_response(416)
                        self.send_header("Content-Range", f"bytes */{size}")
                        self.send_header("Content-Length", "0")
                        self._common_headers()
                        self.end_headers()
                        return
                    status = 206
                else:
                    self.send_response(416)
                    self.send_header("Content-Range", f"bytes */{size}")
                    self.send_header("Content-Length", "0")
                    self._common_headers()
                    self.end_headers()
                    return
            self.send_response(status)
            self.send_header("Content-Type", MIME_TYPES.get(path.suffix.lower(), mimetypes.guess_type(path.name)[0] or "application/octet-stream"))
            self.send_header("Content-Length", str(end - start + 1))
            if is_video:
                self.send_header("Accept-Ranges", "bytes")
            if status == 206:
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
            self._common_headers()
            self.end_headers()
            if head:
                return
            with path.open("rb") as f:
                f.seek(start)
                remaining = end - start + 1
                while remaining:
                    block = f.read(min(1024 * 1024, remaining))
                    if not block:
                        break
                    self.wfile.write(block)
                    remaining -= len(block)
        except (ConnectionResetError, BrokenPipeError):
            pass
        except (OSError, ValueError) as error:
            # Avoid a second response after partial transfer.
            self.log_error("read error: %s", str(error))


def main():
    print(f"OpenRide Local NAS: listening on port {PORT}, videos at {ROOT}", flush=True)
    print("LAN ONLY: do not port-forward this unauthenticated video server", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
