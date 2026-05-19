# Spec: i18n String Extraction

**ID:** SPEC-003
**Status:** done
**Priority:** medium
**Created:** 2026-04-01
**Author:** pm-agent

---

## Summary

This project is a Rails 8.1 application (Syndicate Development motorcycle shop site) with hardcoded English strings scattered across ERB views, controllers, and mailers. This feature extracts every user-facing hardcoded string into the Rails I18n system (`config/locales/en.yml` and scoped locale files), so that all copy lives in one authoritative location, is consistently referenced via the `t()` helper in views and `I18n.t()` in Ruby classes, and can be translated or updated without touching template code.

---

## User Stories

- As a developer, I want all user-facing strings defined in locale files, so that I can update copy without hunting through templates.
- As a future maintainer, I want a consistent `t()` call pattern in every view, so that the codebase is predictable and auditable.
- As a translator (potential future need), I want a single source of truth in YAML, so that I can produce a translated locale file without reading ERB.

---

## Acceptance Criteria

1. Given the existing `config/locales/en.yml`, when the migration is complete, then every user-facing string in ERB views, controllers, and mailers is referenced via `t()` or `I18n.t()` rather than being hardcoded as a string literal.
2. Given a locale key such as `en.nav.home`, when `t("nav.home")` is called in a view, then it returns the correct English string without raising a `I18n::MissingTranslationData` exception.
3. Given the `config/locales/en.yml` file, when it is inspected, then it is organised into namespaces that mirror the application structure: `nav`, `pages.home`, `pages.about`, `pages.gallery`, `contact`, `mailer.contact_email`, and `errors`.
4. Given the `ContactsController`, when it issues a flash `alert` or `notice`, then the string value comes from `I18n.t()` rather than an inline string literal.
5. Given the `ContactMailer`, when it constructs the email `subject:` line, then the prefix string `"[Syndicate Development]"` is drawn from a locale key.
6. Given the Rails test suite, when `rails test` is run, then no test fails due to missing locale keys or changed string values.

---

## Technical Scope

### Data / Models

No schema changes. No new models.

### API / Logic

**`app/controllers/contacts_controller.rb`**
- Replace inline `alert:` string `"Please fill in all required fields (name, email, and message)."` with `I18n.t("contact.errors.missing_required_fields")`.
- Replace inline `notice:` string `"Message sent! We'll be in touch soon."` with `I18n.t("contact.notices.message_sent")`.
- Replace fallback string `"(No subject)"` with `I18n.t("contact.form.no_subject")`.

**`app/mailers/contact_mailer.rb`**
- Replace the hardcoded `"[Syndicate Development] #{subject}"` subject prefix with a locale key: `"#{I18n.t('mailer.contact_email.subject_prefix')} #{subject}"`.

### UI / Frontend

The following ERB files contain hardcoded strings that must be replaced with `t()` calls. The locale key structure to use is shown for each.

**`app/views/layouts/application.html.erb`**
- `<title>Syndicate Development</title>` → `t("application.title")`
- `content="Syndicate Development"` (application-name meta tag) → `t("application.name")`

**`app/views/shared/_nav.html.erb`**
- `alt: "Syndicate Development"` on the logo image → `t("nav.logo_alt")`
- Link text `"Home"` → `t("nav.home")`
- Link text `"About"` → `t("nav.about")`
- Link text `"Gallery"` → `t("nav.gallery")`
- `aria-label: "Toggle navigation menu"` → `t("nav.toggle_aria_label")`

**`app/views/pages/home.html.erb`**
- Hero `<h1>` text `"SYNDICATE DEVELOPMENT"` → `t("pages.home.hero_heading")`
- Hero `<p>` tagline `"Performance, Passion, Precision."` → `t("pages.home.hero_tagline")`
- Link text `"PROJECT GALLERY"` → `t("pages.home.cta_gallery")`
- Mission `<h2>` `"DREAM IT. BUILD IT. RIDE IT. LOVE IT."` → `t("pages.home.mission_heading")`
- Mission `<h4>` `"SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES"` → `t("pages.home.mission_subheading")`
- Mission `<p>` body copy (multiline paragraph) → `t("pages.home.mission_body")`
- CTA `<h1>` `"READY TO START BUILDING?"` → `t("pages.home.cta_heading")`
- CTA link text `"CONTACT THE SHOP"` → `t("pages.home.cta_contact")`

