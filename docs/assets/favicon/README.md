# Favicon source image

`moto-original-822x540.png` is the pre-optimization original of the Syndicate lion
artwork, archived here as the crop source for the site's favicons.

| Property | Value |
|----------|-------|
| Source | `https://syndicate-development.com/moto.png` |
| Retrieved | 2026-08-04 |
| Dimensions | 822 × 540 |
| Format | PNG, 8-bit/color RGBA, non-interlaced, transparent background |
| Size | 298,344 bytes |
| SHA-256 | `fb713abd8bf92ddaf312ea0ad32876d3d7260ece59e94e83464ce4c2ded4d013` |

Verify with:

```bash
shasum -a 256 docs/assets/favicon/moto-original-822x540.png
```

## Why it is committed

The source URL is the legacy site this project replaces. It stops serving at
production cutover, and it is the only public copy of this image — after cutover
the favicon crops could not be reproduced, re-exported at a new size, or checked
against what they were cut from. Committing the original keeps that possible for
as long as the repository exists.

`app/assets/images/syndicate-lion.png` is not a substitute: it is a
post-optimization 177×150 crop, too small to re-crop cleanly for a 180×180 target.

## Reproducing the crops

The three icons under `public/` are all exported from one 540×540 square taken from
the **top-left corner** of this original — `x: 0, y: 0` to `x: 540, y: 540`. That
keeps the whole roaring head, muzzle included, and drops only the trailing mane
wisp past `x: 540`.

```bash
magick docs/assets/favicon/moto-original-822x540.png -crop 540x540+0+0 +repage lion-square.png
sips -z 512 512 lion-square.png --out public/icon.png
sips -z 180 180 lion-square.png --out public/apple-touch-icon.png
sips -z 32  32  lion-square.png --out public/icon-32.png
```

`lion-square.png` is an intermediate and is not committed.

### Why the crop does not use `sips`

SPEC-012 R45 gives the crop as `sips -c 540 540 --cropOffset 0 0`. That does not
produce the crop R45's own prose describes. `sips(1)` documents `--cropOffset
offsetY offsetH` as *"Crop offset from top left corner"*, and positive offsets do
behave that way — but `0` is taken as *no offset given* and falls back to a centred
crop, which slices the lion's muzzle off the left edge.

Measured against known `magick` windows on this source (differences of a few
thousand pixels are re-encode noise, not framing):

| invocation | equivalent window | result |
|---|---|---|
| `--cropOffset 0 0` | `-crop 540x540+141+0` | centred — muzzle sliced off |
| `--cropOffset 0 1` | `-crop 540x540+1+0` | within 1px of the intended crop |
| `--cropOffset 0 282` | `-crop 540x540+282+0` | positive offsets index from the left |
| `--cropOffset 0 -141` | 399px crop, then 141 transparent columns spliced on | **pads, does not pan** |

A negative offset is not a leftward pan. It pads that many transparent columns onto
the left and clips the same number off the right, which is how an earlier attempt at
this crop shipped three icons that were a quarter empty with the mane amputated.

Check the output before shipping it. Every candidate is 540×540 and only the picture
tells them apart — `spec/lib/seo_static_files_spec.rb` now fails on any icon whose
columns are more than 5% blank, which catches the padding mistake but not a
mis-centred crop.

## What it is not

This is an archived build input, not a served asset. It sits under `docs/assets/`
rather than `app/assets/` or `public/` so that neither Propshaft nor the static
file server hands an 822×540 source image to visitors.

The crops derived from it (512×512, 180×180, 32×32) and the layout links that
reference them are specified in `docs/specs/SPEC-012-seo-aeo.md` (R45–R47) and are
not part of this directory.
