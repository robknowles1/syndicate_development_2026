# Research Finding: Logo Background Transparency — Conversion Options

**Feeds:** SPEC-015 (Nav Bar Logo — Admin-Replaceable Site Branding)
**Date:** 2026-09-03
**Author:** spec-agent
**Status:** informational — not independently testable; its conclusion is consumed by SPEC-015's Non Goals, R3, and Implementation Decisions.

---

## Question

Doug will occasionally upload a replacement logo from his phone. The current logo (`syndicate-lion.png`) has a transparent background so it sits correctly on the nav's `#242121` band; a logo saved with a solid (usually white) background renders as a visible rectangle instead. The repo owner asked: **is there a conversion API worth calling to make an uploaded logo transparent automatically**, and if not, what should v1 do instead?

## Method

Web search conducted 2026-09-03 against: hosted background-removal APIs (remove.bg, Photoroom, Clipdrop, Cloudinary), self-hosted offline models (`rembg`/U²-Net/ISNet), and libvips' own compositing/relational operations. Findings below are sourced from the linked pages; pricing pages for this category change often and several aggregator sites disagreed with each other on exact figures (see "What Could Not Be Verified").

## Finding 1: Hosted background-removal APIs

| Service | Pricing (as found) | Notes |
|---|---|---|
| remove.bg | ~$0.20/image on standard API plans; pay-as-you-go from $1/image; subscription tiers $9–$89/mo for 40–500 credits | Free tier exists but is capped to standard definition |
| Photoroom | $0.02/image (Basic "Remove Background" plan); $20/mo ≈ 1,000 images; $0.10/image on the Plus/editing tier | 10 free production calls on signup |
| Clipdrop | Now folded into Jasper (Stability AI sold the parent company in 2024); API access reportedly requires a Jasper Business plan; older per-call figures around $0.002–$9/mo tiers are inconsistent across sources | The product's ownership/API surface changed since Stability AI operated it — treat any specific price as unverified |
| Cloudinary AI Background Removal add-on | Being deprecated — accounts created after Feb 1, 2026 cannot subscribe to the add-on at all; functionality is folding into a core transformation | Not a stable option to build against going forward |

Every option in this table means **sending Doug's logo file to a third-party service** — a new external HTTP call, a new API key held in Rails credentials, a new secret to rotate, and a runtime dependency on that vendor's uptime, for a feature this app would use maybe once every few years.

