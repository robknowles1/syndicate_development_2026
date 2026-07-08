# Spec: About Page Content Editing — Admin-Managed Shop Info and Bio Copy

**ID:** SPEC-007
**Status:** ready
**Priority:** medium
**Created:** 2026-07-07
**Author:** spec-agent

---

## Goal

Allow Doug to edit the shop heading, phone label and number, address label and text, bio heading and body, and the three slideshow image alt texts on the About page through the existing admin backend without developer involvement — mirroring the editing workflow already delivered for the home page in SPEC-006. Changes stay unpublished (the live site continues to render hardcoded i18n fallback copy) until Doug explicitly publishes them, so the About page can never be left blank or broken. This spec also closes a pre-existing gap: the shop phone number is currently a raw hardcoded literal (`"208-251-9536"`) embedded directly in the view's `tel:` link, not wired to i18n at all — this spec brings it in line with the single-source-of-truth pattern used by every other editable field.

---

## Non Goals

- Editing the "CONTACT THE SHOP" heading that titles the contact form box (`pages.about.contact_heading`) — stays hardcoded, same rationale as SPEC-006 excluding its CTA heading.
- Editing any contact form field labels, placeholders, or submit button text (`pages.about.form.*`) — untouched.
- Uploading or changing the 3 slideshow images themselves, or the hardcoded Google Maps URL — no upload/URL-editing capability exists or is being added; only the text adjacent to these (alt text, address display text) becomes editable.
- Rich-text / WYSIWYG editor for `bio_body` — plain textarea only.
- Per-field revision history or audit trail of content changes.
- Preview mode before publishing.
- Multiple draft versions or any staging distinction beyond the single `published` flag.
- Home, Gallery, or Services page content editing — already covered by SPEC-006 or separate specs.
- Changes to the nav partial, layout, or any shared partials other than the about view.
- Re-deriving architecture decisions already settled in ADR-004 (singleton read pattern, `published` as a column, restore-defaults reading i18n at request time). This spec reuses that pattern verbatim; no new ADR is produced.

---

## Definitions

| Term | Definition |
|------|-----------|
| `AboutPageContent` | Singleton ActiveRecord model holding the 10 editable About page fields plus a `published` flag. At most one row ever exists in the `about_page_contents` table. |
| singleton | A model for which exactly one row is used by the application. The application always reads and writes via `AboutPageContent.first_or_initialize`; a second row must never be created. |
| `published` flag | A boolean column on `AboutPageContent` (pattern decided in ADR-004) controlling whether the public About page renders DB values or i18n fallback copy. |
| fallback copy | The hardcoded strings in `config/locales/en.yml` under `pages.about.*`. Rendered when no `AboutPageContent` row exists or `published` is `false`. |
| `whitespace-pre-line` | Tailwind utility class mapping to `white-space: pre-line`, causing `\n` characters in a string to render as visible line breaks in the browser. |
| phone digits | The derived value used only for the `tel:` link `href`, computed at render time by stripping all non-digit characters from the resolved `shop_phone_number` value (`.gsub(/\D/, "")`). Never stored; always computed from whichever value (DB or i18n) is currently resolved. |

---

## Interfaces

### Public Frontend

- `GET /about` — `PagesController#about` loads `AboutPageContent.first` (may be nil) and passes it to the view. The view conditionally renders DB values or i18n fallback based on publish state.

### Admin

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/about_page_content | `Admin::AboutPageContentsController#show` — renders the content edit form |
| PATCH | /admin/about_page_content | `Admin::AboutPageContentsController#update` — persists content and/or publish state |
| PATCH | /admin/about_page_content/restore_defaults | `Admin::AboutPageContentsController#restore_defaults` — overwrites all 10 editable fields with current i18n values; does not touch `published`; redirects to edit form with flash notice |

Route declaration (added to the existing `namespace :admin` block, alongside `resource :home_page_content`):

```ruby
resource :about_page_content, only: [:show, :update] do
  patch :restore_defaults
end
```

Named route generated: `restore_defaults_admin_about_page_content_path`.

### Data Model

New table: `about_page_contents`

| Column | Type | Constraints |
|--------|------|-------------|
| `shop_heading` | string | not null |
| `shop_phone_label` | string | not null |
| `shop_phone_number` | string | not null |
| `shop_address_label` | string | not null |
| `shop_address` | string | not null |
| `bio_heading` | string | not null |
| `bio_body` | text | not null |
| `slideshow_alt_1` | string | not null |
| `slideshow_alt_2` | string | not null |
| `slideshow_alt_3` | string | not null |
| `published` | boolean | not null, default false |
| `created_at` | datetime | |
| `updated_at` | datetime | |

`published` is a boolean column on `AboutPageContent`, not a `SiteSetting` key, per ADR-004 (see Dependencies — this spec does not re-litigate that decision).

### Required i18n Keys

Add under `pages.about` in `config/locales/en.yml` (NEW keys; all other `pages.about.*` keys already exist):