**`app/views/pages/about.html.erb`**
- `<h2>` `"SYNDICATE DEVELOPMENT"` → `t("pages.about.shop_heading")`
- `<strong>Shop Phone:</strong>` → `t("pages.about.shop_phone_label")`
- `<strong>Shop Address:</strong>` → `t("pages.about.shop_address_label")`
- Address text `"1801 N. Arthur Ave., Pocatello, ID, 83204"` → `t("pages.about.shop_address")`
- `<h3>` `"About Doug Haskett"` → `t("pages.about.bio_heading")`
- Bio body paragraph → `t("pages.about.bio_body")`
- Contact form `<h3>` `"CONTACT THE SHOP"` → `t("pages.about.contact_heading")`
- Form label `"Name *"` → `t("pages.about.form.name_label")`
- Placeholder `"Your name"` → `t("pages.about.form.name_placeholder")`
- Form label `"Email *"` → `t("pages.about.form.email_label")`
- Placeholder `"your@email.com"` → `t("pages.about.form.email_placeholder")`
- Form label `"Subject"` → `t("pages.about.form.subject_label")`
- Placeholder `"What is this about?"` → `t("pages.about.form.subject_placeholder")`
- Form label `"Message *"` → `t("pages.about.form.message_label")`
- Placeholder `"Tell us what you need..."` → `t("pages.about.form.message_placeholder")`
- Submit button `"Send Message"` → `t("pages.about.form.submit")`
- Alt text on slideshow images `"Syndicate Development motorcycle 1/2/3"` → `t("pages.about.slideshow_alt", n: 1)` etc. (interpolation)

**`app/views/pages/gallery.html.erb`**
- `<h1>` `"PROJECT GALLERY"` → `t("pages.gallery.heading")`
- Alt text `"Syndicate Development project photo"` → `t("pages.gallery.photo_alt")`

**`app/views/contact_mailer/contact_email.html.erb`** and **`contact_email.text.erb`**
- `"New Contact Form Submission"` heading/line → `t("mailer.contact_email.heading")`
- Label strings `"Name:"`, `"Email:"`, `"Subject:"`, `"Message:"` → `t("mailer.contact_email.name_label")` etc.

### Locale File Structure

The final `config/locales/en.yml` must follow this top-level namespace layout:

```yaml
en:
  application:
    title: "Syndicate Development"
    name: "Syndicate Development"

  nav:
    logo_alt: "Syndicate Development"
    home: "Home"
    about: "About"
    gallery: "Gallery"
    toggle_aria_label: "Toggle navigation menu"

  pages:
    home:
      hero_heading: "SYNDICATE DEVELOPMENT"
      hero_tagline: "Performance, Passion, Precision."
      cta_gallery: "PROJECT GALLERY"
      mission_heading: "DREAM IT. BUILD IT. RIDE IT. LOVE IT."
      mission_subheading: "SPECIALIZING IN CUSTOM PERFORMANCE MOTOCROSS AND SUPERCROSS MOTORCYCLES"
      mission_body: "From simple upgrades to full race ready bikes..."
      cta_heading: "READY TO START BUILDING?"
      cta_contact: "CONTACT THE SHOP"
    about:
      shop_heading: "SYNDICATE DEVELOPMENT"
      shop_phone_label: "Shop Phone:"
      shop_address_label: "Shop Address:"
      shop_address: "1801 N. Arthur Ave., Pocatello, ID, 83204"
      bio_heading: "About Doug Haskett"
      bio_body: "Doug Haskett has been involved..."
      contact_heading: "CONTACT THE SHOP"
      slideshow_alt: "Syndicate Development motorcycle %{n}"
      form:
        name_label: "Name *"
        name_placeholder: "Your name"
        email_label: "Email *"
        email_placeholder: "your@email.com"
        subject_label: "Subject"
        subject_placeholder: "What is this about?"
        message_label: "Message *"
        message_placeholder: "Tell us what you need..."
        submit: "Send Message"
    gallery:
      heading: "PROJECT GALLERY"
      photo_alt: "Syndicate Development project photo"

  contact:
    form:
      no_subject: "(No subject)"
    errors:
      missing_required_fields: "Please fill in all required fields (name, email, and message)."
    notices:
      message_sent: "Message sent! We'll be in touch soon."

  mailer:
    contact_email:
      subject_prefix: "[Syndicate Development]"
      heading: "New Contact Form Submission"
      name_label: "Name:"
      email_label: "Email:"
      subject_label: "Subject:"
      message_label: "Message:"
```

