# TCL 49S405 + LHD: start to finish

Device: `192.168.1.20`, TCL 49S405 (7104X), Roku OS 15.3.4.2402, Airbnb-named Wi-Fi `CuddleCats`.
Host PC: `192.168.1.103` (RTX 5070 Ti, Docker Desktop 29.0.1). Reading time: 6 minutes. Doing time: ~45.

Every source this guide uses is linked in **[Sources and links](#sources-and-links)** at the end, checked
2026-11-09. Three verdicts first, because they decide what we build:

1. **A sideloaded channel has no browser.** `roHtmlWidget` returns `unknown classname` on both the render
   thread and main, and the runtime proves it distinguishes "thread-restricted" from "absent" by giving a
   different error for `roUrlTransfer`. Roku's internal Chromium 104 is for system UI only. So there is no
   way to embed the Hermes web UI in a Roku channel. (Measured on this firmware by prior art.)
2. **There is no Moonlight or Steam Link client for Roku.** Moonlight's own docs list its ports - PS Vita,
   Xbox, LG webOS, embedded Linux - and Roku is not among them. Game streaming needs an HDMI device.
3. **This TV does speak AirPlay** (`supports-airplay: true`, port 7000 open). Apple device only. Windows
   Miracast is not advertised in `device-info` and should be assumed absent until the menu is seen.

Also: `hermes-webui` currently listens on `127.0.0.1:8787` only, so neither the TV nor a phone on the LAN
can reach it as-is. That is a bind-address change, which you ratify before I touch it.

---

## What gets added, kept and removed

| Action | What | Why |
|---|---|---|
| **Keep** | Every streaming app you already use. Nothing about them has to move | LHD launches them by id; Roku keeps them installed |
| **Keep** | Roku's built-ins: Settings, Search, Live TV, Channel Store | Not removable by design; the launcher does not need them gone |
| **Remove** | Only channels you name as dead weight - `:8080 remove_plugin <id>` | This is the honest scope. There is no Android-style debloat list here |
| **Remove** | The 3 ad plugins that accept removal (My Offers, Microsite, Roku Ads Manager) | They may return; the DNS block is what makes it stick |
| **Add** | **LHD Launcher** as the single dev channel - your dock, drawer, icons | It replaces what you look at: no ad panel, no recommendation rows |
| **Add** | **Daybreak** screens as that channel's screensaver (merged 2026-11-09) | Weather, radar, news, calendars and photos, drawn on the TV with no PC in the path |
| **Add** | **Jellyfin** (host the server on the PC, Jellyfin channel on the TV) | Your own films, shows, music, with resume and subtitles |
| **Add** | **Immich** (optional) for LHD's photo screensaver | Replaces Roku City, which is an ad surface |
| **Add** | A **Hermes status tile** forked into LHD (native render, not a browser) | See Phase 8 - this is the version of your idea that works |
| **Add** | **An HDMI device with Moonlight** for gaming and full desktop | See Phase 9 - not possible on Roku OS itself |

One hard constraint that shapes all of it: **Roku allows exactly one sideloaded channel**. LHD and any
custom Hermes screen must ship in the same package, so the Hermes tile is a fork of LHD, not a second app.
The same rule decided the screensaver: Daybreak is compiled into LHD instead of installed beside it - see Phase 11.

---

## Phase 1 - developer mode (your hands, 2 minutes)

1. Be on the Roku **Home** screen, not inside an app.
2. On the remote, quickly: **Home, Home, Home, Up, Up, Right, Left, Right, Left, Right**.
3. The **Developer Settings** screen appears. Note the IP it shows - it should read `192.168.1.20`.
4. Choose **Enable installer and restart**, accept the agreement (**I Agree**).
5. Set a **developer password** and write it down. Username is `rokudev`. Do not reuse a password you use
   anywhere else.
6. The TV restarts. `/query/device-info` will then report `developer-enabled: true`.

What this opens: `tcp/8080` (the dev terminal, no auth), `tcp/80` (the installer, password), `tcp/8085`
(the BrightScript debugger, after a dev-channel crash). Turn dev mode off later and all three close,
along with the launcher.

## Phase 2 - let the network side work (your hands, 30 seconds)

Settings > System > Advanced system settings > Control by mobile apps > **Network access** > **Enabled**.

Roku's own docs: since OS 14.1 this is required for `keypress`, `query/icon`, `query/tv-channels`; with
dev mode it also unlocks `query/registry`, `query/r2d2-bitmaps`, `query/sgnodes`, `query/app-state`,
`query/chanperf`, `exit-app`. Every launcher depends on it - the helper polls `/query/apps`,
`/query/icon/<id>`, `/launch/dev` and keypresses.

Trade-off, plainly: any device on the LAN can now drive the TV. Home LAN, trusted devices - acceptable.
If it ever is not, set it back to Limited and lose the launcher.

## Phase 3 - recon: done, 2026-11-09

Measured with dev mode on and ECP permissive.

- **15 real channels, and no bloat among them.** AV, BBC America, Crunchyroll, Disney Plus, HDMI 1
  ("Xbox"), HDMI 2, HDMI 3, Hulu, Live TV, Met Opera on Demand, NASA, Netflix, PBS, Peacock TV, Plex,
  Prime Video, STARZ, The Roku Channel, Viki, YouTube. Every one was installed deliberately.
- **The bloat is in the plugin layer, and it is not visible as apps**: ACR Lib Channel, AcrAddon, Roku Ads
  Library, Grand Central, FRAME, DFP Ad Service, Interactive Ads Library, Roku Interactive Ads Library,
  Innovid Ad Renderer (live, `usg 29`), BrightLineLibrary (live, `usg 29`), Roku My Offers, Roku Survey
  Channel, Roku City. Removing those is refused by the console; see `tcl-49s405-vectors.md` section 8.
- **The read vectors closed**: `query/registry`, `query/sgnodes`, `query/app-state` are 404 on this
  firmware; `chanperf` and `r2d2-bitmaps` answer only for your own dev channel; `target` + `sgnodes` gives
  "Channel not running / not authorized" for anything Roku built.
- **Memory headroom**: 472 MB total, 122 MB available.

Decision from this data: **remove nothing.** Keep all 15 channels; LHD shows only the ones you put in the
dock, which is the same result without breaking anything. The only removal left worth doing is the few ad
plugins that accept it, and only after testing one on something expendable.

## Phase 4 - install LHD (in progress, 2026-11-09)

Done and verified:

- Repo cloned to `D:\Projects\roku-lhd`; `channel/source/config.brs` points at
  `http://192.168.1.103:8099`.
- Helper **running** on this PC, no Docker needed (stdlib-only Python): health returns
  `{"ok": true, "power": "PowerOn", "ecp": "permissive", "auto_launch": true}`, and it enumerates all 20
  apps through the TV's ECP.
- `lhd-launcher.zip` built: 50 files, 1464 KB, `manifest` verified at the zip root.
- Installer at `http://192.168.1.20/` answers **401** - reachable, waiting for digest auth.
- `sideload.py` written and lint-clean: builds, then uploads with digest auth, password read from a file
  or an env var, never from argv.

Installed, 2026-11-09:

- Installer: **Install Success**, 1,499,004 bytes, v1.0.16.
- `active-app` = `LHD Launcher`; `POST /launch/dev` returns 204.
- The TV calls the PC: `GET /apps 200`, `GET /tvstats 200` (4x), `GET /photo 500` - Immich is not
  configured yet, so the photo screensaver has no source. Either point it at Immich or leave that
  screensaver off.
- Rendered and measurable: `sgnodes -c dev counts` = **167 SceneGraph nodes** - 1 LauncherScene, 47 Poster
  (app tiles and icons), 59 Label (names, clock), 13 Rectangle, 37 RenderableNode. That is a drawn UI, not
  an empty scene.
- `chanperf` on our own channel: CPU 1.0% user / 0.5% sys, **20.6 MB** resident.
- **Memory got better, not worse.** Before install: 321 MB used, 125 MB available. After: **237 MB used,
  214 MB available**. The launcher costs less than the home screen it replaces, because the home screen's
  ad and recommendation plugins stop loading.
- Password file deleted after use; it never entered the chat or shell history.

Two things only your eyes can confirm (Phase 5, below).

## Phase 5 - make it the home screen (last two checks need eyes)

- LHD's helper watches `power-mode`; on `PowerOn` it launches the launcher. Auto-start, no remote needed.
- Home key is firmware-reserved: pressing Home from anywhere flashes Roku's home for about a second, then
  the helper bounces back into LHD. That second is the only Roku UI you will see.
- **Check A:** press Home on the remote. It should return to the dock within about a second. If it stays on
  Roku's home, the watcher is not firing and I will read `helper.log` for the cause.
- **Check B:** Settings > Theme > Screensavers - is **LHD Screensaver** listed? The manifest declares
  `screensaver_title=LHD Screensaver`, so if it appears, setting it removes Roku City (a full-screen ad)
  from the idle state. This was the one open question from the earlier investigation.
- Turn on the process monitor for a day if you want to see what the launcher costs; then turn it off.

## Phase 5b - customizing the launcher

Three layers exist today. The fourth is the one worth building.

**1. From the remote, no rebuild, persisted** in the channel's own registry
(`roRegistrySection("launcher")`: `favorites`, `drawer_order`, `name_<id>`, `icon_<id>`, `photo_interval`,
`monitor`):

| Do | How |
|---|---|
| Reorder the dock | Hold **OK** on an app, arrows to move, OK to drop |
| Reorder the drawer | Same, inside the all-apps drawer |
| Rename any tile | **✱** on the app > Rename |
| Change any icon | **✱** on the app > Change icon (Switch, PlayStation, Raspberry Pi, gamepad, HDMI, AV, Live TV, speaker, stock, generic) |
| Process monitor on/off, auto-start off, restart launcher, organise favourites | the cog, top right |
| Filter the drawer by category | VIDEO, MUSIC, PHOTOS, ANIME, SPORTS, FREE TV, STREAMING, MEDIA SERVER, LIBRARY, LIVE TV, HDMI |

**2. From the PC, visually, today:** open `D:\Projects\roku-lhd\preview-motion.html` in a browser. It is the
real UI in HTML. Two caveats: the app list in it is a mock (`var apps = [` on line 343), and its helper URL
is still `192.168.1.50` (line 844) - change that to `192.168.1.103:8099` and the clock, stats and
background become live. It also pulls a Google font and an Unsplash photo, so it needs internet. Treat it
as a look sandbox, not a mirror of your TV.

**3. From the PC, by editing files, then a 1-minute rebuild + reinstall:**

| What | Where |
|---|---|
| Dock geometry (tile 72 px, gap 18, resting Y 936, open Y 262) | `channel/components/LauncherScene.brs` lines 5-6, 46-47 |
| Positions of clock, date, weather, cog, dim and glow opacity | `channel/components/LauncherScene.xml` |
| Typography | `channel/fonts/Outfit-Light.ttf`, `Outfit-Regular.ttf` |
| Chrome artwork: pill, spotlight, panel, rings, input icons | `channel/images/*.png` (39 files) |
| Per-app icons baked into the package | `channel/images/app-<channel-id>.png` |
| Background photo | `LauncherScene.brs:147` sets `bg.uri = helper + "/photo"` - **that is Immich**. Unconfigured, it returns 500, which is why the background is currently empty |

**4. Why there was no PC-side editor:** the layout lived in the TV's channel registry
(`roRegistrySection("launcher")`), and nothing outside the channel can write that section - no registry
write verb exists in the console either. So the fix was to change *where the layout lives*, not to add
buttons to a TV app.

### D5 - the layout file (implemented)

`D:\Projects\roku-lhd\helper\layout.json` is now the source of truth for how the launcher looks. The edit
loop is: **edit the file, press Home (or cog > Restart launcher), see it.** No rebuild, no reinstall.

How it works, and why it is built this way:

- The channel's `init()` runs on the render thread, where `roUrlTransfer` is refused (that is the
  "MAIN|TASK-only component failed on RENDER thread" error). So the layout cannot be fetched on its own -
  it rides inside the `/apps` response the channel already requests.
