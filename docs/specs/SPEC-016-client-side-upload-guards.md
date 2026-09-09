# Spec: Client-Side Upload Guards for Admin Image Inputs

**ID:** SPEC-016
**Status:** ready
**Priority:** medium
**Created:** 2026-09-09
**Author:** spec-agent

---

## Goal

Stop an oversized or wrong-kind file from ever leaving the browser on the six admin image-upload inputs, so a mistaken selection fails fast and locally instead of paying for a full upload the server was always going to reject anyway.

This was prompted by a concrete incident: the repo owner, testing locally, selected a 4 GB video in place of an image for the hero upload. The server correctly rejected it, but only after a long wait that felt wrong on localhost. The cause is `ActiveStorage::Blob#unfurl` (`activestorage-8.1.3.1/app/models/active_storage/blob.rb:269-273`):

```ruby
self.checksum     = compute_checksum_in_chunks(io)   # reads the ENTIRE file, 5 MB at a time
self.content_type = extract_content_type(io) ...
self.byte_size    = io.size                          # ← only known here
```

`ImageAttachmentValidatable` reads `attachment.blob.byte_size` and `.content_type`, so the blob must be built — meaning the whole file is spooled to a Rack tempfile and then re-read in full for an MD5 checksum — before either check can run. That ordering belongs to Rails and is not this spec's to change. Server-side validation cannot be made to run earlier than the blob it validates. The only place left to intervene is before the file leaves the browser at all, which is what the two guards in this spec do.

## Non Goals

- **Any change to `ImageAttachmentValidatable`'s validation behavior, `MAX_IMAGE_SIZE`'s value, `ALLOWED_IMAGE_TYPES`' contents, or the server-side error message copy.** This spec adds two presentation-only members to that file (R1) and reads its existing constants; it does not touch `validate_image_attachment` or anything `activerecord.errors.messages` says. See R19 — the non-negotiable restatement of why.
- **Thruster's `MAX_REQUEST_BODY`.** It exists, defaults to `0` (unlimited), and is unset in this app. Setting it would 413 an oversized request at the edge in production — but Thruster is not part of the development stack, so it would not have prevented the incident that prompted this spec (which happened on `bin/dev`, not behind Thruster). Recorded here as a deferred follow-up for production hardening, not as scope: raising it is a one-line `config/thruster.yml`-equivalent change independent of anything in this spec.
- **Active Storage direct upload.** SPEC-013 R10 already names this as the deferred remedy for a *different* problem: a proxy read-timeout on a slow mobile connection mid-upload of a file that was always going to be accepted. Direct upload still transfers the whole file from the browser to storage — it does nothing for a file that should never have been offered by the picker or selected by the admin in the first place, which is this spec's problem. The two problems share a neighborhood (image uploads, mobile admin) but not a cause, and are not to be conflated or solved by the same change.
- **Browser-side image resizing, cropping, or transcoding.** Out of scope; the guards only inspect `File.size` and `File.type`, never the file's contents.
- **A submit-time or form-level validation layer.** No `submit` listener is added anywhere in this spec — see R14 for why clearing the input at `change` time is sufficient on its own.
- **Any accessibility or layout change to fields beyond the one hidden message element and the `accept` attribute this spec adds.** No other markup in the six inputs' surrounding forms is touched.

---

## Definitions

| Term | Definition |
|------|-----------|
| Guard 1 / picker filter | The `accept` attribute added to each `<input type="file">`, restricting what the OS-native file picker offers to select. A hint the browser honors when a user opens the *picker dialog* — it has no effect on drag-and-drop and can be bypassed by choosing "All Files" where the OS offers that option. |
| Guard 2 / client-side guard | The Stimulus controller (`image_upload_guard_controller.js`) that inspects a selected file's `size` and `type` on the `change` event and rejects it locally before any submission can include it. |
| oversized rejection | Guard 2 rejecting a file because `file.size > ImageAttachmentValidatable::MAX_IMAGE_SIZE`. |
| type rejection | Guard 2 rejecting a file because its reported `file.type` is non-empty and not a member of `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES`. |
| `unfurl` | `ActiveStorage::Blob#unfurl`, the Rails method described in the Goal section that must read a file in full (for its checksum) before size or content-type become available to validate. Cited, not re-derived, from `activestorage-8.1.3.1/app/models/active_storage/blob.rb:269-273`. |
| `ImageAttachmentValidatable` | The shared server-side validation concern at `app/models/concerns/image_attachment_validatable.rb` (SPEC-008). This spec adds `ALLOWED_IMAGE_EXTENSIONS` and `.accept_attribute_value` to it (R1) and otherwise treats it as read-only, authoritative infrastructure. |
| the six inputs | The admin file inputs enumerated in the Interfaces table below — the full scope of both guards. |

---

## Interfaces

### The Six Admin File Inputs

