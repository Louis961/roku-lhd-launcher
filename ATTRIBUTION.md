# Attribution and trademarks

## Icons

- **Material Symbols / Material Design Icons** — Apache License 2.0.
  The settings, apps, play, HDMI, AV, Live TV, gamepad and speaker glyphs were
  rendered from `@material-design-icons/svg`.
- **Simple Icons** — CC0 1.0. PlayStation, Raspberry Pi and Nintendo Switch
  marks.
- **App icons** (Netflix, YouTube, Disney+, etc.) are trademarks of their
  respective owners. They are included only so a personal, sideloaded launcher
  can show crisp artwork. They are **not** covered by this project's MIT
  license. Remove or replace them if you redistribute this project.
- Glass panel, pill, spotlight, glow and ring assets were generated for this
  project.

## Fonts

- **Outfit** by Rodrigo Fuenzalida — SIL Open Font License 1.1. Bundled as
  `channel/fonts/Outfit-Light.ttf` and `Outfit-Regular.ttf`.

## Brand

- **LHD / Left Hand Designs** name and hand+HD logo belong to shuff57 and are
  used as the project's mark, with the project.

## Services and platforms

- **Roku** and **Roku OS** are trademarks of Roku, Inc. This project is not
  affiliated with or endorsed by Roku. It relies on developer mode and the
  [External Control Protocol](https://developer.roku.com/docs/developer-program/debugging/external-control-api.md).
- **Immich** — photo library API; see the Immich project for its license.
- **Open-Meteo** — weather data used by the screensaver.
- The browser preview uses an Unsplash image as a fallback when Immich is not
  configured; Unsplash images remain subject to the Unsplash license.

## Daybreak (merged 2026-11-09)

`channel/components/DaybreakScene.*`, `channel/components/DataTask.xml`,
`channel/components/SpeedTask.*`, `channel/components/data/`,
`channel/components/screens/`, `channel/components/ui.brs`,
`channel/components/overlays.brs`, `channel/source/lib/`, the fonts and the
icons come from Daybreak by John B. Roberts (roberjo/tv-check), MIT licence.
They are unmodified except:

- `components/data/sources.brs`: `newsQueries()` returns an empty list when the
  config has no news block, instead of raising a dot-operator error and stopping
  every other feed for the session.
- `components/data/fetch.brs`: the refresh error prints the backtrace.

In this build Daybreak is the screensaver (`RunScreenSaver` in
`source/main.brs`); LHD remains the launcher.
