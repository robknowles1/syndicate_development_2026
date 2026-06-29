# Spec: Services Page — Dynamic Content with Admin CRUD

**ID:** SPEC-002
**Status:** ready
**Priority:** medium
**Created:** 2026-03-18
**Updated:** 2026-06-29
**Author:** spec-agent

---

## Goal

Deliver a publicly accessible Services page at `/services` whose content is managed entirely through the admin backend. Doug (the shop owner) can add, edit, delete, and reorder service sections, pick an icon for each section, and manage bullet items per section — all without developer involvement. The frontend renders sections in a responsive 3-column grid with inline SVG icons drawn from a curated set.

---

## Non Goals

- Static hardcoded service content in views or locale files (content is DB-driven).
- Individual deep-dive pages per service category (e.g. `/services/engines`).
- Per-section images (replaced by icons in this revision).
- Drag-and-drop reordering (up/down button controls are sufficient).
- Pricing or rate sheets.
- Booking or appointment forms on the Services page (existing `/about` contact form handles inquiries).
- Public user registration or customer accounts.
- Drag handles or sortable JS libraries (no Node/npm).

---

## Definitions

| Term | Definition |
|------|-----------|
| ServiceSection | An ActiveRecord model representing one service category (e.g. "Precision Engines"). Has a heading, icon_key, position, slug, and many ServiceBullets. |
| ServiceBullet | A single bullet-list item belonging to a ServiceSection. Has a body string and a position integer for display ordering. |
| icon_key | A string identifier for a Heroicon (e.g. `"bolt"`). Must be one of the 12 values in `ServiceSection::ICON_KEYS`. |
| position | An integer on ServiceSection that controls display order on the frontend and in the admin list. Lower values appear first. |
| slug | A URL-safe string auto-generated from the section heading via `parameterize`. Not user-editable. Used internally; not exposed in public URLs. |
| ICON_KEYS | The constant array of permitted icon_key values, defined in the ServiceSection model. |
| heroicon gem | A Ruby gem that provides a `heroicon` view helper for rendering Heroicons v2 as inline SVG. |
| services_page_published | A SiteSetting key (boolean string) that controls whether `/services` is publicly accessible. Managed via the existing admin toggle (SPEC-004). |

---

## Interfaces

### Public Frontend

- `GET /services` — renders section cards from DB, guards on `services_page_published`.

### Admin

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/services | `Admin::ServicesPagesController#show` — lists sections, publish toggle |
| PATCH | /admin/services | `Admin::ServicesPagesController#update` — updates publish toggle only |
| GET | /admin/service_sections/new | `Admin::ServiceSectionsController#new` |
| POST | /admin/service_sections | `Admin::ServiceSectionsController#create` |
| GET | /admin/service_sections/:id/edit | `Admin::ServiceSectionsController#edit` |
| PATCH | /admin/service_sections/:id | `Admin::ServiceSectionsController#update` |
| DELETE | /admin/service_sections/:id | `Admin::ServiceSectionsController#destroy` |
| PATCH | /admin/service_sections/:id/move_up | `Admin::ServiceSectionsController#move_up` |
| PATCH | /admin/service_sections/:id/move_down | `Admin::ServiceSectionsController#move_down` |

### Data Model Changes

`service_sections` table — two new columns:

| Column | Type | Constraints |
|--------|------|-------------|
| `icon_key` | string | not null; must be in `ICON_KEYS` |
| `position` | integer | not null, default 0 |

No changes to `service_bullets`.

### Curated Icon List (`ServiceSection::ICON_KEYS`)

```
wrench  wrench-screwdriver  bolt  fire  beaker
adjustments-horizontal  cpu-chip  chart-bar
cog-6-tooth  cog-8-tooth  sparkles  trophy
```

> Note: if no section maps to polishing or detailing, `sparkles` may be swapped for `shield-check` before implementation. Update both `ICON_KEYS` and the migration backfill together if changed.

Default icon assignments for the three seeded sections:

| Section slug | icon_key | position |
|---|---|---|
| precision_engines | cog-6-tooth | 0 |
| custom_suspension_setup | adjustments-horizontal | 1 |
| ecu_tuning | cpu-chip | 2 |

