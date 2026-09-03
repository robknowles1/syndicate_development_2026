# Spec: Home Page Hero and CTA Image Uploads — Admin-Replaceable Background Images

**ID:** SPEC-013
**Status:** ready
**Priority:** medium
**Created:** 2026-09-02
**Author:** spec-agent

---

## Goal

Let Doug replace the home page's two full-screen background images — the top hero section and the bottom CTA band — from the admin, using the same upload-and-fallback flow he already knows from the About slideshow (SPEC-009). Each of the 2 fixed slots is independently replaceable and independently falls back to the bundled static image that ships in `app/assets/images/gallery/` today, so the home page can never be left blank or broken. Also brings the site's `og:image`/`twitter:image` and schema.org `image` — both of which currently hardcode the same file used as the hero background — into sync with whatever hero image is actually live, so a shared link and the page itself never show two different photos of the shop.

This spec is a direct application of ADR-005's photo-upload data model (named `has_one_attached` slots on a singleton, reusing `published` for gating, no backfill) to a second, unrelated content model. It does not revisit any of ADR-005's architectural decisions — it extends the same pattern already implemented for `AboutPageContent` (SPEC-009) to `HomePageContent`, and additionally raises the shared file-size cap those specs both depend on.

---

## Non Goals

- **A Gallery photo picker for these slots.** Choosing an existing Gallery photo instead of uploading a fresh file was considered and rejected. It requires a new picker UI (search/browse existing `GalleryPhoto` rows from within the Home form) that does not exist anywhere in this codebase today, and it introduces an undefined-behavior question this spec would otherwise have to invent an answer for: what does the hero section render if Doug later deletes the Gallery photo it references? A fresh, independent upload per slot has no such dangling-reference problem — deleting a Gallery photo can never affect the Home page.
- **A third home image slot, or any new page section.** Exactly 2 slots exist today (hero, CTA); adding more is out of scope.
- **A second "images published" flag.** Reuses the existing `HomePageContent#published` column; see R7.
- **Converting the hero/CTA sections from CSS `background-image` to `<img>` tags, or adding admin-editable alt text for either slot.** See R11 and Implementation Decisions for the full argument; this is the one point where this spec deliberately does *not* mirror SPEC-009.
- **Active Storage direct upload.** The known risk in R10 is named and deferred, not solved here — see Implementation Decisions for why it is a follow-up rather than in-scope work.
- **Dimension, aspect-ratio, or minimum-resolution validation** for either slot — none is added, for the same reason ADR-005 Decision 4 and SPEC-009 R12 give: both sections already crop via CSS regardless of source shape.
- **Image cropping, rotation, or filters.**
- **A backfill mechanism.** None is needed — see R5 and Implementation Decisions; the bundled files remain the permanent fallback indefinitely.
- **Per-model file-size limits.** R8 raises one shared constant; this spec does not introduce a Home-specific cap different from Gallery's or About's.

---

## Definitions

| Term | Definition |
|------|-----------|
| hero slot | `HomePageContent#hero_image`, the top full-screen section's background (`app/views/pages/home.html.erb` line 7-9 today). Also the sole source for `og:image`/`twitter:image`/schema.org `image` — see R12-R13. |
| CTA slot | `HomePageContent#cta_image`, the bottom full-screen section's background (line 48-49 today). Feeds nothing outside its own section. |
| static fallback | The bundled asset-pipeline file each slot falls back to when unattached: hero → `gallery/m45a2849.jpg`, CTA → `gallery/m45a2996.jpg`. Never deleted, never copied into Active Storage — the permanent, canonical original for each slot, exactly as SPEC-009 established for About. |
| display variant | `resize_to_limit: [1200, 1200], saver: { quality: 80, keep: :icc }` — the same tuning already established for `GalleryPhoto#display_variant` and `AboutPageContent#slideshow_display_variant`, reused here rather than re-derived (see Implementation Decisions). |
| social share variant | A second, hero-only variant — `resize_to_fill: [1200, 630], saver: { quality: 80, keep: :icc }` — sized to the aspect ratio social platforms expect for a link preview image. Never rendered on the page itself; used only for `og:image`, `twitter:image`, and schema.org `image`. |
| `ImageAttachmentValidatable` | The shared validation concern at `app/models/concerns/image_attachment_validatable.rb` (SPEC-008). This spec modifies its `MAX_IMAGE_SIZE` constant in place (R8) and includes it unmodified otherwise. |

---

## Interfaces

### Public Frontend

- `GET /` — `PagesController#home` (unchanged). `app/views/pages/home.html.erb`'s existing `content = @home_page_content&.published? ? @home_page_content : nil` local (unchanged) becomes the basis for both slots' resolution, exactly as it already is for the 4 existing text fields.
- The `<meta property="og:image">`, `<meta name="twitter:image">` tags (`app/views/layouts/application.html.erb`) and the `local_business_schema["image"]` JSON-LD field (rendered on every page) both change source per R12-R13.

### Admin

No new routes. The existing `Admin::HomePageContentsController` actions are extended in place:

