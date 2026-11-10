#!/usr/bin/env python3
"""Roku launcher helper: ECP bridge + Immich photo feed.

Runs on the NAS. The Roku channel talks to this over the LAN; this talks to
the TV's ECP (port 8060) and to Immich's API.
"""
import io
import json
import os
import random
import shutil
import sqlite3
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from xml.etree import ElementTree as ET

import art

TV_IP = os.environ.get("TV_IP", "192.168.1.50")
TV_PORT = os.environ.get("TV_PORT", "8060")
IMMICH_URL = os.environ.get("IMMICH_URL", "http://192.168.1.50:2283").rstrip("/")
IMMICH_API_KEY = os.environ.get("IMMICH_API_KEY", "").strip()
IMMICH_ALBUM_IDS = [x.strip() for x in os.environ.get("IMMICH_ALBUM_IDS", "").split(",") if x.strip()]
AUTO_LAUNCH = os.environ.get("AUTO_LAUNCH", "1") == "1"
LAUNCHER_APP_ID = os.environ.get("LAUNCHER_APP_ID", "dev")
STATE = {"auto_launch": AUTO_LAUNCH, "pause_until": 0.0, "ignore_home_until": 0.0}
PORT = int(os.environ.get("PORT", "8099"))
TV = f"http://{TV_IP}:{TV_PORT}"

# Clean brand icons: favicon first, ECP channel art as fallback.
KANBAN_DB = os.environ.get(
    "KANBAN_DB",
    r"C:/Users/louis/AppData/Local/hermes/kanban/boards/axiom/kanban.db")
CHROME = os.environ.get(
    "CHROME",
    r"C:/Program Files/Google/Chrome/Application/chrome.exe")
SNAP_URL = os.environ.get("SNAP_URL", "http://127.0.0.1:8787/")

HELPER_DIR = os.path.dirname(os.path.abspath(__file__))
LAYOUT_FILE = os.path.join(HELPER_DIR, "layout.json")
PHOTOS_DIR = os.path.join(HELPER_DIR, "photos")


