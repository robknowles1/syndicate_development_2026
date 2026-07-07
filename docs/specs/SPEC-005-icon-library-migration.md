# Spec: Icon Library Migration — Heroicon to Tabler Icons

**ID:** SPEC-005
**Status:** done
**Priority:** medium
**Created:** 2026-07-02
**Updated:** 2026-07-02 (reviewer REQUEST_CHANGES + architect + UX review findings applied; gem-version-lag amendment — vendored car-suspension icon)
**Author:** spec-agent

---

## Goal

Replace the `heroicon` gem with `tabler_icons_ruby` across the Services page and its admin CRUD, and expand `ServiceSection::ICON_KEYS` from 14 to 18 entries to include literal automotive icons (engine, suspension, motorbike, helmet) unavailable in Heroicons v2. The swap is a clean remove-and-add: no dual-gem period, no coexistence of two icon styles.

---

## Non Goals

- Running `heroicon` and `tabler_icons_ruby` simultaneously at any point.
- Changing the inline-SVG rendering mechanism (Tabler preserves the Propshaft-safe pattern already in place).
- Changing the Services page layout, grid, or admin CRUD behaviour.
- Adding icon search, categories, or pagination to the admin picker.
- Per-section custom colours or stroke widths (icons continue to inherit CSS `currentColor`).
- Migrating icon usage on Home, About, Gallery, or Contact pages — none of those pages use the `heroicon` gem.

---

## Definitions

| Term | Definition |
|------|-----------|
| ICON_KEYS | The constant array of permitted `icon_key` values in `ServiceSection`. After this migration it contains 18 Tabler icon key strings. |
| Tabler icon key | A kebab-case string exactly matching an icon name in the Tabler Icons v3 set (e.g. `"tool"`, `"motorbike"`). Must match the filename stem of the Tabler SVG bundled in the gem. |
| Heroicon key | An icon name from Heroicons v2, as bundled in the `heroicon` gem (e.g. `"wrench"`, `"cog-6-tooth"`). These are the old values being replaced. |
| tabler_icons_ruby gem | A Ruby gem (MIT, v3.26.0+, rubygems.org) that bundles Tabler Icons v3 SVGs and provides a view helper for rendering them as inline SVG. No Sprockets/Propshaft configuration required. |
| explicit key mapping | The authoritative Heroicon→Tabler table defined in this spec. The data migration must use this table verbatim — no heuristic or substring substitution. |
| call site | A view location where `heroicon(...)` is currently invoked. Three call sites exist: `app/views/pages/services.html.erb:14`, `app/views/admin/services_pages/show.html.erb:42`, `app/views/admin/service_sections/_form.html.erb:36`. |

---

## Interfaces

### Gemfile

Remove: `gem "heroicon", "~> 1.0"`
Add: `gem "tabler_icons_ruby", "~> 3.26"`

Note: Gemfile line 25 currently contains the comment `# Render Heroicons v2 as inline SVG [https://github.com/bharget/heroicon]`. This comment becomes orphaned when the gem is swapped and must be removed or replaced with a comment for the new gem. `bundle install` must be run and the regenerated `Gemfile.lock` committed.

### ApplicationHelper (`app/helpers/application_helper.rb`)

Remove: `include Heroicon::ApplicationHelper`
Add: the module include for `tabler_icons_ruby`. Verify the exact module constant name from the gem README before implementing (expected: `TablerIconsRuby::ApplicationHelper`).

### Vendored Icon Fallback (`app/helpers/application_helper.rb`)

`tabler_icons_ruby` v3.26.0 (the only rubygems release, January 2025) bundles ~5,847 icons but does not include `car-suspension.svg`, which was added to the upstream Tabler Icons project after that release.

To handle this and any future gem-vs-upstream gaps, `ApplicationHelper` must define two additions:

**`VENDORED_ICON_SVGS`** — a private frozen `Hash` constant mapping icon key strings to raw SVG markup strings. Each value is a complete `<svg ...>...</svg>` string with:
- Attributes matching Tabler's design system conventions: `viewBox="0 0 24 24"`, `fill="none"`, `stroke="currentColor"`, `stroke-width="2"`, `stroke-linecap="round"`, `stroke-linejoin="round"`
- A `class` attribute following the gem's own naming convention: `"icon icon-tabler icons-tabler-outline icon-tabler-<key>"` (e.g. `"icon icon-tabler icons-tabler-outline icon-tabler-car-suspension"`), with a placeholder string (e.g. `"ICON_CSS_CLASS_PLACEHOLDER"`) appended that the helper replaces at call time with the caller-supplied CSS size classes
- The SVG body reproducing the upstream source verbatim (6 `<path>` elements for `car-suspension`)