| Key | Value | Purpose |
|-----|-------|---------|
| `shop_phone_number` | `"208-251-9536"` | Fallback/original phone number. Currently a hardcoded literal in the view (`app/views/pages/about.html.erb:50`); this spec moves it into i18n so it has a canonical source restore-defaults can read from. |
| `slideshow_alt_1` | `"Syndicate Development motorcycle 1"` | Alt text for the first slideshow image (replaces interpolated `slideshow_alt` for `n: 1`, preserving identical rendered output). |
| `slideshow_alt_2` | `"Syndicate Development motorcycle 2"` | Alt text for the second slideshow image. |
| `slideshow_alt_3` | `"Syndicate Development motorcycle 3"` | Alt text for the third slideshow image. |

The existing interpolated key `pages.about.slideshow_alt` (`"Syndicate Development motorcycle %{n}"`) is removed and replaced by the 3 discrete keys above.

Add under `admin.about_page_content` in `config/locales/en.yml`:

| Key | Purpose |
|-----|---------|
| `heading` | Admin page heading |
| `shop_heading_label` | Label for shop heading input |
| `shop_phone_label_label` | Label for the input editing the `shop_phone_label` field (the text "Shop Phone:") |
| `shop_phone_number_label` | Label for shop phone number input |
| `shop_phone_number_hint` | Hint explaining only digits are used to build the tap-to-call link; formatting punctuation is preserved as displayed text |
| `shop_address_label_label` | Label for the input editing the `shop_address_label` field (the text "Shop Address:") |
| `shop_address_value_label` | Label for the input editing the `shop_address` field (the address text itself) |
| `bio_heading_label` | Label for bio heading input |
| `bio_body_label` | Label for bio body textarea |
| `bio_body_hint` | Hint explaining that line breaks are preserved on the public page |
| `slideshow_alt_1_label` | Label for slideshow image 1 alt text input |
| `slideshow_alt_2_label` | Label for slideshow image 2 alt text input |
| `slideshow_alt_3_label` | Label for slideshow image 3 alt text input |
| `published_label` | Checkbox label; intended content: "About page content is published (visible to the public)" |
| `published_hint` | Help text below the published checkbox, mirroring `admin.home_page_content.published_hint` |
| `current_status_label` | Current status display label |
| `status_published` | Published state label |
| `status_unpublished` | Unpublished state label |
| `save` | Submit button text |
| `update_notice` | Success flash after save |
| `restore_defaults_label` | Text on the "Restore Original Copy" button |
| `confirm_restore_defaults` | Turbo confirmation dialog text shown before restore executes |
| `flash.restored` | Flash notice displayed after a successful restore |

Add under `admin.dashboard`: `about_page_link` — link text on the dashboard pointing to the About page content admin.

> **Naming note:** the `_label_label` keys are intentional, not a typo — see Implementation Decisions for the collision they disambiguate.

---

## Rules

R1: On `GET /about`, if `AboutPageContent.first` is nil or `.published?` is `false`, the About page renders `t("pages.about.*")` for all 10 editable fields: `shop_heading`, `shop_phone_label`, `shop_phone_number`, `shop_address_label`, `shop_address`, `bio_heading`, `bio_body`, `slideshow_alt_1`, `slideshow_alt_2`, `slideshow_alt_3`. `contact_heading` and all `form.*` strings always render from i18n regardless of publish state (out of scope, unchanged).

R2: On `GET /about`, if `AboutPageContent.first.published?` is `true`, the About page renders the model's values for the 10 fields listed in R1 in place of the i18n fallback.

R3: The public About page must never produce a blank or broken rendering. If `AboutPageContent.first` returns nil, `PagesController#about` must not raise. A nil result is treated as equivalent to unpublished (R1 behavior). No nil-unsafe access may exist in the view or controller.

R3a: `PagesController#about` must assign `@about_page_content = AboutPageContent.first` (which may be nil). The view must compute the effective content object ONCE at the point of first use — `content = @about_page_content&.published? ? @about_page_content : nil` — then derive all 10 field values from that single local (`content&.shop_heading || t("pages.about.shop_heading")`, etc.), matching the R3a pattern established in SPEC-006. View conditionals must use `published?`, not `== true`.

R4: The `tel:` link's `href` must derive from the resolved `shop_phone_number` value (DB or i18n, per R1/R2/R3a) by stripping all non-digit characters: `href="tel:#{phone_number.gsub(/\D/, "")}"`. The link's visible text is the resolved `shop_phone_number` value unmodified (formatting punctuation preserved as typed). This rule applies regardless of publish state — both the DB-sourced path and the i18n fallback path derive the `href` the same way from the same resolved string.

R5: The `<p>` element wrapping `bio_body` on the public About page must carry the Tailwind utility `whitespace-pre-line` so that `\n` characters render as visible line breaks. This applies regardless of publish state — both the DB value path and the i18n fallback path use it, matching the R9 precedent from SPEC-006's `mission_body`.

R6: `AboutPageContent` validates presence of all 10 editable fields: `validates :shop_heading, :shop_phone_label, :shop_phone_number, :shop_address_label, :shop_address, :bio_heading, :bio_body, :slideshow_alt_1, :slideshow_alt_2, :slideshow_alt_3, presence: true`. No maximum-length constraint is applied to any of these fields — see Implementation Decisions for why no cap analogous to SPEC-006's `hero_tagline` 50-character limit applies here.

