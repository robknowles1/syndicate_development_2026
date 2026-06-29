# Spec: Services Page

**ID:** SPEC-002
**Status:** on-hold
**Priority:** medium
**Created:** 2026-03-18
**Author:** pm-agent
**Note:** Blocked pending a backend/auth layer. The services page will be driven by user-managed content (show/hide toggle, editable service items) rather than static copy. Revisit after the admin auth spec is complete.

---

## Summary

This spec covers the Services page (`/services`) for the Syndicate Development marketing site. It was deferred from SPEC-001 (Frontend Rebuild) to keep that spec focused. The Services page displays three service category sections — Precision Engines, Custom Suspension Setup, and ECU Tuning — each with a heading, a bulleted list of specific services offered, and at least one image drawn from the existing local asset library. All content is static in the view; no dynamic data layer is required. This spec also wires up the nav link for Services, which currently renders in the nav partial but has no route, causing a 404.

---

## User Stories

- As a potential customer, I want to see a dedicated Services page listing what Syndicate Development offers, so that I can quickly understand whether Doug can do the work I need.
- As a site visitor, I want each service category to have a clear heading and a bulleted list of specific services, so that I do not have to read paragraphs to find out if a service is offered.
- As a site visitor browsing on mobile, I want the Services page to be fully readable without horizontal scrolling, so that I can review services on my phone.
- As a site visitor on any page, I want the Services nav link to be active (highlighted in red) when I am on the Services page, so that I always know where I am in the site.

---

## Acceptance Criteria

1. Given a `GET /services` request, when the server processes it, then the response status is HTTP 200 and the `PagesController#services` action renders `app/views/pages/services.html.erb`.

2. Given the Services page at `/services`, when it is rendered, then it contains a page-level heading that reads "OUR SERVICES" (via `t("pages.services.heading")`), styled with the dark heading color (`#242121`), uppercase, and the same font-weight and tracking conventions used on the About page (`text-3xl md:text-4xl font-black uppercase tracking-wide`).

3. Given the Services page, when it is rendered, then it contains a section for **Precision Engines** with:
   - A section heading reading "PRECISION ENGINES" (via `t("pages.services.engines.heading")`), styled with the red accent color (`#db0505`).
   - A bulleted list containing exactly these items (each via its own `t()` key under `pages.services.engines.items`):
     - "Full engine builds and rebuilds"
     - "Top-end and bottom-end service"
     - "Porting and head work"
     - "Valve train service and upgrades"
     - "Engine blueprinting and balancing"
   - At least one image rendered with `image_tag` using a local asset from `app/assets/images/gallery/`. The recommended image is `gallery/m45a2803.jpg`. The alt text must come from `t("pages.services.engines.image_alt")`.

4. Given the Services page, when it is rendered, then it contains a section for **Custom Suspension Setup** with:
   - A section heading reading "CUSTOM SUSPENSION SETUP" (via `t("pages.services.suspension.heading")`), styled with the red accent color (`#db0505`).
   - A bulleted list containing exactly these items (each via its own `t()` key under `pages.services.suspension.items`):
     - "Revalving and re-springing for rider weight and style"
     - "Fork and shock servicing"
     - "Linkage and bearing service"
     - "Track-day and race setup"
     - "Dyno-verified suspension tuning"
   - At least one image rendered with `image_tag` using a local asset from `app/assets/images/gallery/`. The recommended image is `gallery/m45a2832.jpg`. The alt text must come from `t("pages.services.suspension.image_alt")`.

5. Given the Services page, when it is rendered, then it contains a section for **ECU Tuning** with:
   - A section heading reading "ECU TUNING" (via `t("pages.services.ecu.heading")`), styled with the red accent color (`#db0505`).
   - A bulleted list containing exactly these items (each via its own `t()` key under `pages.services.ecu.items`):
     - "Fuel injection mapping and fuel curve optimization"
     - "Ignition timing adjustment"
     - "Launch control and traction control configuration"
     - "Dyno-tuned power delivery"
     - "Custom maps for aftermarket exhausts and air kits"
   - At least one image rendered with `image_tag` using a local asset from `app/assets/images/gallery/`. The recommended image is `gallery/m45a2996.jpg`. The alt text must come from `t("pages.services.ecu.image_alt")`.

