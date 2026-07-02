# ADR-003: Icon Library Migration — Heroicons to Tabler Icons

**Status:** accepted
**Date:** 2026-07-02
**Deciders:** architect-agent
**Supersedes:** ADR-002 Decision 1 (icon rendering via the `heroicon` gem)

---

## Context

ADR-002 Decision 1 adopted the `heroicon` gem (Heroicons v2) for inline SVG icon rendering on the Services page. The Heroicons v2 set lacks automotive vocabulary that is central to a motocross/supercross shop: no `engine`, `suspension`, `motorbike`, or `helmet` icon exists. SPEC-005 expands `ServiceSection::ICON_KEYS` from 14 to 18 entries to include those four icons. Tabler Icons v3 provides all four as first-class named icons.

The rendering pattern chosen in ADR-002 — bundle SVGs in a gem, render as inline SVG via a Rails view helper, no asset pipeline dependency — remains the correct approach. Only the icon library changes.

ADR-002 Decisions 2 and 3 (section ordering; controller split) are unaffected and remain accepted.

---

## Decision

Replace `gem "heroicon", "~> 1.0"` with `gem "tabler_icons_ruby", "~> 3.26"`. The `heroicon(...)` view helper is replaced with the tabler_icons_ruby equivalent at all three call sites. `ServiceSection::ICON_KEYS` is updated to the 18-entry Tabler key array defined in SPEC-005. A data migration backfills all existing `icon_key` values from Heroicon names to their Tabler equivalents using the explicit mapping table below.

---

## Rationale

Tabler Icons v3 satisfies every requirement that led to choosing Heroicons in ADR-002, and adds the automotive vocabulary Heroicons lacks:

- Renders inline SVG from gem-bundled files. No Propshaft or Sprockets configuration required. CSS `currentColor` inheritance preserved.
- MIT licence. No legal or commercial risk.
- The `tabler_icons_ruby` gem follows the same include-module-in-ApplicationHelper pattern as `heroicon`. The integration surface is identical; only the method name and module constant differ.
- A single icon system eliminates visual inconsistency from mixed SVG stroke weights and styles. Coexisting both gems is explicitly rejected (see Alternatives Considered).

---

## Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|--------|------|------|-----------------|
| Dual-gem coexistence (keep heroicon for old keys, add tabler for new) | Zero migration risk; no data change | Two icon systems with different stroke weights produce visible inconsistency; two ApplicationHelper includes; complexity for a 3-call-site surface | Visual inconsistency is unacceptable; complexity is unjustified for 3 call sites |
| Commit 4 Tabler SVG files to the repo and render with `inline_svg` or direct `File.read` | No new gem dependency | 4 files to maintain manually; no helper; harder to validate `icon_key` at the view layer; inconsistent rendering path for existing 14 icons | Adds maintenance burden without benefit; doesn't resolve the heroicon call-site debt |
| Switch to Heroicons v2 icon that approximates automotive (e.g. `cog` for engine) | Stays on existing gem | No true `engine` or `motorbike` icon in Heroicons v2; approximations are semantically misleading for shop tooling | Product requirement is specific automotive icons, not approximations |

---

## Heroicon → Tabler Key Mapping (historical record)

This table is the authoritative source used in the SPEC-005 data migration and `ICON_KEYS` update.

| Old Heroicon key | New Tabler key | Notes |
|-----------------|---------------|-------|
| `wrench` | `tool` | |
| `wrench-screwdriver` | `tools` | |
| `bolt` | `bolt` | unchanged |
| `fire` | `flame` | |
| `beaker` | `flask` | |
| `adjustments-horizontal` | `adjustments-horizontal` | exact filename match confirmed in Tabler outline directory |
| `adjustments-vertical` | `adjustments` | Tabler naming is inverted: `adjustments` (unsuffixed) is the vertical-sliders form; `adjustments-horizontal` is the explicit horizontal variant. No `adjustments-vertical` file exists in Tabler. |
| `cpu-chip` | `cpu` | |
| `chart-bar` | `chart-bar` | exact filename match confirmed |
| `cog-6-tooth` | `settings` | exact filename match confirmed |
| `cog-8-tooth` | `settings-2` | exact filename match confirmed; visually distinct from `settings` |
| `cube` | `cube` | unchanged |
| `sparkles` | `sparkles` | unchanged |
| `trophy` | `trophy` | unchanged |

