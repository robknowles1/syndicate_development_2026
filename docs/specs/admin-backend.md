# Spec: Admin Backend — Authentication and Services Page Management

**ID:** SPEC-004
**Status:** done
**Priority:** high
**Created:** 2026-05-19
**Author:** pm-agent

---

## Summary

Add a password-protected admin backend at `/admin` so that Doug Haskett (the shop owner) can log in and manage site content without developer involvement. The first management surface is the Services page (currently on hold as SPEC-002): Doug can toggle whether the Services page is publicly accessible and edit the heading and bullet-list content for each of the three service sections (Precision Engines, Custom Suspension Setup, ECU Tuning). A single admin user is seeded via `db/seeds.rb`; there is no self-registration flow. Auth uses Rails `has_secure_password` with session-based login — no Devise, no JWT.

---

## User Stories

- As Doug (the admin), I want to log in at `/admin/login` with my email and password, so that I have exclusive access to site management tools.
- As Doug (the admin), I want to be redirected to `/admin/login` if I visit any `/admin/*` URL while unauthenticated, so that admin pages are never publicly accessible.
- As Doug (the admin), I want a dashboard at `/admin` that shows me which site sections I can manage, so that I have a clear starting point after logging in.
- As Doug (the admin), I want to toggle the Services page on or off with a single click, so that I can control whether the public can see it without help from a developer.
- As Doug (the admin), I want to edit the heading and bullet-list items for each of the three service sections, so that I can keep the Services page content current.
- As Doug (the admin), I want to log out and end my session, so that no one else on my machine can access admin tools.
- As a public visitor, I want the Services nav link to be hidden when the Services page is unpublished, so that I am not directed to a broken URL.
- As a public visitor, I want to be silently redirected to the home page if I manually navigate to `/services` while it is unpublished, so that I see no error.

---

## Acceptance Criteria

1. Given an unauthenticated user, when they visit any route under `/admin/*` (including `/admin`), then they are redirected to `GET /admin/login` and the original admin path is not rendered.

2. Given the login page at `GET /admin/login`, when it is rendered, then it displays an email field, a password field, and a submit button — no other admin UI is visible.

3. Given a user submits `POST /admin/login` with the correct email and password for the seeded admin user, then a session is established, and they are redirected to `GET /admin`.

4. Given a user submits `POST /admin/login` with an incorrect email or password, then no session is created, the login page is re-rendered, and a `flash[:alert]` message is shown (e.g., "Invalid email or password."). The response must not reveal whether the email or the password specifically was wrong.

5. Given an authenticated admin user at `GET /admin`, when the page is rendered, then it displays a heading identifying the admin area and at least one link to the Services management page.

6. Given an authenticated admin user, when they submit `DELETE /admin/logout` (or `GET /admin/logout` — see Open Questions), then their session is destroyed and they are redirected to `GET /admin/login`.

7. Given a `SiteSetting` (or equivalent) record that stores `services_page_published: boolean`, when `services_page_published` is `false`, then a `GET /services` request by any public visitor redirects to `/` with no flash message rendered.

8. Given `services_page_published` is `false`, when any page containing the nav partial is rendered for a public (non-admin) visitor, then the "Services" link is absent from the rendered HTML.

9. Given `services_page_published` is `true`, when a public visitor requests `GET /services`, then the page renders with HTTP 200.

10. Given `services_page_published` is `true`, when any page containing the nav partial is rendered, then the "Services" link is present in the rendered HTML.

11. Given the admin is on the Services management page at `GET /admin/services`, when they toggle the published state (e.g. via a form submit), then `services_page_published` is updated in the database, a `flash[:notice]` confirms the change, and the page re-renders reflecting the new state.

12. Given the admin is on the Services management page, when it renders, then it displays the current heading and bullet-list items for all three service sections (Precision Engines, Custom Suspension Setup, ECU Tuning) in editable form fields.

13. Given the admin submits the edit form for a service section with a new heading and/or modified bullet-list items, when the form is processed, then the new content is persisted, a `flash[:notice]` confirms the save, and the `/services` public page reflects the updated content on next load.

14. Given the admin edits a service section's bullet list, they can add a new item, edit the text of an existing item, and mark an existing item for removal — all within the same form submit. The minimum number of bullet items per section is one; submitting a section with zero items is rejected with a validation error.

