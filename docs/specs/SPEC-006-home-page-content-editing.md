# Spec: Home Page Content Editing — Admin-Managed Hero and Mission Copy

**ID:** SPEC-006
**Status:** ready
**Priority:** medium
**Created:** 2026-07-07
**Author:** spec-agent

---

## Goal

Allow Doug to edit the hero tagline, mission heading, mission subheading, and mission body through the existing admin backend without developer involvement. Changes stay unpublished (the live site continues to render hardcoded i18n fallback copy) until Doug explicitly publishes them, so the home page can never be left blank or broken.

---

## Non Goals

- Editing the hero heading ("SYNDICATE DEVELOPMENT") — stays hardcoded in i18n.
- Editing the CTA section heading ("READY TO START BUILDING?") — stays hardcoded in i18n.
- Editing the gallery CTA button text ("PROJECT GALLERY") or the contact CTA button text ("CONTACT THE SHOP") — both stay hardcoded in i18n.
- Rich-text / WYSIWYG editor for `mission_body` — plain textarea only.
- Per-field revision history or audit trail of content changes.
- Preview mode before publishing (the admin form shows current stored copy; no separate preview page).
- Multiple draft versions or any staging distinction beyond the single `published` flag.
- Gallery, About, or Contact page content editing.
- Changes to the nav partial, layout, or any shared partials other than the home view.

---

## Definitions

| Term | Definition |
|------|-----------|
| `HomePageContent` | Singleton ActiveRecord model holding the 4 editable home page fields plus a `published` flag. At most one row ever exists in the `home_page_contents` table. |
| singleton | A model for which exactly one row is used by the application. The application always reads and writes via `HomePageContent.first_or_initialize`; a second row must never be created. |
| `published` flag | A boolean column on `HomePageContent` (decided in ADR-004) controlling whether the public home page renders DB values or i18n fallback copy. |
| fallback copy | The hardcoded strings in `config/locales/en.yml` under `pages.home.*`. Rendered when no `HomePageContent` row exists or `published` is `false`. |
| `whitespace-pre-line` | Tailwind utility class that maps to `white-space: pre-line`, causing `\n` characters in a string to render as visible line breaks in the browser. |

---

## Interfaces

### Public Frontend

- `GET /` — `PagesController#home` loads `HomePageContent.first` (may be nil) and passes it to the view. The view conditionally renders DB values or i18n fallback based on publish state.

### Admin

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/home_page_content | `Admin::HomePageContentsController#show` — renders the content edit form |
| PATCH | /admin/home_page_content | `Admin::HomePageContentsController#update` — persists content and/or publish state |
| PATCH | /admin/home_page_content/restore_defaults | `Admin::HomePageContentsController#restore_defaults` — overwrites all 4 editable fields with current i18n values; does not touch `published`; redirects to edit form with flash notice |

Route declaration (to be added to the existing `namespace :admin` block):

```ruby
resource :home_page_content, only: [:show, :update] do
  patch :restore_defaults
end
```

Named route generated: `restore_defaults_admin_home_page_content_path`.

### Data Model

New table: `home_page_contents`

| Column | Type | Constraints |
|--------|------|-------------|
| `hero_tagline` | string | not null |
| `mission_heading` | string | not null |
| `mission_subheading` | string | not null |
| `mission_body` | text | not null |
| `published` | boolean | not null, default false |
| `created_at` | datetime | |
| `updated_at` | datetime | |

> **OQ1 — Resolved by ADR-004:** `published` lives as a boolean column on `HomePageContent`. See `docs/architecture/ADR-004-singleton-content-model-and-publish-flag-placement.md` for full rationale.

### Required i18n Keys

Add under `admin.home_page_content` in `config/locales/en.yml`:

| Key | Purpose |
|-----|---------|
| `heading` | Admin page heading |
| `hero_tagline_label` | Label for hero tagline input |
| `hero_tagline_hint` | Permanently visible hint beneath the hero tagline input; must state "Maximum 50 characters" (or equivalent clear wording) so Doug can self-count on mobile before saving |
| `mission_heading_label` | Label for mission heading input |
| `mission_subheading_label` | Label for mission subheading input |
| `mission_body_label` | Label for mission body textarea |
| `mission_body_hint` | Hint explaining that line breaks are preserved on the public page |
| `published_label` | Checkbox label; intended content: "Home page content is published (visible to the public)" — not bare "Published". Rationale: when unchecked, the public page does NOT go blank; it falls back to default i18n copy. Doug needs the label to make this clear so he understands what unpublished actually means. |
| `published_hint` | Help text below the published checkbox; e.g. "When unchecked, your saved changes are hidden — visitors see the original default text, not a blank page" |
| `current_status_label` | Current status display label; e.g. "Current status:" |
| `status_published` | Published state label; e.g. "Published" |
| `status_unpublished` | Unpublished state label; e.g. "Unpublished" |
| `save` | Submit button text |
| `update_notice` | Success flash after save |
| `restore_defaults_label` | Text on the "Restore Original Copy" button in the edit form |
| `confirm_restore_defaults` | Turbo confirmation dialog text shown before the restore executes; e.g. "This will replace your current edits with the original default text. Continue?" |
| `flash.restored` | Flash notice displayed after a successful restore; e.g. "Home page content has been restored to the original defaults." |

