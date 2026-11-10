"""Live browser preview of the TV screens, rendered from your own config.

Daybreak can draw every screen off-device from its own code. This wraps that in a
local page: it renders with config/family.json, serves the PNGs, and re-renders on
demand so a change can be seen before anything is installed on the TV.

    python tools/preview.py            # then open http://127.0.0.1:8100

Re-render happens when you press the button, or automatically when family.json is
newer than the last render. Nothing here touches the TV.
"""

import http.server
import os
import shutil
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.environ.get("DAYBREAK_SRC", "D:/Projects/tv-check")
OUT = os.path.join(SRC, "daybreak", "out", "preview")
CONFIG = os.path.join(SRC, "config", "family.json")
PORT = 8100

STATE = {"rendering": False, "stamp": 0.0, "error": "", "count": 0}
LOCK = threading.Lock()

PAGE = """<!doctype html><html><head><meta charset="utf-8"><title>TV preview</title>
<style>
:root{color-scheme:dark}
body{margin:0;background:#0b1120;color:#f4f1ea;font:14px/1.4 "Segoe UI",system-ui,sans-serif}
header{position:sticky;top:0;display:flex;gap:16px;align-items:center;padding:12px 20px;
  background:#0b1120ee;border-bottom:1px solid #1f2a44;backdrop-filter:blur(8px);z-index:2}
h1{font-size:15px;font-weight:600;margin:0;letter-spacing:.4px}
button{background:#1a2440;color:#f4f1ea;border:1px solid #2b3a5e;border-radius:8px;
  padding:7px 14px;font:inherit;cursor:pointer}
button:hover{background:#223057}
button:disabled{opacity:.5;cursor:default}
#state{color:#a9b1c4;font-size:13px}
a{color:#7fb7e8}
main{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:18px;padding:20px}
figure{margin:0;background:#131b2e;border:1px solid #1f2a44;border-radius:12px;overflow:hidden}
figure img{display:block;width:100%;height:auto}
figcaption{padding:8px 12px;color:#a9b1c4;font-size:13px;border-top:1px solid #1f2a44}
.empty{padding:40px 20px;color:#a9b1c4}
</style></head><body>
<header>
  <h1>TV preview</h1>
  <span style="color:#7f8da8;font-size:12px">layout preview · sample data · live data comes from the TV</span>
  <button id="go">Re-render</button>
  <span id="state">loading</span>
  <a href="/launcher" target="_blank">launcher preview</a>
  <a href="http://127.0.0.1:8099/health" target="_blank">helper health</a>
</header>
<main id="grid"></main>
<script>
let stamp = 0;
async function poll(){
  const r = await fetch('/status'); const s = await r.json();
  const el = document.getElementById('state');
  document.getElementById('go').disabled = s.rendering;
  el.textContent = s.rendering ? 'rendering...' : (s.error ? 'error: ' + s.error : s.count + ' screens');
  if (s.stamp && s.stamp !== stamp) { stamp = s.stamp; draw(s.screens); }
}
function draw(names){
  const g = document.getElementById('grid');
  if (!names.length){ g.innerHTML = '<p class="empty">No screens yet: press Re-render.</p>'; return; }
  g.innerHTML = names.map(n =>
    `<figure><img src="/img/${n}.png?t=${stamp}" alt="${n}"><figcaption>${n.replace(/_/g,' ')}</figcaption></figure>`
  ).join('');
}
document.getElementById('go').onclick = async () => {
  await fetch('/rebuild', {method:'POST'}); poll();
};
poll(); setInterval(poll, 2500);
</script></body></html>"""


def screens():
    if not os.path.isdir(OUT):
        return []
    return sorted(f[:-4] for f in os.listdir(OUT) if f.endswith(".png"))


def render():
    with LOCK:
        if STATE["rendering"]:
            return
        STATE["rendering"] = True
        STATE["error"] = ""
    try:
        # clear first: a screen dropped from the harness should disappear, not linger
        for f in os.listdir(OUT) if os.path.isdir(OUT) else []:
            if f.endswith(".png"):
                os.remove(os.path.join(OUT, f))
        shell = shutil.which("bash")
        if not shell:
            raise RuntimeError("bash not found: the preview renderer is a shell script")
        proc = subprocess.run([shell, os.path.join(SRC, "daybreak", "preview", "preview.sh"), OUT],
                              capture_output=True, text=True, cwd=SRC,
                              creationflags=0x08000000 if os.name == "nt" else 0)
        if proc.returncode != 0:
            tail = (proc.stderr or proc.stdout or "").strip().splitlines()
            STATE["error"] = tail[-1][:180] if tail else "render failed"
    except Exception as exc:
        STATE["error"] = str(exc)[:180]
    finally:
        STATE["count"] = len(screens())
        STATE["stamp"] = time.time()
        STATE["rendering"] = False


def config_is_newer():
    if not os.path.exists(CONFIG):
        return False
    return os.path.getmtime(CONFIG) > STATE["stamp"]


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            body = PAGE.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/status":
            import json
            if config_is_newer() and not STATE["rendering"]:
                threading.Thread(target=render, daemon=True).start()
            body = json.dumps({"rendering": STATE["rendering"], "error": STATE["error"],
                               "stamp": STATE["stamp"], "count": STATE["count"],
                               "screens": screens()}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if path == "/launcher":
            page = os.path.join(HERE, "preview-motion.html")
            if not os.path.exists(page):
                self.send_error(404, "preview-motion.html not found")
                return
            data = open(page, "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if path.startswith("/img/"):
            name = os.path.basename(path[5:])
            target = os.path.join(OUT, name if name.endswith(".png") else name + ".png")
            if not os.path.abspath(target).startswith(os.path.abspath(OUT)) or not os.path.exists(target):
                self.send_error(404)
                return
            data = open(target, "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        self.send_error(404)

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path == "/rebuild":
            threading.Thread(target=render, daemon=True).start()
            self.send_response(202)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_error(404)


def main():
    if not os.path.isdir(SRC):
        sys.exit("Daybreak checkout not found at %s (set DAYBREAK_SRC)" % SRC)
    if screens():
        newest = max(os.path.getmtime(os.path.join(OUT, f))
                     for f in os.listdir(OUT) if f.endswith(".png"))
        STATE["stamp"] = newest
        STATE["count"] = len(screens())
        print("%d screens already rendered" % STATE["count"])
        if config_is_newer():
            print("config is newer than those renders: re-rendering")
    else:
        print("first render, about a minute...")
        render()
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), Handler) as httpd:
        print("preview: http://127.0.0.1:%d  (config: %s)" % (PORT, CONFIG))
        httpd.serve_forever()


if __name__ == "__main__":
    main()