---

## Rules

R1: `GET /services` renders `ServiceSection` records ordered by `position` ascending. It does not render when `services_page_published` is `false` — instead it redirects to `/` (behaviour inherited from SPEC-004; no change required).

R2: Each section card on `/services` displays three elements in order: (a) the section's icon rendered as inline SVG via the heroicon gem using `icon_key`, (b) the `heading`, (c) the ordered list of bullet bodies.

R3: The frontend grid uses Tailwind responsive classes: 1 column below md (< 768 px), 2 columns at md–lg (768–1023 px), 3 columns at lg and above (≥ 1024 px).

R4: `icon_key` must be one of the 12 values in `ServiceSection::ICON_KEYS`. The model validates inclusion. Any other value is a validation error.

R5: `position` is required and integer. On create, the controller assigns `position = (ServiceSection.maximum(:position) || -1) + 1` so new sections always append to the end.

R6: Admin can create a section. A valid creation requires heading (non-blank string), icon_key (from ICON_KEYS), and at least one bullet body (non-blank string).

R7: Admin can edit a section's heading, icon_key, and bullet items. Editing supports adding new bullets, modifying existing bullet text, and marking existing bullets for destruction — all in one form submit using Rails nested attributes. The bullet editor follows the pattern established in `admin/services_pages/show.html.erb`: one text field per bullet, a `_destroy` checkbox to mark a bullet for removal, and a Stimulus-controlled "Add bullet" control that appends a new unsaved row. The existing `bullet-editor` Stimulus controller should be adapted for the nested attributes param structure of `ServiceSection`.

R8: Admin can delete a section. Deletion destroys all associated `ServiceBullet` records via `dependent: :destroy`. There is no minimum section count; the services page may display zero sections.

R9: Admin can reorder sections via "Move Up" and "Move Down" controls. Each control submits a PATCH to the corresponding member route. The controller swaps the `position` values of the target section and its immediate neighbour in a single database transaction. Immediate neighbour is defined as the record with the nearest `position` value strictly less than (for move_up) or strictly greater than (for move_down) the target's position — found via `where('position < ?', target.position).order(position: :desc).first` and the equivalent ascending query for move_down. Using arithmetic `position - 1` or `position + 1` is incorrect when gaps exist after deletions.

R10: Move Up on the section with the lowest `position` value is a no-op (no change, no error). Move Down on the section with the highest `position` value is a no-op.

R11: A section must have at least one bullet not marked for destruction at the time of save. Attempting to save with zero surviving bullets is rejected with a model validation error (`errors.add(:base, :at_least_one_bullet)`).

R12: `slug` is auto-generated from `heading` via `before_validation :generate_slug_from_heading` using `heading.parameterize(separator: "_")`. If the generated slug collides with an existing record (excluding self), a numeric suffix is appended (e.g. `precision_engines_2`). `slug` is not exposed in any public URL or admin form field. The callback must guard with `will_save_change_to_heading?` (or `return unless heading_changed?`) to avoid regenerating the slug on unrelated saves.

R13: The section edit form (`Admin::ServiceSectionsController`) takes over all bullet editing responsibility. The bulk-update path in `Admin::ServicesPagesController#update` (which previously accepted `params[:service_sections]`) is removed; `ServicesPagesController#update` handles only `params[:published]`.

R14: All admin-facing UI strings (labels, button text, flash messages, headings) are rendered via `t()` from `config/locales/en.yml` under the `admin.service_sections` namespace. No hardcoded strings. Required keys:

| Key | Purpose |
|-----|---------|
| `heading` | Section heading field label |
| `icon_key_label` | Icon select field label |
| `bullets_label` | Bullet list field label |
| `add_bullet` | "Add bullet" control text |
| `save` | Form submit button |
| `edit` | Edit control |
| `delete` | Delete control |
| `move_up` | Move Up control |
| `move_down` | Move Down control |
| `confirm_delete` | `data-turbo-confirm` dialog text |
| `add_first` | CTA link text when no sections exist |
| `bullet_minimum_hint` | Hint surfacing the at-least-one-bullet constraint |
| `flash.created` | Success flash after create |
| `flash.updated` | Success flash after update |
| `flash.destroyed` | Success flash after delete |
| `flash.moved` | Success flash after move_up/move_down |