Currently contains one entry: `"car-suspension"` — sourced verbatim from `https://raw.githubusercontent.com/tabler/tabler-icons/main/icons/outline/car-suspension.svg` (MIT licensed). Byte-for-byte consistent with the gem's design system conventions as confirmed by diffing against `engine.svg` from the installed gem.

**`service_icon(icon_key, css_class:)`** — a public helper method:
- If `icon_key` is a key in `VENDORED_ICON_SVGS`, return the corresponding vendored SVG string with the placeholder replaced by `css_class`, marked `html_safe`
- Otherwise delegate to `tabler_icon(icon_key, class: css_class)`

This centralises the vendored-icon fallback in one place instead of duplicating a conditional across all three view call sites. Icons loaded via either path are visually indistinguishable: the vendored SVG uses the same viewBox, fill, stroke, stroke-width, linecap, and linejoin conventions as every icon the gem renders.

### View helper call sites

| File | Current call | Replacement |
|------|-------------|-------------|
| `app/views/pages/services.html.erb:14` | `heroicon section.icon_key, variant: :outline, options: { class: "w-10 h-10" }` | `service_icon(section.icon_key, css_class: "w-10 h-10")` |
| `app/views/admin/services_pages/show.html.erb:42` | `heroicon section.icon_key, variant: :outline, options: { class: "w-6 h-6" }` | `service_icon(section.icon_key, css_class: "w-6 h-6")` |
| `app/views/admin/service_sections/_form.html.erb:36` | `heroicon key, variant: :outline, options: { class: "w-8 h-8" }` | `service_icon(key, css_class: "w-8 h-8")` |

All three call sites use `service_icon` rather than `tabler_icon` directly so that both gem-backed and vendored icons flow through one consistent code path. Verify the exact `tabler_icon` method signature (name and class-passing convention) from the gem README before implementing `service_icon`'s delegation branch.

### ServiceSection::ICON_KEYS

Replace the current 14-entry array with the 18-entry Tabler array specified in the Explicit Key Mapping section below.

### Data Migration

A new Rails migration that backfills `icon_key` values for all existing `ServiceSection` rows, using the explicit key mapping table. No schema change is required — the column type (string, not null) is unchanged.

---

## Explicit Key Mapping (Heroicon → Tabler)

This table is the authoritative source for the migration, seeds, and ICON_KEYS constant.

| Old Heroicon key | New Tabler key | Notes |
|-----------------|---------------|-------|
| `wrench` | `tool` | |
| `wrench-screwdriver` | `tools` | |
| `bolt` | `bolt` | unchanged |
| `fire` | `flame` | |
| `beaker` | `flask` | |
| `adjustments-horizontal` | `adjustments-horizontal` | confirmed exact filename match in Tabler outline directory |
| `adjustments-vertical` | `adjustments` | Tabler's naming is inverted from Heroicons: the plain unsuffixed `adjustments` is the vertical-sliders style; `adjustments-horizontal` is the explicit horizontal variant. No `adjustments-vertical` file exists in Tabler because vertical is the default/implicit form. |
| `cpu-chip` | `cpu` | |
| `chart-bar` | `chart-bar` | confirmed exact filename match in Tabler outline directory |
| `cog-6-tooth` | `settings` | confirmed exact filename match |
| `cog-8-tooth` | `settings-2` | confirmed exact filename match; confirmed visually distinct from `settings` |
| `cube` | `cube` | unchanged |
| `sparkles` | `sparkles` | unchanged |
| `trophy` | `trophy` | unchanged |

New icons added to the picker (no Heroicon predecessor):

| New Tabler key | Represents |
|---------------|-----------|
| `engine` | Internal combustion engine |
| `car-suspension` | Suspension geometry |
| `motorbike` | Motorbike silhouette |
| `helmet` | Riding helmet |

Final `ICON_KEYS` array (18 entries — this order is the picker display order):

```
tool  tools  bolt  flame  flask
adjustments-horizontal  adjustments  cpu  chart-bar
settings  settings-2  cube  sparkles  trophy
engine  car-suspension  motorbike  helmet
```

---

## Seeded Section Mapping

The three default sections in `db/seeds.rb` store old Heroicon keys. After this spec is implemented they must store Tabler equivalents:

| Section heading | Old `icon_key` | New `icon_key` |
|----------------|---------------|---------------|
| PRECISION ENGINES | `cog-6-tooth` | `settings` |
| CUSTOM SUSPENSION SETUP | `adjustments-horizontal` | `adjustments-horizontal` |
| ECU TUNING | `cpu-chip` | `cpu` |

