# Spec: Nav Bar Logo — Admin-Replaceable Site Branding

**ID:** SPEC-015
**Status:** ready
**Priority:** medium
**Created:** 2026-09-03
**Author:** spec-agent

---

## Goal

Let Doug replace the logo in the top-left of the public nav bar from the admin, using the same upload-and-fallback shape he already knows from Home/About/Gallery (SPEC-008/009/013). The logo is site-wide branding — it renders on every public page via the shared nav partial, not on any one page's content — so this spec gives it its own singleton model rather than attaching it to an existing page-content record. Because the current logo depends on a transparent background to sit correctly on the nav's `#242121` band, and because neither "PNG only" nor any other format rule can guarantee transparency, this spec's central concern is not the upload mechanism (a solved problem by SPEC-013's precedent) but making a wrong upload **visible to Doug before it's live**, and never fatal — the bundled lion remains a permanent, one-click-restorable fallback no matter what he uploads.

## Non Goals

- **Automatic background removal or format conversion**, hosted API or self-hosted. Researched and explicitly rejected for v1 — see the dependency research finding (`SPEC-015-research-logo-transparency-conversion.md`) for the full argument. Named as a possible v2 follow-up, not solved here.
- **A `published` flag or any draft/live distinction for the logo.** A logo is either uploaded (and valid) or it is not — there is no partial or in-progress state worth protecting, unlike `HomePageContent`/`AboutPageContent`'s multi-field text copy. See Implementation Decisions.
- **A second logo slot** for any other context (footer, favicon, mailer header, `og:image`/schema `image`, print). The task's measured starting facts are explicit: the current asset is used in exactly one place, and this spec keeps it that way.
- **Admin-editable alt text.** `nav.logo_alt` ("Syndicate Development") already exists, is fixed, and describes the nav's purpose (home link / brand name) independent of which image happens to render — a custom alt field would let the two drift for no benefit. Same reasoning shape as SPEC-013 R11, applied here even more directly since there's already a working static value.
- **Changing the values of `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES` or `MAX_IMAGE_SIZE`.** This spec adds an optional per-attachment content-type override (R4) so the logo can be narrower than the shared default; it does not change what Gallery, About, or Home accept.
- **Active Storage direct upload.** Same deferred-risk framing as SPEC-013 R10 — named, not solved, here. Logo files are typically small icon/wordmark art rather than full-size camera photos, so the risk is lower than for Home/About/Gallery, but it is not eliminated, so it is not silently assumed away either.
- **Image cropping, rotation, or filters.**
- **Dimension or minimum-resolution validation.** The nav box (R10/R11) handles arbitrary source dimensions by construction; no aspect-ratio or pixel-dimension validation is added.

---

## Definitions

| Term | Definition |
|------|-----------|
| logo slot | `SiteLogo#image`, the sole attachment on the new `SiteLogo` singleton. Rendered in exactly one place: `app/views/shared/_nav.html.erb`'s logo `image_tag`, on every public page. |
| static fallback | The bundled `app/assets/images/syndicate-lion.png` (177×150, PNG, real alpha channel — measured, not re-derived here). Remains in the repository permanently and is never copied into Active Storage — identical reasoning to SPEC-013 R5 / SPEC-009 R6, applied to a third slot. |
| display variant | `image.variant(resize_to_limit: [1200, 1200], saver: { quality: 80, keep: :icc })` — the tuning already established for `GalleryPhoto#display_variant`, `AboutPageContent#slideshow_display_variant`, and `HomePageContent`'s hero/CTA variants (SPEC-013 Definitions), reused rather than re-derived. |
| nav logo box | The rendered size constraint applied to whichever source is showing: `h-[50px]` (unchanged) plus a new `max-w-[160px]` and `object-contain`. See R10/R11 and Implementation Decisions for the 160px derivation. |
| `ALLOWED_LOGO_TYPES` | `SiteLogo`'s own, narrower content-type allowlist (`image/png`, `image/webp` — no `image/jpeg`), distinct from the shared `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES` that Gallery/About/Home still use unmodified. |
| fully opaque | An attached image with no alpha channel, or an alpha channel whose minimum value across every pixel is 255. Checked via `Vips::Image#has_alpha?` and the alpha band's minimum — a warn-only signal (R13), never a validation failure. |
| `ImageAttachmentValidatable` | The shared validation concern at `app/models/concerns/image_attachment_validatable.rb` (SPEC-008). This spec adds an optional `allowed_types:` keyword to its class method (R4); it does not change `ALLOWED_IMAGE_TYPES` or `MAX_IMAGE_SIZE`. |

---

## Interfaces

### Public Frontend

- Every public page (nav renders on all of them) — `app/views/shared/_nav.html.erb` line 5's `image_tag "syndicate-lion.png", alt: t("nav.logo_alt"), class: "h-[50px] w-auto"` is replaced by a call to a new shared helper (R12) that resolves the source and applies the nav logo box (R10/R11).

### Admin

New routes, new controller — this is a new singleton, not an extension of `HomePageContentsController` or any existing controller:

| Verb | Path | Action | Behavior |
|------|------|--------|----------|
| GET | /admin/site_logo | `#show` | Renders the file input, the nav-size preview swatch on a literal `#242121` background, the "remove image" checkbox, and (when applicable) the non-blocking opacity warning |
| PATCH | /admin/site_logo | `#update` | Permits `:image, :remove_image`; save-first-then-purge ordering (R17); multipart form |
| PATCH | /admin/site_logo/restore_defaults | `#restore_defaults` | Purges `image` if attached; no text fields to reset (this model has none) |

```ruby
resource :site_logo, only: [ :show, :update ] do
  patch :restore_defaults
end
```

### Data Model

