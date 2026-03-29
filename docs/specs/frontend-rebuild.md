# Spec: Frontend Rebuild — Marketing/Portfolio Site

**ID:** SPEC-001
**Status:** done
**Priority:** high
**Created:** 2026-03-18
**Author:** pm-agent

---

## Summary

Replace the original Express/React frontend of www.syndicate-development.com with a Rails 8.1.2 MVC application using ERB views and Tailwind CSS. The new build preserves all existing content and design intent (dark nav, red accent color, full-bleed hero images, Montserrat typography) while modernizing the markup to be mobile-first and fully responsive. Three pages are required for this phase: Home, About, and Gallery. The Services page is deferred to SPEC-002. No dynamic data layer is required for this phase — all content is static or seeded.

---

## User Stories

- As a site visitor, I want to see the Syndicate Development home page with a hero image and brand messaging, so that I immediately understand what the shop offers.
- As a site visitor, I want to navigate between Home, Services, About, and Gallery from a persistent nav bar, so that I can explore all areas of the site.
- As a site visitor on a mobile device, I want the navigation to collapse into a hamburger menu, so that the nav does not obscure content on small screens.
- As a site visitor, I want to read about Doug Haskett and the shop's background, so that I understand who I'm dealing with.
- As a site visitor, I want to contact the shop via a form on the About page, so that I can ask questions or request work.
- As a site visitor, I want to browse a gallery of completed project photos, so that I can see examples of the shop's work.

---

## Acceptance Criteria

1. Given any page on a desktop viewport (≥768px), the nav bar is fixed to the top, 70px tall, dark background (`#242121`), displays the Syndicate lion logo on the left, and the four nav links — Home, Services, About, Gallery — displayed horizontally on the right and always visible (no toggle, no dropdown). Given any page on a mobile viewport (<768px), the same nav bar is present but the four nav links are hidden; a hamburger icon button is displayed on the right instead.
2. Given the Home page at `/`, it renders a full-viewport hero section with background image, the headline "SYNDICATE DEVELOPMENT", and the tagline "Performance, Passion, Precision."
3. Given the Home page, a mission section below the hero displays the headline "DREAM IT. BUILD IT. RIDE IT. LOVE IT." in red, the subheading "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES", and the full description paragraph (see copy below).
4. Given the Home page, a CTA section renders a second full-viewport background image with the headline "READY TO START BUILDING?" and a red-bordered button/link "CONTACT THE SHOP" linking to `/about`.
5. Given the About page at `/about`, it renders a rotating/fade slideshow of three Cloudinary dirtbike images.
6. Given the About page, a shop info section displays: shop name "SYNDICATE DEVELOPMENT", phone "208-251-9536", address "1801 N. Arthur Ave., Pocatello, ID, 83204" (linked to Google Maps), and the full bio paragraph for Doug Haskett (see copy below).
7. Given the About page, a contact form is present with fields: Name, Email, Subject, Message (textarea), and a Submit button. The form is rendered with `form_with url: contact_path, method: :post` (standard Rails form, CSRF protected). On submit, the `ContactsController#create` action validates the presence of name, email, and message; if valid, it calls `ContactMailer.contact_email(...).deliver_now` which sends an email to `robknowles105@gmail.com`, then redirects to `/about` with `flash[:notice]` "Message sent! We'll be in touch soon.". If any required field is missing, it redirects to `/about` with `flash[:alert]` and no email is sent. Formspree is not used.
8. Given the Gallery page at `/gallery`, it renders a responsive image grid (minimum 2 columns mobile, 3 columns desktop) showing all available project photos.
9. Given any page on a viewport ≤768px, the layout stacks vertically and is readable without horizontal scrolling.
10. Given a mobile viewport (<768px), tapping the hamburger button for the first time reveals a dropdown panel containing the four nav links (Home, Services, About, Gallery) in a dark panel with a red top border. Tapping the hamburger button a second time hides the dropdown. Tapping any nav link inside the dropdown also closes the dropdown and navigates to the target page. This behavior is implemented via a Stimulus controller named `nav_controller` with a `toggle` action that adds or removes a hidden CSS class on the dropdown element; no JavaScript outside of Stimulus is used for this interaction.
11. Given any page, the `<title>` tag reads "Syndicate Development" (not the Rails default placeholder).
12. Given a GET request to `/`, `/about`, `/gallery`, the server returns HTTP 200.

