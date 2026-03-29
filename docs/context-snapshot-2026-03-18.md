# Context Snapshot — 2026-03-18

> Full record of decisions made, work completed, and current state as of this session.

---

## Project Overview

**Repository:** `/Users/robertknowles/repos/syndicate_development_2026`
**Goal:** Rebuild www.syndicate-development.com — migrating from Express/React to Rails 8.1.2 MVC
**Original repo (reference):** `/Users/robertknowles/Desktop/DevMtn/Personal-Project/personal-project`

### Stack Decisions

| Concern | Technology | Notes |
|---------|-----------|-------|
| Language / Framework | Ruby 4.0.1 / Rails 8.1.2 | — |
| Database | PostgreSQL | primary, cache, queue, cable (separate DBs in prod) |
| Frontend | ERB views + Tailwind CSS | `tailwindcss-rails` gem, no Node required |
| JS framework | Hotwire (Turbo + Stimulus) | via importmap-rails, no webpack/vite |
| Asset pipeline | Propshaft | not Sprockets |
| Background jobs | Solid Queue | no Sidekiq, no Redis |
| Caching | Solid Cache | — |
| WebSockets | Solid Cable | — |
| Deployment | Kamal | — |
| Style linter | RuboCop | rubocop-rails-omakase |
| Test framework | RSpec + FactoryBot + Capybara + Selenium | replacing default Minitest |

---

## Agent Pipeline

Three Claude Code sub-agents at `.claude/agents/` form a **spec-driven development pipeline**:

```
[Input] → PM Agent → Developer Agent → QA Agent → [Done]
```

| Agent | File | Role | Tools |
|-------|------|------|-------|
| **pm** | `.claude/agents/pm.md` | Writes specs from raw requirements | Read, Write, Edit, Glob, Grep, WebSearch |
| **developer** | `.claude/agents/developer.md` | Implements features + writes RSpec tests | Read, Write, Edit, Glob, Grep, Bash |
| **qa** | `.claude/agents/qa.md` | Runs tests, verifies AC coverage, produces QA report | Read, Glob, Grep, Bash |

### Workflow
```
"pm agent: <requirement>"          → produces docs/specs/SPEC-NNN.md
"developer agent: implement SPEC-NNN"  → produces code + tests
"qa agent: review SPEC-NNN"        → produces QA report, marks spec done or returns failures
```

### Spec Lifecycle
```
draft → ready → in-progress → done
```
All specs in `docs/specs/`. Naming: `kebab-case.md`. IDs: sequential SPEC-NNN.

---

## SPEC-001: Frontend Rebuild

**File:** `docs/specs/frontend-rebuild.md`
**Status:** ready (all open questions resolved)
**Acceptance Criteria:** 18 (16 original + 2 added for contact form)
**Priority:** high

### What's Being Built

A static marketing/portfolio Rails site with four pages:

| Route | Controller#Action | Page |
|-------|------------------|------|
| `GET /` | `pages#home` | Home — hero, mission, CTA |
| `GET /services` | `pages#services` | Services — Engine, Suspension, ECU |
| `GET /about` | `pages#about` | About — bio, slideshow, contact form |
| `GET /gallery` | `pages#gallery` | Gallery — responsive image grid |
| `POST /contact` | `contacts#create` | Contact form handler (no view) |

### Key Design Decisions (resolved this session)

| Question | Decision |
|----------|----------|
| Tailwind integration | `tailwindcss-rails` gem (standalone CLI, no Node) |
| Gallery images | Committed to `app/assets/images/gallery/` ✅ Done |
| Logo + icons | Local files in `app/assets/images/` ✅ Done |
| Hero/slideshow images (Cloudinary-only) | Cloudinary URL placeholders in views; download to local assets as follow-up task |
| Contact form | ActionMailer (`ContactMailer`) → `robknowles105@gmail.com`; `letter_opener` in dev |
| Production SMTP | TBD — separate task before launch |

### Assets Copied (this session)

**`app/assets/images/`** (root — UI elements):
- `syndicate-lion.png` — nav logo
- `icon-photo.png` — gallery icon
- `icon-piston.png` — engine icon
- `icon-suspension.png` — suspension icon
- `icon-wrench.png` — wrench icon