R7: `AboutPageContent` validates `shop_phone_number` against the format `PHONE_NUMBER_FORMAT = /\A(?=.*\d)[0-9\s\-\+\.\(\)]+\z/` in addition to presence: `validates :shop_phone_number, presence: true, format: { with: PHONE_NUMBER_FORMAT }`. The regex permits digits, whitespace, hyphens, parentheses, periods, and a leading `+`, and requires (via the `(?=.*\d)` lookahead) that at least one digit is present — rejecting both letter-containing input and strings composed entirely of formatting punctuation with no digits. No custom `message:` is supplied; Rails' default format-validation message is used, consistent with the SPEC-006 precedent of not overriding default ActiveRecord validation messages.

R8: `AboutPageContent` is a singleton. The controller always reads and writes via `AboutPageContent.first_or_initialize`. The application must never create a second row. No DB-level unique constraint is required; the singleton contract is enforced by application code, matching R10 of SPEC-006.

R9: `db/seeds.rb` must create exactly one `AboutPageContent` row using `AboutPageContent.first_or_initialize` with initial values matching the current `pages.about.*` i18n copy: `shop_heading: "SYNDICATE DEVELOPMENT"`, `shop_phone_label: "Shop Phone:"`, `shop_phone_number: "208-251-9536"`, `shop_address_label: "Shop Address:"`, `shop_address: "1801 N. Arthur Ave., Pocatello, ID, 83204"`, `bio_heading: "About Doug Haskett"`, `bio_body: I18n.t("pages.about.bio_body")` (block-scalar body sourced via `I18n.t`, not duplicated as a literal — matching the `mission_body` precedent in SPEC-006's seeds), `slideshow_alt_1: "Syndicate Development motorcycle 1"`, `slideshow_alt_2: "Syndicate Development motorcycle 2"`, `slideshow_alt_3: "Syndicate Development motorcycle 3"`, `published: false`. If `first_or_initialize` returns an already-persisted record, no attribute values may be overwritten and `save!` must not be called — initial seed values apply ONLY when `new_record?` is `true`. Running seeds twice must not raise or produce a second row. Maintenance constraint (advisory): `db/seeds.rb`'s literal values must be kept in sync with `pages.about.*` in `config/locales/en.yml` — if those i18n values are ever updated, `db/seeds.rb` must be updated in the same change, since the `new_record?` guard means seeds.rb only applies literal values to a brand-new row.

R10: `GET /admin/about_page_content` renders a form pre-filled with the current `AboutPageContent` values (or blank if no row exists). The form includes labeled inputs for all 10 editable fields, a `published` checkbox with a hidden field sending `"false"` when unchecked, and a submit button. The form must not raise if no `AboutPageContent` row exists.

R11: `PATCH /admin/about_page_content` with valid params updates the `AboutPageContent` record (creating it if none exists via `first_or_initialize`) and redirects to `admin_about_page_content_path` with `flash[:notice]` containing `t("admin.about_page_content.update_notice")`.

R12: `PATCH /admin/about_page_content` with invalid params (failing any validation in R6–R7) re-renders the show template with HTTP 422 and displays the validation errors. No change is persisted.

R13: All admin-facing UI strings — field labels, hints, button text, flash messages, page headings — are rendered via `t()` from `config/locales/en.yml` under the `admin.about_page_content` namespace. No hardcoded English strings in `app/views/admin/about_page_contents/` or `Admin::AboutPageContentsController`.

R14: The admin dashboard view (`GET /admin`) must include a link to `admin_about_page_content_path` using `t("admin.dashboard.about_page_link")`.

R15: The admin About page content form follows the mobile-first design rules from CLAUDE.md: all text inputs and the `bio_body` textarea carry `w-full`; `bio_body` specifies `rows: 8` as a minimum (matching the `mission_body` precedent); the submit button carries at minimum `py-3` padding; no horizontal scroll occurs at any viewport width. The `published` checkbox must use the `<label class="flex items-center gap-3 cursor-pointer">` wrapper pattern from `app/views/admin/services_pages/show.html.erb` (lines 8–12) so the full label area is tappable on mobile. Class and structural patterns for text fields match `app/views/admin/home_page_contents/show.html.erb` (this spec's direct precedent) and `app/views/admin/service_sections/_form.html.erb`.

R16: The original copy has exactly one canonical location — the i18n keys `pages.about.shop_heading`, `shop_phone_label`, `shop_phone_number`, `shop_address_label`, `shop_address`, `bio_heading`, `bio_body`, `slideshow_alt_1`, `slideshow_alt_2`, `slideshow_alt_3` in `config/locales/en.yml`. Both the public unpublished-fallback path (R1) and the restore-defaults action (R17) read from these same keys at runtime. No second hardcoded copy of the original strings may exist anywhere in the codebase — not in a migration, not as controller constants, not as seed defaults beyond the initial `db/seeds.rb` seeded values (R9), and not embedded in view templates. This matches R18 of SPEC-006.

R17: `PATCH /admin/about_page_content/restore_defaults` reads the current values of `t("pages.about.*")` for all 10 fields at request time and persists them to the `AboutPageContent` row via `first_or_initialize`. The `published` flag must not be read or written by this action. On success the action redirects to `admin_about_page_content_path` with `flash[:notice]` set to `t("admin.about_page_content.flash.restored")`.

R18: The restore-defaults action (R17) always overwrites the 10 editable fields regardless of whether the `AboutPageContent` row already exists — an unconditional, intentional overwrite, distinct from R9's seed guard which explicitly does NOT overwrite an existing row. If no row exists, `first_or_initialize` creates one; if a row already exists with custom values, those values are overwritten. In both cases `published` remains unchanged.

R19: The "Restore Original Copy" button in the admin form must: (a) use a secondary/outline visual style clearly distinct from the primary Save button; (b) carry at minimum `py-3` padding; (c) use `data: { turbo_method: :patch, turbo_confirm: t("admin.about_page_content.confirm_restore_defaults") }`; (d) render its label via `t("admin.about_page_content.restore_defaults_label")` with no hardcoded English string. Matches R21 of SPEC-006.

R20: The 3 slideshow `<img>` tags in `app/views/pages/about.html.erb` map 1:1 in document order to `slideshow_alt_1`, `slideshow_alt_2`, `slideshow_alt_3`: the first `image_tag` (`gallery/m45a2920.jpg`) uses the resolved `slideshow_alt_1` value, the second (`gallery/m45a2927.jpg`) uses `slideshow_alt_2`, the third (`gallery/m45a2928.jpg`) uses `slideshow_alt_3`. The images themselves and their `src` values are unchanged — only per-image alt text becomes editable. Each follows the R3a single-content-local derivation pattern (`content&.slideshow_alt_1 || t("pages.about.slideshow_alt_1")`, etc.).

---

## Edge Cases

E1: `AboutPageContent.first` returns nil (fresh deployment, seeds not yet run). `PagesController#about` must not raise. The view treats nil as unpublished and renders i18n fallback for all 10 fields.

E2: `AboutPageContent` row exists with `published: false`. Public page renders i18n fallback — identical behavior to E1 from the visitor's perspective.

E3: `shop_phone_number` contains formatting punctuation, e.g. `"(208) 251-9536"`. The `tel:` `href` strips to digits only (`tel:2082519536`) while the visible link text remains `"(208) 251-9536"` unmodified.

E4: `shop_phone_number` submitted containing letters, e.g. `"call-us-now"`. `PHONE_NUMBER_FORMAT` rejects it (no digit-only-and-punctuation match). HTTP 422 re-renders the form with a format error.

E5: `shop_phone_number` submitted blank. Presence validation rejects it. HTTP 422 re-renders the form.

E6: `shop_phone_number` submitted as formatting characters only with no digit, e.g. `"----"`. The `(?=.*\d)` lookahead in `PHONE_NUMBER_FORMAT` rejects it even though every character is otherwise in the allowed set. HTTP 422 re-renders the form with a format error.

E7: `bio_body` submitted with embedded `\n` characters. On the public page these render as visible line breaks due to `whitespace-pre-line` (R5). The admin textarea preserves them in its value on re-render.

E8: i18n fallback path with `whitespace-pre-line`: `pages.about.bio_body` is a multi-line block-scalar string in `en.yml`. Once `whitespace-pre-line` is applied (R5), the fallback renders as multiple visual lines instead of collapsing to one continuous paragraph (current behavior, since no white-space CSS is applied today). This is an intentional behavior improvement QA must verify does not introduce unexpected whitespace.

E9: `bio_body` submitted as all-whitespace (e.g. `"   "`). Rails `presence: true` rejects this (`present?` returns `false` for blank strings after trimming). HTTP 422 re-renders the form.

E10: `PATCH /admin/about_page_content/restore_defaults` is called when no `AboutPageContent` row exists. The action calls `first_or_initialize`, sets all 10 fields to i18n values, and saves. `published` defaults to `false` for the newly created row. The action must not raise and must redirect normally.

E11: Any one of `slideshow_alt_1`, `slideshow_alt_2`, `slideshow_alt_3` submitted blank independently. Presence validation rejects the update. HTTP 422 re-renders the form; the other two slideshow alt fields' presence is unaffected by the failing one.

---

## Acceptance Criteria

### Public Page Behavior

AC-1: Given `AboutPageContent` has no row, when `GET /about`, then HTTP 200 and the response body includes the literal text of `t("pages.about.*")` for all 10 editable fields.

AC-2: Given `AboutPageContent` exists with `published: false`, when `GET /about`, then HTTP 200 and the response body includes the i18n fallback values for all 10 editable fields.

AC-3: Given `AboutPageContent` exists with `published: true` and custom values for all 10 editable fields, when `GET /about`, then HTTP 200 and the response body includes all 10 custom values.

AC-4: Given any publish state, when `GET /about`, then the `tel:` link's `href` attribute equals `tel:` followed by only the digit characters of the resolved `shop_phone_number` value, and the link's visible text equals the resolved `shop_phone_number` value unmodified.

AC-5: Given `AboutPageContent` exists with `published: true` and `bio_body` containing `\n` characters, when `GET /about`, then the `<p>` element wrapping the bio body carries `whitespace-pre-line` (or equivalent `style="white-space: pre-line"`).

AC-6: Given no `AboutPageContent` row (i18n fallback path), when `GET /about`, then the `<p>` element wrapping the bio body still carries `whitespace-pre-line` styling.

AC-7: Given any publish state, when `GET /about`, then the 3 `<img>` tags' `alt` attributes, in document order, equal the resolved values of `slideshow_alt_1`, `slideshow_alt_2`, and `slideshow_alt_3` respectively.

### Admin Behavior

AC-8: Given admin is logged in, when `GET /admin/about_page_content`, then HTTP 200 and the form renders inputs with name attributes for `about_page_content[shop_heading]`, `[shop_phone_label]`, `[shop_phone_number]`, `[shop_address_label]`, `[shop_address]`, `[bio_heading]`, `[bio_body]`, `[slideshow_alt_1]`, `[slideshow_alt_2]`, `[slideshow_alt_3]`, and `[published]`.

AC-9: Given `AboutPageContent` exists with `shop_heading: "Custom Shop Name"`, when admin visits `GET /admin/about_page_content`, then the `shop_heading` input is pre-filled with "Custom Shop Name".

AC-10: Given no `AboutPageContent` row exists, when admin visits `GET /admin/about_page_content`, then the form renders without error.

AC-11: Given admin is logged in, when `PATCH /admin/about_page_content` with valid params, then the record is updated and the response redirects to `admin_about_page_content_path` with a `flash[:notice]`.

AC-12: Given admin is logged in, when `PATCH /admin/about_page_content` with `shop_heading: ""`, then HTTP 422, the form re-renders with a presence validation error, and no field is changed.

AC-13: Given admin is logged in, when `PATCH /admin/about_page_content` with `shop_phone_number: "call-us-now"`, then HTTP 422, the form re-renders with a format validation error, and no field is changed.

AC-14: Given admin is logged in, when `PATCH /admin/about_page_content` with `shop_phone_number: ""`, then HTTP 422, the form re-renders with a presence validation error.

AC-15: Given admin is logged in, when `PATCH /admin/about_page_content` with `bio_body: ""`, then HTTP 422, the form re-renders with a presence validation error.

AC-16: Given admin is logged in, when `PATCH /admin/about_page_content` with `slideshow_alt_1: ""`, then HTTP 422, the form re-renders with a presence validation error.

AC-17: Given admin is logged in, when `PATCH /admin/about_page_content` with `published: "true"`, then `AboutPageContent.first.published` is `true` after the request.

AC-18: Given admin is logged in, when `PATCH /admin/about_page_content` with `published: "false"`, then `AboutPageContent.first.published` is `false` after the request.

AC-19: `GET /admin` returns HTTP 200 and the response body includes an `href` matching `admin_about_page_content_path`.

AC-20: No hardcoded English strings appear in `app/views/admin/about_page_contents/` or `Admin::AboutPageContentsController`. All user-facing strings use `t()`.

AC-21: The admin About page content form renders without horizontal scroll at 375 px viewport width. All text inputs and the `bio_body` textarea carry `w-full`. The submit button carries at minimum `py-3` padding.

### Data Model and Migration

AC-22: A migration creates the `about_page_contents` table with columns and constraints matching the Data Model table in the Interfaces section. Running the migration on a fresh database succeeds without error.

AC-23: `db/seeds.rb` uses `AboutPageContent.first_or_initialize` to create exactly one row with the current i18n copy (R9 values) and `published: false`. Running seeds twice produces no error and no second `AboutPageContent` row.

### Restore Defaults

AC-24: Given admin is authenticated and no `AboutPageContent` row exists, when `PATCH /admin/about_page_content/restore_defaults`, then exactly one `AboutPageContent` row is created, all 10 fields equal the current `pages.about.*` i18n values, `published` is `false`, and the response redirects to `admin_about_page_content_path` with `flash[:notice]`.

AC-25: Given admin is authenticated and `AboutPageContent` exists with a custom `shop_heading` and `published: true`, when `PATCH /admin/about_page_content/restore_defaults`, then `AboutPageContent.first.shop_heading` equals `t("pages.about.shop_heading")` (not the custom value), `published` remains `true` (unchanged), and the response redirects with `flash[:notice]`.

AC-26: Given a request is NOT authenticated, when `PATCH /admin/about_page_content/restore_defaults`, then the response is a redirect (auth guard). No `AboutPageContent` data is changed.

AC-27: The admin form rendered by `GET /admin/about_page_content` includes a "Restore Original Copy" button that: (a) targets `restore_defaults_admin_about_page_content_path` with HTTP method PATCH; (b) carries a `data-turbo-confirm` attribute; (c) has a visual class indicating secondary/outline styling; (d) carries at minimum `py-3` in its class attribute.

---

## Acceptance Tests

AT1
Given no `AboutPageContent` row exists
When `GET /about`
Then HTTP 200 and the response body includes `t("pages.about.shop_heading")`
Covers: R1, R3, E1, AC-1

AT2
Given `AboutPageContent` exists with `published: false`
When `GET /about`
Then HTTP 200 and the response body includes `t("pages.about.bio_heading")`
Covers: R1, E2, AC-2

AT3
Given `AboutPageContent` exists with `published: true` and custom values for all 10 fields
When `GET /about`
Then the response body includes all 10 custom values
Covers: R2, R3a, AC-3

AT4
Given `AboutPageContent` exists with `published: true` and `shop_phone_number: "(208) 555-1234"`
When `GET /about`
Then the response body includes `href="tel:2085551234"` and the visible text "(208) 555-1234"
Covers: R4, AC-4, E3

AT5
Given no `AboutPageContent` row (i18n fallback)
When `GET /about`
Then the response body includes `href="tel:2082519536"` and the visible text "208-251-9536"
Covers: R4, AC-4

AT6
Given `AboutPageContent` exists with `published: true` and `bio_body: "First.\nSecond."`
When `GET /about`
Then the `<p>` element wrapping the bio body carries `whitespace-pre-line` or `style="white-space: pre-line"`
Covers: R5, AC-5, E7

AT7
Given no `AboutPageContent` row (i18n fallback)
When `GET /about`
Then the `<p>` element wrapping the bio body carries `whitespace-pre-line` styling
Covers: R5, AC-6, E8

AT8
Given `AboutPageContent` exists with `published: true` and custom `slideshow_alt_1`, `slideshow_alt_2`, `slideshow_alt_3`
When `GET /about`
Then the 3 `<img>` tags' `alt` attributes, in document order, equal the 3 custom values respectively
Covers: R20, AC-7

AT9
Given no `AboutPageContent` row (i18n fallback)
When `GET /about`
Then the 3 `<img>` tags' `alt` attributes, in document order, equal `t("pages.about.slideshow_alt_1")`, `t("pages.about.slideshow_alt_2")`, `t("pages.about.slideshow_alt_3")` respectively
Covers: R20, AC-7

AT10
Given admin is authenticated
When `GET /admin/about_page_content`
Then HTTP 200 and the response body contains input name attributes for all 10 `about_page_content[...]` fields and `about_page_content[published]`
Covers: R10, AC-8

AT11
Given `AboutPageContent` exists with `shop_heading: "Custom Shop Name"`
When admin sends `GET /admin/about_page_content`
Then the response body includes `value="Custom Shop Name"` in the shop heading input
Covers: R10, AC-9

AT12
Given no `AboutPageContent` row exists
When admin sends `GET /admin/about_page_content`
Then the response renders without a `NoMethodError` or nil-related exception
Covers: R10, AC-10

AT13
Given admin is authenticated
When `PATCH /admin/about_page_content` with valid params for all 10 fields and `published: "true"`
Then the record is updated, `AboutPageContent.first.published` is `true`, and the response redirects to `admin_about_page_content_path` with `flash[:notice]`
Covers: R11, AC-11, AC-17

AT14
Given admin is authenticated
When `PATCH /admin/about_page_content` with `shop_heading: ""`
Then HTTP 422, `AboutPageContent.first&.shop_heading` is unchanged, and the response body includes a presence validation error
Covers: R6, R12, AC-12

AT15
Given admin is authenticated
When `PATCH /admin/about_page_content` with `shop_phone_number: "call-us-now"`
Then HTTP 422, no field is changed, and the response body includes a format validation error
Covers: R7, R12, AC-13, E4

AT16
Given admin is authenticated
When `PATCH /admin/about_page_content` with `shop_phone_number: ""`
Then HTTP 422 and the response body includes a presence validation error
Covers: R6, R12, AC-14, E5

AT17
Given admin is authenticated
When `PATCH /admin/about_page_content` with `shop_phone_number: "----"`
Then HTTP 422 and the response body includes a format validation error
Covers: R7, E6

AT18
Given admin is authenticated
When `PATCH /admin/about_page_content` with `bio_body: ""`
Then HTTP 422 and the response body includes a presence validation error
Covers: R6, R12, AC-15, E9

AT19
Given admin is authenticated
When `PATCH /admin/about_page_content` with `slideshow_alt_1: ""`
Then HTTP 422 and the response body includes a presence validation error
Covers: R6, R12, AC-16, E11

AT20
Given admin is authenticated
When `PATCH /admin/about_page_content` with `published: "false"`
Then `AboutPageContent.first.published` is `false` after the request
Covers: R11, AC-18

AT21
Given admin is authenticated
When `GET /admin`
Then the response body includes an `href` matching `admin_about_page_content_path`
Covers: R14, AC-19

AT22
Given `db/seeds.rb` is run on a clean database
When `AboutPageContent.all` is queried
Then exactly one row exists with `shop_heading: "SYNDICATE DEVELOPMENT"`, `shop_phone_number: "208-251-9536"`, `slideshow_alt_1: "Syndicate Development motorcycle 1"`, and `published: false`
Covers: R9, AC-23

AT23
Given `db/seeds.rb` is run twice on the same database
When `AboutPageContent.count` is queried
Then it equals 1
Covers: R8, R9, AC-23

AT24
Given admin is authenticated and no `AboutPageContent` row exists
When `PATCH /admin/about_page_content/restore_defaults`
Then exactly one `AboutPageContent` row exists; all 10 fields equal their `I18n.t("pages.about.*")` values; `published` is `false`; and the response redirects to `admin_about_page_content_path` with `flash[:notice]` present
Covers: R16, R17, R18, E10, AC-24

AT25
Given admin is authenticated and `AboutPageContent` exists with a custom `shop_heading` and `published: true`
When `PATCH /admin/about_page_content/restore_defaults`
Then `AboutPageContent.first.shop_heading` equals `I18n.t("pages.about.shop_heading")` (not the custom value); `published` is `true` (unchanged); and the response redirects with `flash[:notice]` present
Covers: R17, R18, AC-25

AT26
Given no active admin session (unauthenticated)
When `PATCH /admin/about_page_content/restore_defaults`
Then the response redirects (auth guard) and `AboutPageContent.count` is unchanged
Covers: R17, AC-26

AT27
Given admin is authenticated
When `GET /admin/about_page_content`
Then the response body includes (a) an element targeting `restore_defaults_admin_about_page_content_path` with method `patch`; (b) a `data-turbo-confirm` attribute on that element; (c) a `py-3` class on that element
Covers: R19, AC-27

AT28
Given `app/views/admin/about_page_contents/` and `Admin::AboutPageContentsController` source
When inspected for hardcoded English string literals in user-facing output
Then none are found; all user-facing strings are rendered via `t()`
Covers: R13, AC-20

AT29
Given admin is authenticated
When `GET /admin/about_page_content` is rendered at a 375 px viewport width (system spec)
Then no horizontal scroll occurs, all text inputs and the `bio_body` textarea carry `w-full`, and the submit button carries `py-3`
Covers: R15, AC-21

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-07 | Reuse ADR-004's singleton + column-`published` pattern verbatim for `AboutPageContent`; no new ADR produced | ADR-004 explicitly anticipated this: "this site will likely need per-page content editing for About and Contact in future specs." The four architectural questions ADR-004 resolved (dedicated table vs. SiteSetting KV, `published` as column vs. separate setting) apply identically here — About's 10 fields are typed, individually validated content, not configuration flags. Re-deriving the decision would be redundant. |
| 2026-07-07 | No length cap on any of the 10 editable fields | SPEC-006's 50-char `hero_tagline` cap was empirically derived from a measured CSS line-wrap constraint (the tagline sits in a `md:truncate` hero banner). None of the About page's editable fields carry an analogous single-line CSS constraint today — `shop_heading`, `bio_heading`, and the phone/address text all render inside a plain `max-w-4xl mx-auto` container with normal wrapping. Inventing a cap without a measured layout constraint would be arbitrary, so none is imposed. |
| 2026-07-07 | `shop_phone_number` format regex: `/\A(?=.*\d)[0-9\s\-\+\.\(\)]+\z/` | Must guarantee at least one digit is present (so the derived `tel:` href is never empty) while allowing any conventional phone punctuation (spaces, hyphens, parentheses, dots, a leading `+`) so Doug isn't forced into one exact format. The `(?=.*\d)` lookahead rejects pure-formatting strings like `"----"` that would otherwise pass a naive character-class-only check. |
| 2026-07-07 | `shop_phone_number` moved from a hardcoded view literal into an i18n fallback key, not just a DB field | Restore-defaults (R17) requires a canonical i18n source to restore from, per the same single-source-of-truth rule (R16) SPEC-006 established as R18. Making it DB-editable without also giving it an i18n fallback would mean "restore to original" has no original to restore to. |
| 2026-07-07 | `slideshow_alt` interpolated key (`"...motorcycle %{n}"`) split into 3 discrete keys `slideshow_alt_1/2/3` | An interpolated `%{n}` field is not something an admin can sensibly edit as three independent texts through one form input. Splitting into 3 discrete i18n keys and 3 discrete model columns lets each slideshow image's alt text be edited independently, while the initial seeded/fallback values reproduce the exact strings the interpolation previously produced ("Syndicate Development motorcycle 1/2/3"), so there is no visible behavior change until an admin edits one. |
| 2026-07-07 | Admin i18n keys `shop_phone_label_label`, `shop_address_label_label`, `shop_address_value_label` | Two of the ten content fields (`shop_phone_label`, `shop_address_label`) already end in `_label` as part of their own field name. Applying SPEC-006's `<field>_label` convention naively to `shop_address` would produce the key `shop_address_label` — character-for-character identical to the unrelated content field name `shop_address_label`. Renamed to `shop_address_value_label` to disambiguate, per naming.md §1.1 (descriptive, unambiguous names). The two `_label_label` keys are visually redundant but unambiguous, and are documented here to preempt confusion during implementation. |
| 2026-07-07 | `resource :about_page_content, only: [:show, :update]` — no new/create/destroy | Matches SPEC-006's `home_page_content` route precedent exactly. The singleton row is created on first update or first restore via `first_or_initialize`; no separate create action is needed. No destroy: deleting About page content would leave the public page on i18n fallback, which is already the unpublished state. |

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. Layout, nav, Tailwind, and asset pipeline are in place.
- SPEC-003 (i18n String Extraction) — done. All new admin UI strings follow the `t()` / `en.yml` pattern.
- SPEC-004 (Admin Backend) — done. `Admin::BaseController`, auth session management, and admin layout are live.
- SPEC-006 (Home Page Content Editing) — done. This spec is a direct structural mirror: `AboutPageContent` mirrors `HomePageContent`, `Admin::AboutPageContentsController` mirrors `Admin::HomePageContentsController`, and `app/views/admin/about_page_contents/show.html.erb` mirrors `app/views/admin/home_page_contents/show.html.erb`.
- ADR-004 (Singleton Content Model and Publish Flag Placement) — the architecture decisions in this spec (singleton model, `published` as a column, restore-defaults reading i18n at request time) are governed by ADR-004 and are not re-derived here.
- No new gems required. This spec uses only existing Rails, Tailwind, and importmap infrastructure.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Migration: create `about_page_contents` table with all columns and constraints per the data model. Create `AboutPageContent` model with presence validations (R6), `shop_phone_number` format validation (R7), and singleton read pattern (R8). Update `db/seeds.rb` with an idempotent seed row (R9). Add FactoryBot factory. Add new `pages.about.shop_phone_number`, `slideshow_alt_1/2/3` i18n keys and remove the old interpolated `slideshow_alt` key. | AC-22, AC-23 | 3 |
| T2 | Public page update: update `PagesController#about` to load `AboutPageContent.first` (R3); update `app/views/pages/about.html.erb` to conditionally render DB vs. i18n for all 10 fields (R1, R2, R3a) using a single `content` local; derive the `tel:` href from stripped phone digits (R4); apply `whitespace-pre-line` to the bio body `<p>` (R5); map the 3 slideshow `<img>` alt attributes to `slideshow_alt_1/2/3` in document order (R20). | AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 | 4 |
| T3 | Admin controller and routes: add `resource :about_page_content, only: [:show, :update] do patch :restore_defaults end` to `config/routes.rb`; create `Admin::AboutPageContentsController` with `restore_defaults`, `show`, `update` actions (alphabetical order per `.claude/standards/practices/architecture.md §1.8`); add all required i18n keys under `admin.about_page_content` and `admin.dashboard.about_page_link` (R13, R14, R16, R17); update dashboard view link (R14). `restore_defaults` reads `I18n.t("pages.about.*")` — the same keys used by the public fallback path — and defines no second copy of the original strings (R16). | AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-17, AC-18, AC-19, AC-20, AC-24, AC-25, AC-26 | 4 |
| T4 | Admin view: create `app/views/admin/about_page_contents/show.html.erb` mirroring `app/views/admin/home_page_contents/show.html.erb` structurally — labeled inputs for all 10 fields, `shop_phone_number_hint` explaining the tel-link digit derivation, `bio_body` textarea with `rows: 8`, a `published` checkbox using the `<label class="flex items-center gap-3 cursor-pointer">` wrapper pattern, and a secondary/outline "Restore Original Copy" button with `turbo_method`/`turbo_confirm` (R10, R15, R19). | AC-8, AC-9, AC-10, AC-21, AC-27 | 3 |
| T5 | Tests: `AboutPageContent` model spec (presence validations, `shop_phone_number` format validation incl. E4/E6 boundary cases, singleton `first_or_initialize`, `published` default); request spec for `PagesController#about` (no row → fallback, unpublished → fallback, published → DB values, tel href digit derivation, slideshow alt mapping). All AAA pattern, inline variables, no `let`/`let!`. | AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7 | 3 |
| T6 | Tests: request spec for `Admin::AboutPageContentsController` (auth guard on show/update/restore_defaults; show pre-fills and handles no-row case; update happy path; update validation failures for presence and format; restore_defaults when no row; restore_defaults overwrites fields but leaves `published` unchanged). | AC-8, AC-9, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-17, AC-18, AC-19, AC-20, AC-24, AC-25, AC-26 | 4 |
| T7 | Tests: system spec for admin form at 375 px viewport (AC-21, AC-27); i18n hardcoded-string audit of `app/views/admin/about_page_contents/` and `Admin::AboutPageContentsController` (AC-20). Update `db/seeds.rb` idempotency test (seeds run twice → count 1). | AC-20, AC-21, AC-22, AC-23, AC-27 | 2 |

Total estimated points: 23 (all tasks ≤ 4 points; no split review required under the ≥ 5-point guardrail)

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-07-07 | Initial draft | All | New spec — mirrors SPEC-006's pattern per ADR-004, per explicit developer scope confirmation (fields in/out of scope, phone number i18n gap, slideshow alt split). |
