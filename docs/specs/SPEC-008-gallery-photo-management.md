# Spec: Gallery Photo Management — Admin-Managed Photo Upload, Delete, and Reorder

**ID:** SPEC-008
**Status:** ready
**Priority:** medium
**Created:** 2026-07-14
**Author:** spec-agent

---

## Goal

Allow Doug to upload, delete, and reorder Gallery page photos through the admin backend without developer involvement, replacing the current `Dir.glob`-based filesystem listing with a genuine, admin-managed, position-ordered `GalleryPhoto` collection. Visitors continue to get a fast-loading page: every photo is served through a single resized `:display` variant, never as a multi-megabyte camera original. Implements ADR-005 Decision 2 (data model), Decision 3 (backfill), Decision 4 (validation), Decision 5 (variants), and Decision 6 (admin UI). Per ADR-005 Implementation Note 12, this spec has no dependency on SPEC-007/PR #38 and can be implemented immediately on a branch off current `main`.

---

## Non Goals

- Multi-file batch upload — one photo per submission, matching the existing camera-roll, one-field-per-submit shape of every other admin form in this codebase (ADR-005 Decision 6).
- Drag-and-drop reordering — Move Up/Move Down buttons only, copying `Admin::ServiceSectionsController`'s exact pattern (ADR-005 Decision 6, ADR-002).
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
| stacked-card list pattern | The admin list UI shape already shipped for `ServiceSection` (`app/views/admin/services_pages/show.html.erb`): one card per record, thumbnail/heading at top, action buttons below in a wrapping `flex flex-wrap gap-2` row with `py-2`/`py-3` touch targets — not a table, not drag-and-drop. |
| gap-tolerant swap | The `move_up`/`move_down` reordering mechanism: find the nearest neighbour by position value (not `position ± 1`), swap the two positions inside a transaction. Identical to `Admin::ServiceSectionsController`'s existing implementation (ADR-002). |

---

## Interfaces

### Public Frontend

- `GET /gallery` — `PagesController#gallery` loads `@photos = GalleryPhoto.order(:position)`. The `Dir.glob` call is removed entirely. The view renders each photo's display variant.

### Admin

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/gallery_photos | `Admin::GalleryPhotosController#index` — lists all photos as stacked cards, includes the upload form |
| POST | /admin/gallery_photos | `#create` — uploads and attaches a new photo |
| DELETE | /admin/gallery_photos/:id | `#destroy` — purges the attached blob and deletes the photo |
| PATCH | /admin/gallery_photos/:id/move_up | `#move_up` — swaps position with the nearest lower-position neighbour |
| PATCH | /admin/gallery_photos/:id/move_down | `#move_down` — swaps position with the nearest higher-position neighbour |

Route declaration (added to the existing `namespace :admin` block):

```ruby
resources :gallery_photos, only: [ :index, :create, :destroy ] do
  member do
    patch :move_up
    patch :move_down
  end
end
```

Named routes generated: `admin_gallery_photos_path` (index GET / create POST), `admin_gallery_photo_path(photo)` (destroy DELETE), `move_up_admin_gallery_photo_path(photo)`, `move_down_admin_gallery_photo_path(photo)`.

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
| `move_up` | Move Up button label |
| `move_down` | Move Down button label |
| `delete` | Delete button label |
| `confirm_delete` | Turbo confirmation dialog text before delete executes |
| `empty_state` | Message shown when zero photos exist |
| `flash.uploaded` | Success flash after upload |
| `flash.deleted` | Success flash after delete |
| `flash.moved` | Success flash after a reorder |

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

R13: `GET /admin/gallery_photos` (`#index`) lists `GalleryPhoto.order(:position)` as stacked cards — thumbnail (via `display_variant`) plus Move Up/Move Down/Delete buttons in a wrapping `flex flex-wrap gap-2` row with `py-2`/`py-3` touch targets, mirroring `app/views/admin/services_pages/show.html.erb` — plus a single `f.file_field :image` upload form. When zero photos exist, an empty-state message (`t("admin.gallery_photos.empty_state")`) is shown instead of an empty list.