New icons added (no Heroicon predecessor):

| New Tabler key | Represents |
|---------------|-----------|
| `engine` | Internal combustion engine |
| `car-suspension` | Suspension geometry |
| `motorbike` | Motorbike silhouette |
| `helmet` | Riding helmet |

---

## Consequences

### Positive

- Automotive icons (`engine`, `car-suspension`, `motorbike`, `helmet`) are now expressible as first-class picker options — the core product requirement.
- Single icon library, uniform stroke weight and style across the entire Services page.
- No asset pipeline changes. Propshaft-safe rendering is preserved.
- Model validation (`inclusion: { in: ICON_KEYS }`) requires no logic change — only the constant value changes.

### Negative

- One additional data migration is required. Any deployment that omits the migration will leave existing `ServiceSection` rows with stale Heroicon key strings, causing validation failures and view render errors.
- The down path for the migration has a bounded irreversibility: rows created with the four new Tabler-only keys (`engine`, `car-suspension`, `motorbike`, `helmet`) after the migration has run cannot be rolled back to a Heroicon equivalent (none exists). Rolling back the migration after such rows are created will leave those rows with icon_key values that fail inclusion validation under the old ICON_KEYS. See Risks.

### Risks

**Down-migration incompleteness for new-key rows.** The migration's `down` block reverses the 14-key Heroicon→Tabler mapping but has no Heroicon predecessor for the 4 new additions. If a section with `icon_key: "engine"` (or any other new-only key) is created after the up migration runs, a subsequent `db:migrate:down` will leave that row with an icon_key value invalid under the old ICON_KEYS constant. Mitigation: the down block should check for rows whose icon_key is in the new-only set (`engine`, `car-suspension`, `motorbike`, `helmet`) and raise before reversing, to prevent silent corruption. The spec should require this guard; the developer must implement it.

**Helper method signature not yet verified.** `tabler_icons_ruby` may not accept a `variant:` parameter (heroicon requires `variant: :outline`). The developer must verify the exact method signature from the gem README before replacing call sites. If the gem is outline-only, the `variant:` argument must be dropped. The spec flags this correctly as E4.

**Icon name correctness.** Three Tabler key names were pre-verified against the Tabler Icons v3 outline directory (see SPEC-005 E2). The remaining 11 carry lower risk (unchanged names or obvious mappings) but each key should be exercised via the view helper before shipping (SPEC-005 R13).

---

## Implementation Notes

1. Verify the tabler_icons_ruby module constant and helper method name from the gem README before editing any file. Expected: `TablerIconsRuby::ApplicationHelper` and a method such as `tabler_icon(name, ...)`, but treat these as unconfirmed until the gem README is read.

2. The data migration must use `reset_column_information`, iterate the explicit mapping with `where(icon_key: old).update_all(icon_key: new)`, then raise on any row whose `icon_key` is not in the new ICON_KEYS array. Wrap in `reversible { |dir| dir.up { ... } dir.down { ... } }`.

3. The down block must add a guard: before reversing the 14-key mapping, query for rows whose `icon_key` is in `%w[engine car-suspension motorbike helmet]` and raise with a descriptive message if any are found. This prevents silent data corruption on rollback.

4. `db/seeds.rb` must use the new Tabler keys. Seeds must remain idempotent.

5. All three heroicon call sites — `app/views/pages/services.html.erb:14`, `app/views/admin/services_pages/show.html.erb:42`, `app/views/admin/service_sections/_form.html.erb:36` — must be updated. Size CSS classes (`w-10 h-10`, `w-6 h-6`, `w-8 h-8`) must be preserved.

6. A forward reference to this ADR should be added to ADR-002 (a one-line note at the top of ADR-002 pointing to ADR-003) to assist future readers navigating the decision history.
