# ADR-001: Service Content Storage

**Status:** Accepted
**Date:** 2026-05-19
**Deciders:** Architect agent

---

## Context

SPEC-004 introduces an admin backend where the shop owner can edit the Services page. The Services page contains three fixed service sections (Precision Engines, Custom Suspension Setup, ECU Tuning). Each section has a heading and a variable-length list of bullet items. The admin must be able to add, edit, and remove individual bullet items within the same form submit.

Two storage approaches were on the table. The choice is a schema-level decision that is hard to reverse once SPEC-002 (the public Services page) is built on top of it.

---

## Decision

**Option A — two database tables (`service_sections` and `service_bullets`) is adopted.**

Exact schema:

**`service_sections`**

| column | type | constraints |
|---|---|---|
| `id` | bigint | PK |
| `slug` | string | not null, unique, indexed — e.g. `"precision_engines"` |
| `heading` | string | not null |
| `created_at` | datetime | |
| `updated_at` | datetime | |

**`service_bullets`**

| column | type | constraints |
|---|---|---|
| `id` | bigint | PK |
| `service_section_id` | bigint | FK → `service_sections.id`, not null, indexed |
| `body` | string | not null |
| `position` | integer | not null, default 0 — used for display ordering |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Model associations and behaviour:

- `ServiceSection has_many :service_bullets, -> { order(:position) }, dependent: :destroy`
- `ServiceSection accepts_nested_attributes_for :service_bullets, allow_destroy: true, reject_if: :all_blank`
- `ServiceBullet belongs_to :service_section`
- Validation on `ServiceSection`: must have at least one associated bullet after the nested attributes are applied (custom validation, not just presence — `reject_if: :all_blank` alone does not enforce a minimum count).
- The three sections are created by `db/seeds.rb` using their slugs as stable identifiers. Seeds are idempotent: `ServiceSection.find_or_create_by(slug: ...)`.
- The `slug` column is the stable identifier used by seeds, controllers, and view lookups. Do not rely on `id` ordering for display — use an explicit scope or the slug.

---

## Rationale

Bullet items are variable in count per section and must be individually addressable (editable body text, independently removable, orderable). This is a one-to-many relationship, and the relational database handles it directly and cleanly.

Rails' `accepts_nested_attributes_for` with `allow_destroy: true` is the standard, well-understood mechanism for this exact pattern. It works without JavaScript and is fully compatible with Turbo form submissions.

Option B introduces a forced mapping from a structured one-to-many relationship to flat string key-value pairs. There is no clean way to represent `["item 1", "item 2", "item 3"]` as a `{ key, value }` override without either serialising the array into a single string value (losing individual editability) or inventing a position-keyed naming scheme (`services.precision_engines.bullets.0`, `services.precision_engines.bullets.1`, …) that is fragile and opaque. Either path adds accidental complexity without any compensating benefit.

The i18n work from SPEC-003 is not wasted. The locale file remains the authoritative source for all static UI strings (labels, headings, admin interface copy). Dynamic content — the section headings and bullet bodies that Doug edits — belongs in the database, not the locale file. These are two different concerns.

---

## Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|---|---|---|---|
| **B — Locale file + `ContentOverride` key-value table** | Preserves SPEC-003 i18n extraction; one generic table | Arrays do not map to string overrides cleanly; custom key-naming convention required; harder to validate minimum bullet count; more complex view helper indirection | The core data shape (variable-length ordered list) is a poor fit for flat key-value storage. The workaround complexity exceeds any benefit. |
| **A with JSON column** | Single table; no join needed | Loses individual row addressability; Rails nested attributes do not work against a JSON column; harder to validate individual items | Unnecessary cleverness. Two normalised tables are simpler and more maintainable. |

---

## Consequences

### Positive

- Standard Rails patterns throughout: migrations, validations, nested attributes, `dependent: :destroy`.
- No custom indirection layer in views — `@section.service_bullets.each` is direct and readable.
- Bullet ordering is explicit via the `position` integer column; drag-and-drop reordering is straightforward to add later if needed.
- Each bullet is a first-class database row — individual validation, individual destroy, no serialisation.

### Negative

- The three sections are seeded data, not code. If a future developer adds a fourth section type, they must write a migration and a seed entry, not just add a YAML key. This is a minor friction for a fixed-content site.
- Slightly more migration surface than a single-table design.

### Risks

- **Seed idempotency.** If `db:seed` is run multiple times, sections must not be duplicated. Mitigated by using `find_or_create_by(slug: ...)` in seeds. The developer must test this explicitly.
- **bcrypt gem is commented out.** The `Gemfile` contains `# gem "bcrypt", "~> 3.1.7"` (commented). `has_secure_password` on `AdminUser` will raise a `LoadError` at runtime until this line is uncommented and `bundle install` is run. **The developer must uncomment the bcrypt gem line as the first step of implementation.**

---

## Implementation Notes

1. Uncomment `gem "bcrypt", "~> 3.1.7"` in `Gemfile` and run `bundle install` before any other work.
2. Generate migrations in this order: `admin_users` → `site_settings` → `service_sections` → `service_bullets`. Run them together before writing any model code.
3. Add a composite index on `service_bullets(service_section_id, position)` — this is the natural query pattern.
4. The `db/seeds.rb` file should seed in dependency order: `AdminUser`, `SiteSetting`, then `ServiceSection` with nested `ServiceBullet` records. Use initial content derived from the current static copy (match what is on the existing static Services page concept).
5. The admin form for service sections should use `fields_for :service_bullets` inside the `form_with` block. Each bullet needs a hidden `_destroy` field rendered when the admin marks it for removal. A Stimulus controller can handle add/remove bullet UI without a full page reload; standard form submit persists the result.
6. The minimum-one-bullet validation must be a custom validator on `ServiceSection` that counts bullets not marked for destruction after `accepts_nested_attributes_for` has processed the params. The `reject_if: :all_blank` option on its own is not sufficient to enforce a minimum.
7. Controller routes for service section content editing should operate through `Admin::ServicesPagesController` (already specified in the spec) rather than adding separate nested resource routes — the single-page management UI can handle all three sections in one form, one `update` action, and one `PATCH` request.
