"""Generated artwork for the launcher: a weather sky per place, rendered to PNG.

Why images and not BrightScript: a Roku screensaver cannot take input, play audio or play
video, so the only expressive surface it has is a picture that changes. Rendering the sky
here, with HTML and CSS, means the channel needs no new scene - it just shows /photo.

Each place renders its own sky from live conditions (Open-Meteo, no API key): the gradient,
the light and the caption all come from the current weather and whether it is day or night.
"""
import json
import os
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

CHROME = os.environ.get(
    "CHROME", r"C:/Program Files/Google/Chrome/Application/chrome.exe")

# Places worth a sky. Override or extend with "places" in layout.json.
PLACES = [
    {"name": "Kyoto", "country": "Japan", "lat": 35.0116, "lon": 135.7681},
    {"name": "Osaka", "country": "Japan", "lat": 34.6937, "lon": 135.5023},
    {"name": "Tokyo", "country": "Japan", "lat": 35.6762, "lon": 139.6503},
    {"name": "Mali Losinj", "country": "Croatia", "lat": 44.5306, "lon": 14.4689},
    {"name": "London", "country": "England", "lat": 51.5074, "lon": -0.1278},
    {"name": "Florence", "country": "Italy", "lat": 43.7696, "lon": 11.2558},
]

# WMO weather codes, collapsed to a condition and a palette.
CODES = {
    0: ("Clear", "clear"), 1: ("Mostly clear", "clear"), 2: ("Partly cloudy", "partly"),
    3: ("Overcast", "cloud"), 45: ("Fog", "fog"), 48: ("Rime fog", "fog"),
    51: ("Light drizzle", "rain"), 53: ("Drizzle", "rain"), 55: ("Heavy drizzle", "rain"),
    61: ("Light rain", "rain"), 63: ("Rain", "rain"), 65: ("Heavy rain", "storm"),
    66: ("Freezing rain", "storm"), 67: ("Freezing rain", "storm"),
    71: ("Light snow", "snow"), 73: ("Snow", "snow"), 75: ("Heavy snow", "snow"),
    77: ("Snow grains", "snow"), 80: ("Showers", "rain"), 81: ("Showers", "rain"),
    82: ("Violent showers", "storm"), 85: ("Snow showers", "snow"), 86: ("Snow showers", "snow"),
    95: ("Thunderstorm", "storm"), 96: ("Thunderstorm", "storm"), 99: ("Thunderstorm", "storm"),
}

# day palette, night palette: (top, bottom, accent)
SKY = {
    "clear":  (("#1d3f6e", "#7fb2e5", "#ffe9b0"), ("#05070f", "#101a33", "#cfe0ff")),
    "partly": (("#24425f", "#9db7c9", "#ffe6bd"), ("#070b14", "#16233a", "#b9cde8")),
    "cloud":  (("#3a4550", "#8d9aa6", "#e8eef3"), ("#0a0d12", "#1c242e", "#aab6c2")),
    "fog":    (("#4a5259", "#a8b0b6", "#e9eef1"), ("#0d1013", "#232a30", "#b0b8be")),
    "rain":   (("#2a3946", "#6d8291", "#bfe0f0"), ("#070c12", "#141e28", "#8fb6c9")),
    "storm":  (("#1e2731", "#55636f", "#c8d8e4"), ("#05080c", "#11181f", "#96a8b8")),
    "snow":   (("#48586a", "#c9d6e0", "#ffffff"), ("#0b0f15", "#1d2733", "#dbe6ef")),
}


