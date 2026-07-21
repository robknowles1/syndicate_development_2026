# ADR-005: Photo Upload Data Model and Active Storage Strategy

**Status:** Accepted
**Date:** 2026-07-14
**Deciders:** Architect agent


## Context

Two upcoming pieces of admin functionality need Doug to be able to replace or manage photos without developer involvement, and they are structurally different problems:

1. **About page slideshow (fixed 3 slots).** `app/views/pages/about.html.erb` currently hardcodes 3 `image_tag` calls pointing at static files in `app/assets/images/gallery/`. SPEC-007 (open PR #38, branch `feature/spec-007-about-page-editable`, not yet merged to `main`) already made each slide's *alt text* editable via `AboutPageContent#slideshow_alt_1/2/3` — a singleton model following the pattern established in ADR-004 (dedicated model, `published` boolean column co-located with content, i18n as the single canonical source of "original" copy). R20 of SPEC-007 establishes a hard 1:1 mapping between the 3 `<img>` tags in document order and `slideshow_alt_1/2/3`. This ADR needs to make the 3 slide *images* themselves admin-replaceable — "replace slot 1/2/3," not an open collection.

2. **Gallery page (open-ended).** `PagesController#gallery` (`app/controllers/pages_controller.rb:12-16`) does `Dir.glob(Rails.root.join("app/assets/images/gallery/*.jpg"))` and renders every matched file in a responsive grid (`app/views/pages/gallery.html.erb`). This needs to become genuine admin CRUD: upload, delete, reorder, with no fixed count.

**Settled infrastructure (not decided here):** Active Storage, local disk service (`config/storage.yml` `local:` service, already pointed at `Rails.root.join("storage")`), the Kamal-mounted persistent volume at `/rails/storage` (`config/deploy.yml`), and the `image_processing` gem (`~> 2.0`, already in `Gemfile`). No S3/GCS. This ADR does not revisit those choices.

**Two things confirmed during investigation that are not yet true, despite being "available":**
- `db/schema.rb` does **not** yet contain `active_storage_blobs` / `active_storage_attachments` / `active_storage_variant_records`. `bin/rails active_storage:install` has never been run. This is a blocking first implementation step for whichever of the two specs lands first.
- Neither `mini_magick` nor `ruby-vips` appears in `Gemfile.lock`, so `image_processing` currently has no processing backend wired up, even though `config.load_defaults 8.1` (`config/application.rb:12`) already defaults `active_storage.variant_processor` to `:vips`, and the production `Dockerfile` already installs the `libvips` system package (`apt-get install ... libvips ...`). Only the Ruby binding gem is missing.

**Existing precedents this ADR builds on:**
- ADR-004: singleton content model, `published` boolean column co-located with the content it gates, i18n as the one canonical "original" source, restore-defaults action that overwrites the record from i18n without touching `published`.
- ADR-002 Decision 2: integer `position` column + gap-tolerant swap queries for reordering, explicitly rejecting `acts_as_list` as unnecessary for this scale. Same ADR's admin list UI (`app/views/admin/services_pages/show.html.erb`) uses stacked cards with wrapping action-button rows (`flex flex-wrap gap-2`, `py-2`/`py-3` touch targets) — not a table, not drag-and-drop.
- ADR-001: dedicated relational table over key-value storage for variable-length, individually-addressable, orderable collections.


## Decision

### 1. About slideshow: three named `has_one_attached` slots on `AboutPageContent`

```ruby
class AboutPageContent < ApplicationRecord
  has_one_attached :slideshow_image_1
  has_one_attached :slideshow_image_2
  has_one_attached :slideshow_image_3
end
```

No new table and no new migration beyond the one-time `active_storage:install` migration — Active Storage attachments live in the polymorphic `active_storage_attachments` table, not as columns on `about_page_contents`.

**Rendering / fallback rule (extends R20):** each slot is resolved independently, mirroring exactly how each text field already falls back independently:

```ruby
content&.slideshow_image_1&.attached? ? content.slideshow_image_1.variant(:display) : "gallery/m45a2920.jpg"
```

**Publish gating reuses the existing `published` column — no second flag.** A slot renders the uploaded image only when `AboutPageContent.first&.published?` is true **and** that specific slot has an attachment. Otherwise it renders the bundled static file that already ships in `app/assets/images/gallery/` today. Those 3 static files are the permanent, canonical fallback — the direct visual equivalent of `pages.about.slideshow_alt_1` in `en.yml` — and are **never deleted and never copied into Active Storage.**

**Consequence: no backfill is required for the About slot images.** Until Doug uploads a replacement, `slideshow_image_N.attached?` is false and the page renders exactly what it renders today. This is a deliberate application of R18's "one canonical location for the original" principle to images: the canonical original is the asset-pipeline file, not a database row.

**Undo mechanism:** extend the existing `restore_defaults` action (SPEC-007 R17-R19 pattern) to also purge all 3 slideshow attachments in the same request, in addition to resetting the 10 text fields from i18n. This gives Doug a single, already-understood "put it back the way it was" button instead of requiring 3 new per-slot reset affordances. `published` is still untouched by this action, per the existing rule.

**Replace mechanics:** add 3 file inputs (`slideshow_image_1`, `slideshow_image_2`, `slideshow_image_3`) to the existing About content edit form, permitted in the existing `about_page_content_params` alongside the 10 text fields. No new controller, no new route — the existing `PATCH /admin/about_page_content` action handles it, since `has_one_attached=` on a model attribute already replaces (and schedules the old blob for purge on) reattachment.

### 2. Gallery: dedicated `GalleryPhoto` model, open-ended, position-ordered

```ruby
create_table :gallery_photos do |t|
  t.integer :position, null: false, default: 0
  t.timestamps
end
```

```ruby
class GalleryPhoto < ApplicationRecord
  has_one_attached :image
  validate :image_must_be_attached
end
```

Public page: `PagesController#gallery` becomes `@photos = GalleryPhoto.order(:position)`, view renders `photo.image.variant(:display)`. `Dir.glob` is removed entirely.

Reordering: identical mechanism to `ServiceSection` (ADR-002 Decision 2) — `move_up` / `move_down` member routes, gap-tolerant nearest-neighbour queries, position swap inside `ActiveRecord::Base.transaction`, new records get `(GalleryPhoto.maximum(:position) || -1) + 1`. No `acts_as_list`, no drag-and-drop, no new Stimulus controller.

Admin UI: same stacked-card list pattern as `admin/services_pages/show.html.erb` — thumbnail + Move Up / Move Down / Delete as wrapping `flex flex-wrap gap-2` buttons with `py-2`/`py-3` touch targets. Upload is a single `f.file_field :image` per submission (one photo at a time), not a multi-file batch uploader.

### 3. Migration path for existing files

**About (3 slots): no backfill needed** — see Decision 1. The static files stay where they are as the permanent fallback.

**Gallery: backfill is required and is a blocking deploy step, not a schema migration.** Once this ships, `PagesController#gallery` no longer reads the filesystem — every photo currently visible on the live site must become a `GalleryPhoto` row with an attached blob, or the gallery goes blank the moment the code deploys. Implement as an idempotent rake task (`lib/tasks/gallery_photos.rake`, task `gallery_photos:backfill`), run once manually as part of this feature's deployment — analogous to how `db:seed` already sits outside the migration path for singleton content rows. It must **not** live inside a `db/migrate` file: attaching blobs is a data operation with external side effects (real file I/O against the mounted volume) and no clean `down` semantics, which does not belong in schema migrations.

The task replicates current behavior losslessly: one `GalleryPhoto` per file currently matched by `Dir.glob("app/assets/images/gallery/*.jpg")`, position assigned in the same sort order the current glob already uses (`.sort`, i.e. alphabetical by filename), `image.attach(io: File.open(path), filename: File.basename(path))`. It must include every file the site shows today — including the 3 pre-existing `* copy.jpg` duplicates already live on production — because the backfill's job is "make the database match what's currently live," not "curate the collection." Deleting unwanted duplicates becomes Doug's first use of the new delete button, not a decision baked into a script. Idempotency: skip filenames that already have a matching `GalleryPhoto` (match on the attached blob's `filename`), so the task is safe to re-run.

### 4. Validation

**Content type allowlist:** `image/jpeg`, `image/png`, `image/webp` — deliberately excluding `image/svg+xml` (a known stored-XSS vector when served inline; SVG can embed `<script>`). Checked against `blob.content_type`, which Active Storage populates via `Marcel::MimeType.for` — content sniffing based on the file's magic bytes, not the client-supplied `Content-Type` header or filename extension. This satisfies "validate actual content type" without adding a gem: no `active_storage_validations` dependency, a small custom concern instead (see Implementation Notes), consistent with this codebase's existing preference for small custom validators over new dependencies (ADR-002 rejected `acts_as_list` on the same reasoning).

**Max file size: 15 MB per file.** Derived the same way SPEC-006 derived its 50-character tagline limit — from the real data already in the repo rather than picking a round number blind. The 20 real files currently in `app/assets/images/gallery/` range from 2.3 MB to 7.7 MB (camera JPEGs, already hand-picked by Doug). 15 MB is roughly 2x the largest file observed today, giving headroom for higher-resolution phone cameras without Doug hitting a rejected-upload error mid-task at the shop, while still bounding worst-case storage (15 MB × 100 photos ≈ 1.5 GB — trivial against the mounted volume) and acting as a basic upload-DoS guard. Because publicly-served images go through the `:display` variant (Decision 5), a generous cap on the original does not translate into a large payload for site visitors.

**No dimension or aspect-ratio validation.** Both render targets already defend against extreme aspect ratios at the CSS layer: Gallery uses `aspect-square ... object-fit: cover`; the About slideshow's `<style>` block absolute-positions each `<img>` with `object-fit: cover` inside a `height: 60vh` container. `object-fit: cover` crops to fill the box regardless of source shape, so no image can break either layout. Not an architectural requirement; the spec agent may optionally add a soft minimum pixel-dimension floor (e.g. reject anything under ~400px on the short edge) purely as a quality guard against an accidentally-uploaded thumbnail being blown up to fill a 60vh hero — that is a UX nicety, not a layout-safety requirement, and is left to SPEC-008.

### 5. Active Storage variants: yes, generate a `:display` variant; never serve originals to visitors

Both surfaces are public marketing pages; uploads are camera-original files (confirmed by the existing 2.3-7.7 MB files already in the repo). Serving originals directly would hurt page-load performance for site visitors on mobile networks — the same mobile-first concern CLAUDE.md raises for the admin applies at least as much to visitors. Define one named variant, applied at both render call sites:

```ruby
photo.image.variant(:display) # resize_to_limit + quality-tuned save
```

The processing backend is already 90% wired: `config.load_defaults 8.1` already sets `active_storage.variant_processor = :vips`, and the production Docker image already installs the `libvips` system package. The only missing piece is the `ruby-vips` **gem** in the `Gemfile` (see Implementation Notes). Synchronous on-demand variant generation (Active Storage's default) is sufficient for this traffic profile — no background job is required. As a cheap optimization, generate the variant synchronously right after `attach` in the create/update action (`photo.image.variant(:display).processed`) so the first public visitor after an upload doesn't pay processing latency.

### 6. Admin upload UI: one file at a time, Move Up/Down buttons, no drag-and-drop

Single `file_field` per submission, not a multi-file picker — matches the phone-camera-roll workflow, avoids a new batch-progress UI, and matches every existing admin form's one-field-per-submit shape. Reordering uses the identical Move Up/Move Down button pattern already shipped for `ServiceSection` (ADR-002), not drag-and-drop — zero new learning curve for Doug, zero new Stimulus controller, and ADR-002 already rejected the added complexity of a general-purpose ordering mechanism for a small, single-admin collection.


## Rationale

### Named `has_one_attached` slots, not `has_many_attached` or a join model (About)

The 3 slots are fixed, named, and individually addressable — exactly the shape already chosen for `slideshow_alt_1/2/3` in SPEC-007 rather than a `slideshow_alts` array or child table. `has_many_attached` is built for open-ended, insertion-ordered collections (that's the Gallery case); using it here to represent "exactly 3 named replaceable slots" would require inventing a positional convention on top of `ActiveStorage::Attachment`'s implicit ordering and a custom validation to enforce the count stays at 3 — solving a problem the named-column approach doesn't have. A dedicated join model (`AboutSlideshowImage` with a `position` 1-3) is the right shape for a *variable*-length ordered collection (see ADR-001's reasoning for `service_bullets`), but these slots are neither variable in count nor unlabeled — they already have stable names. Three named attachments on the existing singleton is the smallest change that preserves the 1:1 slot semantics R20 already established for alt text.

### Reusing `published` instead of a new image-specific flag

`AboutPageContent#published` is already, per ADR-004, "is this content object live?" — a property of the whole record, not of any one field. Images are just another field on that same record. Introducing a second flag (e.g. `images_published`) would let the record enter a state where text is live but images aren't (or vice versa) with no way for Doug to reason about "is my page live" as a single question — exactly the kind of split-brain state ADR-004 avoided by choosing one co-located boolean over independent settings. Gating images with the same `published` column, with per-slot fallback to the bundled static file when a slot has no attachment, extends "unpublished changes are safe" to images using the same mechanism already trusted for text, at zero additional schema cost.

### No backfill for About, blocking backfill for Gallery — because the two "originals" mean different things

For About, the original static file *remains the fallback forever* — it is never superseded, only ever conditionally overridden. There is nothing to migrate because nothing about the current rendering path changes until Doug acts.

For Gallery, the spec removes the fallback mechanism entirely — `Dir.glob` is deleted, full stop. The static files stop being read the instant this ships. Anything not copied into `GalleryPhoto` rows disappears from the live site. That is a real regression risk, not a hypothetical one, which is why the backfill is called out as blocking rather than advisory.

### Rake task, not a migration, for the Gallery backfill

`db/migrate` is schema, not data-with-side-effects. Attaching a blob does real file I/O against the mounted volume and has no meaningful `down` step (un-attaching and re-deleting a blob inside a migration rollback is fragile and not how this codebase treats data seeding — `db/seeds.rb` already sits outside migrations for the same reason). A rake task run once at deploy time is the same shape as every other one-time data operation this app already has.

### `image_processing` variants over serving originals

The files already in the repo are 2.3-7.7 MB camera JPEGs. Both display contexts (an `aspect-square` grid thumbnail, a `60vh` slideshow panel) render at a small fraction of a camera-original's pixel dimensions. Serving the original to every visitor for every photo is pure waste — slower page loads on the same mobile networks CLAUDE.md is explicit about caring for. The infrastructure for this is already 90% present (`vips` variant processor default, `libvips` system package in the Docker image, `image_processing` gem already in `Gemfile`) — the remaining gap is a one-line `Gemfile` addition, not a new architectural direction.


## Alternatives Considered

### About slideshow data model

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-------------------|
| **`has_one_attached` × 3 (chosen)** | Mirrors existing `slideshow_alt_1/2/3` column shape exactly; no new table; simple per-slot fallback | Three near-identical attachment declarations | — |
| `has_many_attached :slideshow_images` | Single association; "add more slides" would be free later | Ordering is implicit (attachment insertion order), which is exactly the "fragile positional convention" this codebase avoids elsewhere (ADR-002 uses an explicit `position` column rather than relying on implicit order); requires a custom validation to pin the count at exactly 3, which is more code than 3 named attachments | Wrong shape for "3 fixed, named, individually-addressable slots"; solves an open-endedness problem that doesn't exist here |
| Dedicated `AboutSlideshowImage` join model (`position` 1-3) | Symmetric with `GalleryPhoto` | New table, new FK, new controller surface for a count that will never change; duplicates the "singleton content record" pattern's job | Over-engineered for a fixed-count, named-slot case; ADR-001's join-table reasoning applies to *variable*-length collections, not fixed ones |

### Gallery data model

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-------------------|
| **Dedicated `GalleryPhoto` model, `has_one_attached :image`, integer `position` (chosen)** | Matches `ServiceSection`/`ServiceBullet` precedent (ADR-001, ADR-002) exactly; each photo individually addressable, orderable, deletable | One more table | — |
| `SiteSetting`-style key-value rows | No new table | Cannot represent a per-row binary attachment or ordering cleanly; same reasoning ADR-001 already rejected for `service_bullets` | Wrong shape for an ordered collection of first-class records |
| JSON column on a singleton "gallery settings" row listing photo metadata, blobs attached separately | Fewer tables | Loses individual-row addressability (no per-photo `id` to target for delete/reorder requests); Rails nested-attributes patterns don't apply to a JSON column | Same reasoning ADR-001 rejected for a JSON-column service model |

### Gallery reordering mechanism

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-------------------|
| **Move Up / Move Down buttons + gap-tolerant position swap (chosen)** | Zero new dependency; identical UX to `ServiceSection`, already shipped and understood by Doug; trivial to tap on a phone | Extra tap per multi-position move | — |
| Drag-and-drop (Stimulus + Sortable-style controller) | Faster for large reorders | New Stimulus controller; touch drag-and-drop on mobile Safari is notoriously fiddly to get right (scroll-vs-drag conflicts); more surface area to test | Disproportionate complexity for a single-admin, phone-first, likely-small (dozens, not hundreds) photo collection |
| Numeric position text field per row | Simple form field | Doug has to compute correct numbers manually; worse mobile UX than tap-to-move buttons | Strictly worse UX than buttons for no implementation savings |

### Gallery backfill mechanism

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-------------------|
| **Idempotent rake task, run once at deploy (chosen)** | Matches existing `db/seeds.rb`-style one-time data operations; safe to re-run; no schema-migration side effects | Manual step to remember at deploy time | — |
| Data migration (`db/migrate` file that attaches blobs) | Runs automatically with `db:migrate` | File I/O and blob creation inside a schema migration; no clean rollback; couples deploy-time file availability to migration success | Anti-pattern for this codebase's migration/seed split; mirrors why ADR-002's icon-key backfill used `reversible`/`up`-only blocks rather than pretending it's cleanly reversible, but goes further by touching real files, which migrations should not do |
| Skip backfill; let Doug re-upload everything manually post-deploy | Zero script to write | Gallery page renders empty from deploy until Doug manually re-uploads ~20 photos one at a time; real, visible regression on a public marketing site | Unacceptable interruption to a live public page for a mechanical, scriptable task |

### Image validation approach

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-------------------|
| **Custom concern, plain Ruby validation against `blob.content_type`/`blob.byte_size` (chosen)** | No new gem; consistent with existing custom-validator style (`PHONE_NUMBER_FORMAT` on `AboutPageContent`, `at_least_one_bullet` on `ServiceSection`) | ~20 lines to write once | — |
| `active_storage_validations` gem | Declarative `validates :image, attached: true, content_type: [...]` | New dependency for a small, one-time need | Same reasoning ADR-002 used to reject `acts_as_list`: a small, well-understood problem doesn't justify a new gem |


## Consequences

### Positive

- The About and Gallery cases use the two data-shape patterns this codebase already has muscle memory for: named fields on a singleton (ADR-004) for fixed slots, and a dedicated ordered table (ADR-001/ADR-002) for an open collection. No third pattern introduced.
- No backfill risk for About — the existing static files keep working as the fallback indefinitely, exactly as they do today, until Doug explicitly uploads a replacement.
- Reordering and admin-list UI for `GalleryPhoto` are a near-verbatim reuse of `ServiceSection`'s already-shipped, already-tested pattern — low implementation risk.
- Visitors get resized/optimized images instead of multi-megabyte camera originals, improving mobile page-load performance on both public pages.
- No new gems beyond `ruby-vips` (a processing backend, not a new capability — `image_processing` was already present).

### Negative

- Three near-identical `has_one_attached` declarations (plus matching form fields, params, and fallback logic) on `AboutPageContent` is some repetition; acceptable because the count is fixed at 3 and unlikely to ever change (a 4th slideshow slot would require a template redesign, not just a data change).
- The Gallery backfill is a manual, must-not-forget deploy step, not something `db:migrate`/`db:seed` runs automatically. This must be called out explicitly in SPEC-008's task breakdown and deploy checklist so it isn't silently skipped.
- `GalleryPhoto` and `AboutPageContent`'s slideshow slots duplicate the same content-type/size validation logic unless factored into a shared concern (addressed in Implementation Notes, but is still two call sites to keep in sync going forward).

### Risks

- **Active Storage is not yet installed.** `bin/rails active_storage:install` has never been run in this codebase. Whichever spec (About images or Gallery) is implemented first must run this migration. If both specs are worked in parallel branches, this is a merge-conflict / double-migration hazard — mitigated by treating this as a single shared prerequisite step, ideally landed once on `main` before either spec's feature branch starts, not duplicated on both branches.
- **`ruby-vips` gem is not yet in `Gemfile.lock`.** Must be added explicitly (`gem "ruby-vips"`) even though the system-level `libvips` C library and Rails' default `variant_processor` are already in place. Until this gem is added, any `.variant(...)` call raises at runtime.
- **Local development and CI need `libvips` too.** The production Docker image already has it; developer machines and the GitHub Actions runners in `.github/workflows/ci.yml` do not, unless a step is added. Any system spec or request spec that renders a variant will fail in CI until `libvips` is installed there (e.g. `apt-get install -y libvips` in the CI job, or the GitHub-hosted runner's default image already includes it — verify before relying on it). Flagging for the devops agent; not a blocker for writing SPEC-008, but is a blocker for that spec's tests passing in CI.
- **`* copy.jpg` duplicates get carried into the Gallery backfill.** Three files in `app/assets/images/gallery/` (`m45a2724 copy.jpg`, `m45a2778 copy.jpg`, `m45a2817 copy.jpg`) are pre-existing duplicates already rendered twice on the live site today. The backfill intentionally preserves this (see Rationale) rather than silently "fixing" it — mitigated by this being immediately, trivially correctable by Doug via the new delete button, which did not exist before this feature.
- **Restoring About defaults now has a destructive side effect it didn't have before** (purging 3 attachments, not just resetting text). Existing `data-turbo-confirm` copy for the restore button (SPEC-007 R21c) should be updated to mention images explicitly so Doug isn't surprised — a spec-level wording change, not an architectural one, but worth flagging so it isn't missed.


## Implementation Notes

1. **Prerequisite, before either spec's implementation work starts:** run `bin/rails active_storage:install` and commit the resulting migration. This is a one-time, shared step — land it on `main` once rather than duplicating it across both the About-images and Gallery-CRUD branches.

2. **Add the variant processing backend:** add `gem "ruby-vips"` to `Gemfile` and `bundle install`. No `config.active_storage.variant_processor` change needed — `config.load_defaults 8.1` already sets it to `:vips`. Confirm `libvips` is available wherever tests run (local dev machines, CI) in addition to the production Docker image, which already has it.

3. **Shared validation concern**, used by both `AboutPageContent` (for the 3 slots) and `GalleryPhoto` (for `:image`):

   ```ruby
   # app/models/concerns/image_attachment_validatable.rb
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

   `AboutPageContent` calls `validates_image_attachment :slideshow_image_1, :slideshow_image_2, :slideshow_image_3` (all optional — presence is not required, since an unattached slot is a valid, expected state that falls back to the static file). `GalleryPhoto` calls `validates_image_attachment :image` plus a separate presence-style validation (`image.attached?` must be true — a `GalleryPhoto` row with no image makes no sense, unlike an About slot).

4. **Named variant**, defined once and called from both views:

   ```ruby
   photo.image.variant(resize_to_limit: [1200, 1200], saver: { quality: 80 })
   ```

   Wrap this in a small helper or model method (e.g. `GalleryPhoto#display_variant`) rather than repeating the options at every call site. Exact dimensions are a spec/developer-level tuning decision, not an architectural one — 1200px is a starting point sized for the largest rendered context (About's `60vh` slideshow panel on a large viewport), not the Gallery grid's smaller cells.

5. **Gallery migration:**

   ```ruby
   create_table :gallery_photos do |t|
     t.integer :position, null: false, default: 0
     t.timestamps
   end
   ```

   No FK, no other columns. `GalleryPhoto.order(:position)` for display order, matching `ServiceSection.order(:position)`.

6. **Gallery reorder actions** — copy `Admin::ServiceSectionsController#move_up`/`#move_down` verbatim, substituting `GalleryPhoto` for `ServiceSection` (see ADR-002 Implementation Notes for the exact gap-tolerant query shape). New records get position via `(GalleryPhoto.maximum(:position) || -1) + 1`, matching `Admin::ServiceSectionsController#create`.

7. **Gallery backfill rake task** (`lib/tasks/gallery_photos.rake`):

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

   Run once, manually, as part of this feature's deploy (`bin/kamal app exec "bin/rails gallery_photos:backfill"` or equivalent) — document this explicitly as a required deploy step in SPEC-008's task breakdown, the same way `db:seed` is already a known post-migration step for this app.

8. **About form additions:** add 3 `f.file_field` inputs to the existing About content edit form; extend `about_page_content_params` in `Admin::AboutPageContentsController` to permit `:slideshow_image_1, :slideshow_image_2, :slideshow_image_3`. `form_with` auto-detects the presence of a file field and sets `multipart: true` — no explicit change needed there.

9. **Restore-defaults extension:** in `Admin::AboutPageContentsController#restore_defaults`, after resetting the 10 text fields, also call `about_page_content.slideshow_image_1.purge` / `_2.purge` / `_3.purge` (guard each with `.attached?` first). Update the `confirm_restore_defaults` i18n string to mention images so the confirmation dialog accurately describes what will happen.

10. **View fallback pattern** for About (extends the existing `content = @about_page_content&.published? ? @about_page_content : nil` local from R3a):

    ```erb
    <% if content&.slideshow_image_1&.attached? %>
      <%= image_tag content.slideshow_image_1.variant(resize_to_limit: [1200, 1200]), alt: content.slideshow_alt_1 %>
    <% else %>
      <%= image_tag "gallery/m45a2920.jpg", alt: content&.slideshow_alt_1 || t("pages.about.slideshow_alt_1") %>
    <% end %>
    ```

    Repeat for slots 2 and 3, preserving document order per R20.

11. **Security confirmation, no action needed:** Active Storage blobs are stored under generated keys, not user-controlled filenames/paths, so path traversal is not a concern for either model. The content-type allowlist (Implementation Note 3) deliberately excludes `image/svg+xml`.

12. **Sequencing:** the Gallery portion of this ADR has no dependency on SPEC-007 and can be implemented and shipped independently, in either order relative to About. The About-slideshow-images portion depends on `AboutPageContent` existing, which is only true once PR #38 (SPEC-007) merges to `main`. Recommend the spec agent split SPEC-008 into two independently-shippable tracks (or two specs) so the Gallery CRUD is not blocked waiting on an unrelated PR to merge.


## Handoff to Spec Agent (SPEC-008)

Not decided here, left for the spec agent:
- Exact pixel dimensions and quality setting for the `:display` variant.
- Whether to add an optional soft minimum-dimension quality guard (Decision 4).
- Exact i18n keys, flash messages, and confirmation-dialog copy (including the updated `confirm_restore_defaults` wording per Implementation Note 9).
- Whether `GalleryPhoto` needs a per-photo caption/alt-text field, or continues using the single generic `t("pages.gallery.photo_alt")` string for every photo as it does today — this ADR does not change that behavior, only the storage/CRUD mechanism.
- Full acceptance criteria and test plan, including request specs for content-type/size rejection and a system spec confirming the Gallery admin list has no horizontal scroll at 375px per CLAUDE.md's mobile-first mandate.


## Addendum (2026-07-17): Reordering mechanism reversed to drag-and-drop

**Status of this addendum:** Accepted, supersedes Decision 6 and the "Gallery reordering mechanism" alternatives table for the Gallery admin UI only. Everything else in this ADR (data model, validation, backfill, variants, About slideshow) is unchanged.

**Original decision:** Move Up / Move Down buttons with gap-tolerant position-swap queries, explicitly chosen over drag-and-drop. Rationale at the time: zero new dependency, reuse of the already-shipped `ServiceSection` pattern, and a stated concern that "touch drag-and-drop on mobile Safari is notoriously fiddly to get right (scroll-vs-drag conflicts)."

**Reversal:** After using the shipped Move Up/Down implementation, the product owner (Doug, via the person testing on his behalf) found it clunky for a photo collection and requested a genuine drag-and-drop grid instead. This is a subjective UX call the architecture process cannot make on his behalf — noted here rather than treated as an oversight in the original analysis.

**Revised decision:**
- Admin Gallery view changes from a stacked-card list to a responsive grid (`grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2`, matching the public Gallery page's own grid, per `app/views/pages/gallery.html.erb`), each cell a draggable thumbnail tile.
- Reordering is handled by **SortableJS**, pinned via `bin/importmap pin sortablejs` — the first third-party JS dependency in this codebase (previously only Hotwire/Stimulus). Chosen specifically because it does not rely on the native HTML5 Drag and Drop API, which is mouse-only and does not fire on touchscreens at all — the exact failure mode the original decision was worried about. SortableJS implements its own pointer-event-based dragging, which works on both mouse and touch, and is a widely-used, dependency-free, actively maintained library with no build-step requirement (ships as a single ESM-compatible file, pinnable directly via importmap from a CDN).
- A new Stimulus controller (`gallery_sort_controller.js`) initializes `Sortable` on the grid container and, on drag-end, POSTs the new ordered list of photo IDs to a new controller action.
- `Admin::GalleryPhotosController#move_up` / `#move_down` and their routes are removed. A new `PATCH /admin/gallery_photos/reorder` action (`Admin::GalleryPhotosController#reorder`) replaces them: accepts an ordered array of IDs, updates every `GalleryPhoto`'s `position` in a single `ActiveRecord::Base.transaction`, and returns a minimal success response (Turbo Stream or a bare 200 — no full-page redirect needed since the client-side drag already reflects the new order).
- Per explicit product decision, the Move Up/Move Down buttons are **fully removed**, not kept as a fallback. This does trade away keyboard-only reordering — acceptable here because this is a single-admin internal tool (only Doug has admin credentials), not a public-facing or multi-user surface, and CLAUDE.md's accessibility bar is scoped around mobile *usability*, not WCAG keyboard-operability compliance for this app.
- Delete stays a per-tile affordance (a small icon/button overlaid on each grid thumbnail), unaffected by this addendum.

**Consequence for Implementation Note 6 and Decision 6:** both are superseded for the Gallery admin UI. `Admin::ServiceSectionsController#move_up`/`#move_down` remains the correct, unchanged pattern for `ServiceSection` (ADR-002) — this addendum does not touch that feature. The gap-tolerant swap-query pattern is not reused by `GalleryPhoto` going forward; full-list position reassignment on drop is simpler and sufficient at this collection's scale (dozens, not hundreds, of rows).