- `helper/app.py` re-reads `layout.json` on **every** request and returns it as `{"apps":[...],
  "layout":{...}}`. An edit is picked up on the next launch, not the next helper restart.
- `LauncherScene.brs` gained one guarded call - `if data.layout <> invalid then applyLayout(data.layout)` -
  and one sub, `applyLayout`. Anything missing, malformed or unreachable falls back to the registry values
  the remote writes, so the on-TV customisation keeps working exactly as before.

What you can change in the file:

| Key | Effect |
|---|---|
| `dock` | The five tiles on the dock, in order. Ids come from `/query/apps` |
| `drawer` | The all-apps drawer order. Anything left out still appears, after these |
| `apps.<id>.name` | Rename any tile (e.g. `13` -> "Prime") |
| `apps.<id>.icon` | Icon without the remote: switch, gamepad, playstation, raspberrypi, speaker, hdmi, av, livetv, stock, generic |
| `photo_interval` | Seconds between wallpaper changes (minimum 10) |

Your wallpaper is `helper + "/photo"`, so it is also file-driven now: Immich if configured, otherwise a
random image from `helper/photos/`. Drop `.jpg` or `.png` files there and they start appearing. That
directory is empty right now, which is why the background is blank.

**Still v2, and honest about it:** a tile that shows *content* rather than launching a channel needs a new
SceneGraph scene - a Roku channel cannot host a web view (`roHtmlWidget` is absent), so a "Hermes tile" is
a native screen rendering JSON text, not an embedded web page. The layout file is the right hook for it:
v2 adds `"tiles": [...]` and a second scene.