15. Given the seeded admin user created by `db/seeds.rb`, when `bin/rails db:seed` is run on a fresh database, then an `AdminUser` record exists with email `doug@syndicate-development.com` and a bcrypt-hashed password, and no plain-text password is stored anywhere in the codebase or version control.

---

## Technical Scope

### Data / Models

**`AdminUser`** — new table `admin_users`

| column | type | notes |
|---|---|---|
| `id` | bigint PK | |
| `email` | string | not null, unique, indexed |
| `password_digest` | string | not null; used by `has_secure_password` |
| `created_at` | datetime | |
| `updated_at` | datetime | |

- Validations: presence and uniqueness of `email`, format validation (simple regex or URI::MailTo).
- `has_secure_password` (Rails built-in, requires `bcrypt` gem).
- Seeded with one record for Doug Haskett. Password value read from an environment variable (e.g. `ENV["ADMIN_SEED_PASSWORD"]`) — never hardcoded.

**`SiteSetting`** — new table `site_settings`

| column | type | notes |
|---|---|---|
| `id` | bigint PK | |
| `key` | string | not null, unique, indexed |
| `value` | string | not null |
| `created_at` | datetime | |
| `updated_at` | datetime | |

- A key-value store for boolean and string site-wide flags.
- Seeded with `{ key: "services_page_published", value: "false" }`.
- Access pattern: `SiteSetting.get("services_page_published")` and `SiteSetting.set("services_page_published", "true")` — class-level convenience methods.
- Boolean coercion: `SiteSetting.enabled?("services_page_published")` returns `true` when value is `"true"`.

**`ServiceSection`** — new table `service_sections` (see ADR-001)

| column | type | notes |
|---|---|---|
| `id` | bigint PK | |
| `slug` | string | not null, unique, indexed — e.g. `"precision_engines"` |
| `heading` | string | not null |
| `created_at` | datetime | |
| `updated_at` | datetime | |

- `has_many :service_bullets, -> { order(:position) }, dependent: :destroy`
- `accepts_nested_attributes_for :service_bullets, allow_destroy: true, reject_if: :all_blank`
- Custom validation: must have at least one bullet not marked for destruction after nested attributes are applied.
- Three records seeded via `db/seeds.rb` using slugs `"precision_engines"`, `"custom_suspension_setup"`, `"ecu_tuning"`. Seeds use `find_or_create_by(slug: ...)` and are idempotent.

**`ServiceBullet`** — new table `service_bullets` (see ADR-001)

| column | type | notes |
|---|---|---|
| `id` | bigint PK | |
| `service_section_id` | bigint FK | not null, indexed (composite index with `position`) |
| `body` | string | not null |
| `position` | integer | not null, default 0 — display ordering |
| `created_at` | datetime | |
| `updated_at` | datetime | |

- `belongs_to :service_section`
- Bullet items for each section seeded alongside their parent `ServiceSection`.

Decision rationale: Option A (relational rows) was chosen over Option B (locale-file overrides) because variable-length ordered lists are a natural one-to-many relationship that does not map cleanly to flat key-value storage. Rails nested attributes (`accepts_nested_attributes_for`) handle this pattern directly. See ADR-001 at `docs/architecture/ADR-001-service-content-storage.md` for full rationale.

### Routes

All admin routes are namespaced under `/admin`. Public-facing route changes are also listed.

```ruby
# Public
get  "/services",        to: "pages#services"   # new — guarded by before_action

# Admin namespace
namespace :admin do
  get    "login",   to: "sessions#new",     as: :login
  post   "login",   to: "sessions#create"
  delete "logout",  to: "sessions#destroy", as: :logout

  root                   to: "dashboard#index"   # GET /admin

  resource :services_page, only: [:show, :update]  # GET/PATCH /admin/services_page
  # service section content routes — shape depends on architect decision
end
```

Note: `resource :services_page` (singular) is used because there is exactly one Services page setting. Content editing routes for individual service sections will be defined after the architect decision.

### Controllers

**`Admin::BaseController < ApplicationController`**
- Defines `require_admin` before_action: checks `session[:admin_user_id]`; redirects to `admin_login_path` if absent.
- All admin controllers inherit from this.

**`Admin::SessionsController < Admin::BaseController`**
- `new` — renders login form (skips `require_admin` via `skip_before_action`).
- `create` — finds `AdminUser` by email, authenticates with `authenticate` (from `has_secure_password`), sets `session[:admin_user_id]`, redirects to `admin_root_path` on success; re-renders `new` with `flash[:alert]` on failure.
- `destroy` — clears `session[:admin_user_id]`, redirects to `admin_login_path`.

