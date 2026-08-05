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
- **No standalone `/faq` page, route, or controller, and no sitemap entry for one.** The FAQ has no URL of its own — it is always a section of the Home page (R6), the same as everything else on that page, editable through the admin CRUD already specced (Part A) and with no separate visibility control.
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

### FAQ Seed Content

This is the single, authoritative copy of the six question/answer pairs `db/seeds.rb` must create (R59) — normative content, not illustrative. It does not appear anywhere else in this document. Positions are 0-indexed in the order listed.

| Position | Question | Answer |
|----------|----------|--------|
| 0 | What suspension work does Syndicate Development offer? | We handle full suspension service for motocross and supercross bikes — revalving and re-springing tuned to your weight and riding style, fork and shock rebuilds, linkage and bearing service, and setup for track day or race day. Whether you're running stock components or a full custom suspension package, we tune it to how you actually ride. |
| 1 | Do you build complete race engines? | Yes. We do full engine builds and rebuilds for motocross and supercross bikes, including top-end and bottom-end service, porting and head work, valve train upgrades, and engine blueprinting and balancing. Every build is set up and verified on our in-house dyno before it goes back to you. |
| 2 | Can you tune my bike's ECU? | We do fuel injection mapping, ignition timing, and custom ECU tuning for fuel-injected motocross and supercross bikes, including launch and traction control setup and custom maps for aftermarket exhausts and air kits. All tuning is dyno-verified, not guesswork. |
| 3 | How long does a typical job take? | Turnaround depends on the scope of the work — a suspension service or ECU tune is usually quicker than a full engine build. Give us a call or send a message with what you need done and we'll give you a realistic timeline before you drop the bike off. |
| 4 | Do you work on stock or trail bikes, or only race bikes? | Both. While we specialize in custom performance work for motocross and supercross machines, we also handle regular servicing for stock and trail bikes — from routine maintenance to the same suspension and engine work we do for race bikes. |
| 5 | Do customers travel from outside Pocatello for work here? | Yes — we take suspension, engine, and ECU work from riders across southeast Idaho and the surrounding region, not just Pocatello. If you're coming from out of town, give us a call ahead of time so we can plan your build or service around your trip and have parts ready when you arrive. |

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