Add under `admin.dashboard`: `home_page_link` — link text on the dashboard pointing to the home page content admin.

---

## Rules

R1: On `GET /`, if `HomePageContent.first` is nil or `HomePageContent.first.published` is `false`, the home page renders `t("pages.home.hero_tagline")`, `t("pages.home.mission_heading")`, `t("pages.home.mission_subheading")`, and `t("pages.home.mission_body")` for the 4 editable fields. All other copy (hero heading, CTA heading, both CTA button texts) always renders from i18n regardless of publish state.

R2: On `GET /`, if `HomePageContent.first.published` is `true`, the home page renders the model's `hero_tagline`, `mission_heading`, `mission_subheading`, and `mission_body` values in place of the i18n fallback for those 4 fields only.

R3: The public home page must never produce a blank or broken rendering. If `HomePageContent.first` returns nil, `PagesController#home` must not raise. A nil result is treated as equivalent to unpublished (R1 behavior). No nil-unsafe access may exist in the view or controller.

R3a: `PagesController#home` must assign `@home_page_content = HomePageContent.first` (which may be nil). The view must compute the effective content object ONCE at the point of first use — e.g. `content = @home_page_content&.published? ? @home_page_content : nil` — then derive all four field values from that single local (`content&.hero_tagline || t("pages.home.hero_tagline")`, etc.). The view must not repeat `@home_page_content&.published?` as four independent checks scattered across the hero and mission sections. View conditionals must use `published?` (the boolean predicate method generated by ActiveRecord), not `== true`.

R4: The hero heading `<h1>` (always `t("pages.home.hero_heading")`) must have `md:whitespace-nowrap` added to its existing CSS class list, forcing a single line at the `md:` breakpoint (≥ 768 px) while the existing `break-words` class continues to allow wrapping on mobile (< 768 px). This is a CSS-only change; the text is not editable.

R5: The hero tagline `<p>` must have `md:truncate` added to its existing CSS class list, forcing a single line at ≥ 768 px (`md:truncate` expands to `overflow-hidden text-ellipsis whitespace-nowrap`). For any valid ≤ 50-character content this renders identically to bare `md:whitespace-nowrap`, but if the model-level validation is ever bypassed via a direct DB edit, the text clips visually with an ellipsis rather than silently overflowing into the CTA link below. The constraint applies whether the tagline renders from i18n or from the DB. See ADR-004 for full rationale. Screen readers read the full underlying DOM text regardless of visual `overflow: hidden` / `text-overflow: ellipsis` clipping, so no `aria-label` or `title` attribute is required for accessibility.

R6: `HomePageContent` validates `hero_tagline` for presence and a 50-character limit: `validates :hero_tagline, presence: true, length: { maximum: 50 }`. Rails' `length: { maximum: 50 }` counts Unicode characters (not bytes), matching the hint text's "Maximum 50 characters" phrasing and removing ambiguity for QA.

R7: `HomePageContent` validates `mission_heading` and `mission_subheading` for presence: `validates :mission_heading, :mission_subheading, presence: true`. No maximum-length constraint is applied to these fields.

R8: `HomePageContent` validates `mission_body` for presence: `validates :mission_body, presence: true`. No maximum-length constraint is applied. `mission_body` stores plain text; no rich-text editor is used.

R9: The `<p>` element wrapping the mission body on the public home page must carry the Tailwind utility `whitespace-pre-line` so that `\n` characters in the stored or i18n string render as visible line breaks. This CSS applies regardless of publish state — both the DB value path and the i18n fallback path must use it. This changes existing behavior: the current `pages.home.mission_body` block-scalar string, which collapses to a single continuous paragraph today (no white-space CSS is currently applied), will render as 4 separate visual lines once R9 is implemented.

R10: `HomePageContent` is a singleton. The controller always reads and writes via `HomePageContent.first_or_initialize`. The application must never create a second row. No DB-level unique constraint is required on a surrogate column; the singleton contract is enforced by application code.