**`Admin::DashboardController < Admin::BaseController`**
- `index` — renders the admin dashboard view.

**`Admin::ServicesPagesController < Admin::BaseController`**
- `show` — loads current `services_page_published` setting and current service section content; renders admin form.
- `update` — handles the published toggle and/or content edits; updates records; redirects back with `flash[:notice]`.

**`PagesController`** (existing, modified)
- Add `services` action.
- Add a `before_action` on the `services` action: check `SiteSetting.enabled?("services_page_published")`; redirect to `root_path` if false.

### Views

All admin views live under `app/views/admin/`. Admin layout (`app/views/layouts/admin.html.erb`) is separate from the public layout — minimal styling (Tailwind utility classes are fine), no public nav, no hero imagery.

- `admin/sessions/new.html.erb` — login form (`form_with url: admin_login_path, method: :post`).
- `admin/dashboard/index.html.erb` — heading, brief welcome, link to Services page management.
- `admin/services_pages/show.html.erb` — published toggle (form with checkbox or toggle button), editable fields for each service section's heading and bullet items.
- `app/views/pages/services.html.erb` — new public Services page view (content sourced from whichever storage the architect approves).
- `app/views/shared/_nav.html.erb` — modified: the Services link is conditionally rendered based on `SiteSetting.enabled?("services_page_published")`.

### i18n Keys

Add the following keys to `config/locales/en.yml` (no hardcoded strings in views):

```yaml
en:
  admin:
    login:
      heading: "Admin Login"
      email_label: "Email"
      password_label: "Password"
      submit: "Log In"
      invalid_credentials: "Invalid email or password."
    dashboard:
      heading: "Admin Dashboard"
      services_link: "Manage Services Page"
    services_page:
      heading: "Services Page Settings"
      published_label: "Services page is published (visible to the public)"
      save: "Save Changes"
      toggle_notice: "Services page visibility updated."
      content_notice: "Service section content saved."
      validation_error: "Each service section must have at least one bullet item."
  nav:
    services: "Services"   # add if not already present
  pages:
    services:
      heading: "Services"  # initial placeholder; content driven by storage mechanism
```

### Background Processing

None required for this spec.

---

## Test Requirements

### Unit Tests

1. `AdminUser` model: valid with email and password; invalid without email; invalid without password; `authenticate` returns the record on correct password; `authenticate` returns false on incorrect password; password is not stored in plain text (assert `password_digest` is not equal to the raw password string).
2. `SiteSetting` model: `.get` returns the string value for a known key; `.get` returns `nil` for an unknown key; `.set` creates a new record when the key does not exist; `.set` updates the value when the key already exists; `.enabled?` returns `true` when value is `"true"` and `false` when value is `"false"`.

### Request (Integration) Tests

All request specs live under `spec/requests/admin/`.

**Auth flow**
1. `GET /admin` when unauthenticated responds with redirect to `/admin/login`.
2. `GET /admin/services_page` when unauthenticated responds with redirect to `/admin/login`.
3. `POST /admin/login` with correct credentials responds with redirect to `/admin`.
4. `POST /admin/login` with incorrect credentials responds with HTTP 200 (re-renders login) and does not set `session[:admin_user_id]`.
5. `DELETE /admin/logout` when authenticated clears the session and redirects to `/admin/login`.

**Dashboard**
6. `GET /admin` when authenticated responds with HTTP 200 and body includes the dashboard heading.

**Services page toggle**
7. `PATCH /admin/services_page` with `{ site_setting: { value: "true" } }` when authenticated updates `services_page_published` to `"true"` and redirects with flash notice.
8. `PATCH /admin/services_page` with `{ site_setting: { value: "false" } }` when authenticated updates `services_page_published` to `"false"` and redirects with flash notice.

**Public services route**
9. `GET /services` when `services_page_published` is `"true"` responds with HTTP 200.
10. `GET /services` when `services_page_published` is `"false"` responds with redirect to `/`.
11. `GET /` (home page) when `services_page_published` is `"false"` renders HTML that does not include the text "Services" in the nav element.
12. `GET /` (home page) when `services_page_published` is `"true"` renders HTML that includes the "Services" nav link.

**Service content editing** (scope depends on architect decision — placeholders; finalize after SPEC-004 architect review)
13. `GET /admin/services_page` when authenticated responds with HTTP 200 and body includes headings for all three service sections.
14. `PATCH /admin/services_page` with valid content params persists the new content and redirects with flash notice.
15. `PATCH /admin/services_page` with zero bullet items for a section re-renders the form with a validation error message.