---

## Technical Scope

### Models / Database

No new models or migrations required for this phase. All content is static in views or hardcoded in controllers/helpers.

### Controllers / Routes

Add the following routes:

```
GET   /            pages#home
GET   /about       pages#about
GET   /gallery     pages#gallery
POST  /contact     contacts#create
```

Create a `PagesController` with three actions (`home`, `about`, `gallery`), each rendering the corresponding view template. No auth required.

Create a `ContactsController` with a single `create` action that:
1. Validates presence of name, email, and message params
2. Calls `ContactMailer.contact_email(...).deliver_now`
3. Redirects to `/about` with `flash[:notice]` on success
4. Redirects to `/about` with `flash[:alert]` on validation failure

### Views / UI

**Layout (`app/views/layouts/application.html.erb`)**
- Add Tailwind CSS (via `tailwindcss-rails` gem — see Dependencies).
- Include the Google Fonts import for Montserrat (weights 400, 700, 900).
- Add the shared `_nav` partial inside `<body>` before `<%= yield %>`.
- Set `<title>` to `"Syndicate Development"`.

**Nav partial (`app/views/shared/_nav.html.erb`)**
- Fixed top bar, dark background, height 70px, z-index high.
- Left: Syndicate lion logo image from local assets (`app/assets/images/syndicate-lion.png`) linking to `/`. Use Rails `image_tag "syndicate-lion.png"`.
- Right (desktop ≥768px): a horizontal link list — Home, Services, About, Gallery — white text, Montserrat font, hover turns red. These links are always visible on desktop and are never hidden.
- Right (mobile <768px): the horizontal link list is hidden (e.g. via a Tailwind `hidden md:flex` pattern). A hamburger icon `<button>` is shown in its place. The button must carry `data-controller="nav"` and `data-action="click->nav#toggle"` (or equivalent Stimulus data attributes on the wrapping nav element). Below the nav bar, a dropdown `<div>` contains the same four links stacked vertically in a dark panel (`#242121` background) with a red top border; this div carries `data-nav-target="menu"` and starts hidden. Each link inside the dropdown must also carry `data-action="click->nav#toggle"` so that tapping it closes the dropdown before navigating. The `nav_controller` Stimulus controller implements a single `toggle()` action that adds/removes a CSS hidden class on the menu target.

**Home (`app/views/pages/home.html.erb`)**

Section 1 — Hero:
- Full-viewport div with background image. **Placeholder:** Cloudinary URL `https://res.cloudinary.com/datcltouj/image/upload/q_auto:eco/v1566577213/jhkj9vmgrsuktmrw1y6c.jpg` — replace with local asset once downloaded. Use inline style `background-image: url(...)` with `bg-cover bg-center` Tailwind classes.
- Overlay text (positioned bottom-left or center): `<h1>` "SYNDICATE DEVELOPMENT", `<p>` "Performance, Passion, Precision."
- Optional: a "PROJECT GALLERY" button linking to `/gallery`.

Section 2 — Mission:
- Centered, white background.
- `<h2>` "DREAM IT. BUILD IT. RIDE IT. LOVE IT." in red (`#db0505`), large, Montserrat.
- `<h4>` "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES"
- `<p>` — full copy:
  > "From simple upgrades to full race ready bikes, Syndicate Development is here to cater to all of your motorcycle needs. With state of the art equipment and a performance dyno room, we are here to get your machine performing better than you even thought possible. We specialize in custom suspension, engine performance, and ECU tuning, but we also offer things from regular services to full race prep. Give us a call or send us a message and let us know what we can do for you!"

