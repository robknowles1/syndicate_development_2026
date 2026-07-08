# Task Management Standard

> How tasks are created, sized, and tracked.
> Read after: `spec-driven-development.md`, `workflow-phases.md`

## Core Principle

Specs define behavior. Tasks track execution. Tasks cannot define new behavior — only implement behavior from specs.

## The Flow

```
Brainstorm → Spec Map → Detail Spec → Break into Tasks → Implement → Verify
```

See `workflow-phases.md` for the full flow description.

## Task Sizing

### The Rule

Each task delivers **one testable behavior**. If a task would produce a PR over ~200 LOC, decompose it further before starting implementation.

### Sizing Guidelines

- A task should be completable in a single focused session.
- One task = one PR. Do not bundle multiple tasks into a single PR.
- If you can't describe what the task tests in one sentence, it's too big.
- When in doubt, make it smaller.

### Decomposition Process

1. Start with the spec's Acceptance Criteria (AC-#).
2. For each AC, identify the smallest testable behavior that proves the AC works.
3. If an AC requires multiple behaviors (e.g., "user can create and edit profiles"), split into separate tasks.
4. Derive 2-3 tasks at a time. Implement them before deriving the next batch.
5. Early implementation often reveals that later tasks need different boundaries — this is expected.

### Task Sizing Is Not Just LOC

~200 LOC is a forcing function, not a strict limit. The real criteria:

- **One verifiable behavior** per task (primary rule)
- **Under ~200 LOC** per PR (guideline)
- **Low churn** — if PRs consistently get rewritten within 2-4 weeks, specs weren't tight enough

Track churn rate as the health metric, not just LOC.

## Task ↔ Spec Relationship

- Every task/PR references which AC-# IDs it implements (see `version-control-standards.md` commit trailer format).
- The link is one-directional: tasks point to spec ACs. Specs do not reference issue/task numbers.
- Tasks cannot introduce behavior not defined in a spec. If new behavior is needed, update the spec first.

## Implementation Decisions

Decisions made during implementation that affect the spec should be:

1. Recorded in the spec's Implementation Decisions section.
2. Noted in the PR description.
3. This prevents context loss between sessions.