R15: Page-level frontend strings (page heading, nav label, empty state message) use `t()`. Required keys: `pages.services.heading`, `nav.services`, `pages.services.empty_message`. Section headings and bullet body text come from DB fields and are rendered directly — they are not passed through i18n.

---

## Edge Cases

E1: If `service_sections` has no records and `services_page_published` is true, `GET /services` returns HTTP 200 and renders only the page-level heading with an empty content area. This is not an error state.

E2: Attempting to move the section at the lowest position further up, or the section at the highest position further down, performs no position change and redirects back to `/admin/services` without an error flash.

E3: Deleting the last remaining section is allowed. The services page then renders with no cards (see E1).

E4: If a section's heading changes to a value whose `parameterize` output collides with an existing slug, the auto-generation logic appends a numeric suffix rather than raising a uniqueness error to the user.

E5: When no service sections exist, `GET /admin/services` renders a localised "No service sections yet" message and a prominent call-to-action link to `admin_new_service_section_path` using `t('admin.service_sections.add_first')`. The section list table and its controls are not rendered.

---

## Acceptance Criteria

### Frontend

AC-1: Given `services_page_published` is `true`, when `GET /services`, then HTTP 200 and the page renders section cards loaded from the DB, ordered by `position` ascending.

AC-2: Given `services_page_published` is `false`, when `GET /services`, then the response redirects to `/` with no error message shown to the visitor.

AC-3: Given a section with `icon_key` `"bolt"` exists at position 0, when `GET /services` (published), then the rendered HTML includes an inline `<svg>` element corresponding to the bolt icon produced by the heroicon helper.

AC-4: Given multiple sections, when `/services` is rendered at a ≥ 1024 px viewport, then sections are displayed in a 3-column grid in ascending position order.

AC-4a: Given multiple sections, when `/services` is rendered at a viewport width between 768 px and 1023 px, then sections are displayed in a 2-column grid.

AC-5: The page-level heading uses `t("pages.services.heading")`; the nav link uses `t("nav.services")`. Section headings and bullet text are rendered from DB values, not from i18n keys.

AC-6: Given `service_sections` is empty and `services_page_published` is `true`, when `GET /services`, then HTTP 200 and only the page-level heading renders — no section cards, no error. The empty content area includes a localised message `t('pages.services.empty_message')` (e.g. "Contact us to learn about our services").

### Admin Section Management

