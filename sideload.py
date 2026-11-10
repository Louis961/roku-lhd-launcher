#!/usr/bin/env python3
"""Build the LHD channel zip and sideload it to the Roku dev installer.

    python sideload.py --build                    build lhd-launcher.zip only
    python sideload.py --install                  build, then upload (needs password)
    python sideload.py --install --launch         also POST /launch/dev afterwards

The installer password is read from the file named by ROKU_PASS_FILE (default
C:/Users/louis/Documents/rokudev.txt) or from ROKU_DEV_PASS. It is never echoed and
never written to argv, so it does not land in shell history or logs.

Digest auth, not basic: the Roku dev installer answers 401 with a digest challenge and
then accepts rokudev + password. stdlib only.
"""
import argparse
import getpass
import io
import os
import sys
import urllib.error
import urllib.request
import uuid
import zipfile
from urllib.request import HTTPDigestAuthHandler, HTTPPasswordMgrWithDefaultRealm

ROOT = os.path.dirname(os.path.abspath(__file__))
CHANNEL = os.path.join(ROOT, "channel")
ZIP = os.path.join(ROOT, "lhd-launcher.zip")
TV = os.environ.get("TV_IP", "192.168.1.20")
PASS_FILE = os.environ.get("ROKU_PASS_FILE", r"C:/Users/louis/Documents/rokudev.txt")


def build():
    if not os.path.isfile(os.path.join(CHANNEL, "manifest")):
        raise SystemExit("no manifest in %s" % CHANNEL)
    count = 0
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for base, dirs, files in os.walk(CHANNEL):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in files:
                if name.startswith("."):
                    continue
                full = os.path.join(base, name)
                # manifest must sit at the zip root, not inside a folder
                arc = os.path.relpath(full, CHANNEL).replace("\\", "/")
                z.write(full, arc)
                count += 1
    size = os.path.getsize(ZIP)
    print("built %s  (%d files, %.1f KB)" % (ZIP, count, size / 1024.0))
    return ZIP


def password():
    pw = os.environ.get("ROKU_DEV_PASS")
    if pw:
        return pw
    if os.path.isfile(PASS_FILE):
        with open(PASS_FILE, "r", encoding="utf-8", errors="replace") as f:
            pw = f.read().strip()
        if pw:
            print("password read from %s (%d chars)" % (PASS_FILE, len(pw)))
            return pw
    if sys.stdin and sys.stdin.isatty():
        return getpass.getpass("rokudev password: ")
    raise SystemExit("No password: create %s with the developer password on one line, "
                     "or set ROKU_DEV_PASS." % PASS_FILE)


def multipart(fields, filefield, filename, filedata):
    boundary = "----roku" + uuid.uuid4().hex
    body = io.BytesIO()
    for k, v in fields.items():
        body.write(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
                    % (boundary, k, v)).encode())
    body.write(("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n"
                "Content-Type: application/octet-stream\r\n\r\n"
                % (boundary, filefield, filename)).encode())
    body.write(filedata)
    body.write(("\r\n--%s--\r\n" % boundary).encode())
    return body.getvalue(), "multipart/form-data; boundary=" + boundary


def install(zip_path):
    pw = password()
    data = open(zip_path, "rb").read()
    payload, ctype = multipart({"mysubmit": "Install", "archive": "", "passwd": ""},
                               "archive", os.path.basename(zip_path), data)
    mgr = HTTPPasswordMgrWithDefaultRealm()
    mgr.add_password(None, "http://%s/" % TV, "rokudev", pw)
    opener = urllib.request.build_opener(HTTPDigestAuthHandler(mgr))
    req = urllib.request.Request("http://%s/plugin_install" % TV, data=payload,
                                 headers={"Content-Type": ctype})
    try:
        resp = opener.open(req, timeout=120)
        body = resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raise SystemExit("installer refused: HTTP %s %s" % (e.code, e.reason))
    text = " ".join(body.split())
    ok = "success" in text.lower() or "installed" in text.lower()
    print("install ->", "OK" if ok else "UNVERIFIED")
    for marker in ("Install Success", "Identical package", "Install Failure",
                   "Failed", "error"):
        i = text.lower().find(marker.lower())
        if i != -1:
            print("  ", text[max(0, i - 80):i + 200])
            break
    else:
        print("  ", text[:400])
    return ok


def launch():
    req = urllib.request.Request("http://%s:8060/launch/dev" % TV, data=b"", method="POST")
    with urllib.request.urlopen(req, timeout=10) as r:
        print("launch/dev ->", r.status)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--install", action="store_true")
    ap.add_argument("--launch", action="store_true")
    a = ap.parse_args()
    z = build()
    if a.install:
        install(z)
    if a.launch:
        launch()
