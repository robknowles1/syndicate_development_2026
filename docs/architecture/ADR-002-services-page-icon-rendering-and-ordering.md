# ADR-002: Services Page Icon Rendering and Section Ordering

**Status:** accepted
**Date:** 2026-06-29

---

## Context

SPEC-002 adds dynamic content management to the Services page. Two architectural decisions beyond the existing data model (ADR-001) need to be locked before implementation begins:

1. How to render per-section icons as inline SVG without a Node/npm build step.
2. How to implement display ordering and reordering for `ServiceSection` records.

A third decision — how to structure the admin controllers — modifies the guidance in ADR-001 and is recorded here so there is no ambiguity.

---

## Decision 1: Icon Rendering via the `heroicon` gem

Add `gem "heroicon"` (current version 1.0.0, Heroicons v2) to the Gemfile. Use the `heroicon(name, variant: :outline)` view helper to render each section's icon as inline SVG.

Rejected alternatives:

| Option | Rejected Because |
|--------|-----------------|
| `heroicons` gem (plural, v2.2.0) | Less widely adopted, no meaningful technical advantage |
| Inline SVG files committed to the repo | 12 SVG files to maintain; no helper; harder to validate icon_key at the view layer |
| `<img>` tags pointing to SVG files | Requires asset pipeline wiring; icons cannot be styled with CSS `currentColor` |
| SVG sprite sheet | Requires a build step or manual concatenation; no Node/npm in this project |

The `heroicon` gem renders SVG strings directly from bundled gem files at runtime. It has no asset pipeline dependency and therefore requires no Propshaft configuration. There is no risk of Sprockets-style manifest issues.

---

## Decision 2: Section Ordering via Integer Position Column

`ServiceSection` gains an integer `position` column. Display order is `ServiceSection.order(:position)`. Reordering is implemented by swapping the `position` values of two adjacent sections in a single `ActiveRecord::Base.transaction` block.

This extends the identical pattern already used for `ServiceBullet#position` (ADR-001) and keeps the implementation uniform.

Rejected alternatives:

| Option | Rejected Because |
|--------|-----------------|
| `acts_as_list` gem | Adds a dependency for a 12-line problem; the swap pattern is trivial to implement directly |
| Timestamp-based ordering | No semantic meaning for admin reordering; non-obvious |
| Full re-sequence on every reorder | O(n) writes instead of O(2); not worth it for a single-admin site with a small section count |

Positions are assigned as `max + 1` on create and are never re-sequenced after deletes. Gaps are harmless: `order(:position)` is correct regardless of gaps.

---

## Decision 3: Controller Split (supersedes ADR-001 Implementation Note 7)

ADR-001 note 7 recommended routing all section editing through `Admin::ServicesPagesController`. That recommendation was scoped to SPEC-004's bulk-edit UI (one form, all sections at once).

SPEC-002 replaces the bulk-edit path with per-section CRUD. A new `Admin::ServiceSectionsController` handles `new`, `create`, `edit`, `update`, `destroy`, `move_up`, and `move_down`. `Admin::ServicesPagesController#update` handles only the publish toggle (`params[:published]`); the `update_service_sections` branch is removed.

This conforms to the thin-controller / single-responsibility rule (architecture.md §1.3) and makes each controller's scope unambiguous.

---

## Consequences

### Positive

- Inline SVG from the heroicon gem supports CSS `currentColor` theming — icons inherit text colour with no extra markup.
- No asset pipeline changes required for icon rendering.
- The swap-position pattern is fully transactional and safe for the single-admin deployment model.
- Removing the `update_service_sections` branch from `ServicesPagesController` eliminates a dual-write path that would otherwise remain as dead code.

### Negative

- Adding the heroicon gem is a new external dependency. If the gem is abandoned or stops shipping Heroicons v2 icons, the icon set is frozen at the installed gem version. For 12 curated icons on a low-change site, this is an acceptable risk.
- The swap-position implementation has a non-obvious correctness requirement (see Risks below).

### Risks

- **Heroicons v2 icon name compatibility.** The `ICON_KEYS` constant uses Heroicons v2 names (`cog-6-tooth`, `adjustments-horizontal`, `cpu-chip`, etc.). The heroicon gem at v1.0.0 ships Heroicons v2. The developer must pin the gem to `~> 1.0` to avoid picking up any future version that changes the bundled icon set. Verify each icon name passes `heroicon(key)` without raising before shipping.
- **"Immediate neighbour" means nearest position value, not `position ± 1`.** Because gaps can exist after deletes, the `move_up` action must find the section with the highest `position` value strictly less than the target's position, and `move_down` must find the section with the lowest `position` value strictly greater than the target's. Using `position - 1` or `position + 1` will silently no-op on gapped sequences. See Implementation Notes.

---

## Implementation Notes

### Migration for `icon_key` (NOT NULL on a populated table)

PostgreSQL rejects `ADD COLUMN ... NOT NULL` without a default when the table has existing rows. The `service_sections` table will have seeded rows at migration time. Use a three-step pattern inside the migration:

```ruby
def change
  add_column :service_sections, :position, :integer, null: false, default: 0

  add_column :service_sections, :icon_key, :string  # nullable initially

  # Backfill seeded rows by slug before adding the NOT NULL constraint.
  # reset_column_information is required so ActiveRecord sees the new column.
  reversible do |dir|
    dir.up do
      ServiceSection.reset_column_information
      {
        "precision_engines"          => "cog-6-tooth",
        "custom_suspension_setup"    => "adjustments-horizontal",
        "ecu_tuning"                 => "cpu-chip"
      }.each do |slug, icon|
        ServiceSection.where(slug: slug).update_all(icon_key: icon, position: ["precision_engines", "custom_suspension_setup", "ecu_tuning"].index(slug))
      end
      change_column_null :service_sections, :icon_key, false
    end
  end
end
```

Alternatively, split into two migrations: one that adds the nullable column, and a second that backfills and adds the constraint. Either approach is acceptable.

### Gap-tolerant swap query

```ruby
# move_up: find the section with the nearest lower position
neighbour = ServiceSection
  .where("position < ?", section.position)
  .order(position: :desc)
  .first

# move_down: find the section with the nearest higher position
neighbour = ServiceSection
  .where("position > ?", section.position)
  .order(position: :asc)
  .first
```

If `neighbour` is nil, it is a no-op (R10). Wrap both `update_column` calls in `ActiveRecord::Base.transaction`.

### Slug regeneration scope

The `before_validation :generate_slug_from_heading` callback should only regenerate the slug when `heading` has changed (use `will_save_change_to_heading?` or a `heading_changed?` guard). Regenerating on every validation pass is unnecessary and risks breaking a stable slug when heading is unchanged.

### Admin routes

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

This produces the route table specified in the Interfaces section of SPEC-002.

### Dead code removal

Remove `ServicesPagesController#update_service_sections` and the private `#service_section_update_params` method. Remove the `elsif params[:service_sections].present?` branch from `#update`. The show action's `@sections` query must be changed from `.order(:slug)` to `.order(:position)`.
