# Standards — Reading Guide

Standards are organized in three tiers.

## Tier 1 — Foundation (read these first, they govern everything)

| File | What It Defines |
|------|----------------|
| `spec-driven-development.md` | The core contract: specs are truth |
| `quality-gates.md` | What must pass before merge |

## Tier 2 — Workflow (read what's relevant to your current work)

| File | When You Need It |
|------|-----------------|
| `workflow-phases.md` | The development lifecycle: Brainstorm → Spec → Tasks → Implement → Verify |
| `task-management.md` | When creating or sizing tasks |
| `version-control-standards.md` | When committing or reviewing commits |
| `handoff-lifecycle.md` | Done checklist: what to verify before PR, QA, and review |
| `naming-conventions.md` | When you need to look up an ID format |

## Tier 3 — Reference (consult as needed)

| File | When You Need It |
|------|-----------------|
| `practices/` | Engineering practice files — read the relevant file for your task |
| `engineering-practices-index.md` | Quick reference to practice files |
| `agent-configuration.md` | Creating or modifying agent YAML frontmatter |

## One Sentence Each

If you only have 60 seconds:
- **Specs are truth.** Agents follow specs, never invent behavior.
- **Developers drive.** No orchestrated pipeline — one agent per task, cherry-picked as needed.
- **Quality gates block merge.** No evidence = no merge.
- **Done checklist before PR.** Verify ACs addressed, tests pass, spec updated.
- **One testable behavior per PR.** Target under ~200 LOC.
- **Humans merge.** Agents never merge PRs.