**`app/assets/images/gallery/`** (23 photos):
```
m45a2724 copy.jpg   m45a2724.jpg    m45a2778 copy.jpg   m45a2778.jpg
m45a2803.jpg        m45a2810.jpg    m45a2817 copy.jpg   m45a2817.jpg
m45a2832.jpg        m45a2849.jpg    m45a2920.jpg        m45a2927.jpg
m45a2928.jpg        m45a2930.jpg    m45a2939.jpg        m45a2941.jpg
m45a2950.jpg        m45a2959_1.jpg  m45a2996.jpg        m45a3001.jpg
m45a3012.jpg        m45a3019.jpg    m45a3028.jpg
```

### Cloudinary Images Still Needed (placeholders in views until downloaded)

| Used in | Cloudinary path |
|---------|----------------|
| Home hero | `v1566577213/jhkj9vmgrsuktmrw1y6c.jpg` |
| Home CTA background | `v1566836472/gimrzsuvathl7rcifzgi.jpg` |
| Services header | `v1566976096/go2r7lxyu07igy3rxhul.jpg` |
| Engine section (×3) | `v1566969793/usgqk8ijaxfmz8nlzhes`, `v1566969498/qh8iszlwuou4csyusn9u`, `v1566969498/zhez5grlifejg4mf8nh0` |
| Suspension section (×3) | `v1566976096/go2r7lxyu07igy3rxhul`, `v1566976115/wlmrvpmbo2svm0famqhh`, `v1566918629/fmadjva61pmzoz6l83ei` |
| About slideshow (×3) | `v1570478297/lchkfu4bspgu65uf4o4u`, `v1570478260/lqwrgl3vkocncpvzikow`, `v1570478258/iscbtckkmdofzwlneeqj` |

### Content Carried Over from Original

| Section | Content |
|---------|---------|
| Brand | "SYNDICATE DEVELOPMENT", "Performance, Passion, Precision.", red accent `#db0505`, dark nav `#242121`, Montserrat font |
| Mission copy | "From simple upgrades to full race ready bikes, Syndicate Development is here..." |
| CTA | "READY TO START BUILDING?" + "CONTACT THE SHOP" → `/about` |
| Services | Engine (Dyno, Ignition, Mapping, Valves, Cams), Suspension (Spring Rate, Valving, Conversion Systems, Steering Damper, Holeshot Device), ECU Tuning |
| Bio | Full Doug Haskett paragraph |
| Contact | Phone: 208-251-9536, Address: 1801 N. Arthur Ave., Pocatello ID 83204 (Google Maps link) |

### Test Requirements Summary

| Type | Count | Key Scenarios |
|------|-------|--------------|
| Request specs | 7 | HTTP 200 for all 4 pages, contact POST success/fail |
| System specs | 8 | Hero text, CTA nav, mobile hamburger, gallery grid, services headings, contact form success/fail |
| Model specs | 0 | No models in this phase |

---

## Files Created This Session

```
.claude/
  agents/
    pm.md
    developer.md
    qa.md

app/assets/images/
  syndicate-lion.png
  icon-photo.png
  icon-piston.png
  icon-suspension.png
  icon-wrench.png
  gallery/
    m45a2724 copy.jpg ... (23 files)

docs/
  workflow.md
  context-snapshot-2026-03-18.md   ← this file
  specs/
    README.md
    frontend-rebuild.md            ← SPEC-001 (ready)
```

---

## Remaining Open Items

| Item | Status | Notes |
|------|--------|-------|
| Download Cloudinary hero/service/slideshow images to local assets | ⬜ Follow-up task | Use placeholders in views until done |
| Choose production SMTP provider | ⬜ Pre-launch task | Separate config spec |
| Developer agent: implement SPEC-001 | ⬜ Ready to start | Install Tailwind first |
| QA agent: review SPEC-001 | ⬜ Blocked on developer | — |

---

## Immediate Next Step

Hand SPEC-001 to the developer agent:

> "developer agent: implement SPEC-001 — start with: (1) add `tailwindcss-rails` and `letter_opener` gems, (2) scaffold `PagesController` + `ContactsController` + routes, (3) build the application layout + nav partial, then implement each page view."