---

## Rules

R1: The `heroicon` gem must be removed from the Gemfile. No code in the application may reference `Heroicon` or call `heroicon(...)` after this migration is complete.

R2: `tabler_icons_ruby` at `~> 3.26` must be added to the Gemfile. The gem must render icons as inline SVG with no Propshaft configuration required.

R3: `ApplicationHelper` must include the tabler_icons_ruby view helper module in place of `Heroicon::ApplicationHelper`. The exact module constant must be verified from the gem README before implementation.

R4: `ServiceSection::ICON_KEYS` must contain exactly the 18 Tabler key strings listed in the Explicit Key Mapping section. The order within the array determines the dropdown order in the admin picker.

R5: The `icon_key` model validation (`validates :icon_key, presence: true, inclusion: { in: ICON_KEYS }`) requires no logic change. After the constant update, all 14 old Heroicon-only keys are invalid; all 18 Tabler keys are valid.

R6: All three `heroicon(...)` view call sites must be replaced with calls to the new `service_icon(icon_key, css_class: ...)` helper — not directly to `tabler_icon(...)`. The size CSS classes (`w-10 h-10`, `w-6 h-6`, `w-8 h-8`) are passed as the `css_class:` keyword argument at each respective call site. Routing all icon renders through `service_icon` ensures both gem-backed and vendored icons (e.g. `car-suspension`) follow one consistent code path.

R7: The icon picker in the admin section form must continue to render one pre-hidden `<span>` per key in ICON_KEYS and toggle visibility on dropdown `change` via the existing `icon-preview` Stimulus controller. No change to the Stimulus controller is required — only the underlying rendered icons change. After this migration the form renders 18 option elements and 18 icon spans (up from 14).

R8: A data migration must backfill `icon_key` on all existing `ServiceSection` rows using the explicit key mapping. The migration must:
(a) Call `ServiceSection.reset_column_information` before querying.
(b) Iterate the mapping and call `where(icon_key: old_key).update_all(icon_key: new_key)` for each pair.
(c) After all known remappings are applied, query for any remaining rows whose `icon_key` is not in the new ICON_KEYS array and raise `StandardError` if any are found — this catches rows with custom or out-of-band keys that have no migration target.
(d) Run inside a `reversible { |dir| dir.up { ... } }` block. The `down` block must first check whether any `ServiceSection` row has `icon_key` in `%w[engine car-suspension motorbike helmet]` (the 4 new keys that have no Heroicon predecessor) and raise a descriptive `StandardError` if any are found — these keys cannot be reversed because Heroicons has no equivalent, and proceeding would leave those rows with invalid keys once the smaller Heroicon ICON_KEYS is restored. Only after that guard check passes must the `down` block reverse the full 14-key mapping (new key → old key) for all rows — not only the three seeded rows.

R9: `db/seeds.rb` must be updated to use the new Tabler `icon_key` values for all three default sections. Seeds remain idempotent.

R10: `docs/architecture/ADR-003-icon-library-migration-to-tabler.md` has been authored by the architect prior to developer implementation and `docs/architecture/README.md` has been updated with the corresponding index entry. The developer must add a one-line forward-reference note at the top of `docs/architecture/ADR-002-services-page-icon-rendering-and-ordering.md` (after the title/frontmatter block) stating that Decision 1 (icon rendering library) is superseded by `ADR-003-icon-library-migration-to-tabler.md`. ADR-002's own status remains `accepted` and is not otherwise amended.

R11: `spec/models/service_section_spec.rb` must be updated so the `ICON_KEYS` length assertion expects exactly 18, not 14.

R12: The following files contain hardcoded Heroicon key strings that must be updated before the test suite will pass. All Heroicon keys must be replaced with the corresponding Tabler key from the explicit mapping:

- `spec/factories/service_sections.rb` — both the `service_section` factory and the `service_section_without_bullet` factory hardcode `"wrench"`; replace with `"tool"`.
- `spec/requests/admin/service_sections_spec.rb` — line 44 and line 65 each reference `"wrench"`; replace with `"tool"`.
- `spec/requests/pages_spec.rb` — line 8 references `"wrench"` (replace with `"tool"`) and line 10 references `"fire"` (replace with `"flame"`).
- `spec/system/admin/service_sections_spec.rb` — lines 27, 49, and 74 reference old Heroicon keys. The Capybara `select "wrench", from: ...` call (approximately line 49) requires special attention: a stale key string there raises `Capybara::ElementNotFound` rather than a clear assertion failure, making the root cause harder to diagnose. Replace all three references with the appropriate Tabler keys.
- `spec/system/admin/services_page_spec.rb` — line 9 references `"cog-6-tooth"`; replace with `"settings"`.