R11: `db/seeds.rb` must create exactly one `HomePageContent` row using `HomePageContent.first_or_initialize` with the following initial values: `hero_tagline: "Performance, Passion, Precision."`, `mission_heading: "DREAM IT. BUILD IT. RIDE IT. LOVE IT."`, `mission_subheading: "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES"`, `mission_body:` (the exact 4-line block-scalar string from `pages.home.mission_body` in `en.yml`), `published: false`. If `first_or_initialize` returns an already-persisted record (`new_record?` is `false`), no attribute values may be overwritten and `save!` must not be called — initial seed values are applied ONLY when creating the first row (`new_record?` is `true`). Running seeds twice must not raise or produce a second row. (See ADR-004 implementation note 3.) Maintenance constraint (advisory): `db/seeds.rb` must be kept in sync with the canonical i18n defaults in `config/locales/en.yml` under `pages.home.*` — if those i18n values are ever updated, `db/seeds.rb`'s literal strings must be updated to match in the same change, since seeds.rb only applies its literal values to a brand-new row (the `new_record?` guard above) and will otherwise silently seed stale copy on any fresh environment created after the i18n update.

R12: `GET /admin/home_page_content` renders a form pre-filled with the current `HomePageContent` values (or i18n defaults / blank if no row exists). The form includes labeled inputs for all 4 editable fields, a `published` checkbox with hidden field to send `"false"` when unchecked, and a submit button. The form must not raise if no `HomePageContent` row exists.

R13: `PATCH /admin/home_page_content` with valid params updates the `HomePageContent` record (creating it if none exists via `first_or_initialize`) and redirects to `admin_home_page_content_path` with `flash[:notice]` containing `t("admin.home_page_content.update_notice")`.

R14: `PATCH /admin/home_page_content` with invalid params (failing any validation in R6–R8) re-renders the show template with HTTP 422 and displays the validation errors. No change is persisted.

R15: All admin-facing UI strings — field labels, hints, button text, flash messages, page headings — are rendered via `t()` from `config/locales/en.yml` under the `admin.home_page_content` namespace. No hardcoded English strings in `app/views/admin/home_page_contents/` or `Admin::HomePageContentsController`.

R16: The admin dashboard view (`GET /admin`) must include a link to `admin_home_page_content_path` using `t("admin.dashboard.home_page_link")`.

R17: The admin home page content form follows the mobile-first design rules from CLAUDE.md: all text inputs and the textarea carry `w-full`; the `mission_body` textarea specifies `rows: 8` as a minimum (the default `rows: 4` is too short for a 4-line field and forces inner scrolling while editing on mobile); the submit button carries at minimum `py-3` padding; no horizontal scroll occurs at any viewport width. The `hero_tagline_hint` text must be permanently visible beneath the `hero_tagline` input (not only shown after a validation error) and must explicitly state the maximum character count (e.g. "Maximum 50 characters"). The `published` checkbox must use the `<label class="flex items-center gap-3 cursor-pointer">` wrapper pattern from `app/views/admin/services_pages/show.html.erb` (lines ~8–12) so that the full label area is tappable on mobile, not just the small checkbox square. Class and structural patterns for all other fields match `app/views/admin/service_sections/_form.html.erb`.

R18: The original copy has exactly one canonical location — the i18n keys `pages.home.hero_tagline`, `pages.home.mission_heading`, `pages.home.mission_subheading`, and `pages.home.mission_body` in `config/locales/en.yml`. Both the public unpublished-fallback path (R1) and the restore-defaults action (R19) read from these same keys at runtime. No second hardcoded copy of the original strings may exist anywhere in the codebase — not in a migration, not as controller constants, not as seed defaults beyond the initial `db/seeds.rb` seeded values, and not embedded in view templates. This ensures there is never a risk of "the original" drifting into two different versions.

R19: `PATCH /admin/home_page_content/restore_defaults` reads the current values of `t("pages.home.hero_tagline")`, `t("pages.home.mission_heading")`, `t("pages.home.mission_subheading")`, and `t("pages.home.mission_body")` at request time and persists them to the `HomePageContent` row via `first_or_initialize`. The `published` flag must not be read or written by this action — restoring content is an explicitly separate decision from whether that content is visible to the public, and the two must not be coupled. On success the action redirects to `admin_home_page_content_path` with `flash[:notice]` set to `t("admin.home_page_content.flash.restored")`.