Sources:
- [remove.bg Pricing 2026: Free, Lite & Pro Plans from $9/mo](https://comparedge.com/tools/remove-bg/pricing)
- [remove.bg: Pricing, Features, and Integration in 2026](https://www.softwaresuggest.com/remove-bg)
- [Pricing | Photoroom API Documentation](https://docs.photoroom.com/remove-background-api-basic-plan/pricing)
- [Photoroom API: Pricing & Plans | Photoroom](https://www.photoroom.com/api/pricing)
- [Clipdrop review 2026 — AI image editing & generation](https://www.toolsforhumans.ai/ai-tools/clipdrop)
- [Comprehensive Guide to Clipdrop: Pricing, API, Legitimacy & Synchronization](https://therightgpt.com/clipdrop-background-removal-tools/)
- [Does Cloudinary support removing the background from a given image? – Cloudinary Support](https://support.cloudinary.com/hc/en-us/articles/202520312-Does-Cloudinary-support-removing-the-background-from-a-given-image)
- [Cloudinary's AI Background Removal: Understanding the Shift in Pricing and Functionality](https://www.oreateai.com/blog/cloudinarys-ai-background-removal-understanding-the-shift-in-pricing-and-functionality/8a35baaf26ede8a791aa7447fd4e96a1)

## Finding 2: Self-hosted / offline models (`rembg` and similar)

`rembg` wraps U²-Net/ISNet ONNX models. The base `u2net` model is ~176 MB (downloaded on first use); lighter variants (`u2netp` ~4.7 MB, `silueta` ~43 MB) trade accuracy for size. It runs via `onnxruntime` and is a **Python** tool — CLI, Python library, or HTTP server. A community-reported Docker image for `rembg` runs to roughly **1.8 GB**, driven mostly by `onnxruntime`.

Weighed against this app's actual deployment: a single small OVH box, deployed via Kamal, Ruby-only, no Node build step, **no Python runtime today**. Adding `rembg` means one of:
- Bundling a Python interpreter, `onnxruntime`, and a ~176 MB model file into the app's own image — a second language runtime and a large model asset for one admin screen used rarely, on a box sized for a static marketing site.
- Running it as a second Kamal-managed service/container the Rails app calls over HTTP — a second thing to deploy, patch, and keep alive, for the same rare use.

Either shape is a standing operational cost for a feature that isn't a recurring workload.

Sources:
- [GitHub - danielgatis/rembg](https://github.com/danielgatis/rembg)
- [rembg · PyPI](https://pypi.org/project/rembg/)
- [rembg Background Removal: Local CLI, Python, Docker, and GPU Guide](https://knightli.com/en/2026/04/19/rembg-background-removal-notes/)
- [why docker image size is very big · Issue #51 · danielgatis/rembg](https://github.com/danielgatis/rembg/issues/51)

## Finding 3: Testing the starting hypothesis — this is not a background-removal problem

AI background-removal/matting models (U²-Net, ISNet, and the hosted APIs above) exist to solve a genuinely hard problem: separating a photographed foreground from a background across soft, high-detail edges — hair strands, fur, foliage, motion blur — where no single background color can be thresholded away. That is not what a logo upload is. A logo saved by a shop owner or a designer is, in the overwhelming common case, flat vector-derived artwork on a **solid, uniform background color** (almost always white). Detecting "pixels near this one known color" and zeroing their alpha is the classic **chroma-key** problem, not the matting problem — deterministic, cheap, and decades older than any ML model.

`libvips` — already a Gemfile dependency (`ruby-vips`) used by `ImageAttachmentValidatable` and every existing variant method in this app — can do this directly, in-process, with no new dependency. A maintainer-described technique from the libvips project itself ([libvips/libvips discussion #2474](https://github.com/libvips/libvips/discussions/2474)) chains:

1. A per-pixel distance calculation from a target color (e.g. white) using ordinary arithmetic/relational image operations (`relational_const` for exact matches, or a Pythagorean-distance calculation for near-matches with a tolerance).
2. Scaling that distance into an alpha value (0 for "is the background color," 255 for "is clearly foreground," graded in between for anti-aliased edge pixels).
3. `extract_band` to take the original RGB bands and `bandjoin` (or `addalpha`) to attach the computed alpha band, producing a 4-band RGBA image.

`ruby-vips` is a direct binding over the same libvips C operations `pyvips` uses, so the same operation names (`relational_const`, `bandbool`/`boolean`, `extract_band`, `bandjoin`) are available from Ruby. No new gem, no API key, no network call, no per-conversion cost, no additional Kamal service.

**Caveat, stated honestly:** this only helps when the background genuinely is a flat, near-uniform color. It will not produce a good result on a photographed logo against a textured or gradient background, and a naive fixed tolerance can leave a visible fringe/halo, or — worse — eat into logo pixels that are legitimately near-white by design (a white outline stroke, for instance). It is a narrower tool than AI matting, but it is the *right-shaped* tool for the actual input (flat-color logo art), not a downgrade from it.

**Conclusion on the hypothesis:** correct. This is a chroma-key problem, not a background-removal problem, and the tool for it is already installed.

## Finding 4: Should any conversion belong in v1 at all?

No. Recommendation: **do not build an auto-conversion feature in v1 — hosted API or local chroma-key.**

Reasoning:
- **Frequency doesn't justify the engineering.** The logo changes on the order of "almost never." Every option researched here — a paid third-party API integration or an in-house libvips chroma-key routine — is real, ongoing engineering and maintenance surface (secrets, error handling for a flaky third-party call, or tuning/testing a tolerance-based algorithm) built for an event that happens a handful of times over the life of this site.
- **A fallible auto-fix is worse than no auto-fix, on this admin's terms.** Even the technically-right libvips chroma-key approach can silently produce a bad result — a color fringe, or logo detail eaten because it was near-white — and there is no design review step in a single-admin, phone-only flow to catch that. The repo owner's own framing applies directly here: a "convert my logo" button that sometimes mangles the result is worse than no button, because it invites trust in an automated step that Doug has no way to sanity-check except by looking at the very same nav-background preview that (mitigation 1, SPEC-015 R15/R16) already exists as the real safety net.
- **Telling Doug what to upload, plus showing him the result before it's live, is strictly cheaper and strictly more reliable than any conversion path.** If Doug uploads a PNG or WebP that was correctly exported with transparency, the feature works perfectly with zero conversion logic. The instruction ("upload a PNG or WebP with a transparent background") is not a hard ask — it's the default export option in every tool that produces logo art (Illustrator, Canva, Photoshop, Figma) — and the live preview (R16) tells him immediately, before saving, whether he got it right.
- **This is a deferred, not a rejected, decision.** If Doug reports in practice that he genuinely cannot produce a transparent-background file himself — e.g. he only has a phone photo of a printed logo, or a JPEG a sign shop emailed him — that is the trigger for a v2 follow-up. At that point, the libvips chroma-key approach (never the hosted API — Findings 1–2 make the cost/privacy/ops case against it) is the one worth prototyping first, and it becomes a *smaller* problem than it looks today: Doug would only need a manual "make near-white pixels transparent" affordance for the person who ignored the instructions and uploaded a solid-background file, not a general-purpose matting feature.

## What Could Not Be Verified

- **Exact current pricing** for remove.bg, Photoroom, and Clipdrop/Jasper. Multiple aggregator/comparison sites returned different numbers for the same service (e.g. remove.bg quoted at both a flat $0.20/image API rate and a $1/image pay-as-you-go rate by different sources), and this category's pricing pages change on a similar cadence to this research. Treat every dollar figure in Finding 1 as directional, not contractual — the same posture SPEC-013's R10 takes toward a risk it names but does not claim certainty about.
- **Clipdrop's current API availability** specifically — its docs now point toward Jasper's own image-API surface following the ownership change, and this research did not confirm whether a standalone Clipdrop background-removal endpoint is still independently reachable.
- **Real-world tolerance tuning** for the libvips chroma-key technique (Finding 3) was not prototyped or benchmarked here — the technique is established and the operations exist, but this research is a literature/API survey, not an implementation trial. This is exactly why Finding 4 recommends deferring it rather than building it speculatively now.

## Recommendation Summary (feeds SPEC-015)

1. No conversion API integration in v1 (Non Goals).
2. No local libvips chroma-key conversion in v1 either — deferred, named explicitly as the v2 path if Doug reports needing it.
3. v1 ships: (a) a narrower content-type allowlist that rejects JPEG for this slot with an explanatory message, (b) a live pre-save preview against the real `#242121` nav background, (c) a non-blocking opacity warning using `Vips::Image#has_alpha?`/alpha-band-minimum (cheap, already-available, no conversion involved), (d) the bundled lion as a permanent, restorable fallback.