R13: Each of the 18 Tabler keys in the final `ICON_KEYS` array must be verified to render without raising in the tabler_icons_ruby helper before shipping. The recommended verification is invoking the helper for each key in the development console or via a dedicated helper spec. The model-level "is valid for every value in ICON_KEYS" spec checks model validation only and does not guarantee the view helper will not raise — both checks are required.

---

## Edge Cases

E1: A `ServiceSection` row in the database whose `icon_key` is not one of the 14 known old Heroicon keys must cause the migration to raise (R8c). This prevents silent data corruption if a custom key was stored outside the seeded set.

E2: Pre-implementation verification of three Tabler key names is complete. Findings:
- `adjustments-horizontal` — exact filename match confirmed in Tabler's outline directory. Mapping stands.
- `chart-bar` — exact filename match confirmed in Tabler's outline directory. Mapping stands.
- `adjustments-vertical` — no exact match in Tabler. Tabler's naming convention is the inverse of Heroicons: the plain unsuffixed `adjustments` is the vertical-sliders style; `adjustments-horizontal` is the explicit horizontal variant. The mapping has been corrected to Heroicon `adjustments-vertical` → Tabler `adjustments`. No `adjustments-vertical` file exists in Tabler because vertical is the default/implicit form. No further developer verification is required for these three names.

E3: The `cog-6-tooth` → `settings` and `cog-8-tooth` → `settings-2` mappings must result in visually distinct icons in the admin picker. The developer must render both side-by-side in the form and confirm visual distinction before sign-off. If they are indistinguishable, a different Tabler settings variant (e.g. `settings-cog`, `settings-automation`) must be chosen and the mapping updated. Note: while the native `<select>` is open on a mobile device, `"settings"` and `"settings-2"` are indistinguishable by label text alone — the live SVG preview only resolves after selection. This is a deliberate accepted tradeoff, not an oversight. It is consistent with the existing 14-key picker, which already uses non-humanized raw key strings (e.g. `"cog-6-tooth"`, `"wrench-screwdriver"`) with no label/value pair abstraction and no reported complaints. Introducing humanized labels for these two keys alone would add unnecessary complexity for a single-admin-user form.

E4: `tabler_icons_ruby` may not expose a `variant:` parameter (the heroicon gem required `variant: :outline`). If the gem is outline-only, the `variant: :outline` argument must be dropped from the replacement call. If the gem offers multiple styles, the outline variant must be explicitly selected.

E5: The migration's `down` block must reverse the full 14-key mapping for every `ServiceSection` row. Partial reversal (e.g. only the three seeded rows) leaves the schema in an inconsistent state if a non-seeded section had been created before the migration ran.

E6: Verification of the 4 new Tabler-only icon names (no Heroicon predecessor) is complete. A direct query of the Tabler Icons GitHub repository (github.com/tabler/tabler-icons, main branch, recursive tree of `icons/outline/*.svg`, 5093 total outline files, non-truncated result) confirmed exact filename matches for all four:
- `engine.svg` — confirmed (sibling `engine-off.svg` also exists but is not used).
- `car-suspension.svg` — confirmed.
- `motorbike.svg` — confirmed.
- `helmet.svg` — confirmed (sibling `helmet-off.svg` also exists but is not used).

No further icon name verification work remains for the developer. All 18 ICON_KEYS entries (14 mapped + 4 new) are fully verified against the Tabler outline directory.

Implementation note — gem version lag: despite `car-suspension.svg` existing in the upstream repository (confirmed above), `tabler_icons_ruby` v3.26.0 does not bundle it — the file was added to the upstream project after the gem's January 2025 release. This gap was discovered during implementation. Two alternatives were considered and rejected: (1) substituting `steering-wheel` — semantically inaccurate, as steering geometry is unrelated to suspension; (2) dropping the icon entirely. The user's explicit choice was to vendor `car-suspension.svg` directly via the `VENDORED_ICON_SVGS` constant in `ApplicationHelper`. The SVG is MIT-licensed (same as the rest of the Tabler library). `car-suspension` remains the canonical key in `ICON_KEYS`, seeds, migrations, and all spec references — the implementation must be corrected to match.

---

## Acceptance Criteria

### Gem and Helper

AC-1: The Gemfile does not contain `heroicon` and does contain `gem "tabler_icons_ruby", "~> 3.26"`. The orphaned Heroicon comment at line 25 is removed or replaced. `bundle install` succeeds and `Gemfile.lock` is committed.