## Phase 6 - ads, ACR and telemetry (your hands 4 toggles; router decision separate)

| Goal | Path | Set |
|---|---|---|
| ACR / content fingerprinting off | Settings > Privacy > Smart TV experience > Use info from TV inputs | Off |
| Ad targeting off | Settings > Privacy > Advertising > Limit ad tracking (or uncheck Personalized ads) | On / unchecked |
| No Roku City billboard | Settings > System > Screen saver | Digital Clock (or LHD's screensaver in Phase 5) |
| No seasonal promo takeover | Settings > Home screen > Theme | a static theme |

Network: a DNS sinkhole that **answers 0.0.0.0** rather than blackholing - this TV has an 8.8.8.8 fallback
in its resolver chain, and a blackhole lets the ad request fall through to Google. Then the 52-host list,
with `cloudservices.roku.com` left open so channel installs keep working. This changes router DHCP, so it
is a separate go/no-go, and I will verify the TV's actual resolver chain first with a probe channel.

## Phase 7 - your own content

- **Jellyfin** on the PC (server), then the Jellyfin channel on the TV from the store. Films, shows, music,
  your own files, resume across devices. LHD launches it like any other app.
- **Immich** (or a folder) for LHD's photo screensaver - your photos instead of Roku City.
- Local video files can also go via Jellyfin rather than DLNA; DLNA gives no resume and no subtitles.

## Phase 7b - content: what can actually go on the screen

Three channels exist for getting your own stuff onto this TV, and they are not interchangeable.

| What you want | Possible? | Mechanism |
|---|---|---|
| A web page, live and interactive, inside a channel | **No** | `roHtmlWidget` returns `unknown classname` on both threads; Roku's Chromium 104 is system-UI only (measured, with a control that proves absence) |
| A web page as a **picture**, refreshed every few seconds | **Yes, built** | `GET /snapshot` renders the page with headless Chrome on this PC and returns a PNG. Verified: **280 KB in 1.0 s**, cached for 4 s, and the capture shows the real Hermes chat UI. A channel showing this as a Poster every 3-5 s looks live; it is not clickable |
| Streaming video from your own server (Plex, Jellyfin, a camera) | **Yes** | The `Video` node plays HLS/DASH/MP4 - exactly how the Plex and Jellyfin channels work. Rebuilding a Plex client is pointless; a custom screen that launches Plex is not |
| A live stream generated on this PC | **Yes** | ffmpeg is installed (`ffmpeg 7.1`). An HLS stream from this machine can be played in a channel: 1-3 s latency with LL-HLS, fine for "watch the desktop", not for play |
| A screensaver | **Yes**, with hard limits | Screensavers are channels (`screensaver_title`, `RunScreenSaver()`); they accept **no input** (any key dismisses) and cannot use audio, video or purchases. So no interactive, no sound - ever |
| A game-stream client | **No** | No Moonlight, Steam Link, Parsec or AMD Link client exists for Roku OS. The client must be an HDMI device |

### What is already served, and what to add

| Endpoint | Serves | Status |
|---|---|---|
| `/hermes` | Board counts, running cards, blocked cards, last completions | **built**, verified |
| `/snapshot` | PNG of any local page (`?url=`), cached 4 s | **built**, verified |
| `/photo` | Wallpaper / screensaver source: Immich, else `helper/photos` | built |
| `/layout` | The launcher layout | built |

### Screensaver ideas, ranked by value per hour of work

**Superseded by Phase 11.** Daybreak is installed and does the first two ideas better than my own renderer
did; what follows is kept as the reasoning that led there, not as work to do.

Constraint first: a screensaver here is a slideshow of images and text. No sound, no input, no video.

1. **Plex poster wall** - recently added or unwatched posters, drifting slowly. You already have the library;
   the Plex API hands out art per item, so this is the highest-value one.
2. **Weather sky** - a gradient and cloud field coloured by current conditions and the next hour
   (Open-Meteo, no key). Changes on its own, always looks intentional.
3. **Now playing from Plex** - album or film art with the title, drifting. Visual only; no audio allowed.
4. **NASA / Wikimedia daily image** - one good photograph a day with its caption. Zero maintenance.
5. **Board ambient** - running cards as slow pulses, blocked cards amber. Useful when you are working
   elsewhere and want the TV to tell you something at a glance.
6. **On this day** - your own photos from this date in previous years (Immich date search).
7. **Astronomy** - ISS position over a map and the next visible pass for this location.

### Wallpaper ideas (same `/photo` hook, no new channel work)

- Time-of-day palette: a gradient that shifts through dawn, day, dusk, night.
- Weather-matched sky, the same source as idea 2.
- The last thing you watched on Plex, blurred and dimmed so the dock stays readable.
- A board-state tint: slate when nothing runs, amber when a card is blocked.
- Your own photos with a blur and 65% dim, so tiles keep contrast.

## Phase 8 - Hermes on the TV: the version that actually works

Not a webview - that door is measured shut. Three real options, best first:

| Option | What you get | Build cost | Interaction |
|---|---|---|---|
| **Status tile inside LHD** (recommended) | A tile that opens a full-screen native dashboard: board counts, running cards, last completions, cost, anything `harness/status.py --brief` prints | A 30-line HTTP server on the PC + a SceneGraph screen forked into LHD (~150 lines) | Browse with the remote; act on your phone or laptop |
| **AirPlay from an Apple device** | Your phone or Mac mirrors the Hermes UI to the TV | Zero | Touch on the phone, TV is the display |
| **Desktop stream** (Phase 9) | The whole desktop, Hermes included, mouse and keyboard at the TV | An HDMI device | Full keyboard and mouse |

The status tile is the honest fit for "see progress while I do something else". It reads one JSON endpoint
and renders text; it cannot click anything, because a channel cannot reach ECP and Roku killed in-app ECP.
If you want it to *act*, the action lives on the phone.

Caveat for the AirPlay option: `hermes-webui` binds `127.0.0.1:8787` only. To reach it from a phone the
bind has to widen to the LAN (a config change you ratify) or it has to be reached over Tailscale.

## Phase 9 - desktop and games on the TV, low latency

Roku OS cannot run the client. The working design is one HDMI device and Sunshine on this PC.

| Part | Choice | Note |
|---|---|---|
| Host | **Sunshine** on this PC | RTX 5070 Ti, driver 621.14 - NVENC for H.264, HEVC and AV1 |
| Client | An Android TV box with an **Ethernet port** (e.g. onn. 4K Pro) or a Fire TV Stick 4K Max + Ethernet adapter | Moonlight is on the Play Store for Android TV; Fire TV needs a sideload |
| Network | Client wired to the same switch as the PC | Wi-Fi 5 on this TV is the wrong tool for 60 fps |

Starting settings, then tune: **1080p60, 40-60 Mbps, H.264 first** (switch to HEVC or AV1 once the client
proves it decodes it), frame pacing **Balanced**, and on the TV turn **Game mode** on for that input with
motion smoothing off.

Latency expectation, stated honestly: this is a 2017 4-series panel. Stream decode plus TV input lag lands
around **40-60 ms** total. Fine for couch co-op, racing, most single-player. Not a competitive shooter rig.

Moonlight also streams the whole desktop, so the gaming device doubles as the "full Hermes with keyboard"
route from Phase 8.

## Phase 10 - lock it down and know how to get out

- **Restore:** dev mode off removes the sideloaded channel and closes `:8080`, `:8085`, `:80`. Roku's home
  returns. Keep `roku-lhd.zip` and this file so a reinstall is five minutes.
- **Keep the zip and `helper/.env`** in `D:\Projects\roku-lhd` - not in a repo, the env has your TV IP.
- **If a firmware update removes the channel**, reinstall from the zip; nothing else changes.
- **Settings log:** every toggle above is reversible from the same menu. Nothing here is one-way, except a
  flash experiment, which we are not doing.
- **What stays exposed:** `:8080` with no auth while dev mode is on, and ECP-wide control of the TV from the
  LAN. Accepted on a trusted network; revisit if the network ever is not.

## Phase 11 - the merged build: LHD home screen + Daybreak screensaver (done 2026-11-09)

Two projects, one package. A Roku has exactly one sideload slot, so instead of choosing between the
ad-free home screen (LHD) and the ambient dashboard (Daybreak), Daybreak's screens are compiled into LHD.

| Entry point | What it runs | Where |
|---|---|---|
| `Main()` | `LauncherScene` - the home screen, dock, drawer, app tiles | `channel/source/main.brs` |
| `RunScreenSaver()` | `DaybreakScene` in screensaver mode | `channel/source/main.brs` |

Installed: channel id `dev`, version 1.1.17, **3.78 MB, 148 files**. Daybreak fetches its own data on the
TV; only the launcher needs the PC helper.

### What is on the screen, and when

Daybreak builds a playlist from the clock and the weather. In screensaver mode it plays up to four screens,
then repeats. Measured on this set: **SCHOOL -> ambient -> MONDAY NIGHT over 90 s**, clock advancing 10:05 to
10:08, zero console errors.

| Screen | Shows |
|---|---|
| briefing | Morning: hourly forecast, calendar, game watch, local headlines, heads-up |
| school | This week at school, per member |
| ambient | Big clock, current conditions, sunrise/sunset, one photo |
| tonight | Tonight: calendar, weather, tomorrow's reminders |
| week / weekend | The week ahead |
| gameday / recap | Team schedules and results |
| season | Seasonal note for the region |
| lake / sky | Local water level; sky and moon |
| radar | Rain and warnings, mapped around home |
| night | 23:00-05:00: a dim clock, no photos |
| board | Household board: chores, whose turn |
| status / diagnostics | Feed health, memory, network throughput |

Rules that decide the order (`channel/components/screens/playlist.brs`): a severe-weather warning takes
over everything; 04:00-11:00 morning, 11:00-17:00 midday, 17:00-23:00 evening, 23:00-05:00 dim clock.
**Any remote key ends the screensaver** - that is Daybreak's design, not a fault.

### What it ingests, and what each source costs you

All free and keyless except the calendar.

| Source | What it gives | What you control |
|---|---|---|
| [Open-Meteo forecast](https://api.open-meteo.com/v1/forecast?latitude=33.8045&longitude=-118.1876&current=temperature_2m) | Current, hourly, 8 days, sunrise/sunset | `home` coordinates; Fahrenheit and mph are hard-coded |
| [Open-Meteo air quality](https://air-quality-api.open-meteo.com/v1/air-quality?latitude=33.8045&longitude=-118.1876&current=us_aqi,pm2_5) | US AQI, PM2.5 | Nothing |
| [NWS alerts](https://api.weather.gov/alerts/active?point=33.8045,-118.1876) | Warnings for your area | `place.area`, `place.town` |
| [NOAA MRMS radar](https://mrms.ncep.noaa.gov/2D/) | Radar tiles around home | `home`; labels from `place.radar` |
| [USGS water services](https://waterservices.usgs.gov/nwis/iv/?format=json&sites=08313000&parameterCd=00062) | Lake elevation in feet | `place.lake` |
| [ESPN site API](https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/1/schedule) | Team schedules and results | `place.teams`, `place.rivalry` |
| [Google News RSS](https://news.google.com/rss/search?q=Long+Beach+CA) | Local headlines | `place.news.queries`, `.local`, `.ownSource` |
| Google Calendar secret iCal | Family events | `.env` `FAMILY_CALENDAR_ICS` |
| College athletics iCal | Results starting `[W]` / `[L]` | `place.college` |
| Wallpaper catalog (`catalog.json` + `img/`) | Photos, credited on screen | `place.wallpapers` |
| Roku bandwidth log | Diagnostics graph | Nothing |

**Turned off in this build:** radar (NOAA MRMS), ESPN sports, the lake gauge, college athletics and the
family calendar. Radar's fetch and its place in the playlist are removed; the rest are inert because their
keys are null or empty, so nothing is downloaded and no card is drawn. Verified on the TV: a screensaver
rotation showed no game, calendar, radar or lake label at all.

### What you can customize

Two config files, one layout file, one menu on the TV.

**1. Daybreak content - `D:\Projects\tv-check\config\family.json`**

| Key | Does |
|---|---|
| `household` | The greeting ("Good evening, Home") |
| `home` `{city,lat,lon}` | Weather, radar centre, sunrise and sunset |
| `members` `[{name,color,birthday,allegiance,school,grade,activities}]` | Whole-word matching in calendar titles, the school screen, house-divided |
| `chores` `[{task,rotate,every}]` | Board screen, rotating turns |
| `curbside` `{weekday}` | Bin night; built-in rules are LaGrange's - `place.curbside: null` turns it off |
| `apps` | The evening app row |

`place` - every key you set replaces the LaGrange default:

| Key | Effect |
|---|---|
| `town`, `region` | Headers, "Long Beach today", radar text |
| `area` | NWS alert wording |
| `seasonRegion` | Season screen title |
| `timezone` | Forecast and air-quality times; must match the TV's own zone |
| `teams` `[{key,name,short,color,id,path}]` | ESPN schedules |
| `rivalry` (two team names) | House-divided split screen |
| `lake` `{name,site,summerPool,winterPool,lowAlert}` | USGS gauge, parameter 00062 |
| `college` `{name,short,team,color,ics}` | College results |
| `news` `{queries,local,ownSource}` | News queries, local regex, the paper's name |
| `radar` `{places,water}` | Map labels |
| `wallpapers` | Catalog URL; `null` uses the packaged photos only |

**2. TV address and calendar - `D:\Projects\tv-check\.env`**

| Key | Does |
|---|---|
| `ROKU_IP` | Which TV the installer talks to |
| `ROKU_DEV_USER` / `ROKU_DEV_PASS` | Dev installer login |
| `FAMILY_CALENDAR_ICS` | Secret iCal URL; empty means no calendar |
| `GENTLE_NEWS` | `1` filters sensational headlines |

**3. Launcher - `D:\Projects\roku-lhd\helper\layout.json`** (re-read on every request, no rebuild)

| Key | Does |
|---|---|
| `dock` | Ordered app ids in the top band |
| `drawer` | Ordered app ids below |
| `apps` `{id:{name,icon}}` | Rename or re-icon a tile: `switch, gamepad, playstation, raspberrypi, speaker, hdmi, av, livetv, stock, generic` |
| `photo_interval` | Seconds between backgrounds |
| `wallpaper` | `["solid"]`, `["photos"]` (drop files in `helper/photos`), `["immich"]`, or a list to alternate |
| `channel/components/ui.brs` | `uiColors()` sets the palette, `uiType()` the type scale - the whole look changes here, then rebuild |

**4. On the TV**: OK -> Settings - gentle news, rotation speed, which screens. Saved on the TV.

### The commands

```bash
cd "D:/Projects/roku-lhd"
python tools/sync_daybreak.py --install   # after editing family.json or .env: rebuild, merge, compile check, install
python sideload.py --install --launch     # channel code changed only
```

Launcher layout needs neither: edit `layout.json`, then press Home (or cog -> Restart launcher).
`sync_daybreak.py` copies Daybreak's screens, data task, fonts and icons in, keeps `lhdHelper()` and
`DaybreakConfig()` in one `config.brs`, keeps the helper URL, and refuses to install if the compile fails.

### The look: DESIGN.md

The screensaver now wears the launcher's clothes. `DESIGN.md` in the repo root is the authority - warm
off-white `#F4F3F0` on an alpha ramp, one amber accent `#FFD166`, cards as glass at 6-11 percent with a
1 px hairline at 14 percent, radius 30, no shadows and no blur. It lints clean:

```bash
npx -y -p @google/design.md designmd lint DESIGN.md     # 0 errors
```

The restyle lives in `channel/components/ui.brs`: `uiCard()` is the plate, `uiColors()` the palette
(note the 8-digit colours), `uiType()` the scale. A screen that hard-codes a colour is a bug against
the spec, not a style choice.

### Wallpaper modes - four ways for the picture to move

Set `wallpaper` in `config/family.json` (top level), then `python tools/sync_daybreak.py --install`.

| Mode | What moves |
|---|---|
| `static` | Nothing. The photo Daybreak ships with. |
| `kenburns` | A 42 s zoom that returns to its start, so a 30 s screen never ends mid-move. **Live now.** |
| `grade` | A wash over the photo: amber in sun and at sunset, blue in rain, violet at night and in a storm. |
| `slideshow` | A second photo crossfades in after 8 s and stays for the rest of the screen. |
| `skies` | No photo: a generated sky picked by weather code and hour - clear, partly, cloud, rain, storm, dusk, night. |

The preview renders all five side by side (`wall_static`, `wall_kenburns`, `wall_grade`, `wall_slideshow`,
`wall_skies`). It poses the frame each animation passes through, because the off-device renderer has no
Animation node; the TV runs the real interpolator.

### Preview before you push

```bash
cd "D:/Projects/roku-lhd"
python tools/preview.py          # then open http://127.0.0.1:8100
```

It renders every screen off-device from Daybreak's own code, serves the PNGs on one page, re-renders on the
button, and re-renders by itself when `config/family.json` is newer than the last run. Stale screens are
cleared first, so a screen you remove disappears. The same page links the launcher preview and the helper's
health, so both halves can be checked before an install.

It is a **layout** preview: the off-device renderer cannot reach the network, so it draws with Daybreak's
sample feeds and your settings. Live weather, headlines and photos only appear on the TV.

### Getting the best information and the best picture

1. **Exact coordinates and timezone.** `33.8045, -118.1876` and `America/Los_Angeles`. Radar centres there,
   NWS wording uses `area`, and every forecast hour depends on the timezone.
2. **Match the TV's clock zone** (Settings -> System -> Time), or hourly rows shift by an hour.
3. **Add the people.** With `members: []` the calendar, school and board screens have nothing to draw, so
   you get fewer screens and a thinner dashboard. This is the single biggest upgrade available.
4. **Add the calendar.** `FAMILY_CALENDAR_ICS` turns "A quiet night in" into real events; names match whole
   words against `members[].name`.
5. **Add teams** and a `rivalry` pair for the gameday and house-divided screens.
6. **Local news**: wider queries per city (`"Long Beach" CA when:2d`) and a `local` regex so the local tag
   lands on the right headlines.
7. **Photos**: `place.wallpapers` points at a catalog; Daybreak's `build.py --audit` measures brightness so
   text stays readable over every image. Keep the credit - the packaged photos are CC BY-SA.
8. **Wired network** if the TV is on Ethernet: steadier radar and feed refresh, and 4K playback from Plex
   is less likely to dip.
9. **Sharpness ceiling**: the UI is 1920x1080 (`ui_resolutions=fhd`) and every asset is made at that size.
   On this 4K panel Roku upscales it; forcing `uhd` would blur, not sharpen.
10. **Units**: the forecast URL is hard-coded to Fahrenheit and mph in `sources.brs`. Celsius means editing
    that URL and rebuilding - it is not a setting.

### Known limits

- **One dev slot.** Deleting the channel brings Roku's ad-filled home screen back; nothing is installed twice.
- **The launcher needs the PC** for its app list and background (`/apps`, `/photo`). The screensaver does not:
  it keeps working with the PC off.
- **News is headlines only.** A headline and its source, cut to fit the card. No tap-through and no
  article view: a channel draws its own screen and has no browser. The articles themselves are normal
  web pages with ads. A QR code on the screen to open a story on your phone is the only way around it.
- **Any key ends the screensaver** - Daybreak's design.
- **No root, no firmware change.** The ACR and ad plugin layer is untouched; what changed is what is drawn.

## Order of work, condensed

1. You: dev mode (Phase 1), network access on (Phase 2).
2. Me: recon, channel list, wall classification (Phase 3).
3. You: tick keep/remove.
4. Me: LHD helper, build, sideload, auto-start, screensaver test (Phases 4-5).
5. You: four privacy toggles (Phase 6).
6. You decide: DNS sinkhole at the router (Phase 6) - the only hard block available.
7. Optional, in this order: Jellyfin (7), Hermes status tile (8), HDMI streaming device (9).
8. Done: Daybreak merged in as the screensaver (Phase 11); set members, FAMILY_CALENDAR_ICS and
   place when you want the calendar, school and sports screens to fill.

---

## Sources and links

Every link below was checked on 2026-11-09: GitHub and cleanyour.tv answer HTTP 200. `developer.roku.com`
answers 403 to a plain `curl` but 200 to a browser - bot filtering, not a dead page.

### The launcher installed on the TV

| What | Link |
|---|---|
| LHD Launcher (channel + helper) | https://github.com/shuff57/roku-lhd-launcher |
| **Your fork - where our changes live** | https://github.com/Louis961/roku-lhd-launcher |
| Upstream, for rebasing future changes | https://github.com/shuff57/roku-lhd-launcher |
| Helper - the Python service running on this PC | https://github.com/shuff57/roku-lhd-launcher/blob/main/helper/app.py |
| Channel config (the one file I edited) | https://github.com/shuff57/roku-lhd-launcher/blob/main/channel/source/config.brs |
| Browser preview of the UI | https://github.com/shuff57/roku-lhd-launcher/blob/main/preview-motion.html |

### The screensaver merged in (Daybreak)

| What | Link |
|---|---|
| Daybreak - source of the screensaver screens | https://github.com/roberjo/tv-check |
| Its configuration reference - every key above | https://github.com/roberjo/tv-check/blob/main/docs/CONFIGURATION.md |
| Its build and preview tools | https://github.com/roberjo/tv-check/blob/main/docs/DEVELOPMENT.md |
| The merged channel, as installed | https://github.com/Louis961/roku-lhd-launcher |
| The sync script that re-imports Daybreak | https://github.com/Louis961/roku-lhd-launcher/blob/main/tools/sync_daybreak.py |
| The other ambient dashboard, if this one misbehaves (needs a companion host) | https://github.com/braydenhand/horizon-roku |

### The feeds the screensaver reads - each checked 2026-11-09

| Feed | Link |
|---|---|
| Open-Meteo forecast, API reference | https://open-meteo.com/en/docs |
| Air quality (same host, no key) | https://air-quality-api.open-meteo.com/v1/air-quality?latitude=33.8045&longitude=-118.1876&current=us_aqi,pm2_5 |
| Geocoding, for game venues by ZIP | https://geocoding-api.open-meteo.com/v1/search?name=90806&count=1&countryCode=US&format=json |
| NWS active alerts | https://api.weather.gov/alerts/active?point=33.8045,-118.1876 |
| NOAA MRMS radar tiles | https://mrms.ncep.noaa.gov/2D/ |
| USGS water services, lake gauge | https://waterservices.usgs.gov/nwis/iv/?format=json&sites=08313000&parameterCd=00062 |
| ESPN team schedule | https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams/1/schedule |
| Google News RSS | https://news.google.com/rss/search?q=Long+Beach+CA |

### Prior art - a full assessment of a Roku TV on Roku OS 15.3.4.2402, the same build as this set

| What | Link |
|---|---|
| The whole writeup | https://github.com/Catnip202X/roku-writeup |
| 02 - attack surface (ports, console, ECP) | https://github.com/Catnip202X/roku-writeup/blob/main/docs/02-attack-surface.md |
| 03 - findings (`:8080` console, `remove_plugin`) | https://github.com/Catnip202X/roku-writeup/blob/main/docs/03-findings.md |
| 04 - the BrightScript sandbox | https://github.com/Catnip202X/roku-writeup/blob/main/docs/04-brightscript-sandbox.md |
| 05 - escape avenues (incl. the AirPlay path) | https://github.com/Catnip202X/roku-writeup/blob/main/docs/05-escape-avenues.md |
| 06 - ad suppression (four toggles, sinkhole) | https://github.com/Catnip202X/roku-writeup/blob/main/docs/06-ad-suppression.md |
| 07 - negative results (`roHtmlWidget`, registry, files) | https://github.com/Catnip202X/roku-writeup/blob/main/docs/07-negative-results.md |
| 52-host blocklist, each line citing its plugin | https://github.com/Catnip202X/roku-writeup/blob/main/blocklist/roku-blocklist.txt |

### The project that started this

| What | Link |
|---|---|
| CleanYourTV (Android TV / Google TV) | https://github.com/Gathin23/cleanyourtv |
| `PROMPT.md` - the rule that says stop on Roku OS | https://github.com/Gathin23/cleanyourtv/blob/main/PROMPT.md |
| Tested models (82 TCL entries, none of them Roku) | https://cleanyour.tv/tvs |
| Non-Android guidance - the Roku section | https://cleanyour.tv/not-android |

### Alternative launchers, if LHD misbehaves on this firmware

| What | Link |
|---|---|
| CleanYourRoku (MIT, no helper, Jellyfin music) | https://github.com/UXDreamer/CleanYourRoku |
| Its Roku privacy settings guide | https://github.com/UXDreamer/CleanYourRoku/blob/main/docs/roku-privacy-settings.md |
| Meu Menu - tested on Roku OS 15.3.4, binds port 8787 | https://github.com/TraspJorge/Roku-launcher |

### Roku's own documentation - the authority for every menu path

| What | Link |
|---|---|
| External Control Protocol: ports, endpoints, what needs dev mode | https://developer.roku.com/dev/docs/external-control-api |
| Enabling developer mode | https://developer.roku.com/dev/docs/developer-setup |
| Screensavers as a channel type | https://developer.roku.com/dev/docs/screensavers |
| Limit ad tracking (the checkbox) | https://docs.roku.com/published/adtracking/en/US |
| Ad preferences | https://support.roku.com/article/manage-ad-preferences |

### What we will install later

| What | Link |
|---|---|
| Sunshine - the host encoder for game streaming | https://github.com/LizardByte/Sunshine |
| Moonlight FAQ - its own list of client platforms (Roku is absent) | https://github.com/moonlight-stream/moonlight-docs/wiki/Frequently-Asked-Questions |
| Jellyfin server | https://github.com/jellyfin/jellyfin |
| Jellyfin Roku channel | https://github.com/jellyfin/jellyfin-roku |
| Immich - source for the launcher's photo background and screensaver | https://github.com/immich-app/immich |

### On this PC, not on GitHub

| What | Path |
|---|---|
| LHD checkout | `D:\Projects\roku-lhd` |
| My ECP/console helper | `C:\Users\louis\Documents\rokutv.py` |
| Build + sideload script | `D:\Projects\roku-lhd\sideload.py` |
| Daybreak checkout - source of the screensaver | `D:\Projects\tv-check` |
| Daybreak config you edit | `D:\Projects\tv-check\config\family.json` |
| Sync, check and install in one command | `D:\Projects\roku-lhd\tools\sync_daybreak.py` |
| Launcher layout: dock, names, icons, background | `D:\Projects\roku-lhd\helper\layout.json` |
| Raw recon output (device-info, plugins, consoles) | `C:\Users\louis\Documents\rokutv-recon\` |
| The three other documents | `C:\Users\louis\Documents\tcl-49s405-{debloat,vectors,runbook,start-to-finish}.md` |
