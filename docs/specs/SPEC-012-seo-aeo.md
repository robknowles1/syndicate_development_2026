# Spec: SEO/AEO Pass — Structured Data, Metadata, FAQ, and Contact Form Hardening

**ID:** SPEC-012
**Status:** ready
**Priority:** high
**Created:** 2026-08-04
**Author:** spec-agent

---

## Goal

Bring the public site up to a genuine SEO/AEO baseline before Doug sees it on staging: distinct per-page titles and meta descriptions, `LocalBusiness` and `FAQPage` structured data, a real `sitemap.xml` and `robots.txt`, Open Graph/Twitter cards, a footer, a proper favicon, and an editable FAQ that doubles as the site's primary answer-engine surface. The site being replaced (a React SPA) already carried a single site-wide title, description, and keyword list; losing that would be a regression, so this spec restores parity and then goes further with per-page metadata and structured data the old site never had.

Folded into the same pass: `ContactsController#create` has no spam defenses of any kind. The site it replaces used Formspree, which filtered spam by default without anyone configuring it — self-hosting the form dropped that protection without replacing it. The form calls `deliver_now` synchronously against Resend with an attacker-controlled `reply_to`, so unprotected it is both a spam-inbox risk and, on a 2-vCPU box with a small Puma thread pool, a trivial denial-of-service vector: every submission holds a thread for a live SMTP round trip. Admin login already carries three layers of rate limiting (`Admin::SessionsController`); the public endpoint that sends real email carries none. This spec closes that gap with zero-friction defenses (honeypot, timing check, rate limiting) — explicitly not a visible CAPTCHA, which costs conversions on a small business contact form and is especially poor on the phone most of this shop's customers will be using.

This is scoped for one implementation pass, not an exhaustive SEO audit. Where a choice existed, it was made and recorded below rather than left open.

---

## Non Goals