AC-2: `app/helpers/application_helper.rb` does not reference `Heroicon::ApplicationHelper` and does include the tabler_icons_ruby helper module.

### Model

AC-3: `ServiceSection::ICON_KEYS` is an array of exactly 18 strings matching the Explicit Key Mapping section.

AC-4: `ServiceSection.new(icon_key: "wrench").valid?` is `false` — `errors[:icon_key]` is present (`"wrench"` is an old Heroicon-only key not in the new ICON_KEYS).

AC-5: A `ServiceSection` with `icon_key: "tool"` (new Tabler equivalent of `"wrench"`) passes the `icon_key` inclusion validation.

AC-6: A `ServiceSection` with `icon_key: "engine"` (new addition) passes the `icon_key` inclusion validation.

### Views

AC-7: `GET /services` with `services_page_published` true and at least one section returns HTTP 200 with `<svg` present in the response body (inline SVG rendered via tabler_icons_ruby).

AC-8: `GET /admin/services` (authenticated) returns HTTP 200 with `<svg` present in the response body for each section's icon preview.

AC-9: `GET /admin/service_sections/new` (authenticated) renders exactly 18 `<option>` elements in the icon_key select and exactly 18 icon preview spans.

AC-10: The rendered output of `admin/service_sections/_form.html.erb` contains no reference to `heroicon` — the old helper is fully replaced.

### Data Migration

AC-11: After running the migration on a database with the three seeded sections, the rows have the following Tabler keys:
- PRECISION ENGINES: `icon_key = "settings"`
- CUSTOM SUSPENSION SETUP: `icon_key = "adjustments-horizontal"`
- ECU TUNING: `icon_key = "cpu"`

AC-12: If a `ServiceSection` row exists with `icon_key = "legacy_custom"` (not in the 14-key mapping) when the migration runs, the migration raises and does not commit.

AC-13: `db:migrate:down` on this migration restores the three seeded sections to their original Heroicon keys (`cog-6-tooth`, `adjustments-horizontal`, `cpu-chip`).

AC-13b: `db:migrate:down` raises a descriptive `StandardError` (or subclass) and rolls back the entire transaction without modifying any rows when any `ServiceSection` row has `icon_key` in `%w[engine car-suspension motorbike helmet]` — the 4 new-only keys that have no Heroicon equivalent.

AC-13c: A non-seeded `ServiceSection` whose `icon_key` is any of the 14 mapped Tabler keys (e.g. `"tool"`) has its `icon_key` reverted to the corresponding Heroicon key (e.g. `"wrench"`) when `db:migrate:down` runs. The full 14-pair reversal applies to every row, not only the three seeded rows.

### Seeds

AC-14: `db/seeds.rb` specifies `icon_key: "settings"` for PRECISION ENGINES, `icon_key: "adjustments-horizontal"` for CUSTOM SUSPENSION SETUP, and `icon_key: "cpu"` for ECU TUNING. Running seeds twice is idempotent (no error, no duplicate records).

### ADR

AC-15: `docs/architecture/ADR-003-icon-library-migration-to-tabler.md` exists (created by the architect prior to implementation) and contains: the decision to use `tabler_icons_ruby`, rationale (automotive icons, MIT licence, Propshaft-safe), rejected alternative (dual-gem coexistence), and the full 14-key Heroicon→Tabler mapping table. No developer action is required to create this file. Additionally, `docs/architecture/ADR-002-services-page-icon-rendering-and-ordering.md` contains a one-line forward-reference note (added by the developer) stating that Decision 1 (icon rendering library) is superseded by `ADR-003-icon-library-migration-to-tabler.md`.

### Tests

AC-16: `spec/models/service_section_spec.rb` asserts `ServiceSection::ICON_KEYS.length` equals 18.

AC-17: The "is valid for every value in ICON_KEYS" model spec passes for all 18 Tabler keys with zero failures.

AC-18: No spec file contains a Heroicon-only key string (e.g. `"wrench"`, `"cog-6-tooth"`, `"cpu-chip"`, `"fire"`, `"beaker"`) as an expected-valid `icon_key` value.

### Vendored Icon Fallback

AC-19: `GET /services` with `services_page_published` true and a section with `icon_key: "car-suspension"` returns HTTP 200 and the response body contains `<svg` (confirming the vendored fallback path in `service_icon` renders correctly). `GET /admin/services` (authenticated) with the same section also returns HTTP 200 and the response body contains `<svg`.

---

## Acceptance Tests