def _get(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "lhd-helper/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def weather(place):
    """Current conditions for one place, or a reason it could not be fetched."""
    q = "latitude=%s&longitude=%s&current=temperature_2m,weather_code,is_day,cloud_cover,wind_speed_10m" \
        "&temperature_unit=celsius&timezone=auto" % (place["lat"], place["lon"])
    try:
        d = _get("https://api.open-meteo.com/v1/forecast?" + q)["current"]
        cond, key = CODES.get(int(d.get("weather_code", 3)), ("Cloudy", "cloud"))
        return {
            "temp": round(float(d.get("temperature_2m", 0))),
            "cond": cond, "key": key,
            "day": bool(int(d.get("is_day", 1))),
            "cloud": int(d.get("cloud_cover", 0) or 0),
            "wind": round(float(d.get("wind_speed_10m", 0) or 0)),
            "ok": True,
        }
    except Exception as exc:
        return {"ok": False, "error": str(exc)[:120], "cond": "Unavailable",
                "key": "cloud", "day": False, "temp": None, "cloud": 0, "wind": 0}


def sky_html(place, wx):
    """One sky, as a page. Sun or moon, drifting clouds, a horizon and a caption."""
    top, bottom, accent = SKY[wx["key"]][0 if wx["day"] else 1]
    disc = "sun" if wx["day"] else "moon"
    disc_y = 22 if wx["day"] else 18
    clouds = max(0, min(100, wx["cloud"]))
    cloud_alpha = 0.10 + clouds / 100.0 * 0.55
    stars = "" if wx["day"] else "".join(
        '<i style="left:%d%%;top:%d%%;opacity:%.2f"></i>'
        % (7 + (i * 37) % 88, 4 + (i * 53) % 46, 0.25 + ((i * 29) % 60) / 100.0)
        for i in range(26))
    temp = "&mdash;" if wx["temp"] is None else "%d&deg;" % wx["temp"]
    return """<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Outfit;src:local("Segoe UI"),local("Helvetica Neue"),sans-serif}
*{margin:0;padding:0;box-sizing:border-box}
body{width:1920px;height:1080px;overflow:hidden;font-family:"Segoe UI",system-ui,sans-serif;
  background:linear-gradient(180deg,%(top)s 0%%,%(mid)s 55%%,%(bottom)s 100%%);color:#fff}
.stars i{position:absolute;width:3px;height:3px;border-radius:50%%;background:#fff}
.disc{position:absolute;right:280px;top:%(disc_y)d%%;width:190px;height:190px;border-radius:50%%;
  background:radial-gradient(circle at 40%% 40%%, #fff, %(accent)s 55%%, transparent 72%%);
  filter:blur(2px);opacity:.92}
.haze{position:absolute;inset:0;background:radial-gradient(ellipse at 50%% 105%%,
  rgba(255,255,255,.28), transparent 60%%)}
.cloud{position:absolute;left:-20%%;width:140%%;height:34%%;border-radius:50%%;
  background:rgba(255,255,255,%(ca)s);filter:blur(38px)}
.c1{top:8%%}.c2{top:26%%;height:26%%;opacity:.7}.c3{top:44%%;height:20%%;opacity:.5}
.hill{position:absolute;left:0;right:0;bottom:0;height:26%%;
  background:linear-gradient(180deg,rgba(0,0,0,.35),rgba(0,0,0,.72))}
.meta{position:absolute;left:110px;top:268px;text-shadow:0 2px 24px rgba(0,0,0,.55)}
.city{font-size:104px;font-weight:600;letter-spacing:-2px;line-height:1}
.country{font-size:34px;opacity:.62;margin-top:10px;letter-spacing:6px;text-transform:uppercase}
.right{position:absolute;right:110px;top:268px;text-align:right;
  text-shadow:0 2px 24px rgba(0,0,0,.55)}
.temp{font-size:150px;font-weight:300;line-height:.9}
.cond{font-size:38px;opacity:.8;margin-top:8px}
.wind{font-size:26px;opacity:.5;margin-top:14px}
</style></head><body>
<div class="stars">%(stars)s</div>
<div class="disc"></div>
<div class="haze"></div>
<div class="cloud c1"></div><div class="cloud c2"></div><div class="cloud c3"></div>
<div class="hill"></div>
<div class="meta"><div class="city">%(city)s</div><div class="country">%(country)s</div></div>
<div class="right"><div class="temp">%(temp)s</div><div class="cond">%(cond)s</div>
<div class="wind">%(wind)s km/h</div></div>
</body></html>""" % {
        "top": top, "bottom": bottom, "accent": accent,
        "mid": bottom, "disc_y": disc_y, "ca": cloud_alpha, "stars": stars,
        "city": place["name"], "country": place.get("country", ""),
        "temp": temp, "cond": wx["cond"], "wind": wx["wind"],
    }


def render(html, width=1920, height=1080, timeout=25):
    """Screenshot an HTML string. Chrome writes the file and then keeps running, so this
    waits for the file to appear and stop growing rather than for the process to exit."""
    if not os.path.isfile(CHROME):
        raise RuntimeError("chrome not found at %s" % CHROME)
    work = tempfile.mkdtemp(prefix="lhdart-")
    page = os.path.join(work, "sky.html")
    shot = os.path.join(work, "sky.png")
    with open(page, "w", encoding="utf-8") as f:
        f.write(html)
    proc = subprocess.Popen(
        [CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", "--hide-scrollbars",
         "--no-first-run", "--no-default-browser-check", "--disable-extensions",
         "--user-data-dir=" + os.path.join(work, "prof"),
         "--window-size=%d,%d" % (width, height),
         "--screenshot=" + shot, "file:///" + page.replace("\\", "/")],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=0x08000000)
    size = 0
    deadline = time.time() + timeout
    try:
        while time.time() < deadline:
            time.sleep(0.2)
            try:
                now = os.path.getsize(shot)
            except OSError:
                now = 0
            if now > 1024 and now == size:
                break
            size = now
        if not os.path.exists(shot):
            raise RuntimeError("chrome produced no image")
        with open(shot, "rb") as f:
            return f.read()
    finally:
        try:
            proc.kill()
        except Exception:
            pass
        for name in ("sky.png", "sky.html"):
            try:
                os.remove(os.path.join(work, name))
            except OSError:
                pass
        try:
            os.remove(os.path.join(work, "prof"))
        except OSError:
            pass


def weather_png(place):
    return render(sky_html(place, weather(place)))


def find_place(spec):
    """'Kyoto' or 'Kyoto,JP' or '35.0,135.7' -> a place dict."""
    s = (spec or "").strip()
    if not s:
        return PLACES[0]
    if "," in s and all(p.strip().replace("-", "").replace(".", "").isdigit() for p in s.split(",", 1)):
        lat, lon = s.split(",", 1)
        return {"name": "%.2f, %.2f" % (float(lat), float(lon)), "country": "",
                "lat": float(lat), "lon": float(lon)}
    name = s.split(",")[0].strip().lower()
    for p in PLACES:
        if p["name"].lower() == name or p["name"].lower().startswith(name):
            return p
    return None

def solid_png(rgb=(10, 10, 15), size=(8, 8)):
    """A flat colour PNG, built without any image library. Used when photos are off."""
    import struct
    import zlib

    w, h = size
    row = bytes([0]) + bytes(rgb) * w
    raw = row * h

    def chunk(tag, payload):
        body = tag + payload
        crc = zlib.crc32(body) & 0xffffffff
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    signature = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    return (signature + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
