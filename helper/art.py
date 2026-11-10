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
    d = None
    for attempt in range(3):
        try:
            d = _get("https://api.open-meteo.com/v1/forecast?" + q)["current"]
            break
        except Exception as exc:
            last = exc
            time.sleep(1.2 * (attempt + 1))
    if d is None:
        return {"ok": False, "error": str(last)[:120], "cond": "No data",
                "key": "cloud", "day": False, "temp": None, "cloud": 0, "wind": 0}
    try:
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
        return {"ok": False, "error": str(exc)[:120], "cond": "No data",
                "key": "cloud", "day": False, "temp": None, "cloud": 0, "wind": 0}


def sky_html(place, wx):
    """One sky, as a page: sun or moon, drifting cloud bands, a city skyline, a caption.

    The skyline is seeded from the place name, so each city has its own silhouette and it
    never changes between renders.
    """
    top, bottom, accent = SKY[wx["key"]][0 if wx["day"] else 1]
    clouds = max(0, min(100, wx["cloud"]))
    cloud_alpha = 0.10 + clouds / 100.0 * 0.55
    seed = sum(ord(c) for c in place["name"])
    stars = "" if wx["day"] else "".join(
        '<i style="left:%d%%;top:%d%%;opacity:%.2f"></i>'
        % (5 + (seed + i * 37) % 90, 3 + (i * 53) % 44, 0.15 + ((i * 29) % 45) / 100.0)
        for i in range(34))
    bars = "".join(
        '<i style="height:%d%%"></i>' % (14 + ((seed * (i + 3) * 7) % 58))
        for i in range(26))
    temp = "&mdash;" if wx["temp"] is None else "%d&deg;C" % wx["temp"]
    disc_size = 150 if wx["day"] else 132
    return """<!doctype html><html><head><meta charset="utf-8"><style>
*{margin:0;padding:0;box-sizing:border-box}
body{width:1920px;height:1080px;overflow:hidden;font-family:"Segoe UI",system-ui,sans-serif;
  background:linear-gradient(180deg,%(top)s 0%%,%(mid)s 52%%,%(bottom)s 78%%);color:#fff}
.stars i{position:absolute;width:2px;height:2px;border-radius:50%%;background:#fff}
.disc{position:absolute;right:250px;top:16%%;width:%(ds)dpx;height:%(ds)dpx;border-radius:50%%;
  background:radial-gradient(circle at 42%% 42%%, #fff 0%%, %(accent)s 46%%, rgba(255,255,255,0) 68%%);
  box-shadow:0 0 70px 14px %(accent)s33;opacity:.92}
.haze{position:absolute;left:0;right:0;bottom:0;height:42%%;
  background:radial-gradient(ellipse at 50%% 100%%, %(accent)s33, transparent 68%%)}
.cloud{position:absolute;left:-25%%;width:150%%;height:26%%;border-radius:50%%;
  background:rgba(255,255,255,%(ca)s);filter:blur(46px)}
.c1{top:6%%}.c2{top:24%%;height:20%%;opacity:.65}.c3{top:40%%;height:14%%;opacity:.45}
.skyline{position:absolute;left:0;right:0;bottom:0;height:14%%;display:flex;
  align-items:flex-end;gap:13px;padding:0 30px;opacity:.42;filter:blur(3px)}
.skyline i{flex:1;background:linear-gradient(180deg,#0d1119 0%%,#06080c 100%%);
  border-radius:4px 4px 0 0}
.win{position:absolute;left:0;right:0;bottom:0;height:14%%;opacity:.18;
  background-image:radial-gradient(circle, rgba(255,214,150,.55) 1.2px, transparent 1.4px);
  background-size:34px 46px;background-position:0 6px;mix-blend-mode:screen}
.ground{position:absolute;left:0;right:0;bottom:0;height:3.2%%;background:#03050a}
.meta{position:absolute;left:104px;top:250px;text-shadow:0 3px 28px rgba(0,0,0,.6)}
.city{font-size:104px;font-weight:600;letter-spacing:-2px;line-height:1}
.country{font-size:30px;opacity:.6;margin-top:12px;letter-spacing:7px;text-transform:uppercase}
.right{position:absolute;right:104px;top:246px;text-align:right;
  text-shadow:0 3px 28px rgba(0,0,0,.6)}
.temp{font-size:142px;font-weight:300;line-height:.92;letter-spacing:-4px}
.cond{font-size:34px;opacity:.82;margin-top:10px}
.wind{font-size:24px;opacity:.45;margin-top:16px;letter-spacing:1px}
</style></head><body>
<div class="stars">%(stars)s</div>
<div class="disc"></div>
<div class="cloud c1"></div><div class="cloud c2"></div><div class="cloud c3"></div>
<div class="haze"></div>
<div class="skyline">%(bars)s</div>
<div class="win"></div>
<div class="ground"></div>
<div class="meta"><div class="city">%(city)s</div><div class="country">%(country)s</div></div>
<div class="right"><div class="temp">%(temp)s</div><div class="cond">%(cond)s</div>
<div class="wind">%(wind)s km/h</div></div>
</body></html>""" % {
        "top": top, "bottom": bottom, "accent": accent, "mid": bottom,
        "ds": disc_size, "ca": cloud_alpha, "stars": stars, "bars": bars,
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


def weather_png(place, wx=None):
    return render(sky_html(place, wx or weather(place)))


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