R20: The restore-defaults action (R19) always overwrites the 4 editable fields regardless of whether the `HomePageContent` row already exists. This is the opposite intent from the seed guard in R11, which explicitly does NOT overwrite an existing row. A developer must not conflate the two: R11's `new_record?` guard is a protective mechanism that prevents accidental data loss on redeploy; R19's restore performs an unconditional, intentional overwrite because it has been explicitly confirmed by the admin before submission (R21). If no row exists, `first_or_initialize` creates one; if a row already exists with custom values, those values are overwritten. In both cases the `published` flag remains unchanged (default `false` for a new row, unchanged for an existing one).

R21: The "Restore Original Copy" button in the admin form must: (a) use a secondary/outline visual style that is clearly distinct from the primary Save button, so it is not accidentally confused with a save action; (b) carry at minimum `py-3` padding for an adequate touch target per mobile-first convention (CLAUDE.md); (c) use `data: { turbo_method: :patch, turbo_confirm: t("admin.home_page_content.confirm_restore_defaults") }` to require explicit confirmation before submitting — matching the `data: { turbo_method: :delete, turbo_confirm: ... }` precedent in `app/views/admin/services_pages/show.html.erb:65`; (d) render its label via `t("admin.home_page_content.restore_defaults_label")` with no hardcoded English string.

---

## Edge Cases

E1: `HomePageContent.first` returns nil (fresh deployment, seeds not yet run). `PagesController#home` must not raise. The view must treat nil as unpublished and render i18n fallback for all 4 fields.

E2: `HomePageContent` row exists with `published: false`. Public page renders i18n fallback — identical behavior to E1 from the visitor's perspective.

E3: `hero_tagline` submitted with exactly 50 characters. Valid; must save without a length error.

E4: `hero_tagline` submitted with 51 characters. Validation rejects with a length error. HTTP 422 re-renders the form.

E5: `mission_body` submitted with embedded `\n` characters (line breaks typed in the textarea). On the public page these render as visible line breaks due to `whitespace-pre-line` (R9). The admin textarea preserves them in its value on re-render.

E6: i18n fallback path with `whitespace-pre-line`: the `pages.home.mission_body` block-scalar string in `en.yml` contains `\n` characters. Once `whitespace-pre-line` is applied (R9), the fallback will render as 4 separate visual lines instead of the current single continuous paragraph. This is an intentional behavior improvement that QA must verify does not introduce unexpected whitespace.

E7: `mission_body` submitted as all-whitespace (e.g. `"   "`). Rails `validates :mission_body, presence: true` must reject this — `present?` returns `false` for blank strings after trimming — and HTTP 422 re-renders the form.

E8: `PATCH /admin/home_page_content/restore_defaults` is called when no `HomePageContent` row exists (e.g. before the admin has ever saved anything and seeds have not run). The action calls `first_or_initialize`, which returns a new unsaved record; the action sets all 4 fields to i18n values and saves. The `published` field defaults to `false` for the newly created row. The action must not raise and must redirect normally. This is the only code path that creates a `HomePageContent` row outside of seeds and the `update` action.

---

## Acceptance Criteria

### Public Page Behavior

AC-1: Given `HomePageContent` has no row, when `GET /`, then HTTP 200 and the response body includes the literal text of `t("pages.home.hero_tagline")`, `t("pages.home.mission_heading")`, `t("pages.home.mission_subheading")`, and `t("pages.home.mission_body")`.

AC-2: Given `HomePageContent` exists with `published: false`, when `GET /`, then HTTP 200 and the response body includes the i18n fallback values for all 4 editable fields.

AC-3: Given `HomePageContent` exists with `published: true` and `hero_tagline: "Race-Ready."`, `mission_heading: "BUILD FAST."`, `mission_subheading: "BIKES THAT WIN."`, `mission_body: "Custom builds."`, when `GET /`, then HTTP 200 and the response body includes all four custom values.

AC-4: Given any publish state, when `GET /`, then the hero heading `<h1>` element carries both `break-words` and `md:whitespace-nowrap` in its class attribute.

AC-5: Given `HomePageContent` exists with `published: true` and `mission_body: "Line one.\nLine two."`, when `GET /`, then the `<p>` element wrapping the mission body carries `whitespace-pre-line` (Tailwind class) or equivalent `style="white-space: pre-line"`.

AC-6: Given no `HomePageContent` row (i18n fallback path), when `GET /`, then the `<p>` element wrapping the mission body still carries `whitespace-pre-line` styling.

### Admin Behavior

AC-7: Given admin is logged in, when `GET /admin/home_page_content`, then HTTP 200 and the form renders inputs with name attributes for `home_page_content[hero_tagline]`, `home_page_content[mission_heading]`, `home_page_content[mission_subheading]`, `home_page_content[mission_body]`, and `home_page_content[published]`.

