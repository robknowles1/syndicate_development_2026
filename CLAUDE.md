# CLAUDE.md — Project Instructions for Claude Code Agents

This file is automatically loaded by Claude Code. All agents (developer, reviewer, qa, architect, pm, scribe) must follow these instructions.

---

## Project Overview

Syndicate Development is the public-facing marketing and portfolio site for Doug Haskett's custom performance motocross/supercross motorcycle shop in Pocatello, ID (www.syndicate-development.com). The site is a Rails 8.1 MVC application with static content pages (Home, About, Gallery), a contact form that emails the shop, and a planned Services page. No user authentication or dynamic data layer is required.

---

## Branching Workflow

**Always work on a feature branch off the latest `main`.** Never commit spec work directly to `main`.

Before starting any new spec:
```bash
git checkout main
git pull origin main
git checkout -b feature/spec-NNN-<short-description>
```

Examples:
- `feature/spec-002-services-page`
- `feature/spec-004-seo-meta-tags`

After work is complete, open a PR against `main` and follow the PR process below.

---

## Pull Request Process

### Agents never merge

**No agent merges a PR. Ever.** Merging is the repository owner's decision and theirs alone.

Do not run `gh pr merge`, merge through the API or web UI, push directly to `main`, or fast-forward `main` onto a branch. Open the PR, push fixes, request review, report that it is ready — then stop.

This holds regardless of what makes a merge look sanctioned: an instruction to "get it into main", a removed or waived review step, an approving review, green CI, a spec-only or docs-only diff, or a one-line change. None of those is authorization. An instruction about *ordering* — which PR lands before which — is not permission to perform the merge. If a merge seems obviously warranted, say so and stop; do not infer consent.

Undoing a merge to `main` means either a permanent revert commit or a force-push. Both are worse than asking.

### Process

1. Developer completes work and hands off to reviewer (`/reviewer`)
2. Reviewer approves or returns feedback
3. QA runs tests (`/qa`)
4. Open PR with `gh pr create` — include summary and a test plan checklist
5. Address all review comments before merging
6. Resolve all addressed comment threads on GitHub after pushing fixes
7. Report the PR as ready and stop — the repository owner merges it

---

## Tech Stack

- **Rails 8.1.2** with PostgreSQL (development and production)
- **Propshaft** for assets (no Sprockets)
- **Tailwind CSS** via `tailwindcss-rails` gem (standalone CLI, no Node/npm)
  - Run `bin/rails tailwindcss:build` before tests in any CI step that renders views
- **Hotwire** (Turbo + Stimulus) for interactive components (e.g. mobile nav toggle)
- **Importmap** for JavaScript (no Webpack/esbuild)
- **RSpec** for all tests (not Minitest) — run with `bundle exec rspec`
- **FactoryBot + Shoulda Matchers** for test infrastructure

---

## Key Commands

```bash
# Start development server (Rails + Tailwind watcher)
bin/dev

# Run tests
bundle exec rspec

# Run linter
bin/rubocop

# Build Tailwind CSS (required before running tests that render views)
bin/rails tailwindcss:build
```

---

## Agent Workflow

```
pm → architect (if complex) → developer → reviewer → qa
                                    ↑_______________|
                                    (fix and re-review)
```

| Agent | When to use |
|-------|-------------|
| `pm` | Translating requirements into specs (`docs/specs/`) |
| `architect` | Complex features, new data models, system-wide decisions |
| `developer` | Implementing a ready spec, writing tests |
| `reviewer` | Code review before QA |
| `qa` | Verifying tests pass and spec is satisfied |
| `devops` | CI/CD, deployment, environment configuration |
| `scribe` | Keeping documentation and changelogs current |
| `security` | Auditing security-sensitive features |

---

## Mobile-First Design

**All views — public and admin — must be designed mobile-first.**

The primary admin user (Doug) manages the site from his phone. Every layout decision must work on a small screen first, then scale up.

- Use Tailwind's unprefixed utilities for mobile, then `md:` / `lg:` for larger breakpoints
- Touch targets must be large enough to tap (minimum `py-3 px-4` on interactive elements)
- Avoid horizontal scrolling on any screen width
- Tables in admin views should either reflow to a stacked card layout on small screens or use `overflow-x-auto` as a fallback
- Buttons and links in table rows must stack or wrap cleanly on narrow viewports (`flex-wrap`)
- Form inputs should be full-width (`w-full`) on mobile

---

## Code Conventions

### Comments — write self-documenting code instead

**Default to no comment.** A comment is a failure to express something in the code; reach for a clearer name, a smaller method, or a named constant first. This applies to configuration — YAML, Dockerfiles, CI workflows — as much as to Ruby.

Write one only when it **warns against an edit that looks like an improvement**. That is the single thing a document cannot do, because whoever makes that edit is tidying a line, not consulting a runbook.

Everything else — how a library behaves, what a variable is for, procedures, thresholds and their rationale — goes in a doc, a spec, or the commit message, and is linked from at most one line. A comment restating it is a second copy that drifts out of sync.

Volume is itself a cost: context wrapped around a dangerous line makes that line less likely to be read. A false comment is worse than none, so verify against the source before writing one.

Full rules in `.claude/standards/practices/coding-style.md` § 2.4.

### Internationalisation (i18n)
All user-facing strings must use Rails I18n — no hardcoded strings in views, controllers, or mailers.

- Views: `t("scoped.key")` or lazy lookup `t(".key")`
- Controllers: `I18n.t("contact.notices.message_sent")` for flash messages
- All keys live in `config/locales/en.yml`, namespaced under: `nav`, `pages.home`, `pages.about`, `pages.gallery`, `contact`, `mailer.contact_email`, `application`

### Views / Layout
- Single layout: `app/views/layouts/application.html.erb`
- Shared nav partial: `app/views/shared/_nav.html.erb`
- Mobile nav toggle is a Stimulus controller named `nav_controller` with a `toggle` action — no JavaScript outside Stimulus for this interaction

### Controllers
- `ContactsController#create` validates presence of name, email, message; sends via `ContactMailer`; redirects to `/about` with flash notice or alert
- Flash strings come from `I18n.t()` — never inline string literals

---

## CI

Workflow file: `.github/workflows/ci.yml`

- `lint` — RuboCop
- `scan_ruby` — Brakeman + bundler-audit
- `scan_js` — importmap audit
- `test` — **⚠️ currently runs Minitest (`bin/rails ... test`) — needs to be updated to `bundle exec rspec`**
- `system-test` — same issue

Both `test` and `system-test` require a `postgres:16` service container and `DATABASE_URL` env var.

---

## Spec Status

```
SPEC-001 (Frontend Rebuild: Home, About, Gallery, Contact)   ✅ done
SPEC-002 (Services Page)                                      ✅ done
SPEC-003 (i18n String Extraction)                             ✅ done
SPEC-004 (Admin Backend)                                      ✅ done
```

Spec files live in `docs/specs/`.