def load_layout():
    """The launcher's layout, re-read on every request so edits apply on the next launch."""
    try:
        with open(LAYOUT_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


_cycle = {"i": 0}
_art_cache = {}
_art_lock = threading.Lock()


def wallpaper_sources():
    lay = load_layout() or {}
    lst = lay.get("wallpaper")
    if isinstance(lst, list) and lst:
        return [str(x) for x in lst]
    return ["photos"]


def weather_image(spec, ttl=300):
    """One sky per place, cached: a render costs about a second of Chrome."""
    place = art.find_place(spec)
    if not place:
        raise RuntimeError("unknown place %r - add it to helper/art.py PLACES" % spec)
    key = place["name"]
    with _art_lock:
        hit = _art_cache.get(key)
        if hit and time.time() - hit[0] < ttl:
            return hit[1]
    body = art.weather_png(place)
    with _art_lock:
        _art_cache[key] = (time.time(), body)
    return body


def next_wallpaper():
    """Round-robin over layout.json "wallpaper", so sources alternate as the TV asks."""
    items = wallpaper_sources()
    with _art_lock:
        i = _cycle["i"] % len(items)
        _cycle["i"] = (i + 1) % len(items)
    spec = items[i].strip()
    if spec.startswith("weather:"):
        return weather_image(spec.split(":", 1)[1])
    if spec in ("solid", "none", "off"):
        return art.solid_png()
    if spec in ("photos", "folder"):
        return local_photo()
    if spec == "immich":
        return random_photo()
    raise RuntimeError("unknown wallpaper source %r" % spec)


def hermes_status():
    """Board state for the TV tile. Read-only connection, so a locked board cannot stall it."""
    out = {"counts": {}, "running": [], "blocked": [], "recent": [],
           "generated": time.strftime("%H:%M:%S")}
    try:
        con = sqlite3.connect("file:%s?mode=ro" % KANBAN_DB, uri=True, timeout=2)
        con.row_factory = sqlite3.Row
        for row in con.execute("select status, count(*) n from tasks group by status"):
            if row["status"] != "archived":
                out["counts"][row["status"]] = row["n"]
        for row in con.execute(
                "select title, assignee from tasks where status='running' "
                "order by started_at desc limit 4"):
            out["running"].append({"title": row["title"], "who": row["assignee"] or ""})
        for row in con.execute(
                "select title, block_kind from tasks where status='blocked' "
                "order by priority desc limit 4"):
            out["blocked"].append({"title": row["title"], "kind": row["block_kind"] or ""})
        for row in con.execute(
                "select title, completed_at from tasks where status='done' "
                "order by completed_at desc limit 4"):
            out["recent"].append({"title": row["title"], "at": (row["completed_at"] or "")[:16]})
        con.close()
    except Exception as exc:
        out["error"] = str(exc)
    return out


_snap = {"at": 0.0, "body": None}
_snap_lock = threading.Lock()


def snapshot(url=None, max_age=4.0):
    """A real screenshot of a local web page, cached for a few seconds.

    A Roku channel cannot render HTML, but it can render a PNG, so the closest thing to
    "your web app on the TV" is: render the page here, show the picture there.

    Chrome writes the file and then keeps running when the page holds an open connection,
    so this waits for the file rather than for the process to exit, then kills it.
    """
    url = url or SNAP_URL
    with _snap_lock:
        if _snap["body"] and time.time() - _snap["at"] < max_age:
            return _snap["body"]
        if not os.path.isfile(CHROME):
            raise RuntimeError("chrome not found at %s" % CHROME)
        fd, path = tempfile.mkstemp(suffix=".png")
        os.close(fd)
        os.remove(path)
        profile = tempfile.mkdtemp(prefix="rokusnap-")
        proc = subprocess.Popen(
            [CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
             "--no-first-run", "--no-default-browser-check", "--disable-extensions",
             "--user-data-dir=" + profile, "--window-size=1920,1080",
             "--screenshot=" + path, url],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=0x08000000)
        size = 0
        deadline = time.time() + 20
        try:
            while time.time() < deadline:
                time.sleep(0.25)
                try:
                    now = os.path.getsize(path)
                except OSError:
                    now = 0
                if now > 1024 and now == size:
                    break
                size = now
            if not os.path.exists(path):
                raise RuntimeError("chrome produced no screenshot within 20 s")
            with open(path, "rb") as f:
                body = f.read()
            if not body:
                raise RuntimeError("screenshot file was empty")
            _snap["body"] = body
            _snap["at"] = time.time()
            return body
        finally:
            try:
                proc.kill()
            except Exception:
                pass
            for target in (path,):
                try:
                    os.remove(target)
                except OSError:
                    pass
            shutil.rmtree(profile, ignore_errors=True)


def local_photo():
    """Fallback wallpaper source: helper/photos. Immich stays optional."""
    try:
        names = [n for n in os.listdir(PHOTOS_DIR) if n.lower().endswith((".jpg", ".jpeg", ".png"))]
    except FileNotFoundError:
        raise RuntimeError("no Immich key and no helper/photos folder")
    if not names:
        raise RuntimeError("no Immich key and helper/photos holds no images")
    path = os.path.join(PHOTOS_DIR, random.choice(names))
    with open(path, "rb") as f:
        body = f.read()
    return body, ("image/png" if path.lower().endswith(".png") else "image/jpeg")


DOMAINS = {
    "837": "youtube.com",
    "12": "netflix.com",
    "592369": "jellyfin.org",
    "22297": "spotify.com",
    "13": "primevideo.com",
    "61322": "max.com",
    "291097": "disneyplus.com",
    "151908": "roku.com",
    "2595": "crunchyroll.com",
    "34376": "espn.com",
    "31440": "paramountplus.com",
    "593099": "peacocktv.com",
    "41468": "tubitv.com",
    "551012": "tv.apple.com",
    "773622": "",
}

_icon_cache: dict[str, tuple[bytes, str, float]] = {}
_icon_lock = threading.Lock()


def http(url, method="GET", data=None, headers=None, timeout=8):
    req = urllib.request.Request(url, data=data, method=method)
    for key, value in (headers or {}).items():
        req.add_header(key, value)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.status, response.headers.get("Content-Type", "application/octet-stream"), response.read()


def ecp(path, method="GET", data=None, timeout=6):
    return http(TV + path, method=method, data=data, timeout=timeout)


def get_apps():
    status, _, body = ecp("/query/apps")
    if status != 200:
        raise RuntimeError(f"ECP apps returned {status}")
    root = ET.fromstring(body)
    return [
        {"id": app.get("id"), "name": (app.text or "").strip(), "type": app.get("type", "appl")}
        for app in root.findall("app")
    ]


_stats_cache: dict[str, Any] = {"ts": 0.0, "data": None}
_stats_lock = threading.Lock()


INPUT_KEYS = {
    "tvinput.hdmi1": "InputHDMI1",
    "tvinput.hdmi2": "InputHDMI2",
    "tvinput.hdmi3": "InputHDMI3",
    "tvinput.hdmi4": "InputHDMI4",
    "tvinput.cvbs": "InputAV1",
    "tvinput.av1": "InputAV1",
    "tvinput.dtv": "InputTuner",
}


def launch_app(app_id):
    """Launch a channel, or switch a TV input with the InputHDMI*/InputAV* keys."""
    STATE["ignore_home_until"] = time.time() + 4.0
    key = INPUT_KEYS.get(app_id)
    if key:
        status, _, _ = ecp("/keypress/" + key, method="POST")
        if status in (200, 204):
            return status, {}, b""
    return ecp("/launch/" + app_id, method="POST")


def restart_launcher():
    """Close the launcher and relaunch it through ECP."""
    STATE["ignore_home_until"] = time.time() + 4.0
    ecp("/keypress/Home", method="POST")
    time.sleep(1.2)
    ecp(f"/launch/{LAUNCHER_APP_ID}", method="POST")


def get_tvstats():
    """Live CPU/memory of the running channel, from Roku ECP chanperf.

    Roku does not expose system-wide CPU/RAM to channels; chanperf reports
    the launcher process itself.
    """
    now = time.time()
    with _stats_lock:
        cached = _stats_cache["data"]
        if cached is not None and now - _stats_cache["ts"] < 1.0:
            return cached

    status, _, body = ecp("/query/chanperf", timeout=4)
    if status != 200:
        raise RuntimeError(f"ECP chanperf returned {status}")
    root = ET.fromstring(body)
    plugin = root.find("plugin")
    if plugin is None:
        return {"ok": False, "reason": "no running plugin"}

    cpu_node = plugin.find("cpu-percent")
    mem_node = plugin.find("memory")
    user = float(cpu_node.findtext("user", "0")) if cpu_node is not None else 0.0
    sys_ = float(cpu_node.findtext("sys", "0")) if cpu_node is not None else 0.0
    used = int(mem_node.findtext("used", "0")) if mem_node is not None else 0
    limit = int(mem_node.findtext("limit", "0")) if mem_node is not None else 0

    data = {
        "ok": True,
        "app": plugin.findtext("id", ""),
        "cpu": round(user + sys_, 1),
        "cpu_user": round(user, 1),
        "cpu_sys": round(sys_, 1),
        "ram_mb": round(used / 1048576),
        "limit_mb": round(limit / 1048576),
        "ts": int(now),
    }
    with _stats_lock:
        _stats_cache["ts"] = now
        _stats_cache["data"] = data
    return data


def get_device():
    status, _, body = ecp("/query/device-info")
    if status != 200:
        raise RuntimeError(f"ECP device-info returned {status}")
    return {child.tag: (child.text or "") for child in ET.fromstring(body)}


def active_app_info():
    try:
        status, _, body = ecp("/query/active-app")
        if status != 200:
            return None, None
        app = ET.fromstring(body).find("app")
        if app is None:
            return None, None
        return app.get("id"), app.get("type")
    except Exception:
        return None, None


def immich(path, method="GET", data=None, timeout=15):
    headers = {"x-api-key": IMMICH_API_KEY}
    if data is not None:
        data = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    return http(IMMICH_URL + path, method=method, data=data, headers=headers, timeout=timeout)


def ensure_roku_image(body, ctype, prefer="JPEG"):
    """Roku channels don't render WebP; convert anything else to PNG/JPEG."""
    if body[:4] != b"RIFF" and ctype in ("image/jpeg", "image/png"):
        return body, ctype
    from PIL import Image
    image = Image.open(io.BytesIO(body))
    out = io.BytesIO()
    if prefer == "PNG":
        image.convert("RGBA").save(out, "PNG")
        return out.getvalue(), "image/png"
    image.convert("RGB").save(out, "JPEG", quality=90)
    return out.getvalue(), "image/jpeg"


def compose_photo(body):
    """1920x1080 composite: blurred cover backdrop + full photo contained."""
    from PIL import Image, ImageEnhance, ImageFilter
    img = Image.open(io.BytesIO(body)).convert("RGB")
    W, H = 1920, 1080

    scale = max(W / img.width, H / img.height)
    bg = img.resize((int(img.width * scale) + 1, int(img.height * scale) + 1), Image.Resampling.LANCZOS)
    left = (bg.width - W) // 2
    top = (bg.height - H) // 2
    bg = bg.crop((left, top, left + W, top + H))
    bg = bg.filter(ImageFilter.GaussianBlur(40))
    bg = ImageEnhance.Brightness(bg).enhance(0.45)

    fscale = min(W / img.width, H / img.height)
    fw, fh = int(img.width * fscale), int(img.height * fscale)
    fg = img.resize((fw, fh), Image.Resampling.LANCZOS)
    bg.paste(fg, ((W - fw) // 2, (H - fh) // 2))

    out = io.BytesIO()
    bg.save(out, "JPEG", quality=90)
    return out.getvalue(), "image/jpeg"


def square_icon(body):
    """Pad a landscape ECP icon to a square with its own edge colour."""
    from PIL import Image
    image = Image.open(io.BytesIO(body)).convert("RGBA")
    w, h = image.size
    if w == h:
        out = io.BytesIO()
        image.save(out, "PNG")
        return out.getvalue(), "image/png"

    side = max(w, h)
    samples = []
    for x in range(0, w, max(1, w // 8)):
        for y in (0, h - 1):
            p = image.getpixel((x, y))
            if isinstance(p, tuple) and len(p) >= 4 and p[3] > 200:
                samples.append(p)
    for y in range(0, h, max(1, h // 8)):
        for x in (0, w - 1):
            p = image.getpixel((x, y))
            if isinstance(p, tuple) and len(p) >= 4 and p[3] > 200:
                samples.append(p)

    if samples:
        bg = (
            sum(p[0] for p in samples) // len(samples),
            sum(p[1] for p in samples) // len(samples),
            sum(p[2] for p in samples) // len(samples),
            255,
        )
    else:
        bg = (0, 0, 0, 255)

    canvas = Image.new("RGBA", (side, side), bg)
    canvas.paste(image, ((side - w) // 2, (side - h) // 2), image)
    out = io.BytesIO()
    canvas.save(out, "PNG")
    return out.getvalue(), "image/png"


def favicon_for(app_id):
    domain = DOMAINS.get(app_id)
    if not domain:
        return None
    with _icon_lock:
        cached = _icon_cache.get(app_id)
        if cached and time.time() - cached[2] < 86400:
            return cached[0], cached[1]
    url = f"https://www.google.com/s2/favicons?domain={domain}&sz=128"
    status, ctype, body = http(url, timeout=10)
    if status != 200 or not body:
        return None
    body, ctype = ensure_roku_image(body, ctype, prefer="PNG")
    with _icon_lock:
        _icon_cache[app_id] = (body, ctype, time.time())
    return body, ctype


_photo_cache: dict[str, Any] = {"ids": [], "at": 0.0}
_photo_lock = threading.Lock()


def random_photo():
    if not IMMICH_API_KEY:
        return local_photo()
    with _photo_lock:
        if not _photo_cache["ids"] or time.time() - _photo_cache["at"] > 60:
            payload: dict[str, Any] = {"size": 24}
            if IMMICH_ALBUM_IDS:
                payload["albumIds"] = IMMICH_ALBUM_IDS
            status, _, raw = immich("/api/search/random", method="POST", data=payload)
            if status != 200:
                raise RuntimeError(f"Immich random returned {status}")
            ids = [asset["id"] for asset in json.loads(raw) if asset.get("type") == "IMAGE"]
            if not ids:
                raise RuntimeError("Immich returned no images")
            _photo_cache["ids"] = ids
            _photo_cache["at"] = time.time()
        asset_id = random.choice(_photo_cache["ids"])
    status, ctype, body = immich(f"/api/assets/{asset_id}/thumbnail?size=preview", timeout=20)
    if status != 200:
        raise RuntimeError(f"Immich thumbnail returned {status}")
    body, ctype = ensure_roku_image(body, ctype or "image/jpeg", prefer="JPEG")
    return compose_photo(body)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: Any) -> None:
        print("%s - %s" % (self.address_string(), format % args), flush=True)

    def send_payload(self, code, body=b"", ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        if body:
            self.wfile.write(body)

    def send_json(self, code, obj):
        self.send_payload(code, json.dumps(obj).encode(), "application/json")

    def do_GET(self):
        try:
            if self.path == "/health":
                info = get_device()
                self.send_json(200, {
                    "ok": True,
                    "tv": TV,
                    "power": info.get("power-mode"),
                    "ecp": info.get("ecp-setting-mode"),
                    "immich_configured": bool(IMMICH_API_KEY),
                    "auto_launch": STATE["auto_launch"],
                    "paused": time.time() < STATE.get("pause_until", 0.0),
                })
            elif self.path == "/home":
                ecp("/keypress/Home", method="POST")
                self.send_json(200, {"ok": True})
            elif self.path == "/auto-launch/off":
                STATE["auto_launch"] = False
                self.send_json(200, {"auto_launch": False})
            elif self.path == "/auto-launch/on":
                STATE["auto_launch"] = True
                STATE["pause_until"] = 0.0
                self.send_json(200, {"auto_launch": True, "paused": False})
            elif self.path.startswith("/auto-launch/pause"):
                seconds = 600
                if "?" in self.path:
                    query = urllib.parse.parse_qs(self.path.split("?", 1)[1])
                    try:
                        seconds = int(query.get("seconds", ["600"])[0])
                    except ValueError:
                        seconds = 600
                STATE["pause_until"] = time.time() + seconds
                self.send_json(200, {"auto_launch": STATE["auto_launch"], "paused_for": seconds})
            elif self.path == "/apps":
                self.send_json(200, {"apps": get_apps(), "layout": load_layout()})
            elif self.path == "/layout":
                self.send_json(200, load_layout() or {})
            elif self.path == "/hermes":
                self.send_json(200, hermes_status())
            elif self.path == "/snapshot" or self.path.startswith("/snapshot?"):
                url = None
                if "?" in self.path:
                    q = urllib.parse.parse_qs(self.path.split("?", 1)[1])
                    url = (q.get("url") or [None])[0]
                self.send_payload(200, snapshot(url), "image/png")
            elif self.path == "/tvstats":
                self.send_json(200, get_tvstats())
            elif self.path == "/restart":
                restart_launcher()
                self.send_json(200, {"ok": True})
            elif self.path == "/albums":
                status, _, raw = immich("/api/albums")
                if status != 200:
                    raise RuntimeError(f"Immich albums returned {status}")
                albums = json.loads(raw)
                self.send_json(200, {"albums": [
                    {
                        "id": album.get("id"),
                        "name": album.get("albumName"),
                        "count": album.get("assetCount"),
                    }
                    for album in albums
                ]})
            elif self.path.startswith("/icon/"):
                app_id = self.path.split("/icon/", 1)[1]
                status, ctype, body = ecp("/query/icon/" + app_id)
                if status != 200:
                    try:
                        fav = favicon_for(app_id)
                    except Exception:
                        fav = None
                    if fav:
                        body, ctype = fav
                        status = 200
                if status == 200:
                    body, ctype = ensure_roku_image(body, ctype, prefer="PNG")
                    body, ctype = square_icon(body)
                self.send_payload(status, body, ctype)
            elif self.path.startswith("/launch/"):
                app_id = self.path.split("/launch/", 1)[1]
                status, _, _ = launch_app(app_id)
                self.send_json(200, {"ok": status in (200, 204), "status": status})
            elif self.path == "/photo" or self.path.startswith("/photo?"):
                self.send_payload(200, next_wallpaper(), "image/png")
            elif self.path.startswith("/art"):
                q = urllib.parse.parse_qs(self.path.split("?", 1)[1]) if "?" in self.path else {}
                src = (q.get("src") or ["weather"])[0]
                place = (q.get("place") or ["Kyoto"])[0]
                if src != "weather":
                    raise RuntimeError("only src=weather today, got %r" % src)
                self.send_payload(200, weather_image(place), "image/png")
            else:
                self.send_json(404, {"error": "not found"})
        except urllib.error.HTTPError as exc:
            self.send_json(502, {"error": f"upstream {exc.code}"})
        except Exception as exc:
            self.send_json(500, {"error": str(exc)})

    def do_POST(self):
        if self.path.startswith("/launch/"):
            try:
                app_id = self.path.split("/launch/", 1)[1]
                status, _, _ = launch_app(app_id)
                self.send_json(200, {"ok": status in (200, 204), "status": status})
            except Exception as exc:
                self.send_json(500, {"error": str(exc)})
        else:
            self.send_json(404, {"error": "not found"})


def launch_launcher():
    app_id, _ = active_app_info()
    if app_id != LAUNCHER_APP_ID:
        print(f"home/power-on -> launching {LAUNCHER_APP_ID}", flush=True)
        ecp(f"/launch/{LAUNCHER_APP_ID}", method="POST")


def watcher():
    """Bounce Home back to LHD Launcher unless auto-start is paused."""
    last_power = None
    last_launch = 0.0
    while True:
        try:
            power = get_device().get("power-mode")
            now = time.time()
            paused = now < STATE.get("pause_until", 0.0)
            ignoring = now < STATE.get("ignore_home_until", 0.0)
            _, app_type = active_app_info()

            if power == "PowerOn" and last_power not in (None, "PowerOn"):
                if STATE["auto_launch"] and not paused:
                    launch_launcher()
                    last_launch = now
            else:
                if app_type == "home":
                    if STATE["auto_launch"] and not paused and not ignoring \
                            and power == "PowerOn" and now - last_launch > 3:
                        time.sleep(0.35)
                        _, app_type2 = active_app_info()
                        if app_type2 == "home":
                            print(f"home -> launching {LAUNCHER_APP_ID}", flush=True)
                            ecp(f"/launch/{LAUNCHER_APP_ID}", method="POST")
                            last_launch = time.time()

            last_power = power
        except Exception as exc:
            print(f"watcher: {exc}", flush=True)
        time.sleep(0.5)


if __name__ == "__main__":
    print(f"helper on :{PORT}  tv={TV}  auto_launch={AUTO_LAUNCH} ({LAUNCHER_APP_ID})", flush=True)
    threading.Thread(target=watcher, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
