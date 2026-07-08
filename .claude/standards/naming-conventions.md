# Naming Conventions

> Reference for all ID and naming patterns used across specs, tasks, commits, and code.
> Read when: you need to look up an ID format.

## 1. Spec IDs

| ID Type | Format | Purpose |
|---------|--------|---------|
| Rule | R# | Numbered system behavior rules (R1, R2, R14) |
| Edge Case | E# | Numbered edge-case scenarios (E1, E2) |
| Acceptance Test | AT# | Numbered test scenarios with Given/When/Then (AT1, AT2) |
| Acceptance Criterion | AC-# | Numbered observable outcomes for stakeholder verification (AC-1, AC-2) |

Rules are sequential within a spec file. IDs are stable — do not renumber after implementation begins.

## 2. Branch and PR Naming

- Spec filenames use kebab-case matching the feature name: `docs/specs/{feature}.md`.
- Branch naming default: `{type}/{short-description}` (see `version-control-standards.md`).
- Optional, when work is tied to a GitHub issue: `{type}/{issue-number}-{short-description}`
  (e.g. `feat/142-status-page`). There is no Jira ID segment — this repo is GitHub-only.
- GitHub PR references: `#N` (e.g. `#123`).

## 3. Commit Message Format

```
<type>[(scope)][!]: <description>

<body>

Spec: SPEC-###
AC: AC-1, AC-2
```

Full policy: `.claude/standards/version-control-standards.md`.

## 4. Code Naming

Code naming conventions (variable, function, class, file naming) are defined in the practices naming file: `.claude/standards/practices/naming.md`.

## 5. Quick Reference

| ID Type | Format | Example |
|---------|--------|---------|
| Rule | R# | R1, R2, R14 |
| Edge Case | E# | E1, E2 |
| Acceptance Test | AT# | AT1, AT2 |
| Acceptance Criterion | AC-# | AC-1, AC-2 |
| GitHub PR | #N | #123 |
| Spec file | docs/specs/{feature}.md | docs/specs/rename-folder.md |
| Branch (default) | {type}/{short-description} | feat/status-page |
| Branch (issue-linked) | {type}/{issue-number}-{short-description} | feat/142-status-page |