AC-7: Given admin is logged in, when `GET /admin/services`, then all sections are listed in `position` order, each showing the heading, an icon preview (inline SVG rendered via the heroicon helper matching the section's `icon_key`), bullet count, and controls in this order: Move Up and Move Down together, then Edit, then Delete last — visually separated from Edit by a minimum `ml-4` gap and styled `text-red-600`. If no sections exist, the empty state described in E5 is rendered instead.

AC-8: Given admin is logged in, when `GET /admin/service_sections/new`, then a form renders with: (a) a heading text input; (b) an icon_key select from the curated list, with a live preview pane showing the selected icon as an inline SVG — driven by a Stimulus controller that toggles visibility among 12 pre-rendered hidden icon spans on `change`, requiring no page reload; (c) a bullet list editor with at least one bullet row and an add-bullet control — the editor follows the pattern in `admin/services_pages/show.html.erb` (text field per bullet, `_destroy` checkbox, Stimulus-controlled "Add bullet" that appends a new row); (d) bullet rows marked for `_destroy` receive a visual indicator (line-through text decoration and reduced opacity); (e) a hint `t('admin.service_sections.bullet_minimum_hint')` below the bullet list surfaces the at-least-one-bullet constraint.

AC-9: Given admin is logged in and 2 sections exist (positions 0 and 1), when `POST /admin/service_sections` with valid heading, icon_key, and one bullet, then a new section is created with `position = 2`, and the response redirects to `GET /admin/services` with a success flash.

AC-10: Given admin is logged in and an existing section, when `GET /admin/service_sections/:id/edit`, then the form is pre-populated with the section's current heading, icon_key (pre-selected in the dropdown), and all existing bullet rows.

AC-11: Given admin is logged in, when `PATCH /admin/service_sections/:id` with a changed heading, then the section's heading is updated in the DB and the response redirects to `GET /admin/services` with a success flash.

AC-12: Given admin is logged in and a section with 3 bullets, when `DELETE /admin/service_sections/:id`, then the section and all 3 bullets are destroyed and the response redirects to `GET /admin/services` with a success flash. The Delete control carries a `data-turbo-confirm` attribute with the value of `t('admin.service_sections.confirm_delete')`; the admin must confirm before the DELETE request is issued.

AC-13: Given admin is logged in and sections at positions 0 (A) and 1 (B), when `PATCH /admin/service_sections/:id_of_B/move_up`, then section B has `position = 0` and section A has `position = 1`, and the response redirects to `GET /admin/services` reflecting the new order.

AC-14: Given admin is logged in and section A is at the lowest position, when `PATCH /admin/service_sections/:id_of_A/move_up`, then no position changes occur and the response redirects to `GET /admin/services`.

AC-15: Given admin is logged in, when `POST /admin/service_sections` with all bullet bodies blank or all bullets removed, then HTTP 422, the form re-renders with a validation error message, and no section is created.

AC-16: Given admin is logged in, when `POST /admin/service_sections` with `icon_key = "invalid_icon"`, then HTTP 422, the form re-renders with a validation error message, and no section is created.

### Data Model and Migration

AC-17: A migration adds `icon_key` (string) to `service_sections` using a three-step pattern: (1) add the column as nullable, (2) backfill existing rows by slug inside the migration (`precision_engines` → `"cog-6-tooth"`, `custom_suspension_setup` → `"adjustments-horizontal"`, `ecu_tuning` → `"cpu-chip"`) using `ServiceSection.reset_column_information` followed by individual `update_column` calls, (3) add the NOT NULL constraint with `change_column_null :service_sections, :icon_key, false`. Steps 1–3 run inside a `reversible { |dir| dir.up { ... } }` block.

AC-18: A migration adds `position` (integer, not null, default 0) to `service_sections`.

AC-19: The seeds file is updated so each of the three existing sections receives an explicit `icon_key` and `position`. Seeds remain idempotent (`find_or_create_by` or equivalent). New columns are also set when a section is found-or-created. The seeds should no longer pass `slug:` explicitly — the `before_validation` callback generates it from `heading`. The `find_or_create_by` lookup should use `heading:` (or derive the slug via `heading.parameterize(separator: '_')` for lookup). Confirm the generated slugs: `"PRECISION ENGINES"` → `"precision_engines"`, `"CUSTOM SUSPENSION SETUP"` → `"custom_suspension_setup"`, `"ECU TUNING"` → `"ecu_tuning"`.

---

## Acceptance Tests

AT1
Given `services_page_published` is `true` and three sections exist at positions 0, 1, 2 with headings "A", "B", "C"
When `GET /services`
Then HTTP 200 and the response body includes "A", "B", "C" in that order
Covers: R1, R3

AT2
Given `services_page_published` is `false`
When `GET /services`
Then the response redirects to `root_path`
Covers: R1

AT3
Given a section with `icon_key` `"bolt"` and `services_page_published` is `true`
When `GET /services`
Then the response body includes `<svg` (inline SVG output from the heroicon helper)
Covers: R2, R4

AT4
Given `service_sections` is empty and `services_page_published` is `true`
When `GET /services`
Then HTTP 200 and body includes the value of `t("pages.services.heading")` and does not include any section heading text (no section records exist to render)
Covers: R1, E1

AT5
Given admin is authenticated
When `GET /admin/services`
Then HTTP 200 and all section headings appear in the response body in position order
Covers: AC-7

AT6
Given admin is authenticated and 2 sections exist
When `POST /admin/service_sections` with `{ heading: "Frame Fab", icon_key: "wrench", service_bullets_attributes: [{ body: "Custom chromoly frames", position: 0 }] }`
Then a new `ServiceSection` exists with `heading = "Frame Fab"` and `position = 2`, and the response redirects to `admin_services_page_path`
Covers: R5, R6

AT7
Given admin is authenticated and a section exists with heading "OLD HEADING"
When `PATCH /admin/service_sections/:id` with `{ heading: "NEW HEADING" }`
Then the section's heading in the DB is "NEW HEADING" and the response redirects to `admin_services_page_path`
Covers: R7

AT8
Given admin is authenticated and a section with 3 bullets exists
When `DELETE /admin/service_sections/:id`
Then `ServiceSection.find_by(id: id)` returns nil and `ServiceBullet.where(service_section_id: id).count` is 0
Covers: R8

AT9
Given admin is authenticated and two sections: A at position 0, B at position 1
When `PATCH /admin/service_sections/:id_of_B/move_up`
Then A has position 1 and B has position 0
Covers: R9, R10

AT10
Given admin is authenticated and section A is at the minimum position among all sections
When `PATCH /admin/service_sections/:id_of_A/move_up`
Then A's position is unchanged
Covers: R10, E2

AT11
Given admin is authenticated
When `POST /admin/service_sections` with no bullet attributes (or all bullet bodies blank)
Then HTTP 422 and no new `ServiceSection` row exists
Covers: R11

AT12
Given admin is authenticated
When `POST /admin/service_sections` with `icon_key = "invalid_icon"`
Then HTTP 422 and no new `ServiceSection` row exists
Covers: R4, AC-16

AT13
Given a section heading changes from "Engines" to "Precision Engines" and a slug "precision_engines" already exists on another section
When the model runs `before_validation`
Then the slug is set to "precision_engines_2" (or another non-colliding suffix) and the record saves without a uniqueness error
Covers: R12 (slug auto-generation, E4)

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-29 | Icon stored as string key in DB, not as file upload | Keeps the icon set curated and avoids asset management complexity. The curated list is defined as a Ruby constant in the model, used by both validation and the admin form. |
| 2026-06-29 | Reorder via up/down button forms, not drag-and-drop | Stack has no Node/npm. Stimulus + Turbo can enhance with smooth re-renders, but the core behaviour requires only standard HTML form submits. |
| 2026-06-29 | Section CRUD in `Admin::ServiceSectionsController`, not in `Admin::ServicesPagesController` | Separates publish-toggle responsibility from section CRUD per architecture layering rules (thin controllers, single responsibility). |
| 2026-06-29 | Bulk-section-update path removed from `ServicesPagesController#update` | That path (keyed by slug) is superseded by ID-routed CRUD actions. Removing it reduces dead code and prevents accidental double-update paths. |
| 2026-06-29 | `position` assigned as max+1 on create, not re-sequenced on delete | Avoids expensive re-numbering queries. Gaps in position values are harmless; `order(:position)` still produces correct display order. |

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. Layout, nav partial, Tailwind, asset pipeline in place.
- SPEC-003 (i18n String Extraction) — done. All new UI strings follow the `t()` / `en.yml` pattern.
- SPEC-004 (Admin Backend) — done. Authentication, `Admin::BaseController`, `SiteSetting`, publish toggle, and the initial bullet-edit UI are all live. This spec extends the admin and changes the section-editing surface.
- `gem "heroicon", "~> 1.0"` — must be added to the Gemfile before T4 can be implemented. The gem renders Heroicons v2 as inline SVG via a `heroicon(name, variant: :outline)` view helper with no asset pipeline dependency.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Migration: add `icon_key` and `position` to `service_sections`; update seeds with icon/position values; update model validations and `ICON_KEYS` constant; add `before_validation` for slug generation | AC-17, AC-18, AC-19, R4, R11, R12 | 2 |
| T2 | Add `Admin::ServiceSectionsController` with `new`, `create`, `edit`, `update`, `destroy`, `move_up`, `move_down` actions; add routes; strip bulk-update path from `ServicesPagesController#update` (R13); update `Admin::ServicesPagesController#show` to use `.order(:position)` instead of `.order(:slug)` | AC-9, AC-11, AC-12, AC-13, AC-14, R5, R9, R10, R13 | 3 |
| T3 | Admin views: update `services_pages/show` to list sections with position, icon preview, edit/delete/move controls (including E5 empty state and `data-turbo-confirm` on delete); create `service_sections/new` and `edit` forms with icon dropdown + live preview Stimulus controller and bullet editor | AC-7, AC-8, AC-10, AC-15, AC-16, R14 | 3 |
| T4 | Frontend services page: update `pages/services` to load sections from DB ordered by position; replace existing `md:grid-cols-3` with `md:grid-cols-2 lg:grid-cols-3` for the 3-step responsive layout (R3); render heroicon SVG per section; update `PagesController#services` to use `.order(:position)` instead of `.order(:slug)` | AC-1, AC-2, AC-3, AC-4, AC-4a, AC-5, AC-6, R1, R2, R3, R15 | 3 |
| T5 | Tests: model specs (validations, slug generation, position assignment, move logic); request specs (CRUD actions, move actions, frontend 200/redirect); system specs (admin section CRUD flow, frontend renders seeded sections) | All ATs | 3 |

Total estimated points: 14

---

## Technical Guidance

See [ADR-002](/docs/architecture/ADR-002-services-page-icon-rendering-and-ordering.md) for the full rationale behind decisions in this section.

### Gem addition

Add `gem "heroicon", "~> 1.0"` to the Gemfile. The gem renders Heroicons v2 as inline SVG via a `heroicon(name, variant: :outline)` view helper. It has no asset pipeline dependency and requires no Propshaft configuration. Pin to `~> 1.0` to stay on the Heroicons v2 bundle.

Verify each icon name in `ICON_KEYS` works with the helper before shipping (call `heroicon(key)` in a test or the console — an unrecognised name raises at render time, not at boot).

### Migration: `icon_key NOT NULL` on a populated table

PostgreSQL rejects `ADD COLUMN ... NOT NULL` without a default when rows already exist. The `service_sections` table has seeded rows. The migration must use a three-step pattern:

1. Add `icon_key` as nullable.
2. Backfill existing rows by slug (call `ServiceSection.reset_column_information` first).
3. Add the `NOT NULL` constraint with `change_column_null :service_sections, :icon_key, false`.

Do this inside a `reversible { |dir| dir.up { ... } }` block. The `position` column can be added with `null: false, default: 0` in a single step — PostgreSQL will backfill the default for existing rows without a separate step.

Full migration guidance is in ADR-002 Implementation Notes.

### Position swap: use nearest-neighbour query, not `position ± 1`

Positions can have gaps after deletions (by design — R5 and the Implementation Decisions table). The `move_up` and `move_down` actions must query for the section with the nearest lower or higher `position` value:

```ruby
# move_up
neighbour = ServiceSection.where("position < ?", section.position).order(position: :desc).first

# move_down
neighbour = ServiceSection.where("position > ?", section.position).order(position: :asc).first
```

Using `position - 1` or `position + 1` will silently no-op on gapped sequences. Wrap both `update_column` calls in `ActiveRecord::Base.transaction`.

### Slug regeneration guard

The `before_validation :generate_slug_from_heading` callback should only run when `heading` has changed. Guard it with `return unless will_save_change_to_heading?` (or `heading_changed?` inside a `before_validation` block). Regenerating on every save is unnecessary and risks an unintended slug change when an unrelated attribute is updated.

### Controller cleanup

Remove `ServicesPagesController#update_service_sections`, its private helper `#service_section_update_params`, and the `elsif params[:service_sections].present?` branch from `#update`. Change the `@sections` query in `#show` from `.order(:slug)` to `.order(:position)`.

### Route structure

```ruby
namespace :admin do
  resource  :services_page,    only: [:show, :update]
  resources :service_sections, only: [:new, :create, :edit, :update, :destroy] do
    member do
      patch :move_up
      patch :move_down
    end
  end
end
```

This produces all nine routes in the Interfaces table and conforms to Rails conventions.

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-06-29 | Full spec revision. Original draft (static, no model, no admin CMS) replaced with DB-driven content, admin CRUD for sections, icon support, and position ordering. All original ACs 1–10 replaced. | All | Original spec was blocked pending admin auth (SPEC-004, now done). Requirements evolved to full content management rather than static copy. |