Section 3 — Service Icons (optional for MVP; include if straightforward):
- A 2×2 grid of icon cards: ENGINE (piston icon), SUSPENSION (spring icon), GALLERY (photo icon), SHOP TALK (wrench icon). Icons source from `src/components/images/` — copy those PNG files to `app/assets/images/`.

Section 4 — CTA:
- Full-viewport div with background image. **Placeholder:** Cloudinary URL `https://res.cloudinary.com/datcltouj/image/upload/v1566836472/gimrzsuvathl7rcifzgi.jpg` — replace with local asset once downloaded.
- `<h1>` "READY TO START BUILDING?"
- Red-bordered link/button "CONTACT THE SHOP" → `/about`.

**About (`app/views/pages/about.html.erb`)**
- Image slideshow: three images cycling with a CSS fade animation (replicate original `@keyframes bikes` using a custom CSS block in `app/assets/stylesheets/`). **Placeholder:** use three local gallery images (e.g. `m45a2920.jpg`, `m45a2927.jpg`, `m45a2928.jpg`) until Cloudinary originals are downloaded. Original Cloudinary refs: `v1570478297/lchkfu4bspgu65uf4o4u`, `v1570478260/lqwrgl3vkocncpvzikow`, `v1570478258/iscbtckkmdofzwlneeqj`.
- Shop info block:
  - Heading: "SYNDICATE DEVELOPMENT"
  - Phone: "Shop Phone: 208-251-9536"
  - Address: "Shop Address: 1801 N. Arthur Ave., Pocatello, ID, 83204" (linked to `https://goo.gl/maps/k6PjesVBsAqDArb27`)
- Bio copy:
  > "Doug Haskett has been involved with motorcycles and racing for most of his life. Since 1998 he has been perfecting his skills in the mechanics of the machine, learning the fine craft of engine, suspension and ECU tuning, and overall bike fixes, upgrades and performance. He has worked at the highest levels of dirt bike racing, having experience with professional Supercross and Motocross teams such as Rocky Mountain ATV MC and High Desert Racing as a mechanic. He has also worked with many pro riders in testing and has the experience to do some testing himself. He continues to ride and race, and his lifelong passion for bikes combined with his knowledge and state of the art performance equipment and dyno room make him a highly sought-after mechanic today. Have a question? Send a message!"
- Contact form using `form_with url: contact_path, method: :post`:
  - Fields: name (text), email (text), subject (text), message (textarea)
  - Submit button: "Send Message"
  - On submit, a `ContactsController#create` action sends an email via ActionMailer to `robknowles105@gmail.com` then redirects back to `/about` with a flash notice "Message sent! We'll be in touch soon."
  - Use `gem "letter_opener"` in development to preview emails in the browser without a real SMTP server.
  - In production, configure Rails `action_mailer.smtp_settings` (provider TBD — e.g. SendGrid, Postmark, or Gmail SMTP). This is out of scope for the initial build; use letter_opener for now.
  - CSRF protection is active (standard Rails `form_with`).

**Gallery (`app/views/pages/gallery.html.erb`)**
- Responsive grid of all local project images.
- Images should be copied from `src/components/images/m45a*.jpg` to `app/assets/images/gallery/`.
- Grid: `grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2` (Tailwind).
- Each cell: a square-cropped image (`object-cover aspect-square`), optionally wrapped in an `<a>` for lightbox expansion (lightbox is out of scope for MVP; wrap in `<a>` pointing to the full image for later).
- Do not display the noun_*.png icon images in the gallery grid.

### Background Jobs

None.

### Emails

**ContactMailer** (`app/mailers/contact_mailer.rb`):
- Method: `contact_email(name:, email:, subject:, message:)`
- To: `robknowles105@gmail.com`
- Reply-To: submitter's email address
- Subject: `"[Syndicate Development] #{subject}"`
- Body: plain-text and HTML templates showing name, email, subject, and message
- Templates: `app/views/contact_mailer/contact_email.html.erb` and `.text.erb`

