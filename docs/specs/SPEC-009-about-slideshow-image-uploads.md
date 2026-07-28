# Spec: About Slideshow Image Uploads — Admin-Replaceable Slide Images

**ID:** SPEC-009
**Status:** ready
**Priority:** medium
**Created:** 2026-07-14
**Author:** spec-agent

---

## Goal

Allow Doug to replace any of the 3 About page slideshow images through the existing admin backend, without developer involvement — extending SPEC-007's already-editable slideshow alt text to the images themselves. Each of the 3 fixed slots is independently replaceable and independently falls back to the bundled static image that ships in `app/assets/images/gallery/` today, so the About page can never be left blank or broken, and no migration is ever required for these images. Implements ADR-005 Decision 1 (data model), Decision 3 (no backfill needed), and the About-specific portions of Decisions 4–6 and Implementation Notes 8–10.

**Blocked until both of the following land on `main`:**
1. **SPEC-008** (Gallery Photo Management) — provides the shared prerequisite infrastructure this spec reuses unmodified: the `active_storage:install` migration, the `ruby-vips` gem, and the `ImageAttachmentValidatable` concern.
2. **SPEC-007** (About Page Content Editing, PR #38) — provides `AboutPageContent`, `Admin::AboutPageContentsController`, the existing admin form, and the `content` local / `published?` gating pattern this spec extends.

This spec's Rules, ACs, and ATs below are complete and unambiguous (status `ready`), but implementation cannot begin until both dependencies are merged.

**Independent addendum (2026-07-21, revised 2026-07-27):** This spec also covers a second, unrelated scope item folded in at explicit user request, to ship in the same implementation pass as the About slideshow work above: a persistent admin nav bar in the shared admin layout, listing all five admin destinations (Dashboard, Home, About, Gallery, Services) and rendered on every admin page including the dashboard itself. It originally shipped as a single "back to dashboard" header link; see the 2026-07-27 Change Log entry for why that was replaced. This addendum is not blocked by SPEC-007/SPEC-008 and is not derived from ADR-005 — see the "Admin Layout" subsections within Rules, Edge Cases, Acceptance Criteria, and Acceptance Tests below.

---

## Non Goals

- Gallery photo upload, delete, or reorder — covered by SPEC-008, entirely independent of this spec.
- A new backfill mechanism for the 3 slideshow images — explicitly not needed; see R6 and Implementation Decisions for why.
- A second "images published" flag — reuses the existing `AboutPageContent#published` column; see R5.
- Any change to the 3 slideshow images' alt text or the document-order mapping to `slideshow_alt_1/2/3` — that is SPEC-007 R20's territory and is unchanged by this spec (see R11).
- Dimension, aspect-ratio, or minimum-resolution validation for slideshow images — none is added; see R12.
- Uploading a 4th slide or making the slide count configurable — the 3 slots are fixed, per ADR-005's rationale for choosing named `has_one_attached` slots over an open collection.
- Image cropping, rotation, or filters.
- Changing the hardcoded Google Maps URL, contact form, or any other About page content not already covered by SPEC-007.

---

## Definitions

| Term | Definition |
|------|-----------|
| slideshow slot | One of 3 fixed, named positions in the About page's CSS fade slideshow: `slideshow_image_1`, `slideshow_image_2`, `slideshow_image_3` on `AboutPageContent`, mapped 1:1 in document order to the existing `slideshow_alt_1/2/3` fields (SPEC-007 R20) and to the 3 `<img>` tags in `app/views/pages/about.html.erb`. |
| static fallback | The bundled asset-pipeline file each slot falls back to when unattached: slot 1 → `gallery/m45a2920.jpg`, slot 2 → `gallery/m45a2927.jpg`, slot 3 → `gallery/m45a2928.jpg`. These files are never deleted and never copied into Active Storage — they are the permanent, canonical original for each slot. |
| independent per-slot resolution | Each of the 3 slots is resolved on its own — one slot having an uploaded, published image has no bearing on whether the other 2 slots show their static fallback or an upload of their own. Mirrors how each text field on `AboutPageContent` already falls back independently (SPEC-007 R3a). |
| display variant | The same named Active Storage variant options SPEC-008 defines for `GalleryPhoto` — `resize_to_limit: [1200, 1200], saver: { quality: 80 }` — applied here via a small `AboutPageContent` helper method, not a second variant definition. |
| `ImageAttachmentValidatable` | The shared validation concern created by SPEC-008 at `app/models/concerns/image_attachment_validatable.rb`. This spec includes and calls it; it does not redefine or duplicate it. |

---

## Interfaces

### Public Frontend

- `GET /about` — `PagesController#about` (unchanged from SPEC-007) loads `AboutPageContent.first`. The view's existing `content = @about_page_content&.published? ? @about_page_content : nil` local (SPEC-007 R3a) is reused, unmodified, as the basis for per-slot image resolution.

### Admin

No new routes. The existing SPEC-007 routes and actions are extended in place:

| Verb | Path | Action | Extension in this spec |
|------|------|--------|------------------------|
| GET | /admin/about_page_content | `Admin::AboutPageContentsController#show` | Renders 3 new file inputs alongside the existing 10 text fields |
| PATCH | /admin/about_page_content | `#update` | Permits 3 new file params; multipart form (auto-detected by `form_with` once a file field is present) |
| PATCH | /admin/about_page_content/restore_defaults | `#restore_defaults` | Also purges the 3 slideshow attachments, in addition to its existing 10-field text reset |

### Data Model

No new table and no new migration beyond SPEC-008's one-time `active_storage:install` migration. `AboutPageContent` gains 3 named attachments:

```ruby
class AboutPageContent < ApplicationRecord
  has_one_attached :slideshow_image_1
  has_one_attached :slideshow_image_2
  has_one_attached :slideshow_image_3
end
```

Attachment data lives in the polymorphic `active_storage_attachments`/`active_storage_blobs` tables (SPEC-008), keyed by `name` (`"slideshow_image_1"`, etc.) and `record` (`AboutPageContent`) — not as columns on `about_page_contents`.

### Validation

`AboutPageContent` includes the existing `ImageAttachmentValidatable` concern (created by SPEC-008 — not redefined here) and calls:

```ruby
validates_image_attachment :slideshow_image_1, :slideshow_image_2, :slideshow_image_3
```

No presence validation is added for any of the 3 slots — an unattached slot is a valid, expected state (falls back to the static file), unlike `GalleryPhoto#image` in SPEC-008, where an unattached image is invalid.

No new i18n keys are needed for the `invalid_content_type`/`file_too_large` error messages — SPEC-008 already defines them once at `activerecord.errors.messages.*`, and Rails' error-message fallback chain resolves them for `AboutPageContent#slideshow_image_1/2/3` automatically (see SPEC-008 Implementation Decisions).

### Required i18n Keys

Add under `admin.about_page_content` in `config/locales/en.yml` (all other keys in this namespace already exist from SPEC-007):

| Key | Purpose |
|-----|---------|
| `slideshow_image_1_label` | Label for the slot-1 file input |
| `slideshow_image_2_label` | Label for the slot-2 file input |
| `slideshow_image_3_label` | Label for the slot-3 file input |
| `slideshow_image_hint` | Shared hint beneath each file input: allowed types, 15 MB max, and that leaving it blank keeps the current image |

**Update** the existing `confirm_restore_defaults` key (SPEC-007) to also mention images, since restore now has a destructive side effect it didn't have before (ADR-005 Risks):

| Key | Old Value (SPEC-007) | New Value |
|-----|----------------------|-----------|
| `confirm_restore_defaults` | "This will replace your current edits with the original default text. Continue?" | "This will replace your current edits with the original default text and remove any uploaded slideshow images. Continue?" |

### Admin Layout (Persistent Admin Nav Bar)

No new routes or controllers. `app/views/layouts/admin.html.erb` — the single shared layout rendered by every `Admin::BaseController` subclass — gains a `<nav>` element beneath its `<header>`, holding a `<ul>` of five `link_to` destinations, rendered only when `current_admin` is present. The logout `button_to` stays in the header; the back-to-dashboard link previously in the header is removed, superseded by the nav's "Dashboard" item.

New helper `app/helpers/admin_helper.rb`:

| Method | Purpose |
|--------|---------|
| `admin_nav_items` | Ordered `[label, path]` pairs for the five admin destinations |
| `admin_nav_current?(path)` | Whether `path` corresponds to the page being rendered. Deliberately **not** `current_page?`, which matches GET only and would drop the marking on a validation-failure re-render (a PATCH/POST). Matches on `request.path`; treats `/admin/service_sections*` as belonging to Services, which has no nav entry of its own |
| `admin_nav_link_class(path)` | Tailwind classes for a nav item, applying the active fill when `admin_nav_current?` |

Add under `admin.layout` in `config/locales/en.yml` (alongside the existing `title`, `header`, `logout` keys):

| Key | Purpose |
|-----|---------|
| `nav.aria_label` | Accessible name for the `<nav>` landmark |
| `nav.dashboard` | Nav label for the dashboard |
| `nav.home` | Nav label for Home page content |
| `nav.about` | Nav label for About page content |
| `nav.gallery` | Nav label for gallery photo management |
| `nav.services` | Nav label for the services page |

Changed value: `admin.layout.header` is shortened from "Syndicate Development Admin" to "Syndicate Admin" so the header row does not wrap at phone width.

Removed key: `admin.layout.dashboard_link`, which backed the superseded single header link.

---

## Rules

R1: `AboutPageContent` gains `has_one_attached :slideshow_image_1`, `:slideshow_image_2`, `:slideshow_image_3`, per the Interfaces section's Data Model.

R2: `AboutPageContent` includes `ImageAttachmentValidatable` (reused unmodified from SPEC-008) and calls `validates_image_attachment :slideshow_image_1, :slideshow_image_2, :slideshow_image_3`. No presence validation is added for any of the 3 slots.

R3: `AboutPageContent` gains a helper method — e.g. `slideshow_display_variant(n)` — that returns `public_send("slideshow_image_#{n}").variant(resize_to_limit: [1200, 1200], saver: { quality: 80 })`. This centralizes the variant options in one place rather than repeating them at 3 view call sites, matching ADR-005 Implementation Note 4's guidance and reusing the exact same dimensions/quality SPEC-008 confirmed for `GalleryPhoto#display_variant`.

R4: Each slideshow slot is resolved independently in `app/views/pages/about.html.erb`, extending the existing `content` local (SPEC-007 R3a): slot N renders `content.slideshow_display_variant(N)` when `content&.public_send("slideshow_image_#{N}")&.attached?` is true; otherwise it renders the existing static fallback file for that slot (Definitions table), with `alt: content&.public_send("slideshow_alt_#{N}") || t("pages.about.slideshow_alt_#{N}")` — unchanged from SPEC-007 R20. One slot having an uploaded image has no effect on the other 2 slots' resolution.

R5: Publish gating for slideshow images reuses the existing `AboutPageContent#published` column — no second flag is introduced. A slot renders its uploaded image only when **both** `content` is non-nil (i.e., `AboutPageContent.first&.published?` is `true`, per the existing `content` local) **and** that specific slot has an attachment. If `published?` is `false`, all 3 slots render their static fallback regardless of what is attached — identical to how unpublished text already falls back (SPEC-007 R1).

R6: No backfill mechanism exists or is needed for these 3 slots. The bundled static files remain the permanent fallback indefinitely — they are never copied into Active Storage and never deleted by any part of this spec. `lib/tasks/gallery_photos.rake` (SPEC-008) is not modified and does not reference `AboutPageContent` or any `slideshow_image_*` attachment.

R7: `Admin::AboutPageContentsController#restore_defaults` (existing SPEC-007 action) is extended: after resetting the 10 text fields via `i18n_default_attributes` (unchanged), it also purges each attached slideshow slot — `about_page_content.slideshow_image_1.purge if about_page_content.slideshow_image_1.attached?`, repeated for slots 2 and 3 — in the same request. `published` remains untouched, exactly as before this spec (SPEC-007 R17/R18 are unaffected).

R8: Reattaching a new file to an already-attached slot via the normal `#update` action automatically replaces and purges the previous blob — this is Active Storage's default `has_one_attached=` reattachment behavior (confirmed by ADR-005: "`has_one_attached=` on a model attribute already replaces (and schedules the old blob for purge on) reattachment"). No explicit purge call is added to `#update` for this case.

R9: 3 `f.file_field` inputs — `slideshow_image_1`, `slideshow_image_2`, `slideshow_image_3` — are added to the existing admin About form (`app/views/admin/about_page_contents/show.html.erb`), each positioned near its corresponding `slideshow_alt_N` text input. `about_page_content_params` in `Admin::AboutPageContentsController` permits `:slideshow_image_1, :slideshow_image_2, :slideshow_image_3` alongside the existing 10 text params and `:published`. No new route; the existing `PATCH /admin/about_page_content` handles the multipart submission (`form_with` auto-detects the file field and sets `multipart: true`).

R10: The `confirm_restore_defaults` i18n string is updated per the Interfaces section's table so the confirmation dialog accurately describes that uploaded slideshow images are also removed, not just text.

R11: Alt-text resolution for the 3 `<img>` tags is unchanged from SPEC-007 R20 — `content&.slideshow_alt_N || t("pages.about.slideshow_alt_N")`. This spec only changes how each `<img>` `src` is resolved; `alt` resolution logic is untouched, and applies identically whether the `src` came from an uploaded image or the static fallback.

R12: No dimension, aspect-ratio, or minimum-resolution validation is added for slideshow images. `object-fit: cover` inside the slideshow's fixed `height: 60vh` container already crops any source image to fill the box regardless of shape or resolution, matching ADR-005 Decision 4's reasoning and SPEC-008's identical decision for `GalleryPhoto`.

R13: The 3 new file inputs follow the mobile-first rules from CLAUDE.md: each carries `w-full` (to the extent applicable to a file input), positioned within the existing form's `space-y-6` vertical rhythm, introducing no horizontal scroll at any viewport width including 375 px.

### Admin Layout — Persistent Admin Nav Bar (added 2026-07-21, revised 2026-07-27)

R14: The admin layout (`app/views/layouts/admin.html.erb`) renders a persistent nav bar — a `<nav>` element carrying `aria-label` from `admin.layout.nav.aria_label`, holding a `<ul>` of real `link_to` destinations, not JavaScript history controls — directly beneath the header, whenever `current_admin` is present. This mirrors the existing logout button's guard (same conditional), so the nav is absent on the unauthenticated login page. The nav lists all five admin destinations in a fixed order: Dashboard, Home, About, Gallery, Services.

R15: The nav item matching the current page is marked with `aria-current="page"` and rendered with a solid fill (`bg-red-600 text-white`) rather than a hover-only cue. Exactly one item is marked current on every admin page, including the dashboard (where "Dashboard" is active) and the service-section sub-pages at `/admin/service_sections/*` (where "Services" is active, as they have no nav entry of their own). The marking is computed by `admin_nav_current?`, **not** `current_page?`: `current_page?` returns false for any non-GET request, which would drop the marking on every validation-failure re-render, since those render in response to the original PATCH/POST. The current item remains a real, enabled link.

R16: All nav labels are sourced from new i18n keys under a new `admin.layout.nav` namespace in `config/locales/en.yml` (`aria_label`, `dashboard`, `home`, `about`, `gallery`, `services`), alongside the existing `title`, `header`, and `logout` keys. No hardcoded string is used. `admin.layout.header` is shortened to "Syndicate Admin" so the header row does not wrap at phone width.

R17: Every nav item carries touch-target padding (`py-3 px-3`, yielding a ≥44px tap height, matching the `py-3 px-6` / `py-3 px-5` pattern already used on admin form buttons per CLAUDE.md's mobile-first mandate) and does not depend on hover-only affordance (no visibility or tappability gated solely behind `:hover`), since the primary admin user (Doug) navigates by touch on his phone. The nav wraps to multiple rows (`flex-wrap`) rather than scrolling horizontally, per CLAUDE.md's prohibition on horizontal scrolling at any width.

R18: Because `Admin::BaseController` sets `layout "admin"` for every admin controller, this is a change to `app/views/layouts/admin.html.erb` plus a new `app/helpers/admin_helper.rb` (holding `admin_nav_items` and `admin_nav_link_class`, so the destination list and active-state styling live in one testable place) — no per-view edits are made to `app/views/admin/home_page_contents/show.html.erb`, `app/views/admin/about_page_contents/show.html.erb`, `app/views/admin/gallery_photos/index.html.erb`, or `app/views/admin/services_pages/show.html.erb`. All admin pages, current and future, gain the nav automatically.

---

## Edge Cases

E1: No slot has ever been attached (fresh `AboutPageContent`, or none exists at all). All 3 `<img>` tags render their static fallback, regardless of `published` state.

E2: `published: false`, but `slideshow_image_1` is attached. All 3 slots still render their static fallback — the publish gate applies to images exactly as it does to text (R5).

E3: `published: true`, only `slideshow_image_1` is attached. Slot 1 renders the uploaded image; slots 2 and 3 render their static fallback — independent per-slot resolution (R4).

E4: An upload to `slideshow_image_2` is rejected (e.g., `image/svg+xml` content type). HTTP 422; no attachment is persisted for slot 2; because `#update` is a single whole-record `update` call, none of the other fields submitted in the same request are persisted either (matches existing `#update` all-or-nothing behavior from SPEC-007 R12).

E5: An upload to `slideshow_image_3` exceeds 15 MB. HTTP 422; rejected by the size validation (R2).

E6: `restore_defaults` is called when 2 of 3 slots have attachments. Both attached slots are purged; the 10 text fields reset from i18n; `published` is unchanged; the already-unattached 3rd slot is unaffected (its `.attached?` guard prevents any error).

E7: `restore_defaults` is called when zero slots are attached. Each purge call is guarded by `.attached?`, so nothing raises; the action completes normally.

E8: A new file is uploaded to a slot that already has an attachment, via a normal (non-restore) `#update`. The old blob is replaced and purged automatically (R8); only the new image is visible afterward.

E9: `AboutPageContent.first` returns nil entirely (fresh deployment, before any save or restore has ever happened). The slideshow renders all 3 static fallbacks; no `NoMethodError` (extends SPEC-007 E1/R3).

### Admin Layout — Persistent Admin Nav Bar (added 2026-07-21, revised 2026-07-27)

E10: `current_admin` is `nil` (the unauthenticated login page, `GET /admin/login`). The nav does not render, mirroring the existing logout button's absence in the same state.

E11: An admin navigates directly to an edit page (e.g. `GET /admin/about_page_content`) via a bookmarked or freshly typed URL, with no prior entry in browser history. Because each nav item is a real `link_to`, not a JS `history.back()` call, it still navigates correctly regardless of history state.

E12: Admin is already on the dashboard (`GET /admin`). The nav still renders, with "Dashboard" as the active item (R15) — it is not hidden, so the nav's position and item count stay stable across every admin page.

E13: Viewport is narrower than the nav's total intrinsic width (any phone below ~500px). The nav wraps to a second row rather than overflowing; no item is pushed off-screen and `document.body.scrollWidth` does not exceed the viewport width (R17). The header row above it stays on a single unwrapped line.

E14: A form submission fails validation and the controller re-renders the form (e.g. `Admin::AboutPageContentsController#update` → `render :show`, responding 422 to a PATCH). The nav renders with the correct item still marked current, because `admin_nav_current?` matches on `request.path` independently of HTTP verb (R15).

E15: Admin is on an admin page with no nav entry of its own — `/admin/service_sections/new` or `/admin/service_sections/:id/edit`. The nav renders with "Services" marked current, so the admin is never left with no orientation cue (R15).

---

## Acceptance Criteria

### Public Page Behavior

AC-1: Given no `AboutPageContent` row exists, when `GET /about`, then all 3 `<img>` `src` attributes equal the asset path for `gallery/m45a2920.jpg`, `gallery/m45a2927.jpg`, and `gallery/m45a2928.jpg` respectively — unchanged from current (pre-SPEC-009) behavior.

AC-2: Given `AboutPageContent` exists with `published: true` and `slideshow_image_1` attached (a valid JPEG), when `GET /about`, then the first `<img>` `src` resolves to an Active Storage representation path (not the static asset path), while the second and third `<img>` `src` values still equal their static asset paths.

AC-3: Given `AboutPageContent` exists with `published: false` and `slideshow_image_1` attached, when `GET /about`, then all 3 `<img>` `src` attributes equal their static asset paths — the publish gate applies to images.

AC-4: Given `AboutPageContent` exists with `published: true` and all 3 slots attached, when `GET /about`, then all 3 `<img>` `src` attributes are Active Storage representation paths, in document order matching slot 1, 2, 3.

### Admin Behavior

AC-5: Given admin is authenticated, when `PATCH /admin/about_page_content` with a valid `slideshow_image_2` file (JPEG, under 15 MB) plus valid values for the existing required fields, then `AboutPageContent.first.slideshow_image_2.attached?` is `true`, and the response redirects with `flash[:notice]`.

AC-6: Given admin is authenticated, when `PATCH /admin/about_page_content` with `slideshow_image_2` as an `image/svg+xml` file, then HTTP 422, no attachment is persisted for slot 2, and the response body includes a content-type validation error.

AC-7: Given admin is authenticated, when `PATCH /admin/about_page_content` with `slideshow_image_3` exceeding 15 MB, then HTTP 422 and the response body includes a file-size validation error.

AC-8: Given admin is authenticated and `AboutPageContent` exists with all 3 slideshow slots attached, when `PATCH /admin/about_page_content/restore_defaults`, then all 3 `slideshow_image_N.attached?` are `false`, the 10 text fields equal their `I18n.t("pages.about.*")` originals, `published` is unchanged, and the response redirects with `flash[:notice]`.

AC-9: Given admin is authenticated and `AboutPageContent` exists with zero slideshow slots attached, when `PATCH /admin/about_page_content/restore_defaults`, then the action completes normally without raising.

AC-10: The admin About form (`GET /admin/about_page_content`) includes 3 file inputs with `name` attributes `about_page_content[slideshow_image_1]`, `[slideshow_image_2]`, `[slideshow_image_3]`.

AC-11: The `confirm_restore_defaults` i18n string's content mentions uploaded images being removed/reset, in addition to text.

AC-12: Given admin is authenticated and `slideshow_image_1` is already attached, when `PATCH /admin/about_page_content` with a new `slideshow_image_1` file, then exactly one `ActiveStorage::Attachment` record exists for `name: "slideshow_image_1"` on that `AboutPageContent` afterward (the old blob was replaced, not accumulated).

AC-13: No hardcoded English strings are introduced by this spec's view or controller changes; all new labels/hints use `t()`.

AC-14: The admin About form renders without horizontal scroll at 375 px viewport width, including the 3 new file inputs, each carrying `w-full`.

AC-15: Given a request is NOT authenticated, when `PATCH /admin/about_page_content/restore_defaults`, then the response redirects (auth guard, unchanged from SPEC-007) and no `AboutPageContent` data changes — confirms adding the purge logic (R7) introduces no auth regression.

### Admin Layout — Persistent Admin Nav Bar (added 2026-07-21, revised 2026-07-27)

AC-16: Given admin is authenticated, when any admin page is requested, then the response includes a `<nav>` labelled `I18n.t("admin.layout.nav.aria_label")` whose links' texts and hrefs equal, in order, the five destinations of `admin_nav_items` (Dashboard, Home, About, Gallery, Services).

AC-17: Given admin is authenticated, when each admin page is requested, then exactly one nav link carries `aria-current="page"`, it is the link matching the requested page, and its class includes `bg-red-600`.

AC-18: Given no active admin session, when `GET /admin/login`, then the response does not include the nav.

AC-19: Given admin is authenticated, when each of `GET /admin`, `GET /admin/home_page_content`, `GET /admin/about_page_content`, `GET /admin/gallery_photos`, and `GET /admin/services_page` is requested, then each response includes the full nav — confirming the layout-level change covers every admin page without any per-view modification.

AC-20: Every nav link's markup carries touch-target padding classes (`py-3 px-3` or equivalent) and includes no styling that gates its visibility or tappability behind `:hover`; the containing `<ul>` carries `flex-wrap` and does not carry `overflow-x-auto`.

AC-21: At viewport widths of 320px, 375px, and 390px, the rendered admin nav produces no horizontal document overflow, keeps every item fully within the viewport, and renders each item at ≥44px tap height. At the same widths the header row keeps its title and logout button on one row, with the title unwrapped — the original failure mode, which produces no overflow and so is not caught by the overflow assertion alone.

AC-22: Given admin is authenticated, when a `PATCH /admin/about_page_content` fails validation and re-renders (HTTP 422), then the nav still marks "About" as the current page.

AC-23: Given admin is authenticated, when `GET /admin/service_sections/new` is requested, then the nav marks "Services" as the current page.

---

## Acceptance Tests

AT1
Given no `AboutPageContent` row exists
When `GET /about`
Then all 3 `<img>` `src` attributes equal the asset paths for `gallery/m45a2920.jpg`, `gallery/m45a2927.jpg`, `gallery/m45a2928.jpg` respectively
Covers: R4, R6, AC-1, E1, E9

AT2
Given `AboutPageContent` exists with `published: true` and `slideshow_image_1` attached (valid JPEG)
When `GET /about`
Then the first `<img>` `src` is an Active Storage representation path, and the second and third `<img>` `src` values remain the static asset paths
Covers: R1, R3, R4, AC-2, E3

AT3
Given `AboutPageContent` exists with `published: false` and `slideshow_image_1` attached
When `GET /about`
Then all 3 `<img>` `src` attributes equal the static asset paths
Covers: R4, R5, AC-3, E2

AT4
Given `AboutPageContent` exists with `published: true` and all 3 slots attached
When `GET /about`
Then all 3 `<img>` `src` attributes are Active Storage representation paths, in document order matching slot 1, 2, 3
Covers: R3, R4, AC-4

AT5
Given admin is authenticated
When `PATCH /admin/about_page_content` with a valid `slideshow_image_2` file and valid values for all required text fields
Then `AboutPageContent.first.slideshow_image_2.attached?` is `true` and the response redirects with `flash[:notice]`
Covers: R1, R9, AC-5

AT6
Given admin is authenticated
When `PATCH /admin/about_page_content` with `slideshow_image_2` as an `image/svg+xml` file
Then HTTP 422, `AboutPageContent.first&.slideshow_image_2&.attached?` is falsy, and the response includes a content-type validation error
Covers: R2, AC-6, E4

AT7
Given admin is authenticated
When `PATCH /admin/about_page_content` with `slideshow_image_3` exceeding 15 MB
Then HTTP 422 and the response includes a file-size validation error
Covers: R2, AC-7, E5

AT8
Given admin is authenticated and `AboutPageContent` exists with all 3 slideshow slots attached
When `PATCH /admin/about_page_content/restore_defaults`
Then all 3 `slideshow_image_N.attached?` are `false`, the 10 text fields equal their `I18n.t("pages.about.*")` originals, `published` is unchanged, and the response redirects with `flash[:notice]`
Covers: R7, AC-8

AT9
Given admin is authenticated and `AboutPageContent` exists with zero slideshow slots attached
When `PATCH /admin/about_page_content/restore_defaults`
Then the action does not raise and completes with a normal redirect
Covers: R7, AC-9, E6, E7

AT10
Given admin is authenticated
When `GET /admin/about_page_content`
Then the response includes file inputs named `about_page_content[slideshow_image_1]`, `[slideshow_image_2]`, `[slideshow_image_3]`
Covers: R9, AC-10

AT11
Given the `confirm_restore_defaults` i18n string
When inspected
Then its content mentions uploaded images being removed/reset, in addition to text
Covers: R10, AC-11

AT12
Given admin is authenticated and `slideshow_image_1` is already attached to `AboutPageContent`
When `PATCH /admin/about_page_content` with a new `slideshow_image_1` file
Then exactly one `ActiveStorage::Attachment` record exists for `name: "slideshow_image_1"` on that record afterward
Covers: R8, AC-12, E8

AT13
Given `app/views/admin/about_page_contents/show.html.erb` and `Admin::AboutPageContentsController` source, as modified by this spec
When inspected for hardcoded English string literals introduced by this spec
Then none are found
Covers: R9, R10, AC-13

AT14
Given admin is authenticated
When `GET /admin/about_page_content` is rendered at 375 px viewport width (system spec)
Then no horizontal scroll occurs and the 3 new file inputs carry `w-full`
Covers: R13, AC-14

AT15
Given no active admin session
When `PATCH /admin/about_page_content/restore_defaults`
Then the response redirects (auth guard) and no `AboutPageContent` data changes
Covers: R7, AC-15

AT16
Given `AboutPageContent` exists with `published: true`, `slideshow_image_1` attached, and `slideshow_alt_1: "Custom alt text"`
When `GET /about`
Then the first `<img>` `alt` attribute equals "Custom alt text" — unchanged resolution logic from SPEC-007 R20, regardless of whether the image itself is DB-uploaded or falls back to the static file
Covers: R11, AC-4

AT17
Given a valid JPEG under 15 MB with pixel dimensions smaller than 400×400 attached to `slideshow_image_1`
When the `AboutPageContent` record is validated
Then it is valid — no minimum-dimension validation is applied
Covers: R12

### Admin Layout — Persistent Admin Nav Bar (added 2026-07-21, revised 2026-07-27)

AT18
Given admin is authenticated
When each of `GET /admin`, `GET /admin/home_page_content`, `GET /admin/about_page_content`, `GET /admin/gallery_photos`, and `GET /admin/services_page` is requested
Then each response's nav contains exactly the five expected labels and hrefs, in `admin_nav_items` order
Covers: R14, R16, R18, AC-16, AC-19, E11

AT19
Given admin is authenticated
When each admin page is requested
Then exactly one nav link carries `aria-current="page"`, it is the one matching the requested page, and its class includes `bg-red-600`
Covers: R15, AC-17, E12

AT20
Given no active admin session
When `GET /admin/login`
Then the response does not include the nav
Covers: R14, AC-18, E10

AT21
Given admin is authenticated and the browser viewport is set to 320px, 375px, and 390px in turn
When `GET /admin/about_page_content` is rendered in a real browser
Then `document.body.scrollWidth` does not exceed the viewport width, no nav item's bounding box falls outside the viewport, every nav item renders at ≥44px tap height, and the header title and logout button share one row with the title unwrapped
Covers: R17, AC-21, E13

AT23
Given admin is authenticated
When `PATCH /admin/about_page_content` is submitted with a blank required field and re-renders 422
Then exactly one nav link carries `aria-current="page"` and it is "About"
Covers: R15, AC-22, E14

AT24
Given admin is authenticated
When `GET /admin/service_sections/new`
Then exactly one nav link carries `aria-current="page"` and it is "Services"
Covers: R15, AC-23, E15

AT22
Given the admin layout nav markup
When inspected
Then every link carries touch-target padding classes (`py-3 px-3`) with no hover-only visibility/tappability styling, and the containing `<ul>` carries `flex-wrap` but not `overflow-x-auto`
Covers: R17, AC-20

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-14 | `:display`-equivalent variant confirmed at `resize_to_limit: [1200, 1200], saver: { quality: 80 }`, same numbers as SPEC-008's `GalleryPhoto#display_variant` | ADR-005 Implementation Note 4 explicitly sizes 1200 px for About's `60vh` slideshow panel — the largest rendered context across both specs. Reusing the identical numbers via a small `AboutPageContent#slideshow_display_variant(n)` helper (R3) avoids inventing a second set of tuning values and keeps both specs' visual output consistent. |
| 2026-07-14 | No soft minimum pixel-dimension guard | Same rationale as SPEC-008's identical decision: no evidence of accidental low-res uploads, `object-fit: cover` already fully protects the fixed-height slideshow container regardless of source resolution, and this codebase consistently favors minimal validation surface over speculative guards (ADR-002, ADR-005 Decision 4). Applying the decision consistently across both photo-upload specs avoids two different validation postures for the same underlying concern class. |
| 2026-07-14 | No per-slot alt-text change | SPEC-007 R20 already made alt text independently editable per slot; this spec only changes image `src` resolution. Re-deriving or modifying alt-text behavior here would be scope creep beyond ADR-005's stated boundary ("only the images themselves become admin-replaceable"). |
| 2026-07-14 | Reuse `AboutPageContent#published` — no second "images published" flag | ADR-005 Decision 1 / Rationale: `published` already answers "is this content object live?" as a property of the whole record. A second flag would let text and images independently be live/not-live with no single answer to "is my page live," reintroducing the exact split-brain state ADR-004 avoided for the text fields. Gating images with the same column, with per-slot fallback when unattached, extends the already-trusted mechanism at zero additional schema cost. |
| 2026-07-14 | No backfill mechanism | The static file *is* the permanent fallback, not a value being migrated away from — nothing about the current rendering path changes until Doug explicitly uploads a replacement (ADR-005 Decision 3/Rationale: "the two 'originals' mean different things"). This is structurally different from Gallery, where `Dir.glob` is removed and every visible photo must become a row or the page goes blank — About's rendering path is untouched by this spec until an admin acts. |
| 2026-07-14 | `confirm_restore_defaults` copy updated to mention images | ADR-005 Risks explicitly flags that restore now has a destructive side effect (purging attachments) it didn't have before this spec. Updating the confirmation copy is a one-line change that keeps Doug from being surprised by a wider blast radius than the button previously had. |

---

## Dependencies

- **SPEC-008 (Gallery Photo Management) — must ship first.** Provides the shared, one-time Active Storage install migration, the `ruby-vips` gem, and the `ImageAttachmentValidatable` concern this spec includes and calls unmodified. This spec adds zero new infrastructure — it is a pure consumer of SPEC-008's prerequisites.
- **SPEC-007 (About Page Content Editing, PR #38) — must merge to `main` first.** `AboutPageContent`, `Admin::AboutPageContentsController`, `app/views/admin/about_page_contents/show.html.erb`, the `content` local / `published?` gating pattern (R3a), and the existing `restore_defaults` action must all exist before this spec's changes can be applied. This spec extends each of those in place; it creates none of them.
- SPEC-001 (Frontend Rebuild) — done. Layout, nav, Tailwind, and asset pipeline are in place.
- SPEC-003 (i18n String Extraction) — done. All new admin UI strings follow the `t()` / `en.yml` pattern.
- SPEC-004 (Admin Backend) — done. `Admin::BaseController`, auth session management, and admin layout are live.
- ADR-004 (Singleton Content Model and Publish Flag Placement) — governs the `published`-column-reuse decision; not re-derived here.
- ADR-005 (Photo Upload Data Model and Active Storage Strategy) — governs this spec's data model, validation, variant, and no-backfill decisions; not re-derived here.
- No new gems required — `ruby-vips` is already added by SPEC-008.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Model: add `has_one_attached :slideshow_image_1/2/3` to `AboutPageContent` (R1); include `ImageAttachmentValidatable` (already defined by SPEC-008) and call `validates_image_attachment` for the 3 slots, no presence validation (R2); add `slideshow_display_variant(n)` helper (R3). Update factory to optionally attach fixture images via a trait. | Enables AC-2, AC-4, AC-5, AC-6, AC-7 | 2 |
| T2 | Public page: update `app/views/pages/about.html.erb` slideshow section for independent per-slot fallback rendering (R4, R5), preserving unchanged alt-text resolution (R11). | AC-1, AC-2, AC-3, AC-4 | 2 |
| T3 | Admin controller: extend `about_page_content_params` to permit the 3 file params (R9); extend `restore_defaults` to purge the 3 attachments with `.attached?` guards (R7); add `slideshow_image_1/2/3_label` and `slideshow_image_hint` i18n keys; update `confirm_restore_defaults` copy (R10). | AC-5, AC-6, AC-7, AC-8, AC-9, AC-11, AC-15 | 2 |
| T4 | Admin view: add 3 `f.file_field` inputs to the existing About form, each positioned near its corresponding alt-text input, mobile-first (`w-full`) (R9, R13). | AC-10, AC-13, AC-14 | 2 |
| T5 | Tests: `AboutPageContent` model spec (content-type/size validations for all 3 slots; confirms no presence requirement); request spec for `PagesController#about` (per-slot independent fallback, publish gating, all-3-attached case, alt-text unchanged). All AAA pattern, inline variables, no `let`/`let!`. | AC-1, AC-2, AC-3, AC-4 | 3 |
| T6 | Tests: request spec for `Admin::AboutPageContentsController` (upload happy path; content-type/size rejection; `restore_defaults` purge behavior including zero-attached no-op; reattachment replaces rather than accumulates; auth guard regression check); system spec extending SPEC-007's 375 px coverage to include the 3 new file inputs; i18n audit of new strings. | AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15 | 4 |
| T7 | Admin layout: add a persistent nav bar to `app/views/layouts/admin.html.erb` beneath the header, guarded by `current_admin` presence (R14), listing all five admin destinations with the active one marked via `aria-current` and a solid fill (R15); add the `admin.layout.nav.*` i18n keys and shorten `admin.layout.header` (R16); apply mobile-first touch targets and `flex-wrap` (R17); extract `admin_nav_items` / `admin_nav_link_class` into `app/helpers/admin_helper.rb` (R18). Independent scope, folded in at explicit user request — not part of ADR-005. Request spec asserting nav contents and active-state marking across all five admin pages and its absence on login, **plus a system spec exercising real viewport widths (320/375/390px)** — a request spec alone cannot catch layout overflow or collapsed tap targets. | AC-16 – AC-23 | 1 |

Total estimated points: 16 (all tasks ≤ 4 points; no split review required under the ≥ 5-point guardrail)

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-07-14 | Initial draft | All | Translates ADR-005 (Decision 1, Decision 3, and the About-specific portions of Decisions 4–6, Implementation Notes 8–10) into implementation-ready spec format. Explicitly documents the SPEC-008 and SPEC-007/PR#38 blocking dependencies per ADR-005 Implementation Note 12. Resolves the ADR's "Handoff to Spec Agent" open items as they apply to About: confirmed the shared 1200×1200 quality-80 variant via a per-slot helper method; confirmed no soft minimum-dimension guard (consistent with SPEC-008); confirmed no per-slot alt-text change (SPEC-007 R20 unchanged); wrote the `confirm_restore_defaults` copy update and the 4 new admin i18n keys; wrote full acceptance criteria including content-type/size rejection request specs and a 375 px mobile-first system spec extension. |
| 2026-07-21 | Added independent scope: persistent "back to dashboard" navigation link in the shared admin layout header (`app/views/layouts/admin.html.erb`) | R14–R18, E10–E12, AC-16–AC-20, AT18–AT22, T7 | Folded into this spec at explicit user request, to ship alongside the About-slideshow-image-uploads work in the same implementation pass — **not** derived from ADR-005 and unrelated to the slideshow scope above. Addresses a mobile-usability gap: every admin edit page (Home, About, Gallery, Services) was a navigational dead end with no way back to the dashboard except the browser's back button, which is unreliable on Doug's phone per CLAUDE.md's mobile-first mandate. Fixed once at the shared-layout level rather than per-view so all current and future admin pages get it automatically. |
| 2026-07-27 | **Replaced** the single "back to dashboard" header link with a persistent five-destination admin nav bar (Dashboard / Home / About / Gallery / Services), added active-page marking, shortened `admin.layout.header`, extracted `app/helpers/admin_helper.rb`, and added phone-width system coverage | R14–R18 rewritten, E12 rewritten, E13–E15 added, AC-16–AC-20 rewritten, AC-21–AC-23 added, AT18–AT22 rewritten, AT23–AT24 added, T7 rewritten, Interfaces § rewritten | Manual QA finding: the as-shipped link was technically present and request-spec-verified, but at phone width the header crammed a long title, the link, and the logout button into one non-wrapping flex row — all three wrapped into unreadable two-line fragments and the link was effectively invisible, which is how the user reported it ("I don't see anything"). Two corrections: (1) the header was rebalanced and the nav moved to its own row, and (2) the destination set was widened from dashboard-only to all five sections, since the underlying need was to move between admin pages freely rather than only to retreat to the dashboard. The old R15/AC-17 rule hiding the link on the dashboard was dropped — with a full nav, a stable item count and position across every page matters more than avoiding one self-referential link. The root process gap was that AC-16–AC-20 were all assertable from markup alone; AC-21 and its system spec now pin the rendered geometry at 320/375/390px so a repeat regression fails CI instead of reaching the user, and that guard was verified to fail when the long header title is restored. Review also caught that the first cut used `current_page?`, which matches GET only, so the active marking vanished on every validation-failure re-render and on the service-section sub-pages; replaced with `admin_nav_current?` and covered by AC-22/AC-23. |

---

## Open Questions

None. All items from ADR-005's "Handoff to Spec Agent" section that apply to the About slideshow are resolved above (see Implementation Decisions). This spec's only open item is procedural, not a spec ambiguity: implementation of the About-slideshow-image-uploads scope (R1–R13) cannot start until the two Dependencies listed above land on `main`. The Admin Layout addendum (R14–R18, added 2026-07-21) has no such blocker and may be implemented independently at any time — see the Goal section's Independent addendum note.