No additional locale files (e.g. `es.yml`) are created in this spec. The structure is designed to make adding them trivial later.

### Background Processing

None.

---

## Test Requirements

### Unit Tests

- `test/mailers/contact_mailer_test.rb`: assert the email subject line uses the locale key value and that no literal `"[Syndicate Development]"` string appears in the mailer source.
- `test/controllers/contacts_controller_test.rb`:
  - POST with missing fields: assert flash `alert` equals `I18n.t("contact.errors.missing_required_fields")`.
  - POST with valid fields: assert flash `notice` equals `I18n.t("contact.notices.message_sent")`.

### Integration Tests

- `test/integration/locale_completeness_test.rb`: iterate over every key defined in `config/locales/en.yml` and assert `I18n.t(key)` does not return a "translation missing" string. This catches gaps between the YAML and any call site.

### End-to-End Tests

- Load the home page and assert the page title is `"Syndicate Development"`.
- Load the about page, submit the contact form with an empty name, and assert the flash alert text matches the locale value.
- Load the about page, submit the contact form with all valid fields, and assert the flash notice text matches the locale value.

---

## Migration Plan

Execute the migration in this order to keep the app functional at each step:

1. **Populate `config/locales/en.yml`** with all keys and their current English values first. The app continues to use hardcoded strings and nothing breaks.
2. **Replace strings in `_nav.html.erb`** (shared partial — highest visibility, easiest to verify visually).
3. **Replace strings in `layouts/application.html.erb`** (title and meta tags).
4. **Replace strings in `pages/home.html.erb`**.
5. **Replace strings in `pages/about.html.erb`** (including the contact form labels and placeholders).
6. **Replace strings in `pages/gallery.html.erb`**.
7. **Replace strings in `contact_mailer/` views** (both `.html.erb` and `.text.erb`).
8. **Replace strings in `ContactsController`** (flash messages, fallback subject).
9. **Replace strings in `ContactMailer`** (email subject prefix).
10. **Run the full test suite** after each file to catch regressions immediately.

---

## Out of Scope

- Adding any non-English locale files (e.g. `es.yml`, `fr.yml`).
- Translating or changing the content of any string — only extraction, not editing.
- Extracting strings from `public/404.html`, `public/422.html`, `public/500.html` — these are static HTML files served by the web server before Rails loads and cannot use the I18n system.
- Extracting strings from `app/views/pwa/manifest.json.erb` — the PWA manifest `name` and `description` fields are not user-facing UI strings governed by the Rails view layer.
- Extracting the `default from:` email address in `ApplicationMailer` — this is configuration, not a user-facing string.
- Extracting the recipient email `"robknowles105@gmail.com"` in `ContactMailer` — this is configuration, not copy.
- Setting up a locale switcher or `around_action` for locale detection.

---

## Open Questions

1. **Slideshow alt text interpolation** — the current alt strings are `"Syndicate Development motorcycle 1"`, `"...2"`, `"...3"`. The simplest approach is a single key with `%{n}` interpolation called three times. An alternative is three separate keys. Neither blocks progress; interpolation is preferred. (Non-blocking.)
2. **Long prose strings** — the bio body and mission body paragraphs are multi-sentence. YAML scalar strings can hold them as quoted or literal block scalars. The developer should use the YAML literal block style (`|`) for readability. (Non-blocking.)
3. **`app/views/pwa/manifest.json.erb`** — the `name` and `description` fields are currently `"SyndicateDevelopment2026"` (the Rails app constant name, not the brand name). Whether this should be corrected to `"Syndicate Development"` as part of this work is a separate concern and is explicitly out of scope here.

---

## Dependencies

- SPEC-001 (Frontend Rebuild) — done. This spec operates on the views produced by that work.
- No external services required.