- **No `keywords` meta tag.** Google has ignored it since 2009; Bing treats it as a spam signal. The old site's keyword list is used instead as the authoritative source of terms to work into titles, descriptions, headings, and FAQ answers where they carry real weight.
- **No per-city landing pages.** `areaServed` on the `LocalBusiness` schema plus genuine FAQ prose carry Idaho Falls, Boise, Idaho, and Utah — not a `/motorcycle-suspension-boise`-style page differing from another only by city name. That pattern is a doorway page, which Google names as a violation, and it is the obvious wrong turn once a list of cities exists. One well-written service area is both safer and more effective.
- **No shipping or mail-in service claim.** Confirmed with the user: the shop does not ship. No FAQ entry, schema property, or meta description mentions shipping, mail-in service, or "servicing the United States" (the old site's phrasing, which implied nationwide remote service this shop does not offer). This is a deliberate exclusion, not an oversight — if Doug starts offering it, the editable FAQ is exactly the mechanism to add it himself.
- **No structured, admin-editable address fields.** `AboutPageContent#shop_address` remains a single free-text field (SPEC-007). The `LocalBusiness` schema's `streetAddress` reuses that same resolved value rather than a second, independently-editable copy; `addressLocality`/`addressRegion`/`postalCode`/`addressCountry` are fixed constants (see R30) since the shop's city/state/zip do not change independently of a physical relocation.
- **No visible "hours" widget beyond a plain list.** No "open now" indicator, no calendar UI — a static list of the days that have hours set (R19).
- **No rich text / markdown in FAQ answers.** Plain text only, matching `bio_body`'s plain-textarea precedent (SPEC-007).
- **No per-page Open Graph image.** One site-wide default image, reused on every page (R40).
- **No FAQ item in the persistent 5-item admin nav bar.** A sixth item was previously declined for mobile-width reasons (SPEC-009). FAQs and Business Hours follow the existing `Users`/`Account` precedent instead — dashboard-only entry points, not persistent-nav items (R9, R20).
- **No favicon change to the admin layout.** Admin is not a public/crawled surface; the browser's default tab icon is left as-is there.
- **No `priceRange` on the `LocalBusiness` schema.** No basis exists for stating one without guessing.
- **No sitemap ping to Google/Bing on deploy**, no `lastmod`/`changefreq`/`priority` in sitemap entries — Google has stated these are largely ignored; omitting them avoids fabricating a freshness signal this app doesn't track.
- **No `deliver_later` for the contact mailer.** Considered and declined for now: Solid Queue only runs in production today (`config/environments/production.rb`), not staging, so switching now would make the form silently stop sending in staging. Recorded here as a deliberate deferral so it is picked up once a queue supervisor runs in every environment — rate limiting is this pass's answer to the DoS exposure `deliver_now` carries in the meantime.
- **No visible CAPTCHA or challenge on the contact form.** Explicit user decision — costs conversions, is poor on mobile. The three defenses in Part I are all zero-friction.
- **No re-litigating ADR-004** for FAQ's data shape — R1's Implementation Decision explains why FAQ deliberately does not follow the singleton+`published`+i18n-fallback pattern ADR-004 established.

---

## Definitions

| Term | Definition |
|------|-----------|
| `Faq` | A dedicated ActiveRecord model — one row per question/answer pair, with an integer `position` for display order. Purely database-backed; unlike `AboutPageContent`, there is no i18n fallback copy and no `published` flag (see R1 Implementation Decision). |
| `BusinessHours` | A singleton ActiveRecord model (at most one row, read/written via `first_or_initialize`) holding 7 named day-pairs of nullable `time` columns. Seeded with every column blank; Doug fills them in. |
| structured data / JSON-LD | Machine-readable markup embedded as `<script type="application/ld+json">`, describing the business (`LocalBusiness`/`MotorcycleRepair`) and the FAQ (`FAQPage`) per schema.org vocabulary, read by search and answer engines. |
| AEO | Answer Engine Optimization — writing content so that an AI answer engine (which quotes sentences, not keyword lists) can extract and cite it directly. The `FAQPage` schema is this spec's primary AEO lever, since answer engines lean on it heavily. |
| `areaServed` | A `LocalBusiness` schema property stating the geographic region a business serves, independent of its registered address. Used here to carry Idaho Falls, Boise, Idaho, and Utah honestly — the shop is physically in Pocatello; it does not claim a location it does not have. |
| content parity | The principle that structured data must reflect content that is actually present on the page (visible or reachable, e.g. inside a native `<details>` element) — not markup describing content a visitor never sees. Applied here to both `FAQPage` (R7) and `BusinessHours` (R19). |
| canonical URL | The `<link rel="canonical">` URL for a page — the one the site asserts is authoritative when the same content could otherwise be reached by more than one URL. |
| honeypot | A form field invisible to human visitors but present in the HTML a bot's scraper sees; a filled honeypot is treated as a spam signal. |
| timing token | A server-signed, tamper-evident timestamp recording when the contact form was rendered, used to reject submissions completed faster than a human could plausibly fill the form. |
| fake success | The response a spam-defense rejection produces: identical in status code, redirect target, and flash message to a genuine successful submission, so a bot cannot distinguish "blocked" from "sent" and probe for the failure mode. |

---

## Interfaces

### Public Frontend — New Routes

```ruby
get "/sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: :xml }
get "/robots.txt",  to: "robots#show",   as: :robots,  defaults: { format: :text }
```

### Public Frontend — Existing Routes, Extended Behavior

| Verb | Path | Action | Extension |
|------|------|--------|-----------|
| GET | `/` | `PagesController#home` | Assigns `@faqs = Faq.order(:position)`; view sets per-page title/description/canonical and renders the FAQ section + `FAQPage` JSON-LD |
| GET | `/about` | `PagesController#about` | View sets per-page title/description/canonical and renders the Business Hours list |
| GET | `/gallery` | `PagesController#gallery` | View sets per-page title/description/canonical |
| GET | `/services` | `PagesController#services` | View sets per-page title/description/canonical |
| POST | `/contact` | `ContactsController#create` | Gains honeypot, timing, and rate-limit guards ahead of existing validation (Part I) |

### Admin — New Routes

```ruby
namespace :admin do
  resources :faqs, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    member do
      patch :move_up
      patch :move_down
    end
  end
  resource :business_hours, only: [ :show, :update ]
end
```

| Verb | Path | Action |
|------|------|--------|
| GET | /admin/faqs | `Admin::FaqsController#index` — stacked-card list, mirrors `admin/services_pages/show.html.erb`'s per-section layout |
| GET | /admin/faqs/new | `#new` |
| POST | /admin/faqs | `#create` |
| GET | /admin/faqs/:id/edit | `#edit` |
| PATCH | /admin/faqs/:id | `#update` |
| DELETE | /admin/faqs/:id | `#destroy` |
| PATCH | /admin/faqs/:id/move_up | `#move_up` |
| PATCH | /admin/faqs/:id/move_down | `#move_down` |
| GET | /admin/business_hours | `Admin::BusinessHoursController#show` |
| PATCH | /admin/business_hours | `#update` |

Neither resource is added to `admin_nav_items` (`app/helpers/admin_helper.rb`) — both follow the existing `Users`/`Account` precedent of dashboard-only links (`admin.dashboard.faqs_link`, `admin.dashboard.business_hours_link`), not the persistent 5-item nav.

### Data Model

New table `faqs`:

| Column | Type | Constraints |
|--------|------|-------------|
| `question` | string | not null |
| `answer` | text | not null |
| `position` | integer | not null, default 0 |
| `created_at` / `updated_at` | datetime | |

New table `business_hours` (singleton — one row, read/written via `first_or_initialize`):

| Column | Type | Constraints |
|--------|------|-------------|
| `monday_opens_at` / `monday_closes_at` | time | nullable |
| `tuesday_opens_at` / `tuesday_closes_at` | time | nullable |
| `wednesday_opens_at` / `wednesday_closes_at` | time | nullable |
| `thursday_opens_at` / `thursday_closes_at` | time | nullable |
| `friday_opens_at` / `friday_closes_at` | time | nullable |
| `saturday_opens_at` / `saturday_closes_at` | time | nullable |
| `sunday_opens_at` / `sunday_closes_at` | time | nullable |
| `created_at` / `updated_at` | datetime | |

`BusinessHours::DAYS = %w[monday tuesday wednesday thursday friday saturday sunday].freeze` — the one ordered list the admin form, the public hours list, and the schema builder all iterate, so no second copy of the day order can drift (R12).

### New Helper

`app/helpers/structured_data_helper.rb`:

| Method | Returns |
|--------|---------|
| `local_business_schema` | Ruby hash for the `MotorcycleRepair`/`LocalBusiness` JSON-LD object, reading `AboutPageContent.first` (for the resolved phone/address) and `BusinessHours.first` (for `openingHoursSpecification`) |
| `faq_page_schema(faqs)` | Ruby hash for the `FAQPage` JSON-LD object, built from the same `Faq` collection the view renders |

Both are embedded via `json_escape(hash.to_json)` (R32) — never a raw `.to_json` — since FAQ answers are admin-authored text that could otherwise break out of the `<script>` context.

### Structured Data — Fixed Constants

Sourced by resolving the About page's existing Google Maps link (`https://goo.gl/maps/k6PjesVBsAqDArb27`), which redirects to `https://www.google.com/maps/place/1801+N+Arthur+Ave,+Pocatello,+ID+83204/@42.8739291,...!3d42.8739291!4d-112.4668151` — the coordinates the shop's own existing map link already resolves to, not an estimate.

```ruby
BUSINESS_NAME     = "Syndicate Development"
ADDRESS_LOCALITY  = "Pocatello"
ADDRESS_REGION    = "ID"
POSTAL_CODE       = "83204"
ADDRESS_COUNTRY   = "US"
GEO_LATITUDE      = 42.8739291
GEO_LONGITUDE     = -112.4668151
AREA_SERVED = [
  { "@type" => "City",  "name" => "Pocatello" },
  { "@type" => "City",  "name" => "Idaho Falls" },
  { "@type" => "City",  "name" => "Boise" },
  { "@type" => "State", "name" => "Idaho" },
  { "@type" => "State", "name" => "Utah" }
].freeze
```

### Required i18n Keys

New keys under `application`:

| Key | Purpose |
|-----|---------|
| `meta_description` | Site-wide fallback description, used only if a page fails to set `content_for(:meta_description)` |
| `footer.copyright` | `"© %{year} %{business_name}. All rights reserved."` |

New keys under `pages.home`, `pages.about`, `pages.gallery`, `pages.services` (each page gets its own `meta_title` and `meta_description`):

| Page | `meta_title` | `meta_description` |
|------|-------------|---------------------|
| home | "Syndicate Development \| Custom Motorcycle Shop in Pocatello, Idaho" | "Custom motorcycle builds, suspension setup, and ECU tuning for motocross and supercross riders in Pocatello, Idaho. Race prep, engine work, and dyno-tuned performance." |
| about | "About Syndicate Development \| Pocatello, Idaho" | "Meet Doug Haskett, the mechanic behind Syndicate Development's custom suspension, engine, and ECU work for motocross and supercross riders in Pocatello, Idaho." |
| gallery | "Project Gallery \| Syndicate Development Custom Motorcycles" | "See custom motocross and supercross builds from Syndicate Development — suspension, engine, and ECU projects completed in Pocatello, Idaho." |
| services | "Services \| Suspension, Engine Builds & ECU Tuning — Syndicate Development" | "Custom suspension setup, full race engine builds, and dyno-tuned ECU mapping for motocross and supercross bikes at Syndicate Development in Pocatello, Idaho." |

New key `pages.home.faq_heading`: "Frequently Asked Questions".

New keys under `admin.faqs`: `heading`, `question_label`, `answer_label`, `save`, `new_heading`, `edit_heading`, `move_up`, `move_down`, `edit`, `delete`, `confirm_delete`, `empty_state`, `add_first`, `flash.created`, `flash.updated`, `flash.destroyed`, `flash.moved`.

New keys under `admin.business_hours`: `heading`, `opens_label`, `closes_label`, `save`, `update_notice`, `hint` (explains that a blank day is omitted from the site's structured data and from the visible hours list), plus 7 day labels (`day_monday` … `day_sunday`).

New keys under `admin.dashboard`: `faqs_link`, `business_hours_link`.

New key under `pages.about`: `hours_heading` ("Hours").

New key under `contact.form`: `honeypot_label` — inert decoy label text, never perceivable by a real user (aria-hidden), still routed through i18n per the codebase's no-hardcoded-strings rule.

---

## Rules

### Part A — FAQ Model and Admin CRUD

R1: `Faq` is a plain, database-backed collection — **not** a singleton with a `published` flag and i18n fallback (ADR-004's pattern). *Implementation Decision:* ADR-004's pattern exists because Home/About had pre-existing hardcoded copy that must always render even before the DB is seeded — a "never blank" guarantee for content that already existed. FAQ is new content with no pre-existing original to fall back to. It structurally matches `ServiceSection` instead (ADR-001): a variable-length collection of individually addressable, individually validated records, each fully formed the moment it's created (an invalid create 422s and never persists — the same guarantee ADR-004 gives, achieved without the extra machinery). No restore-defaults action, no i18n keys for FAQ question/answer content — only the admin UI chrome (labels, buttons) is i18n'd, matching `ServiceSection#heading` and `ServiceBullet#body`.

R2: `Faq` validates `question` and `answer` presence. No length cap on either — no CSS single-line truncation constraint exists on the rendered `<details>`/`<summary>` markup, matching the precedent set by `AboutPageContent`'s uncapped fields (SPEC-007).

R3: On `POST /admin/faqs`, `position` is assigned `(Faq.maximum(:position) || -1) + 1`, matching the `ServiceSection`/`GalleryPhoto` precedent. No user-facing position field.

R4: `Admin::FaqsController#move_up` / `#move_down` use the identical gap-tolerant nearest-neighbour swap `ServiceSectionsController` already implements (ADR-002 Decision 2) — nearest lower/higher `position` neighbour, both rows' positions swapped inside `ActiveRecord::Base.transaction`. Not extracted into a shared concern; duplicated the same way the codebase already duplicates it between the two controllers that need it today (`GalleryPhoto`'s drag-based reorder is a different mechanism entirely and is not a precedent here — a curated ~6-item FAQ list matches `ServiceSection`'s scale and UI pattern, not Gallery's).

R5: `GET /admin/faqs` lists every `Faq.order(:position)` as stacked cards (question preview + wrapping `flex flex-wrap gap-2` row of Move Up / Move Down / Edit / Delete), mirroring `app/views/admin/services_pages/show.html.erb`'s existing per-section layout exactly. When zero `Faq` rows exist, an empty-state message (`t("admin.faqs.empty_state")`) plus an "Add FAQ" link (`t("admin.faqs.add_first")`) is shown instead.

R6: `PagesController#home` assigns `@faqs = Faq.order(:position)`. `app/views/pages/home.html.erb` renders a `<section>` (heading `t("pages.home.faq_heading")`) containing one native `<details><summary>{question}</summary><p>{answer}</p></details>` per FAQ, in position order, positioned between the Mission section and the CTA section. **The entire section — heading included — is omitted when `@faqs.empty?`**, not rendered with zero items.

R7: The `FAQPage` JSON-LD block (`faq_page_schema(@faqs)`, embedded via `json_escape`) is rendered on the Home page immediately after the FAQ section, **built from the exact same `@faqs` collection and in the same order** the visible `<details>` list renders — one query, two renderings, so schema and visible content can never drift apart (content parity, Definitions). It is omitted whenever the visible section is omitted (`@faqs.empty?`) — never an empty `mainEntity` array.

R8: `faq_page_schema(faqs)` returns:
```ruby
{
  "@context" => "https://schema.org",
  "@type" => "FAQPage",
  "mainEntity" => faqs.map { |faq|
    {
      "@type" => "Question",
      "name" => faq.question,
      "acceptedAnswer" => { "@type" => "Answer", "text" => faq.answer }
    }
  }
}
```

R9: Neither `Admin::FaqsController` nor `Admin::BusinessHoursController` (Part B) is added to `admin_nav_items` (`app/helpers/admin_helper.rb`) or the persistent nav's `<ul>`. Both are reachable only via new links on the dashboard (`GET /admin`) — `t("admin.dashboard.faqs_link")` and `t("admin.dashboard.business_hours_link")` — following the existing precedent set by `Users` and `Account`, which are also dashboard-only and not in the 5-item persistent nav.

R10: All admin-facing UI strings in `app/views/admin/faqs/` and `Admin::FaqsController` are rendered via `t()` under `admin.faqs`. No hardcoded English strings.

R11: The admin FAQ list, new, and edit forms follow CLAUDE.md's mobile-first rules: no horizontal scroll at any viewport width including 375 px; text inputs and the answer textarea carry `w-full`; the save button carries at minimum `py-3`; each card's Move Up/Down/Edit/Delete controls wrap (`flex flex-wrap gap-2`) rather than overflow, matching the established `services_pages` pattern.

### Part B — Business Hours

R12: `BusinessHours` is a singleton, read/written via `BusinessHours.first_or_initialize`, matching the `HomePageContent`/`AboutPageContent` singleton contract (ADR-004 Implementation Note 1) — but with **no `published` flag**. There is no draft/live distinction for hours; a day's presence or absence in the two nullable `time` columns is the only signal (R13), and that signal is exactly what the brief requires the schema to honor.

R13: For each day in `BusinessHours::DAYS`, that day has hours only when **both** `<day>_opens_at` and `<day>_closes_at` are present. Either column blank means "no hours for that day" — covering both "not yet entered" and "closed that day" with the same, single representation. No separate `closed` boolean is introduced.

R14: `BusinessHours` validates, for each day in `DAYS`: if exactly one of `<day>_opens_at` / `<day>_closes_at` is present (not both), an error is added on the present attribute (a half-filled day is invalid — both or neither). If both are present, `<day>_closes_at` must be after `<day>_opens_at` (a same-day span; overnight-spanning hours are not supported — a reasonable constraint for a daytime motorcycle shop, not a stated requirement to relax).

R15: `db/seeds.rb` ensures exactly one `BusinessHours` row exists via `first_or_initialize`, with every column left at its default `nil` — seeded blank, per the brief. Running seeds twice must not raise or create a second row.

R16: `BusinessHours#opening_hours_specification` returns an array of `OpeningHoursSpecification` hashes, one per day that satisfies R13, in `DAYS` order:
```ruby
{
  "@type" => "OpeningHoursSpecification",
  "dayOfWeek" => "https://schema.org/Monday",
  "opens" => "08:00",
  "closes" => "17:00"
}
```
(`opens`/`closes` formatted `%H:%M`.) Returns `nil` if zero days satisfy R13.

R17: `local_business_schema` includes the `openingHoursSpecification` key **only when `BusinessHours.first&.opening_hours_specification` is present** — omitted entirely (not an empty array, not a guessed value) when `BusinessHours` has no row or every day is blank. This is the literal requirement from the brief: the schema must never claim hours the shop hasn't confirmed.

R18: `GET /admin/business_hours` renders one row per `DAYS` entry — day label (`t("admin.business_hours.day_#{day}")`) plus two `f.time_field` inputs (`<day>_opens_at`, `<day>_closes_at`) labelled Opens/Closes. `PATCH /admin/business_hours` updates the singleton via `first_or_initialize`; on a validation failure (R14), re-renders `:show` at HTTP 422 with the errors.

R19: `app/views/pages/about.html.erb` renders a plain `<ul>` under a `t("pages.about.hours_heading")` heading, listing only the days that satisfy R13, in `DAYS` order, each formatted for human reading (e.g. `content.monday_opens_at.strftime("%-l:%M %p")` – `closes_at` likewise) — content parity for `BusinessHours`, mirroring R7's rule for FAQ: the schema must never describe hours that aren't also visible somewhere on the page. The whole block is omitted when zero days satisfy R13.

R20: `Admin::BusinessHoursController` and its views follow CLAUDE.md's mobile-first rules identically to R11 — `w-full` time inputs, `py-3` save button, no horizontal scroll at 375 px. Not added to the persistent nav (R9).

### Part C — Per-Page Titles, Meta Descriptions, Canonical URLs

R21: `app/views/layouts/application.html.erb`'s `<title>` becomes `content_for?(:title) ? content_for(:title) : t("application.title")`. A `<meta name="description">` tag is added, sourced identically via `content_for(:meta_description)` falling back to `t("application.meta_description")`.

R22: Each of the 4 public page views (`home`, `about`, `gallery`, `services`) sets, at the top of the template: `content_for :title, t("pages.<page>.meta_title")`, `content_for :meta_description, t("pages.<page>.meta_description")`, and `content_for :canonical_url, <page>_url` (e.g. `root_url`, `about_url`, `gallery_url`, `services_url`) — using the literal copy from the Interfaces table.

R23: The layout renders `<link rel="canonical" href="...">` using `content_for(:canonical_url)`, falling back to `request.base_url + request.path` if a page ever omits it (defensive; all 4 pages set it per R22, so this path should not trigger in practice).

R24: No page title or meta description mentions Idaho Falls, Boise, or Utah. Per the `areaServed` design (R30), those terms live in structured data and FAQ prose — not stacked into on-page titles/descriptions, which would read as the doorway-page pattern this spec explicitly rules out (Non-Goals).

R25: The `<title>`/description text is exactly the literal copy specified in the Interfaces table — not paraphrased or regenerated at implementation time.

### Part D — Structured Data: `LocalBusiness` / `MotorcycleRepair`

R26: The layout (`application.html.erb`) renders one `<script type="application/ld+json">` block, present on every public page (Home, About, Gallery, Services — wherever the layout renders), containing `json_escape(local_business_schema.to_json)`.

R27: `local_business_schema` uses `@type: "MotorcycleRepair"` (schema.org: `LocalBusiness > AutomotiveBusiness > MotorcycleRepair`) rather than generic `LocalBusiness`. *Implementation Decision:* this is a strict specialization — every property used here (`telephone`, `address`, `geo`, `areaServed`, `openingHoursSpecification`) is valid on both types, so falling back to plain `LocalBusiness` is a one-line change if `MotorcycleRepair` ever causes a rich-result validation issue. Chosen because it is the closest schema.org type to what this business actually is, and more specific typing is generally more useful to answer engines, not less.

R28: `local_business_schema`'s `telephone` and `address.streetAddress` reuse the **exact same resolved value** the About page itself renders — `content = AboutPageContent.first&.published? ? AboutPageContent.first : nil`, then `content&.shop_phone_number || t("pages.about.shop_phone_number")` and `content&.shop_address || t("pages.about.shop_address")` — never a second, independently hardcoded copy. If Doug edits the phone number or address on the About page, the schema updates with it automatically.

R29: `address.addressLocality`, `address.addressRegion`, `address.postalCode`, and `address.addressCountry` are the fixed constants from Interfaces (`ADDRESS_LOCALITY`/`ADDRESS_REGION`/`POSTAL_CODE`/`ADDRESS_COUNTRY`) — not admin-editable, not parsed out of the free-text `shop_address` string (Non-Goals). `geo.latitude`/`geo.longitude` are the fixed `GEO_LATITUDE`/`GEO_LONGITUDE` constants.

R30: `local_business_schema`'s `areaServed` is the fixed `AREA_SERVED` array from Interfaces (Pocatello, Idaho Falls, Boise as `City`; Idaho, Utah as `State`) — not derived from any admin-editable field, since it is a standing claim about service reach the shop confirmed directly, not page content that changes.

R31: `local_business_schema`'s `image` is `image_url("gallery/m45a2849.jpg")` — the same photo already used as the Home hero background — and `url` is `root_url`. `name` is the `BUSINESS_NAME` constant.

R32: Every `<script type="application/ld+json">` block in this spec (`local_business_schema`, `faq_page_schema`) is embedded as `json_escape(hash.to_json)`, never a bare `.to_json` — `json_escape` (Rails' `ActionView::Helpers::JavaScriptHelper`) escapes `<`, `>`, and `&`, which a raw `.to_json` does not, preventing an admin-authored FAQ answer or address value containing `</script>` from breaking out of the script context.

### Part E — Sitemap and Robots

R33: `SitemapsController#show` renders `app/views/sitemaps/show.xml.builder` (`Content-Type: application/xml`), a `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` containing one `<url><loc>` entry for `root_url`, `about_url`, and `gallery_url` unconditionally, plus `services_url` **only when** `SiteSetting.enabled?("services_page_published")` — the identical check `PagesController#services` and `shared/_nav.html.erb` already use. No `<lastmod>`, `<changefreq>`, or `<priority>` (Non-Goals).

R34: `RobotsController#show` renders `app/views/robots/show.text.erb` (`Content-Type: text/plain`). **In production** (`Rails.env.production?`): `Allow: /`, `Disallow: /admin`, and a `Sitemap:` line pointing at `sitemap_url`. **In every other environment** (staging included): `Disallow: /` — nothing is crawlable. *Implementation Decision:* staging is a real, publicly reachable host (`staging.syndicate-development.com`, per `config/deploy.staging.yml`) with no separate access control. Shipping a permissive `robots.txt` there risks a search engine indexing the staging site — duplicate content at best, a competing/stale result at worst. Gating on `Rails.env.production?` (already how this app distinguishes environments — `RAILS_ENV=staging` is set in `config/deploy.staging.yml`) is simple, environment-accurate, and needs no new configuration.

R35: `public/robots.txt` is **deleted** from the repo. Rails' static file middleware (`ActionDispatch::Static`, active whenever `config.public_file_server` headers are configured — true in every environment per `config/environments/*.rb`) serves a matching file under `public/` before a request ever reaches the router. Leaving the stub in place would permanently shadow the new dynamic route regardless of what the route or controller does.

R36: `app/views/layouts/admin.html.erb` gains `<meta name="robots" content="noindex, nofollow">` in its `<head>`, present whenever the admin layout renders. Defense in depth alongside R34's `Disallow: /admin` — a crawler that ignores `robots.txt`, or an admin URL that ends up linked somewhere, still can't get an admin page indexed.

R37: Sitemap and robots routes are unauthenticated, top-level (not under `namespace :admin`), matching `PagesController`'s existing public routes.

R38: No `public/sitemap.xml` exists to conflict with the new dynamic route (confirmed — none currently in the repo), so R35's deletion concern applies only to `robots.txt`.

### Part F — Open Graph / Twitter Cards

R39: The layout adds, sourced from the same `content_for(:title)`/`content_for(:meta_description)` values R21–R22 already resolve (no second copy authored):
```html
<meta property="og:type" content="website">
<meta property="og:site_name" content="<%= t('application.name') %>">
<meta property="og:title" content="<resolved title>">
<meta property="og:description" content="<resolved description>">
<meta property="og:url" content="<resolved canonical URL>">
<meta property="og:image" content="<%= image_url('gallery/m45a2849.jpg') %>">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="<resolved title>">
<meta name="twitter:description" content="<resolved description>">
<meta name="twitter:image" content="<%= image_url('gallery/m45a2849.jpg') %>">
```
*Implementation Decision:* `og:type` is `website`, not `business.business` — the latter requires additional Facebook-specific business-vertical properties with uncertain platform support; `website` is simple and universally valid.

R40: `og:image`/`twitter:image` reuse the same `gallery/m45a2849.jpg` asset as `local_business_schema.image` (R31) — one default image, not a separate OG-specific asset (Non-Goals).

### Part G — Footer

R41: `app/views/layouts/application.html.erb` gains a `<footer>` after `<%= yield %>` and before `</body>`, rendering `t("application.footer.copyright", year: Date.current.year, business_name: t("application.name"))`. No address, phone, or nav links — explicitly declined by the user.

R42: The footer carries a dark background consistent with the site's existing header color (`#242121`), centered text, adequate padding, and introduces no horizontal scroll at any viewport width (CLAUDE.md mobile-first).

R43: The year is computed at render time (`Date.current.year`) — never a hardcoded literal — so it advances automatically with no code change required.

### Part H — Favicon

R44: `public/icon.png` is replaced with a 32×32 PNG crop of the shop's lion logo; `public/apple-touch-icon.png` (new file) is a 180×180 PNG crop of the same source. `public/icon.svg` is deleted — no vector source exists for the lion mark, and scaling a raster crop up to fake one is out of scope.

R45: **Source and crop, verified during spec authoring:** fetch `https://syndicate-development.com/moto.png` (822×540 PNG, transparent background — this is the pre-optimization original; `app/assets/images/syndicate-lion.png` in this repo is a post-optimization 177×150 crop, too small to re-crop cleanly for a 180×180 target). Crop a 540×540 square anchored at the top-left corner (`x: 0, y: 0` to `x: 540, y: 540`), which keeps the full roaring head and most of the mane while dropping only the thin trailing mane wisp past `x: 540`. Verified during spec authoring (both the 540×540 crop, and that crop downscaled to 180×180 and to 32×32) to read clearly as a lion head at both target sizes. Suggested recipe: `sips -c 540 540 --cropOffset 0 0 moto-original.png --out lion-square.png`, then `sips -z 180 180 lion-square.png --out apple-touch-icon.png` and `sips -z 32 32 lion-square.png --out icon.png` (or an equivalent image tool) — transparency preserved throughout.

R46: `application.html.erb`'s favicon links become:
```html
<link rel="icon" href="/icon.png" type="image/png" sizes="32x32">
<link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">
```
replacing the current 3-line stock-Rails block (`icon.png` without `sizes`, `icon.svg`, `apple-touch-icon` pointing at the same 512×512 stock file).

R47: Only the public layout changes. The admin layout gets no favicon markup (Non-Goals).

### Part I — Contact Form Spam Protection

R48: `ContactsController` gains three declarative rate limits, evaluated ahead of `#create`'s body, using Rails 8's built-in `rate_limit` — the same mechanism `Admin::SessionsController` already uses:
```ruby
rate_limit to: 5, within: 10.minutes, only: :create, name: "contact_per_ip",
  by: -> { request.remote_ip },
  with: -> { fake_success_response }

rate_limit to: 3, within: 10.minutes, only: :create, name: "contact_per_email",
  by: -> { params[:email].to_s.strip.downcase },
  with: -> { fake_success_response }
```
*Rationale for the numbers:* three genuine submissions from the same claimed email within 10 minutes is already an edge case (a typo correction, an immediate follow-up); a fourth is far more likely automated. Five from one IP within 10 minutes covers a shared connection (e.g. a household) making more than one genuine enquiry while still bounding a flood. Both windows are short enough that a real visitor who gets throttled by mistake can simply try again shortly after — there is no account to lock out here, unlike login.

R49: Unlike `Admin::SessionsController`'s rate limits — which deliberately tell a real, locked-out admin what happened (`t("admin.login.too_many_attempts")`) — the contact form's rate-limit rejection produces the **identical response a successful submission produces** (`fake_success_response`, R52). This is a deliberate divergence from the login precedent, not an inconsistency: the constraint here is that a blocked submission must not reveal why it was blocked, which login's UX goal (inform a real, inconvenienced admin) does not share.

R50: `request.remote_ip` and `params[:email]` are read the same way `Admin::SessionsController` reads them — `request.remote_ip` already respects this app's configured `trusted_proxies` (`config/environments/production.rb`/`staging.rb`), and `params[:email]` is normalized (`.to_s.strip.downcase`) before being used as a rate-limit key, exactly like the login email-keyed limit. This narrows, but as the existing login comment already documents, does not eliminate, the risk of a spoofed `X-Forwarded-For` resetting the IP-keyed bucket — the email-keyed bucket is what holds when it is.

R51: A hidden honeypot field, name `website`, is added to the contact form (`app/views/pages/about.html.erb`) inside the existing `form_with url: contact_path` block:
```erb
<div aria-hidden="true" class="absolute -left-[9999px] -top-[9999px]">
  <%= label_tag :website, t("contact.form.honeypot_label") %>
  <%= text_field_tag :website, nil, autocomplete: "off", tabindex: -1 %>
</div>
```
`aria-hidden="true"` on the wrapping element removes both the label and field from the accessibility tree entirely (not just visually hidden — genuinely absent to a screen reader, per the brief's explicit accessibility requirement); `tabindex="-1"` keeps it out of keyboard tab order; the off-screen absolute positioning (not `display: none` or `visibility: hidden`) defeats bots that specifically check for and skip those two properties. `autocomplete="off"` reduces (does not eliminate) the chance of a password manager's autofill triggering a false positive against a genuine visitor.

R52: `ContactsController` gains a private `fake_success_response` method — `redirect_to about_path, notice: I18n.t("contact.notices.message_sent")` — the single place that response is built, called by every rejection path (R48's two `with:` lambdas, and the `before_action`s in R53–R54) so the "what does a block look like" behavior has one definition, not four independent copies that could drift apart.

R53: A `before_action :reject_if_honeypot_filled, only: :create` runs `fake_success_response` and returns (no email sent, no further processing) whenever `params[:website].present?`.

R54: A signed timing token is rendered as a hidden field in the same form:
```erb
<%= hidden_field_tag :rendered_at, contact_form_rendered_at_token %>
```
where `contact_form_rendered_at_token` (a new `ApplicationHelper` method) is `Rails.application.message_verifier(:contact_form).generate(Time.current.to_i)`. A `before_action :reject_if_submitted_too_quickly, only: :create` decodes it —
```ruby
rendered_at = Rails.application.message_verifier(:contact_form).verify(params[:rendered_at])
```
rescuing `ActiveSupport::MessageVerifier::InvalidSignature` (tampered or absent token) as a rejection — and calls `fake_success_response` (no email sent) unless `Time.current.to_i - rendered_at >= 2` (`ContactsController::MINIMUM_SECONDS_BEFORE_SUBMIT = 2`). No upper bound — a real visitor who leaves the page open a long time before submitting is not penalized, only a submission arriving implausibly fast is rejected.

R55: Check order in `#create`'s `before_action` chain: honeypot (R53) → timing (R54) → the two `rate_limit`s (R48, evaluated by Rails' own filter mechanism) → the existing name/email/message presence validation (unchanged). Only a submission that clears every spam-defense gate reaches the existing validation logic, whose behavior (alert flash on a genuinely missing required field, real send + notice flash on success) is **completely unchanged** by this spec — spam defenses and field validation produce visibly identical *rejection* responses only when spam is what's being rejected; a real visitor's own mistake still gets real, specific feedback.

R56: `deliver_now` is retained (Non-Goals) — the rate limits in R48 are this pass's mitigation for the synchronous-SMTP DoS exposure `deliver_now` carries, pending a queue supervisor running in every environment.

R57: `spec/requests/contacts_spec.rb`'s shared `valid_params` is extended to include a validly-signed, sufficiently-aged `rendered_at` token by default (e.g. signed for a timestamp several seconds in the past — deterministic, no sleep needed in a request spec that never renders the real page) so every existing scenario — success and the missing-field failure cases alike — still clears the new gates and exercises the same behavior it did before. New scenarios are added (not substituted) for honeypot-filled, timing-too-fast, and both rate limits.

R58: `spec/system/contact_form_spec.rb`'s scenarios that submit the form add an explicit wait (e.g. `sleep` for longer than `MINIMUM_SECONDS_BEFORE_SUBMIT`) between visiting the page and clicking submit. *Implementation Decision:* the real page render already produces a genuine, validly-signed token — the only risk is a fast Capybara/Selenium run completing well under the 2-second floor, which would make an unmodified system spec flaky (sometimes above the threshold, sometimes not) rather than reliably passing. An explicit, deliberate wait removes that flakiness outright rather than papering over it.

---

## Edge Cases

E1: Zero `Faq` rows exist. Home page renders with no FAQ section at all (R6) and no `FAQPage` script (R7) — not an empty heading, not an empty `mainEntity` array.

E2: A `Faq` create is submitted with a blank `answer`. Rejected (422), no row persists, no partial/blank FAQ is ever visible (R2, matches ADR-004's "never blank" guarantee via ordinary validation rather than a publish flag).

E3: `move_up` is called on the `Faq` already at the lowest position (no lower neighbour). No-op — matches `ServiceSection`'s identical existing behavior when no neighbour exists.

E4: An `Faq` question or answer contains characters that are special in JSON or HTML (`"`, `<`, `&`, an embedded `</script>`-like string). Both the visible `<details>` rendering (auto-escaped by ERB) and the `FAQPage` script (`json_escape`, R32) render it safely; neither breaks page structure.

E5: `BusinessHours` has a row where `monday_opens_at` is set but `monday_closes_at` is blank. Invalid (R14); update rejected at 422.

E6: `BusinessHours` has a row where every day is blank (the seeded state). `opening_hours_specification` returns `nil` (R16); `local_business_schema` omits `openingHoursSpecification` entirely (R17); the About page's visible hours block is omitted entirely (R19).

E7: `BusinessHours` has 3 of 7 days set, the rest blank. Both the schema's `openingHoursSpecification` array and the visible hours list contain exactly those 3 days, in `DAYS` order, and nothing else.

E8: No `BusinessHours` row exists at all (pre-seed, or seeds never run). Treated identically to "every day blank" (E6) — `BusinessHours.first` is `nil`, `&.opening_hours_specification` is `nil`, both the schema key and the visible block are omitted. No `NoMethodError`.

E9: `<day>_closes_at` submitted equal to or before `<day>_opens_at`. Rejected (R14); no overnight-spanning hours are supported.

E10: A page view fails to set `content_for(:canonical_url)` (should not happen given R22, but exercised as a regression guard). The layout's fallback (`request.base_url + request.path`, R23) still renders a valid, non-blank canonical URL.

E11: `/services` is unpublished (`SiteSetting.enabled?("services_page_published")` is `false`). It is absent from `sitemap.xml` (R33, AC-35) and unreachable directly (existing, unmodified `check_services_published` redirect) — the two behaviors already imply each other in this app, but the sitemap's own check is asserted independently rather than assumed.

E12: `AboutPageContent.first` is `nil` or unpublished. `local_business_schema`'s `telephone`/`streetAddress` fall back to the same `t("pages.about.*")` values the About page itself falls back to (R28) — never a raised error, never a blank schema field.

E13: The shop's registered address, phone, or geo coordinates never change during this feature's lifetime under normal operation — the fixed constants (R29, R30) are not expected to need editing; if the shop ever relocates, that is a code change alongside the CLAUDE.md business-context update, not a runtime concern.

E14: A gallery/services page renders while `AboutPageContent`'s `shop_phone_number`/`shop_address` are mid-edit (invalid, not yet saved) in an open admin tab. The public schema always reads the last **persisted** state — an in-progress, unsaved admin edit never leaks into `local_business_schema` on any public page, including ones other than About.

E15: `Rails.env.production?` is false but the app is reachable at a public host (staging today; potentially a future review environment). `robots.txt` disallows everything (R34) regardless of which non-production host is serving the request — the check is purely on `Rails.env`, not on the request's `Host` header.

E16: A crawler ignores `robots.txt` entirely and requests an `/admin/*` page directly. The admin layout's `noindex, nofollow` meta tag (R36) still prevents indexing even though the page itself still renders normally for an authenticated admin — defense in depth, not an access control.

E17: `/robots.txt` is requested with the static stub from a stale deployed image still present (a deploy that skipped R35's deletion). Flagged here as the specific regression R35 exists to prevent — the static file would shadow the dynamic route with no error, so `AC-40` asserts the file's absence directly rather than only asserting the route's behavior, which a shadowed route would still appear to pass for the wrong reason.

E18: `og:image`/`twitter:image`/`local_business_schema.image` all point at the same asset. A broken or missing `gallery/m45a2849.jpg` would degrade all three simultaneously — an accepted, single point of dependency, since introducing per-surface fallback images is out of scope for this pass.

E19: A visitor's browser aggressively autofills every input on a page, including off-screen ones, filling the honeypot `website` field despite `autocomplete="off"`. Accepted, documented risk (R51) — a real submission would then be silently treated as spam (`fake_success_response`, no email sent, no error shown). Mitigation if this is observed in practice: rename the field, a one-line change; not solved preemptively without evidence it's needed.

E20: The honeypot is filled **and** the timing check would also have passed **and** the fields are all otherwise valid. Still rejected — honeypot alone is sufficient (R53 runs before, and independently of, R54).

E21: The `rendered_at` param is present but signed by a different `message_verifier` purpose, or is a plain unsigned integer a bot fabricated. `MessageVerifier#verify` raises `InvalidSignature` for both; both are treated as a rejection (R54), not a crash.

E22: A submission arrives with a validly-signed `rendered_at` exactly 2 seconds old (the floor). Per R54's `>=`, this is accepted — the boundary is inclusive.

E23: The per-IP rate limit (5/10 min) is exhausted by requests that vary the claimed `email` each time. Still throttled — the per-IP bucket does not depend on the email param at all (R48).

E24: The per-email rate limit (3/10 min) is exhausted by requests arriving from different IPs (e.g. a botnet, or `X-Forwarded-For` variation) but claiming the same `email`. Still throttled — the per-email bucket does not depend on IP (R48), which is precisely the bound `Admin::SessionsController`'s own comments describe as "the one that holds when remote_ip is worthless."

E25: A genuine visitor submits the form with a missing required field (blank `name`) after clearing all spam gates. Existing behavior is completely unchanged: redirect to `/about` with the existing alert flash, no email sent — this is not a spam rejection and must not be silently converted into a fake-success response (R55).

---

## Acceptance Criteria

### FAQ

AC-1: `bin/rails db:migrate` on a fresh database creates `faqs` with exactly `question`, `answer`, `position`, `created_at`, `updated_at`.

AC-2: A `Faq` with blank `question` or blank `answer` is invalid.

AC-3: Given zero prior `Faq` rows, `POST /admin/faqs` with valid params creates a row with `position: 0`.

AC-4: Given a `Faq` at `position: 0`, `POST /admin/faqs` with a second valid `Faq` creates it at `position: 1`.

AC-5: `PATCH /admin/faqs/:id/move_up` swaps the target's position with its nearest lower neighbour; called on the lowest-position row, it is a no-op.

AC-6: `DELETE /admin/faqs/:id` removes the row and redirects to `admin_faqs_path` with `flash[:notice]`.

AC-7: Given zero `Faq` rows, `GET /admin/faqs` returns 200 and includes `t("admin.faqs.empty_state")`.

AC-8: Given 3 `Faq` rows, `GET /` returns 200 and the response body contains 3 `<details>` elements, each containing its `question` in a `<summary>` and its `answer`, in position order.

AC-9: Given zero `Faq` rows, `GET /` returns 200 and the response body contains no FAQ heading, no `<details>` element, and no `<script type="application/ld+json">` block whose parsed `@type` is `"FAQPage"`.

AC-10: Given 3 `Faq` rows, `GET /`'s `FAQPage` JSON-LD `mainEntity` array has exactly 3 entries, in the same order as the visible `<details>` list, each `name`/`acceptedAnswer.text` matching the corresponding `question`/`answer`.

AC-11: A `Faq` whose `answer` contains `</script><script>` renders on the page without breaking subsequent markup, and the same string appears correctly escaped inside the `FAQPage` JSON-LD script.

AC-12: `GET /admin` includes `href`s matching both `admin_faqs_path` and `admin_business_hours_path`; neither `href` appears inside the persistent nav's `<ul>` (`app/views/layouts/admin.html.erb`'s nav element).

AC-13: No hardcoded English strings in `app/views/admin/faqs/` or `Admin::FaqsController`.

AC-14: The admin FAQ index/new/edit views render without horizontal scroll at 375 px; text inputs and the answer textarea carry `w-full`; the save button carries `py-3`.

### Business Hours

AC-15: `bin/rails db:migrate` creates `business_hours` with exactly the 14 nullable `time` columns plus timestamps.

AC-16: A `BusinessHours` with `monday_opens_at` set and `monday_closes_at` blank is invalid.

AC-17: A `BusinessHours` with `tuesday_closes_at` earlier than `tuesday_opens_at` is invalid.

AC-18: A `BusinessHours` with every column blank is valid.

AC-19: `db/seeds.rb` run on a clean database creates exactly one `BusinessHours` row with every column `nil`; run twice, `BusinessHours.count` is still 1.

AC-20: `PATCH /admin/business_hours` with valid hours for `friday` persists them and redirects with `flash[:notice]`.

AC-21: `PATCH /admin/business_hours` with an invalid day (E5-shaped) returns 422 and re-renders `:show` with the error.

AC-22: Given `BusinessHours` has every column blank, `GET /about`'s response body contains no hours list (no `t("pages.about.hours_heading")`, no day text).

AC-23: Given `BusinessHours` has `monday`/`wednesday`/`friday` set and the rest blank, `GET /about`'s hours list contains exactly those 3 days, in Monday–Sunday order, and no others.

AC-24: Given the same `BusinessHours` state as AC-23, `GET /`'s (or wherever `local_business_schema` renders — every public page) `LocalBusiness` JSON-LD has an `openingHoursSpecification` array with exactly 3 entries matching those days' `opens`/`closes` in `HH:MM` format, and no `openingHoursSpecification` key at all when every day is blank (AC-25).

AC-25: Given `BusinessHours` has every column blank (or no row exists), the `LocalBusiness` JSON-LD object has no `openingHoursSpecification` key present at all — not an empty array.

### Titles, Meta Descriptions, Canonical

AC-26: `GET /` returns a `<title>` equal to `t("pages.home.meta_title")` and a `<meta name="description">` whose `content` equals `t("pages.home.meta_description")`.

AC-27: `GET /about`, `GET /gallery`, `GET /services` (when published) each return their own distinct `<title>`/description per the Interfaces table — no two pages share a title.

AC-28: Each of the 4 pages' response includes `<link rel="canonical" href="...">` equal to that page's own canonical URL (`root_url`, `about_url`, `gallery_url`, `services_url`).

AC-29: No page's `<title>` or meta description contains the strings "Idaho Falls", "Boise", or "Utah".

### Structured Data

AC-30: Every public page's response includes exactly one `<script type="application/ld+json">` block whose parsed content has `"@type": "MotorcycleRepair"`.

AC-31: That object's `telephone` and `address.streetAddress` equal the same resolved values the About page itself currently renders for phone/address, under both published and unpublished `AboutPageContent` states.

AC-32: That object's `address.addressLocality`, `addressRegion`, `postalCode`, `addressCountry` equal `"Pocatello"`, `"ID"`, `"83204"`, `"US"` respectively; `geo.latitude`/`geo.longitude` equal `42.8739291`/`-112.4668151`.

AC-33: That object's `areaServed` array has exactly 5 entries matching the fixed `AREA_SERVED` list (Pocatello, Idaho Falls, Boise as City; Idaho, Utah as State).

AC-34: That object's `image` and `url` resolve to `gallery/m45a2849.jpg`'s absolute URL and `root_url` respectively.

### Sitemap and Robots

AC-35: `GET /sitemap.xml` returns `Content-Type: application/xml` (or `text/xml`) containing `<loc>` entries for `/`, `/about`, `/gallery`, and no entry for `/services` when `services_page_published` is `false`.

AC-36: Given `services_page_published` is `true`, `GET /sitemap.xml` includes a `<loc>` entry for `/services`.

AC-37: `GET /sitemap.xml`'s response contains no `<lastmod>`, `<changefreq>`, or `<priority>` element.

AC-38: In the `production` environment, `GET /robots.txt` returns `Allow: /`, `Disallow: /admin`, and a `Sitemap:` line containing the full sitemap URL.

AC-39: In the `test`/non-production environment, `GET /robots.txt` returns `Disallow: /` and no `Allow:` line.

AC-40: `public/robots.txt` does not exist in the repository after this spec.

AC-41: `GET /admin` (and any other admin page) includes `<meta name="robots" content="noindex, nofollow">` in the response head.

### Open Graph / Twitter / Footer / Favicon

AC-42: `GET /`'s response includes `og:title`, `og:description`, `og:url`, `og:image`, `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image` meta tags, with `og:title`/`twitter:title` equal to the page's own `<title>` and `og:description`/`twitter:description` equal to its meta description.

AC-43: `og:image` and `twitter:image` are absolute URLs pointing at the same asset as `local_business_schema.image`.

AC-44: Every public page's response includes a `<footer>` containing the current year (`Date.current.year`) and `t("application.name")`, and no address, phone number, or navigation link inside that `<footer>` element.

AC-45: Two requests made in different years (simulated via `travel_to`) each render the footer with their own respective year — the year is not baked in at boot or asset-compile time.

AC-46: The layout's favicon links are exactly `<link rel="icon" href="/icon.png" type="image/png" sizes="32x32">` and `<link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">`; no `icon.svg` link is present.

AC-47: `public/icon.png` is a 32×32 PNG; `public/apple-touch-icon.png` is a 180×180 PNG; `public/icon.svg` does not exist in the repository.

AC-58: The admin Business Hours form (`GET /admin/business_hours`) renders without horizontal scroll at 375 px viewport width; the day/time inputs carry `w-full`; the save button carries at minimum `py-3`.

AC-59: The footer renders without horizontal scroll at 375 px viewport width and uses a background color consistent with the site header's `#242121`.

AC-60: `app/views/layouts/admin.html.erb` contains no favicon `<link>` tags added by this spec — the admin tab icon is unchanged (Non-Goals).

### Contact Form Spam Protection

AC-48: `POST /contact` with all required fields valid, no honeypot filled, and a `rendered_at` token signed ≥2 seconds in the past sends exactly one email and redirects to `/about` with the success notice (unchanged from current behavior).

AC-49: `POST /contact` with `website` (honeypot) present and non-blank, all other fields otherwise valid, sends zero emails and produces a response byte-for-byte indistinguishable in status/redirect/flash from AC-48's success response.

AC-50: `POST /contact` with a `rendered_at` token signed less than 2 seconds before the request sends zero emails and produces the same fake-success response.

AC-51: `POST /contact` with `rendered_at` missing entirely, or present but not a validly-signed token, sends zero emails and produces the same fake-success response.

AC-52: `POST /contact` repeated 6 times within 10 minutes from the same IP (varying `email` each time, all otherwise valid + past-threshold token) sends at most 5 emails; the 6th produces the fake-success response and sends no email.

AC-53: `POST /contact` repeated 4 times within 10 minutes with the same `email` (varying IP via `X-Forwarded-For`, all otherwise valid + past-threshold token) sends at most 3 emails; the 4th produces the fake-success response and sends no email.

AC-54: `POST /contact` with a blank `name`, honeypot empty, and a valid past-threshold token still produces the existing alert-flash behavior (`t("contact.errors.missing_required_fields")`) and sends zero emails — the pre-existing validation-error UX is unchanged and is not converted into a fake-success response.

AC-55: The honeypot field's wrapping element carries `aria-hidden="true"`; the input itself carries `tabindex="-1"` and `autocomplete="off"`; neither the label nor the input is positioned on-screen (verified via its CSS class, not `display:none`/`visibility:hidden`).

AC-56: `spec/requests/contacts_spec.rb`'s existing scenarios (success, missing name, missing email, missing message, phone optional, phone passed through) all still pass after this spec's changes, using a `valid_params` that includes a valid honeypot-blank + past-threshold-timing default.

AC-57: `spec/system/contact_form_spec.rb`'s existing scenarios all still pass, with an added deliberate wait before each form submission exceeding the minimum-elapsed threshold.

---

## Acceptance Tests

AT1
Given zero `Faq` rows
When `bin/rails db:migrate` runs on a fresh database
Then `faqs` exists with exactly `question`, `answer`, `position`, `created_at`, `updated_at`
Covers: R1, R2, R3, AC-1

AT2
Given a new `Faq` with blank `answer`
When `valid?` is called
Then it is invalid with an error on `:answer`
Covers: R2, AC-2, E2

AT3
Given zero prior `Faq` rows, admin authenticated
When `POST /admin/faqs` with valid `question`/`answer`
Then a row is created with `position: 0`
Covers: R3, AC-3

AT4
Given a `Faq` at `position: 0`
When `POST /admin/faqs` with a second valid `Faq`
Then the new row's `position` equals 1
Covers: R3, AC-4

AT5
Given 3 `Faq` rows at positions 0, 1, 2, admin authenticated
When `PATCH /admin/faqs/:id/move_up` is called on the row at position 1
Then it swaps positions with the row at position 0, and calling it again on the now-lowest row is a no-op
Covers: R4, AC-5, E3

AT6
Given a `Faq` exists, admin authenticated
When `DELETE /admin/faqs/:id`
Then the row no longer exists, the response redirects to `admin_faqs_path`, and `flash[:notice]` is present
Covers: R5, AC-6

AT7
Given zero `Faq` rows, admin authenticated
When `GET /admin/faqs`
Then HTTP 200 and the response includes `t("admin.faqs.empty_state")`
Covers: R5, AC-7

AT8
Given 3 `Faq` rows with distinct question/answer text
When `GET /`
Then HTTP 200, the response contains 3 `<details>` elements in position order, each with its question inside `<summary>` and its answer in the body
Covers: R6, AC-8

AT9
Given zero `Faq` rows
When `GET /`
Then the response contains no FAQ heading, no `<details>` element, and no `application/ld+json` block with `"@type":"FAQPage"`
Covers: R6, R7, AC-9, E1

AT10
Given 3 `Faq` rows
When `GET /`'s response body is parsed for the `FAQPage` script
Then `mainEntity` has exactly 3 entries in the same order as the visible list, each `name`/`acceptedAnswer.text` matching the source row
Covers: R7, R8, AC-10

AT11
Given a `Faq` with `answer: "Safe </script><script>alert(1)</script> text"`
When `GET /`
Then the page renders without truncated/broken markup and the `FAQPage` script's JSON parses successfully with that exact string as the answer text
Covers: R7, R8, R32, AC-11, E4

AT12
Given admin is authenticated
When `GET /admin`
Then the response includes `href`s for `admin_faqs_path` and `admin_business_hours_path`, and neither appears inside the persistent nav `<ul>`
Covers: R9, AC-12

AT13
Given zero prior `BusinessHours` rows
When `bin/rails db:migrate` runs
Then `business_hours` exists with the 14 nullable time columns plus timestamps
Covers: R12, AC-15

AT14
Given a new `BusinessHours` with `monday_opens_at` set and `monday_closes_at` nil
When `valid?` is called
Then it is invalid with an error on `:monday_opens_at` or `:monday_closes_at`
Covers: R13, R14, AC-16, E5

AT15
Given a `BusinessHours` with `tuesday_closes_at` earlier than `tuesday_opens_at`
When `valid?` is called
Then it is invalid
Covers: R14, AC-17, E9

AT16
Given a `BusinessHours` with every column nil
When `valid?` is called
Then it is valid
Covers: R14, AC-18

AT17
Given a clean database
When `db/seeds.rb` runs, then runs again
Then exactly one `BusinessHours` row exists with every column nil after both runs
Covers: R15, AC-19

AT18
Given admin is authenticated
When `PATCH /admin/business_hours` with valid `friday_opens_at`/`friday_closes_at`
Then the singleton is updated, the response redirects, and `flash[:notice]` is present
Covers: R18, AC-20

AT19
Given admin is authenticated
When `PATCH /admin/business_hours` with `saturday_opens_at` set and `saturday_closes_at` blank
Then HTTP 422 and `:show` re-renders with the validation error
Covers: R14, R18, AC-21, E5

AT20
Given `BusinessHours` has `monday`/`wednesday`/`friday` set, the rest blank
When `GET /about`
Then the hours list contains exactly those 3 days in Monday–Sunday order and no others; when every column is blank, no hours list renders at all
Covers: R19, AC-22, AC-23, E6, E7

AT21
Given the same `BusinessHours` state as AT20 (3 days set)
When any public page renders `local_business_schema`
Then `openingHoursSpecification` has exactly 3 matching entries in `HH:MM` format; given `BusinessHours` has no row or every column blank, `openingHoursSpecification` is absent from the object entirely
Covers: R16, R17, AC-24, AC-25, E6, E8

AT22
Given no request-specific setup
When `GET /`, `GET /about`, `GET /gallery`, `GET /services` (published) are each requested
Then each returns its own distinct `<title>` and meta description exactly matching the Interfaces table, and none contains "Idaho Falls", "Boise", or "Utah"
Covers: R21, R22, R24, R25, AC-26, AC-27, AC-29

AT23
Given each of the 4 public pages
When requested
Then each response includes `<link rel="canonical">` equal to that page's own canonical URL
Covers: R22, R23, AC-28

AT24
Given a page renders without setting `content_for(:canonical_url)` (simulated)
When the layout renders
Then the canonical link falls back to `request.base_url + request.path` rather than omitting the tag
Covers: R23, AC-28, E10

AT25
Given any public page
When its `application/ld+json` `MotorcycleRepair` block is parsed
Then it is present exactly once, and `telephone`/`address.streetAddress` equal the same resolved values the About page renders, under both published and unpublished `AboutPageContent` states
Covers: R26, R27, R28, AC-30, AC-31, E12, E14

AT26
Given the same block
When parsed
Then `address.addressLocality/addressRegion/postalCode/addressCountry` and `geo.latitude/longitude` equal the fixed constants
Covers: R29, AC-32

AT27
Given the same block
When parsed
Then `areaServed` has exactly the 5 fixed entries, and `image`/`url` resolve to the hero photo and `root_url`
Covers: R30, R31, AC-33, AC-34

AT28
Given `services_page_published` is `false`, then `true`, with no admin session
When `GET /sitemap.xml` is requested in each state, unauthenticated
Then `/services` is absent, then present, while `/`, `/about`, `/gallery` are present in both, no `<lastmod>`/`<changefreq>`/`<priority>` ever appears, and no `public/sitemap.xml` static file exists to have shadowed this route
Covers: R33, R37, R38, AC-35, AC-36, AC-37, E11

AT29
Given `Rails.env` is `production`
When `GET /robots.txt`
Then the response contains `Allow: /`, `Disallow: /admin`, and a `Sitemap:` line
Covers: R34, AC-38

AT30
Given `Rails.env` is `test` (or any non-production environment)
When `GET /robots.txt`
Then the response contains `Disallow: /` and no `Allow:` line
Covers: R34, AC-39, E15

AT31
Given the repository as shipped by this spec
When `public/robots.txt` and `public/icon.svg` are checked
Then neither file exists
Covers: R35, R44, AC-40, AC-47, E17

AT32
Given admin is authenticated
When any admin page is requested
Then the response head includes `<meta name="robots" content="noindex, nofollow">`
Covers: R36, AC-41, E16

AT33
Given `GET /`
When the response is inspected
Then `og:title`/`twitter:title` equal the page's `<title>`, `og:description`/`twitter:description` equal its meta description, and `og:image`/`twitter:image` are absolute URLs matching `local_business_schema.image`
Covers: R39, R40, AC-42, AC-43

AT34
Given any public page
When rendered
Then a `<footer>` is present containing `Date.current.year` and `t("application.name")`, with no phone/address/nav link inside it
Covers: R41, R43, AC-44

AT35
Given `travel_to` two different years in turn
When `GET /` renders in each
Then the footer shows the corresponding year each time
Covers: R43, AC-45

AT36
Given the shipped layout
When inspected
Then the favicon `<link>` tags exactly match R46, with no `icon.svg` link present
Covers: R46, AC-46

AT37
Given `public/icon.png` and `public/apple-touch-icon.png`
When inspected
Then they are 32×32 and 180×180 PNGs respectively
Covers: R44, R45, AC-47

AT38
Given the contact form's default state (no honeypot, no rate limits exhausted)
When `POST /contact` with all required fields valid and a token signed 2+ seconds ago
Then exactly one email is sent and the response redirects to `/about` with the success notice
Covers: R55, R56, AC-48, E22

AT39
Given the contact form
When `POST /contact` with `website` present and otherwise-valid fields
Then zero emails are sent and the response is identical (status, redirect target, flash) to AT38's success response
Covers: R51, R53, R52, AC-49, E20

AT40
Given the contact form
When `POST /contact` with a `rendered_at` signed less than 2 seconds ago
Then zero emails are sent and the response matches the fake-success shape
Covers: R54, AC-50

AT41
Given the contact form
When `POST /contact` with `rendered_at` omitted, and separately with a garbage/tampered value
Then in both cases zero emails are sent and the response matches the fake-success shape
Covers: R54, AC-51, E21

AT42
Given a clean rate-limit cache
When `POST /contact` is sent 6 times within 10 minutes from the same IP with 6 different `email` values, all otherwise valid
Then at most 5 emails are sent, and the 6th response matches the fake-success shape byte-for-byte
Covers: R48, R49, R50, AC-52, E23

AT43
Given a clean rate-limit cache
When `POST /contact` is sent 4 times within 10 minutes with the same `email` but a different `X-Forwarded-For` value each time, all otherwise valid
Then at most 3 emails are sent, and the 4th response matches the fake-success shape byte-for-byte
Covers: R48, R49, R50, AC-53, E24

AT44
Given the contact form
When `POST /contact` with `name` blank, honeypot empty, and a valid past-threshold token
Then the response shows the existing alert flash (`t("contact.errors.missing_required_fields")`) and sends zero emails — not the fake-success response
Covers: R55, AC-54, E25

AT45
Given the shipped honeypot markup
When inspected
Then the wrapper carries `aria-hidden="true"`, the input carries `tabindex="-1"` and `autocomplete="off"`, and neither relies on `display:none`/`visibility:hidden`
Covers: R51, AC-55

AT46
Given `spec/requests/contacts_spec.rb` as modified by this spec
When the full existing scenario list (success, missing name/email/message, phone optional, phone passed through) is run
Then every scenario still passes
Covers: R57, AC-56

AT47
Given `spec/system/contact_form_spec.rb` as modified by this spec
When the full existing scenario list is run
Then every scenario still passes with the added pre-submit wait
Covers: R58, AC-57

AT48
Given `app/views/admin/faqs/` and `Admin::FaqsController` source, plus those views rendered at 375 px viewport width
When inspected for hardcoded English string literals and for horizontal overflow
Then no hardcoded strings are found, no horizontal scroll occurs, text inputs and the answer textarea carry `w-full`, and the save button carries `py-3`
Covers: R10, R11, AC-13, AC-14

AT49
Given `app/views/admin/business_hours/show.html.erb` rendered at 375 px viewport width
When inspected
Then no horizontal scroll occurs, the day/time inputs carry `w-full`, and the save button carries `py-3`
Covers: R20, AC-58

AT50
Given the site footer rendered at 375 px viewport width
When inspected
Then no horizontal scroll occurs and the footer's background color matches the site header's `#242121`
Covers: R42, AC-59

AT51
Given `app/views/layouts/admin.html.erb` as modified by this spec
When inspected
Then it contains no favicon `<link>` tags — the admin tab icon is unchanged
Covers: R47, AC-60

---

## Implementation Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-08-04 | `Faq` is purely database-backed — no `published` flag, no i18n fallback, no restore-defaults action | Mirrors `ServiceSection` (ADR-001), not `AboutPageContent`/`HomePageContent` (ADR-004). FAQ has no pre-existing "original" copy to restore to, and every record is fully validated before it can ever be seen — the "never blank" guarantee ADR-004's pattern exists to provide is already satisfied by ordinary presence validation on create. |
| 2026-08-04 | `BusinessHours` uses blank-columns-as-signal instead of a `published` flag | The brief's own requirement — "omit `openingHours` entirely while blank" — is already exactly what per-day column presence gives for free. A separate flag would let hours be "published" while still blank, an extra state with no useful meaning. |
| 2026-08-04 | FAQ and Business Hours are dashboard-only links, not persistent-nav items | SPEC-009 already declined a 6th persistent nav item for mobile-width reasons and established the precedent (`Users`, `Account`) of dashboard-only entry points for secondary admin surfaces. Two new resources following the same precedent is more consistent than reopening that constraint. |
| 2026-08-04 | `LocalBusiness` schema uses `@type: "MotorcycleRepair"` | Schema.org's closest valid subtype for this business (`LocalBusiness > AutomotiveBusiness > MotorcycleRepair`), verified against schema.org's own type hierarchy during spec authoring. Every property used remains valid on plain `LocalBusiness` too, so this is reversible in one line if it ever proves to hurt rich-result eligibility. |
| 2026-08-04 | Address locality/region/postal/country are fixed constants, not admin-editable fields | Splitting the existing free-text `shop_address` into structured components is meaningful new admin surface (migration, form fields, i18n, tests) not requested in scope, and the sub-components in question (city/state/zip) do not change independent of a physical relocation — a genuinely rare event that would warrant a code change regardless. `streetAddress` itself still reuses the live, editable value to avoid a drifting duplicate. |
| 2026-08-04 | Geo coordinates sourced by resolving the About page's own existing Google Maps short link | Produces the exact coordinates the shop's own current site already asserts for its location, rather than an estimated/looked-up value — verified during spec authoring by following the redirect. |
| 2026-08-04 | FAQ section placed on the Home page, not a new `/faq` route or the gated `/services` page | Home always renders (no publish gate), gets the most traffic, and needs no new route, nav entry, or system-spec surface. Placing it on `/services` would risk the FAQ — the AEO lever the user called the most important piece of this spec — being invisible whenever Services is unpublished, which defeats the point. |
| 2026-08-04 | `robots.txt` is environment-aware (`Rails.env.production?`), not a static file | Staging is a real, publicly reachable host with no access control of its own. A permissive static `robots.txt` shipped there risks a search engine indexing pre-release content. |
| 2026-08-04 | Contact form: fake-success response for every spam-defense rejection, but unchanged behavior for genuine field-validation errors | The user's constraint is specifically "a blocked submission must not tell the bot why" — that applies to the three anti-spam layers, not to the pre-existing UX for a real visitor's own mistake, which continues to deserve honest, specific feedback. |
| 2026-08-04 | Contact form: `deliver_now` retained, rate limiting is the interim DoS mitigation | Matches the user's explicit deferral of `deliver_later` until Solid Queue runs in every environment (today: production only). Recorded so the deferred work is picked up once staging also runs a queue supervisor. |
| 2026-08-04 | Contact form timing threshold set at 2 seconds, with an explicit sleep added to the system spec rather than a lower/flakier threshold | A threshold low enough to never risk system-spec flakiness on a fast CI runner would also be too low to filter an instant scripted POST. An explicit wait removes the tension entirely rather than trading it for a weaker check. |

---

## Dependencies

- SPEC-007 (About Page Content Editing) — done. `AboutPageContent`, its `published`/i18n-fallback pattern (R3a), and the admin controller this spec's schema builder reads from and does not modify.
- SPEC-008 (Gallery Photo Management) — done. `gallery/m45a2849.jpg` (reused as the default OG/schema image) and the general precedent for admin-managed content this spec's FAQ/Business Hours controllers follow structurally (though FAQ's reorder mechanism follows `ServiceSection`, not `GalleryPhoto`'s drag-and-drop — see R4).
- SPEC-009 (About Slideshow Image Uploads / Persistent Admin Nav) — done. Establishes the persistent-5-item-nav constraint and the dashboard-only-link precedent this spec's FAQ/Business Hours navigation follows (R9).
- ADR-001 (Service Content Storage) — governs the "dedicated relational model over KV/singleton" reasoning FAQ follows instead of ADR-004's pattern; not re-derived here.
- ADR-002 (Services Page Icon Rendering and Ordering) — governs the gap-tolerant position-swap reordering FAQ's `move_up`/`move_down` duplicates from `ServiceSection`.
- ADR-004 (Singleton Content Model and Publish Flag Placement) — the pattern this spec explicitly does **not** apply to `Faq`, and does apply (minus the `published` flag) to `BusinessHours`; the divergence is justified in R1 and this spec's Implementation Decisions, not re-derived from the ADR itself.
- `Admin::SessionsController`'s existing `rate_limit` declarations — the direct precedent Part I's contact-form rate limits follow, including the "remote_ip alone is not enough" lesson already documented there.
- No new gems required. `Rails.application.message_verifier` (timing token), `rate_limit` (Rails 8 built-in), and `json_escape` (`ActionView::Helpers::JavaScriptHelper`) are all already available in this Rails 8.1.2 app.

---

## Proposed Task Breakdown

| Task | Description | ACs covered | Points |
|------|-------------|-------------|--------|
| T1 | `Faq` model + migration + validations (R1–R3); `Admin::FaqsController` (index/new/create/edit/update/destroy/move_up/move_down, R4); admin views mirroring `services_pages` stacked-card pattern (R5, R11); dashboard links (R9); i18n keys (R10). | AC-1–AC-7, AC-12–AC-14 | 5 |
| T2 | `BusinessHours` model + migration + validations (R12–R14); `db/seeds.rb` blank-seed (R15); `Admin::BusinessHoursController` show/update (R18, R20); admin form; i18n keys. | AC-15–AC-21, AC-58 | 3 |
| T3 | Home page: `@faqs` assignment, FAQ `<details>` section + `FAQPage` JSON-LD (R6–R8); About page: visible hours list (R19). | AC-8–AC-11, AC-22, AC-23 | 3 |
| T4 | `structured_data_helper.rb`: `local_business_schema` + `BusinessHours#opening_hours_specification` (R16, R17, R26–R32); wire into layout `<head>`; fixed constants module. | AC-24, AC-25, AC-30–AC-34 | 5 |
| T5 | Per-page title/description/canonical infrastructure (`content_for`, layout changes, R21–R25) across all 4 public views; new i18n copy. | AC-26–AC-29 | 2 |
| T6 | Sitemap (`SitemapsController`, `.xml.builder`, R33) + Robots (`RobotsController`, `.text.erb`, environment-aware, R34–R35, R37–R38); delete `public/robots.txt`; admin `noindex` meta (R36). | AC-35–AC-41 | 3 |
| T7 | Open Graph / Twitter tags (R39–R40); footer (R41–R43); favicon fetch/crop/export + layout links (R44–R47, admin layout untouched). | AC-42–AC-47, AC-59, AC-60 | 3 |
| T8 | Contact form: honeypot field + rejection (R51, R53); signed timing token + rejection (R54); two `rate_limit` declarations (R48–R50); `fake_success_response` (R52); check ordering (R55); `deliver_now` retained note (R56). | AC-48–AC-55 | 5 |
| T9 | Update `spec/requests/contacts_spec.rb` (`valid_params` default token, new spam-rejection scenarios, R57) and `spec/system/contact_form_spec.rb` (pre-submit wait, R58); full model/request/system test coverage for T1–T7 (FAQ, BusinessHours, schema, sitemap/robots, OG, footer, favicon, mobile-first 375px checks). | AC-56, AC-57 (+ regression coverage for all above) | 5 |

Total estimated points: 34. T4 and T8 sit closest to the 5-point split-review guardrail; both were reviewed and kept as single tasks — T4 has no natural mid-point split (the helper's two methods are read by the same layout change in the same PR), and T8's five sub-mechanisms (honeypot, timing, two rate limits, shared response) are small individually but must land together for the check ordering (R55) to be testable at all.

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-08-04 | Initial draft | All | Translates the user's SEO/AEO scope decisions (FAQ, per-page metadata, structured data, sitemap/robots, OG tags, footer, favicon, blank-seeded opening hours) plus mid-authoring additions — expanded `areaServed` geo terms (Idaho Falls, Boise, Idaho, Utah, confirmed genuine per the user's "customers travel because he's one of the best in the region"), the explicit exclusion of any shipping/mail-in claim, and contact form spam protection (honeypot, timing check, rate limiting) — into one implementation-ready spec, per explicit instruction to favor a single one-pass document over an exhaustive multi-spec decomposition. |

---

## Open Questions

None blocking implementation. Two items were explicitly resolved with the user during spec authoring rather than left open:

1. **Whether the shop takes customers who travel from outside Pocatello** — confirmed yes; reflected in `areaServed` (R30) and FAQ item 6 (seed content below).
2. **Whether the shop ships parts / offers remote service** — confirmed no; explicitly excluded (Non-Goals), with a note against re-adding it by assumption later.

One item is worth flagging for Doug specifically, not the developer: the FAQ is seeded with real, considered answers (not placeholders) so the admin never sees blank content, but seed content is still a starting draft in Doug's own voice, editable from the moment this ships. He should read all 6 before this reaches production, particularly the travel/out-of-state answer.

**FAQ seed content** (for `db/seeds.rb`, `position` 0–5):

1. Q: "What suspension work does Syndicate Development offer?"
   A: "We handle full suspension service for motocross and supercross bikes — revalving and re-springing tuned to your weight and riding style, fork and shock rebuilds, linkage and bearing service, and setup for track day or race day. Whether you're running stock components or a full custom suspension package, we tune it to how you actually ride."

2. Q: "Do you build complete race engines?"
   A: "Yes. We do full engine builds and rebuilds for motocross and supercross bikes, including top-end and bottom-end service, porting and head work, valve train upgrades, and engine blueprinting and balancing. Every build is set up and verified on our in-house dyno before it goes back to you."

3. Q: "Can you tune my bike's ECU?"
   A: "We do fuel injection mapping, ignition timing, and custom ECU tuning for fuel-injected motocross and supercross bikes, including launch and traction control setup and custom maps for aftermarket exhausts and air kits. All tuning is dyno-verified, not guesswork."

4. Q: "How long does a typical job take?"
   A: "Turnaround depends on the scope of the work — a suspension service or ECU tune is usually quicker than a full engine build. Give us a call or send a message with what you need done and we'll give you a realistic timeline before you drop the bike off."

5. Q: "Do you work on stock or trail bikes, or only race bikes?"
   A: "Both. While we specialize in custom performance work for motocross and supercross machines, we also handle regular servicing for stock and trail bikes — from routine maintenance to the same suspension and engine work we do for race bikes."

6. Q: "Do customers travel from outside Pocatello for work here?"
   A: "Yes — riders travel from across Idaho and northern Utah for suspension, engine, and ECU work, including from Idaho Falls, Boise, and the Salt Lake area. If you're coming from out of town, give us a call ahead of time so we can plan your build or service around your trip."
