---
version: alpha
name: Axiom Glass
description: LHD's warm off-white glass language, applied to the Daybreak screens on a TCL Roku TV.
colors:
  primary: "#FFD166"
  ink: "#0A0A0F"
  ink-deep: "#07070B"
  glass: "#F4F3F0"
  hairline: "#F4F3F0"
  text: "#F4F3F0"
  text-2: "#F4F3F0A8"
  text-3: "#F4F3F066"
  accent: "#FFD166"
  sun: "#F4A259"
  rain: "#7FB7E8"
  night: "#B3A6F2"
  calm: "#9EC79B"
typography:
  clock:
    fontFamily: Outfit
    fontSize: 142px
    fontWeight: 200
    lineHeight: 0.92
    letterSpacing: "-0.02em"
  h1:
    fontFamily: Outfit
    fontSize: 76px
    fontWeight: 300
    lineHeight: 1.05
  h2:
    fontFamily: Manrope
    fontSize: 44px
    fontWeight: 600
    lineHeight: 1.15
  body:
    fontFamily: Manrope
    fontSize: 26px
    fontWeight: 400
    lineHeight: 1.35
  label:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.08em"
rounded:
  card: 30px
  pill: 32px
  chip: 18px
  dot: 999px
spacing:
  margin: 112px
  gutter: 32px
  card-pad: 36px
  row: 24px
components:
  card:
    backgroundColor: "{colors.glass}"
    textColor: "{colors.text}"
    rounded: "{rounded.card}"
    padding: 36px
  card-dim:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.text-2}"
    rounded: "{rounded.card}"
    padding: 36px
  pill:
    backgroundColor: "{colors.ink-deep}"
    textColor: "{colors.text}"
    rounded: "{rounded.pill}"
    padding: 12px
  accent-dot:
    backgroundColor: "{colors.accent}"
    rounded: "{rounded.dot}"
    size: 12px
---

# Overview

Axiom Glass is the visual language of the LHD launcher on this TV, written down so the Daybreak
screens can wear the same clothes. It is one photograph, darkened, with a few plates of frosted
white floating over it. Nothing has a solid fill; nothing is pure white; one amber accent marks the
only thing that matters on a screen.

The rules are deliberately narrow. Warm off-white text, never grey. One accent, never two. Cards
read as glass because they are the text colour at 6-10 percent over the photo, with a hairline at 14
percent and a large corner radius - not because anything is blurred (SceneGraph has no blur; LHD gets
its softness from baked glow images, and so do we).

# Colors

- **Ink (#0A0A0F)** - the scrim over every photo, and the fill when no photo is loaded. Never used as
  a card fill; cards are glass over the photo.
- **Glass (#F4F3F0)** - the plate. Drawn at 0.06-0.10 opacity, so the photo's colour comes through and
  every card picks up the scene behind it.
- **Hairline (#F4F3F0)** - 1 px border at 0.14. It is what makes a plate read as an edge rather than a
  smudge.
- **Text ramp** - `#F4F3F0` full for what you must read, `A8` for secondary, `66` for metadata and
  photo credits. Same hue at three alphas, never a second grey.
- **Accent (#FFD166)** - amber, LHD's own. One per screen: the focused tile, the next event, the one
  warning that matters.
- **Weather tints** - `sun`, `rain`, `night`, `calm` appear only inside weather iconography and the
  weather grade overlay, never as a plate or text colour.

# Typography

Outfit for numbers and the clock, because its light weights stay legible at 142 px. Manrope for
everything else. Nothing below 24 px: at living-room distance that is the floor, not a preference.
Eyebrow labels are Manrope 600 with 0.08em tracking, uppercase.

# Layout

1920x1080. Side margin 112 px. Twelve columns of 112 px with 32 px gutters; `gx(c)` and `gw(n)` in
`ui.brs` do the arithmetic. Cards sit on the grid, 32 px apart, never touching the edge.

# Elevation & Depth

Four layers, in this order and no others:

1. Photo, full bleed.
2. Scrim: ink at 0.55 for photo-led screens (ambient), 0.78-0.82 where cards carry the screen.
3. Glass plate: text colour at 0.06-0.10, radius 30.
4. Hairline: 1 px, 0.14. Text sits on top with a soft shadow, never on bare photo.

There is no drop shadow and no blur. Depth comes from the scrim and the hairline.

Contrast note: `designmd lint` compares a component's `textColor` with its `backgroundColor` as flat
colours, so a translucent plate always fails it. The pair that actually renders is text `#F4F3F0`
over ink at 0.78-0.82, which measures about 16:1 - well past WCAG AA. The `card-dim` component is
the flat equivalent the linter can check.

# Shapes

Cards and pills are 30-32 px radius, chips 18, dots 999. Corners are generous on purpose: at 1080p
a 30 px radius is the smallest that still reads as "rounded" from a couch.

# Components

- **card** - the glass plate. Used for weather, news, calendar, chores.
- **card-dim** - a plate for content that must recede: footers, credits, disabled rows.
- **pill** - a reminder or badge; ink at 0.82 with full-strength text.
- **accent-dot** - the one amber mark on a card header.

# Do's and Don'ts

- Do keep one accent per screen. Do let the photo show through every plate.
- Don't add a second grey, a saturated card fill, or a border thicker than 1 px.
- Don't put text directly on a photo without the scrim, and don't use pure white.
- Don't animate anything that isn't either the data (clock, countdown) or the wallpaper (drift, grade,
  slideshow, sky). Cards fade; they do not slide.
