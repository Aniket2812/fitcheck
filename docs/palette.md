# Palette & Token Spine

**Surface:** Compete — Pinterest for outfits
**Mood:** neutral cream, editorial, premium, quiet
**Status:** proposed — nothing consumed by the app yet beyond `theme.js`

---

## The thesis

This is a photo app. Every screen is dominated by try-on renders, garment cards, and
outfit grids — user imagery in every color there is. The interface's job is to disappear
behind that.

So the palette is **near-monochrome: warm cream and ink, and essentially nothing else.**
There is no brand accent color. Hierarchy comes from contrast, fill, and weight — not hue.

Cream specifically — rather than a cool gray — for two reasons:

1. **Skin tones.** A cool gray-blue canvas casts every try-on render slightly sallow. Warm
   cream sits behind skin without fighting it. In an app whose payoff is *you* wearing
   something, that matters more than it would elsewhere.
2. **Premium reads warm.** Pure `#FFFFFF` reads as "unstyled default." Cream reads as a
   deliberate choice — gallery wall, not blank canvas.

**The one exception:** photo wells stay pure white in *both* light and dark themes. A
garment shot on a cream ground picks up a warm cast and the color is a lie. Since users may
buy based on what they see, the try-on surface is a lightbox — white, always.

---

## Layer 1 — Primitives

Named for **values**, never roles. Nothing in the app should reference these directly.

### Sand (warm neutral ramp) — the whole palette

| Token | Hex | |
|---|---|---|
| `sand.50`  | `#FDFCF9` | |
| `sand.100` | `#FAF7F1` | canvas |
| `sand.200` | `#F3EFE7` | |
| `sand.300` | `#E8E3D9` | |
| `sand.400` | `#D6CFC2` | |
| `sand.500` | `#B5AD9F` | |
| `sand.600` | `#8C8477` | |
| `sand.700` | `#5E574C` | |
| `sand.800` | `#423C33` | |
| `sand.900` | `#211E18` | ink |
| `sand.950` | `#15130F` | dark canvas |

Warm but greige — pulled off pure yellow so it reads as paper, not custard.

### Bronze (Outfit of the Day only)

| Token | Hex | |
|---|---|---|
| `bronze.100` | `#EFE7D6` | |
| `bronze.400` | `#B99F6E` | |
| `bronze.500` | `#967C4E` | |

Muted, not gold-leaf. Reserved — this is the **only** decorative chroma in the app, and it
appears exclusively on the OOTD badge and winner treatment. If it shows up anywhere else it
stops meaning "won."

### Status — the only other chroma

| Token | Hex |
|---|---|
| `olive.500` (success) | `#5F6E56` |
| `ochre.500` (warning) | `#9A7B3F` |
| `brick.500` (error) | `#8F4A42` |
| `slate.500` (info) | `#55656B` |

Heavily desaturated to sit inside the neutral world. They're legible and distinct from each
other, but they never read as "brand color" — which is the point. In a palette this quiet,
a status color carries real weight because it's the only thing on screen with hue.

---

## Layer 2 — Semantics

Named for **roles**. This is what components consume.

### Surface stack

| Role | Light | Dark |
|---|---|---|
| `surface.canvas` | `#FAF7F1` | `#15130F` |
| `surface.raised` | `#FFFFFF` | `#1E1B16` |
| `surface.overlay` | `#FFFFFF` | `#27231C` |
| `surface.sunken` | `#F3EFE7` | `#0E0C09` |
| `surface.inverse` | `#211E18` | `#FAF7F1` |
| `surface.photo` | `#FFFFFF` | `#FFFFFF` |

`surface.photo` not switching is deliberate — see the thesis.

### Text

| Role | Light | Dark | Contrast on canvas |
|---|---|---|---|
| `text.primary` | `#211E18` | `#F3EFE7` | ~15:1 ✅ |
| `text.secondary` | `#5E574C` | `#B7AF9F` | ~7:1 ✅ AA all sizes |
| `text.muted` | `#8C8477` | `#877F70` | ~3.5:1 ⚠️ |
| `text.onAccent` | `#FDFCF9` | `#15130F` | |

⚠️ **`text.muted` fails AA for body copy.** It's for ≥18px text or genuinely non-essential
metadata (timestamps, like counts). Anything a user needs to read is `text.secondary` or darker.