AT1
Given the Gemfile swap is applied and `bundle install` has run
When `ServiceSection::ICON_KEYS` is inspected in the Rails console
Then it contains exactly 18 strings and none of the old Heroicon-only keys (`wrench`, `cog-6-tooth`, `cpu-chip`, `fire`, `beaker`) are present
Covers: R1, R2, R4

AT2
Given a ServiceSection record with `icon_key = "wrench"` (old Heroicon key)
When `section.valid?` is called
Then `section.errors[:icon_key]` is present and the record is invalid
Covers: R5, AC-4

AT3
Given a ServiceSection record with `icon_key = "engine"` (new Tabler addition)
When `section.valid?` is called
Then no `icon_key` error is present and the record passes inclusion validation
Covers: R4, R5, AC-6

AT4
Given all 18 Tabler keys listed in ICON_KEYS
When each is assigned to `section.icon_key` and `section.valid?` is called
Then no key produces an `icon_key` inclusion error
Covers: R4, R5, AC-5, AC-6

AT5
Given `services_page_published` is true and a section exists with `icon_key = "tool"`
When `GET /services`
Then HTTP 200 and the response body contains `<svg`
Covers: R3, R6, AC-7

AT6
Given admin is authenticated and a section exists with `icon_key = "flame"`
When `GET /admin/services`
Then HTTP 200 and the response body contains `<svg`
Covers: R3, R6, AC-8

AT7
Given admin is authenticated
When `GET /admin/service_sections/new`
Then the response body contains exactly 18 `<option` elements in the icon_key select and 18 icon preview spans
Covers: R7, AC-9

AT8
Given the three seeded sections exist with old Heroicon keys (`cog-6-tooth`, `adjustments-horizontal`, `cpu-chip`)
When the migration runs (`db:migrate`)
Then the rows have `icon_key` values `settings`, `adjustments-horizontal`, and `cpu` respectively
Covers: R8, AC-11

AT9
Given a `ServiceSection` row exists with `icon_key = "legacy_custom"` (absent from the explicit mapping)
When the migration runs
Then the migration raises and does not commit any changes
Covers: R8(c), E1, AC-12

AT10
Given the migration has run and sections have Tabler keys
When `db:migrate:down` is run for this migration
Then the three seeded sections have their original Heroicon keys restored (`cog-6-tooth`, `adjustments-horizontal`, `cpu-chip`)
Covers: R8(d), E5, AC-13

AT10b
Given a `ServiceSection` exists with `icon_key = "engine"` (a new-only key with no Heroicon predecessor)
When `db:migrate:down` is run for this migration
Then the migration raises a descriptive error before modifying any rows, and the transaction is rolled back with no `icon_key` values changed
Covers: R8(d), AC-13b

AT10c
Given a non-seeded `ServiceSection` exists with `icon_key = "tool"` (the Tabler equivalent of `"wrench"`, not one of the three seeded sections)
When `db:migrate:down` is run for this migration
Then that section's `icon_key` is reverted to `"wrench"`, confirming all 14 mapped pairs are reversed — not only the three seeded rows
Covers: R8(d), E5, AC-13c

AT11
Given `db/seeds.rb` is run on a clean database
When the three default sections are queried
Then PRECISION ENGINES has `icon_key = "settings"`, CUSTOM SUSPENSION SETUP has `icon_key = "adjustments-horizontal"`, ECU TUNING has `icon_key = "cpu"`
Covers: R9, AC-14

AT12
Given `spec/models/service_section_spec.rb` has been updated
When `bundle exec rspec spec/models/service_section_spec.rb` is run
Then it passes with 0 failures, the ICON_KEYS length assertion expects 18, and no example references a Heroicon-only key string as a valid value
Covers: R11, R12

AT13
Given the implementation is complete
When `docs/architecture/ADR-003-icon-library-migration-to-tabler.md` and `docs/architecture/ADR-002-services-page-icon-rendering-and-ordering.md` are read
Then ADR-003 exists and contains: the decision to use `tabler_icons_ruby`, rationale, rejected dual-gem alternative, and the full 14-key Heroicon→Tabler mapping table; and ADR-002 contains a forward-reference note at the top stating that Decision 1 (icon rendering library) is superseded by `ADR-003-icon-library-migration-to-tabler.md`
Covers: R10, AC-15

AT14
Given `bundle install` is complete in development
When the tabler_icons_ruby view helper is called for each of the 18 keys in ICON_KEYS (via Rails console or a helper spec)
Then no call raises and each returns a string containing `<svg`
Covers: R13