AC-8: Given `HomePageContent` exists with `hero_tagline: "Custom tagline"`, when admin visits `GET /admin/home_page_content`, then the `hero_tagline` input is pre-filled with "Custom tagline".

AC-9: Given no `HomePageContent` row exists, when admin visits `GET /admin/home_page_content`, then the form renders without error (no `NoMethodError` or nil-related exception).

AC-10: Given admin is logged in, when `PATCH /admin/home_page_content` with valid params including `hero_tagline: "Speed. Power. Precision."`, then the record is updated and the response redirects to `admin_home_page_content_path` with a `flash[:notice]`.

AC-11: Given admin is logged in, when `PATCH /admin/home_page_content` with `hero_tagline: ""`, then HTTP 422, the form re-renders with a validation error, and no `HomePageContent` field is changed.

AC-12: Given admin is logged in, when `PATCH /admin/home_page_content` with a `hero_tagline` of 51 characters, then HTTP 422, the form re-renders with a length validation error, and no change is persisted.

AC-13: Given admin is logged in, when `PATCH /admin/home_page_content` with `published: "true"`, then `HomePageContent.first.published` is `true` after the request.

AC-14: Given admin is logged in, when `PATCH /admin/home_page_content` with `published: "false"`, then `HomePageContent.first.published` is `false` after the request.

AC-15: `GET /admin` returns HTTP 200 and the response body includes an `href` matching the value of `admin_home_page_content_path`.

AC-16: No hardcoded English strings appear in `app/views/admin/home_page_contents/` or in `Admin::HomePageContentsController`. All user-facing strings use `t()`.

AC-17: The admin home page content form renders without horizontal scroll at 375 px viewport width. All text inputs and the textarea carry `w-full`. The submit button carries at minimum `py-3` padding. (Verified by a system spec in T5.)

### Data Model and Migration

AC-18: A migration creates the `home_page_contents` table with columns and constraints matching the Data Model table in the Interfaces section. Running the migration on a fresh database succeeds without error.

AC-19: `db/seeds.rb` uses `HomePageContent.first_or_initialize` to create exactly one row with the current i18n copy (R11 values) and `published: false`. Running seeds twice produces no error and no second `HomePageContent` row.

### Restore Defaults

AC-20: Given admin is authenticated and no `HomePageContent` row exists, when `PATCH /admin/home_page_content/restore_defaults`, then exactly one `HomePageContent` row is created, all 4 fields (`hero_tagline`, `mission_heading`, `mission_subheading`, `mission_body`) equal the current i18n values for `pages.home.*`, `published` is `false`, and the response redirects to `admin_home_page_content_path` with `flash[:notice]`.

AC-21: Given admin is authenticated and `HomePageContent` exists with `hero_tagline: "Custom tagline"` and `published: true`, when `PATCH /admin/home_page_content/restore_defaults`, then `HomePageContent.first.hero_tagline` equals `t("pages.home.hero_tagline")` (not "Custom tagline"), `HomePageContent.first.published` remains `true` (unchanged), and the response redirects to `admin_home_page_content_path` with `flash[:notice]`.

AC-22: Given a request is NOT authenticated, when `PATCH /admin/home_page_content/restore_defaults`, then the response is a redirect (authentication guard, same behavior as all other admin actions). No `HomePageContent` data is changed.