6. Given the Services page, when it is rendered at a desktop viewport (≥768px), then each service section lays out in a two-column grid: image on one side, heading and bullet list on the other. Alternate sections should flip the image/text order (image-left for Engines, image-right for Suspension, image-left for ECU) to create visual rhythm. This is achieved with Tailwind classes (`md:grid-cols-2` with `md:order-*` utilities). On mobile (< 768px), each section stacks vertically (image on top, text below) with no horizontal scrolling.

7. Given the Services page, when the nav is rendered, then the "Services" link in both the desktop nav and the mobile dropdown is highlighted in red (`text-red-600`) to indicate it is the active page. The active state is applied by comparing `current_page?(services_path)` in the nav partial and conditionally applying `text-red-600` versus the default `hover:text-red-600` class. All other nav links remain white with the standard hover behavior.

8. Given any viewport, when the Services page is rendered, then there are no hardcoded user-facing strings in the view — every visible text string is rendered via `t()` calling a key in `config/locales/en.yml` under the `pages.services` namespace.

9. Given a `GET /services` request in the RSpec request suite, when the suite runs, then the test passes with HTTP 200 and the response body includes the text "PRECISION ENGINES", "CUSTOM SUSPENSION SETUP", and "ECU TUNING".

10. Given a Capybara system spec visiting `/services`, when the page loads, then the page contains the text "OUR SERVICES", and all three section headings are present on the page.

---

## Technical Scope

### Models / Database

No new models or migrations required. All content is static in the view and locale file.

### API / Logic

**Route** — add to `config/routes.rb`:
```
get "/services", to: "pages#services"
```
The named route helper will be `services_path`.

**Controller** — add a `services` action to `PagesController`:
```ruby
def services
end
```
No instance variables needed; all content is static in the view.

### Views / UI

**`app/views/pages/services.html.erb`** (new file)

Overall page structure:
- A top hero banner: a full-width, fixed-height (`h-64 md:h-80`) section with a background image (`gallery/m45a2849.jpg`, already used on the home page hero), using `bg-cover bg-center`. Overlay the page title "OUR SERVICES" (`t("pages.services.heading")`) in white, bottom-left aligned, styled `text-4xl md:text-6xl font-black uppercase tracking-widest`.
- A content wrapper: `<div class="py-16 px-6 max-w-5xl mx-auto space-y-20">` containing three service sections.

Each service section follows this structure (use a shared pattern across all three):
```erb
<section class="grid md:grid-cols-2 gap-8 items-center">
  <%# Image column — use md:order-first / md:order-last to alternate %>
  <div class="[order classes]">
    <%= image_tag "[asset path]", alt: t("[alt key]"), class: "w-full h-64 md:h-80 object-cover" %>
  </div>
  <%# Text column %>
  <div>
    <h2 class="text-2xl md:text-3xl font-black uppercase tracking-wide mb-4" style="color: #db0505;">
      <%= t("[heading key]") %>
    </h2>
    <ul class="list-disc list-inside space-y-2 text-gray-700 text-base md:text-lg">
      <li><%= t("[item key]") %></li>
      ...
    </ul>
  </div>
</section>
```

Column order:
- Precision Engines: image is `md:order-first` (image left, text right on desktop).
- Custom Suspension Setup: image is `md:order-last` (text left, image right on desktop).
- ECU Tuning: image is `md:order-first` (image left, text right on desktop).

The page uses `mt-[70px]` or `pt-[70px]` on the outermost element to clear the fixed 70px nav bar (same pattern as `about.html.erb` which uses `mt-[70px]` on the slideshow section). Apply `mt-[70px]` to the hero banner section so it is not obscured.

**`app/views/shared/_nav.html.erb`** (modify existing)

