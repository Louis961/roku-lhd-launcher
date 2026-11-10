"""Re-import Daybreak's screens into this channel after a Daybreak config change.

Daybreak generates its settings into channel/source/config.brs at build time. This
channel also has its own lhdHelper() in that same file, so a plain copy would
overwrite it. This script rebuilds Daybreak, copies its components and assets in,
and writes one config.brs holding both functions.

    python tools/sync_daybreak.py              # sync + compile check
    python tools/sync_daybreak.py --install    # then build and sideload to the TV

Set DAYBREAK_SRC if the Daybreak checkout is not D:/Projects/tv-check.
"""

import argparse
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHANNEL = os.path.join(HERE, "channel")
SRC = os.environ.get("DAYBREAK_SRC", "D:/Projects/tv-check")

COMPONENTS = [
    "components/ui.brs",
    "components/overlays.brs",
    "components/DaybreakScene.brs",
    "components/DaybreakScene.xml",
    "components/DataTask.xml",
    "components/SpeedTask.brs",
    "components/SpeedTask.xml",
]
DIRS = ["components/data", "components/screens", "source/lib", "fonts", "images"]

LHD_HELPER = """' Point this at the Lua helper that runs on your LAN (see helper/.env).
' Example: http://192.168.1.50:8099
function lhdHelper() as String
    return "%s"
end function

"""


def python_bin():
    for candidate in ("Scripts/python.exe", "bin/python"):
        path = os.path.join(SRC, ".venv", candidate.replace("/", os.sep))
        if os.path.exists(path):
            return path
    return sys.executable


def keep_helper_url(current_config):
    """Read the helper URL out of the config we are about to replace."""
    for line in current_config.splitlines():
        stripped = line.strip()
        if stripped.startswith("return \"http://"):
            return stripped[8:].strip().strip('"')
    return "http://127.0.0.1:8099"


def run(cmd, **kwargs):
    result = subprocess.run(cmd, capture_output=True, text=True,
                            creationflags=0x08000000 if os.name == "nt" else 0, **kwargs)
    if result.returncode != 0:
        print("FAILED: %s" % " ".join(cmd))
        print((result.stdout or "") + (result.stderr or ""))
        sys.exit(1)
    return result


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--install", action="store_true", help="build and sideload after syncing")
    args = ap.parse_args()

    if not os.path.isdir(SRC):
        sys.exit("Daybreak checkout not found at %s (set DAYBREAK_SRC)" % SRC)
    family = os.path.join(SRC, "config", "family.json")
    if not os.path.exists(family):
        sys.exit("No %s yet: copy config/family.example.json and edit it." % family)

    print("building Daybreak from %s" % SRC)
    run([python_bin(), os.path.join(SRC, "daybreak", "build_channel.py")], cwd=SRC)

    src_channel = os.path.join(SRC, "daybreak", "channel")

    for rel in DIRS:
        src, dst = os.path.join(src_channel, rel), os.path.join(CHANNEL, rel)
        if os.path.isdir(dst) and rel.startswith("components"):
            shutil.rmtree(dst)
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True)
    for rel in COMPONENTS:
        shutil.copy2(os.path.join(src_channel, rel), os.path.join(CHANNEL, rel))

    config_path = os.path.join(CHANNEL, "source", "config.brs")
    previous = open(config_path, encoding="utf-8").read() if os.path.exists(config_path) else ""
    helper_url = keep_helper_url(previous)
    generated = open(os.path.join(src_channel, "source", "config.brs"), encoding="utf-8").read()
    merged = (LHD_HELPER % helper_url) + generated.strip() + "\n"
    open(config_path, "w", encoding="utf-8", newline="\n").write(merged)
    print("synced; config.brs holds lhdHelper() (%s) and DaybreakConfig()" % helper_url)

    bsc = os.path.join(SRC, "node_modules", ".bin", "bsc.cmd" if os.name == "nt" else "bsc")
    if os.path.exists(bsc):
        check = subprocess.run([bsc, "--rootDir", CHANNEL, "--createPackage", "false"],
                               capture_output=True, text=True,
                               creationflags=0x08000000 if os.name == "nt" else 0)
        for line in (check.stdout or "").splitlines():
            if "error" in line.lower() or "Found" in line:
                print("  " + line.strip())
        if check.returncode != 0:
            sys.exit("compile check failed; nothing installed")

    if args.install:
        run([sys.executable, os.path.join(HERE, "sideload.py"), "--install", "--launch"], cwd=HERE)
        print("installed and launched on the TV")
    else:
        print("next: python sideload.py --install --launch")


if __name__ == "__main__":
    main()