AT15
Given `services_page_published` is true and a section exists with `icon_key = "car-suspension"`
When `GET /services` and `GET /admin/services` (authenticated) are requested
Then both return HTTP 200 and both response bodies contain `<svg` — confirming the vendored fallback in `service_icon` renders the car-suspension SVG through the same assertion path as gem-backed icons
Covers: R6, AC-19

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-02 | Clean swap (remove heroicon, add tabler_icons_ruby) rather than dual-gem coexistence | Mixing two icon libraries produces visual inconsistency from differing SVG stroke weights and styles. Tabler is a strict superset for this project's needs. |
| 2026-07-02 | New ADR-003 rather than amending ADR-002 | ADR-002 documents the original heroicon decision as accepted — amending it obscures decision history. ADR-003 records the migration as a separate decision event, superseding ADR-002 Decision 1 only. |
| 2026-07-02 | Migration raises on any unmapped key (R8c) rather than skipping rows | Silent skips leave stale Heroicon key strings in the DB, causing validation failures and view render errors at runtime. Fail-loud is safer. |
| 2026-07-02 | ICON_KEYS picker order: 14 mapped keys first, then 4 new additions | Preserves visual familiarity of the existing picker for Doug while appending the new automotive icons. Order can be adjusted before shipping if a domain-grouped order is preferred. |
| 2026-07-02 | Three Tabler key names verified against Tabler's outline directory (E2 resolved) | `adjustments-horizontal` and `chart-bar` confirmed as exact filename matches. `adjustments-vertical` has no Tabler equivalent — corrected to Tabler `adjustments` (vertical is Tabler's default/unsuffixed form; horizontal is the explicitly-named variant). |
| 2026-07-02 | Migrate-then-restart deployment window accepted as non-issue | This project deploys via Kamal, where migrations run as part of the release process using the new container image. The new `tabler_icons_ruby` gem is already present in that image before traffic cuts over, so there is no window where the database contains new Tabler keys while the running app process still has the old `heroicon` gem loaded. No code changes required; documented as an accepted non-issue given the deploy process. |
| 2026-07-02 | Accept raw Tabler key strings as picker labels — no humanization for settings/settings-2 | On a mobile device, "settings" and "settings-2" are indistinguishable by label text alone while the native select is open. Accepted as a deliberate tradeoff consistent with the existing 14-key picker, which already uses non-humanized raw keys (e.g. "cog-6-tooth", "wrench-screwdriver") with no reported complaints. Introducing a label/value pair abstraction for two keys alone adds unnecessary complexity for a single-admin-user form. |

---

## Dependencies

- SPEC-002 (Services Page) — done. This spec modifies the icon rendering layer only. All SPEC-002 routes, model validations, admin CRUD, and ordering logic remain intact.
- SPEC-003 (i18n) — done. No new i18n keys required.
- SPEC-004 (Admin Backend) — done. No admin auth changes required.
- `gem "tabler_icons_ruby", "~> 3.26"` — must be available on rubygems.org. Verify the exact helper method name and module constant from the gem README before implementing T1 and T5.
- `docs/architecture/ADR-003-icon-library-migration-to-tabler.md` — already created by the architect. `docs/architecture/README.md` already updated. Developer action is forward-reference note on ADR-002 only (T6).

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Gemfile swap: remove `heroicon`, add `tabler_icons_ruby`; remove/replace the orphaned Heroicon comment at Gemfile line 25; update ApplicationHelper include; verify helper method signature and module constant name from gem README; run `bundle install` and commit the regenerated `Gemfile.lock` | AC-1, AC-2 | 1 |
| T2 | Update `ServiceSection::ICON_KEYS` to the 18-entry Tabler array. All 18 keys are fully verified: the 14 mapped keys were confirmed in the previous verification pass (E2); the 4 new-only keys (`engine`, `car-suspension`, `motorbike`, `helmet`) were confirmed via direct query of the Tabler Icons GitHub repo outline directory (E6). No further icon name verification work is required. | AC-3, AC-4, AC-5, AC-6 | 1 |
| T3 | Write data migration: backfill icon_key using explicit 14-key mapping; raise on unknown key (R8c); `down` block must first guard against rows with any of the 4 new-only keys and raise if found (R8d amended; AC-13b), then reverse all 14 mapped pairs for every row — not only the 3 seeded rows (AC-13c) | AC-11, AC-12, AC-13, AC-13b, AC-13c | 3 |
| T4 | Update `db/seeds.rb` with new Tabler icon_key values for all three default sections | AC-14 | 1 |
| T5 | Add `VENDORED_ICON_SVGS` frozen Hash constant (with `car-suspension` SVG sourced verbatim from upstream Tabler, MIT licensed — 6 `<path>` elements, same viewBox/stroke/fill/linecap/linejoin conventions as the gem) and `service_icon(icon_key, css_class:)` helper to `ApplicationHelper`; update all 3 view call sites (`services.html.erb`, `admin/services_pages/show.html.erb`, `admin/service_sections/_form.html.erb`) to call `service_icon(icon_key, css_class: ...)` instead of `tabler_icon(...)` directly; confirm E4 (variant param) and E3 (visual distinction of settings/settings-2) | AC-7, AC-8, AC-9, AC-10, AC-19 | 3 |
| T6 | Add a one-line forward-reference note at the top of `docs/architecture/ADR-002-services-page-icon-rendering-and-ordering.md` stating that Decision 1 (icon rendering library) is superseded by `ADR-003-icon-library-migration-to-tabler.md`. Note: ADR-003 already exists at `docs/architecture/ADR-003-icon-library-migration-to-tabler.md` (created by the architect) and `docs/architecture/README.md` is already updated — no ADR authoring required, only the forward-reference note on ADR-002. | AC-15 | 1 |
| T7 | Update `spec/models/service_section_spec.rb` (ICON_KEYS count 14→18); update all files in R12 to replace Heroicon key strings with Tabler equivalents: `spec/factories/service_sections.rb` (both factories), `spec/requests/admin/service_sections_spec.rb` (lines 44, 65), `spec/requests/pages_spec.rb` (lines 8, 10), `spec/system/admin/service_sections_spec.rb` (lines 27, 49, 74 — exercise care on the Capybara `select` call at ~line 49), `spec/system/admin/services_page_spec.rb` (line 9) | AC-16, AC-17, AC-18 | 2 |