**Development:** use `gem "letter_opener"` — emails open in the browser instead of being sent.
**Production SMTP:** TBD (separate config task); not in scope for this spec.

---

## Test Requirements

### Unit / Model Tests

None required — no models are introduced in this spec.

### Request / Integration Tests

1. `GET /` returns HTTP 200 and response body includes "SYNDICATE DEVELOPMENT".
2. `GET /about` returns HTTP 200 and response body includes "Doug Haskett" and "208-251-9536".
3. `GET /gallery` returns HTTP 200 and response body includes at least one `<img` tag.
4. Each of the three routes resolves without error (no 404, no 500).
5. `POST /contact` with valid params enqueues an email (mock delivery) and redirects to `/about` with a flash notice.
6. `POST /contact` with missing params redirects to `/about` with a flash alert and does not send email.

### System Tests (Capybara + Selenium)

1. Visiting `/` displays the text "SYNDICATE DEVELOPMENT" and "Performance, Passion, Precision."
2. Clicking "CONTACT THE SHOP" on the home page navigates to `/about`.
3. On a mobile viewport (375×667), the four nav links (Home, Services, About, Gallery) are not visible in the nav bar and the hamburger icon button is visible.
4. On a mobile viewport (375×667), clicking the hamburger button causes the dropdown panel to become visible, showing all four nav links (Home, Services, About, Gallery).
5. On a mobile viewport (375×667), with the dropdown open, clicking the hamburger button again hides the dropdown panel.
6. On a mobile viewport (375×667), with the dropdown open, clicking one of the nav links (e.g. "About") closes the dropdown and navigates to the target page.
7. Visiting `/gallery` renders a grid with multiple images visible.
8. Filling out and submitting the contact form on `/about` with valid data shows the flash notice "Message sent! We'll be in touch soon."
9. Submitting the contact form with missing required fields shows a flash alert.

---

## Out of Scope

- Services page — deferred to a future spec (SPEC-002).
- Admin panel (ServicesAdmin, ProjectAdmin, TechAdmin) — no auth or CMS in this phase.
- Blog / Projects feed (dynamic content from a database).
- Tech Tips / Shop Talk blog page.
- Engine and Suspension standalone deep-dive pages (`/engine`, `/suspension`).
- Lightbox image viewer on Gallery.
- Contact form backend (ActionMailer); Formspree handles delivery.
- Any Redis, Sidekiq, or external queue usage.
- PWA manifest / service worker.

---

## Open Questions

1. **Hero / slideshow images not yet local**: The home page hero, CTA hero, services header, and about slideshow images exist only on Cloudinary. Views should use the Cloudinary URLs as placeholders with a `<!-- TODO: replace with local asset -->` comment. Download and add to `app/assets/images/` in a follow-up task.
2. **Production SMTP provider**: `letter_opener` handles development email previews. A production SMTP provider (SendGrid, Postmark, Gmail SMTP, etc.) needs to be chosen and configured before deploying. This is a separate task.
3. **Active Storage for gallery growth**: If the gallery photo set grows significantly, migrating from committed assets to Active Storage + cloud storage (S3/GCS) is the recommended path. Separate spec when needed.

---

## Dependencies

- **Tailwind CSS**: Add `gem "tailwindcss-rails"` to the Gemfile and run `bin/rails tailwindcss:install`. This is a prerequisite before any view work can begin.
- **letter_opener**: Add `gem "letter_opener"` to the `development` group for email previewing during development. Configure in `config/environments/development.rb`: `config.action_mailer.delivery_method = :letter_opener`.
- **All assets are local** — no Cloudinary gem or API key required. Images in `app/assets/images/` and `app/assets/images/gallery/`. Any images not yet available locally use Cloudinary placeholder URLs (annotated in views with a TODO comment).