R14: `POST /admin/gallery_photos` (`#create`) with a valid image: builds `GalleryPhoto.new(gallery_photo_params)`, sets `position: (GalleryPhoto.maximum(:position) || -1) + 1`, saves, then calls `photo.display_variant.processed` synchronously (so the first public visitor after an upload doesn't pay processing latency), and redirects to `admin_gallery_photos_path` with `flash[:notice] = t("admin.gallery_photos.flash.uploaded")`.

R15: `POST /admin/gallery_photos` with an invalid image (missing, wrong content-type, or oversized) re-renders `:index` at HTTP 422 — with `@photos` reloaded and `@gallery_photo` holding the validation errors — and persists no `GalleryPhoto` row.

R16: `DELETE /admin/gallery_photos/:id` (`#destroy`) calls `photo.image.purge` synchronously (explicit, not relying on implicit destroy-cascade behavior — see Implementation Decisions) before destroying the `GalleryPhoto` record, then redirects to `admin_gallery_photos_path` with `flash[:notice] = t("admin.gallery_photos.flash.deleted")`.

R17: `#move_up`/`#move_down` copy `Admin::ServiceSectionsController#move_up`/`#move_down`'s exact gap-tolerant nearest-neighbour swap pattern (ADR-002), substituting `GalleryPhoto` for `ServiceSection`, wrapped in `ActiveRecord::Base.transaction`. If no neighbour exists (already first/last), the action no-ops but still redirects normally with `flash[:notice] = t("admin.gallery_photos.flash.moved")`.

R18: The admin dashboard view (`GET /admin`) must include a link to `admin_gallery_photos_path` using `t("admin.dashboard.gallery_link")`.

R19: All admin-facing UI strings in `app/views/admin/gallery_photos/` and `Admin::GalleryPhotosController` are rendered via `t()` from `config/locales/en.yml` under `admin.gallery_photos`. No hardcoded English strings.

R20: The admin gallery photo list and upload form follow the mobile-first rules from CLAUDE.md: no horizontal scroll at any viewport width, including 375 px; action buttons wrap via `flex flex-wrap gap-2`; list action buttons carry at minimum `py-2`; the upload submit button carries at minimum `py-3`; the file field's wrapping container carries `w-full`.

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

---

## Edge Cases

E1: A valid JPEG under 15 MB is uploaded. The record is valid and saves successfully.

E2: An uploaded file has `content_type` `image/svg+xml` (or any type outside the allowlist). Validation rejects it (R7); HTTP 422 on `#create`.

E3: An uploaded file's `blob.byte_size` exceeds 15 MB. Validation rejects it (R8); HTTP 422 on `#create`.

E4: `#create` is submitted with no file selected. `image_must_be_attached` (R5) rejects it; HTTP 422.

E5: `#move_down` is called on the photo with the highest `position` value. No neighbour exists with a higher position; the action no-ops (positions unchanged) and still redirects normally.

E6: `#move_up` is called on the photo with the lowest `position` value. No neighbour exists with a lower position; the action no-ops and still redirects normally.

E7: The backfill task runs against a fresh database where `app/assets/images/gallery/` contains N files and zero `GalleryPhoto` rows exist. Exactly N rows are created, one per file, positioned in the same alphabetical order the file glob already produced.

E8: The backfill task runs a second time (or runs when only some files have already been backfilled — e.g., a file added to the directory since the last run). Already-backfilled filenames are skipped; only genuinely new files produce new rows; `GalleryPhoto.count` does not grow for files already present.

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

AC-13: Given admin is authenticated and 2 `GalleryPhoto` rows exist, when `GET /admin/gallery_photos`, then HTTP 200 and the response includes 2 thumbnails, each with Move Up, Move Down, and Delete controls.

AC-14: Given admin is authenticated, when `GET /admin/gallery_photos`, then the response includes a file input with `name="gallery_photo[image]"` and a submit button.

AC-15: Given admin is authenticated and zero `GalleryPhoto` rows exist, when `GET /admin/gallery_photos`, then HTTP 200, no error, and the response includes `t("admin.gallery_photos.empty_state")`.

AC-16: Given admin is authenticated and zero prior `GalleryPhoto` rows exist, when `POST /admin/gallery_photos` with a valid JPEG under 15 MB, then a `GalleryPhoto` is created with `position: 0`, the response redirects to `admin_gallery_photos_path`, and `flash[:notice]` is present.

AC-17: Given admin is authenticated and one `GalleryPhoto` exists at `position: 0`, when `POST /admin/gallery_photos` with a second valid image, then the new row's `position` equals 1.

AC-18: Given admin is authenticated, when `POST /admin/gallery_photos` with an `image/svg+xml` file, then HTTP 422, `GalleryPhoto.count` is unchanged, and the response body includes a content-type validation error.

AC-19: Given admin is authenticated, when `POST /admin/gallery_photos` with a file exceeding 15 MB, then HTTP 422, `GalleryPhoto.count` is unchanged, and the response body includes a file-size validation error.

AC-20: Given admin is authenticated, when `POST /admin/gallery_photos` with no file selected, then HTTP 422, `GalleryPhoto.count` is unchanged, and the response body includes a presence validation error.

AC-21: Given admin is authenticated and a `GalleryPhoto` with an attached image exists, when `DELETE /admin/gallery_photos/:id`, then the row no longer exists, its blob is purged, the response redirects to `admin_gallery_photos_path`, and `flash[:notice]` is present.

AC-22: Given admin is authenticated and 3 `GalleryPhoto` rows exist at positions 0, 1, 2, when `PATCH .../move_up` on the row at position 1, then it moves to position 0 and the former position-0 row moves to position 1.

AC-23: Given admin is authenticated and 3 `GalleryPhoto` rows exist, when `PATCH .../move_down` on the row at the highest position, then no position changes and the response still redirects normally with `flash[:notice]`.

AC-24: Given admin is authenticated, when `PATCH .../move_up` on the row at the lowest position, then no position changes and the response redirects normally.

AC-25: `GET /admin` returns HTTP 200 and the response body includes an `href` matching `admin_gallery_photos_path`.

AC-26: No hardcoded English strings appear in `app/views/admin/gallery_photos/` or `Admin::GalleryPhotosController`. All user-facing strings use `t()`.

AC-27: The admin gallery photo list renders without horizontal scroll at 375 px viewport width; action buttons wrap via `flex flex-wrap`; list action buttons carry at least `py-2`; the upload submit button carries at least `py-3`.

AC-28: Given a request is NOT authenticated, when any `Admin::GalleryPhotosController` action is requested, then the response redirects to the login page and no `GalleryPhoto` data changes.

### Backfill

AC-29: Given `app/assets/images/gallery/*.jpg` contains N files and zero `GalleryPhoto` rows exist, when `rails gallery_photos:backfill` runs, then exactly N `GalleryPhoto` rows are created, each with an attached blob whose filename matches its source file, positioned in the same alphabetical order `Dir.glob(...).sort` already produced.

AC-30: Given the backfill task has already run once (all N files backfilled), when `rails gallery_photos:backfill` runs again, then `GalleryPhoto.count` is unchanged (idempotent — no duplicate rows).

AC-31: Given the backfill has already run for all but one file, when `rails gallery_photos:backfill` runs, then exactly one new `GalleryPhoto` row is created (for the missing file); existing rows are untouched.

AC-32: The backfill task is not referenced by `db/seeds.rb`, any file under `db/migrate/`, or `.github/workflows/ci.yml` — it is never invoked automatically.

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
Then HTTP 200 and the response includes 2 sets of Move Up/Move Down/Delete controls
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
Given admin is authenticated and 3 `GalleryPhoto` rows exist at positions 0, 1, 2
When `PATCH move_up` on the row at position 1
Then it moves to position 0 and the former position-0 row moves to position 1
Covers: R17, AC-22

AT22
Given admin is authenticated and 3 `GalleryPhoto` rows exist
When `PATCH move_down` on the row with the highest position
Then no position changes and the response redirects normally with `flash[:notice]`
Covers: R17, AC-23, E5

AT23
Given admin is authenticated and 3 `GalleryPhoto` rows exist
When `PATCH move_up` on the row with the lowest position
Then no position changes and the response redirects normally
Covers: R17, AC-24, E6

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
Then no horizontal scroll occurs and action buttons wrap cleanly
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
Covers: R21, AC-29, E7

AT29
Given the backfill task has already run once
When `rails gallery_photos:backfill` runs again
Then `GalleryPhoto.count` is unchanged
Covers: R21, AC-30, E8

AT30
Given the backfill has run for all but one file
When `rails gallery_photos:backfill` runs
Then exactly one new `GalleryPhoto` row is created for the missing file; existing rows are untouched
Covers: R21, AC-31, E8

AT31
Given `db/seeds.rb`, every file under `db/migrate/`, and `.github/workflows/ci.yml`
When inspected for invocations of `gallery_photos:backfill`
Then none are found — the task is never invoked automatically
Covers: R22, AC-32

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

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. Layout, nav, Tailwind, and asset pipeline are in place.
- SPEC-003 (i18n String Extraction) — done. All new admin UI strings follow the `t()` / `en.yml` pattern.
- SPEC-004 (Admin Backend) — done. `Admin::BaseController`, auth session management, and admin layout are live.
- ADR-002 (Services Page Icon Rendering and Section Ordering) — the gap-tolerant swap reordering mechanism (R17) is copied verbatim from `Admin::ServiceSectionsController`, not re-derived.
- ADR-005 (Photo Upload Data Model and Active Storage Strategy) — governs this spec's data model, validation, variant, and backfill decisions; not re-derived here.
- New gem: `ruby-vips` (added by this spec, R2).
- **Devops follow-up, not implemented by this spec:** CI runners for the `test` and `system-test` jobs in `.github/workflows/ci.yml` must have `libvips` available before any test exercising `.variant(...)` (this spec's request/system specs) can pass in CI. The production Docker image already has it; local dev machines and GitHub-hosted CI runners are unconfirmed. Flagged per ADR-005 Risks — tracked here as an explicit dependency for the devops agent, not addressed by this spec.
- No dependency on SPEC-007/PR #38 or `AboutPageContent` — this spec is independently implementable per ADR-005 Implementation Note 12.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Prerequisite: run `bin/rails active_storage:install`, commit the generated migration. Add `gem "ruby-vips"` to `Gemfile`, `bundle install`. | AC-6 (partial: AS tables), AC-8 | 1 |
| T2 | Migration: create `gallery_photos` table (R3). Create `GalleryPhoto` model with `has_one_attached :image` (R4), `image_must_be_attached` presence validation (R5), `app/models/concerns/image_attachment_validatable.rb` concern (R6–R9), and `#display_variant` (R10). Add `activerecord.errors.messages.invalid_content_type`/`file_too_large` i18n keys. Add FactoryBot factory with a fixture-attached valid image. | AC-6 (gallery_photos table), AC-7, AC-9, AC-10, AC-11, AC-12 | 3 |
| T3 | Public page update: `PagesController#gallery` loads `GalleryPhoto.order(:position)`, removes `Dir.glob` (R11); update `app/views/pages/gallery.html.erb` to render `display_variant` for both `<img src>` and the wrapping `<a href>` (R12). | AC-1, AC-2, AC-3, AC-4, AC-5 | 2 |
| T4 | Admin controller and routes: add `resources :gallery_photos, only: [:index, :create, :destroy] do member { patch :move_up; patch :move_down } end` to `config/routes.rb`; create `Admin::GalleryPhotosController` with actions in alphabetical order (`create, destroy, index, move_down, move_up`) per `.claude/standards/practices/architecture.md §1.8` (R13–R17); add all `admin.gallery_photos.*` and `admin.dashboard.gallery_link` i18n keys (R18, R19); update dashboard view link. | AC-13, AC-14, AC-15, AC-16, AC-17, AC-18, AC-19, AC-20, AC-21, AC-22, AC-23, AC-24, AC-25, AC-28 | 3 |
| T5 | Admin view: create `app/views/admin/gallery_photos/index.html.erb` — stacked-card list (thumbnail + Move Up/Move Down/Delete, `flex flex-wrap gap-2`, `py-2`/`py-3`) mirroring `admin/services_pages/show.html.erb`, empty-state message, and a mobile-first (`w-full`) single-file upload form with a permanently visible `image_hint` (R13, R20). | AC-13, AC-14, AC-15, AC-26, AC-27 | 3 |
| T6 | Backfill: create `lib/tasks/gallery_photos.rake` with the `gallery_photos:backfill` task exactly per R21; document the required manual deploy step (R22) in the deploy runbook/README. Add spec fixture files (`spec/fixtures/files/gallery_photo.jpg` valid, `gallery_photo.svg` invalid, and a size-appropriate oversized fixture or a stubbed `byte_size` approach) for use across T7/T8. | AC-29, AC-30, AC-31, AC-32 | 2 |
| T7 | Tests: `GalleryPhoto` model spec (presence, content-type, size validations; `display_variant`); request spec for `PagesController#gallery` (ordering, variant rendering, alt text, zero-photos case). All AAA pattern, inline variables, no `let`/`let!`. | AC-1 through AC-12 | 3 |
| T8 | Tests: request spec for `Admin::GalleryPhotosController` (auth guard on all actions; index list and empty state; create happy path and position assignment; create validation failures for missing/wrong-type/oversized; destroy purges blob; move_up/move_down including no-op boundary cases); system spec for admin list at 375 px (AC-27); rake task spec for `gallery_photos:backfill` (fresh run, idempotent re-run, partial re-run); static-inspection check confirming no automatic invocation of the backfill task (AC-32). | AC-13 through AC-32 | 4 |

Total estimated points: 21 (all tasks ≤ 4 points; no split review required under the ≥ 5-point guardrail)

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-07-14 | Initial draft | All | Translates ADR-005 (Decisions 2–6, Implementation Notes 1–7, 11–12) into implementation-ready spec format. Resolves the ADR's "Handoff to Spec Agent" open items: confirmed `:display` variant at 1200×1200 quality 80; decided against a soft minimum-dimension guard; wrote full `admin.gallery_photos.*` i18n copy; confirmed no per-photo alt text change; wrote full acceptance criteria including content-type/size rejection request specs and a 375 px mobile-first system spec for the admin list. |

---

## Open Questions

None. All items from ADR-005's "Handoff to Spec Agent (SPEC-008)" section are resolved above (see Implementation Decisions).