New keys under `admin.business_hours`: `heading`, `opens_label`, `closes_label`, `save`, `update_notice`, `hint` (explains that a blank day is omitted from the site's structured data and from the visible hours list), plus 7 day labels (`day_monday` … `day_sunday`) **for the admin form only** — no public view renders an `admin.*` key (see the public set below).

New keys under `admin.dashboard`: `faqs_link`, `business_hours_link`.

New keys under `pages.about`: `hours_heading` ("Hours"), plus 7 **public** day labels — the strings the About page's visible hours list renders (R19):

| Key | Value |
|-----|-------|
| `pages.about.hours.day_monday` | "Monday" |
| `pages.about.hours.day_tuesday` | "Tuesday" |
| `pages.about.hours.day_wednesday` | "Wednesday" |
| `pages.about.hours.day_thursday` | "Thursday" |
| `pages.about.hours.day_friday` | "Friday" |
| `pages.about.hours.day_saturday` | "Saturday" |
| `pages.about.hours.day_sunday` | "Sunday" |

These are a deliberately separate set from the `admin.business_hours.day_*` labels above, not a shared one: the About page is public output and must not render a key from the `admin` namespace, and the two surfaces are free to word a day differently without one edit changing the other. Both sets are suffixed with the same `BusinessHours::DAYS` strings (R12), so each surface needs exactly one interpolated lookup — `t("pages.about.hours.day_#{day}")` on the public page, `t("admin.business_hours.day_#{day}")` on the admin form — and neither needs a second copy of the day order.

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

R59 *(added out of sequence — see Change Log)*: `db/seeds.rb` creates exactly the 6 `Faq` rows listed in Interfaces → FAQ Seed Content, at positions 0–5 in that exact order, using the `question`/`answer` text **verbatim — not paraphrased or regenerated at implementation time** (mirrors R25's identical requirement for per-page title/description copy).

R60 *(added out of sequence — see Change Log; mechanism corrected, see Change Log)*: The seed is a **table-empty guard**, not a per-row lookup — `db/seeds.rb` creates all 6 rows from Interfaces → FAQ Seed Content **only when `Faq.count.zero?`**, e.g. `Faq.create!(question:, answer:, position:) for each (question, answer) in Interfaces → FAQ Seed Content, with position 0-5, all inside an if Faq.count.zero? guard`. If **any** `Faq` row already exists, for any reason, the seed does nothing at all — no create, no update, no per-row lookup.

*Implementation Decision, replaces an earlier per-row `find_or_create_by!(question:)` design (see Change Log):* that mechanism broke the moment an admin reworded a *question* — the very field it matched on. A reworded question no longer matches its original seed row, so a reseed would create a 7th, duplicate FAQ rather than recognizing the edited row as the same one. Rewording a question is not an edge case for an admin-editable FAQ; it is the ordinary use of one (E28). A table-empty guard closes the entire class of problem rather than patching one instance of it: it makes no assumption about which fields are stable, because it inspects nothing about individual rows — only whether the table has been touched at all. The seed's purpose is that the admin is not blank on first boot; once any `Faq` row exists, Doug owns the collection, and the seed has no further business touching it — whether he has edited a question, edited an answer, reordered rows, deleted some, or added his own.

This also removes a subtler defect the old mechanism had: deleting 3 of the 6 seeded rows and reseeding **used to silently restore exactly those 3** (the lookup found no match for the missing questions and recreated them) — partial resurrection nobody asked for. Under the table-empty guard, any surviving row blocks the seed entirely, so a partial deletion stays exactly as deleted (E29).

**One consequence, stated plainly rather than left to be discovered:** if Doug deletes *every* `Faq` row, a later reseed restores all 6, verbatim, because an empty table is indistinguishable from a fresh install — there is no way for the seed to tell "never seeded" apart from "seeded, then fully cleared" (E30). This is an accepted trade-off, not an oversight: it is strictly better than the old mechanism's partial-resurrection behavior, and it requires a far less likely admin action (clearing the entire starter set) than the bug it replaces (rewording one question).

### Part B — Business Hours

R12: `BusinessHours` is a singleton, read/written via `BusinessHours.first_or_initialize`, matching the `HomePageContent`/`AboutPageContent` singleton contract (ADR-004 Implementation Note 1) — but with **no `published` flag**. There is no draft/live distinction for hours; a day's presence or absence in the two nullable `time` columns is the only signal (R13), and that signal is exactly what the brief requires the schema to honor.

R13: For each day in `BusinessHours::DAYS`, that day has hours only when **both** `<day>_opens_at` and `<day>_closes_at` are present. Either column blank means "no hours for that day" — covering both "not yet entered" and "closed that day" with the same, single representation. No separate `closed` boolean is introduced.

R14: `BusinessHours` validates, for each day in `DAYS`: if exactly one of `<day>_opens_at` / `<day>_closes_at` is present (not both), an error is added on the present attribute (a half-filled day is invalid — both or neither). If both are present, `<day>_closes_at` must be after `<day>_opens_at` (a same-day span; overnight-spanning hours are not supported — a reasonable constraint for a daytime motorcycle shop, not a stated requirement to relax).

R15: `db/seeds.rb` ensures exactly one `BusinessHours` row **exists and is persisted**, with every column left at its default `nil` — seeded blank, per the brief. `first_or_initialize` alone builds an in-memory record and writes nothing, so the seed must either use `BusinessHours.first_or_create!` or follow `first_or_initialize` with an explicit `save!` guarded on `new_record?`, matching the `HomePageContent`/`AboutPageContent` blocks already in `db/seeds.rb`. Running seeds twice must not raise or create a second row.

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

R19: `app/views/pages/about.html.erb` renders a plain `<ul>` under a `t("pages.about.hours_heading")` heading, listing only the days that satisfy R13, in `DAYS` order — content parity for `BusinessHours`, mirroring R7's rule for FAQ: the schema must never describe hours that aren't also visible somewhere on the page. The whole block is omitted when zero days satisfy R13. Each row is a day label followed by that day's span:

- **Day label:** `t("pages.about.hours.day_#{day}")` — the public day keys defined in Interfaces → Required i18n Keys. Not an English literal (CLAUDE.md's no-hardcoded-strings rule, enforced by `spec/integration/locale_completeness_spec.rb`), and **not** `t("admin.business_hours.day_#{day}")`, which is admin-form chrome and must not appear in public output.
- **Span:** the two `time` columns formatted for human reading, e.g. `content.monday_opens_at.strftime("%-l:%M %p")` and `closes_at` likewise.

R20: `Admin::BusinessHoursController` and its views follow CLAUDE.md's mobile-first rules identically to R11 — `w-full` time inputs, `py-3` save button, no horizontal scroll at 375 px. Not added to the persistent nav (R9).

### Part C — Per-Page Titles, Meta Descriptions, Canonical URLs

R21: `app/views/layouts/application.html.erb`'s `<title>` becomes `content_for?(:title) ? content_for(:title) : t("application.title")`. A `<meta name="description">` tag is added, sourced identically via `content_for(:meta_description)` falling back to `t("application.meta_description")`.

R22: Each of the 4 public page views (`home`, `about`, `gallery`, `services`) sets, at the top of the template: `content_for :title, t("pages.<page>.meta_title")`, `content_for :meta_description, t("pages.<page>.meta_description")`, and `content_for :canonical_url, <page>_url` (e.g. `root_url`, `about_url`, `gallery_url`, `services_url`) — using the literal copy from the Interfaces table.

R23: The layout renders `<link rel="canonical" href="...">` using `content_for(:canonical_url)`, falling back to `request.base_url + request.path` if a page ever omits it (defensive; all 4 pages set it per R22, so this path should not trigger in practice).

R24: No page title or meta description mentions Idaho Falls, Boise, or Utah. Per the `areaServed` design (R30), those terms live in structured data and FAQ prose — not stacked into on-page titles/descriptions, which would read as the doorway-page pattern this spec explicitly rules out (Non-Goals).

R25: The `<title>`/description text is exactly the literal copy specified in the Interfaces table — not paraphrased or regenerated at implementation time.

### Part D — Structured Data: `LocalBusiness` / `MotorcycleRepair`

R26: The layout (`application.html.erb`) renders one `<script type="application/ld+json">` block, present on every public page (Home, About, Gallery, Services — wherever the layout renders), containing `json_escape(local_business_schema.to_json)`. The object carries `"@id" => "#{root_url}#business"` — a stable identifier so the four copies of the node are recognised by consumers as one entity described four times, rather than four separate businesses that happen to share a name and address. Without it the same shop is emitted at four URLs with nothing tying them together.

R27: `local_business_schema` uses `@type: "MotorcycleRepair"` (schema.org: `LocalBusiness > AutomotiveBusiness > MotorcycleRepair`) rather than generic `LocalBusiness`. *Implementation Decision:* this is a strict specialization — every property used here (`telephone`, `address`, `geo`, `areaServed`, `openingHoursSpecification`) is valid on both types, so falling back to plain `LocalBusiness` is a one-line change if `MotorcycleRepair` ever causes a rich-result validation issue. Chosen because it is the closest schema.org type to what this business actually is, and more specific typing is generally more useful to answer engines, not less.

R28: `local_business_schema`'s `telephone` and `address.streetAddress` reuse the **exact same resolved value** the About page itself renders — never a second, independently hardcoded copy. If Doug edits the phone number or address on the About page, the schema updates with it automatically. The record is resolved into a single local first:
```ruby
content = AboutPageContent.first
content = nil unless content&.published?
```
then `content&.shop_phone_number || t("pages.about.shop_phone_number")` and `content&.shop_address || t("pages.about.shop_address")`. **One `AboutPageContent.first` call, not two** — R26 renders this block from the layout on every public page, so a second call would put an extra query on every `/`, `/gallery` and `/services` request for a value already in hand.

R29: `address.addressLocality`, `address.addressRegion`, `address.postalCode`, and `address.addressCountry` are the fixed constants from Interfaces (`ADDRESS_LOCALITY`/`ADDRESS_REGION`/`POSTAL_CODE`/`ADDRESS_COUNTRY`) — not admin-editable, not parsed out of the free-text `shop_address` string (Non-Goals). `geo.latitude`/`geo.longitude` are the fixed `GEO_LATITUDE`/`GEO_LONGITUDE` constants.

R30: `local_business_schema`'s `areaServed` is the fixed `AREA_SERVED` array from Interfaces (Pocatello, Idaho Falls, Boise as `City`; Idaho, Utah as `State`) — not derived from any admin-editable field, since it is a standing claim about service reach the shop confirmed directly, not page content that changes.

R31: `local_business_schema`'s `image` is `image_url("gallery/m45a2849.jpg")` — the same photo already used as the Home hero background — and `url` is `root_url`. `name` is the `BUSINESS_NAME` constant.

R32: Every `<script type="application/ld+json">` block in this spec (`local_business_schema`, `faq_page_schema`) is embedded as `json_escape(hash.to_json)`, never a bare `.to_json` — `json_escape` (Rails' `ActionView::Helpers::JavaScriptHelper`) escapes `<`, `>`, and `&`, which a raw `.to_json` does not, preventing an admin-authored FAQ answer or address value containing `</script>` from breaking out of the script context.

### Part E — Sitemap and Robots

R33: `SitemapsController#show` renders `app/views/sitemaps/show.xml.builder` (`Content-Type: application/xml`), a `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">` containing one `<url><loc>` entry for `root_url`, `about_url`, and `gallery_url` unconditionally, plus `services_url` **only when** `SiteSetting.enabled?("services_page_published")` — the identical check `PagesController#services` and `shared/_nav.html.erb` already use. No `<lastmod>`, `<changefreq>`, or `<priority>` (Non-Goals).

R34: `RobotsController#show` renders `app/views/robots/show.text.erb` (`Content-Type: text/plain`). **In production** (`Rails.env.production?`): `Allow: /`, `Disallow: /admin`, and a `Sitemap:` line pointing at `sitemap_url`. **In every other environment** (staging included): `Disallow: /` — nothing is crawlable. *Implementation Decision:* staging is a real, publicly reachable host (`staging.syndicate-development.com`, per `config/deploy.staging.yml`) with no separate access control. Shipping a permissive `robots.txt` there risks a search engine indexing the staging site — duplicate content at best, a competing/stale result at worst. Gating on `Rails.env.production?` (already how this app distinguishes environments — `RAILS_ENV=staging` is set in `config/deploy.staging.yml`) is simple, environment-accurate, and needs no new configuration.

R35: `public/robots.txt` is **deleted** from the repo. Rails' static file middleware (`ActionDispatch::Static`) serves a matching file under `public/` before a request ever reaches the router, so leaving the stub in place would permanently shadow the new dynamic route regardless of what the route or controller does. The middleware is inserted when `config.public_file_server.enabled` is true, which is the framework default (`railties/lib/rails/application/configuration.rb`) and is not overridden anywhere in this app — each `config/environments/*.rb` sets only `config.public_file_server.headers`, which configures the middleware's cache-control header and neither enables nor disables it. So the shadowing applies in every environment, including production.

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

R44: Three PNG crops of the shop's lion logo replace the stock Rails icon set, all exported from the one square crop R45 defines:

| File | Size | Status |
|------|------|--------|
| `public/icon.png` | 512×512 | Replaces the stock 512×512 file, same dimensions |
| `public/icon-32.png` | 32×32 | New file |
| `public/apple-touch-icon.png` | 180×180 | New file |

`public/icon.svg` is deleted — no vector source exists for the lion mark, and scaling a raster crop up to fake one is out of scope.

`icon.png` **keeps its 512×512 dimensions**; it is not shrunk to 32×32. It is the only large icon the site has: the hi-DPI tab icon on a retina display comes from it, and it is the asset a web app manifest would point at — `application.html.erb` already carries a commented-out manifest link, so that is a live, one-uncomment-away consumer. Shrinking the large icon to produce the small one would throw both away to save 4 KB. The 32×32 is an additional file, not a replacement.

R45: **Source and crop, verified during spec authoring:** fetch `https://syndicate-development.com/moto.png` (822×540 PNG, transparent background — this is the pre-optimization original; `app/assets/images/syndicate-lion.png` in this repo is a post-optimization 177×150 crop, too small to re-crop cleanly for a 180×180 target).

**The fetched original is committed to this repository at `docs/assets/favicon/moto-original-822x540.png` as the first step of T7, before any crop is exported.** That URL is the live site this project replaces: at cutover it stops serving, and with it goes the only copy of the source these three icons are derived from — after which no one can re-crop, re-export at a new size, or verify what was cropped. Committing the 822×540 original makes R45 reproducible for as long as the repo exists. It goes under `docs/assets/` rather than `app/assets/` or `public/` deliberately: it is a build input, not a served asset, and neither Propshaft nor the static file server should be handing an 822×540 source image to visitors. **If the cutover lands before T7 does, fetch and commit this file immediately regardless of where T7 sits in the queue** — it is the one step in this spec that stops being possible with the passage of time.

Crop a 540×540 square anchored at the top-left corner (`x: 0, y: 0` to `x: 540, y: 540`), which keeps the full roaring head and most of the mane while dropping only the thin trailing mane wisp past `x: 540`. Verified during spec authoring (both the 540×540 crop, and that crop downscaled to 512×512, 180×180 and 32×32) to read clearly as a lion head at every target size. Suggested recipe, from the committed original:
```
sips -c 540 540 --cropOffset 0 0 docs/assets/favicon/moto-original-822x540.png --out lion-square.png
sips -z 512 512 lion-square.png --out public/icon.png
sips -z 180 180 lion-square.png --out public/apple-touch-icon.png
sips -z 32  32  lion-square.png --out public/icon-32.png
```
(or an equivalent image tool) — transparency preserved throughout. `lion-square.png` is an intermediate and is not committed; the committed original plus these four lines reproduce all three icons.

R46: `application.html.erb`'s favicon links become:
```html
<link rel="icon" href="/icon-32.png" type="image/png" sizes="32x32">
<link rel="icon" href="/icon.png" type="image/png" sizes="512x512">
<link rel="apple-touch-icon" href="/apple-touch-icon.png" sizes="180x180">
```
replacing the current 3-line stock-Rails block (`icon.png` without `sizes`, `icon.svg`, `apple-touch-icon` pointing at the same 512×512 stock file). Both `rel="icon"` entries are declared with explicit `sizes` so the browser picks the 32×32 for a standard tab and the 512×512 where it wants the detail; a single unsized link would leave that to chance.

R47: Only the public layout changes. The admin layout gets no favicon markup (Non-Goals).

### Part I — Contact Form Spam Protection

R48: `ContactsController` gains two declarative rate limits using Rails 8's built-in `rate_limit` — the same mechanism `Admin::SessionsController` already uses — declared **below** the two `before_action` guards, in this exact source order (R55 explains why the order is load-bearing):
```ruby
class ContactsController < ApplicationController
  before_action :reject_if_honeypot_filled, only: :create
  before_action :reject_if_submitted_too_quickly, only: :create

  rate_limit to: 5, within: 10.minutes, only: :create, name: "contact_per_ip",
    by: -> { request.remote_ip },
    with: -> { fake_success_response }

  rate_limit to: 3, within: 10.minutes, only: :create, name: "contact_per_email",
    by: -> { params[:email].to_s.strip.downcase },
    with: -> { fake_success_response },
    if: -> { params[:email].to_s.strip.present? }
```
*Rationale for the numbers:* three genuine submissions from the same claimed email within 10 minutes is already an edge case (a typo correction, an immediate follow-up); a fourth is far more likely automated. Five from one IP within 10 minutes covers a shared connection (e.g. a household) making more than one genuine enquiry while still bounding a flood. Both windows are short enough that a real visitor who gets throttled by mistake can simply try again shortly after — there is no account to lock out here, unlike login.

*The `if:` guard on the email-keyed limit is required, not decorative.* `params[:email].to_s.strip.downcase` collapses to `""` for every submission that omits or blanks the email field, which would put all blank-email submissions site-wide into a single shared bucket. Three of them in 10 minutes — from anyone, anywhere — would make the fourth genuine visitor who simply forgot to fill in their email receive a fake-success redirect instead of the honest `t("contact.errors.missing_required_fields")` alert, contradicting R55 and AC-54 (E32). Skipping the limit entirely for a blank email costs nothing: such a submission is rejected by the existing presence validation and sends no mail regardless, and it is still bounded by the per-IP limit. `rate_limit` forwards `**options` straight to the `before_action` it registers, so `if:` is the supported way to express this — a `by:` lambda returning `nil` would **not** work, because `rate_limiting` builds its cache key with `.compact`, which drops the nil and yields the same single shared bucket the guard exists to avoid.

R49: Unlike `Admin::SessionsController`'s rate limits — which deliberately tell a real, locked-out admin what happened (`t("admin.login.too_many_attempts")`) — the contact form's rate-limit rejection produces the **identical response a successful submission produces** (`fake_success_response`, R52). This is a deliberate divergence from the login precedent, not an inconsistency: the constraint here is that a blocked submission must not reveal why it was blocked, which login's UX goal (inform a real, inconvenienced admin) does not share. What is identical is the response *content* — status, redirect target, flash (AC-49). Response *timing* is not, and that gap is recorded as an accepted, time-boxed risk in E31 rather than left to be inferred from AC-49's "byte-for-byte" wording.

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

R53: A `before_action :reject_if_honeypot_filled, only: :create` — declared first in the class body, above both `rate_limit`s (R48, R55) — runs `fake_success_response` and returns (no email sent, no further processing) whenever `params[:website].present?`.

R54: A signed timing token is rendered as a hidden field in the same form:
```erb
<%= hidden_field_tag :rendered_at, contact_form_rendered_at_token %>
```
where `contact_form_rendered_at_token` (a new `ApplicationHelper` method) is `Rails.application.message_verifier(:contact_form).generate(Time.current.to_i)`. A `before_action :reject_if_submitted_too_quickly, only: :create` decodes it —
```ruby
rendered_at = Rails.application.message_verifier(:contact_form).verify(params[:rendered_at])
```
rescuing `ActiveSupport::MessageVerifier::InvalidSignature` (tampered or absent token) as a rejection — and calls `fake_success_response` (no email sent) unless `Time.current.to_i - rendered_at >= 2` (`ContactsController::MINIMUM_SECONDS_BEFORE_SUBMIT = 2`). No upper bound — a real visitor who leaves the page open a long time before submitting is not penalized, only a submission arriving implausibly fast is rejected. This `before_action` is declared second, immediately after R53's and still above both `rate_limit`s (R48, R55).

R55: Check order in `#create`'s `before_action` chain: honeypot (R53) → timing (R54) → the two `rate_limit`s (R48) → the existing name/email/message presence validation (unchanged). Only a submission that clears every spam-defense gate reaches the existing validation logic, whose behavior (alert flash on a genuinely missing required field, real send + notice flash on success) is **completely unchanged** by this spec — spam defenses and field validation produce visibly identical *rejection* responses only when spam is what's being rejected; a real visitor's own mistake still gets real, specific feedback.

**That order is produced by source order in the class body, and nothing else.** `rate_limit` is a thin wrapper that registers a `before_action` *at the point of declaration* (`ActionController::RateLimiting::ClassMethods#rate_limit`), so callbacks run in the order they are written. The two `before_action` declarations in R53–R54 must therefore appear **above** both `rate_limit` declarations in `ContactsController`'s class body, exactly as R48's snippet shows. Written the other way round, the rate limits run first and this rule is silently inverted — no error, no failing test unless one asserts the order, which AC-67/AT58 exist to do.

**What the order buys — rejected requests must not consume a rate-limit bucket.** `rate_limiting` calls `store.increment` on *every* request that reaches it, before it compares the count to the limit, so any request the filter runs at all spends a slot. Running the honeypot and timing guards first means a bot spraying rejected submissions never touches either bucket: a `redirect_to` inside a `before_action` halts the chain, so those requests stop before the limiter. This is the intended accounting, stated so it is not "fixed" later by moving the guards down: **honeypot- and timing-rejected requests do not consume the per-IP or per-email allowance.** Inverted, a bot could burn a shared household IP's 5-per-10-minutes — or a specific person's 3-per-10-minutes, by submitting their address with the honeypot filled — and lock out a real visitor who sends nothing wrong at all. The rate limits exist to bound traffic that has already got past the cheap guards; spending their allowance on traffic the cheap guards already caught converts a spam defense into a denial-of-service lever against real visitors.

R56: `deliver_now` is retained (Non-Goals) — the rate limits in R48 are this pass's mitigation for the synchronous-SMTP DoS exposure `deliver_now` carries, pending a queue supervisor running in every environment. It is also what makes a genuine success measurably slower than a rejection, the one respect in which fake success is not indistinguishable (E31); switching to `deliver_later` closes that as a side effect, so E31 is scoped to this deferral's lifetime rather than solved separately.

R57: `spec/requests/contacts_spec.rb` builds its shared parameters in a `let(:valid_params)` block today (`spec/requests/contacts_spec.rb:5`). `.claude/standards/practices/testing.md` § 3.4 prohibits `let`/`let!` outright, so that block is **removed, not extended**: replace it with an explicitly-called helper method defined in the spec file (e.g. `def valid_contact_params(overrides = {})`) and invoked in each example's own Arrange phase, per testing.md's rule that identical setup is extracted into a helper called explicitly rather than declared lazily. The helper returns the existing `name`/`email`/`subject`/`message` values, no `website` value, and a validly-signed `rendered_at` token generated for a timestamp several seconds in the past — deterministic, no sleep needed in a request spec that never renders the real page — so every existing scenario, success and missing-field failure alike, still clears the new gates and exercises the same behavior it did before. New scenarios are added (not substituted) for honeypot-filled, timing-too-fast, both rate limits, guard-ordering (AC-67), rejection logging (AC-68), and the blank-email skip (AC-69).

R58: `spec/system/contact_form_spec.rb`'s scenarios that submit the form advance the clock with `travel 5.seconds` between `visit about_path` and clicking submit — **not** `sleep`. *Implementation Decision:* the real page render already produces a genuine, validly-signed token; the only risk is a fast Capybara/Selenium run completing well under the 2-second floor, which would make an unmodified system spec flaky (sometimes above the threshold, sometimes not) rather than reliably passing. `travel` removes that flakiness deterministically and instantly: `ActiveSupport::Testing::TimeHelpers` is already included for every spec (`spec/rails_helper.rb:77`), and the token is both generated and verified inside the same Rails process the system spec drives, so the advanced clock applies to both halves of the check. `sleep` was considered and rejected — 4 affected scenarios × 2+ seconds is 8+ seconds of real wall-clock time added to a `system-test` job already running ~1m35s, paid on every CI run forever, to buy exactly what `travel` gives for free.

R61 *(added out of sequence — see Change Log)*: Every rejection path — R53's honeypot, R54's timing check, and each of R48's two rate limits — emits exactly one `Rails.logger.warn` line immediately before calling `fake_success_response`. Each line carries:

- a **reason token distinct from the other three** (`honeypot`, `timing`, `rate_limit`), so the four paths are told apart in a log stream, not merely counted;
- for a rate-limit rejection, the **`name:` of the limit that fired** (`contact_per_ip` or `contact_per_email`), since which bucket filled is the whole diagnostic value;
- `request.remote_ip`, which every Rails request line already carries anyway.

**No submitted field value appears in the line** — not the `message` body, not `name`, `email`, or `subject`. The log exists to make rejections *observable*, not to reconstruct the message: the request's own log entry already records filtered params, and copying visitor-supplied text into `warn` output would put arbitrary attacker-controlled content, and a real customer's enquiry, into logs that are neither access-controlled nor retention-bounded for that purpose.

*Why this is a rule and not an optional nicety:* every rejection path in this spec is silent to the visitor by design (R49, R52), so without this line a wrongly-rejected genuine enquiry is undiscoverable by anyone. Two such paths already exist on paper: an autofilled honeypot silently discards a real message (E19), and anyone can burn a specific person's 3-per-10-minutes email allowance by submitting that address three times, after which the real customer's message is dropped and they see a success screen (R48). E19's stated mitigation — "rename the field if observed in practice" — is not actionable at all unless "observed in practice" has a mechanism, and this is that mechanism. `warn` rather than `info` so the lines survive a production log level that filters `info`.

---

## Edge Cases

E1: Zero `Faq` rows exist. Home page renders with no FAQ section at all (R6) and no `FAQPage` script (R7) — not an empty heading, not an empty `mainEntity` array.

E2: A `Faq` create is submitted with a blank `answer`. Rejected (422), no row persists, no partial/blank FAQ is ever visible (R2, matches ADR-004's "never blank" guarantee via ordinary validation rather than a publish flag).

E3: `move_up` is called on the `Faq` already at the lowest position (no lower neighbour). No-op — matches `ServiceSection`'s identical existing behavior when no neighbour exists.

E4: An `Faq` question or answer contains characters that are special in JSON or HTML (`"`, `<`, `&`, an embedded `</script>`-like string). Both the visible `<details>` rendering (auto-escaped by ERB) and the `FAQPage` script (`json_escape`, R32) render it safely; neither breaks page structure.

E26 *(added out of sequence — see Change Log)*: `db/seeds.rb` runs a second time with no admin edits made in between. `Faq.count` is non-zero, so the guard (R60) skips entirely; still exactly 6 rows, no duplicates, the run does not raise.

E27 *(added out of sequence — see Change Log)*: `db/seeds.rb` runs once (creating the 6 rows), an admin then edits one row's `answer` via `PATCH /admin/faqs/:id`, and `db/seeds.rb` runs again. That row's `answer` still equals the admin's edited text, not the original seed text — the guard (R60) never touches an existing row's fields, so a reseed never reverts a deliberate edit. `Faq.count` is unchanged.

E28 *(added out of sequence — see Change Log)*: **The defect this correction fixes.** `db/seeds.rb` runs once (creating the 6 rows), an admin rewords one row's *question* — not its answer — via `PATCH /admin/faqs/:id` (e.g. "Can you tune my bike's ECU?" → "Do you do ECU tuning?"), and `db/seeds.rb` runs again. The guard (R60) sees `Faq.count` non-zero and does nothing: the reworded question is untouched, and — critically — no 7th row is created. `Faq.count` is still 6, not 7.

E29 *(added out of sequence — see Change Log)*: An admin deletes 3 of the 6 seeded `Faq` rows (`Faq.count` is now 3, not 0), then `db/seeds.rb` runs again. The guard (R60) sees `Faq.count` non-zero and does nothing — `Faq.count` is still 3 afterward; none of the 3 deleted rows are recreated. This is a deliberate behavior change from the mechanism R60 replaced, which used to silently restore exactly the deleted rows.

E30 *(added out of sequence — see Change Log)*: An admin deletes **all 6** seeded `Faq` rows (`Faq.count` is 0), then `db/seeds.rb` runs again. The guard (R60) sees `Faq.count.zero?` and recreates all 6 rows, verbatim, from Interfaces → FAQ Seed Content — indistinguishable from a fresh install that has never been seeded. Documented, accepted trade-off (R60), not a defect: recorded here so it is discovered by reading the spec, not by a confused deploy.

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

E19: A visitor's browser aggressively autofills every input on a page, including off-screen ones, filling the honeypot `website` field despite `autocomplete="off"`. Accepted, documented risk (R51) — a real submission would then be silently treated as spam (`fake_success_response`, no email sent, no error shown). Mitigation if this is observed in practice: rename the field, a one-line change; not solved preemptively without evidence it's needed. "Observed in practice" is only possible because of R61: the honeypot path logs a `warn` line with its own reason token, so a run of them against otherwise-plausible submissions is visible in the log rather than invisible to everyone including Doug.

E20: The honeypot is filled **and** the timing check would also have passed **and** the fields are all otherwise valid. Still rejected — honeypot alone is sufficient (R53 runs before, and independently of, R54).

E21: The `rendered_at` param is present but signed by a different `message_verifier` purpose, or is a plain unsigned integer a bot fabricated. `MessageVerifier#verify` raises `InvalidSignature` for both; both are treated as a rejection (R54), not a crash.

E22: A submission arrives with a validly-signed `rendered_at` exactly 2 seconds old (the floor). Per R54's `>=`, this is accepted — the boundary is inclusive.

E23: The per-IP rate limit (5/10 min) is exhausted by requests that vary the claimed `email` each time. Still throttled — the per-IP bucket does not depend on the email param at all (R48).

E24: The per-email rate limit (3/10 min) is exhausted by requests arriving from different IPs (e.g. a botnet, or `X-Forwarded-For` variation) but claiming the same `email`. Still throttled — the per-email bucket does not depend on IP (R48), which is precisely the bound `Admin::SessionsController`'s own comments describe as "the one that holds when remote_ip is worthless."

E25: A genuine visitor submits the form with a missing required field (blank `name`) after clearing all spam gates. Existing behavior is completely unchanged: redirect to `/about` with the existing alert flash, no email sent — this is not a spam rejection and must not be silently converted into a fake-success response (R55).

E31 *(added out of sequence — see Change Log)*: A bot measures **response latency** instead of response content. `deliver_now` is retained (R56), so a genuine success blocks on a live SMTP round trip to Resend — typically hundreds of milliseconds — while every rejection path returns immediately. The fake-success response is byte-for-byte identical in status, redirect target, and flash (R52, AC-49) and still distinguishable by a stopwatch. Accepted, documented risk, recorded rather than papered over: **no artificial latency is added to match a plausible send.** A matched delay is work whose only purpose is to be deleted later — it would slow every rejection on a 2-vCPU box holding a Puma thread for the duration, which is the same resource the rate limits in R48 exist to protect, and it would need removing the moment the underlying cause goes away. The channel closes on its own when `deliver_later` lands (Non-Goals deferral, R56): once the success path stops blocking on SMTP, every path returns at the same speed for the same reason, with no timing code to maintain. Until then the exposure is bounded — the honeypot and timing checks (R51, R54) cost a bot nothing to *detect* this way but nothing to *evade* either, and the rate limits bound how often it can measure. Precedent for reasoning about this channel at all: `app/controllers/admin/sessions_controller.rb` already documents that "neither the body nor the response time distinguishes a wrong password from an address with no account" — there, closing it was free; here it is not, so it is deferred rather than faked.

E32 *(added out of sequence — see Change Log)*: `params[:email]` is blank or absent. Without the `if:` guard, the per-email key `params[:email].to_s.strip.downcase` collapses to `""` and every blank-email submission site-wide shares one bucket, so the fourth genuine visitor in 10 minutes who simply forgot to fill in their email would get a fake-success redirect instead of the honest `t("contact.errors.missing_required_fields")` alert — the exact conversion R55 and AC-54 forbid. R48's `if: -> { params[:email].to_s.strip.present? }` skips the email-keyed limit entirely for such a submission. Nothing is lost by skipping it: the existing presence validation already rejects a blank email and sends no mail, and the per-IP limit still bounds the same traffic.

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

AC-61 *(added out of sequence — see Change Log)*: Given a clean database, when `db/seeds.rb` runs, then exactly 6 `Faq` rows exist at positions 0–5, in that order, with `question`/`answer` matching Interfaces → FAQ Seed Content verbatim.

AC-62 *(added out of sequence — see Change Log)*: Given `db/seeds.rb` has already run once with no admin edits since, when `db/seeds.rb` runs again, then `Faq.count` is still 6 and no duplicate rows exist.

AC-63 *(added out of sequence — see Change Log)*: Given `db/seeds.rb` has run once and an admin has since edited one seeded `Faq`'s `answer` via `PATCH /admin/faqs/:id`, when `db/seeds.rb` runs again, then that row's `answer` still equals the admin's edited text (not the original seed text) and `Faq.count` is still 6.

AC-64 *(added out of sequence — see Change Log; regression coverage for the defect corrected in R60)*: Given `db/seeds.rb` has run once and an admin has since edited one seeded `Faq`'s **`question`** (not its `answer`) via `PATCH /admin/faqs/:id`, when `db/seeds.rb` runs again, then that row's `question` still equals the admin's edited text, `Faq.count` is still 6 (not 7), and no row exists with the original, pre-edit question text.

AC-65 *(added out of sequence — see Change Log)*: Given `db/seeds.rb` has run once and an admin has since deleted 3 of the 6 seeded `Faq` rows, when `db/seeds.rb` runs again, then `Faq.count` is still 3 and none of the 3 deleted rows have been recreated.

AC-66 *(added out of sequence — see Change Log)*: Given `db/seeds.rb` has run once and an admin has since deleted all 6 seeded `Faq` rows (`Faq.count` is 0), when `db/seeds.rb` runs again, then all 6 rows from Interfaces → FAQ Seed Content are recreated verbatim, at positions 0–5.

### Business Hours

AC-15: `bin/rails db:migrate` creates `business_hours` with exactly the 14 nullable `time` columns plus timestamps.

AC-16: A `BusinessHours` with `monday_opens_at` set and `monday_closes_at` blank is invalid.

AC-17: A `BusinessHours` with `tuesday_closes_at` earlier than `tuesday_opens_at` is invalid.

AC-18: A `BusinessHours` with every column blank is valid.

AC-19: `db/seeds.rb` run on a clean database creates exactly one `BusinessHours` row with every column `nil`; run twice, `BusinessHours.count` is still 1.

AC-20: `PATCH /admin/business_hours` with valid hours for `friday` persists them and redirects with `flash[:notice]`.

AC-21: `PATCH /admin/business_hours` with an invalid day (E5-shaped) returns 422 and re-renders `:show` with the error.

AC-22: Given `BusinessHours` has every column blank, `GET /about`'s response body contains no hours list (no `t("pages.about.hours_heading")`, no day text).

AC-23: Given `BusinessHours` has `monday`/`wednesday`/`friday` set and the rest blank, `GET /about`'s hours list contains exactly those 3 days, in Monday–Sunday order, and no others. Each day label equals `t("pages.about.hours.day_#{day}")`; the response contains no string resolved from the `admin.business_hours.day_*` namespace and no hardcoded English day literal in `app/views/pages/about.html.erb`.

AC-24: Given the same `BusinessHours` state as AC-23, `GET /`'s (or wherever `local_business_schema` renders — every public page) `LocalBusiness` JSON-LD has an `openingHoursSpecification` array with exactly 3 entries matching those days' `opens`/`closes` in `HH:MM` format, and no `openingHoursSpecification` key at all when every day is blank (AC-25).

AC-25: Given `BusinessHours` has every column blank (or no row exists), the `LocalBusiness` JSON-LD object has no `openingHoursSpecification` key present at all — not an empty array.

### Titles, Meta Descriptions, Canonical

AC-26: `GET /` returns a `<title>` equal to `t("pages.home.meta_title")` and a `<meta name="description">` whose `content` equals `t("pages.home.meta_description")`.

AC-27: `GET /about`, `GET /gallery`, `GET /services` (when published) each return their own distinct `<title>`/description per the Interfaces table — no two pages share a title.

AC-28: Each of the 4 pages' response includes `<link rel="canonical" href="...">` equal to that page's own canonical URL (`root_url`, `about_url`, `gallery_url`, `services_url`).

AC-29: No page's `<title>` or meta description contains the strings "Idaho Falls", "Boise", or "Utah".

### Structured Data

AC-30: Every public page's response includes exactly one `<script type="application/ld+json">` block whose parsed content has `"@type": "MotorcycleRepair"`, and that object's `@id` equals `"#{root_url}#business"` — the same value on all four pages.

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

AC-46: The layout's favicon links are exactly the three in R46 — `rel="icon"` at `/icon-32.png` `sizes="32x32"`, `rel="icon"` at `/icon.png` `sizes="512x512"`, and `rel="apple-touch-icon"` at `/apple-touch-icon.png` `sizes="180x180"`; no `icon.svg` link is present.

AC-47: `public/icon.png` is a 512×512 PNG; `public/icon-32.png` is a 32×32 PNG; `public/apple-touch-icon.png` is a 180×180 PNG; `public/icon.svg` does not exist in the repository; and `docs/assets/favicon/moto-original-822x540.png` exists in the repository at 822×540 (R45's committed crop source).

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

AC-56: `spec/requests/contacts_spec.rb`'s existing scenarios (success, missing name, missing email, missing message, phone optional, phone passed through) all still pass after this spec's changes, each calling an explicitly-defined helper method in its own Arrange phase to build params with a honeypot-blank + past-threshold-timing default. The file declares no `let` or `let!` (testing.md § 3.4).

AC-57: `spec/system/contact_form_spec.rb`'s existing scenarios all still pass, each advancing the clock past the minimum-elapsed threshold with `travel` between visiting the page and submitting. The file contains no `sleep` call.

AC-67 *(added out of sequence — see Change Log)*: Honeypot- and timing-rejected requests do not consume a rate-limit bucket. Given a clean rate-limit cache, `POST /contact` sent 6 times from one IP with the honeypot filled (all other fields valid, token past threshold) returns the fake-success response 6 times and sends zero emails; a 7th request from the same IP with the honeypot empty and everything else valid then sends exactly one email — the per-IP allowance of 5 was never touched. Asserted behaviourally rather than by reading source, so it fails if the `before_action` and `rate_limit` declarations are ever reordered in the class body.

AC-68 *(added out of sequence — see Change Log)*: Each of the four rejection paths (honeypot, timing, per-IP limit, per-email limit) writes exactly one `Rails.logger` line at `warn` level. Each line's reason token is distinct from the other three; a rate-limit rejection's line also names the limit that fired (`contact_per_ip` or `contact_per_email`). No line contains any part of the submitted `message`, `name`, `email`, or `subject`.

AC-69 *(added out of sequence — see Change Log)*: `POST /contact` with `email` blank, repeated 4 times within 10 minutes from one IP (honeypot empty, valid past-threshold token, `name` and `message` present), produces the existing `t("contact.errors.missing_required_fields")` alert on **all four**, never the success notice, and sends zero emails — the per-email limit is skipped for a blank email, so blank-email submissions never share one site-wide bucket.

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

AT52 *(added out of sequence — see Change Log)*
Given a clean database
When `db/seeds.rb` runs
Then exactly 6 `Faq` rows exist at positions 0–5, in that order, with `question`/`answer` matching Interfaces → FAQ Seed Content verbatim
Covers: R59, AC-61

AT53 *(added out of sequence — see Change Log)*
Given `db/seeds.rb` has already run once
When `db/seeds.rb` runs again with no admin edits in between
Then `Faq.count` is still 6 and no duplicate rows exist for any of the 6 questions
Covers: R60, AC-62, E26

AT54 *(added out of sequence — see Change Log)*
Given `db/seeds.rb` has run once and an admin has since edited one seeded `Faq`'s `answer`
When `db/seeds.rb` runs again
Then that row's `answer` still equals the admin's edited text, not the original seed text, and `Faq.count` is still 6
Covers: R60, AC-63, E27

AT55 *(added out of sequence — see Change Log; regression test for the defect corrected in R60)*
Given `db/seeds.rb` has run once and an admin has since edited one seeded `Faq`'s `question` (e.g. "Can you tune my bike's ECU?" reworded to "Do you do ECU tuning?")
When `db/seeds.rb` runs again
Then that row's `question` still equals the admin's edited text, `Faq.count` is still 6, and no row exists whose `question` equals the original, pre-edit text
Covers: R60, AC-64, E28

AT56 *(added out of sequence — see Change Log)*
Given `db/seeds.rb` has run once and an admin has since deleted 3 of the 6 seeded `Faq` rows
When `db/seeds.rb` runs again
Then `Faq.count` is still 3 and none of the 3 deleted rows have been recreated
Covers: R60, AC-65, E29

AT57 *(added out of sequence — see Change Log)*
Given `db/seeds.rb` has run once and an admin has since deleted all 6 seeded `Faq` rows
When `db/seeds.rb` runs again
Then all 6 rows from Interfaces → FAQ Seed Content are recreated verbatim at positions 0–5
Covers: R60, AC-66, E30

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
Then the hours list contains exactly those 3 days in Monday–Sunday order and no others, each label equal to `t("pages.about.hours.day_#{day}")` with no `admin.business_hours.day_*` value and no hardcoded English day literal in the view; when every column is blank, no hours list renders at all
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
Then it is present exactly once, its `@id` equals `"#{root_url}#business"` on every public page, and `telephone`/`address.streetAddress` equal the same resolved values the About page renders, under both published and unpublished `AboutPageContent` states
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
Given `public/icon.png`, `public/icon-32.png`, `public/apple-touch-icon.png`, and `docs/assets/favicon/moto-original-822x540.png`
When inspected
Then they are 512×512, 32×32, 180×180, and 822×540 PNGs respectively — the crop source is committed alongside the icons it produced
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

AT58 *(added out of sequence — see Change Log)*
Given a clean rate-limit cache
When `POST /contact` is sent 6 times from one IP with the honeypot `website` field filled (all other fields valid, token past threshold), then a 7th time from the same IP with the honeypot empty and everything else valid
Then all 6 honeypot submissions return the fake-success response and send zero emails, and the 7th sends exactly one email — the honeypot guard halted every rejected request before the per-IP limiter could increment its bucket, so the allowance of 5 was never spent
Covers: R48, R53, R55, AC-67

AT59 *(added out of sequence — see Change Log)*
Given a clean rate-limit cache and a captured `Rails.logger`
When `POST /contact` is rejected once by each of the four paths in turn (honeypot filled; token signed under 2 seconds ago; per-IP limit exceeded; per-email limit exceeded)
Then each rejection writes exactly one `warn` line, the four reason tokens are distinct from one another, the two rate-limit lines name `contact_per_ip` and `contact_per_email` respectively, and no line contains any part of the submitted `message`, `name`, `email`, or `subject`
Covers: R61, AC-68

AT60 *(added out of sequence — see Change Log)*
Given a clean rate-limit cache
When `POST /contact` is sent 4 times within 10 minutes from one IP with `email` blank, honeypot empty, a valid past-threshold token, and `name`/`message` present
Then all 4 responses carry the existing missing-required-fields alert rather than the success notice, and zero emails are sent — the per-email limit was skipped for the blank email, so no shared `""` bucket ever filled
Covers: R48, R55, AC-69, E32

AT45
Given the shipped honeypot markup
When inspected
Then the wrapper carries `aria-hidden="true"`, the input carries `tabindex="-1"` and `autocomplete="off"`, and neither relies on `display:none`/`visibility:hidden`
Covers: R51, AC-55

AT46
Given `spec/requests/contacts_spec.rb` as modified by this spec — the `let(:valid_params)` block replaced by an explicitly-called helper method
When the full existing scenario list (success, missing name/email/message, phone optional, phone passed through) is run, and the file is inspected for `let`/`let!`
Then every scenario still passes and the file declares no `let` or `let!`
Covers: R57, AC-56

AT47
Given `spec/system/contact_form_spec.rb` as modified by this spec
When the full existing scenario list is run, and the file is inspected for `sleep`
Then every scenario still passes with the clock advanced by `travel` before each submission, and the file contains no `sleep` call
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
| 2026-08-04, corrected (see Change Log) | The FAQ seed is a **table-empty guard** (`Faq.count.zero?`) (R60), not a per-row lookup | A per-row `find_or_create_by!(question:)` design was specified first and found defective on review: it matched on `question`, but `question` is admin-editable (R2, the edit form exposes it), so rewording a question — ordinary use, not an edge case — made a reseed create a 7th, duplicate row instead of recognizing the edited one. A table-empty guard closes the whole class of problem (question edits, answer edits, reordering, partial deletion) rather than patching the one instance found, because it inspects nothing about individual rows. Accepted, documented trade-off: deleting *every* `Faq` row makes a reseed indistinguishable from a fresh install, so it restores all 6 (E30) — worse than doing nothing, better than the prior mechanism's partial resurrection of exactly the rows an admin had deliberately deleted (E29). |
| 2026-08-04 | `BusinessHours` uses blank-columns-as-signal instead of a `published` flag | The brief's own requirement — "omit `openingHours` entirely while blank" — is already exactly what per-day column presence gives for free. A separate flag would let hours be "published" while still blank, an extra state with no useful meaning. |
| 2026-08-04 | FAQ and Business Hours are dashboard-only links, not persistent-nav items | SPEC-009 already declined a 6th persistent nav item for mobile-width reasons and established the precedent (`Users`, `Account`) of dashboard-only entry points for secondary admin surfaces. Two new resources following the same precedent is more consistent than reopening that constraint. |
| 2026-08-04 | `LocalBusiness` schema uses `@type: "MotorcycleRepair"` | Schema.org's closest valid subtype for this business (`LocalBusiness > AutomotiveBusiness > MotorcycleRepair`), verified against schema.org's own type hierarchy during spec authoring. Every property used remains valid on plain `LocalBusiness` too, so this is reversible in one line if it ever proves to hurt rich-result eligibility. |
| 2026-08-04 | Address locality/region/postal/country are fixed constants, not admin-editable fields | Splitting the existing free-text `shop_address` into structured components is meaningful new admin surface (migration, form fields, i18n, tests) not requested in scope, and the sub-components in question (city/state/zip) do not change independent of a physical relocation — a genuinely rare event that would warrant a code change regardless. `streetAddress` itself still reuses the live, editable value to avoid a drifting duplicate. |
| 2026-08-04 | Geo coordinates sourced by resolving the About page's own existing Google Maps short link | Produces the exact coordinates the shop's own current site already asserts for its location, rather than an estimated/looked-up value — verified during spec authoring by following the redirect. |
| 2026-08-04 | FAQ section placed on the Home page, not a new `/faq` route or the gated `/services` page | Home always renders (no publish gate), gets the most traffic, and needs no new route, nav entry, or system-spec surface. Placing it on `/services` would risk the FAQ — the AEO lever the user called the most important piece of this spec — being invisible whenever Services is unpublished, which defeats the point. |
| 2026-08-04 | `robots.txt` is environment-aware (`Rails.env.production?`), not a static file | Staging is a real, publicly reachable host with no access control of its own. A permissive static `robots.txt` shipped there risks a search engine indexing pre-release content. |
| 2026-08-04 | Contact form: fake-success response for every spam-defense rejection, but unchanged behavior for genuine field-validation errors | The user's constraint is specifically "a blocked submission must not tell the bot why" — that applies to the three anti-spam layers, not to the pre-existing UX for a real visitor's own mistake, which continues to deserve honest, specific feedback. |
| 2026-08-04 | Contact form: `deliver_now` retained, rate limiting is the interim DoS mitigation | Matches the user's explicit deferral of `deliver_later` until Solid Queue runs in every environment (today: production only). Recorded so the deferred work is picked up once staging also runs a queue supervisor. |
| 2026-08-04 | Contact form timing threshold set at 2 seconds, with the system spec advancing the clock via `travel` rather than lowering the threshold or sleeping | A threshold low enough to never risk system-spec flakiness on a fast CI runner would also be too low to filter an instant scripted POST. `travel` removes the tension entirely rather than trading it for a weaker check — and, unlike the `sleep` first specified, costs no wall-clock time on a `system-test` job already running ~1m35s. The token is generated and verified in the same process the system spec drives, so the advanced clock covers both halves. |
| 2026-08-04, added on review | The honeypot and timing `before_action`s are declared **above** the two `rate_limit`s, and rejected requests therefore consume no rate-limit allowance | `rate_limit` registers its `before_action` at the point of declaration, so callback order is source order, and `rate_limiting` increments the bucket for every request that reaches it — before comparing the count to the limit. Declaring the limits first would let a bot spraying honeypot-filled submissions exhaust a shared household IP's allowance, or a named person's email allowance, and lock out a visitor who did nothing wrong. Stated as a rule (R55) and asserted behaviourally (AC-67/AT58) so the ordering cannot be silently inverted by a later tidy-up. |
| 2026-08-04, added on review | The fake-success response's timing side channel is accepted and time-boxed, not padded with artificial latency | `deliver_now` makes a genuine success measurably slower than any rejection (E31). Matching the delay would mean holding a Puma thread on a 2-vCPU box for no reason other than to look busy — spending the resource the rate limits exist to protect — and it is code whose only future is deletion, since `deliver_later` (already a recorded deferral, R56) closes the gap for free. Recorded as an accepted risk with a named exit condition rather than solved with work that has to be removed. |

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
| T1 | `Faq` model + migration + validations (R1–R3); `Admin::FaqsController` (index/new/create/edit/update/destroy/move_up/move_down, R4); admin views mirroring `services_pages` stacked-card pattern (R5, R11); dashboard links (R9); i18n keys (R10); `db/seeds.rb` creates the 6 literal `Faq` rows verbatim, guarded by `Faq.count.zero?` (R59–R60). | AC-1–AC-7, AC-12–AC-14, AC-61–AC-66 | 8 |
| T2 | `BusinessHours` model + migration + validations (R12–R14); `db/seeds.rb` blank-seed (R15); `Admin::BusinessHoursController` show/update (R18, R20); admin form; i18n keys. | AC-15–AC-21, AC-58 | 3 |
| T3 | Home page: `@faqs` assignment, FAQ `<details>` section + `FAQPage` JSON-LD (R6–R8); About page: visible hours list using the public `pages.about.hours.day_*` keys (R19). **`app/views/pages/home.html.erb` currently carries spec-duplicating comments (`<%# R4: md:whitespace-nowrap forces single line at md+ breakpoint %>` and similar) of the kind CLAUDE.md § Comments and `.claude/standards/practices/coding-style.md` § 2.4 prohibit. Do not extend that pattern with new `R#`-referencing comments, and delete the ones in the blocks this task touches.** | AC-8–AC-11, AC-22, AC-23 | 3 |
| T4 | `structured_data_helper.rb`: `local_business_schema` + `BusinessHours#opening_hours_specification` (R16, R17, R26–R32); wire into layout `<head>`; fixed constants module. | AC-24, AC-25, AC-30–AC-34 | 5 |
| T5 | Per-page title/description/canonical infrastructure (`content_for`, layout changes, R21–R25) across all 4 public views; new i18n copy. | AC-26–AC-29 | 2 |
| T6 | Sitemap (`SitemapsController`, `.xml.builder`, R33) + Robots (`RobotsController`, `.text.erb`, environment-aware, R34–R35, R37–R38); delete `public/robots.txt`; admin `noindex` meta (R36). | AC-35–AC-41 | 3 |
| T7 | Open Graph / Twitter tags (R39–R40); footer (R41–R43); favicon fetch/crop/export + layout links (R44–R47, admin layout untouched). | AC-42–AC-47, AC-59, AC-60 | 3 |
| T8 | Contact form: honeypot field + rejection (R51, R53); signed timing token + rejection (R54); two `rate_limit` declarations including the blank-email `if:` guard (R48–R50); `fake_success_response` (R52); check ordering — guards declared above the limits (R55); rejection logging (R61); `deliver_now` retained note (R56). | AC-48–AC-55, AC-67–AC-69 | 5 |
| T9 | Update `spec/requests/contacts_spec.rb` (`valid_params` default token, new spam-rejection scenarios, R57) and `spec/system/contact_form_spec.rb` (pre-submit wait, R58); full model/request/system test coverage for T1–T7 (FAQ, BusinessHours, schema, sitemap/robots, OG, footer, favicon, mobile-first 375px checks). | AC-56, AC-57 (+ regression coverage for all above) | 5 |

Total estimated points: 37. Points are Fibonacci-only per `.claude/standards/version-control-standards.md` § Task Sizing → Allowed Values (1, 2, 3, 5, 8, 13); T1 sits at 8, the next legal value above 5, not at the 6 an earlier revision used. Four tasks sit at or above the 5-point split-review guardrail (T1, T4, T8, T9); each was reviewed and kept as a single task rather than split:
- **T1 (8)** — 8 points requires an explicitly documented rationale to remain unsplit, and this is it. The task is one model with its CRUD surface plus the seed that fills it; the seed addition (R59–R60) is a small, mechanical literal-array-plus-loop attached to the model it seeds. Splitting the seed out would review six literal strings in isolation from the model and validation code that give them meaning — less useful, not more — and splitting the CRUD from the model would leave a table nothing can write to. The risk the 8 acknowledges is breadth (migration, controller, 8 routes, views, i18n, seed), not a hard problem; it is accepted here rather than pretended away with a smaller number.
- **T4 (5)** — no natural mid-point split; the helper's two methods (`local_business_schema`, `opening_hours_specification`) are consumed by the same single layout change in the same PR.
- **T8 (5)** — its five sub-mechanisms (honeypot, timing, two rate limits, shared fake-success response) are small individually but must land together for the check ordering (R55) to be testable at all; a partial landing would leave the contact form's spam defenses incomplete mid-review.
- **T9 (5)** — pure test coverage for T1–T8's combined surface; splitting it would mean either duplicating setup across multiple test-only PRs or reviewing tests without the code they exercise having fully landed.

---

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-08-04 | Initial draft | All | Translates the user's SEO/AEO scope decisions (FAQ, per-page metadata, structured data, sitemap/robots, OG tags, footer, favicon, blank-seeded opening hours) plus mid-authoring additions — expanded `areaServed` geo terms (Idaho Falls, Boise, Idaho, Utah, confirmed genuine per the user's "customers travel because he's one of the best in the region"), the explicit exclusion of any shipping/mail-in claim, and contact form spam protection (honeypot, timing check, rate limiting) — into one implementation-ready spec, per explicit instruction to favor a single one-pass document over an exhaustive multi-spec decomposition. |
| 2026-08-04 | FAQ seed item 1 corrected: removed a misplaced "dyno-verified" that had welded two separate Services-page bullets together, leaving it modifying a clause neither bullet actually makes | Interfaces → FAQ Seed Content (position 0) | User review of the seeded copy. Straight text deletion, no other wording change; items 2 and 3's own "dyno-verified" (engine/ECU work) were already correct and untouched. |
| 2026-08-04 | FAQ seed content promoted from an informal Open Questions note to normative content: moved into Interfaces → FAQ Seed Content (single authoritative copy), with a new rule pinning it verbatim (R59) and an (initial, since corrected below) idempotent seed mechanism (R60). Added E26–E27, AC-61–AC-63, AT52–AT54 (added out of sequence, physically positioned near the other Part A / FAQ items) | R59, R60; E26, E27; AC-61–AC-63; AT52–AT54; T1 (bumped 5→6 points) | User review flagged that nothing in the spec previously stopped an implementer from paraphrasing or regenerating the seed copy — the six answers lived only in an Open Questions aside, unreferenced by any R#/AC#, which is exactly the section a developer reads as unresolved. |
| 2026-08-04 | **Corrected R60's mechanism.** The initial design keyed the seed's `find_or_create_by!` lookup on `question` text. Review caught that `question` is admin-editable (R2) — rewording a question through `PATCH /admin/faqs/:id` is ordinary use, not an edge case — and a reworded question no longer matches its original seed row, so a reseed created a duplicate 7th row rather than recognizing the edited one. Replaced with a table-empty guard (`Faq.count.zero?`): the seed runs only against a genuinely empty table and does nothing otherwise, regardless of which fields an admin has changed. This also removes a defect the old mechanism had but nobody had flagged yet: it silently resurrected any individually-deleted seeded row, so deleting 3 of 6 and reseeding used to bring exactly those 3 back. The new mechanism trades that for a different, honestly-documented consequence: deleting *all 6* is indistinguishable from a fresh install, so a reseed after that restores all 6 (E30) — accepted as strictly better than the defect it replaces. | R60 rewritten; E27 narrowed to the answer-edit case it still covers; added E28 (question-edit — the motivating defect), E29 (partial deletion, no resurrection), E30 (full deletion, honest resurrection); added AC-64–AC-66, AT55–AT57; updated the seed-mechanism Implementation Decisions row; T1's AC range extended to AC-66 | User review of R60 during a second pass, before implementation — the exact scenario described (Doug reworders "Can you tune my bike's ECU?") is realistic first-week admin behavior for an editable FAQ, not a contrived edge case. |
| 2026-08-04 | **Softened FAQ seed item 6 (position 5).** Replaced the answer's claim about where customers currently travel from — "riders travel from across Idaho and northern Utah … including from Idaho Falls, Boise, and the Salt Lake area" — with what the shop takes on: "we take suspension, engine, and ECU work from riders across southeast Idaho and the surrounding region, not just Pocatello." Regional geography, the service list, and the call-ahead CTA are unchanged. The question text is unchanged. | Interfaces → FAQ Seed Content (position 5); Open Questions note narrowed | The Salt Lake claim was inferred during spec authoring, not confirmed. R59 pins this text verbatim and `faq_page_schema` (R7, R8) feeds it into `FAQPage` structured data, so an unverified factual claim about existing customers would have become a machine-readable assertion an answer engine may surface as a rich result. Reframing it from *what customers do* to *what the shop takes on* keeps the local-SEO value and makes the claim true by construction. No rule, AC, AT, or edge case changes — R59 still pins the table, AC-61 still matches against it, AT52 still compares to the same source of truth. |
| 2026-08-04 | **Review response (PR #58).** Two gaps where the spec asked for behavior the implementer could not produce from what it gave them: (1) the public hours list had no day-name strings — the only 7 day labels defined were `admin.business_hours.day_*`, so R19/AC-23 could only be satisfied by hardcoding English into a public view or rendering an `admin.*` key from one; added 7 public `pages.about.hours.day_*` keys and made R19 name them. (2) R55's mandated check order was unachievable from R48's own snippet: `rate_limit` registers its `before_action` at the point of declaration, so the layout shown put the limits first, inverting the rule — R48 now shows the guards above the limits, R55 states that source order is the mechanism and that honeypot/timing rejections must not consume a bucket, and AC-67/AT58 assert it behaviourally. Also: the per-email limit now skips a blank email (E32, AC-69/AT60) instead of putting every blank-email submission site-wide into one `""` bucket; every rejection path logs a distinguishable `warn` line (R61, AC-68/AT59), which is what makes E19's "rename the field if observed in practice" actionable; the fake-success timing side channel is recorded as an accepted, time-boxed risk (E31) rather than padded with artificial latency; R15 now persists (`first_or_create!`, or `first_or_initialize` + `save!`) instead of specifying `first_or_initialize` alone, which creates nothing; R44/R46/AC-46/AC-47 keep `icon.png` at 512×512 and add the 32×32 as `icon-32.png` rather than shrinking the only large icon; R45 commits the 822×540 crop source to `docs/assets/favicon/` before the live source disappears at cutover; R57 replaces the prohibited `let(:valid_params)` with an explicitly-called helper (testing.md § 3.4); R58 uses `travel 5.seconds` instead of `sleep`; R35's rationale corrected (`config.public_file_server.enabled` enables `ActionDispatch::Static`, not `.headers`); R28 resolves `AboutPageContent.first` into one local instead of calling it twice on every public page; R26 adds `"@id" => "#{root_url}#business"`; T1 corrected 6 → 8 (Fibonacci-only per version-control-standards, total 35 → 37); T3 carries a note not to extend `home.html.erb`'s spec-duplicating comments. | R15, R19, R26, R28, R35, R44–R46, R48, R49, R53–R58; added R61; added E31, E32; added AC-67–AC-69; added AT58–AT60; amended AC-23, AC-30, AC-46, AC-47, AC-56, AC-57; amended AT20, AT25, AT37, AT46, AT47; Interfaces → Required i18n Keys; T1, T3, T8; Implementation Decisions | Code review on PR #58 (CHANGES REQUIRED, 2 critical + 8 major + 6 minor). Fixed here rather than at implementation time because this spec merges before implementation begins, and R25/R59 pin its literal copy as normative — a defect in the document becomes a defect in the code that follows it. |

---

## Open Questions

None blocking implementation. Two items were explicitly resolved with the user during spec authoring rather than left open:

1. **Whether the shop takes customers who travel from outside Pocatello** — confirmed yes; reflected in `areaServed` (R30) and FAQ item 6 (Interfaces → FAQ Seed Content).
2. **Whether the shop ships parts / offers remote service** — confirmed no; explicitly excluded (Non-Goals), with a note against re-adding it by assumption later.

**FAQ seed content lives in Interfaces → FAQ Seed Content** (normative, required verbatim by R59) — not reproduced here, so there is exactly one copy of that text in this document.

One item is worth flagging for Doug specifically, not the developer: the FAQ is seeded with real, considered answers (not placeholders) so the admin never sees blank content, but seed content is still a starting draft in Doug's own voice, editable from the moment this ships. He should read all 6 before this reaches production. If any answer needs correcting, the FAQ is already admin-editable, and R60 guarantees an edit like that survives a reseed.