### System (End-to-End) Tests

All system specs live under `spec/system/admin/`.

1. Visiting `/admin/login` shows an email field, a password field, and a submit button.
2. Submitting the login form with correct credentials redirects to `/admin` and the dashboard heading is visible.
3. Submitting the login form with incorrect credentials stays on `/admin/login` and shows "Invalid email or password."
4. After logging in, visiting `/admin/logout` (or clicking a Logout button/link) returns the user to `/admin/login`.
5. On the Services management page, toggling the published state (checking/unchecking and submitting) causes the nav Services link to appear or disappear on the public home page when visited in the same browser session.
6. On a separate (non-admin) browser context: with `services_page_published` false, navigating to `/services` lands on `/` with no error shown; with `services_page_published` true, navigating to `/services` renders the Services page.

---

## Out of Scope

- Gallery content management (future spec).
- Contact form/submission management (future spec).
- Multiple admin users or role-based access control.
- Password reset / "forgot password" flow — initial password is set via seed; a future spec will add self-service reset.
- Admin user invitation or registration UI — no sign-up page exists or is permitted.
- Any JavaScript-heavy SPA admin interface — standard Turbo-compatible Rails forms only.
- Rate limiting or brute-force protection on the login endpoint (recommended for production hardening, separate spec or devops task).
- Email notification to Doug when someone submits the contact form — already handled by SPEC-001.
- Two-factor authentication.
- Audit logging of admin actions.

---

## Open Questions

1. **[BLOCKS AC 12-14 — ARCHITECT INPUT REQUIRED] How should service section content (headings and bullet items) be stored?**

   Two candidate approaches:

   **Option A — Database rows.** A `ServiceSection` model (table: `service_sections`) with columns `slug` (string, unique — e.g. `"precision_engines"`), `heading` (string), and a has_many association to `ServiceBullet` (table: `service_bullets`) with columns `service_section_id`, `body` (string), `position` (integer). Content is fully dynamic; the admin form uses nested attributes (`accepts_nested_attributes_for :service_bullets, allow_destroy: true`). This is the most flexible approach — content can grow without code changes.

   **Option B — Locale file with database overrides.** Default content stays in `config/locales/en.yml` (matching current i18n extraction). A generic `ContentOverride` table stores `{ key, value }` pairs that shadow locale keys at render time. The application checks the database first; if no override exists, falls back to the locale file. Less flexible for bullet lists (YAML arrays are awkward as string overrides) but preserves the i18n extraction work done in SPEC-003.

   **Recommendation to architect:** Option A is the cleaner long-term design given that bullet items are variable in count and must be individually editable. Option B introduces impedance mismatch between i18n arrays and string overrides. The architect should confirm or propose an alternative before the developer proceeds.

2. **[NON-BLOCKING] Should the logout action use `DELETE /admin/logout` or `GET /admin/logout`?**

   Rails convention (and Turbo compatibility) favors `DELETE` via a form. However, a simple link to a `GET` logout route is easier to implement without Turbo method spoofing. The spec lists `DELETE` as the default; if the developer encounters Turbo-related issues, a `GET` route is acceptable for this admin-only interface. Resolve at implementation time.

3. **[NON-BLOCKING] Should the admin layout inherit from `ApplicationController` or a separate `Admin::ApplicationController`?**

   Recommend `Admin::BaseController < ApplicationController` (as described in Technical Scope) so that the `allow_browser` and `stale_when_importmap_changes` before-actions in `ApplicationController` still apply. If the architect disagrees, flag before implementation.

4. **[NON-BLOCKING] What is the seeded admin password, and how is it supplied to `db/seeds.rb`?**

   The seed must not commit a password to version control. Proposed approach: read from `ENV["ADMIN_SEED_PASSWORD"]`, raise a descriptive error if the variable is absent. The developer should document this in a `.env.example` file. Doug's actual credentials are communicated out-of-band.

---

## Dependencies

- `bcrypt` gem — required by `has_secure_password`. Confirm it is present in the Gemfile; add if not.
- SPEC-002 (Services Page) remains on hold until this spec is implemented and the architect has answered Open Question #1. SPEC-002 will inherit the data model chosen here.
- SPEC-003 (i18n) is complete — all new admin view strings must follow the same i18n pattern (no hardcoded strings).
