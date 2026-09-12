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
| SPEC-007 | About Page Content Editing — Admin-Managed Shop Info and Bio Copy | ready | medium | [SPEC-007-about-page-content-editing.md](SPEC-007-about-page-content-editing.md) (merged via PR #38, `feature/spec-007-about-page-editable`, 2026-07-17) |
| SPEC-008 | Gallery Photo Management — Admin CRUD | ready | medium | [SPEC-008-gallery-photo-management.md](SPEC-008-gallery-photo-management.md) |
| SPEC-009 | About Slideshow Image Uploads | ready | medium | [SPEC-009-about-slideshow-image-uploads.md](SPEC-009-about-slideshow-image-uploads.md) (its SPEC-008 and SPEC-007/PR#38 blockers both landed on `main`; SPEC-009 itself merged via PR #43, 2026-07-28) |
| SPEC-010 | Email Delivery — Resend Wiring and Staging Environment | done | high | *No spec file — delivered directly via PR #47, merged to `main`* |
| SPEC-011 | Admin Authentication — Invite-Only Accounts, Password Reset, Auth Hardening | done | high | *No spec file — delivered directly via PR #48, merged to `main`* |
| SPEC-012 | SEO/AEO Pass — Structured Data, Metadata, FAQ, and Contact Form Hardening | ready | high | [SPEC-012-seo-aeo.md](SPEC-012-seo-aeo.md) (merged via PR #58, `feature/spec-012-seo-aeo`, 2026-08-05; implementation landed across PR #61-#64, last merged 2026-08-06) |
| SPEC-013 | Home Page Hero and CTA Image Uploads — Admin-Replaceable Background Images | ready | medium | [SPEC-013-home-hero-cta-image-uploads.md](SPEC-013-home-hero-cta-image-uploads.md) |
| SPEC-014 | Social Media Links — Admin-Managed Profile Icons | ready | medium | [SPEC-014-social-media-links.md](SPEC-014-social-media-links.md) |
| SPEC-016 | Client-Side Upload Guards for Admin Image Inputs | ready | medium | [SPEC-016-client-side-upload-guards.md](SPEC-016-client-side-upload-guards.md) (builds on SPEC-013's `MAX_IMAGE_SIZE` and `padded_jpeg_upload` test helper) |
| SPEC-017 | Production Deployment, Domain Migration and Backups | ready | high | [SPEC-017-production-deployment-domain-migration-backups.md](SPEC-017-production-deployment-domain-migration-backups.md) (runbook: 7 sequenced phases executed against the live OVH box; cross-references [`docs/deployment/ovh-server-access.md`](../deployment/ovh-server-access.md)) |

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

## Change Log

| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
| 2026-09-11 | Added the SPEC-017 index row (Production Deployment, Domain Migration and Backups). Note the numbering gap: SPEC-015 was never allocated, and IDs are never reused. | SPEC-017 (Index) | New spec. |
| 2026-09-11 | Corrected the SPEC-007 and SPEC-012 index rows, which claimed open, unmerged PRs/branches. SPEC-007 merged via PR #38 on 2026-07-17. SPEC-012 merged via PR #58 (the spec's own docs branch) on 2026-08-05, with implementation landing across PR #61-#64 by 2026-08-06. Also updated the SPEC-009 row, whose "blocked on SPEC-008 and SPEC-007/PR#38" note was stale on both counts — both blockers landed, and SPEC-009 itself merged via PR #43 on 2026-07-28. | SPEC-007, SPEC-009, SPEC-012 (Index) | These rows were left unedited after the PRs they described merged, so the index told a developer three landed specs were still pending review. Statuses (`ready`/`done`) are intentionally left untouched here — that column is the QA agent's call, not this correction's. |