| File | Line (current) | Field | Guard 1 | Guard 2 |
|---|---|---|---|---|
| `app/views/admin/home_page_contents/show.html.erb` | n/a — see Dependencies | `:hero_image` | applies | applies |
| `app/views/admin/home_page_contents/show.html.erb` | n/a — see Dependencies | `:cta_image` | applies | applies |
| `app/views/admin/about_page_contents/show.html.erb` | 76 | `:slideshow_image_1` | applies | applies |
| `app/views/admin/about_page_contents/show.html.erb` | 90 | `:slideshow_image_2` | applies | applies |
| `app/views/admin/about_page_contents/show.html.erb` | 104 | `:slideshow_image_3` | applies | applies |
| `app/views/admin/gallery_photos/index.html.erb` | 17 | `:image` | applies | applies |

The `hero_image`/`cta_image` inputs do not exist in `main` as of this spec's authoring — see Dependencies. Their line numbers and markup shape are drawn from the open, unmerged SPEC-013 implementation (PR #81), which is where this spec's location table for those two rows was verified.

### `ImageAttachmentValidatable` — New Presentation-Only Members

```ruby
module ImageAttachmentValidatable
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  ALLOWED_IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze
  MAX_IMAGE_SIZE = 15.megabytes # or 30.megabytes once SPEC-013 lands — unchanged by this spec either way

  def self.accept_attribute_value
    (ALLOWED_IMAGE_TYPES + ALLOWED_IMAGE_EXTENSIONS).join(",")
  end

  # ... validate_image_attachment and everything else, unchanged
end
```

`accept_attribute_value` is a module method (not a `class_methods` mixin method) — called directly as `ImageAttachmentValidatable.accept_attribute_value` from any of the six views, the same way `ImageAttachmentValidatable::MAX_IMAGE_SIZE` is already referenced directly rather than through an including model.

### New Stimulus Controller

`app/javascript/controllers/image_upload_guard_controller.js` — picked up automatically by `eagerLoadControllersFrom("controllers", application)` in `app/javascript/controllers/index.js` (unchanged); no registration edit needed.

Contract:

```js
static targets = ["input", "message"]
static values = {
  maxBytes: Number,
  allowedTypes: String,        // comma-separated MIME types, e.g. "image/jpeg,image/png,image/webp"
  oversizedMessage: String,
  invalidTypeMessage: String
}
```

One public action, `validate(event)`, bound via `data-action="change->image-upload-guard#validate"` on the file input itself — the same wiring shape `icon_preview_controller.js` already uses for its `select`'s `change->icon-preview#change` (`app/views/admin/service_sections/_form.html.erb` line 28), not a listener attached in `connect()`.

### View Wiring (representative — applies identically at all six sites)

```erb
<div data-controller="image-upload-guard"
     data-image-upload-guard-max-bytes-value="<%= ImageAttachmentValidatable::MAX_IMAGE_SIZE %>"
     data-image-upload-guard-allowed-types-value="<%= ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES.join(',') %>"
     data-image-upload-guard-oversized-message-value="<%= t("admin.gallery_photos.oversized_image_alert", max_mb: ImageAttachmentValidatable::MAX_IMAGE_SIZE / 1.megabyte) %>"
     data-image-upload-guard-invalid-type-message-value="<%= t("admin.gallery_photos.invalid_image_type_alert") %>">
  <%= f.label :image, t("admin.gallery_photos.image_label"), class: "block text-sm font-semibold mb-1" %>
  <%= f.file_field :image,
        accept: ImageAttachmentValidatable.accept_attribute_value,
        data: { "image-upload-guard-target" => "input", action: "change->image-upload-guard#validate" },
        class: "w-full border border-gray-300 rounded px-3 py-2" %>
  <p class="mt-1 text-xs text-gray-500"><%= t("admin.gallery_photos.image_hint") %></p>
  <p data-image-upload-guard-target="message" class="hidden mt-1 text-sm text-red-600" role="alert"></p>
</div>
```

The `data-controller` and value attributes land on the **existing** field-wrapping `<div>` at each of the six sites (no new wrapping element introduced); only the new `<p data-image-upload-guard-target="message">` and the `accept`/`data-action` additions on the `<input>` are new markup.

### Required i18n Keys

Six new keys, two per admin namespace (`admin.home_page_content`, `admin.about_page_content`, `admin.gallery_photos`), following the existing per-view duplication convention these three views already use for `image_hint`/`slideshow_image_hint` rather than a new shared namespace:

| Key | Purpose |
|---|---|
| `oversized_image_alert` | Shown when Guard 2 rejects a file for size. Interpolates `%{max_mb}`. |
| `invalid_image_type_alert` | Shown when Guard 2 rejects a file for type. |