The nav currently links to Home, About, and Gallery. Add the Services link in both the desktop nav and the mobile dropdown:

Desktop nav block (`hidden md:flex items-center space-x-6`): add the Services link between Home and About:
```erb
<%= link_to t("nav.services"), services_path,
      class: current_page?(services_path) ? "text-red-600 font-bold tracking-wide" : "text-white font-bold tracking-wide hover:text-red-600 transition-colors" %>
```
Apply the same active-state pattern to the existing Home, About, and Gallery links as well (this is a minor extension — see Open Questions item 1 if it should be a separate spec).

Mobile dropdown block (inside `data-nav-target="menu"`): add the Services link between Home and About:
```erb
<%= link_to t("nav.services"), services_path,
      class: current_page?(services_path) ? "text-red-600 font-bold px-6 py-3" : "text-white font-bold px-6 py-3 hover:text-red-600 transition-colors",
      data: { action: "click->nav#toggle" } %>
```

### i18n Keys

Add the following keys to `config/locales/en.yml` under the existing `pages:` namespace. All string values are exact — do not change the copy.

```yaml
  nav:
    services: "Services"   # add alongside existing nav keys

  pages:
    services:
      heading: "OUR SERVICES"
      hero_image_alt: "Syndicate Development services"
      engines:
        heading: "PRECISION ENGINES"
        image_alt: "Engine work at Syndicate Development"
        items:
          build: "Full engine builds and rebuilds"
          top_end: "Top-end and bottom-end service"
          porting: "Porting and head work"
          valve_train: "Valve train service and upgrades"
          blueprinting: "Engine blueprinting and balancing"
      suspension:
        heading: "CUSTOM SUSPENSION SETUP"
        image_alt: "Suspension setup at Syndicate Development"
        items:
          revalving: "Revalving and re-springing for rider weight and style"
          servicing: "Fork and shock servicing"
          linkage: "Linkage and bearing service"
          track_setup: "Track-day and race setup"
          dyno: "Dyno-verified suspension tuning"
      ecu:
        heading: "ECU TUNING"
        image_alt: "ECU tuning at Syndicate Development"
        items:
          fuel_map: "Fuel injection mapping and fuel curve optimization"
          ignition: "Ignition timing adjustment"
          launch_control: "Launch control and traction control configuration"
          dyno_power: "Dyno-tuned power delivery"
          custom_maps: "Custom maps for aftermarket exhausts and air kits"
```

### Image Assets

All images are already present in `app/assets/images/gallery/`. No new assets need to be added.

| Section | Recommended file | Rationale |
|---|---|---|
| Hero banner | `gallery/m45a2849.jpg` | Already used on home page hero; full-bleed action shot |
| Precision Engines | `gallery/m45a2803.jpg` | Close-up mechanical detail shot |
| Custom Suspension | `gallery/m45a2832.jpg` | Bike side-profile shot showing chassis |
| ECU Tuning | `gallery/m45a2996.jpg` | Already used on home page CTA; high-energy shot |

If any of these produce poor visual results at `object-cover` crop, the developer may substitute another gallery image at their discretion — the requirement is one image per section from the local gallery, not a specific filename.

### Background Processing

None.

### Emails

None.

---

## Test Requirements

### Unit / Model Tests

None required — no models are introduced in this spec.

### Request / Integration Tests

Add to `spec/requests/pages_spec.rb` (alongside the existing Home, About, and Gallery blocks):

```ruby
describe "GET /services" do
  it "returns HTTP 200" do
    get services_path
    expect(response).to have_http_status(:ok)
  end

  it "includes the page heading" do
    get services_path
    expect(response.body).to include("OUR SERVICES")
  end

  it "includes the Precision Engines section heading" do
    get services_path
    expect(response.body).to include("PRECISION ENGINES")
  end

  it "includes the Custom Suspension Setup section heading" do
    get services_path
    expect(response.body).to include("CUSTOM SUSPENSION SETUP")
  end

  it "includes the ECU Tuning section heading" do
    get services_path
    expect(response.body).to include("ECU TUNING")
  end

  it "includes at least one img tag" do
    get services_path
    expect(response.body).to include("<img")
  end
end
```

