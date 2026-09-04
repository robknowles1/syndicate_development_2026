# Specs

This directory contains feature specs produced by the PM agent following the spec-driven development model.

## Index

| ID       | Feature | Status | Priority | File |
|----------|---------|--------|----------|------|
| SPEC-001 | Frontend Rebuild — Marketing/Portfolio Site | done | high | [frontend-rebuild.md](frontend-rebuild.md) |
| SPEC-002 | Services Page — Dynamic Content with Admin CRUD | ready | medium | [services-page.md](services-page.md) |
| SPEC-003 | i18n String Extraction | ready | medium | [i18n-string-extraction.md](i18n-string-extraction.md) |
| SPEC-004 | Admin Backend — Authentication and Services Page Management | done | high | [admin-backend.md](admin-backend.md) |
| SPEC-005 | Icon Library Migration — Heroicon to Tabler Icons | ready | medium | [SPEC-005-icon-library-migration.md](SPEC-005-icon-library-migration.md) |
| SPEC-006 | Home Page Content Editing — Admin-Managed Hero and Mission Copy | done | medium | [SPEC-006-home-page-content-editing.md](SPEC-006-home-page-content-editing.md) |
| SPEC-007 | About Page Content Editing — Admin-Managed Shop Info and Bio Copy | ready | medium | [SPEC-007-about-page-content-editing.md](SPEC-007-about-page-content-editing.md) (open PR #38, branch `feature/spec-007-about-page-editable`, not yet merged to `main`) |
| SPEC-008 | Gallery Photo Management — Admin CRUD | ready | medium | [SPEC-008-gallery-photo-management.md](SPEC-008-gallery-photo-management.md) |
| SPEC-009 | About Slideshow Image Uploads | ready | medium | [SPEC-009-about-slideshow-image-uploads.md](SPEC-009-about-slideshow-image-uploads.md) (blocked on SPEC-008 and SPEC-007/PR#38 landing on `main`) |
| SPEC-010 | Email Delivery — Resend Wiring and Staging Environment | done | high | *No spec file — delivered directly via PR #47, merged to `main`* |
| SPEC-011 | Admin Authentication — Invite-Only Accounts, Password Reset, Auth Hardening | done | high | *No spec file — delivered directly via PR #48, merged to `main`* |
| SPEC-012 | SEO/AEO Pass — Structured Data, Metadata, FAQ, and Contact Form Hardening | ready | high | [SPEC-012-seo-aeo.md](SPEC-012-seo-aeo.md) (branch `feature/spec-012-seo-aeo`, not yet merged to `main`) |
| SPEC-013 | Home Page Hero and CTA Image Uploads — Admin-Replaceable Background Images | ready | medium | [SPEC-013-home-hero-cta-image-uploads.md](SPEC-013-home-hero-cta-image-uploads.md) |
| SPEC-014 | Social Media Links — Admin-Managed Profile Icons | ready | medium | [SPEC-014-social-media-links.md](SPEC-014-social-media-links.md) |
| SPEC-015 | Nav Bar Logo — Admin-Replaceable Site Branding | ready | medium | [SPEC-015-nav-logo-image-upload.md](SPEC-015-nav-logo-image-upload.md) (depends on research finding [SPEC-015-research-logo-transparency-conversion.md](SPEC-015-research-logo-transparency-conversion.md)) |

*(Update this table as specs are added.)*

## Status Lifecycle

```
draft → ready → in-progress → done
```

- **draft** — PM agent created the spec; acceptance criteria may be incomplete.
- **ready** — Spec is complete and unambiguous; developer agent can start.
- **in-progress** — Developer agent is implementing.
- **done** — QA agent has signed off; all tests pass.

## Naming Convention

Files: `docs/specs/<kebab-case-feature-name>.md`
IDs: `SPEC-001`, `SPEC-002`, ... (sequential, never reused)

## Agent Roles

| Agent | Responsibility |
|-------|---------------|
| `pm` | Creates and owns specs; sets status to `ready` |
| `developer` | Implements from spec; sets status to `in-progress` → writes tests |
| `qa` | Verifies against spec; sets status to `done` on sign-off |