New table, `site_logos` — no columns beyond `id`/`timestamps`. The entire record exists to be the polymorphic host for the `image` attachment (Active Storage attachments require a persisted `ActiveRecord` row; `SiteSetting`'s flat `key`/`value` string schema cannot hold one — see Implementation Decisions).

```ruby
class SiteLogo < ApplicationRecord
  include ImageAttachmentValidatable

  ALLOWED_LOGO_TYPES = %w[image/png image/webp].freeze

  has_one_attached :image

  validates_image_attachment :image, allowed_types: ALLOWED_LOGO_TYPES

  def display_variant
    image.variant(resize_to_limit: [ 1200, 1200 ], saver: { quality: 80, keep: :icc })
  end

  def fully_opaque?
    # true when Vips::Image#has_alpha? is false, or the alpha band's minimum is 255
  end
end
```

### Validation

`SiteLogo` includes `ImageAttachmentValidatable` and calls `validates_image_attachment :image, allowed_types: SiteLogo::ALLOWED_LOGO_TYPES` — the concern's content-type check runs against this narrower list instead of the shared `ALLOWED_IMAGE_TYPES` (R4), while the size check still runs against the unchanged shared `MAX_IMAGE_SIZE` (currently `15.megabytes` on `main` as of this spec — see Dependencies for the ordering risk if SPEC-013 lands first and raises it to 30 MB). No presence validation — an unattached slot is valid and falls back to the static file.

### Required i18n Keys

New, under `admin.site_logo`:

| Key | Purpose |
|-----|---------|
| `heading` | Page heading |
| `image_label` | Label for the file input |
| `image_hint` | Allowed types (PNG/WebP only — not JPEG), size limit, "blank keeps the current image" |
| `remove_image_label` | Label for the "remove image" checkbox |
| `using_default_label` | Shown in the preview area when no custom logo is attached |
| `opaque_warning` | Non-blocking warning shown when `fully_opaque?` is true |
| `save` | Submit button |
| `update_notice` | Flash after a successful `#update` |
| `restore_defaults_label` | Restore-to-default button |
| `confirm_restore_defaults` | Confirmation dialog text |
| `flash.restored` | Flash after a successful `#restore_defaults` |

New, under `activerecord.errors.models.site_logo.attributes.image`:

| Key | Purpose |
|-----|---------|
| `invalid_content_type` | "Logos need a transparent background — upload a PNG or WebP." Overrides the shared generic message (R5) for this model/attribute only, via Rails' standard I18n lookup order — no code branch needed for the text itself. |

New, under `admin.dashboard`:

| Key | Purpose |
|-----|---------|
| `site_logo_link` | Dashboard entry linking to `/admin/site_logo`, matching every other admin section's existing link |

`nav.logo_alt` is reused unchanged — no new key.

---

## Rules

### Data Model, Attachment, Fallback

R1: New singleton model `SiteLogo` (table `site_logos`), no columns beyond `id`/`timestamps`. Accessed exclusively via `SiteLogo.first_or_initialize`, per ADR-004 Implementation Note 1's established singleton-enforcement pattern — reused, not re-derived.

R2: `SiteLogo` gains `has_one_attached :image`, includes `ImageAttachmentValidatable`, and calls `validates_image_attachment :image, allowed_types: SiteLogo::ALLOWED_LOGO_TYPES`.

R3: `SiteLogo::ALLOWED_LOGO_TYPES = %w[image/png image/webp].freeze` — narrower than the shared `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES` (`image/jpeg image/png image/webp`). `ALLOWED_IMAGE_TYPES` itself is unchanged by this spec; `GalleryPhoto`, `AboutPageContent`, and `HomePageContent` continue to accept JPEG. This is the format-restriction mitigation the repo owner proposed, adopted because a rejected JPEG with a clear reason is strictly better than a silently-broken white rectangle on the nav — see the Research Finding for why this alone is not sufficient (R13 covers the opaque-PNG/WebP gap it leaves).

R4: `ImageAttachmentValidatable.validates_image_attachment` gains an optional `allowed_types:` keyword argument, default `nil`. When omitted (every existing caller — `GalleryPhoto`, `AboutPageContent`, `HomePageContent`), content-type validation checks against the module's `ALLOWED_IMAGE_TYPES` exactly as today. When supplied, content-type validation checks against the given list instead, for that attachment only. The file-size check (`MAX_IMAGE_SIZE`) is unaffected either way. This is additive: no existing caller's behavior changes.

R5: A rejected content type on `:image` adds the error via the same `errors.add(:image, :invalid_content_type)` call the concern already makes. The logo-specific explanation is supplied entirely through Rails' standard model+attribute-scoped I18n lookup (`activerecord.errors.models.site_logo.attributes.image.invalid_content_type`), which Rails checks before falling back to the shared `activerecord.errors.messages.invalid_content_type` string. No new error code and no message-selection branching in the concern are needed.

R6: `SiteLogo#display_variant` returns `image.variant(resize_to_limit: [1200, 1200], saver: { quality: 80, keep: :icc })` — the tuning already established for `GalleryPhoto#display_variant` / `AboutPageContent#slideshow_display_variant` / `HomePageContent`'s hero/CTA variants, reused rather than re-derived. Named `display_variant` (no prefix), matching `GalleryPhoto`'s precedent for a model with exactly one attachment.

R7: Variant/format processing must preserve the alpha channel. `resize_to_limit` with `saver: { quality: 80, keep: :icc }` does not flatten or discard transparency by default; this spec's implementation must not introduce an additional flattening/compositing step (e.g. a white-background composite) anywhere in the variant path — doing so would defeat the feature regardless of what Doug uploaded.

R8: When unattached, the logo slot falls back to the bundled `app/assets/images/syndicate-lion.png`. That file remains in the repository permanently and is never copied into Active Storage — identical reasoning to SPEC-013 R5 / SPEC-009 R6, applied to a third slot.

### Publish Gate

R9: `SiteLogo` has no `published` column and no publish gate of any kind. A successfully attached, valid `image` renders on the public nav immediately upon save; there is no intermediate "saved but hidden" state. See Implementation Decisions for the argued reasoning (citing ADR-004 and `GalleryPhoto`'s no-gate precedent) for why this departs from `HomePageContent`/`AboutPageContent`'s `published`-column pattern.

### Layout / Sizing

R10: The nav logo's rendered box is constrained on both axes: `h-[50px]` (unchanged) plus a new `max-w-[160px]`, combined with `object-contain`. This applies to whichever source renders — uploaded `display_variant` or the bundled fallback (R8) — via one shared helper (R12), so the constraint can never end up applied to only one of the two sources.

R11: `object-contain` is required alongside `max-w-[160px]`, not optional. Capping `max-width` alone on a fixed-`height` replaced element does not reliably preserve the source aspect ratio across browsers — the used-value resolution for a definite height plus a capped auto-width diverges from a definite-box-plus-`object-fit` approach. `object-contain` guarantees the image scales down to fit within the `50px × 160px` box without distortion and without overflowing either dimension. See Implementation Decisions for the 160px derivation and the mobile viewport math it's based on.

### Shared Rendering Helper

R12: One helper, `ApplicationHelper#site_logo_image_tag`, resolves the source (uploaded `display_variant` vs. bundled fallback, per R8/R9) and applies the R10/R11 CSS classes in exactly one place. `app/views/shared/_nav.html.erb`'s logo `image_tag` call and the admin preview swatch (R15) both call this same helper. This is the mechanism — not a copied class string — that keeps what Doug previews and what a visitor sees identical, mirroring SPEC-013 R12/R13's `social_share_image_url` anti-drift reasoning, applied here to prevent nav/preview drift instead of `og:image`/schema drift.

### Opacity Warning

R13: `SiteLogo#fully_opaque?` returns `true` when the attached image has no alpha channel, or has an alpha channel whose minimum value across the image is 255 (fully opaque everywhere) — checked via `Vips::Image#has_alpha?` and the alpha band's minimum, per the repo owner's proposed mitigation. `Admin::SiteLogosController#show` computes `@site_logo.image.attached? && @site_logo.fully_opaque?` on every render — not only immediately after an upload — and the view shows a non-blocking warning banner when true, so the warning persists across visits until Doug replaces or removes the image rather than being a one-time toast he could miss. The check never adds a validation error and never blocks a save: Doug may deliberately want an opaque badge-style logo (see Goal and the Research Finding's framing of this as the over-validation failure mode SPEC-014 R11 already argued this project should avoid).

### Admin UI and Controller

R14: The admin form (`app/views/admin/site_logos/show.html.erb`) has: an `f.file_field :image`, the preview swatch (R15), a "remove image" checkbox, and the opacity warning banner (R13) when applicable. This model has no text fields, so unlike Home/About's forms the image controls are the entire form.

R15: The preview swatch renders at the nav logo box (R10/R11, via the shared helper R12) inside a container whose background is the literal `bg-[#242121]` — the same hex `_nav.html.erb` uses, not an approximation — so what Doug sees in admin is representative of the public nav. On page load the swatch shows the currently persisted logo (uploaded or bundled default), guarded by `Admin::ImagePreviewsHelper#image_preview_available?(@site_logo, :image)` before calling `display_variant`, exactly as SPEC-013 established, to avoid asking an unsaved or just-rejected blob for a variant URL.

R16: A Stimulus controller, `logo_preview_controller` (`data-controller="logo-preview"`), updates the same swatch's `<img>` `src` client-side, before any form submission, the moment a file is chosen in the `:image` file input (`change->logo-preview#update`, using `URL.createObjectURL` on the selected `File`). This is the mitigation the repo owner ranked highest-value: Doug sees a wrong-background upload the instant he picks the file, not after a save round-trip. No other JavaScript is introduced; this follows CLAUDE.md's Stimulus-only convention for interactive behavior.

R17: `Admin::SiteLogosController#update` assigns the permitted params (including a new `:image` file if present) and calls `save` **first**. Only after `save` succeeds does the controller purge the `image` attachment, and only when `remove_image` was checked **and** no new file was submitted for `:image` in that same request (upload wins over removal — same tie-break shape SPEC-013 establishes for its slots). **If `save` fails — e.g. the uploaded file is rejected for content type or size — nothing is purged, and the previously-attached logo, if any, is left exactly as it was before the request.** This is a corrected ordering relative to an earlier purge-first shape that could destroy a live attachment on a request whose save ultimately failed; this spec does not repeat that shape, and it is called out explicitly here because it reads differently from the purge-then-update wording elsewhere in this codebase's spec history.

R18: `Admin::SiteLogosController#restore_defaults` purges `image` (guarded by `.attached?`) and redirects with a flash notice — functionally identical to the removal checkbox's effect for this single-attachment model, but exposed as its own control to match the "per-slot removal control plus `restore_defaults`" shape SPEC-013 R14/R17 established for Home. Kept as two controls for UI consistency with every other image-upload admin screen, not because the underlying behavior differs here.

R19: `site_logo_params` permits `:image, :remove_image`.

R20: The admin dashboard gains a link to `/admin/site_logo`, using a new `admin.dashboard.site_logo_link` i18n key, matching every other admin section's existing dashboard entry.

R21: The form, preview swatch, file input, and checkbox all follow CLAUDE.md's mobile-first rules: `w-full` file input, adequate tap padding on the checkbox label, no horizontal scroll at any viewport including 375px — the same requirement as SPEC-013 R19, applied to this screen.

R22: After a successful `#update` that attaches a new `image`, the controller synchronously processes `display_variant.processed` — matching ADR-005 Decision 5 / SPEC-013 R20's established pattern — so the admin's own post-save preview render (R15) never triggers cold variant processing.

### i18n

R23: Every new user-facing string introduced by this spec is an I18n key under `admin.site_logo`, `admin.dashboard`, or `activerecord.errors.models.site_logo.attributes.image` (R5) — no hardcoded English strings, per CLAUDE.md.

---

## Edge Cases

E1: No `SiteLogo` row exists. Nav renders the bundled fallback; admin `#show` shows the "using default" indicator and no opacity warning (the check simply doesn't run against an unattached slot).

E2: `SiteLogo` exists, `image` attached and valid. Nav renders the uploaded image immediately — no publish gate to satisfy (R9).

E3: Upload rejected for content type (e.g. `image/jpeg`). HTTP 422; no attachment persisted; the logo-specific message (R5) appears; nav continues rendering whatever was previously attached, or the fallback if nothing was.

E4: Upload rejected for size (over `MAX_IMAGE_SIZE`). HTTP 422; same no-op-on-the-existing-attachment guarantee as E3.

E5: Upload accepted (PNG/WebP, valid size) but fully opaque. Save succeeds; nav renders it as a solid rectangle against `#242121` by design, not blocked; admin `#show` displays the opacity warning banner.

E6: `remove_image` checked, no new file, `image` currently attached. Purged after the (no-op) save; nav reverts to the bundled fallback.

E7: `remove_image` checked **and** a new valid `:image` file submitted in the same request. The new file wins (R17); the slot ends attached to the new file.

E8: `remove_image` checked and a new `:image` file submitted, but that new file is rejected (bad content type or size). Save fails; **nothing is purged** — the previously-attached logo, if any, remains live. This is the case R17's corrected ordering specifically protects.

E9: `restore_defaults` called with `image` attached. Purged; nav reverts to the bundled fallback.

E10: `restore_defaults` called with nothing attached. Purge guard (`.attached?`) makes this a no-op; the action completes without raising.

E11: A wide, banner-shaped logo (e.g. ~1600×100px, ~16:1 aspect) is attached. The rendered box stays within `50px × 160px`; per R11 the image is scaled down (letterboxed) rather than distorted or allowed to overflow; no horizontal scroll occurs at 375/390/414px and the hamburger button remains fully visible and tappable.

E12: `SiteLogo.first` returns `nil` entirely (fresh deployment, before any save). Nav and admin both handle this without a `NoMethodError` — same nil-safety requirement as SPEC-013 E12 / ADR-004 Implementation Note 4.

E13: The admin form is re-rendered after a validation failure (E3/E4/E8) with a file attached-in-memory-but-unsaved on `@site_logo`. The preview swatch does not crash calling `display_variant` on that unsaved blob — `image_preview_available?` (R15) guards it, falling back to the last-persisted state instead.

---

## Acceptance Criteria

### Public Page Behavior

AC-1: Given no `SiteLogo` row exists, when any public page is rendered, then the nav logo's `image_tag` source resolves to the asset path for `syndicate-lion.png`.

AC-2: Given `SiteLogo` exists with `image` attached and valid, when any public page is rendered, then the nav logo's `image_tag` source is an Active Storage representation URL — immediately, with no publish-flag check gating it.

AC-3: In both AC-1 and AC-2, the rendered `<img>` carries `h-[50px]`, `max-w-[160px]`, and `object-contain`, is produced by `site_logo_image_tag`, and its `alt` attribute equals `t("nav.logo_alt")`.

### Admin — Upload / Validation

AC-4: Given admin is authenticated, when `PATCH /admin/site_logo` with a valid PNG under `MAX_IMAGE_SIZE`, then `SiteLogo.first.image.attached?` is `true` and the response redirects with `flash[:notice]`.

AC-5: Given admin is authenticated, when `PATCH /admin/site_logo` with a valid WebP under `MAX_IMAGE_SIZE`, then the same outcome as AC-4.

AC-6: Given admin is authenticated, when `PATCH /admin/site_logo` with `image` as `image/jpeg`, then HTTP 422, `image.attached?` is unchanged, and the response includes the `site_logo`-scoped message text ("Logos need a transparent background — upload a PNG or WebP"), not the generic "must be a JPEG, PNG, or WEBP image" message.

AC-7: Given admin is authenticated, when `PATCH /admin/site_logo` with `image` exceeding `MAX_IMAGE_SIZE`, then HTTP 422 and the response includes a file-size validation error.

AC-8: Given a `GalleryPhoto`, `AboutPageContent`, or `HomePageContent` image slot, when a valid `image/jpeg` file is attached, then validation still passes — confirming R3/R4's additive change did not narrow those models' accepted types.

### Opacity Warning

AC-9: Given a fully-opaque PNG is attached to `SiteLogo`, when `GET /admin/site_logo`, then the response includes the opacity-warning copy.

AC-10: Given a PNG with a genuine alpha channel (not fully opaque) is attached, when `GET /admin/site_logo`, then the response does not include the opacity-warning copy.

AC-11: Given a fully-opaque logo is submitted, when `PATCH /admin/site_logo`, then the save still succeeds (HTTP redirect, `image.attached?` is `true`) — confirming the check warns rather than blocks.

### Removal / Restore

AC-12: Given `image` is attached, when `PATCH /admin/site_logo` with `remove_image: "1"` and no new file, then `SiteLogo.first.image.attached?` is `false` afterward.

AC-13: Given `image` is attached, when `PATCH /admin/site_logo` with `remove_image: "1"` and a new valid `:image` file in the same request, then `image.attached?` is `true` and the attached blob is the new file.

AC-14: Given `image` is attached, when `PATCH /admin/site_logo` with `remove_image: "1"` and a new **invalid** `:image` file (wrong content type or oversize) in the same request, then HTTP 422, and `image.attached?` is still `true` with the blob still equal to the **original** attachment — neither purged nor replaced.

AC-15: Given admin is authenticated and `image` is attached, when `PATCH /admin/site_logo/restore_defaults`, then `image.attached?` is `false` afterward and the response redirects with `flash[:notice]`.

AC-16: Given admin is authenticated and nothing is attached, when `PATCH /admin/site_logo/restore_defaults`, then the action completes normally without raising.

### Layout at Mobile Breakpoints

AC-17: Given a ~16:1-aspect wide logo is attached, when `GET /` is rendered at 375px viewport width (system spec), then no horizontal scroll occurs and the hamburger button is present, visible, and clickable.

AC-18: Same as AC-17 at 390px viewport width.

AC-19: Same as AC-17 at 414px viewport width.

AC-20: Given admin is authenticated, when `GET /admin/site_logo` is rendered at 375px viewport width, then no horizontal scroll occurs and the file input carries `w-full`.

### Preview

AC-21: Given `image` is attached, when `GET /admin/site_logo`, then the response includes a preview swatch with a `bg-[#242121]` container and an `<img>` carrying the nav logo box classes (`h-[50px]`, `max-w-[160px]`, `object-contain`).

AC-22: Given nothing is attached, when `GET /admin/site_logo`, then the swatch shows the bundled default and the request does not raise.

AC-23: Given admin is authenticated, when `GET /admin/site_logo`, then the response markup includes `data-controller="logo-preview"` wiring the file input to the swatch.

AC-24: (System spec) Given the admin form is open, when a file is selected in the `:image` file input, then the preview swatch's image updates to reflect the selected file before the form is submitted, with no page reload.

### Structural / Integrity

AC-25: Given `image` is already attached, when `PATCH /admin/site_logo` with a new valid `:image` file, then exactly one `ActiveStorage::Attachment` record exists for `name: "image"` on that `SiteLogo` afterward.

AC-26: Given a successful upload, then `SiteLogo.first.image.variant(resize_to_limit: [1200, 1200], saver: { quality: 80, keep: :icc }).processed` already has a processed `ActiveStorage::VariantRecord` by the time the response returns (R22).

AC-27: Given a request is NOT authenticated, when `PATCH /admin/site_logo/restore_defaults`, then the response redirects (auth guard, unchanged) and no `SiteLogo` data changes.

AC-28: Given a PNG with a genuine alpha channel is attached, when `SiteLogo.first.display_variant.processed` is inspected, then its alpha band is still non-uniform (not flattened to fully opaque) — confirming R7.

AC-29: All new copy introduced by this spec (Required i18n Keys table) resolves through I18n — no hardcoded English strings in the new view, controller, or model code.

AC-30: The admin dashboard includes a link to `/admin/site_logo` using `admin.dashboard.site_logo_link`.

---

## Acceptance Tests

AT1
Given no `SiteLogo` row exists
When any public page is rendered
Then the nav logo resolves to the `syndicate-lion.png` asset path, with `h-[50px] max-w-[160px] object-contain` classes and `alt` equal to `t("nav.logo_alt")`
Covers: R8, R10, R12, AC-1, AC-3, E1, E12

AT2
Given `SiteLogo` exists with `image` attached and valid
When any public page is rendered
Then the nav logo is an Active Storage representation URL, immediately
Covers: R1, R2, R6, R9, R12, AC-2, E2

AT3
Given admin is authenticated
When `PATCH /admin/site_logo` with a valid PNG under the size limit
Then `SiteLogo.first.image.attached?` is `true` and the response redirects with `flash[:notice]`
Covers: R2, R14, R19, AC-4

AT4
Given admin is authenticated
When `PATCH /admin/site_logo` with a valid WebP under the size limit
Then the same outcome as AT3
Covers: R2, R3, AC-5

AT5
Given admin is authenticated
When `PATCH /admin/site_logo` with `image` as `image/jpeg`
Then HTTP 422, `image.attached?` is unchanged, and the response includes the `site_logo`-scoped rejection message, not the shared generic one
Covers: R3, R4, R5, AC-6, E3, E13

AT6
Given admin is authenticated
When `PATCH /admin/site_logo` with `image` exceeding `MAX_IMAGE_SIZE`
Then HTTP 422 and the response includes a file-size validation error
Covers: R2, AC-7, E4

AT7
Given a `GalleryPhoto`, an `AboutPageContent` slideshow slot, and a `HomePageContent` image slot
When a valid `image/jpeg` file is attached to each
Then all three remain valid
Covers: R4, AC-8

AT8
Given a fully-opaque PNG is attached to `SiteLogo`
When `GET /admin/site_logo`
Then the response includes the opacity-warning copy
Covers: R13, AC-9, E5

AT9
Given a PNG with a genuine alpha channel is attached to `SiteLogo`
When `GET /admin/site_logo`
Then the response does not include the opacity-warning copy
Covers: R13, AC-10

AT10
Given a fully-opaque logo is submitted
When `PATCH /admin/site_logo`
Then the save succeeds (redirect, `image.attached?` true) — the warning does not block
Covers: R13, AC-11, E5

AT11
Given `image` is attached
When `PATCH /admin/site_logo` with `remove_image: "1"` and no new file
Then `image.attached?` is `false` afterward
Covers: R17, AC-12, E6

AT12
Given `image` is attached
When `PATCH /admin/site_logo` with `remove_image: "1"` and a new valid file in the same request
Then `image.attached?` is `true` and the blob is the new file
Covers: R17, AC-13, E7

AT13
Given `image` is attached
When `PATCH /admin/site_logo` with `remove_image: "1"` and a new **invalid** file in the same request
Then HTTP 422 and `image.attached?` is still `true`, with the blob still equal to the original attachment — nothing purged
Covers: R17, AC-14, E8

AT14
Given admin is authenticated and `image` is attached
When `PATCH /admin/site_logo/restore_defaults`
Then `image.attached?` is `false` afterward and the response redirects with `flash[:notice]`
Covers: R18, AC-15, E9

AT15
Given admin is authenticated and nothing is attached
When `PATCH /admin/site_logo/restore_defaults`
Then the action completes normally without raising
Covers: R18, AC-16, E10

AT16
Given a ~16:1-aspect wide logo fixture is attached
When `GET /` is rendered at 375px, 390px, and 414px viewport widths (system spec)
Then no horizontal scroll occurs at any of the three widths and the hamburger button stays visible and clickable
Covers: R10, R11, AC-17, AC-18, AC-19, E11

AT17
Given admin is authenticated
When `GET /admin/site_logo` is rendered at 375px viewport width (system spec)
Then no horizontal scroll occurs and the file input carries `w-full`
Covers: R21, AC-20

AT18
Given `image` is attached
When `GET /admin/site_logo`
Then the response includes a `bg-[#242121]` preview swatch containing an `<img>` with `h-[50px] max-w-[160px] object-contain`
Covers: R12, R15, AC-21

AT19
Given nothing is attached
When `GET /admin/site_logo`
Then the swatch shows the bundled default and the request does not raise
Covers: R15, AC-22, E1, E12

AT20
Given admin is authenticated
When `GET /admin/site_logo`
Then the markup includes `data-controller="logo-preview"` on the preview/file-input wiring
Covers: R16, AC-23

AT21
Given the admin form is open (system spec)
When a file is selected in the `:image` file input
Then the preview swatch updates to the selected file's contents before the form is submitted, with no page reload
Covers: R16, AC-24

AT22
Given `image` is already attached
When `PATCH /admin/site_logo` with a new valid `:image` file
Then exactly one `ActiveStorage::Attachment` exists for `name: "image"` afterward
Covers: R17, AC-25

AT23
Given admin is authenticated
When `PATCH /admin/site_logo` attaches a new `image`
Then an `ActiveStorage::VariantRecord` for the display variant already exists by the time the response returns
Covers: R22, AC-26

AT24
Given no active admin session
When `PATCH /admin/site_logo/restore_defaults`
Then the response redirects and no `SiteLogo` data changes
Covers: R18, AC-27

AT25
Given a PNG with a genuine alpha channel is attached
When `SiteLogo.first.display_variant.processed` is inspected
Then its alpha band remains non-uniform, not flattened to opaque
Covers: R7, AC-28

AT26
Given the `admin.site_logo.*`, `admin.dashboard.site_logo_link`, and `activerecord.errors.models.site_logo.attributes.image.invalid_content_type` i18n keys
When inspected
Then all resolve to non-blank English copy and none of this spec's new view/controller code contains a hardcoded string
Covers: R23, AC-29

AT27
Given the admin dashboard
When rendered
Then it includes a link to `/admin/site_logo` via `admin.dashboard.site_logo_link`
Covers: R20, AC-30

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-03 | New `SiteLogo` singleton, not a field on `HomePageContent`, not a `SiteSetting` row | The nav renders on every public page, not on Home specifically — attaching the logo to `HomePageContent` would be semantically wrong (it would couple site-wide branding to one page's `published` flag) and is explicitly what the task asked this spec to avoid. `SiteSetting` is a flat `key`/`value` string store (`validates :value, presence: true`, a string column) with no path to `has_one_attached` without contorting its schema around one exceptional row — and Active Storage attachments require a persisted `ActiveRecord` row as their polymorphic host regardless, so a dedicated table is the only structurally clean option. ADR-004 Decision 1's reasoning for a dedicated table over a KV store — a poor fit for anything that doesn't reduce cleanly to flat strings — applies here even though `SiteLogo` (unlike `HomePageContent`) has no text fields at all: the payload itself (an attachment) is the thing that doesn't fit KV storage, not any per-field typing concern. |
| 2026-09-03 | No `published` column; no publish gate of any kind (R9) | ADR-004 frames `published` as a *content substitution switch* protecting an in-progress or intentionally-withheld draft state — `HomePageContent`/`AboutPageContent` need it because their text fields can be saved half-written. A logo attachment has no such intermediate state: `ImageAttachmentValidatable` already validates content-type and size synchronously at save time, so the only two states that exist are "no custom logo" (bundled default renders) and "a valid custom logo is attached" (it renders) — there is no "saved but intentionally not yet live" state to gate. `GalleryPhoto` is the closer precedent here, not `HomePageContent`: it is also a single, unconditional visual asset with no publish flag, and once a photo passes validation it is simply live. Adding a flag to `SiteLogo` would only introduce a way to be confused about why a validly-attached image isn't showing, which is exactly the "phantom inconsistency" ADR-004's Consequences section warns a co-located flag is meant to prevent, not create. |
| 2026-09-03 | `max-w-[160px]` chosen as the nav logo box's width cap (R10) | At 375px viewport width, the nav (`px-4`, i.e. 16px each side) leaves roughly 343px of interior width; the hamburger button and its own margin consume roughly 40–44px on the right. A logo capped at 160px wide, plus its 16px left inset, ends at ~176px from the left edge — comfortably clear of the ~331px point where the hamburger's left edge begins, with margin to spare. At the fixed 50px height, 160px allows aspect ratios up to ~3.2:1 before letterboxing kicks in (R11) — wide enough for a realistic wordmark-plus-icon lockup, well beyond the current asset's near-square ~1.18:1 ratio, while still leaving no scenario where a wider upload can force horizontal scroll or crowd the hamburger off-screen. |
| 2026-09-03 | `object-contain` required alongside the fixed height and capped max-width (R11) | A definite `height` plus a capped `max-width` on a replaced element (an `<img>`) does not, by itself, reliably force the browser to shrink both dimensions in lockstep to preserve the source aspect ratio — the used-value resolution for that combination is inconsistent across the CSS sizing algorithms browsers actually implement. `object-fit: contain` sidesteps the ambiguity entirely: it fixes the box via `height`/`max-width` first, then scales the image *content* to fit inside that box without distortion, which is the guarantee this spec actually needs (no stretching, no overflow) regardless of source aspect ratio. |
| 2026-09-03 | `allowed_types:` as an optional keyword on `ImageAttachmentValidatable.validates_image_attachment`, not a subclass, a second concern, or a model-level override method | The concern is shared infrastructure `GalleryPhoto`, `AboutPageContent`, and `HomePageContent` all depend on identically (ADR-005 Implementation Note 3, cited by SPEC-013's own R8 rationale). A subclass or parallel concern would fork that shared behavior for content-type checking while still sharing the size check, which is more moving parts than the actual difference (one narrower list, for one model) justifies. An additive, default-`nil`-falls-back-to-current-behavior keyword argument is the smallest change that lets `SiteLogo` diverge on exactly the one axis it needs to (content types) without touching any existing caller's behavior or requiring them to pass a new argument to keep working. |
| 2026-09-03 | Content-type rejection message uses Rails' built-in model+attribute-scoped I18n lookup rather than a new error symbol or in-concern conditional | `errors.add(name, :invalid_content_type)` already triggers Rails' standard lookup order — `activerecord.errors.models.<model>.attributes.<attribute>.<key>` before the generic `activerecord.errors.messages.<key>` fallback. Adding the `site_logo`-scoped translation gets the narrower, explanatory copy for free, with zero changes to the concern's error-raising code — only the locale file gains a key. This is the "without breaking the shared concern" mechanism the task asked for: the concern doesn't need to know that `SiteLogo`'s message differs at all. |
| 2026-09-03 | R17's purge-only-after-a-successful-save ordering is stated explicitly here, diverging from the purge-first wording currently written into this codebase's own SPEC-013 R15 | A purge-before-save shape is a data-loss bug: if the new file in the same request fails validation, the record's `save` fails, but a purge that already ran destroys the previously-live attachment anyway — the admin sees a validation error while the public site has already lost its logo. This spec's controller is new code, not a modification of `Admin::HomePageContentsController`, so it is free to implement the corrected ordering directly rather than inheriting the earlier shape; it is called out at this length so a developer who has read SPEC-013 first does not "fix" `SiteLogosController#update` by copying that spec's literal purge-first wording under the assumption it's the established pattern. |
| 2026-09-03 | No automatic background-removal or transparency-conversion feature in v1 (Non Goals; R3/R13 stand in for it) | Full research and reasoning live in `SPEC-015-research-logo-transparency-conversion.md`, cited here rather than restated. Summary: every hosted API researched (remove.bg, Photoroom, Clipdrop, Cloudinary) means sending Doug's logo to a third party for a feature used a handful of times ever; every self-hosted option (`rembg`/U²-Net) requires a Python runtime and a large model asset this Ruby-only, Kamal-deployed single-box app does not have today; and the underlying problem is not background-removal (AI matting for photographic edges) at all but chroma-keying a flat-color background — a problem `libvips`, already a dependency, can solve deterministically and offline, but which this spec still declines to build in v1 because a fallible auto-fix without a review step is worse than plain instructions plus the live preview (R16) that already exists as the real safety net. |
| 2026-09-03 | Opacity check (R13) recomputed on every `#show` render, not only surfaced as a one-time post-upload flash | A flash message is easy to miss or dismiss and disappears on the next page load; the underlying condition ("the current logo has no transparency") is a property of the persisted state, not of the action that created it. Recomputing it on every render (cheap, per the task's own framing of `Vips::Image#has_alpha?`/alpha-band-minimum as an inexpensive check) means the warning is visible for as long as the condition is true, however many admin sessions that spans, rather than being tied to the moment of upload. |
| 2026-09-03 | `image_hint` states the size limit as it exists on `main` at the time this spec was written (15 MB) | `ImageAttachmentValidatable::MAX_IMAGE_SIZE` is `15.megabytes` as of this spec's authoring; SPEC-013 (not yet implemented as of this spec) proposes raising it to 30 MB as a shared-constant change affecting every model that includes the concern, `SiteLogo` included. Whichever of SPEC-013 or this spec is implemented second must update the other's `image_hint` copy to match — the same cross-spec staleness SPEC-013 itself flagged for SPEC-008/009's "15 MB" prose in its own Dependencies section. This spec does not resolve that ordering; it only names it, consistent with how SPEC-013 handled the identical situation one spec earlier in the chain. |

---

## Dependencies

- **SPEC-008 (Gallery Photo Management)** — provides `active_storage:install`, `ruby-vips`, and `ImageAttachmentValidatable`, reused with one additive change (R4).
- **SPEC-013 (Home Page Hero and CTA Image Uploads)** — this spec's admin-form shape (file input, thumbnail/preview, removal checkbox, `restore_defaults` purging attachments) is a direct extension of the pattern SPEC-013 established, including `Admin::ImagePreviewsHelper#image_preview_available?` (R15). **Divergence, stated explicitly:** this spec's R17 purge-ordering deliberately does not match the purge-first wording currently written in SPEC-013's own R15 — see Implementation Decisions. Whoever implements SPEC-013 should adopt the same corrected save-then-purge ordering this spec uses, rather than the literal text currently on file for SPEC-013 R15, to avoid shipping the same data-loss shape in two places. **Cross-spec staleness, same shape SPEC-013 itself flagged for SPEC-008/009:** if SPEC-013 ships first and raises `MAX_IMAGE_SIZE` to 30 MB, this spec's `admin.site_logo.image_hint` copy (written here assuming the current 15 MB) goes stale and must be updated in the same pass — see Implementation Decisions.
- **SPEC-015 Research Finding (`SPEC-015-research-logo-transparency-conversion.md`)** — the conversion-API investigation this spec's Non Goals and R3/R13 rest on; cited throughout rather than re-argued.
- **SPEC-014 (Social Media Links)** — R11's "warn, don't block" reasoning for the opacity check follows the same over-validation-avoidance argument SPEC-014 R11 already made for URL/platform mismatches on this project; cited, not re-derived.
- **ADR-004 (Singleton Content Model and Publish Flag Placement)** — governs both the dedicated-table decision and the no-publish-flag decision (R1, R9); consulted and extended, not re-derived, in Implementation Decisions.
- **ADR-005 (Photo Upload Data Model and Active Storage Strategy)** — governs the underlying attachment/variant data model and the synchronous-variant-processing-after-attach pattern (R22) this spec extends to a third area of the app.
- CLAUDE.md — mobile-first rules (R21), i18n rules (R23), and the Stimulus-only JavaScript convention (R16).
- No new gems required. `ruby-vips` (already present) is sufficient for R13; the Research Finding is explicit that no conversion gem or API client is added.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Model + migration: `SiteLogo` (R1), `has_one_attached :image` + `ImageAttachmentValidatable` + `ALLOWED_LOGO_TYPES` (R2, R3), `display_variant` (R6), `fully_opaque?` (R13). Confirm variant processing preserves alpha (R7). Factory with attachment traits (opaque and transparent fixtures). | AC-4–AC-11, AC-25, AC-26, AC-28 | 3 |
| T2 | Concern change: `allowed_types:` keyword on `ImageAttachmentValidatable.validates_image_attachment` (R4); new scoped locale key (R5). | AC-6, AC-8 | 2 |
| T3 | `ApplicationHelper#site_logo_image_tag` (R12) with the nav logo box classes (R10, R11); wire into `_nav.html.erb`. | AC-1–AC-3 | 2 |
| T4 | Admin routes + `Admin::SiteLogosController` (`#show`, `#update`, `#restore_defaults`) — save-then-purge ordering (R17), `restore_defaults` (R18), permitted params (R19), synchronous variant processing (R22), opacity check wired into `#show` (R13). | AC-4, AC-9–AC-16, AC-22, AC-23, AC-26, AC-27 | 3 |
| T5 | Admin view: file input, preview swatch on literal `#242121` (R15), removal checkbox, opacity warning banner, mobile-first layout (R14, R21). Dashboard link (R20). | AC-20–AC-23, AC-30 | 2 |
| T6 | Stimulus `logo_preview_controller` (R16) for pre-save client-side preview. | AC-24 | 2 |
| T7 | New i18n keys under `admin.site_logo`, `admin.dashboard.site_logo_link`, and the scoped `activerecord.errors` key (R23). | AC-29 | 1 |
| T8 | Tests: model specs (`SiteLogo` validations at both content-type lists, `fully_opaque?` against fixed opaque/transparent fixtures); request specs for `Admin::SiteLogosController` (upload happy path, rejection cases, remove-checkbox tie-break incl. AC-14's reject-without-purging case, restore_defaults); helper spec for `site_logo_image_tag`; system specs at 375/390/414px with a ~16:1 wide-logo fixture (AT16) and for the live pre-save preview (AT21). All AAA, inline variables, no `let`/`let!`. | All | 5 (documented split: T8a model/request/helper specs, 3pts; T8b system specs incl. wide-fixture layout and JS preview, 2pts — split for review per the ≥5-point guardrail) |

Total estimated points: 20 (T8 split into two ≤3-point pieces per the guardrail; every other task ≤3 points).

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-09-03 | Initial draft | All | Translates the repo owner's nav-logo replacement request into an implementation-ready spec. Adopts mitigation 1 (live pre-save preview on the real `#242121` background) as the highest-value, best-argued control; adopts mitigation 2 (narrower PNG/WebP-only allowlist for this slot) via an additive, backward-compatible change to the shared `ImageAttachmentValidatable` concern; adopts mitigation 3 (non-blocking opacity warning via `Vips::Image#has_alpha?`) recomputed on every admin render rather than a one-time flash; adopts mitigation 4 (permanent bundled fallback with a restore path), following SPEC-013's established shape with one explicit, argued correction to the purge-ordering rule (R17) so this spec does not repeat a data-loss-on-validation-failure bug present in SPEC-013's currently-committed R15 wording. Resolves the model-placement question by consulting ADR-004 directly: new `SiteLogo` singleton, no `published` flag (departing from `HomePageContent`/`AboutPageContent`'s pattern in favor of `GalleryPhoto`'s closer precedent). Specifies a `max-w-[160px]` + `object-contain` width constraint alongside the existing fixed height, with the mobile-viewport math and CSS reasoning behind the chosen value, and requires system-spec coverage at 375/390/414px with a deliberately wide test fixture. Commissions and cites a dependency research finding (`SPEC-015-research-logo-transparency-conversion.md`) recommending against any automatic background-removal or conversion feature in v1, hosted or self-hosted, and explains why the "chroma-key, not matting" reframing is correct but still not worth building speculatively now. |

---

## Open Questions

None. All decisions requiring an argued choice — model placement, the publish-gate question, the width constraint value, the content-type-override mechanism, the corrected purge ordering, and the conversion-API recommendation — are settled above, with reasoning, rather than left for the developer to infer.
