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
sips -c 540 540 --cropOffset 0 -141 docs/assets/favicon/moto-original-822x540.png --out lion-square.png
sips -z 512 512 lion-square.png --out public/icon.png
sips -z 180 180 lion-square.png --out public/apple-touch-icon.png
sips -z 32  32  lion-square.png --out public/icon-32.png
```

`lion-square.png` is an intermediate and is not committed.

`sips --cropOffset` measures from the **centre** of the source, not the top-left
corner, and it takes its arguments as `offsetY offsetX`. A top-left anchored crop
therefore needs `-141` on the X axis — half the 282px the 822px-wide source
overhangs the 540px square. SPEC-012 R45 gives this line as `--cropOffset 0 0`,
which silently produces a centre crop with the lion's muzzle sliced off the left
edge. Check the output before shipping it; both crops are 540×540 and only the
picture tells them apart.

## What it is not

This is an archived build input, not a served asset. It sits under `docs/assets/`
rather than `app/assets/` or `public/` so that neither Propshaft nor the static
file server hands an 822×540 source image to visitors.

The crops derived from it (512×512, 180×180, 32×32) and the layout links that
reference them are specified in `docs/specs/SPEC-012-seo-aeo.md` (R45–R47) and are
not part of this directory.