| Verb | Path | Action | Extension in this spec |
|------|------|--------|------------------------|
| GET | /admin/home_page_content | `#show` | Renders 2 new file inputs, current-image thumbnails, and 2 "remove image" checkboxes alongside the existing 4 text fields |
| PATCH | /admin/home_page_content | `#update` | Permits 2 new file params and 2 new removal-checkbox params; purges a slot when checked (unless a new file for that slot arrived in the same request — R15); multipart form (auto-detected by `form_with` once a file field is present) |
| PATCH | /admin/home_page_content/restore_defaults | `#restore_defaults` | Also purges `hero_image` and `cta_image`, in addition to its existing 4-field text reset |

### Data Model

No new table. `HomePageContent` gains 2 named attachments, living in the existing polymorphic `active_storage_attachments`/`active_storage_blobs` tables (installed by SPEC-008), not as columns on `home_page_contents`:

```ruby
class HomePageContent < ApplicationRecord
  include ImageAttachmentValidatable

  has_one_attached :hero_image
  has_one_attached :cta_image

  validates_image_attachment :hero_image, :cta_image
end
```

### Validation

`HomePageContent` includes `ImageAttachmentValidatable` (already used by `AboutPageContent` and `GalleryPhoto`) and calls `validates_image_attachment :hero_image, :cta_image`. No presence validation — an unattached slot is valid and expected, exactly as for About's 3 slots (SPEC-009).

**`ImageAttachmentValidatable::MAX_IMAGE_SIZE` changes from `15.megabytes` to `30.megabytes` (R8).** This is a shared constant, so the change also applies to `GalleryPhoto#image` and `AboutPageContent#slideshow_image_1/2/3` — intentionally; see Implementation Decisions. `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES` is unchanged (`image/jpeg`, `image/png`, `image/webp`).

### Required i18n Keys

New, under `admin.home_page_content`:

| Key | Purpose |
|-----|---------|
| `hero_image_label` | Label for the hero file input |
| `cta_image_label` | Label for the CTA file input |
| `image_hint` | Shared hint beneath each file input: allowed types, **30 MB** max, blank keeps the current image |
| `remove_hero_image_label` | Label for the hero "remove image" checkbox |
| `remove_cta_image_label` | Label for the CTA "remove image" checkbox |

**Existing keys whose text must change because R8 raises the shared cap from 15 MB to 30 MB** — every hardcoded "15 MB" in the app becomes stale the moment `MAX_IMAGE_SIZE` changes, regardless of which spec originally wrote the copy:

| Key | Old Value | New Value |
|-----|-----------|-----------|
| `activerecord.errors.messages.file_too_large` | "must be smaller than 15 MB" | "must be smaller than 30 MB" |
| `admin.gallery_photos.image_hint` | "JPEG, PNG, or WEBP. Maximum 15 MB." | "JPEG, PNG, or WEBP. Maximum 30 MB." |
| `admin.about_page_content.slideshow_image_hint` | "...Maximum 15 MB. Leave blank to keep the current image." | "...Maximum 30 MB. Leave blank to keep the current image." |

