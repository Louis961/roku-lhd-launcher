# AGENTS.md — LHD Launcher

Read `README.md` first. This file is the short operating guide for a coding agent.

## What this is

A sideloadable Roku SceneGraph launcher/screensaver (channel/) plus a Python
ECP + Immich helper (helper/). The channel talks only to the helper; the helper
talks to the TV's ECP and to Immich. No root, no firmware changes.

## Key facts

- TV control: `http://<TV_IP>:8060` — `query/apps`, `query/active-app`,
  `query/device-info`, `query/chanperf`, `launch/<id>`, `keypress/<key>`.
- Helper: `http://<HELPER_IP>:8099` — `/health`, `/apps`, `/icon/<id>`,
  `/launch/<id>`, `/home`, `/tvstats`, `/restart`, `/photo`, `/albums`,
  `/auto-launch/...`.
- Helper URL used by the channel: `channel/source/config.brs` (`lhdHelper()`).
- Browser previews use `HELPER` near the top of `preview-motion.html`.
- The screensaver is the channel's `ScreensaverScene`; it is selected in Roku
  Settings → Screen saver → LHD Screensaver.
- TV inputs (`tvinput.hdmi3`) launch through the helper's `launch_app()` using `InputHDMI*`/`InputAV*` keypresses; launches set a 4 s `ignore_home_until` grace so the Home watcher doesn't bounce the input.
- `/tvstats` uses ECP `chanperf`: CPU/RAM of the running channel process only.
  Roku exposes no system-wide CPU/RAM to channels.
- The helper watcher bounces Home to LHD from anywhere, including inside LHD,
  unless auto-start is paused/off; power-on also launches LHD. The Settings
  menu's Roku Home (10 min) / Disable auto-start are the deliberate exits.

## Commands

```bash
./build.sh                                  # channel/ -> lhd-launcher.zip
TV_IP=<tv-ip> ./install-channel.sh          # user types the dev password
python3 -m http.server 8123                 # preview at /preview-motion.html
```

Optional compile check (BrighterScript):

```bash
npx --yes brighterscript --project bsconfig.json
# bsconfig.json: rootDir channel/, files source/**/* components/**/*
```

Verify a running channel:

```bash
curl http://<TV_IP>:8060/query/active-app
# Roku debug console: port 8085 (telnet/nc) for compile/runtime errors
curl http://<HELPER_IP>:8099/health
```

## Safety rules

- Never ask for, echo, store, or commit the **Roku developer password** or the
  **Immich API key**. The user types the dev password at the install prompt;
  the Immich key is written to `helper/.env` by the user or
  `helper/set-immich-key.sh`.
- Never commit `.env`, personal photos, browser profiles, or screenshots that
  show personal photos. Screenshots must use a neutral background.
- The helper has no authentication. Keep it on the LAN; never port-forward 8099.
- Do not attempt to root the TV or replace RokuOS; this project deliberately
  stays in developer mode + ECP.

## Conventions

- Outfit Light/Regular; monochrome glass; the LHD hand+HD mark; no focus rings.
- Focus uses a brand-coloured spotlight; organise/pick-up uses a gold ring and
  the `MOVING` state.
- Keep the channel self-contained (images/fonts inside `channel/`); rebuild the
  zip after any channel change and re-sideload to test.
- SceneGraph limitations are real: no backdrop blur, no true width morph.
  Approximate with scaled rounded-panel PNGs and translation/scale animation.
- Roku keys: `options` is ✱; `rev`/`fwd` may be swallowed by TV firmware, which
  is why drawer/dock reordering uses hold-OK rather than media keys.

## Layout

```
channel/components/   LauncherScene, ScreensaverScene, HttpTask
channel/source/       main.brs, config.brs
channel/images/       app/input/stock icons, glass assets, LHD mark/splash
helper/app.py         ECP bridge, Immich photo proxy, stats/restart
docs/                 README art only
```