Total estimated points: 12

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-07-02 | Initial draft | All | New spec |
| 2026-07-02 | Corrected `adjustments-vertical` mapping; resolved all three E2 verification flags | Explicit Key Mapping table, ICON_KEYS array, E2, T2, Implementation Decisions | Verified against Tabler Icons GitHub repo (main branch, icons/outline/). `adjustments-vertical` does not exist in Tabler; corrected to `adjustments`. `adjustments-horizontal` and `chart-bar` confirmed exact. `settings` and `settings-2` confirmed exact and visually distinct. All ⚠ flags removed. |
| 2026-07-02 | Applied reviewer (REQUEST_CHANGES), architect, and UX review findings; status promoted to ready | R8(d), R10, R12, E3, E6 (new), AC-1, AC-13b (new), AC-13c (new), AC-15, AT10b (new), AT10c (new), AT13, T1, T2, T3, T6, T7, Implementation Decisions | Reviewer majors: (1) added E6 with hard evidence for 4 new Tabler-only icon names verified via Tabler GitHub tree query; tightened T2 language (all 18 verified, no further work needed); (2) replaced R12 catch-all with explicit enumerated file list including line numbers and Capybara ElementNotFound warning. Reviewer minors: (3) added AC-13c and AT10c to ensure full 14-pair reversal in down block, not just 3 seeded rows; (4) added Gemfile comment note and explicit bundle install/Gemfile.lock step to T1 and AC-1. Architect: (5) amended R8(d) with guard for 4 new-only keys before reversal attempt; (6) added AC-13b; (7) added AT10b; (8) updated R10/AC-15/T6/AT13 to reflect ADR-003 already created — developer action is ADR-002 forward-reference note only. UX: (9) added Kamal deployment-window decision to Implementation Decisions table; (10) added deliberate-tradeoff note to E3 for settings/settings-2 picker label ambiguity, with corresponding Implementation Decisions row. |
| 2026-07-02 | Gem-version-lag amendment: `car-suspension.svg` absent from `tabler_icons_ruby` v3.26.0; added Vendored Icon Fallback interface (`VENDORED_ICON_SVGS` constant and `service_icon` helper); amended R6 to require `service_icon` at all call sites; added vendor-path ACs and AT; noted gem-version-lag in E6; updated T5; status reset to `ready` pending implementation correction | Interfaces (new Vendored Icon Fallback section), View helper call sites table, R6, E6, AC-19 (new), AT15 (new), T5, Status | `tabler_icons_ruby` v3.26.0 does not bundle `car-suspension.svg` (added to upstream Tabler Icons after the January 2025 gem release). Discovered during implementation: developer substituted `steering-wheel`. Two alternatives considered and rejected by the user: (1) `steering-wheel` — semantically inaccurate; (2) dropping the icon. User's explicit choice: vendor the SVG directly in `VENDORED_ICON_SVGS`. `car-suspension` remains the canonical key throughout the spec; the implementation must be corrected to match. |