**Updated** `confirm_restore_defaults` under `admin.home_page_content` (currently text-only, matching About's pre-SPEC-009 wording), per R18:

| Key | Old Value | New Value |
|-----|-----------|-----------|
| `confirm_restore_defaults` | "This will replace your current edits with the original default text. Continue?" | "This will replace your current edits with the original default text and remove any uploaded hero/CTA images. Continue?" |

---

## Rules

### Data Model, Variants, Fallback

R1: `HomePageContent` gains `has_one_attached :hero_image` and `has_one_attached :cta_image`, per the Interfaces section's Data Model. No migration beyond the `active_storage:install` migration SPEC-008 already ran.

R2: `HomePageContent` includes `ImageAttachmentValidatable` and calls `validates_image_attachment :hero_image, :cta_image`. No presence validation is added — an unattached slot is valid and falls back to the static file.

R3: `HomePageContent` gains `hero_display_variant` and `cta_display_variant` methods, each returning `public_send(name).variant(resize_to_limit: [1200, 1200], saver: { quality: 80, keep: :icc })` — the exact tuning already established for `GalleryPhoto#display_variant` and `AboutPageContent#slideshow_display_variant`, reused rather than re-derived.

R4: `HomePageContent` gains a `social_share_variant` method — **hero slot only** — returning `hero_image.variant(resize_to_fill: [1200, 630], saver: { quality: 80, keep: :icc })`. `resize_to_fill`, not `resize_to_limit`, matching `GalleryPhoto#thumbnail_variant`'s established precedent for a fixed-aspect-ratio crop: social scrapers do not reliably letterbox a non-matching aspect ratio well, so the crop is done once, server-side, rather than left to the consumer. This variant is never used inside `home.html.erb` — only by R12/R13.

R5: Each slot independently falls back to its bundled static file when unattached: hero → `gallery/m45a2849.jpg`, CTA → `gallery/m45a2996.jpg`. Both files remain in the repository permanently and are never copied into Active Storage — identical reasoning to SPEC-009 R6.

R6: Each slot is resolved independently in `app/views/pages/home.html.erb`: the hero section's `background-image` resolves to `content.hero_display_variant`'s URL when `content&.hero_image&.attached?`, else the static fallback; the CTA section resolves the same way against `cta_image`/`cta_display_variant`. One slot having an uploaded image has no effect on the other slot's resolution.

R7: Publish gating for both slots reuses the existing `HomePageContent#published` column — no second flag. A slot renders its uploaded image only when **both** `content` is non-nil (i.e. `HomePageContent.first&.published?` is `true`, per the existing `content` local) **and** that specific slot has an attachment. If `published?` is `false`, both slots render their static fallback regardless of what is attached — identical to how the 4 existing text fields already fall back (mirrors SPEC-009 R5).

### Shared Size Cap

R8: `ImageAttachmentValidatable::MAX_IMAGE_SIZE` is raised from `15.megabytes` to `30.megabytes`. Because the constant is shared by `GalleryPhoto`, `AboutPageContent`, and now `HomePageContent`, this raises the cap for all three — deliberately. These are all ordinary photos taken on Doug's phone; a cap that differs by which admin screen he happens to be on is confusing and has no underlying rationale (the original 15 MB figure was itself derived from real file sizes already in the repo, not from a per-surface risk assessment — see ADR-005 Decision 4). `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES` is unchanged.

R9: Every i18n string that states the file-size limit in prose must be updated to say 30 MB, not just the ones this spec's own admin screen introduces — see the Required i18n Keys table above for the exhaustive list of existing keys that go stale the moment R8 ships. No hardcoded "15 MB" string may remain anywhere in the app after this spec is implemented.

### Known Risk — Not Solved Here

R10: Hero/CTA uploads are ordinary multipart form submissions (`form_with` auto-`multipart`), not Active Storage direct uploads. No request-body size limit is configured at the Kamal-managed reverse proxy (`config/deploy.yml`'s `proxy:` block has no such setting). A 30 MB file will therefore be accepted by the proxy, but on a slow mobile connection it can exceed a request/read timeout partway through and fail in a way indistinguishable, from Doug's side, from "it just didn't work." **This is a named, deferred risk, not something this spec fixes.** The remedy — migrating hero/CTA (and, by the same logic, About/Gallery) uploads to Active Storage direct upload, which streams the file from the browser straight to storage and reports progress — is the follow-up if Doug reports upload failures in practice. What **is** in scope here: the admin form must state the 30 MB limit in visible copy (`image_hint`, R9), and a rejected upload — oversize or wrong content type — must produce a specific, attributable validation error (already guaranteed by `ImageAttachmentValidatable`'s per-attribute `errors.add`), not a generic failure page.

### Alt Text

R11: **Decision: the hero and CTA sections remain undecorated CSS `background-image`s.** No `alt` attribute is introduced (there has never been one — these are not `<img>` tags), and no admin-editable alt-text field is added for either slot. The existing visible `<h1>` + tagline (hero) and `<h1>` (CTA) already carry each section's meaning to assistive technology and to search engines; nothing is hidden behind either image. This is a deliberate, argued choice, not an oversight — see Implementation Decisions for the alternative that was considered and rejected. A developer implementing this spec must **not** add `slideshow_alt`-style fields by reflexively copying SPEC-009's pattern; R11 is the answer, not a placeholder.

### Social Share Image / Schema.org

R12: `MetaTagsHelper#social_share_image_url` is rewritten: it looks up `HomePageContent.first`; when that record is `published?` **and** its `hero_image` is attached, it returns an absolute URL for `social_share_variant` (R4); otherwise it returns `image_url(StructuredDataHelper::BUSINESS_IMAGE)`, unchanged from today. "Absolute URL" means the same contract `image_url` already provides — a full `https://...` URL, since social scrapers do not follow relative paths and will not fetch anything behind an authenticated or relative reference.

R13: `StructuredDataHelper#local_business_schema`'s `"image"` key is changed from `image_url(BUSINESS_IMAGE)` to a call to `social_share_image_url` (R12) — the exact same method, not a re-implementation of its conditional. Both helper modules are mixed into the same view/controller context in this app, so the method is directly callable from `local_business_schema`. This is the mechanism by which `og:image` and schema `image` are guaranteed to agree: there is exactly one place the resolution logic lives.

### Admin UI and Controller

R14: The admin Home form (`app/views/admin/home_page_contents/show.html.erb`) gains, for each of the 2 slots: an `f.file_field`, a thumbnail preview of the current image (or a short "using default image" indicator when the slot is unattached), and a "remove image" checkbox. Positioned near the top of the form, before the 4 existing text fields, since the hero/CTA images are the first thing a visitor sees.

R15: `Admin::HomePageContentsController#update` purges a slot when its removal checkbox is checked **unless** a new file was also submitted for that same slot in the same request — a simultaneous upload always wins over a simultaneous removal request, so the outcome of one form submission is never ambiguous. Implementation shape: purge checked-and-not-replaced slots first, then call `update` with the permitted params, so `has_one_attached=`'s own replace-and-purge-old-blob behavior (confirmed by ADR-005, reused unmodified from SPEC-009 R8) governs the "new file present" case without any extra code.

R16: `home_page_content_params` permits `:hero_image, :cta_image, :remove_hero_image, :remove_cta_image` alongside the existing 4 text params and `:published`.

R17: `Admin::HomePageContentsController#restore_defaults` is extended: after resetting the 4 text fields via `i18n_default_attributes` (unchanged), it also purges `hero_image` and `cta_image`, each guarded by `.attached?` — identical shape to SPEC-009 R7 for About's 3 slots. `published` remains untouched.

R18: The `confirm_restore_defaults` i18n string (under `admin.home_page_content`) is updated per the Interfaces table so the confirmation dialog accurately describes that uploaded images are also removed, not just text — same reasoning as SPEC-009 R10, applied to Home's own key (About's key is separate and already correct as of SPEC-009).

R19: The 2 new file inputs and 2 removal checkboxes follow CLAUDE.md's mobile-first rules: `w-full` file inputs, checkbox labels with adequate tap padding, positioned within the existing form's vertical rhythm, introducing no horizontal scroll at any viewport width including 375 px.

R20: After a successful `#update` that attaches a new `hero_image` and/or `cta_image`, the controller synchronously processes the relevant variant(s) — `hero_display_variant.processed`, `social_share_variant.processed` (hero only), `cta_display_variant.processed` (CTA only) — matching ADR-005 Decision 5's established pattern for `GalleryPhoto#create` ("generate the variant synchronously right after attach... so the first public visitor after an upload doesn't pay processing latency"). This matters more here than for Gallery: a social-media crawler fetching `og:image` immediately after Doug shares a freshly-updated link should not be the first request to trigger variant processing.

---

## Edge Cases

E1: No `HomePageContent` row exists (or one exists with neither slot attached). Both sections render their static fallback; `og:image`/`twitter:image`/schema `image` all resolve to `image_url(BUSINESS_IMAGE)`.

E2: `published: false`, both slots attached. Both sections still render their static fallback, and the social/schema image also falls back — the publish gate applies uniformly (R7, R12).

E3: `published: true`, only `hero_image` attached. Hero section renders the uploaded image; CTA section renders its static fallback; `og:image`/schema `image` resolve to the uploaded hero's `social_share_variant`.

E4: `published: true`, only `cta_image` attached. CTA section renders the uploaded image; hero section renders its static fallback; `og:image`/schema `image` **also fall back** to `BUSINESS_IMAGE` — the social/schema image is tied to the hero slot specifically, not "any uploaded home image" (R4, R12).

E5: An upload to either slot is rejected (e.g. `image/svg+xml`). HTTP 422; no attachment persisted for that slot; because `#update` is a single whole-record call, none of the other submitted fields persist either (matches existing all-or-nothing `#update` behavior).

E6: An upload to either slot exceeds 30 MB. HTTP 422; rejected by R8's raised size validation.

E7: `restore_defaults` called with both slots attached. Both purged; the 4 text fields reset from i18n; `published` unchanged.

E8: `restore_defaults` called with zero slots attached. Each purge is guarded by `.attached?`; nothing raises.

E9: A new file is uploaded to a slot that already has an attachment, via a normal (non-restore) `#update`. The old blob is replaced and purged automatically (Active Storage default, R15).

E10: `remove_hero_image` is checked **and** a new `hero_image` file is submitted in the same request. The new file wins (R15) — the slot ends attached to the new file, not empty.

E11: `remove_hero_image` is checked with no new file submitted, and `hero_image` was previously attached. The slot is purged; on the next render it shows the static fallback; `og:image`/schema `image` also revert to `BUSINESS_IMAGE` (since the hero slot is now unattached — same rule as E4, applied to the removal path).

E12: `HomePageContent.first` returns `nil` entirely (fresh deployment, before any save or restore has happened). Both sections render their static fallbacks; social/schema image falls back; no `NoMethodError`.

---

## Acceptance Criteria

### Public Page Behavior

AC-1: Given no `HomePageContent` row exists, when `GET /`, then the hero section's background-image resolves to the asset path for `gallery/m45a2849.jpg` and the CTA section's to `gallery/m45a2996.jpg`.

AC-2: Given `HomePageContent` exists with `published: true` and `hero_image` attached (valid JPEG), when `GET /`, then the hero section's background-image is an Active Storage representation URL, and the CTA section's remains the static asset path.

AC-3: Given `HomePageContent` exists with `published: true` and `cta_image` attached, when `GET /`, then the CTA section's background-image is an Active Storage representation URL, and the hero section's remains the static asset path.

AC-4: Given `HomePageContent` exists with `published: false` and both slots attached, when `GET /`, then both sections render their static asset paths.

AC-5: Given `HomePageContent` exists with `published: true` and both slots attached, when `GET /`, then both sections render Active Storage representation URLs.

### Social Share Image / Schema

AC-6: Given `HomePageContent` exists with `published: true` and `hero_image` attached, when any page is rendered, then the `og:image` and `twitter:image` meta tag `content` values equal the absolute URL of that record's `social_share_variant`.

AC-7: Given the same state as AC-6, then `local_business_schema["image"]` equals the exact same URL as AC-6's `og:image` value.

AC-8: Given `hero_image` is not attached (regardless of `published`), when any page is rendered, then `og:image`, `twitter:image`, and `local_business_schema["image"]` all equal `image_url("gallery/m45a2849.jpg")` — unchanged from current behavior.

AC-9: Given `HomePageContent` exists with `published: false` and `hero_image` attached, when any page is rendered, then `og:image`/`twitter:image`/schema `image` still resolve to the `BUSINESS_IMAGE` fallback — the publish gate applies to the social image too.

AC-10: Given `HomePageContent` exists with `published: true` and only `cta_image` attached (not `hero_image`), when any page is rendered, then `og:image`/`twitter:image`/schema `image` resolve to the `BUSINESS_IMAGE` fallback, confirming the social image is hero-specific.

### Admin Behavior

AC-11: Given admin is authenticated, when `PATCH /admin/home_page_content` with a valid `hero_image` file (JPEG, under 30 MB) plus valid values for the existing required text fields, then `HomePageContent.first.hero_image.attached?` is `true`, and the response redirects with `flash[:notice]`.

AC-12: Given admin is authenticated, when `PATCH /admin/home_page_content` with `cta_image` as an `image/svg+xml` file, then HTTP 422, no attachment is persisted for the CTA slot, and the response body includes a content-type validation error.

AC-13: Given admin is authenticated, when `PATCH /admin/home_page_content` with `hero_image` exceeding 30 MB, then HTTP 422 and the response body includes a file-size validation error whose text states the 30 MB limit.

AC-14: Given admin is authenticated, when `PATCH /admin/home_page_content` with `hero_image` at 29 MB (a file that would have been rejected under the old 15 MB cap), then the update succeeds — confirming R8's raised cap took effect.

AC-15: Given a `GalleryPhoto` or `AboutPageContent` slideshow slot, when a file between 15 MB and 30 MB is attached, then validation passes — confirming the shared-constant change (R8) applies system-wide, not only to `HomePageContent`.

AC-16: Given admin is authenticated and `hero_image` is attached, when `PATCH /admin/home_page_content` with `remove_hero_image: "1"` and no new `hero_image` file, then `HomePageContent.first.hero_image.attached?` is `false` afterward.

AC-17: Given admin is authenticated and `hero_image` is attached, when `PATCH /admin/home_page_content` with `remove_hero_image: "1"` **and** a new `hero_image` file in the same request, then `HomePageContent.first.hero_image.attached?` is `true` and the attached blob is the new file, not empty (the upload wins).

AC-18: Given admin is authenticated and `HomePageContent` exists with both slots attached, when `PATCH /admin/home_page_content/restore_defaults`, then both `hero_image.attached?` and `cta_image.attached?` are `false`, the 4 text fields equal their `I18n.t("pages.home.*")` originals, `published` is unchanged, and the response redirects with `flash[:notice]`.

AC-19: Given admin is authenticated and `HomePageContent` exists with zero slots attached, when `PATCH /admin/home_page_content/restore_defaults`, then the action completes normally without raising.

AC-20: The admin Home form (`GET /admin/home_page_content`) includes file inputs named `home_page_content[hero_image]`, `[cta_image]` and checkboxes named `home_page_content[remove_hero_image]`, `[remove_cta_image]`.

AC-21: Given `hero_image` is already attached, when `PATCH /admin/home_page_content` with a new `hero_image` file, then exactly one `ActiveStorage::Attachment` record exists for `name: "hero_image"` on that `HomePageContent` afterward (old blob replaced, not accumulated).

AC-22: Given a request is NOT authenticated, when `PATCH /admin/home_page_content/restore_defaults`, then the response redirects (auth guard, unchanged) and no `HomePageContent` data changes.

AC-26: Given admin is authenticated, when `PATCH /admin/home_page_content` attaches a new `hero_image`, then `HomePageContent.first.hero_image.variant(resize_to_limit: [1200, 1200], saver: { quality: 80, keep: :icc }).processed` and the `social_share_variant` equivalent are both already processed (an `ActiveStorage::VariantRecord` exists for each) by the time the response is returned — the first public/social request does not trigger cold variant generation.

### Copy and Accessibility

AC-23: `activerecord.errors.messages.file_too_large`, `admin.gallery_photos.image_hint`, and `admin.about_page_content.slideshow_image_hint` all state "30 MB", not "15 MB". `admin.home_page_content.confirm_restore_defaults`'s content mentions uploaded images being removed, in addition to text. No hardcoded English strings are introduced by this spec's view or controller changes.

AC-24: Neither the hero nor the CTA section's rendered markup contains an `alt` attribute, an `aria-label` describing the image, or any other new accessible-name annotation tied to the background image — confirming R11's decorative-background decision was implemented as specified, not silently upgraded to an `<img>` + alt-text pattern.

AC-25: The admin Home form renders without horizontal scroll at 375 px viewport width, including the 2 new file inputs and their thumbnails/checkboxes.

---

## Acceptance Tests

AT1
Given no `HomePageContent` row exists
When `GET /`
Then the hero background resolves to `gallery/m45a2849.jpg` and the CTA background resolves to `gallery/m45a2996.jpg`
Covers: R5, R6, AC-1, E1, E12

AT2
Given `HomePageContent` exists with `published: true` and `hero_image` attached
When `GET /`
Then the hero background is an Active Storage representation URL and the CTA background remains the static path
Covers: R1, R3, R6, AC-2, E3

AT3
Given `HomePageContent` exists with `published: true` and `cta_image` attached
When `GET /`
Then the CTA background is an Active Storage representation URL and the hero background remains the static path
Covers: R1, R3, R6, AC-3, E4

AT4
Given `HomePageContent` exists with `published: false` and both slots attached
When `GET /`
Then both backgrounds render their static asset paths
Covers: R6, R7, AC-4, E2

AT5
Given `HomePageContent` exists with `published: true` and both slots attached
When `GET /`
Then both backgrounds render Active Storage representation URLs
Covers: R3, R6, AC-5

AT6
Given `HomePageContent` exists with `published: true` and `hero_image` attached
When any page is rendered
Then `og:image` and `twitter:image` equal the absolute URL of `social_share_variant`, and `local_business_schema["image"]` equals the same URL
Covers: R4, R12, R13, AC-6, AC-7

AT7
Given `hero_image` is not attached
When any page is rendered
Then `og:image`, `twitter:image`, and schema `image` all equal `image_url("gallery/m45a2849.jpg")`
Covers: R12, R13, AC-8

AT8
Given `HomePageContent` exists with `published: false` and `hero_image` attached
When any page is rendered
Then `og:image`/`twitter:image`/schema `image` resolve to the `BUSINESS_IMAGE` fallback
Covers: R12, AC-9

AT9
Given `HomePageContent` exists with `published: true` and only `cta_image` attached
When any page is rendered
Then `og:image`/`twitter:image`/schema `image` resolve to the `BUSINESS_IMAGE` fallback
Covers: R4, R12, AC-10, E4

AT10
Given admin is authenticated
When `PATCH /admin/home_page_content` with a valid `hero_image` file and valid values for all required text fields
Then `HomePageContent.first.hero_image.attached?` is `true` and the response redirects with `flash[:notice]`
Covers: R1, R14, R16, AC-11

AT11
Given admin is authenticated
When `PATCH /admin/home_page_content` with `cta_image` as an `image/svg+xml` file
Then HTTP 422, `cta_image.attached?` is falsy, and the response includes a content-type validation error
Covers: R2, AC-12, E5

AT12
Given admin is authenticated
When `PATCH /admin/home_page_content` with `hero_image` exceeding 30 MB
Then HTTP 422 and the response includes a file-size validation error mentioning 30 MB
Covers: R8, R9, AC-13, E6

AT13
Given admin is authenticated
When `PATCH /admin/home_page_content` with `hero_image` at 29 MB
Then the update succeeds
Covers: R8, AC-14

AT14
Given a `GalleryPhoto` and an `AboutPageContent` slideshow slot
When a file between 15 MB and 30 MB is attached to each and validated
Then both are valid
Covers: R8, AC-15

AT15
Given admin is authenticated and `hero_image` is attached
When `PATCH /admin/home_page_content` with `remove_hero_image: "1"` and no new file
Then `hero_image.attached?` is `false` afterward
Covers: R15, AC-16, E11

AT16
Given admin is authenticated and `hero_image` is attached
When `PATCH /admin/home_page_content` with `remove_hero_image: "1"` and a new `hero_image` file in the same request
Then `hero_image.attached?` is `true` and the blob is the new file
Covers: R15, AC-17, E10

AT17
Given admin is authenticated and `HomePageContent` exists with both slots attached
When `PATCH /admin/home_page_content/restore_defaults`
Then both slots are unattached, the 4 text fields equal their i18n originals, `published` is unchanged, and the response redirects with `flash[:notice]`
Covers: R17, AC-18, E7

AT18
Given admin is authenticated and `HomePageContent` exists with zero slots attached
When `PATCH /admin/home_page_content/restore_defaults`
Then the action does not raise and completes with a normal redirect
Covers: R17, AC-19, E8

AT19
Given admin is authenticated
When `GET /admin/home_page_content`
Then the response includes file inputs named `home_page_content[hero_image]`, `[cta_image]` and checkboxes `[remove_hero_image]`, `[remove_cta_image]`
Covers: R14, R16, AC-20

AT20
Given admin is authenticated and `hero_image` is already attached
When `PATCH /admin/home_page_content` with a new `hero_image` file
Then exactly one `ActiveStorage::Attachment` record exists for `name: "hero_image"` afterward
Covers: R15, AC-21, E9

AT21
Given no active admin session
When `PATCH /admin/home_page_content/restore_defaults`
Then the response redirects and no `HomePageContent` data changes
Covers: R17, AC-22

AT25
Given admin is authenticated and `HomePageContent` has no `hero_image` attached
When `PATCH /admin/home_page_content` attaches a new `hero_image`
Then, immediately after the response returns, an `ActiveStorage::VariantRecord` already exists for both the display variant and the social share variant of that blob — the first subsequent public/social request does not trigger cold processing
Covers: R20, AC-26

AT22
Given the `activerecord.errors.messages.file_too_large`, `admin.gallery_photos.image_hint`, `admin.about_page_content.slideshow_image_hint`, `admin.home_page_content.image_hint`, and `admin.home_page_content.confirm_restore_defaults` i18n strings
When inspected
Then the first four state "30 MB" and the last mentions images being removed
Covers: R9, R10, R18, AC-23

AT23
Given `app/views/pages/home.html.erb` as modified by this spec
When inspected for `alt` attributes or `aria-label`s tied to the hero/CTA background images
Then none are found
Covers: R11, AC-24

AT24
Given admin is authenticated
When `GET /admin/home_page_content` is rendered at 375 px viewport width (system spec)
Then no horizontal scroll occurs and the 2 new file inputs carry `w-full`
Covers: R19, AC-25

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-02 | Alt text: hero/CTA stay as undecorated CSS backgrounds — no `alt`, no admin field (R11) | The alternative — converting each full-screen section to a positioned `<img>` with `object-fit: cover` plus an overlaid `<h1>`/tagline, matching About's slideshow markup shape, so an admin-editable alt field becomes possible — was seriously considered, since it's the only way these images could ever carry a real accessible name. It was rejected because it is a strictly larger and riskier change than the one actually requested: it means rewriting two full-bleed, `h-screen` layouts (hero has a bottom-aligned text block over a `flex items-end` container; CTA is centered) and re-verifying both at every breakpoint this codebase already tests at 375/390/414px, all to solve an accessibility gap that does not currently exist — a CSS background image with no semantic content behind an already-present, already-accessible `<h1>` is not an accessibility gap at all; it is the same treatment every hero-image marketing site uses, and WCAG does not require alt text for purely decorative backgrounds. Doing (b) here would also create an inconsistency the next developer has to explain: why does Home get real alt text but not have the elaborate multi-image slideshow About has? About's alt fields exist because About has 3 *content* photos genuinely worth describing in sequence; Home's hero/CTA are backdrop treatment behind headline copy that already says what needs saying. (a) is the smaller, more honest change and is fully argued here so a future developer does not "fix" this by copying SPEC-009's `slideshow_alt_N` pattern under the assumption it was simply forgotten. |
| 2026-09-02 | `MAX_IMAGE_SIZE` raised from 15 MB to 30 MB as one shared constant, not a Home-specific override (R8) | `ImageAttachmentValidatable` is deliberately shared infrastructure (ADR-005 Implementation Note 3) precisely so `GalleryPhoto`, `AboutPageContent`, and `HomePageContent` validate identically — introducing a Home-only override would reintroduce exactly the "why does this screen have a different limit" confusion a single shared constant was chosen to avoid. The original 15 MB figure was itself derived from real camera-JPEG sizes already in the repo at the time (ADR-005 Decision 4: "roughly 2x the largest file observed"), not from a considered per-surface risk ceiling, so raising it uniformly for "the same kind of photo, from the same phone, on a different screen" is a like-for-like extension of the same reasoning, not a new risk posture. |
| 2026-09-02 | Direct upload deferred as a named follow-up, not implemented now (R10) | Doug has only just finished a staging trial; there is no reported evidence yet that ordinary multipart uploads fail for him on mobile. Implementing direct upload now would be solving a problem that may not materialize, at the cost of real new complexity (a Stimulus-driven upload progress UI, a new JS dependency or Rails' built-in `direct_uploads` route wiring, and above all a change to every existing image-upload form in the app, not just Home's). Recording it here as the specific, ready-to-reach-for remedy means that if Doug does report a failed upload, the fix is already scoped rather than requiring fresh investigation. |
| 2026-09-02 | Separate `social_share_variant` (1200×630 fill) distinct from `hero_display_variant`/`cta_display_variant` (1200×1200 limit) | The on-page hero is a full-bleed `background-size: cover` section with no fixed aspect ratio — a `resize_to_limit` fit (the same approach already used for About/Gallery) is the right shape there, since `bg-cover`/`bg-center` will crop whatever it's given regardless of source dimensions. `og:image` is different: social platforms (Facebook, X, etc.) read a specific recommended aspect ratio (~1.91:1, commonly delivered as 1200×630) and either crop unpredictably or letterbox when given something else. Producing the correctly-shaped crop once, server-side, is more reliable than hoping every consuming platform crops it well. |
| 2026-09-02 | `og:image`/schema `image` resolution centralized in one method (`social_share_image_url`), called from both `MetaTagsHelper` and `StructuredDataHelper` (R12-R13) | The two call sites existed independently before this spec, each hardcoding `BUSINESS_IMAGE`/`image_url` separately — which is exactly how they could already drift if only one were updated. Routing both through the same method removes the possibility of drift by construction rather than by discipline, and as a side effect means the `HomePageContent.first` lookup happens once per request path rather than being duplicated. |

---

## Dependencies

- **SPEC-008 (Gallery Photo Management)** — provides `active_storage:install`, `ruby-vips`, and `ImageAttachmentValidatable`, all reused unmodified except for the `MAX_IMAGE_SIZE` value itself (R8).
- **SPEC-009 (About Slideshow Image Uploads)** — this spec's data-model, validation, variant, and admin-form shape are a direct extension of SPEC-009's precedent to a second singleton. **Consequence for SPEC-009 and SPEC-008's own text:** both specs' finalized Rules/ACs/ATs state the file-size limit as "15 MB" in prose (e.g. SPEC-009 AC-7/AT7, SPEC-008's equivalent). This spec's implementation makes those specific numbers stale — the underlying *behavior* they describe (reject files over the shared cap) stays correct, but the literal "15 MB" text in those already-`ready`/`done` spec files will no longer match the app once R8 ships. This spec does not edit SPEC-008/009 (out of this agent's scope to modify already-approved specs unprompted) — flagging here so whoever schedules this work updates those two files' prose in the same pass, or accepts the drift consciously.
- ADR-004 (Singleton Content Model and Publish Flag Placement) — governs the `published`-column-reuse decision (R7); not re-derived here.
- ADR-005 (Photo Upload Data Model and Active Storage Strategy) — governs the data model, validation, and no-backfill decisions this spec extends to `HomePageContent`; not re-derived here.
- SPEC-006 (Home Page Content Editing) — provides `HomePageContent`, `Admin::HomePageContentsController`, and the existing admin form this spec extends.
- SPEC-012 (SEO/AEO Pass) — owns `StructuredDataHelper`/`MetaTagsHelper` in their current form; this spec modifies both in place.
- No new gems required.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Model: add `has_one_attached :hero_image, :cta_image` to `HomePageContent` (R1); include `ImageAttachmentValidatable`, call `validates_image_attachment` (R2); add `hero_display_variant`, `cta_display_variant`, `social_share_variant` (R3, R4). Raise `ImageAttachmentValidatable::MAX_IMAGE_SIZE` to 30 MB (R8). Update factory with attachment traits. | AC-2, AC-3, AC-5, AC-11-AC-15 | 3 |
| T2 | Public page: update `home.html.erb`'s two background sections for independent per-slot fallback (R5, R6, R7); confirm no `alt`/`aria-label` added (R11). | AC-1 – AC-5, AC-24 | 2 |
| T3 | `MetaTagsHelper#social_share_image_url` rewrite (R12) and `StructuredDataHelper#local_business_schema["image"]` delegation (R13). | AC-6 – AC-10 | 2 |
| T4 | Admin controller: extend `home_page_content_params` (R16); implement remove-checkbox purge-then-assign with new-file-wins tie-break (R15); extend `restore_defaults` (R17); synchronous variant processing after attach (R20); new/updated i18n keys including the cross-spec 30 MB copy fixes (R9, R10). | AC-11 – AC-23, AC-26 | 3 |
| T5 | Admin view: 2 file inputs, thumbnails, remove checkboxes, mobile-first (R14, R19). | AC-20, AC-25 | 2 |
| T6 | Tests: `HomePageContent` model spec (validations for both slots at the new 30 MB boundary, variant methods); request specs for `PagesController#home` (per-slot fallback, publish gating, hero-only social-image linkage); request specs for `Admin::HomePageContentsController` (upload happy path, rejection cases, remove-checkbox tie-break, restore_defaults purge); helper specs for `social_share_image_url`/`local_business_schema["image"]`; system spec for 375px admin form. All AAA, inline variables, no `let`/`let!`. | All | 4 |

Total estimated points: 16 (all tasks ≤ 4 points; no split review required under the ≥ 5-point guardrail)

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-09-02 | Initial draft | All | Translates the repo owner's post-staging-trial request into an implementation-ready spec, following SPEC-009's established pattern for a second `has_one_attached`-on-singleton image feature. Resolves the alt-text question explicitly (R11, decision (a)) rather than leaving it for the developer to guess. Raises the shared `MAX_IMAGE_SIZE` constant (R8) and identifies every existing i18n string that goes stale as a result (R9). Names, but explicitly defers, the multipart-upload/no-proxy-cap risk (R10) as a follow-up rather than in-scope work. Wires `og:image`/`twitter:image`/schema `image` to the uploaded hero through one shared resolution method (R12-R13) so the two can never independently drift. |

---

## Open Questions

None. All settled decisions from the requesting session are captured above (see Implementation Decisions for the two points — alt text and the shared size cap — that required an argued choice rather than a direct translation).