### Border

| Role | Light | Dark |
|---|---|---|
| `border.subtle` | `#EFEAE0` | `#2B261E` |
| `border.default` | `#E4DED2` | `#373127` |
| `border.strong` | `#CFC7B8` | `#4B4438` |

On cream, prefer hairline borders over shadows for separation. Shadows on a warm ground
muddy fast.

### Accent — ink, not a color

| Role | Light | Dark |
|---|---|---|
| `accent.default` | `#211E18` | `#F3EFE7` |
| `accent.hover` | `#423C33` | `#FFFFFF` |
| `accent.subtle` | `#F3EFE7` | `#27231C` |
| `accent.border` | `#D6CFC2` | `#4B4438` |

The primary action is an **ink button on cream** — and in dark mode it inverts to a cream
button on ink. This is the Aesop/COS move, and it's the single biggest reason the palette
reads premium rather than default.

### OOTD

| Role | Light | Dark |
|---|---|---|
| `ootd.default` | `#967C4E` | `#B99F6E` |
| `ootd.subtle` | `#EFE7D6` | `#2C2517` |
| `ootd.border` | `#B99F6E` | `#5A4C2C` |

---

## What replaces the accent color

Removing hue means **state has to be carried by fill and weight instead.** This is a
constraint, not an oversight — design around it deliberately:

| State | Signal |
|---|---|
| Like — inactive | Outline heart, `text.muted` |
| Like — active | **Filled** heart, `text.primary` |
| Selected variant | 2px `border.strong` ring + `surface.raised` lift |
| Primary action | Solid ink fill |
| Secondary action | Hairline border, transparent fill |
| Disabled | `surface.sunken` fill, `text.muted` label |

If a state ever feels ambiguous, the fix is **more contrast or more fill weight** — not
reintroducing a hue. The moment a second color enters, the photos stop being the loudest
thing on screen and the whole premise weakens.

---

## Intentional dark mode

Dark is not an inversion. Specifically:

- `surface.canvas` is `#15130F`, a **warm-tinted near-black** — never `#000000`. Pure black
  against warm photography looks like a rendering bug.
- The accent genuinely flips: ink-on-cream becomes cream-on-ink.
- **Shadows are replaced by border rings.** Elevation via shadow doesn't read on dark
  ground; `border.default` at 1px does the same job.
- Status colors lighten slightly to hold contrast against the dark canvas.
- Photo wells stay white — the lightbox rule holds in both themes.

---

## Layer 3 — the other four categories

### Spacing — 4px base
`0, 2, 4, 8, 12, 16, 20, 24, 32, 40, 48, 64`

### Type scale — ~1.2 ratio
`12, 13, 15, 17, 20, 24, 30, 36`

Body 15/17. System font (SF Pro / Roboto) for UI. In a palette with no color, **typography
carries more of the hierarchy than usual** — be deliberate about weight steps (400/500/600)
and don't rely on size alone.

### Radii
`0, 4, 8, 12, 16, 24, 999`

Cards at 16, buttons at 12, avatars/pills at 999. Garment thumbnails at 12.

### Shadows — warm-tinted, two-layer

Shadow color is `rgba(33, 30, 24, α)` — **never** `rgba(0,0,0,α)`. A black shadow on cream
reads as grime; a warm one reads as depth. Two layers (tight key + soft ambient).

React Native needs both `shadow*` (iOS) and `elevation` (Android) — see `theme.js`.

### Motion
`instant 120ms · fast 180ms · base 240ms · slow 320ms`, ease-out for enters.

### Z-index
`base 0 · dropdown 10 · sticky 100 · modal 1000 · toast 10000`

---

## Notes & gaps

- **OKLCH isn't available.** React Native's color parser accepts hex/rgb/hsl only, so these
  are sRGB hex. The ramp was still spaced perceptually rather than by even hex steps.
- **Component tokens (layer 3) are deliberately not defined yet** — no components exist to
  derive them from. Add them when the outfit card and vote button are built.
- Contrast figures are computed against `surface.canvas`. Re-check anything landing on
  `surface.sunken`.
- **The risk of a monochrome palette is flatness.** The mitigation is surface separation
  (white cards on cream canvas) and disciplined type weight — not color. If screens start
  looking muddy, add contrast between surface levels before adding hue.
