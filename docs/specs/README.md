# Specs

This directory contains feature specs produced by the PM agent following the spec-driven development model.

## Index

| ID       | Feature | Status | Priority | File |
|----------|---------|--------|----------|------|
| SPEC-001 | Frontend Rebuild — Marketing/Portfolio Site | ready | high | [frontend-rebuild.md](frontend-rebuild.md) |
| SPEC-002 | Services Page | draft | medium | [services-page.md](services-page.md) |

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