### System Tests (Capybara + Selenium)

Create `spec/system/services_page_spec.rb`:

```ruby
RSpec.describe "Services page", type: :system do
  before { driven_by(:selenium_chrome_headless) }

  it "displays the page heading and all three service section headings" do
    visit services_path
    expect(page).to have_text("OUR SERVICES")
    expect(page).to have_text("PRECISION ENGINES")
    expect(page).to have_text("CUSTOM SUSPENSION SETUP")
    expect(page).to have_text("ECU TUNING")
  end

  it "displays service bullet items for each section" do
    visit services_path
    expect(page).to have_text("Full engine builds and rebuilds")
    expect(page).to have_text("Revalving and re-springing for rider weight and style")
    expect(page).to have_text("Fuel injection mapping and fuel curve optimization")
  end

  it "highlights the Services nav link as active on the desktop nav" do
    Capybara.current_session.driver.browser.manage.window.resize_to(1280, 800)
    visit services_path
    within("nav") do
      services_link = find_link("Services")
      expect(services_link[:class]).to include("text-red-600")
    end
  end

  it "clicking the Services link in the nav navigates to /services" do
    visit root_path
    Capybara.current_session.driver.browser.manage.window.resize_to(1280, 800)
    within("nav") do
      click_link "Services"
    end
    expect(page).to have_current_path(services_path)
    expect(page).to have_text("OUR SERVICES")
  end

  it "renders without horizontal scrolling on a mobile viewport" do
    Capybara.current_session.driver.browser.manage.window.resize_to(375, 667)
    visit services_path
    expect(page).to have_text("OUR SERVICES")
    expect(page).to have_text("PRECISION ENGINES")
  end
end
```

---

## Out of Scope

- Dynamic pricing or rate sheets — all content is static copy; no prices are shown.
- Booking or appointment request forms on the Services page — the existing contact form on `/about` handles all inquiries.
- Individual deep-dive pages per service (e.g. `/services/engines`, `/services/suspension`) — a single unified `/services` page covers all three categories.
- Adding active-state highlighting to the Home, About, and Gallery nav links — only the Services link requires active highlighting per this spec (those links have no active state today and adding it to all four is a separate improvement).
- Lightbox or modal overlays for section images.
- Any JavaScript beyond what is already in place via Stimulus (the existing `nav_controller` requires no changes for Services page functionality).
- Admin CMS or editable service list — content is static in the view and locale file.

---

## Open Questions

1. **Active nav state for all links** — This spec adds active-state highlighting only to the Services nav link, because that is the minimum needed to satisfy the "active/highlighted on this page" acceptance criterion. The Home, About, and Gallery links have no active state today. If the team wants active highlighting on all four links simultaneously, that should be a separate spec or added to the developer's discretion here. This does not block implementation of the Services page. (Non-blocking.)

2. **Hero banner image** — The spec recommends `gallery/m45a2849.jpg` for the hero banner (same image used on the home page hero). If the developer or designer feels reusing the same image looks repetitive, any other `gallery/m45a*.jpg` image may be substituted. The requirement is a full-width banner with a dark overlay and the page title — the specific image is not mandated. (Non-blocking.)

3. **Bullet list content accuracy** — The service bullet items listed in this spec represent the canonical service offering as understood at the time of writing. If Doug Haskett reviews the content and requests changes to specific wording, the only files that need updating are `config/locales/en.yml` (the copy) and this spec. No view code changes are required. This is a content concern, not a technical blocker. (Non-blocking.)

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. Layout, nav partial, Tailwind, asset pipeline, and `PagesController` are all in place.
- SPEC-003 (i18n String Extraction) — done. The i18n convention is established; all new strings must follow the `t()` / `en.yml` pattern from day one and must not be hardcoded in the view.
- No external services, gems, or APIs required. All images are already local assets.
