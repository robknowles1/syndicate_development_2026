# Spec: Gallery Photo Management — Admin-Managed Photo Upload, Delete, and Reorder

**ID:** SPEC-008
**Status:** ready
**Priority:** medium
**Created:** 2026-07-14
**Author:** spec-agent

---

## Goal

Allow Doug to upload, delete, and reorder Gallery page photos through the admin backend without developer involvement, replacing the current `Dir.glob`-based filesystem listing with a genuine, admin-managed, position-ordered `GalleryPhoto` collection. Visitors continue to get a fast-loading page: every photo is served through a single resized `:display` variant, never as a multi-megabyte camera original. Implements ADR-005 Decision 2 (data model), Decision 3 (backfill), Decision 4 (validation), Decision 5 (variants), and — per the 2026-07-17 addendum to ADR-005, which supersedes original Decision 6 for Gallery's admin UI — a drag-and-drop reordering mechanism (SortableJS driving a new `gallery_sort_controller.js` Stimulus controller) replacing the Move Up/Move Down button pattern. Per ADR-005 Implementation Note 12, this spec has no dependency on SPEC-007/PR #38 and can be implemented immediately on a branch off current `main`.

---

## Non Goals

- Multi-file batch upload — one photo per submission, matching the existing camera-roll, one-field-per-submit shape of every other admin form in this codebase (ADR-005 Decision 6).
- Move Up/Move Down buttons, or any keyboard-operable reordering fallback — reordering is drag-and-drop only, via SortableJS driving a new `gallery_sort_controller.js` Stimulus controller, per explicit product decision (ADR-005's 2026-07-17 addendum, superseding original Decision 6). No non-drag alternative is provided; accepted because this is a single-admin (Doug-only) internal tool, not a public or multi-user surface.
- Per-photo captions or alt text — every photo continues to share the single generic `t("pages.gallery.photo_alt")` string, unchanged from current behavior (see Implementation Decisions).
- A "Gallery page published" visibility toggle — no such flag exists today for the Gallery page (unlike Services); none is introduced by this spec.
- Image cropping, rotation, filters, or any other editing tool — upload and delete only.
- A soft minimum pixel-dimension validation guard — considered and explicitly rejected (see Implementation Decisions).
- Pagination of the admin photo list — the expected collection size is dozens, not hundreds, per ADR-005's rationale for rejecting drag-and-drop.
- S3/cloud storage migration — local disk Active Storage service only, per ADR-005's "settled infrastructure" context.
- CI runner `libvips` provisioning — flagged as a blocking dependency for this spec's tests to pass in CI, but the `.github/workflows/ci.yml` change itself is devops-agent scope, not implemented here (see Dependencies).
- About page slideshow image uploads — covered separately by SPEC-009, blocked on this spec merging first.

---

## Definitions

| Term | Definition |
|------|-----------|
| `GalleryPhoto` | Dedicated ActiveRecord model, one row per photo, with an attached `image` and an integer `position` for display order. Open-ended collection — no fixed count, unlike `AboutPageContent`'s 3 slideshow slots (SPEC-009). |
| display variant | The named Active Storage variant `resize_to_limit: [1200, 1200], saver: { quality: 80 }`, generated from the original attached blob. The only image representation ever served to a site visitor or shown in the admin list — originals are never served directly. |
| content-type allowlist | The 3 MIME types Active Storage will accept for an upload: `image/jpeg`, `image/png`, `image/webp`. Checked against `blob.content_type` (Marcel content-sniffed from the file's actual bytes), not the filename extension or client-supplied header. `image/svg+xml` is deliberately excluded (stored-XSS vector). |
| backfill | The one-time, idempotent rake task that converts every file currently in `app/assets/images/gallery/*.jpg` into a `GalleryPhoto` row with an attached blob, run once manually as a required deploy step for this feature. |
| responsive photo grid | The admin `GalleryPhoto` list layout: `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2`, identical to the public Gallery page's own grid (`app/views/pages/gallery.html.erb`). Replaces the old stacked-card list for this collection only — `ServiceSection`'s admin list (`app/views/admin/services_pages/show.html.erb`) is unaffected and still uses stacked cards. |
| SortableJS | Third-party JavaScript library, pinned via `bin/importmap pin sortablejs` — the first non-Hotwire JavaScript dependency in this codebase. Implements pointer-event-based dragging (not the native HTML5 Drag and Drop API), so it works on both mouse and touch input. |
| `gallery_sort_controller` | The Stimulus controller (`app/javascript/controllers/gallery_sort_controller.js`) that initializes `Sortable` on the admin photo grid and, on drop, sends the new photo order to the server. |
| reorder request | The `PATCH /admin/gallery_photos/reorder` request `gallery_sort_controller.js` sends on drop: a JSON body `{ "photo_ids": [...] }` listing every `GalleryPhoto` id in its new display order, read from the grid's post-drop DOM order. |

---

## Interfaces

### Public Frontend

- `GET /gallery` — `PagesController#gallery` loads `@photos = GalleryPhoto.order(:position)`. The `Dir.glob` call is removed entirely. The view renders each photo's display variant.

### Admin

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/gallery_photos | `Admin::GalleryPhotosController#index` — lists all photos in a draggable responsive grid, includes the upload form |
| POST | /admin/gallery_photos | `#create` — uploads and attaches a new photo |
| DELETE | /admin/gallery_photos/:id | `#destroy` — purges the attached blob and deletes the photo |
| PATCH | /admin/gallery_photos/reorder | `#reorder` — accepts an ordered array of photo IDs and reassigns every `GalleryPhoto`'s `position` to match, in one transaction |

Route declaration (added to the existing `namespace :admin` block):

```ruby
resources :gallery_photos, only: [ :index, :create, :destroy ] do
  collection do
    patch :reorder
  end
end
```

`reorder` is a `collection` route, not a `member` route: unlike the removed `move_up`/`move_down`, it doesn't target one `GalleryPhoto` — it repositions the entire set in a single request.

Named routes generated: `admin_gallery_photos_path` (index GET / create POST), `admin_gallery_photo_path(photo)` (destroy DELETE), `reorder_admin_gallery_photos_path` (PATCH).

### Client-Side Reordering

New import map pin (`config/importmap.rb`), added via `bin/importmap pin sortablejs`:

```ruby
pin "sortablejs" # @1.x
```

This is the first third-party (non-Hotwire) JavaScript dependency in this codebase.

New Stimulus controller: `app/javascript/controllers/gallery_sort_controller.js`. It requires no manual registration step — the existing `eagerLoadControllersFrom("controllers", application)` call in `app/javascript/controllers/index.js` already auto-registers every controller under `app/javascript/controllers/`, per this codebase's existing convention. Addressable in the view as `data-controller="gallery-sort"`.

**Reorder request contract**, sent by the controller's `onEnd` handler on drop:

- Method/path: `PATCH` to `reorder_admin_gallery_photos_path`.
- Body: JSON, e.g. `{ "photo_ids": [7, 3, 9, 1] }` — every `GalleryPhoto` id currently in the grid, in the grid's new top-left-to-bottom-right DOM order, read from each tile's `data-gallery-photo-id` attribute after SortableJS has already relocated the dragged tile's DOM node.
- Headers: `Content-Type: application/json`, `Accept: application/json`, and `X-CSRF-Token` read from `document.querySelector('meta[name="csrf-token"]').content`. This app already renders `<%= csrf_meta_tags %>` in `app/views/layouts/application.html.erb`; a plain `fetch()` call from a Stimulus controller — unlike a Turbo-driven form or link submission — does not attach Rails' CSRF header automatically, so `gallery_sort_controller.js` must read and set it explicitly.
- Success response: `head :ok` (HTTP 200, empty body) — no redirect, no re-rendered HTML. The grid's DOM already reflects the new order, so the client needs no further update.
- Failure response: HTTP 422 (validation rejection, see R17) or a network-level failure. The controller surfaces `t("admin.gallery_photos.flash.reorder_failed")` via `alert()`, then calls `window.location.reload()` — discarding the optimistic client-side reorder and re-rendering the grid from server-side truth.

**Drag interaction feedback:** `Sortable.create(element, { animation: 150, ghostClass: "opacity-50", delay: 150, delayOnTouchOnly: true, filter: "[data-turbo-method='delete']", preventOnFilter: false, onEnd: ... })`. `ghostClass` visually marks the tile being dragged; `animation` smoothly reflows the other tiles as the drag position changes. `delay`/`delayOnTouchOnly` require a 150ms press-and-hold on touch devices before a drag starts, so a normal vertical swipe still scrolls the grid instead of being hijacked into a drag — mouse users are unaffected (`delayOnTouchOnly` scopes the delay to touch input only). `filter`/`preventOnFilter` exclude the per-tile Delete control from drag initiation entirely, so tapping Delete cannot be misread as a drag gesture. The reorder is optimistic: SortableJS relocates the dragged tile's DOM node the instant it's dropped, before the `fetch` resolves, so the grid never visibly waits on the network in the common (successful) case.

### Data Model

New table: `gallery_photos`

| Column | Type | Constraints |
|--------|------|-------------|
| `position` | integer | not null, default 0 |
| `created_at` | datetime | |
| `updated_at` | datetime | |

No foreign key, no other columns, per ADR-005 Decision 2. `image` is not a column — it lives in the polymorphic `active_storage_attachments`/`active_storage_blobs` tables, created by the one-time `bin/rails active_storage:install` migration (a shared prerequisite for this spec, run once and committed before the `gallery_photos` migration).

### Shared Validation Concern

New file: `app/models/concerns/image_attachment_validatable.rb` — a generic concern, not Gallery-specific, so SPEC-009 can reuse it unmodified for `AboutPageContent`'s 3 slideshow slots:

```ruby
module ImageAttachmentValidatable
  extend ActiveSupport::Concern

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  MAX_IMAGE_SIZE = 15.megabytes

  class_methods do
    def validates_image_attachment(*attachment_names)
      attachment_names.each do |name|
        validate -> { validate_image_attachment(name) }
      end
    end
  end

  private

  def validate_image_attachment(name)
    attachment = public_send(name)
    return unless attachment.attached?

    unless attachment.blob.content_type.in?(ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES)
      errors.add(name, :invalid_content_type)
    end

    if attachment.blob.byte_size > ImageAttachmentValidatable::MAX_IMAGE_SIZE
      errors.add(name, :file_too_large)
    end
  end
end
```

### Required i18n Keys

Add under `admin.gallery_photos` in `config/locales/en.yml`:

| Key | Purpose |
|-----|---------|
| `heading` | Admin page heading |
| `image_label` | Label for the upload file field |
| `image_hint` | Permanently visible hint: allowed types and 15 MB max |
| `save` | Upload submit button text |
| `drag_hint` | Permanently visible instructional text above the grid (e.g. "Drag and drop to reorder"), since dragging has no other on-screen affordance now that Move Up/Move Down buttons are gone |
| `delete` | Delete button label (per-tile overlay control) |
| `confirm_delete` | Turbo confirmation dialog text before delete executes |
| `empty_state` | Message shown when zero photos exist |
| `flash.uploaded` | Success flash after upload |
| `flash.deleted` | Success flash after delete |
| `flash.reorder_failed` | Error message shown client-side (via `alert()`) when a reorder request is rejected or fails; there is no success-path flash for reorder — the already-reordered grid is its own confirmation |

Add under `admin.dashboard`: `gallery_link` — link text on the dashboard pointing to the gallery photo admin.

Add under `activerecord.errors.messages` (top-level, sibling to `activerecord.errors.models`, **not** nested per-model): `invalid_content_type` and `file_too_large`. Placing these at the shared `activerecord.errors.messages.*` level (Rails' documented i18n fallback chain: `models.[model].attributes.[attr].[type]` → `models.[model].[type]` → **`messages.[type]`** → ...) means both `GalleryPhoto#image` (this spec) and `AboutPageContent#slideshow_image_1/2/3` (SPEC-009) resolve the same two messages automatically — no per-model duplication is needed when SPEC-009 reuses this concern.

| Key | Value |
|-----|-------|
| `invalid_content_type` | "must be a JPEG, PNG, or WEBP image" |
| `file_too_large` | "must be smaller than 15 MB" |

---

## Rules

R1: **Prerequisite.** `bin/rails active_storage:install` must be run and its generated migration committed before the `gallery_photos` migration, creating `active_storage_blobs`, `active_storage_attachments`, and `active_storage_variant_records`. This is a one-time, shared step for both this spec and the future SPEC-009 — it must not be run or committed a second time.

R2: **Prerequisite.** `gem "ruby-vips"` is added to `Gemfile` and `bundle install` is run, providing the `:vips` variant-processing backend already selected by `config.load_defaults 8.1`. No `config.active_storage.variant_processor` change is needed.

R3: `gallery_photos` table has exactly `position` (integer, not null, default 0) plus `created_at`/`updated_at` — no other columns, no foreign key.

R4: `GalleryPhoto has_one_attached :image`.

R5: `GalleryPhoto` validates that an image is attached via a custom `image_must_be_attached` validation (`errors.add(:image, :blank) unless image.attached?`) — a `GalleryPhoto` row with no image makes no sense, unlike an About slideshow slot (SPEC-009), where an unattached slot is a valid, expected state.

R6: `GalleryPhoto` includes `ImageAttachmentValidatable` and calls `validates_image_attachment :image`, per the Interfaces section's concern definition.

R7: The content-type validation (via R6) rejects any attached image whose `blob.content_type` is not in `%w[image/jpeg image/png image/webp]` — deliberately excluding `image/svg+xml` — adding an `:invalid_content_type` error on `:image`.

R8: The size validation (via R6) rejects any attached image whose `blob.byte_size` exceeds 15 megabytes, adding a `:file_too_large` error on `:image`.

R9: The `:invalid_content_type` and `:file_too_large` error messages are defined once, at `activerecord.errors.messages.*` (not duplicated per-model), per the Interfaces section's i18n table.

R10: `GalleryPhoto#display_variant` returns `image.variant(resize_to_limit: [1200, 1200], saver: { quality: 80 })`. This single named variant is used at every render call site in this spec — the public gallery grid thumbnail, the public gallery's click-through link target, and the admin list thumbnail. No second variant is defined.

R11: `PagesController#gallery` assigns `@photos = GalleryPhoto.order(:position)`. The existing `Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg"))` call is removed entirely from `PagesController#gallery`.

R12: `app/views/pages/gallery.html.erb` renders each `@photos` entry via `image_tag photo.display_variant, alt: t("pages.gallery.photo_alt")` — the same generic alt string for every photo, unchanged from current behavior. The wrapping `<a href>` targets `url_for(photo.display_variant)` — the same variant, not the raw original blob's download URL. Visitors never receive a camera-original file from this page at any point.

R13: `GET /admin/gallery_photos` (`#index`) lists `GalleryPhoto.order(:position)` as a responsive grid — `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2`, matching the public Gallery page's own grid exactly — where each cell is a draggable thumbnail tile (via `display_variant`) carrying a `data-gallery-photo-id="<id>"` attribute and a small per-tile Delete control overlaid on the thumbnail (not a button row below it, since Move Up/Move Down no longer occupy that space) — plus a single `f.file_field :image` upload form and a permanently visible drag-instruction hint (`t("admin.gallery_photos.drag_hint")`). The grid container carries `data-controller="gallery-sort"` so `gallery_sort_controller.js` can initialize SortableJS on it. When zero photos exist, an empty-state message (`t("admin.gallery_photos.empty_state")`) is shown instead of an empty grid.

R14: `POST /admin/gallery_photos` (`#create`) with a valid image: builds `GalleryPhoto.new(gallery_photo_params)`, sets `position: (GalleryPhoto.maximum(:position) || -1) + 1`, saves, then calls `photo.display_variant.processed` synchronously (so the first public visitor after an upload doesn't pay processing latency), and redirects to `admin_gallery_photos_path` with `flash[:notice] = t("admin.gallery_photos.flash.uploaded")`.

R15: `POST /admin/gallery_photos` with an invalid image (missing, wrong content-type, or oversized) re-renders `:index` at HTTP 422 — with `@photos` reloaded and `@gallery_photo` holding the validation errors — and persists no `GalleryPhoto` row.

R16: `DELETE /admin/gallery_photos/:id` (`#destroy`) calls `photo.image.purge` synchronously (explicit, not relying on implicit destroy-cascade behavior — see Implementation Decisions) before destroying the `GalleryPhoto` record, then redirects to `admin_gallery_photos_path` with `flash[:notice] = t("admin.gallery_photos.flash.deleted")`.

R17: `PATCH /admin/gallery_photos/reorder` (`#reorder`) receives the new display order as `params[:photo_ids]`, a JSON array of `GalleryPhoto` ids (see Interfaces → Client-Side Reordering for the exact request shape). The action rejects the request — `head :unprocessable_entity` (422), no `GalleryPhoto` changed — unless all of the following hold:
  - `params[:photo_ids]` is present and is an array;
  - every element is unique (no duplicates);
  - the array, treated as a set, exactly equals the set of every existing `GalleryPhoto` id (`GalleryPhoto.pluck(:id)`) — catching both foreign/non-existent ids and omitted existing photos in one check.

  When all three hold, the action updates every named `GalleryPhoto`'s `position` to its index within the array, inside a single `ActiveRecord::Base.transaction`, and responds `head :ok` (200, empty body) — no redirect, no flash, no re-rendered view, since the requesting client's grid already reflects the new order before the request is sent.

R18: The admin dashboard view (`GET /admin`) must include a link to `admin_gallery_photos_path` using `t("admin.dashboard.gallery_link")`.

R19: All admin-facing UI strings in `app/views/admin/gallery_photos/` and `Admin::GalleryPhotosController` are rendered via `t()` from `config/locales/en.yml` under `admin.gallery_photos`. No hardcoded English strings.

R20: The admin gallery photo grid and upload form follow the mobile-first rules from CLAUDE.md: no horizontal scroll at any viewport width, including 375 px; the grid itself (`grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2`) is inherently mobile-first, matching the public page's own responsive breakpoints; each tile's overlaid Delete control is sized for a comfortable touch target (minimum effective 44×44 px tap area, e.g. `p-2` around a sufficiently large icon) since it sits on a small thumbnail rather than in a full-width button row; the upload submit button carries at minimum `py-3`; the file field's wrapping container carries `w-full`.

R21: `lib/tasks/gallery_photos.rake` defines task `gallery_photos:backfill`, matching ADR-005 Implementation Note 7 exactly:

```ruby
namespace :gallery_photos do
  desc "One-time backfill of app/assets/images/gallery/*.jpg into GalleryPhoto records"
  task backfill: :environment do
    paths = Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg")).sort
    paths.each_with_index do |path, index|
      filename = File.basename(path)
      next if GalleryPhoto.joins(image_attachment: :blob)
                           .where(active_storage_blobs: { filename: filename })
                           .exists?

      photo = GalleryPhoto.create!(position: index)
      photo.image.attach(io: File.open(path), filename: filename)
    end
  end
end
```

Idempotent — skips filenames that already have a matching `GalleryPhoto` blob, so it is safe to run more than once. The 3 pre-existing `* copy.jpg` duplicates (`m45a2724 copy.jpg`, `m45a2778 copy.jpg`, `m45a2817 copy.jpg`) are intentionally included — the backfill's job is "make the database match what's currently live," not "curate the collection." Deleting unwanted duplicates becomes Doug's first use of the new delete button.

R22: The backfill task (R21) is a required manual deploy step — run once, after this feature's code deploys, before the live gallery is expected to show every photo — and is **not** invoked automatically by any migration, `db/seeds.rb`, or CI workflow step. Without this manual step, the Gallery page renders blank immediately after deploy (`Dir.glob` is removed per R11).

R23: `sortablejs` is pinned via `bin/importmap pin sortablejs`, adding a `pin "sortablejs"` entry to `config/importmap.rb` — the first third-party (non-Hotwire) JavaScript dependency in this codebase.

R24: `app/javascript/controllers/gallery_sort_controller.js` is a Stimulus controller that, on `connect()`, calls `Sortable.create(this.element, { animation: 150, ghostClass: "opacity-50", delay: 150, delayOnTouchOnly: true, filter: "[data-turbo-method='delete']", preventOnFilter: false, onEnd: this.onEnd.bind(this) })` against the grid container it's attached to (`data-controller="gallery-sort"`). The `delay`/`delayOnTouchOnly` options require a 150ms press-and-hold before a touch drag starts, so ordinary swipe-to-scroll on the photo grid is not hijacked into a drag on mobile — this is the specific touch behavior ADR-005's addendum cited as the reason for choosing SortableJS over native HTML5 drag-and-drop, and it must actually be configured, not merely available. `filter`/`preventOnFilter` exclude the per-tile Delete control from initiating a drag, preventing an accidental drag from a Delete tap. It requires no manual registration — the existing `eagerLoadControllersFrom("controllers", application)` call in `app/javascript/controllers/index.js` picks it up automatically, per the codebase's existing Stimulus convention.

R25: In `onEnd`, if the dropped tile's resulting index equals its starting index (`event.newIndex === event.oldIndex`), the controller performs no network request and no `GalleryPhoto` position changes — a pure client-side no-op (see E5). Otherwise, it reads every tile's `data-gallery-photo-id` in the grid's current (post-drop) DOM order and sends the reorder request described in Interfaces → Client-Side Reordering.

R26: The reorder `fetch()` call includes `X-CSRF-Token` read from the page's `<meta name="csrf-token">` tag (already rendered via `csrf_meta_tags` in `app/views/layouts/application.html.erb`), since a plain `fetch()` — unlike a Turbo-driven form or link submission — does not attach Rails' CSRF header automatically.

R27: `Admin::GalleryPhotosController#move_up` and `#move_down`, their `member` routes, and the `move_up`/`move_down`/`flash.moved` i18n keys are removed entirely. No keyboard-operable reordering fallback is provided — an explicit product decision (ADR-005's 2026-07-17 addendum), accepted because this is a single-admin (Doug-only) internal tool.

---

## Edge Cases

E1: A valid JPEG under 15 MB is uploaded. The record is valid and saves successfully.

E2: An uploaded file has `content_type` `image/svg+xml` (or any type outside the allowlist). Validation rejects it (R7); HTTP 422 on `#create`.

E3: An uploaded file's `blob.byte_size` exceeds 15 MB. Validation rejects it (R8); HTTP 422 on `#create`.

E4: `#create` is submitted with no file selected. `image_must_be_attached` (R5) rejects it; HTTP 422.

E5: A tile is dropped in the same position it was picked up from (`event.newIndex === event.oldIndex`). The `gallery_sort_controller.js` `onEnd` handler no-ops client-side — no fetch request is sent, and no `GalleryPhoto` position changes.

E6: A reorder request's `photo_ids` does not exactly match the full, current set of `GalleryPhoto` ids — e.g. it includes an id that doesn't exist or doesn't belong to the current set, omits an existing photo, or contains a duplicate. `#reorder` rejects the request (422); no `GalleryPhoto` position changes.

E7: `#reorder` is called with `photo_ids` empty or absent entirely. Rejected (422); no `GalleryPhoto` position changes.

E8: The backfill task runs against a fresh database where `app/assets/images/gallery/` contains N files and zero `GalleryPhoto` rows exist. Exactly N rows are created, one per file, positioned in the same alphabetical order the file glob already produced.

E9: The backfill task runs a second time (or runs when only some files have already been backfilled — e.g., a file added to the directory since the last run). Already-backfilled filenames are skipped; only genuinely new files produce new rows; `GalleryPhoto.count` does not grow for files already present.

---

## Acceptance Criteria

### Public Page Behavior

AC-1: Given 3 `GalleryPhoto` rows exist with `position` 0, 1, 2 (each with an attached image), when `GET /gallery`, then HTTP 200 and the 3 `<img>` tags appear in that position order.

AC-2: Given a `GalleryPhoto` with an attached image, when `GET /gallery`, then the `<img src>` resolves to the display-variant representation path, not the raw original blob's URL.

AC-3: Given a `GalleryPhoto`, when `GET /gallery`, then the wrapping `<a href>` also resolves to the same display-variant URL as the `<img src>` — never the raw original.

AC-4: Given zero `GalleryPhoto` rows exist, when `GET /gallery`, then HTTP 200, the page renders with zero images, and no error is raised.

AC-5: Given any `GalleryPhoto` with an attached image, when `GET /gallery`, then its `<img>` `alt` attribute equals `t("pages.gallery.photo_alt")` — the same generic string used for every photo.

### Data Model, Migration, and Gem

AC-6: Running `bin/rails db:migrate` on a fresh database creates `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`, and `gallery_photos` without error.

AC-7: The `gallery_photos` table has exactly `position` (integer, not null, default 0) plus `created_at`/`updated_at` — no other columns.

AC-8: `Gemfile.lock` includes `ruby-vips`; calling `.variant(...).processed` on an attached `GalleryPhoto#image` does not raise a missing-processor error.

### Model Validations

AC-9: Given a `GalleryPhoto` with no image attached, when validated, then it is invalid with an error present on `:image`.

AC-10: Given a `GalleryPhoto` with an attached image whose `content_type` is `image/svg+xml`, when validated, then it is invalid with an error on `:image` whose message equals `t("activerecord.errors.messages.invalid_content_type")`.

AC-11: Given a `GalleryPhoto` with an attached image whose `byte_size` exceeds 15 megabytes, when validated, then it is invalid with an error on `:image` whose message equals `t("activerecord.errors.messages.file_too_large")`.

AC-12: Given a `GalleryPhoto` with a valid JPEG under 15 MB attached, when validated, then it is valid (no errors).

### Admin Behavior

AC-13: Given admin is authenticated and 2 `GalleryPhoto` rows exist, when `GET /admin/gallery_photos`, then HTTP 200 and the response includes a `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2` container with 2 draggable tiles, each with a Delete control; no Move Up or Move Down controls are present anywhere in the response.

AC-14: Given admin is authenticated, when `GET /admin/gallery_photos`, then the response includes a file input with `name="gallery_photo[image]"` and a submit button.

AC-15: Given admin is authenticated and zero `GalleryPhoto` rows exist, when `GET /admin/gallery_photos`, then HTTP 200, no error, and the response includes `t("admin.gallery_photos.empty_state")`.

AC-16: Given admin is authenticated and zero prior `GalleryPhoto` rows exist, when `POST /admin/gallery_photos` with a valid JPEG under 15 MB, then a `GalleryPhoto` is created with `position: 0`, the response redirects to `admin_gallery_photos_path`, and `flash[:notice]` is present.

AC-17: Given admin is authenticated and one `GalleryPhoto` exists at `position: 0`, when `POST /admin/gallery_photos` with a second valid image, then the new row's `position` equals 1.

AC-18: Given admin is authenticated, when `POST /admin/gallery_photos` with an `image/svg+xml` file, then HTTP 422, `GalleryPhoto.count` is unchanged, and the response body includes a content-type validation error.

AC-19: Given admin is authenticated, when `POST /admin/gallery_photos` with a file exceeding 15 MB, then HTTP 422, `GalleryPhoto.count` is unchanged, and the response body includes a file-size validation error.

AC-20: Given admin is authenticated, when `POST /admin/gallery_photos` with no file selected, then HTTP 422, `GalleryPhoto.count` is unchanged, and the response body includes a presence validation error.

AC-21: Given admin is authenticated and a `GalleryPhoto` with an attached image exists, when `DELETE /admin/gallery_photos/:id`, then the row no longer exists, its blob is purged, the response redirects to `admin_gallery_photos_path`, and `flash[:notice]` is present.

AC-22: Given admin is authenticated and 3 `GalleryPhoto` rows exist (ids A, B, C) at positions 0, 1, 2, when `PATCH /admin/gallery_photos/reorder` with `photo_ids: [C.id, A.id, B.id]`, then C's position is 0, A's position is 1, B's position is 2, and the response is HTTP 200 with an empty body (no redirect).

AC-23: Given admin is authenticated and 3 `GalleryPhoto` rows exist, when `PATCH /admin/gallery_photos/reorder` is submitted with a `photo_ids` array that doesn't exactly match the current set of ids (contains a non-existent id, omits an existing photo, or contains a duplicate), then HTTP 422 and no `GalleryPhoto`'s position changes.

AC-24: Given admin is authenticated and 3 `GalleryPhoto` rows exist, when `PATCH /admin/gallery_photos/reorder` is submitted with an empty array or a missing `photo_ids` param, then HTTP 422 and no `GalleryPhoto`'s position changes.

AC-25: `GET /admin` returns HTTP 200 and the response body includes an `href` matching `admin_gallery_photos_path`.

AC-26: No hardcoded English strings appear in `app/views/admin/gallery_photos/` or `Admin::GalleryPhotosController`. All user-facing strings use `t()`.

AC-27: The admin gallery photo grid renders without horizontal scroll at 375 px viewport width, using `grid-cols-2` at that width; each tile's Delete control meets a minimum effective 44×44 px touch target; the upload submit button carries at least `py-3`.

AC-28: Given a request is NOT authenticated, when any `Admin::GalleryPhotosController` action is requested, then the response redirects to the login page and no `GalleryPhoto` data changes.

### Backfill

AC-29: Given `app/assets/images/gallery/*.jpg` contains N files and zero `GalleryPhoto` rows exist, when `rails gallery_photos:backfill` runs, then exactly N `GalleryPhoto` rows are created, each with an attached blob whose filename matches its source file, positioned in the same alphabetical order `Dir.glob(...).sort` already produced.

AC-30: Given the backfill task has already run once (all N files backfilled), when `rails gallery_photos:backfill` runs again, then `GalleryPhoto.count` is unchanged (idempotent — no duplicate rows).

AC-31: Given the backfill has already run for all but one file, when `rails gallery_photos:backfill` runs, then exactly one new `GalleryPhoto` row is created (for the missing file); existing rows are untouched.

AC-32: The backfill task is not referenced by `db/seeds.rb`, any file under `db/migrate/`, or `.github/workflows/ci.yml` — it is never invoked automatically.

### Drag-and-Drop Reordering Infrastructure

AC-33: `config/routes.rb` no longer defines `move_up`/`move_down` member routes for `gallery_photos`; requesting `PATCH /admin/gallery_photos/:id/move_up` (or `.../move_down`) raises a routing error rather than reaching a controller action.

AC-34: `config/importmap.rb` contains a `pin "sortablejs"` entry.

AC-35: `app/javascript/controllers/gallery_sort_controller.js` exists and is reachable via `data-controller="gallery-sort"` without any manual entry in `app/javascript/controllers/index.js` (relies on the existing `eagerLoadControllersFrom` convention).

AC-36: The admin `#index` grid container carries `data-controller="gallery-sort"`, and every rendered tile carries `data-gallery-photo-id` equal to its `GalleryPhoto#id`.

AC-37: `gallery_sort_controller.js`'s `onEnd` handler contains a guard that returns without issuing a `fetch` request when the drop event's `newIndex` equals its `oldIndex`.

AC-38: The reorder `fetch()` request sent by `gallery_sort_controller.js` sets an `X-CSRF-Token` header whose value is read from the page's `<meta name="csrf-token">` tag.

---

## Acceptance Tests

AT1
Given 3 `GalleryPhoto` rows exist with `position` 0, 1, 2 and attached images
When `GET /gallery`
Then HTTP 200 and the 3 `<img>` tags appear in that position order
Covers: R11, R12, AC-1

AT2
Given a `GalleryPhoto` with an attached JPEG image
When `GET /gallery`
Then the `<img>` `src` attribute is an Active Storage representation path (display variant), not the blob's raw download path
Covers: R4, R10, R12, AC-2

AT3
Given a `GalleryPhoto` with an attached image
When `GET /gallery`
Then the wrapping `<a>` tag's `href` equals the same display-variant URL as the `<img>` `src`
Covers: R10, R12, AC-3

AT4
Given zero `GalleryPhoto` rows exist
When `GET /gallery`
Then HTTP 200 and no error is raised
Covers: R11, AC-4

AT5
Given 2 `GalleryPhoto` rows with attached images
When `GET /gallery`
Then each rendered `<img>` `alt` attribute equals `t("pages.gallery.photo_alt")`
Covers: R12, AC-5

AT6
Given a fresh test database
When `bin/rails db:migrate` runs
Then `active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`, and `gallery_photos` all exist in the schema, and `gallery_photos` has only `position`, `created_at`, `updated_at`
Covers: R1, R3, AC-6, AC-7

AT7
Given the `ruby-vips` gem is installed
When `GalleryPhoto#display_variant.processed` is called on an attached image
Then no missing-processor error is raised
Covers: R2, R10, AC-8

AT8
Given a new `GalleryPhoto` with no image attached
When `valid?` is called
Then it is invalid and `errors[:image]` is present
Covers: R4, R5, AC-9, E4

AT9
Given a `GalleryPhoto` with an image attached with `content_type: "image/svg+xml"`
When `valid?` is called
Then it is invalid and `errors[:image]` includes `t("activerecord.errors.messages.invalid_content_type")`
Covers: R6, R7, R9, AC-10, E2

AT10
Given a `GalleryPhoto` with an image attached whose blob `byte_size` exceeds 15 megabytes
When `valid?` is called
Then it is invalid and `errors[:image]` includes `t("activerecord.errors.messages.file_too_large")`
Covers: R6, R8, R9, AC-11, E3

AT11
Given a `GalleryPhoto` with a valid JPEG under 15 MB attached
When `valid?` is called
Then it is valid (no errors)
Covers: R4, R5, R7, R8, AC-12, E1

AT12
Given admin is authenticated and 2 `GalleryPhoto` rows exist
When `GET /admin/gallery_photos`
Then HTTP 200 and the response includes a `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2` container with 2 draggable tiles, each with a Delete control, and zero Move Up/Move Down controls
Covers: R13, AC-13

AT13
Given admin is authenticated
When `GET /admin/gallery_photos`
Then the response includes a file input named `gallery_photo[image]` and a submit button
Covers: R13, AC-14

AT14
Given admin is authenticated and zero `GalleryPhoto` rows exist
When `GET /admin/gallery_photos`
Then HTTP 200, no error, and the response includes the empty-state message
Covers: R13, AC-15

AT15
Given admin is authenticated and zero prior `GalleryPhoto` rows exist
When `POST /admin/gallery_photos` with a valid JPEG under 15 MB
Then a `GalleryPhoto` is created with `position: 0`, the response redirects to `admin_gallery_photos_path`, and `flash[:notice]` is present
Covers: R14, AC-16

AT16
Given admin is authenticated and one `GalleryPhoto` exists at `position: 0`
When `POST /admin/gallery_photos` with a second valid image
Then the new row's `position` equals 1
Covers: R14, AC-17

AT17
Given admin is authenticated
When `POST /admin/gallery_photos` with an `image/svg+xml` file
Then HTTP 422, `GalleryPhoto.count` unchanged, and the response includes a content-type validation error
Covers: R15, AC-18, E2

AT18
Given admin is authenticated
When `POST /admin/gallery_photos` with a file exceeding 15 MB
Then HTTP 422, `GalleryPhoto.count` unchanged, and the response includes a file-size validation error
Covers: R15, AC-19, E3

AT19
Given admin is authenticated
When `POST /admin/gallery_photos` with no file selected
Then HTTP 422, `GalleryPhoto.count` unchanged, and the response includes a presence validation error
Covers: R15, AC-20, E4

AT20
Given admin is authenticated and a `GalleryPhoto` with an attached image exists
When `DELETE /admin/gallery_photos/:id`
Then `GalleryPhoto.count` decreases by 1, the blob is purged, the response redirects to `admin_gallery_photos_path`, and `flash[:notice]` is present
Covers: R16, AC-21

AT21
Given admin is authenticated and 3 `GalleryPhoto` rows exist (ids A, B, C) at positions 0, 1, 2
When `PATCH /admin/gallery_photos/reorder` with `photo_ids: [C.id, A.id, B.id]`
Then C's position is 0, A's position is 1, B's position is 2, and the response is HTTP 200 with an empty body
Covers: R17, AC-22

AT22
Given admin is authenticated and 3 `GalleryPhoto` rows exist
When `PATCH /admin/gallery_photos/reorder` is submitted with `photo_ids` containing an id that does not belong to any existing `GalleryPhoto`
Then HTTP 422 and no `GalleryPhoto`'s position changes
Covers: R17, AC-23, E6

AT23
Given admin is authenticated and 3 `GalleryPhoto` rows exist
When `PATCH /admin/gallery_photos/reorder` is submitted with an empty array
Then HTTP 422 and no `GalleryPhoto`'s position changes
Covers: R17, AC-24, E7

AT24
Given admin is authenticated
When `GET /admin`
Then the response includes an `href` matching `admin_gallery_photos_path`
Covers: R18, AC-25

AT25
Given `app/views/admin/gallery_photos/` and `Admin::GalleryPhotosController` source
When inspected for hardcoded English string literals
Then none are found
Covers: R19, AC-26

AT26
Given admin is authenticated
When `GET /admin/gallery_photos` is rendered at 375 px viewport width (system spec)
Then no horizontal scroll occurs and the grid renders at `grid-cols-2`
Covers: R20, AC-27

AT27
Given no active admin session
When any `Admin::GalleryPhotosController` action is requested (e.g. `GET /admin/gallery_photos`)
Then the response redirects and no `GalleryPhoto` data changes
Covers: AC-28

AT28
Given `app/assets/images/gallery/*.jpg` contains N files and zero `GalleryPhoto` rows exist
When `rails gallery_photos:backfill` runs
Then exactly N `GalleryPhoto` rows exist, each with an attached blob matching a source filename, positioned in alphabetical order
Covers: R21, AC-29, E8

AT29
Given the backfill task has already run once
When `rails gallery_photos:backfill` runs again
Then `GalleryPhoto.count` is unchanged
Covers: R21, AC-30, E9

AT30
Given the backfill has run for all but one file
When `rails gallery_photos:backfill` runs
Then exactly one new `GalleryPhoto` row is created for the missing file; existing rows are untouched
Covers: R21, AC-31, E9

AT31
Given `db/seeds.rb`, every file under `db/migrate/`, and `.github/workflows/ci.yml`
When inspected for invocations of `gallery_photos:backfill`
Then none are found — the task is never invoked automatically
Covers: R22, AC-32

AT32
Given `config/routes.rb`
When `PATCH /admin/gallery_photos/:id/move_up` (or `.../move_down`) is requested
Then a routing error occurs — no controller action is reached
Covers: R27, AC-33

AT33
Given `config/importmap.rb`
When inspected
Then it contains a `pin "sortablejs"` entry
Covers: R23, AC-34

AT34
Given `app/javascript/controllers/gallery_sort_controller.js` and `app/javascript/controllers/index.js`
When inspected
Then the controller file exists and no manual registration entry was needed (relies on `eagerLoadControllersFrom`)
Covers: R24, AC-35

AT35
Given admin is authenticated and 2 `GalleryPhoto` rows exist
When `GET /admin/gallery_photos`
Then the grid container carries `data-controller="gallery-sort"` and each tile carries `data-gallery-photo-id` matching its `GalleryPhoto#id`
Covers: R13, R24, AC-36

AT36
Given `gallery_sort_controller.js` source
When inspected
Then the `onEnd` handler returns without issuing a `fetch` request when `event.newIndex === event.oldIndex`
Covers: R25, AC-37, E5

AT37
Given `gallery_sort_controller.js` source
When inspected
Then the reorder `fetch()` call sets an `X-CSRF-Token` header sourced from `document.querySelector('meta[name="csrf-token"]').content`
Covers: R26, AC-38

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-14 | `:display` variant confirmed at `resize_to_limit: [1200, 1200], saver: { quality: 80 }` (ADR-005's suggested starting point, not adjusted) | 1200 px is sized for the largest rendered context across both Gallery and the future About slideshow (60vh hero panel on a large viewport). Reusing the exact same numbers for Gallery means one variant definition serves both specs without recalculation, and is generous headroom for Gallery's smaller `aspect-square` grid cells and its click-through "view larger" link. |
| 2026-07-14 | No soft minimum pixel-dimension guard added | ADR-005 left this open as an optional quality nicety. Rejected: (a) every file currently in the repo is a substantial camera original (2.3–7.7 MB), so an accidentally-uploaded thumbnail has not been an observed problem for this single-admin workflow; (b) implementing it requires an extra image-dimension read outside the variant pipeline plus a new error message for a scenario with no evidence it occurs; (c) `object-fit: cover` on the grid already fully protects layout integrity regardless of source resolution (ADR-005 Decision 4) — a low-res image looks softer, it does not break anything; (d) consistent with this codebase's established preference for minimal validation surface over speculative guards (the same reasoning ADR-002 used to reject `acts_as_list` and ADR-005 used to reject the `active_storage_validations` gem). |
| 2026-07-14 | No per-photo caption or alt text; the single generic `t("pages.gallery.photo_alt")` string continues to apply to every photo | ADR-005 explicitly states this spec does not change that behavior, only the storage/CRUD mechanism. Confirmed, not overridden — adding a per-photo field would be new scope beyond what the ADR settled. |
| 2026-07-14 | Shared error-message i18n keys placed at `activerecord.errors.messages.*`, not duplicated per model/attribute | Rails' documented error-message fallback chain resolves this location for any ActiveRecord model/attribute combination. Defining `invalid_content_type`/`file_too_large` once here means SPEC-009's `AboutPageContent#slideshow_image_1/2/3` (reusing the same `ImageAttachmentValidatable` concern) needs zero new i18n keys for these two messages — same single-source-of-truth principle already applied to copy strings (R18 of SPEC-006, R16 of SPEC-007). |
| 2026-07-14 | `#destroy` explicitly calls `photo.image.purge` rather than relying on implicit Active Storage destroy-cascade behavior | Rails' default `has_one_attached` destroy behavior purges the join `ActiveStorage::Attachment` record but does not guarantee synchronous blob/file purge unless configured. An explicit, synchronous purge call removes any ambiguity and guarantees no orphaned files accumulate on the finite mounted local-disk volume — consistent with ADR-005 Decision 5's "no background job required" posture (no `purge_later`/ActiveJob dependency introduced). |
| 2026-07-14 | Admin CRUD combined into a single `index` action — no separate `new` page | Mirrors the combined show+list+form pattern already shipped in `admin/services_pages/show.html.erb`. Keeps the one-photo-at-a-time upload flow to a single screen Doug already understands, with no new navigation step. |
| 2026-07-14 | No "Gallery page published" visibility toggle | No such flag exists today for the Gallery page (unlike Services' `services_page_published` SiteSetting). Out of ADR-005's scope; not invented here — the Gallery page is always accessible, same as before this spec. |
| 2026-07-17 | Reorder request transmits `photo_ids` as a JSON body (`fetch` with `Content-Type: application/json`), not a form-encoded `params[:photo_ids][]` array | A plain JSON body is the simplest payload for a Stimulus-initiated `fetch()` reading DOM order and needing no other form fields; avoids the ambiguity of Rails' bracket-array form-encoding for a JS-constructed request. |
| 2026-07-17 | `#reorder` validates the incoming id array as a single set-equality + uniqueness check (R17) rather than validating each id independently | One query (`GalleryPhoto.pluck(:id)`) and one comparison cover all three failure modes (foreign id, omitted id, duplicate id) without three separate code paths or three separate error messages — consistent with this codebase's preference for minimal validation surface (ADR-005's reasoning for rejecting a dimension-validation gem applies equally here). |
| 2026-07-17 | On reorder failure, the client shows `alert()` then calls `window.location.reload()` rather than programmatically reverting the DOM to its pre-drag order | SortableJS does not expose a built-in "undo the drop" API; hand-rolling a DOM-order revert is meaningfully more code for a failure path expected to be rare (network blip or a stale multi-tab edit). A reload is simple, guarantees the grid matches server truth, and matches this codebase's general preference for the smallest sufficient mechanism over general-purpose machinery. |
| 2026-07-17 | No success-path flash message for a completed reorder | The grid already visually reflects the new order the instant the tile is dropped (optimistic client-side update via SortableJS) — a redirect-and-flash cycle would be redundant for something the admin can already see happened. Failure is the only case that needs an explicit signal, since it's the only case not already visible on screen. |
| 2026-07-17 | `reorder` is a `collection` route, not a `member` route | Unlike `move_up`/`move_down` (which each targeted one `GalleryPhoto`), `reorder` repositions the entire set in one request — it has no single-record target, so it belongs on the resource's collection, not a member. |

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. Layout, nav, Tailwind, and asset pipeline are in place.
- SPEC-003 (i18n String Extraction) — done. All new admin UI strings follow the `t()` / `en.yml` pattern.
- SPEC-004 (Admin Backend) — done. `Admin::BaseController`, auth session management, and admin layout are live.
- ADR-002 (Services Page Icon Rendering and Section Ordering) — `ServiceSection`'s gap-tolerant swap / Move Up-Down pattern remains the reference precedent for the *rest* of this codebase's admin ordering UI (unaffected by this spec); it is **no longer** the mechanism `GalleryPhoto` uses, per ADR-005's 2026-07-17 addendum, which replaces R17's original swap-based logic with full-list position reassignment on drag-and-drop.
- ADR-005 (Photo Upload Data Model and Active Storage Strategy), including its 2026-07-17 addendum — governs this spec's data model, validation, variant, backfill, and (as of the addendum) drag-and-drop reordering decisions; not re-derived here.
- New gem: `ruby-vips` (added by this spec, R2).
- New third-party JS dependency: `sortablejs`, pinned via `bin/importmap pin sortablejs` (R23) — the first non-Hotwire JavaScript library in this codebase.
- **Devops flag:** `bin/importmap pin sortablejs` vendors the library file locally (importmap-rails' default `--download` behavior) rather than referencing a CDN URL at runtime, so no network access is required in production or CI once the vendored file is committed — confirm this file is committed as part of this revision's implementation, not fetched at build/deploy time.
- **Devops follow-up, not implemented by this spec:** CI runners for the `test` and `system-test` jobs in `.github/workflows/ci.yml` must have `libvips` available before any test exercising `.variant(...)` (this spec's request/system specs) can pass in CI. The production Docker image already has it; local dev machines and GitHub-hosted CI runners are unconfirmed. Flagged per ADR-005 Risks — tracked here as an explicit dependency for the devops agent, not addressed by this spec.
- No dependency on SPEC-007/PR #38 or `AboutPageContent` — this spec is independently implementable per ADR-005 Implementation Note 12.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Prerequisite: run `bin/rails active_storage:install`, commit the generated migration. Add `gem "ruby-vips"` to `Gemfile`, `bundle install`. | AC-6 (partial: AS tables), AC-8 | 1 |
| T2 | Migration: create `gallery_photos` table (R3). Create `GalleryPhoto` model with `has_one_attached :image` (R4), `image_must_be_attached` presence validation (R5), `app/models/concerns/image_attachment_validatable.rb` concern (R6–R9), and `#display_variant` (R10). Add `activerecord.errors.messages.invalid_content_type`/`file_too_large` i18n keys. Add FactoryBot factory with a fixture-attached valid image. | AC-6 (gallery_photos table), AC-7, AC-9, AC-10, AC-11, AC-12 | 3 |
| T3 | Public page update: `PagesController#gallery` loads `GalleryPhoto.order(:position)`, removes `Dir.glob` (R11); update `app/views/pages/gallery.html.erb` to render `display_variant` for both `<img src>` and the wrapping `<a href>` (R12). | AC-1, AC-2, AC-3, AC-4, AC-5 | 2 |
| T4 | Admin controller and routes: replace the `member { patch :move_up; patch :move_down }` block in `config/routes.rb` with `collection { patch :reorder }`; remove `#move_up`/`#move_down` and their `before_action` entry from `Admin::GalleryPhotosController`; add `#reorder` implementing R17's set-equality/uniqueness validation, transactional position reassignment, and `head :ok`/`head :unprocessable_entity` responses; actions remain alphabetical (`create, destroy, index, reorder`) per `.claude/standards/practices/architecture.md §1.8`; remove `move_up`/`move_down`/`flash.moved` i18n keys, add `drag_hint`/`flash.reorder_failed` (R18, R19, R27); dashboard link unchanged. | AC-16 through AC-25, AC-28, AC-33 | 3 |
| T5 | Admin view: rewrite `app/views/admin/gallery_photos/index.html.erb` from the stacked `<ul>` to a `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2` container (R13); each tile gets `data-gallery-photo-id` and an overlaid Delete control sized per R20's touch-target rule; the container gets `data-controller="gallery-sort"`; add the permanently visible `drag_hint` text; empty-state message and mobile-first (`w-full`) upload form carry over unchanged. | AC-13, AC-14, AC-15, AC-26, AC-27, AC-36 | 3 |
| T6 | Backfill: create `lib/tasks/gallery_photos.rake` with the `gallery_photos:backfill` task exactly per R21; document the required manual deploy step (R22) in the deploy runbook/README. Add spec fixture files (`spec/fixtures/files/gallery_photo.jpg` valid, `gallery_photo.svg` invalid, and a size-appropriate oversized fixture or a stubbed `byte_size` approach) for use across T7/T8. | AC-29, AC-30, AC-31, AC-32 | 2 |
| T7 | Tests: `GalleryPhoto` model spec (presence, content-type, size validations; `display_variant`); request spec for `PagesController#gallery` (ordering, variant rendering, alt text, zero-photos case). All AAA pattern, inline variables, no `let`/`let!`. | AC-1 through AC-12 | 3 |
| T8 | Tests: request spec for `Admin::GalleryPhotosController` (auth guard on all actions incl. `#reorder`; index list, grid structure, and empty state; create happy path and position assignment; create validation failures for missing/wrong-type/oversized; destroy purges blob; `#reorder` success permutation and its rejection paths — foreign id, omitted id, duplicate id, empty list — per R17/E6/E7); system spec for admin grid at 375 px (AC-27); routing spec confirming `move_up`/`move_down` paths no longer resolve (AC-33); static-inspection checks for the `sortablejs` importmap pin (AC-34), the `gallery_sort_controller.js` file's existence, same-position guard, and CSRF header (AC-35, AC-37, AC-38), and the grid's `data-controller`/`data-gallery-photo-id` attributes (AC-36); rake task spec for `gallery_photos:backfill` (fresh run, idempotent re-run, partial re-run); static-inspection check confirming no automatic invocation of the backfill task (AC-32). Note: actual pointer-based drag interaction is not simulated in this suite — there is no JS test runner in this stack (no Node/npm per CLAUDE.md), and headless system-spec simulation of pointer-event-based drag libraries is unreliable; the drag *feel* and same-position guard (E5) are covered via the source-inspection checks above plus manual QA on a real device. | AC-13 through AC-38 | 4 |
| T9 | Client-side reordering: run `bin/importmap pin sortablejs`, commit the resulting `config/importmap.rb` pin and vendored file (R23); create `app/javascript/controllers/gallery_sort_controller.js` — `connect()` initializes `Sortable` with `animation: 150`, `ghostClass: "opacity-50"`, `delay: 150`, `delayOnTouchOnly: true`, `filter: "[data-turbo-method='delete']"`, `preventOnFilter: false` (touch-scroll/accidental-drag guards, R24), and an `onEnd` handler implementing the same-position no-op guard (R25), the `photo_ids` fetch with `X-CSRF-Token` (R26), and the alert-then-reload failure path (Interfaces → Client-Side Reordering). No manual Stimulus registration needed (R24). Endpoint-side correctness for the requests this controller sends (AC-22–AC-24) is implemented in T4 and tested there; this task's own ACs are the client artifact's existence and wiring. | AC-34, AC-35, AC-37, AC-38 | 3 |

Total estimated points: 24 (all tasks ≤ 4 points; no split review required under the ≥ 5-point guardrail)

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-07-14 | Initial draft | All | Translates ADR-005 (Decisions 2–6, Implementation Notes 1–7, 11–12) into implementation-ready spec format. Resolves the ADR's "Handoff to Spec Agent" open items: confirmed `:display` variant at 1200×1200 quality 80; decided against a soft minimum-dimension guard; wrote full `admin.gallery_photos.*` i18n copy; confirmed no per-photo alt text change; wrote full acceptance criteria including content-type/size rejection request specs and a 375 px mobile-first system spec for the admin list. |
| 2026-07-17 | Reversed the Gallery admin reordering mechanism from Move Up/Move Down buttons to drag-and-drop (SortableJS + a new `gallery_sort_controller.js` Stimulus controller), per ADR-005's 2026-07-17 addendum. Flipped the drag-and-drop Non-Goal to a Move-Up/Down-fallback Non-Goal; replaced the `gap-tolerant swap`/`stacked-card list pattern` Definitions with `responsive photo grid`/`SortableJS`/`gallery_sort_controller`/`reorder request`; replaced the `move_up`/`move_down` member routes and i18n keys with a `PATCH /admin/gallery_photos/reorder` collection route and `drag_hint`/`flash.reorder_failed` keys; added the Interfaces → Client-Side Reordering subsection specifying the `photo_ids` JSON request contract, CSRF header handling, and success/failure response codes; rewrote R13 (grid + drag admin view) and R17 (reorder validation/transaction/response contract) and R20 (grid-based mobile-first rules); added R23–R27 (SortableJS pin, Stimulus controller init, same-position no-op, CSRF header, removal of move_up/move_down); replaced E5/E6 with drag-specific edge cases and renumbered the backfill edge cases to E8/E9; rewrote AC-13, AC-22, AC-23, AC-24, AC-27 and added AC-33–AC-38 (AC-38 and its AT37 close a self-test gap: R26's CSRF-header requirement had no dedicated acceptance test); rewrote AT12, AT21, AT22, AT23, AT26 and added AT32–AT37; rewrote Task Breakdown T4/T5/T8 and added T9 for the new client-side dependency (total estimate 21→24; T9's AC list was corrected to the client-artifact ACs it actually produces — AC-22–AC-24 are endpoint-correctness ACs owned by T4, not T9); updated Dependencies to note ADR-002's swap pattern is no longer reused by `GalleryPhoto` and to flag the new `sortablejs` third-party JS dependency and its vendoring. Status remains `ready`; this revision targets PR #40 before merge — the underlying feature was already implemented, reviewed, and QA-passed with Move Up/Move Down, but not yet merged to `main`. | Non Goals, Definitions, Interfaces, R13, R17, R20, R23, R24, R25, R26, R27, E5, E6, E7, E8, E9, AC-13, AC-22, AC-23, AC-24, AC-27, AC-33, AC-34, AC-35, AC-36, AC-37, AC-38, AT12, AT21, AT22, AT23, AT26, AT32, AT33, AT34, AT35, AT36, AT37, T4, T5, T8, T9, Dependencies | Product/UX decision after using the shipped Move Up/Down implementation on PR #40 — reordering a photo collection via repeated taps was judged clunky by the product owner (Doug); ADR-005's 2026-07-17 addendum authorizes SortableJS-based drag-and-drop as the replacement mechanism. |
| 2026-07-21 | Reviewer finding on the first drag-and-drop implementation: `Sortable.create` was missing touch-scroll-conflict guards, meaning a plain vertical swipe on the grid would have been hijacked into a drag on touch devices - the exact "scroll-vs-drag conflict" ADR-005's addendum cited as the reason for choosing SortableJS over native HTML5 drag-and-drop in the first place, left unaddressed by an incomplete options object. Added `delay: 150`, `delayOnTouchOnly: true` (press-and-hold required to start a drag on touch; mouse unaffected), and `filter: "[data-turbo-method='delete']"` / `preventOnFilter: false` (the per-tile Delete control cannot initiate a drag). Updated R24 and the Interfaces Client-Side Reordering section's `Sortable.create` options string and T9 to match. No AC/AT numbering changed - this refines R24's existing options-string requirement rather than adding new observable behavior; the existing static-inspection test for the controller's structure/wiring was not asserting the literal options string, so no test needed updating. Fixed before the product owner's first manual phone test, per reviewer recommendation. | R24, Interfaces (Client-Side Reordering), T9 | Reviewer finding - touch-drag would have conflicted with scrolling and with tapping Delete |

---

## Open Questions

None. All items from ADR-005's "Handoff to Spec Agent (SPEC-008)" section are resolved above (see Implementation Decisions).