AC-23: The admin form rendered by `GET /admin/home_page_content` includes a "Restore Original Copy" button that: (a) targets `restore_defaults_admin_home_page_content_path` with HTTP method PATCH; (b) carries a `data-turbo-confirm` attribute; (c) has a visual class indicating secondary/outline styling (distinct from the Save button's primary styling); (d) carries at minimum `py-3` in its class attribute.

---

## Acceptance Tests

AT1
Given no `HomePageContent` row exists
When `GET /`
Then HTTP 200 and the response body includes the value of `t("pages.home.hero_tagline")`
Covers: R1, R3, E1

AT2
Given `HomePageContent` exists with `published: false`
When `GET /`
Then HTTP 200 and the response body includes the value of `t("pages.home.mission_heading")`
Covers: R1, E2

AT3
Given `HomePageContent` exists with `published: true`, `hero_tagline: "Race-Ready."`, `mission_heading: "BUILD FAST."`, `mission_subheading: "BIKES THAT WIN."`, `mission_body: "Custom builds."`
When `GET /`
Then the response body includes "Race-Ready.", "BUILD FAST.", "BIKES THAT WIN.", and "Custom builds."
Covers: R2, R3a

AT4
Given any `HomePageContent` publish state
When `GET /`
Then (a) the hero heading `<h1>` element in the response carries both `break-words` and `md:whitespace-nowrap` in its class attribute; and (b) the hero tagline `<p>` carries `md:truncate` in its class attribute (resolved in ADR-004)
Covers: R4, R5, AC-4

AT5
Given `HomePageContent` exists with `published: true` and `mission_body: "First.\nSecond."`
When `GET /`
Then the response body contains the mission body text and its wrapping `<p>` element carries `whitespace-pre-line` or `style="white-space: pre-line"`
Covers: R9, AC-5, E5

AT6
Given no `HomePageContent` row (i18n fallback)
When `GET /`
Then the `<p>` element wrapping the mission body carries `whitespace-pre-line` or `style="white-space: pre-line"`
Covers: R9, AC-6, E6

AT7
Given admin is authenticated
When `GET /admin/home_page_content`
Then HTTP 200 and the response body contains input name attributes for `home_page_content[hero_tagline]`, `home_page_content[mission_heading]`, `home_page_content[mission_subheading]`, `home_page_content[mission_body]`, and `home_page_content[published]`
Covers: R12, AC-7

AT8
Given `HomePageContent` exists with `hero_tagline: "Test Tagline"`
When admin sends `GET /admin/home_page_content`
Then the response body includes `value="Test Tagline"` in the hero tagline input
Covers: R12, AC-8

AT9
Given admin is authenticated
When `PATCH /admin/home_page_content` with `{ home_page_content: { hero_tagline: "Precision. Power.", mission_heading: "DREAM IT.", mission_subheading: "CUSTOM BIKES.", mission_body: "We build.", published: "true" } }`
Then `HomePageContent.first.hero_tagline` equals "Precision. Power.", `HomePageContent.first.published` is `true`, and the response redirects to `admin_home_page_content_path`
Covers: R13, AC-10, AC-13

AT10
Given admin is authenticated
When `PATCH /admin/home_page_content` with `home_page_content[hero_tagline]: ""` (blank)
Then HTTP 422, `HomePageContent.first&.hero_tagline` is unchanged, and the response body includes a validation error message
Covers: R6, R14, AC-11

AT11
Given admin is authenticated
When `PATCH /admin/home_page_content` with `hero_tagline` set to a 51-character string
Then HTTP 422, no `HomePageContent` value is changed, and the response body includes a length validation error
Covers: R6, E4, AC-12

AT12
Given admin is authenticated
When `PATCH /admin/home_page_content` with `hero_tagline` set to exactly a 50-character string
Then HTTP 302 redirect, no validation error is present, and `HomePageContent.first.hero_tagline` equals the submitted 50-character value
Covers: R6, E3

AT13
Given admin is authenticated
When `PATCH /admin/home_page_content` with `mission_heading: ""` (blank)
Then HTTP 422 and the response body includes a presence validation error
Covers: R7, R14

AT14
Given admin is authenticated
When `PATCH /admin/home_page_content` with `mission_body: ""` (blank)
Then HTTP 422 and the response body includes a presence validation error
Covers: R8, R14, E7

AT15
Given admin is authenticated
When `GET /admin`
Then the response body includes an `href` matching the value of `admin_home_page_content_path`
Covers: R16, AC-15

AT16
Given `db/seeds.rb` is run on a clean database
When `HomePageContent.all` is queried
Then exactly one row exists with `hero_tagline: "Performance, Passion, Precision."` and `published: false`
Covers: R11, AC-19

AT17
Given `db/seeds.rb` is run twice on the same database
When `HomePageContent.count` is queried
Then it equals 1 (idempotent, no second row)
Covers: R10, R11, AC-19

AT18
Given admin is authenticated and no `HomePageContent` row exists
When `PATCH /admin/home_page_content/restore_defaults`
Then exactly one `HomePageContent` row exists; `hero_tagline` equals `I18n.t("pages.home.hero_tagline")`; `mission_heading` equals `I18n.t("pages.home.mission_heading")`; `mission_subheading` equals `I18n.t("pages.home.mission_subheading")`; `mission_body` equals `I18n.t("pages.home.mission_body")`; `published` is `false`; and the response redirects to `admin_home_page_content_path` with `flash[:notice]` present
Covers: R18, R19, R20, E8, AC-20

AT19
Given admin is authenticated and `HomePageContent` exists with `hero_tagline: "My Custom Line"` and `published: true`
When `PATCH /admin/home_page_content/restore_defaults`
Then `HomePageContent.first.hero_tagline` equals `I18n.t("pages.home.hero_tagline")` (not "My Custom Line"); `HomePageContent.first.published` is `true` (unchanged); and the response redirects to `admin_home_page_content_path` with `flash[:notice]` present
Covers: R19, R20, AC-21

AT20
Given no active admin session (unauthenticated)
When `PATCH /admin/home_page_content/restore_defaults`
Then the response redirects (auth guard) and `HomePageContent.count` is unchanged
Covers: R19, AC-22

AT21
Given admin is authenticated
When `GET /admin/home_page_content`
Then the response body includes (a) a form action or link targeting the path for `restore_defaults_admin_home_page_content_path` with method `patch`; (b) a `data-turbo-confirm` attribute on the restore element; and (c) a `py-3` class on the restore button element
Covers: R21, AC-23

---

## Open Questions

OQ1 — **Resolved by ADR-004:** `published` lives as a boolean column on `HomePageContent`. The `services_page_published` SiteSetting precedent does not apply — it is a page-access gate, not a content substitution switch. See `docs/architecture/ADR-004-singleton-content-model-and-publish-flag-placement.md` for full rationale.

OQ2 — **Resolved by ADR-004:** Use `md:truncate` on the hero tagline `<p>` element. `md:truncate` expands to `overflow-hidden text-ellipsis whitespace-nowrap`. For any valid ≤ 50-character content it renders identically to bare `md:whitespace-nowrap`, but clips with an ellipsis if the DB value ever bypasses the model-level validation. See R5 and ADR-004 for full rationale.

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-07 | Dedicated `HomePageContent` model rather than expanding `SiteSetting` key-value store | Four distinct typed fields with individual validations map cleanly to an ActiveRecord model. The SiteSetting store is designed for single boolean/string flags, not multi-field content objects. Confirmed by ADR-004. |
| 2026-07-07 | `published: false` for the seed row | Matches the `services_page_published` precedent. No change visible on the live site until Doug explicitly publishes. |
| 2026-07-07 | `whitespace-pre-line` applied regardless of publish state | The i18n fallback `mission_body` string is a 4-line block scalar and should render as 4 lines on the public page. Applying `pre-line` only to the DB-sourced path would create visual inconsistency between fallback and published renderings. |
| 2026-07-07 | 50-character `hero_tagline` limit empirically derived | Worst-case (M/W-heavy text) wraps at 60 chars at 1024 px and 75 chars at 1280 px at the tagline's rendered CSS (`text-xl md:text-2xl font-bold tracking-wide`). 50 chars leaves comfortable margin at common desktop widths while still giving materially more room than the current 33-character default. |
| 2026-07-07 | `resource :home_page_content, only: [:show, :update]` — no new/create/destroy | The singleton row is created on first update via `first_or_initialize` — no separate create action needed. No destroy: deleting home page content would leave the public page on i18n fallback, which is already the unpublished state. |

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. Layout, nav, Tailwind, and asset pipeline are in place.
- SPEC-003 (i18n String Extraction) — done. All new admin UI strings must follow the `t()` / `en.yml` pattern.
- SPEC-004 (Admin Backend) — done. `Admin::BaseController`, auth session management, and admin layout are live.
- No new gems required. This spec uses only existing Rails, Tailwind, and importmap infrastructure.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Migration: create `home_page_contents` table with all columns and constraints per the data model. Create `HomePageContent` model with validations (R6, R7, R8) and singleton read pattern (R10). Update `db/seeds.rb` with idempotent seed row (R11). Add FactoryBot factory. | AC-18, AC-19, R6, R7, R8, R10, R11 | 2 |
| T2 | Public page update: update `PagesController#home` to load `HomePageContent.first` (R3); update `app/views/pages/home.html.erb` to conditionally render DB vs. i18n (R1, R2, R3a) using a single `content` local variable (R3a — do not scatter four independent `published?` checks); add `md:whitespace-nowrap` to hero h1 class list (R4); add `md:truncate` to hero tagline `<p>` class list (R5); apply `whitespace-pre-line` to mission body `<p>` (R9). | AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, R1, R2, R3, R3a, R4, R5, R9 | 2 |
| T3 | Admin controller and routes: add `resource :home_page_content, only: [:show, :update] do patch :restore_defaults end` to the admin namespace in `config/routes.rb`; create `Admin::HomePageContentsController` with `restore_defaults`, `show`, and `update` actions (alphabetical order per `.claude/standards/practices/architecture.md §1.8`); add all required i18n keys under `admin.home_page_content` (including `restore_defaults_label`, `confirm_restore_defaults`, `flash.restored`) and `admin.dashboard.home_page_link` (R15, R16, R18, R19); update dashboard view link (R16). The `restore_defaults` action reads i18n values via `I18n.t("pages.home.*")` — the same keys used by the public fallback path — and must not define a second copy of the original strings anywhere in the controller (R18). | AC-7, AC-10, AC-11, AC-12, AC-13, AC-14, AC-15, AC-16, AC-20, AC-21, AC-22, R12, R13, R14, R15, R16, R18, R19, R20 | 3 |
| T4 | Admin view: create `app/views/admin/home_page_contents/show.html.erb` with a mobile-first form (R17); include error display block, labeled inputs for all 4 fields, `hero_tagline_hint` permanently visible beneath the hero tagline input (R17), `mission_body` textarea with `rows: 8` (R17), a `published` checkbox using the `<label class="flex items-center gap-3 cursor-pointer">` wrapper pattern from `app/views/admin/services_pages/show.html.erb` (lines ~8–12) with accompanying hidden field for unchecked state (R17), `published_hint` help text and `current_status_label`/`status_published`/`status_unpublished` status display, a primary Save button, and a secondary/outline "Restore Original Copy" button that targets `restore_defaults_admin_home_page_content_path` via `data: { turbo_method: :patch, turbo_confirm: t("admin.home_page_content.confirm_restore_defaults") }` with at minimum `py-3` padding (R21). The restore button must be visually distinct from Save — it must not share the same primary-color CTA class. Advisory (not blocking): consider a live character-counter Stimulus controller on the hero tagline input (e.g. "32 / 50"). Class and structural patterns for non-checkbox fields match `app/views/admin/service_sections/_form.html.erb`. | AC-7, AC-8, AC-9, AC-16, AC-17, AC-23, R12, R17, R21 | 2 |
| T5 | Tests: `HomePageContent` model spec (validations, singleton first_or_initialize, published default); request spec for `PagesController#home` (no row → fallback, unpublished → fallback, published → DB values); request spec for `Admin::HomePageContentsController` (auth guard on show, update, and restore_defaults; show pre-fills; update happy path; update validation failures; restore_defaults when no row; restore_defaults overwrites fields but leaves published unchanged); system spec for admin form at 375 px viewport (AC-17 and AC-23). All tests use AAA pattern, inline variables only, no `let`/`let!`, no domain-setup `before` hooks (per testing.md). | All ATs (AT1–AT21) | 5 |

Total estimated points: 13

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-07-07 | Initial draft | All | New spec |
| 2026-07-07 | Applied consolidated review findings (architect ADR-004, reviewer critical/major/minor, UX): resolved OQ1 and OQ2; added R3a (single-computation content pattern; `published?` predicate requirement); updated R5 to `md:truncate` with accessibility note; updated R6 with Unicode-character clarification; expanded R11 with non-overwrite constraint referencing ADR-004 note 3; expanded R17 with `hero_tagline_hint` permanent-visibility requirement, `mission_body` `rows: 8` minimum, and `published` checkbox wrapper pattern; added AT12 (exactly 50-character boundary test); renumbered old AT12–AT16 to AT13–AT17; added `published_hint`, `current_status_label`, `status_published`, `status_unpublished` i18n keys; revised `published_label` rationale; updated T2, T3, T4; removed OQ1/OQ2 blockers; removed "Final structure subject to OQ1" from Implementation Decisions; promoted status to `ready`. | All | Reviewer critical + major + minor; ADR-004; UX review |
| 2026-07-07 | Added Restore Original Copy capability: new route `PATCH /admin/home_page_content/restore_defaults`; added R18 (single source of truth for original copy — i18n keys only, no second hardcoded copy), R19 (restore action behavior: overwrites 4 fields from i18n, does not touch `published`, redirects with flash), R20 (restore vs. seed distinction — unconditional overwrite vs. R11's protective guard), R21 (restore button UX: secondary/outline style, `py-3` touch target, `data-turbo-confirm`); added E8 (restore when no row exists); added AC-20–AC-23 and AT18–AT21; added i18n keys `restore_defaults_label`, `confirm_restore_defaults`, `flash.restored`; updated Interfaces admin table and route declaration; updated T3 (+1 point, 2→3), T5 (+2 points, 3→5); T4 unchanged at 2 points. Total estimate updated 11→13. Status remains `ready`. | R18, R19, R20, R21, E8, AC-20, AC-21, AC-22, AC-23, AT18, AT19, AT20, AT21, T3, T4, T5, i18n table | New requirement added post-initial review |
| 2026-07-07 | Added maintenance constraint sentence to R11: `db/seeds.rb` literal strings must be kept in sync with `config/locales/en.yml` `pages.home.*` values — any i18n update requires a matching seeds.rb update in the same change, otherwise stale copy is silently seeded on fresh environments. Advisory (not blocking). Status remains `ready`. | R11 | Reviewer advisory finding |