`admin.home_page_content.*` and `admin.about_page_content.*` `oversized_image_alert` text reassures the admin their other field values are untouched and that a blank field keeps the current image (matching those views' existing `image_hint` framing); `admin.gallery_photos.oversized_image_alert` does not, since `GalleryPhoto#image` has no "current image to keep" — presence is required (`image_must_be_attached`) and this is always a fresh upload, not a replace.

---

## Rules

### Guard 1 — Picker Filter

R1: `ImageAttachmentValidatable` gains `ALLOWED_IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .webp].freeze`, declared immediately below `ALLOWED_IMAGE_TYPES`, and a module method `self.accept_attribute_value` returning `(ALLOWED_IMAGE_TYPES + ALLOWED_IMAGE_EXTENSIONS).join(",")`. Both `.jpg` and `.jpeg` are listed — a JPEG-only extension list that omits one of its two common spellings would hide a legitimate file from a picker that filters strictly by extension, which is exactly the failure mode this rule exists to avoid.

R2: `ALLOWED_IMAGE_TYPES` gets a one-line comment warning that adding or removing a MIME type there without a matching edit to `ALLOWED_IMAGE_EXTENSIONS` silently desyncs the picker filter from the server's actual rule. This is the one case CLAUDE.md's comment policy calls for: editing `ALLOWED_IMAGE_TYPES` alone looks like a complete, self-contained change, and nothing else in the file signals that it isn't.

R3: All six inputs (Interfaces table) receive `accept: ImageAttachmentValidatable.accept_attribute_value` on their `f.file_field`. The value is **derived**, not written literally per call site — a MIME type added to or removed from `ALLOWED_IMAGE_TYPES` changes what every picker offers with no second edit required, closing the same drift risk R8/R9 of SPEC-013 already named for hardcoded "MB" prose, applied here to the type list instead.

R4: The `accept` value combines MIME types and file extensions in one comma-separated string (e.g. `"image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp"`), not one or the other. MIME-type matching is the more precise, standards-driven mechanism and is what makes iOS/Android offer the native photo picker instead of a general file browser (the mobile-first win this spec is partly about); extension matching is what desktop OS file-dialog filters fall back to reliably across browser/OS combinations where MIME-based filtering is inconsistent. Declaring only one risks silently narrowing what a legitimate file picker shows on some platform; declaring both has no offsetting cost, since a browser unions the two forms rather than requiring both to match.

### Guard 2 — Client-Side Size and Type Guard

R5: A new Stimulus controller, `app/javascript/controllers/image_upload_guard_controller.js`, implements the contract in Interfaces (`targets: ["input", "message"]`, `values: { maxBytes, allowedTypes, oversizedMessage, invalidTypeMessage }`, one action `validate(event)`). It is picked up automatically by the existing `eagerLoadControllersFrom` call — no change to `app/javascript/controllers/index.js`.

R6: `validate(event)` reads the newly selected file from `this.inputTarget.files[0]`. If no file is present (the picker was cancelled, or the field was cleared), the method hides the message target and returns — this is not a rejection.

R7: Type is checked before size. If `file.type` is a non-empty string and is not included in `this.allowedTypesValue.split(",")`, the file is rejected with a type message (R9). This order is deliberate: a video selected by mistake — the exact incident that prompted this spec — is both the wrong type and (usually) oversized, and telling the admin "that's not an image" names the actual mistake more usefully than "that image is too large," which wrongly concedes the file was an image at all.

R8: If the type check passes (or is skipped per R12), size is checked: if `file.size > this.maxBytesValue`, the file is rejected with the oversized message (R9). The comparison is strict `>`, matching `ImageAttachmentValidatable#validate_image_attachment`'s own `attachment.blob.byte_size > ImageAttachmentValidatable::MAX_IMAGE_SIZE` exactly — a file exactly at the cap is accepted by both the client guard and the server, never rejected by one and accepted by the other.

R9: A rejection (type or size) does exactly three things: clear `this.inputTarget.value = ""`, set `this.messageTarget.textContent` to the corresponding message value (`invalidTypeMessageValue` or `oversizedMessageValue`), and remove the `hidden` class from `this.messageTarget`. Nothing else in the DOM changes — see R13.

R10: A pass (no rejection) does the reverse of the message half of R9: add `hidden` back to `this.messageTarget` and clear its `textContent`. The file is left selected in `this.inputTarget` — Guard 2 never clears a valid selection.

R11: This is deliberately the entire remedy — no `submit` listener is added anywhere. Because R9 clears the input's value synchronously inside the `change` handler, an oversized or wrong-type file can never be present in the input by the time any later `submit` event fires; there is no race to guard against, and a second listener would be redundant complexity solving a problem that clearing-on-change already closes.

R12: If `file.type` is empty or not recognized by the browser (which happens for some files on some older mobile browsers), the type check is skipped — it neither rejects nor accepts on type grounds, and the file proceeds to the size check (R8). Failing open here is deliberate: rejecting a file client-side on the strength of a browser's absence of information would produce false rejections of legitimate images, and `ImageAttachmentValidatable` remains the backstop regardless (R19).

R13: A rejection touches only `this.inputTarget.value` and `this.messageTarget`'s content/visibility. No other field in the form — text input, textarea, checkbox, another file input — is read, cleared, or reset; no `form.reset()` is called; no page reload or Turbo navigation is triggered. This is what guarantees an admin's unsaved text edits survive a rejected image selection: nothing about the rest of the form's DOM state is touched, so there is nothing to lose.

R14: The message element (`data-image-upload-guard-target="message"`) is a `<p>` with `role="alert"`, `hidden` by default, styled `text-sm text-red-600` matching the existing red validation-error styling already used for server-side errors in these same three forms. It sits directly after the existing hint paragraph, inside the same field-wrapping `<div>` — no horizontal scroll is introduced at any viewport width, including 375px (mobile-first, CLAUDE.md).

### Values Source and i18n

R15: `data-image-upload-guard-max-bytes-value` and `data-image-upload-guard-allowed-types-value` are rendered directly from `ImageAttachmentValidatable::MAX_IMAGE_SIZE` and `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES.join(",")` at each of the six call sites, at render time, in Ruby. No JavaScript file contains a numeric size literal or a hardcoded MIME-type list — if either constant changes, every one of the six inputs reflects the new value on the next page render with no JS edit.

R16: Six new i18n keys are added — `oversized_image_alert` and `invalid_image_type_alert` under each of `admin.home_page_content`, `admin.about_page_content`, `admin.gallery_photos` — per the Interfaces table's content guidance. `oversized_image_alert` interpolates `%{max_mb}` (supplied as `ImageAttachmentValidatable::MAX_IMAGE_SIZE / 1.megabyte` at the call site) rather than stating a number in the translated string itself. Unlike the static hint copy SPEC-013 R9 had to hunt down and correct by hand across three keys when the cap changed once already, this copy cannot go stale — a future cap change requires no i18n edit at all.

R17: All six new keys are looked up with explicit scoped calls — `t("admin.gallery_photos.oversized_image_alert", ...)`, not lazy `t(".oversized_image_alert")` — matching the existing, deliberate convention in all three of these views (their key namespace is singular, `admin.home_page_content`/`admin.about_page_content`, while Rails' lazy lookup would derive the plural view-path namespace `admin.home_page_contents`/`admin.about_page_contents`; the existing code already avoids this mismatch by never using lazy lookup in these three files).

### Non-Authority — Restated

R18: This spec introduces no new server-side validation and modifies no existing one. `ImageAttachmentValidatable#validate_image_attachment`, `MAX_IMAGE_SIZE`'s value, `ALLOWED_IMAGE_TYPES`'s contents, and every `activerecord.errors.messages` string are unchanged by this spec. `accept` is a picker hint a user can override; the Stimulus controller is JavaScript a user can disable, and both are bypassable by drag-and-drop, a disabled-JS browser, or a non-browser client posting directly to the endpoint. A file that reaches the server despite both guards is rejected exactly as it is today, by the unchanged concern. A future reader must not read this spec as having made server-side validation redundant — it has not; it has only made the common, honest-mistake path faster.

### Scope Contingency

R19: `hero_image` and `cta_image` (Interfaces table rows 1-2) do not exist on `main` as of this spec's authoring — see Dependencies. Both guards apply to them in the identical shape described here once SPEC-013 (PR #81) merges. Until then, this spec's implementation covers the four inputs that exist today (`slideshow_image_1/2/3`, `gallery_photos:image`); the `admin.home_page_content.*` i18n keys and hero/cta view wiring are added in the same PR that rebases onto, or lands after, PR #81.

---

## Edge Cases

E1: A file exactly at `MAX_IMAGE_SIZE` (byte-for-byte). Accepted by Guard 2 (R8's strict `>`) and, if it also reaches the server, accepted there too — no boundary mismatch.

E2: A file one byte over `MAX_IMAGE_SIZE`. Rejected by Guard 2 with the oversized message; the input is cleared before any submission can include it.

E3: JavaScript is disabled. Guard 2 never runs; Guard 1's `accept` attribute still narrows the picker (a browser feature, not a script). An oversized file selected via "All Files" still reaches the server and is rejected there, exactly as before this spec — unchanged, and not a regression, since this spec's guarantee is server-side correctness under any condition, not client-side speed under every condition.

E4: A non-image file (e.g. a video) is dragged onto the input rather than selected via the picker. `accept` has no effect on drag-and-drop; Guard 2's type check (R7) still catches it if the browser reports a recognizable, disallowed `file.type`.

E5: A dragged or selected file's `file.type` is empty or unrecognized. Guard 2's type check fails open (R12) — no type rejection — and the file proceeds to the size check. If it also passes that, it reaches the server, where `ImageAttachmentValidatable` is the final word.

E6: An admin selects an oversized file, is rejected, then selects a valid smaller file for the same input without reloading. The message hides (R10), the valid file is retained, and submission proceeds normally.

E7: An admin selects an oversized file (rejected, input cleared) and then submits the form without selecting a replacement. For `home_page_content`/`about_page_content`, this is indistinguishable from leaving the field blank — the existing "leave blank to keep the current image" behavior applies unchanged. For `gallery_photos`, this fails server-side on `image_must_be_attached`, exactly as submitting the create form with no file ever selected already does today — this spec does not add or relax that presence check.

E8: An admin has unsaved edits in one or more text fields (e.g. `mission_body`, `bio_heading`) when an image selection is rejected by Guard 2. Per R13, those fields are never read or touched by the rejection handler — their values are exactly what the admin typed, unaffected.

E9: The `hero_image`/`cta_image` inputs, before SPEC-013 (PR #81) lands. They do not exist; nothing in this spec applies to them yet. See R19.

E10: A request reaches `Admin::HomePageContentsController#update`, `Admin::AboutPageContentsController#update`, or `Admin::GalleryPhotosController#create` with an oversized or wrong-type file despite both guards (disabled JS, a hand-crafted request, or drag-and-drop past a stale/disabled `accept`). The server rejects it via the unchanged `ImageAttachmentValidatable` path — HTTP 422, the existing `file_too_large`/`invalid_content_type` messages — proving the guards added no gap.

---

## Acceptance Criteria

### Guard 1 — Picker Filter

AC-1: `ImageAttachmentValidatable.accept_attribute_value` returns a comma-separated string containing all of `image/jpeg`, `image/png`, `image/webp`, `.jpg`, `.jpeg`, `.png`, `.webp`, and nothing else.

AC-2: Given `ALLOWED_IMAGE_TYPES` gains or loses a member, when `accept_attribute_value` is called, then its return value reflects the change with no other code edited (unit-level proof of R3's no-drift claim).

AC-3: The rendered `f.file_field` at each of `about_page_contents:show` lines 76/90/104 and `gallery_photos:index` line 17 carries an `accept` attribute equal to `ImageAttachmentValidatable.accept_attribute_value`.

AC-4: Once SPEC-013 (PR #81) has landed, the rendered `f.file_field` for `hero_image` and `cta_image` also carries that same `accept` attribute (contingent — see R19, Dependencies).

### Guard 2 — Oversized Rejection

AC-5: Given the gallery photo upload field, when a file larger than `ImageAttachmentValidatable::MAX_IMAGE_SIZE` is selected, then the field's value is cleared and `admin.gallery_photos.oversized_image_alert` becomes visible with `%{max_mb}` substituted for the actual cap.

AC-6: Given an About slideshow image field (representative of all three), when a file larger than `MAX_IMAGE_SIZE` is selected, then the same clearing/message behavior occurs using `admin.about_page_content.oversized_image_alert`.

AC-7: Given a Home hero/CTA image field (contingent on R19), when a file larger than `MAX_IMAGE_SIZE` is selected, then the same clearing/message behavior occurs using `admin.home_page_content.oversized_image_alert`.

AC-8: Given a file exactly at `MAX_IMAGE_SIZE`, when selected on any of the six inputs, then it is accepted client-side — the field retains the file, and the message stays hidden.

AC-9: Given a file one byte over `MAX_IMAGE_SIZE`, when selected, then it is rejected per AC-5/AC-6/AC-7's behavior.

### Guard 2 — Type Rejection

AC-10: Given any of the six inputs, when a file whose `file.type` is a recognized, disallowed MIME type (e.g. `video/mp4`) is selected, then the field's value is cleared and the relevant `invalid_image_type_alert` key becomes visible.

AC-11: Given any of the six inputs, when a file whose `file.type` is empty or unrecognized is selected, then no type rejection occurs — the file proceeds to the size check (AC-5 – AC-9 govern the outcome from there).

AC-12: Given a file that is both oversized and a disallowed type, when selected, then the type rejection message is shown, not the oversized message (R7's ordering).

### Unaffected State

AC-13: Given a text field on the same form holds an admin-typed, unsaved value, when an oversized or wrong-type file is rejected on that form's image field, then the text field's value is unchanged immediately afterward — no reset, no reload, no navigation.

AC-14: Given an oversized file was just rejected and the field cleared, when a valid file under the cap is subsequently selected for the same input, then the message hides and the valid file is retained.

AC-15: Given an oversized file was rejected on an About or Home image field and no replacement is selected, when the form is submitted, then the submission succeeds and that field's existing image (or default) is unchanged — identical to submitting with the field left blank.

AC-16: Given an oversized file was rejected on the Gallery upload field and no replacement is selected, when the form is submitted, then it fails with the existing `image_must_be_attached` presence error — unchanged from current behavior.

### i18n

AC-17: All six new keys (`oversized_image_alert`, `invalid_image_type_alert` under each of the three admin namespaces) resolve without "translation missing" (covered by the existing `spec/integration/locale_completeness_spec.rb`).

AC-18: `oversized_image_alert` under each namespace contains a `%{max_mb}` placeholder, not a hardcoded number.

### Non-Authority

AC-19: `app/models/concerns/image_attachment_validatable.rb`'s `validate_image_attachment` method, `MAX_IMAGE_SIZE`'s value, and `ALLOWED_IMAGE_TYPES`'s contents are byte-for-byte unchanged by this spec's implementation, save for the two new members added by R1 (verified by code review — this spec's diff touches nothing else in that file's validation logic).

AC-20: Given a request is made directly to `Admin::HomePageContentsController#update`, `Admin::AboutPageContentsController#update`, or `Admin::GalleryPhotosController#create` with an oversized file — bypassing both client guards entirely, as a JS-disabled browser or a direct request would — then the response is HTTP 422 with the existing `file_too_large` error, unchanged from pre-spec behavior.

### Mobile-First

AC-21: The message element and its field container introduce no horizontal scroll at 375px viewport width, on all three admin forms, whether the message is hidden or visible.

---

## Acceptance Tests

AT1
Given `ImageAttachmentValidatable::ALLOWED_IMAGE_TYPES` and `ALLOWED_IMAGE_EXTENSIONS`
When `ImageAttachmentValidatable.accept_attribute_value` is called
Then it returns `"image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp"`
Covers: R1, R4, AC-1

AT2
Given a stubbed additional entry in `ALLOWED_IMAGE_TYPES`
When `accept_attribute_value` is called
Then the new MIME type appears in the returned string with no other code changed
Covers: R3, AC-2

AT3
Given the About admin page
When `GET /admin/about_page_content` is rendered
Then the file inputs at `slideshow_image_1/2/3` each carry `accept="#{ImageAttachmentValidatable.accept_attribute_value}"`
Covers: R3, AC-3

AT4
Given the Gallery admin page
When `GET /admin/gallery_photos` is rendered
Then the `:image` file input carries the same `accept` value
Covers: R3, AC-3

AT5 (contingent on SPEC-013 / PR #81 landing — see Dependencies)
Given the Home admin page, post-SPEC-013
When `GET /admin/home_page_content` is rendered
Then the `hero_image` and `cta_image` file inputs each carry the same `accept` value
Covers: R3, R19, AC-4

AT6
Given an authenticated admin on the Gallery upload form (system spec, Selenium headless)
When a file larger than `ImageAttachmentValidatable::MAX_IMAGE_SIZE` is attached via `attach_file`
Then the file field's value is empty and `admin.gallery_photos.oversized_image_alert` (with the real `max_mb`) is visible
Covers: R5, R6, R8, R9, R15, R16, R17, AC-5, E2

AT7
Given an authenticated admin on the About form
When a file larger than `MAX_IMAGE_SIZE` is attached to `slideshow_image_1`
Then the same clearing/message behavior occurs with `admin.about_page_content.oversized_image_alert`
Covers: R8, R9, AC-6

AT8 (contingent on SPEC-013 / PR #81 landing)
Given an authenticated admin on the Home form, post-SPEC-013
When a file larger than `MAX_IMAGE_SIZE` is attached to `hero_image`
Then the same clearing/message behavior occurs with `admin.home_page_content.oversized_image_alert`
Covers: R8, R9, R19, AC-7

AT9
Given a file exactly at `MAX_IMAGE_SIZE` bytes (built via `padded_jpeg_upload`)
When attached to any of the six inputs
Then the field retains the file and the message stays hidden
Covers: R8, AC-8

AT10
Given a file one byte over `MAX_IMAGE_SIZE`
When attached
Then it is rejected per AT6/AT7's behavior
Covers: R8, AC-9, E2

AT11
Given an authenticated admin on the Gallery upload form
When a `video/mp4` file is attached
Then the field is cleared and `admin.gallery_photos.invalid_image_type_alert` is visible
Covers: R7, R9, AC-10, E4

AT12
Given a file whose `type` cannot be determined by the browser (e.g. no extension)
When attached to any of the six inputs
Then no type-rejection message appears and the size check still runs
Covers: R12, AC-11, E5

AT13
Given a file that is both larger than `MAX_IMAGE_SIZE` and a disallowed type
When attached
Then the invalid-type message is shown, not the oversized message
Covers: R7, AC-12

AT14
Given the About form with a distinctive, unsaved value typed into `bio_heading`
When an oversized file is attached to and rejected on `slideshow_image_1`
Then `bio_heading`'s field value is still the typed value immediately afterward
Covers: R13, AC-13, E8

AT15
Given an oversized file was just rejected on a field
When a valid file under the cap is subsequently attached to the same field
Then the message hides and the valid file is retained
Covers: R10, AC-14, E6

AT16
Given an oversized file was rejected on `slideshow_image_2` and no replacement is chosen
When the About form is submitted with valid text field values
Then the submission succeeds and `slideshow_image_2` is unchanged from before the attempt
Covers: R11, AC-15, E7

AT17
Given an oversized file was rejected on the Gallery upload field and no replacement is chosen
When the form is submitted
Then it fails with the existing `image_must_be_attached` presence error
Covers: AC-16, E7

AT18
Given the six new i18n keys
When inspected via the existing locale-completeness check
Then all resolve without "translation missing," and each `oversized_image_alert` value contains `%{max_mb}`
Covers: R16, AC-17, AC-18

AT19
Given `app/models/concerns/image_attachment_validatable.rb` as modified by this spec
When diffed against its pre-spec version
Then the only changes are the addition of `ALLOWED_IMAGE_EXTENSIONS`, the warning comment on `ALLOWED_IMAGE_TYPES` (R2), and `accept_attribute_value` — `validate_image_attachment`, `MAX_IMAGE_SIZE`, and `ALLOWED_IMAGE_TYPES` are otherwise untouched
Covers: R1, R2, R18, AC-19

AT20
Given a request spec that posts directly to `Admin::GalleryPhotosController#create` with an oversized file, bypassing the browser and both client guards entirely
When the request is made
Then the response is HTTP 422 with the existing `file_too_large` error text
Covers: R18, AC-20, E10

AT21
Given the Gallery, About, and Home admin forms rendered at 375px viewport width (system spec), both with and without the guard message visible
When inspected
Then no horizontal scroll occurs in either state
Covers: R14, AC-21

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-09 | Clearing the input at `change` time is the entire remedy — no submit-time guard is added (R11, R13) | The forms mix file inputs with text fields whose unsaved edits must survive a rejected image. A submit-time block risks being implemented as (or evolving into) a full or partial `form.reset()`/re-render, which is exactly the failure mode to avoid. Clearing only the offending input's value inside the `change` handler removes the oversized file from existence before any submit can occur, making a second, submit-time check redundant rather than defense-in-depth. |
| 2026-09-09 | Type check runs before size check (R7) | The incident that prompted this spec was a video mistaken for an image — both wrong-type and oversized. Naming the actual mistake ("not an image") is more accurate and more useful than a size complaint that implicitly concedes the file was a plausible image candidate. |
| 2026-09-09 | Type-check fails open on an empty/unrecognized `file.type` (R12) | Some browsers, mostly older mobile ones, don't always populate `File.type` for every selection. `ImageAttachmentValidatable` is the actual authority regardless of what the client guard concludes (R18); a false client-side rejection of a legitimate image is a worse failure mode than letting an ambiguous file continue to the size check and, if needed, the server. |
| 2026-09-09 | `accept` combines MIME types and file extensions rather than choosing one (R4) | MIME types drive the mobile-first win (native photo picker on iOS/Android) that motivated including this in scope at all; extensions are what desktop OS file dialogs fall back to filtering by when MIME-based filtering isn't consistently honored. Dropping either risks silently narrowing what a legitimate file picker shows on some platform, for a filter that is UX-only regardless. |
| 2026-09-09 | `oversized_image_alert` interpolates `%{max_mb}` instead of stating a number (R16) | SPEC-013 R8 had already raised the shared cap once (15 MB → 30 MB) and R9 had to hand-correct three separately hardcoded "MB" strings as a result. Interpolating from `ImageAttachmentValidatable::MAX_IMAGE_SIZE` at render time means this spec's own new copy can never go stale the same way, and this spec's own prose (Rules, Edge Cases, Acceptance Tests above) deliberately refers to "the cap" or "`MAX_IMAGE_SIZE`" rather than restating its current numeric value, for the identical reason. |
| 2026-09-09 | Six near-duplicate i18n keys (two per view namespace) rather than one shared `admin.shared` key (R16) | `image_hint`/`slideshow_image_hint` already established the pattern of near-identical copy duplicated per admin namespace rather than centralized, and the Gallery copy genuinely differs in substance (no "keep the current image" framing — Gallery has no such concept). Introducing a new `admin.shared` i18n namespace to save five lines of duplication would be a bigger, unrequested change to this codebase's i18n conventions than the duplication it would avoid. |
| 2026-09-09 | Both guards are specified for all six inputs despite two not yet existing on `main` (R19) | The task scope named all six explicitly, and the two missing inputs (`hero_image`, `cta_image`) are on an open, actively-progressing PR (#81, SPEC-013), not a hypothetical future feature. Treating them as in-scope-but-contingent, rather than dropping them to a follow-up spec, avoids a second spec later that would otherwise just repeat this one's Rules verbatim for two more call sites. |

---

## Dependencies

- **SPEC-008 (Gallery Photo Management)** — owns `ImageAttachmentValidatable`, `ALLOWED_IMAGE_TYPES`, `MAX_IMAGE_SIZE`, and the `gallery_photos:image` input this spec wraps unmodified except for R1's two additions.
- **SPEC-009 (About Slideshow Image Uploads)** — owns the three `about_page_contents` slideshow inputs this spec wraps.
- **SPEC-013 (Home Page Hero and CTA Image Uploads) — PR #81, `feature/spec-013-home-hero-cta-image-uploads`, OPEN as of this spec's authoring, not yet merged to `main`.** This is a hard dependency for two of the six inputs and for the test infrastructure this spec's system tests reuse:
  - `hero_image`/`cta_image` and their surrounding view markup (R19, AC-4/AC-7, AT5/AT8) do not exist until PR #81 merges.
  - `admin.home_page_content.image_hint` and the rest of that view's SPEC-013-introduced i18n keys, which this spec's new `admin.home_page_content.*` keys sit alongside, are also introduced by that PR.
  - `spec/support/padded_image_uploads.rb` (the `padded_jpeg_upload(byte_size)` helper used by AT9/AT10 to build an oversized fixture at runtime without committing a large binary to the repo) is introduced by PR #81's commit `4a575f2`. This spec's test suite cannot run the boundary/oversized ATs until that file exists on whatever branch implements this spec — either because PR #81 has merged to `main`, or because this spec's branch is rebased onto it first.
  - PR #81 also raises `ImageAttachmentValidatable::MAX_IMAGE_SIZE` from 15 MB to 30 MB. This spec's mechanism (R15) reads that constant directly rather than a literal, so it is correct at either value and requires no change regardless of merge order.
- **ADR-005 (Photo Upload Data Model and Active Storage Strategy)** — governs `ImageAttachmentValidatable` as shared infrastructure; not re-derived here, only extended with two presentation-only members (R1).
- No new gems. No new routes. No database migration.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | `ImageAttachmentValidatable`: add `ALLOWED_IMAGE_EXTENSIONS`, `.accept_attribute_value`, and the R2 warning comment. | AC-1, AC-2, AC-19 | 1 |
| T2 | New `image_upload_guard_controller.js` implementing the full `validate()` contract (R5-R14). | AC-5, AC-6, AC-8 – AC-14 | 3 |
| T3 | Wire `accept` + the controller + message markup into the four existing inputs (About × 3, Gallery × 1); add their four new i18n keys. | AC-3, AC-5, AC-6, AC-10 – AC-16, AC-17, AC-18, AC-21 | 3 |
| T4 | Same wiring for `hero_image`/`cta_image` once PR #81 has merged (or this branch is rebased onto it); add the two `admin.home_page_content.*` keys. | AC-4, AC-7 | 2 |
| T5 | Concern spec for `accept_attribute_value`; request spec proving server-side rejection is unchanged when both guards are bypassed. | AC-19, AC-20 | 2 |
| T6 | System specs (Selenium headless) across all three admin forms: oversized/type rejection and messages, at-cap acceptance, unsaved-text-field preservation, re-selection recovery, 375px no-scroll. All AAA, inline variables, no `let`/`let!`. | AC-5 – AC-14, AC-21 | 3 |

Total estimated points: 14 (all tasks ≤ 3 points; no split-review flag required under the ≥5-point guardrail)

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-09-09 | Initial draft | All | Translates the repo owner's post-incident diagnosis (a 4 GB video absorbed and MD5-hashed in full by `ActiveStorage::Blob#unfurl` before being rejected) into two client-side, UX-only guards. Guard 1 restricts the file picker via a derived, drift-proof `accept` attribute (R1-R4). Guard 2 is a Stimulus controller that rejects oversized or wrong-type files at `change` time, before any submission, without disturbing any other field's state (R5-R14) — the mechanism that directly answers "what happens to unsaved text edits." Both guards bind to `ImageAttachmentValidatable`'s existing constants at render time rather than restating them (R15), and the new i18n copy interpolates the cap rather than hardcoding it (R16), so neither guard drifts the next time the cap changes. R18 restates, non-negotiably, that server-side validation is unchanged and remains sole authority. R19 records a real, discovered dependency: two of the six named inputs (`hero_image`/`cta_image`) do not yet exist on `main` — they are on open PR #81 (SPEC-013) — so this spec is implementable in full today for four of six inputs, with the remaining two following PR #81's merge. |

---

## Open Questions

None. The one point that needed resolving before this spec could be called implementation-ready — that two of the six named inputs don't exist yet on `main` — is not a question but a discovered fact, recorded in Dependencies and R19 rather than left open.
