# Spec: Social Media Links — Admin-Managed Profile Icons

**ID:** SPEC-014
**Status:** ready
**Priority:** medium
**Created:** 2026-09-02
**Author:** spec-agent

---

## Goal

Let Doug add his shop's social media profiles himself — pick a platform from a fixed list, paste the profile URL — from an admin screen that follows the same pattern he already knows from FAQs (ordered list, Move Up/Down, edit, delete). Only platforms Doug has actually filled in ever appear anywhere on the site: the footer on every page, the home page's closing CTA band, the About page's shop-info block, and the `sameAs` field of the site's schema.org business listing. The public site renders icons only, with no visible text label, so every rendered link must carry an accessible name a screen reader can announce.

---

## Non Goals

- **Platforms beyond the fixed 7** (Instagram, Facebook, YouTube, TikTok, X, Threads, LinkedIn). Adding an 8th platform is a code change (extending the allowlist constant and its icon/label mapping), not an admin-configurable option — same posture `ServiceSection::ICON_KEYS` already takes toward its icon list.
- **Custom or admin-uploaded icons.** Every platform's icon is a fixed Tabler `brand-*` icon; there is no per-link icon picker.
- **A `published`-style draft/live gate**, distinct from the per-link `active` toggle. See R6 and Implementation Decisions for why this record does not follow ADR-004's `published` convention.
- **Domain/ownership validation of the pasted URL against the chosen platform.** Rejected explicitly — see R11 and Implementation Decisions.
- **More than one link per platform.** Uniqueness is enforced per platform; changing a platform's URL means editing the existing row, not adding a second one — see R10.
- **Drag-and-drop reordering.** This follows the FAQ Move Up/Down pattern deliberately, not the Gallery-specific SortableJS reversal from ADR-005's addendum, which was scoped to Gallery's photo-grid UX only.
- **Click analytics or tracking** on outbound social links.
- **Reordering the 4 render locations relative to other page content** (e.g. moving the footer's icon row above the nav). Each location's position within its own page is fixed template structure; only the *order of links within* a location, and which links exist at all, is admin-controlled.

---

## Definitions

| Term | Definition |
|------|-----------|
| platform | One of exactly 7 fixed keys stored in `SocialMediaLink#platform`: `instagram`, `facebook`, `youtube`, `tiktok`, `x`, `threads`, `linkedin`. Defined once as `SocialMediaLink::PLATFORMS`, the direct analogue of `ServiceSection::ICON_KEYS`. |
| active link | A `SocialMediaLink` row with `active: true`. Only active links render anywhere or appear in `sameAs`; an inactive link still exists in the admin list (edit/reorder/re-activate remain possible) but is invisible everywhere else — see R6. |
| icon-only render | The public-facing rule (R7) that every rendered social link shows its platform's icon and nothing else — no adjacent text, no visible platform name — with the platform name instead carried as the link's `aria-label` so the icon-only presentation does not strip the link of an accessible name. |
| the 4 render locations | Site footer (every page), the home page's closing CTA band, the About page's shop-info block, and schema.org `sameAs`. All 4 are in scope; see R11-R15. |
| shared partial | `app/views/shared/_social_media_links.html.erb` — the single view fragment rendering the icon-only row, parameterized per call site for size/color/spacing, so the 4 locations cannot visually drift apart from independent copies of the same markup. |

---

## Interfaces

### Public Frontend

No new routes. 3 existing views/helpers gain a rendering of the shared partial or a schema field:

| Location | File | Placement |
|----------|------|-----------|
| Footer | `app/views/layouts/application.html.erb` | Above the existing copyright line, inside the existing `<footer>` |
| Home CTA band | `app/views/pages/home.html.erb` | Below the existing "CONTACT THE SHOP" link, inside the final full-screen section |
| About shop info | `app/views/pages/about.html.erb` | Immediately below the existing phone/address block (after line 83), before the Hours section |
| Schema.org | `app/helpers/structured_data_helper.rb` | `local_business_schema` gains a `"sameAs"` key |

### Admin

New resource, new controller, following `Admin::FaqsController` exactly:

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/social_media_links | `#index` |
| GET | /admin/social_media_links/new | `#new` |
| POST | /admin/social_media_links | `#create` |
| GET | /admin/social_media_links/:id/edit | `#edit` |
| PATCH | /admin/social_media_links/:id | `#update` |
| DELETE | /admin/social_media_links/:id | `#destroy` |
| PATCH | /admin/social_media_links/:id/move_up | `#move_up` |
| PATCH | /admin/social_media_links/:id/move_down | `#move_down` |

```ruby
resources :social_media_links, only: [ :index, :new, :create, :edit, :update, :destroy ] do
  member do
    patch :move_up
    patch :move_down
  end
end
```

### Data Model

```ruby
create_table :social_media_links do |t|
  t.string  :platform, null: false
  t.string  :url,      null: false
  t.integer :position, null: false, default: 0
  t.boolean :active,   null: false, default: true
  t.timestamps
end
add_index :social_media_links, :platform, unique: true
```

```ruby
class SocialMediaLink < ApplicationRecord
  PLATFORMS = %w[instagram facebook youtube tiktok x threads linkedin].freeze

  scope :active, -> { where(active: true) }

  validates :platform, presence: true, inclusion: { in: PLATFORMS }, uniqueness: true
  validates :url, presence: true, format: { with: ... }  # scheme restricted to http/https — see R4
  validates :position, presence: true, numericality: { only_integer: true }

  def icon_key
    "brand-#{platform}"
  end

  def platform_label
    I18n.t("social_media.platforms.#{platform}")
  end
end
```

`icon_key` is computed, not stored: every one of the 7 platforms' Tabler icon follows the exact pattern `brand-<platform>` (`brand-instagram`, `brand-facebook`, `brand-youtube`, `brand-tiktok`, `brand-x`, `brand-threads`, `brand-linkedin`), so a separate lookup table would only be a second place the platform list could drift from `PLATFORMS`.

### Required i18n Keys

New top-level namespace (not nested under `admin`, since `platform_label` is read by the *public* partial's `aria-label` as well as the admin dropdown — see R8):

```yaml
social_media:
  platforms:
    instagram: "Instagram"
    facebook: "Facebook"
    youtube: "YouTube"
    tiktok: "TikTok"
    x: "X"
    threads: "Threads"
    linkedin: "LinkedIn"
```

New, under `admin.social_media_links` (mirrors `admin.faqs` key-for-key):

| Key | Purpose |
|-----|---------|
| `heading` | Index page heading |
| `platform_label` | Form label for the platform select |
| `url_label` | Form label for the URL field |
| `url_placeholder` | Placeholder text, e.g. "https://instagram.com/yourshop" |
| `active_label` | Checkbox label for the visibility toggle |
| `active_hint` | Short explanation of what unchecking does |
| `save`, `edit`, `delete`, `move_up`, `move_down` | Action labels |
| `confirm_delete` | Delete confirmation copy |
| `add_first` | "Add Social Media Link" call-to-action |
| `empty_state` | Shown when the list is empty |
| `new_heading`, `edit_heading` | Form page headings |
| `flash.created`, `flash.updated`, `flash.destroyed`, `flash.moved` | Flash messages |

New, under `admin.dashboard`: `social_media_links_link`. New, under `admin.layout.nav`: `social`.

---

## Rules

### Data Model and Validation

R1: A new `SocialMediaLink` model/table, per the Interfaces section's Data Model — `platform` (string), `url` (string), `position` (integer, default 0), `active` (boolean, default `true`), timestamps. No foreign keys.

R2: `SocialMediaLink::PLATFORMS` is a frozen array of exactly the 7 allowlisted platform keys. `platform` is validated with `inclusion: { in: PLATFORMS }`, directly following the `ServiceSection::ICON_KEYS` pattern (frozen constant + `inclusion:`) named in this spec's requirements.

R3: `platform` is validated `uniqueness: true` (model-level) with a DB-level unique index as defense in depth (matching `service_sections.slug`'s existing unique-index precedent). Uniqueness applies regardless of `active` state — at most one row exists per platform, ever, whether shown or hidden. Changing a platform's URL is done by editing its existing row (R10), not by adding a second row for the same platform.

R4: `url` is validated `presence: true` and by format: the scheme must be exactly `http` or `https` (case-insensitive), and the value must otherwise be a well-formed URL. A `javascript:`, `data:`, `mailto:`, or schemeless value (e.g. `instagram.com/shop`) is invalid. See Implementation Decisions for the recommended validation technique.

R5: `position` is validated `presence: true, numericality: { only_integer: true }`, matching `ServiceSection#position`. New records are assigned `(SocialMediaLink.maximum(:position) || -1) + 1` in the controller's `#create`, matching `Admin::FaqsController#create` and `Admin::ServiceSectionsController#create` exactly.

R6: **No `published` flag is added.** Visibility is controlled by the `active` boolean column, which defaults to `true`. A `SocialMediaLink.active` scope (`where(active: true)`) is the single source every public render and `sameAs` computation reads from. See Implementation Decisions for why this deliberately departs from ADR-004's `published`-column convention used by every other content model in this codebase.

R7: `SocialMediaLink#icon_key` returns `"brand-#{platform}"` — computed, not stored (see Interfaces). `SocialMediaLink#platform_label` returns `I18n.t("social_media.platforms.#{platform}")` — the single source for both the admin dropdown's option text and the public link's `aria-label`, so the two cannot independently drift out of sync.

### Admin CRUD

R8: `Admin::SocialMediaLinksController` implements `index`, `new`, `create`, `edit`, `update`, `destroy`, `move_up`, `move_down`, following `Admin::FaqsController`'s shape exactly (`before_action :set_social_media_link`, `swap_position_with` for reordering, flash notices from `admin.social_media_links.flash.*`, `render ..., status: :unprocessable_entity` on validation failure). The `new`/`edit` form's platform field is an `f.select` built from `SocialMediaLink::PLATFORMS.map { |p| [I18n.t("social_media.platforms.#{p}"), p] }` — the dropdown's **visible option text is each platform's human-readable name** ("Instagram", "X"), while the submitted value is the underlying key (`"instagram"`, `"x"`). The `active` toggle is a checkbox, following the exact hidden-field-plus-checkbox pattern already used for `published` in `admin/home_page_contents/show.html.erb` (`<input type="hidden" name="...[active]" value="false">` followed by the checkbox), defaulting checked for a new record.

R9: `Admin::SocialMediaLinksController` and `admin_helper.rb` add a "Social" entry to `admin_nav_items`, appended after "Services" (the existing 5-item order is preserved unchanged; the new item is added, not inserted mid-list, so the already-tested nav order for the 5 existing destinations does not change). No change to `admin_nav_current?`'s branching logic is required — its existing generic `request.path.start_with?(path)` branch already correctly marks "Social" current across `/admin/social_media_links`, `/new`, and `/:id/edit`, the same way it already works for Home/About/Gallery without a special case.

R10: `app/views/admin/dashboard/index.html.erb` gains a link to `admin_social_media_links_path`, appended after the existing links, following the existing `<li>` markup pattern.

### URL Validation Posture

R11: The URL format validation (R4) does **not** check the URL's domain against the selected platform (e.g. does not require an Instagram URL to contain `instagram.com`). A mismatched icon/URL pair is a mild, self-correctable data-entry mistake; rejecting a URL Doug knows is correct because it doesn't look like what the validator expected is a worse failure mode on a single-admin, phone-first tool.

R12: Every rendered social link (all 4 locations) carries `rel="noopener noreferrer"` and `target="_blank"`, matching the existing external-link pattern already used for the About page's Google Maps link (`about.html.erb` line 76-79).

### Rendering — Shared Partial and 4 Locations

R13: A single shared partial, `app/views/shared/_social_media_links.html.erb`, renders the icon-only row. It queries `SocialMediaLink.active.order(:position)` itself (via a small helper method, e.g. `active_social_media_links`, callable from any view without controller-level wiring) rather than depending on a controller-set instance variable — this guarantees the footer (rendered from the shared layout on every action of every controller) is always correct without every current and future controller action remembering to set an ivar. The partial accepts locals for per-location styling (e.g. `icon_css_class:`, `link_css_class:`, `wrapper_css_class:`) and is rendered from all 4 call sites with those locals set per R14-R16.

R14: **Zero-render rule, all 4 locations.** When `SocialMediaLink.active` is empty, the partial renders nothing at all — no wrapping container element, no heading, no leftover margin or divider that would otherwise separate adjacent content. This is implemented as a single top-level guard (`<% links = active_social_media_links %><% if links.any? %>...<% end %>`) so the empty case can never accidentally leave behind an empty `<div>`/`<ul>` with its own spacing.

R15: **Per-link markup.** Each active link renders as `<a href="<link.url>" target="_blank" rel="noopener noreferrer" aria-label="<link.platform_label>">` wrapping an SVG icon (`link.icon_key`) that itself carries `aria-hidden="true"`. No visible text is rendered adjacent to the icon at any of the 4 locations — this is the explicit, non-negotiable instruction behind the "icon-only" requirement, satisfied by giving the accessible name entirely to the link's `aria-label` rather than to visible text.

R16: **Per-location styling**, all reachable only via the R13 partial's locals (never a second copy of the markup):
  - **Footer** (`application.html.erb`, dark `bg-[#242121]` background): rendered above the copyright `<p>`, light/white icon color with the existing red-600 hover accent (`text-white hover:text-red-600`), wrapping (`flex-wrap`) row, centered.
  - **Home CTA band** (`home.html.erb`, dark photographic `background-image` section, existing text already `text-white`): rendered below the "CONTACT THE SHOP" link, same white/red-600-hover treatment as the footer for contrast against the photo, slightly larger icon size to suit the full-bleed section.
  - **About shop info** (`about.html.erb`, white background, existing phone/address links already `hover:text-red-600` on a `text-gray-700` base): rendered directly below the phone/address block, same gray/red-600-hover treatment as the existing tel/address links immediately above it, so it reads as a continuation of "ways to reach the shop" rather than a visually distinct new block. No new heading text is added — proximity to the phone/address block, plus the aria-labels, carries the context.
  - No location renders a visible heading or caption naming the row (e.g. no literal "Follow Us" text) — consistent with the icon-only, no-text-label instruction applying to the row as a whole, not just to each individual icon.

R17: `StructuredDataHelper#local_business_schema` gains a `"sameAs"` key: when `SocialMediaLink.active.order(:position)` is non-empty, `"sameAs"` is set to the array of those links' `url` values, in position order. **When empty, the `"sameAs"` key is omitted from the hash entirely** — not present with an empty-array value — matching how the existing `openingHoursSpecification` key is already conditionally added only when data exists (`schema["openingHoursSpecification"] = opening_hours if opening_hours`).

R18: All 4 render locations read from the same `SocialMediaLink.active.order(:position)` query (directly, or via the R13 helper), so link order is identical everywhere — no location performs its own independent sort.

### Mobile-First

R19: Every rendered link's tap target is padded beyond the raw icon's bounding box (e.g. `p-2` around a `w-6 h-6`/`w-7 h-7`/`w-8 h-8` icon, per location) rather than the literal `py-3 px-4` CLAUDE.md specifies for full-width buttons — see Implementation Decisions for why a literal substitution is the wrong read of that rule for a small inline icon row, while the underlying "tappable without precision" intent is still honored. The containing row wraps (`flex-wrap`) rather than scrolling horizontally at any of the 4 locations, consistent with CLAUDE.md's blanket no-horizontal-scroll rule.

---

## Edge Cases

E1: Zero `SocialMediaLink` rows exist at all (the state the site ships in today). Nothing renders at any of the 4 locations; `local_business_schema` has no `"sameAs"` key.

E2: Rows exist but all have `active: false`. Identical outward behavior to E1 at all 4 locations and in `sameAs` — an inactive link is indistinguishable from a nonexistent one anywhere outside the admin list.

E3: Exactly one active link exists. Renders as a single icon at all 4 locations; `sameAs` is a 1-element array (not omitted, since it is non-empty).

E4: Multiple active links exist. All render, in `position` order, identically at all 4 locations (R18).

E5: An inactive link is mixed among active ones. The inactive one is excluded from all 4 renders and from `sameAs`; the remaining active links keep their existing relative order (deactivating one link does not renumber the others' `position` values).

E6: A create/update attempt submits a `javascript:alert(1)` URL. Rejected by R4's format validation; no record is saved/changed; the admin sees a specific format error, not a generic failure.

E7: A create attempt submits `platform: "instagram"` while an Instagram row already exists (active or inactive). Rejected by R3's uniqueness validation with a clear, attributable error.

E8: `move_up` is requested on the first (lowest-position) link, or `move_down` on the last. No-op — mirrors `Faq#swap_position_with` returning early when there is no neighbour in that direction; no error is raised.

E9: A link that is currently rendered on the public site is deleted. It stops appearing at all 4 locations on the very next request — there is no caching layer to invalidate.

E10: A submitted URL uses an uppercase or mixed-case scheme (`HTTPS://instagram.com/shop`). Accepted — scheme matching is case-insensitive, matching standard URI scheme handling.

E11: A submitted URL omits the scheme entirely (`instagram.com/shop`). Rejected — R4 requires an explicit `http://`/`https://` prefix; it is never inferred or auto-prepended.

---

## Acceptance Criteria

### Model

AC-1: Given `platform: "instagram"`, a valid `https://` `url`, and no existing Instagram row, a `SocialMediaLink` is valid.

AC-2: Given `platform: "myspace"` (not in the allowlist), the record is invalid with an inclusion error on `platform`.

AC-3: Given a `platform` value that already exists on another `SocialMediaLink` row (regardless of that row's `active` value), the record is invalid with a uniqueness error on `platform`.

AC-4: Given a blank `url`, the record is invalid with a presence error on `url`.

AC-5: Given `url: "javascript:alert(1)"`, the record is invalid with a format error on `url`.

AC-6: Given `url: "ftp://example.com/shop"`, the record is invalid (scheme not http/https).

AC-7: For each of the 7 `SocialMediaLink::PLATFORMS` values, `#icon_key` returns `"brand-<platform>"` exactly.

AC-8: Given a mix of `active: true` and `active: false` rows, `SocialMediaLink.active` returns only the `active: true` rows; chained with `.order(:position)` it returns them in position order.

AC-9: Given a new `SocialMediaLink` built without explicitly setting `active`, its `active` value is `true`.

### Admin CRUD

AC-10: `GET /admin/social_media_links` lists existing links; when none exist, shows the `empty_state` message and an "add first" call to action.

AC-11: Given admin is authenticated, `POST /admin/social_media_links` with a valid, not-yet-used platform and a valid `https://` URL creates the record with `position` equal to `(previous max || -1) + 1`, and redirects with `flash[:notice]`.

AC-12: Given admin is authenticated, `POST /admin/social_media_links` with a platform already in use returns HTTP 422 and re-renders `new` with a uniqueness error.

AC-13: Given admin is authenticated, `PATCH /admin/social_media_links/:id` with a new `url` updates the record and redirects with `flash[:notice]`.

AC-14: Given admin is authenticated, `DELETE /admin/social_media_links/:id` destroys the record and redirects with `flash[:notice]`.

AC-15: Given admin is authenticated and at least 2 links exist, `PATCH .../move_up` and `PATCH .../move_down` swap `position` with the correct neighbour; requesting `move_up` on the first link or `move_down` on the last is a no-op that does not raise.

AC-16: The `new`/`edit` form's platform `<select>` renders exactly 7 `<option>` elements whose visible text is each platform's human-readable name (e.g. "Instagram", "X"), not the raw key.

AC-17: The `new`/`edit` form includes an `active` checkbox, checked by default on `new`.

AC-18: Given no active admin session, requests to any of the 8 `Admin::SocialMediaLinksController` routes redirect to the login page and change no data.

AC-19: `admin_nav_items` includes a "Social" entry, positioned after "Services", pointing at `admin_social_media_links_path`; visiting the index, `new`, or an `edit` page all mark that item current via `aria-current="page"`.

AC-20: `admin/dashboard/index.html.erb` includes a link to `admin_social_media_links_path`.

### Public Rendering — Footer

AC-21: Given ≥ 1 active link, every public page's footer includes one icon-only link per active link: `href` equals the link's `url`, `aria-label` equals `platform_label`, `rel="noopener noreferrer"`, `target="_blank"`, the inner SVG carries `aria-hidden="true"`, and no visible text node naming the platform is present.

AC-22: Given 0 active links, the footer contains no social-links wrapper element at all (asserted by the wrapper's identifying selector being absent, not merely empty of children).

### Public Rendering — Home CTA Band

AC-23: Given ≥ 1 active link, the home page's final section includes the same per-link markup as AC-21, positioned below the "CONTACT THE SHOP" link.

AC-24: Given 0 active links, the home page's final section contains no social-links wrapper element.

### Public Rendering — About Page

AC-25: Given ≥ 1 active link, the About page includes the same per-link markup as AC-21, positioned below the phone/address block.

AC-26: Given 0 active links, the About page contains no social-links wrapper element.

### Schema.org

AC-27: Given ≥ 1 active link, `local_business_schema["sameAs"]` equals the array of active links' `url` values, in position order.

AC-28: Given 0 active links, `local_business_schema.key?("sameAs")` is `false`.

### Cross-Cutting

AC-29: All 4 locations render links in identical relative order for the same underlying data — no location reorders independently.

AC-30: No hardcoded English platform-name string is introduced; the admin dropdown's option text and every rendered `aria-label` both resolve through `I18n.t("social_media.platforms.<platform>")` (i.e. `SocialMediaLink#platform_label`), not a separately-written string.

AC-31: At 375 px, 390 px, and 414 px viewport widths, all 4 render locations produce no horizontal document overflow, and every rendered link has a padded tap area larger than its raw icon bounding box.

---

## Acceptance Tests

AT1
Given valid platform/url values and no existing row for that platform
When a `SocialMediaLink` is validated
Then it is valid
Covers: R1, R2, R4, AC-1

AT2
Given `platform: "myspace"`
When validated
Then it is invalid with an inclusion error on `platform`
Covers: R2, AC-2

AT3
Given a platform already used by another row (`active: false` on the existing row)
When a second row with the same platform is validated
Then it is invalid with a uniqueness error on `platform`
Covers: R3, AC-3, E7

AT4
Given a blank `url`
When validated
Then it is invalid with a presence error
Covers: R4, AC-4

AT5
Given `url: "javascript:alert(1)"`
When validated
Then it is invalid with a format error
Covers: R4, R11, AC-5, E6

AT6
Given `url: "ftp://example.com/shop"`
When validated
Then it is invalid
Covers: R4, AC-6

AT7
Given each of the 7 `SocialMediaLink::PLATFORMS` values in turn
When `#icon_key` is called
Then it returns `"brand-<platform>"`
Covers: R7, AC-7

AT8
Given a mix of active and inactive rows
When `SocialMediaLink.active.order(:position)` is called
Then only active rows are returned, in position order
Covers: R6, R18, AC-8

AT9
Given a new `SocialMediaLink` built with no explicit `active` value
When inspected
Then `active` is `true`
Covers: R1, AC-9

AT10
Given admin is authenticated and zero links exist
When `GET /admin/social_media_links`
Then the response shows the empty-state message and an add-first link
Covers: R8, AC-10

AT11
Given admin is authenticated
When `POST /admin/social_media_links` with a valid platform/url
Then the record is created with the next sequential position, and the response redirects with `flash[:notice]`
Covers: R5, R8, AC-11

AT12
Given admin is authenticated and an Instagram link already exists
When `POST /admin/social_media_links` with `platform: "instagram"` again
Then HTTP 422 and `new` re-renders with a uniqueness error
Covers: R3, R8, AC-12

AT13
Given admin is authenticated and a link exists
When `PATCH /admin/social_media_links/:id` with a new url
Then the record updates and the response redirects with `flash[:notice]`
Covers: R8, AC-13

AT14
Given admin is authenticated and a link exists
When `DELETE /admin/social_media_links/:id`
Then the record is destroyed and the response redirects with `flash[:notice]`
Covers: R8, AC-14

AT15
Given admin is authenticated and 3 links exist in position order
When `move_up` is requested on the middle link, then `move_down` is requested on the first link
Then positions swap with the correct neighbour each time, and requesting `move_up` on the resulting first link is a no-op
Covers: R5, R8, AC-15, E8

AT16
Given admin is authenticated
When `GET /admin/social_media_links/new`
Then the platform `<select>` has exactly 7 options whose visible text are the platforms' human-readable names
Covers: R7, R8, AC-16, AC-30

AT17
Given admin is authenticated
When `GET /admin/social_media_links/new`
Then the form includes an `active` checkbox that is checked
Covers: R8, AC-17

AT18
Given no active admin session
When each of the 8 `Admin::SocialMediaLinksController` routes is requested
Then each redirects to login and no data changes
Covers: R8, AC-18

AT19
Given admin is authenticated
When `GET /admin/social_media_links`, `GET .../new`, and `GET .../:id/edit` are each requested
Then `admin_nav_items` includes "Social" after "Services", and each response marks it current via `aria-current="page"`
Covers: R9, AC-19

AT20
Given admin is authenticated
When `GET /admin`
Then the dashboard includes a link to `admin_social_media_links_path`
Covers: R10, AC-20

AT21
Given 2 active `SocialMediaLink` records (Instagram, position 0; Facebook, position 1)
When any public page is rendered
Then the footer includes 2 icon-only links in that order, each with the correct `href`, `aria-label`, `rel="noopener noreferrer"`, `target="_blank"`, and `aria-hidden` SVG, with no visible platform-name text
Covers: R12, R13, R14, R15, R16, R18, AC-21, E3, E4

AT22
Given zero active `SocialMediaLink` records
When any public page is rendered
Then the footer contains no social-links wrapper element
Covers: R14, AC-22, E1, E2

AT23
Given 2 active `SocialMediaLink` records
When `GET /`
Then the closing CTA section includes the same 2 icon-only links, positioned below the contact link
Covers: R13, R16, AC-23

AT24
Given zero active `SocialMediaLink` records
When `GET /`
Then the closing CTA section contains no social-links wrapper element
Covers: R14, AC-24

AT25
Given 2 active `SocialMediaLink` records
When `GET /about`
Then the shop-info block includes the same 2 icon-only links, positioned below the phone/address block
Covers: R13, R16, AC-25

AT26
Given zero active `SocialMediaLink` records
When `GET /about`
Then the shop-info block contains no social-links wrapper element
Covers: R14, AC-26

AT27
Given 2 active `SocialMediaLink` records (Instagram, Facebook) and 1 inactive (YouTube)
When `local_business_schema` is built
Then `schema["sameAs"]` equals `[instagram_url, facebook_url]` in position order, excluding the inactive YouTube link
Covers: R17, R18, AC-27, E5

AT28
Given zero active `SocialMediaLink` records
When `local_business_schema` is built
Then `schema.key?("sameAs")` is `false`
Covers: R17, AC-28, E1, E2

AT29
Given 3 active `SocialMediaLink` records
When the footer, home CTA band, About shop-info block, and `sameAs` are each inspected
Then all 4 present the links in the identical relative order
Covers: R18, AC-29

AT30
Given the admin platform `<select>` and the public partial's rendered `aria-label`s
When both are inspected for the same platform
Then both resolve through `SocialMediaLink#platform_label` / `I18n.t("social_media.platforms.<platform>")`, with no independently-hardcoded string at either call site
Covers: R7, AC-30

AT31
Given 3 active `SocialMediaLink` records and the browser viewport set to 375px, 390px, and 414px in turn (system spec)
When the footer, home page, and About page are each rendered
Then `document.body.scrollWidth` does not exceed the viewport width at any of the 3 locations, and each rendered link's clickable area is visibly larger than its raw icon
Covers: R19, AC-31

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-09-02 | `active` boolean toggle, not a second `published` flag (R6) | Every other content model in this codebase (`HomePageContent`, `AboutPageContent`, `ServicesPage`) follows ADR-004's `published` convention because each is a *page's content*, with a meaningful distinction between "what's saved" and "what's live" — the whole point of `published` is to let an admin draft changes without exposing them. A `SocialMediaLink` has no analogous draft state: a URL is either correct or it isn't, and there is no "draft version of a link" concept to protect. What Doug actually asked for is closer to a light switch — hide a profile without losing the typed-in URL — which `active` gives him directly. Naming it `active` rather than `published` is also intentional: reusing `published` here would misleadingly imply this record participates in the same content-draft workflow ADR-004 describes, when it does not. Neither `Faq` nor `ServiceSection` — the two closest existing "small ordered admin collection" precedents — has any visibility flag at all; `active` is a deliberate addition beyond what either of those has, specifically because the requesting session asked for a hide-without-delete affordance neither of those needed. |
| 2026-09-02 | URL domain is not validated against the selected platform (R11) | A pasted URL that is valid but doesn't obviously match its platform (a shortened link, a regional TikTok domain, a business-account URL structure Instagram itself has changed over the years) is far more likely than a genuine mismatch, and rejecting it would put a single-admin, phone-first tool in the position of correcting Doug about his own social accounts. The downside of not validating — an icon that links to the "wrong" platform because of a copy-paste mistake — is self-evident the moment Doug or anyone else clicks it, and is a one-field edit to fix. That asymmetry (rare, self-evident, cheaply-fixed failure vs. a validator that actively blocks legitimate input) is the same reasoning already applied elsewhere in this codebase to avoid over-validating (ADR-005 Decision 4's rejection of dimension/aspect-ratio checks on uploaded images, for the same class of reason: the failure mode of over-validating is worse than the failure mode being guarded against). |
| 2026-09-02 | `icon_key` computed as `"brand-#{platform}"`, no stored/hardcoded per-platform icon mapping | All 7 verified Tabler icons happen to follow the platform name exactly (`brand-instagram`, `brand-x`, etc.), so a separate `{ "instagram" => "brand-instagram", ... }` table would be redundant data that could, in principle, drift from `PLATFORMS` if a future edit updated one list and not the other. Computing it removes that entire class of bug. If a future 8th platform's Tabler icon name ever doesn't follow this pattern, that is the moment to introduce a mapping — not preemptively, for 7 platforms that all currently fit the rule. |
| 2026-09-02 | `py-3 px-4`-style touch targets applied as generous icon padding, not verbatim (R19) | CLAUDE.md's `py-3 px-4` guidance is written with full-width form buttons and links in mind, where the padding also defines the element's visible size. Applying it literally to a small inline icon (turning a `w-6 h-6` glyph into a padded block roughly the size of a "Send Message" button) would look visually broken in a footer or CTA row and is not what the rule is protecting against. The substantive requirement — nothing on this phone-first site should require pixel-precision tapping — is honored instead by padding each icon's hit area meaningfully beyond its visible glyph and giving adjacent icons real spacing (`gap-4`/`gap-6`), which is the same design language already used for icon-only affordances elsewhere in this codebase (the Gallery lightbox close button, `pages/gallery.html.erb`, pads its `x` icon rather than sizing the tap target to the raw SVG). |
| 2026-09-02 | Public-facing i18n keys live under a new top-level `social_media` namespace, not nested inside `admin` | `platform_label` (R7) is read by both the admin dropdown and the public partial's `aria-label`. Nesting the shared string under `admin.social_media_links.platforms.*` would make a public accessibility string appear, by its key path, to be admin-only copy — misleading to whoever next edits `en.yml`, and the literal opposite of R7's goal (one shared source, unambiguously shared). A parallel top-level namespace, alongside the existing `nav`, `pages`, `contact`, `application`, and `admin` namespaces, keeps the key's scope honest. |

---

## Dependencies

- SPEC-004 (Admin Backend) — provides `Admin::BaseController`, `current_admin`, and the admin layout this spec's new controller and nav entry extend.
- ADR-002 Decision 2 — governs the `position`/gap-tolerant-swap reordering mechanism (R5, R8), reused verbatim from `ServiceSection`/`Faq`, not re-derived here.
- ADR-004 (Singleton Content Model and Publish Flag Placement) — explicitly **not** followed for this model; see R6 and Implementation Decisions for the reasoned departure.
- `tabler_icons_ruby` (~> 3.26) — already a dependency; this spec's icon rendering uses `ApplicationHelper`'s existing `TablerIconsRuby::Helper` inclusion and the same `tabler_icon(...)` call already used in `pages/gallery.html.erb`. All 7 required `brand-*` icons were confirmed present in the installed gem version before this spec was written (no `VENDORED_ICON_SVGS`-style fallback is needed, unlike `car-suspension` in `ApplicationHelper`).
- SPEC-012 (SEO/AEO Pass) — owns `StructuredDataHelper#local_business_schema` in its current form; this spec adds the `"sameAs"` key to it.
- No new gems required.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | Model + migration: `social_media_links` table, `SocialMediaLink` with `PLATFORMS`, validations (R1-R5), `active` scope, `icon_key`, `platform_label` (R6, R7). Factory. | AC-1 – AC-9 | 2 |
| T2 | Admin controller + routes: `Admin::SocialMediaLinksController` mirroring `Admin::FaqsController` (R8); `admin_nav_items`/dashboard entries (R9, R10). | AC-10 – AC-15, AC-18 – AC-20 | 3 |
| T3 | Admin views: index/new/edit/_form with platform-name dropdown and active checkbox (R8). | AC-16, AC-17 | 2 |
| T4 | Shared partial `_social_media_links.html.erb` + `active_social_media_links` helper (R13-R15, R18); wire into footer, home CTA, About (R16). | AC-21, AC-23, AC-25, AC-29, AC-31 | 3 |
| T5 | Zero-state guard verified at all 3 render locations (R14) — likely folded into T4's implementation but tracked separately since it is the single most likely thing to regress. | AC-22, AC-24, AC-26 | 1 |
| T6 | `StructuredDataHelper#local_business_schema` `sameAs` key (R17). | AC-27, AC-28 | 1 |
| T7 | i18n: `social_media.platforms.*`, `admin.social_media_links.*`, dashboard/nav keys. | AC-30 | 1 |
| T8 | Tests: model spec (validations, scope, `icon_key`/`platform_label`); request specs for `Admin::SocialMediaLinksController` (CRUD, reorder, auth guard, nav marking); request/helper specs for the 3 public locations and `sameAs` (present/absent/ordering); system spec at 375/390/414px covering all 3 visible locations plus the admin form. All AAA, inline variables, no `let`/`let!`. | All | 5 |

Total estimated points: 18. T8 sits at the 5-point guardrail threshold — flagged for split review per CLAUDE.md's `>= 5 points` rule; recommend splitting into T8a (model + admin request specs) and T8b (public-render + system specs) if the developer agent finds it unwieldy as one PR, since the two halves touch entirely different layers and have no shared setup.

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-09-02 | Initial draft | All | Translates the repo owner's request into an implementation-ready spec. Resolves all 8 settled decisions from the requesting session explicitly: platform allowlist shape (R2, following `ServiceSection::ICON_KEYS`), the admin-names/public-icons split and its accessible-name consequence (R7, R15), all 4 render locations with a single shared partial to prevent drift (R13-R16), the zero-links-renders-nothing requirement made an explicit AC at every location (AC-22, AC-24, AC-26, AC-28) rather than left implicit, URL validation scope and posture (R4, R11), one-platform-one-link (R3, R10), and the `active`-not-`published` visibility decision with its full rationale (R6). |

---

## Open Questions

None. All 8 settled decisions from the requesting session are captured and argued above.
