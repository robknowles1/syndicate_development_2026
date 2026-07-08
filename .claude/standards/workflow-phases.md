# Workflow Phases

> Developers drive the workflow. Agents assist at each phase.

## The Flow

```
Brainstorm (developer + Claude, structured questions session)
  → Spec Map (thin outline of all features + dependencies)
      → Detail Spec (one at a time, full R#/E#/AC-#/AT#)
          → Break into Tasks (each = one testable behavior, ~200 LOC)
          → Implement (2-3 tasks at a time, TDD)
          → Verify (done checklist, tests pass)
      → Next Spec...
```

## Phase Descriptions

### 1. Brainstorm

Run a structured questions session against the feature idea or issue with Claude before writing any specs. The goal is to surface unstated requirements, edge cases, and architectural concerns.

Key mechanic: have the AI ask *you* questions about the request rather than trying to anticipate everything yourself.

### 2. Spec Map

Before detailing any single spec, sketch all specs needed in a thin outline. Note dependencies between specs. This is disposable — its job is dependency visibility, not documentation.

### 3. Detail Spec

Expand one spec at a time to full detail: Goal, Rules (R#), Edge Cases (E#), Acceptance Criteria (AC-#), Acceptance Tests (AT#). Get it reviewed before breaking into tasks.

### 4. Break into Tasks

Each task delivers one testable behavior. Target under ~200 LOC per PR. Derive 2-3 tasks at a time, not all upfront. Early implementation informs later task breakdown.

Tasks/PRs reference which AC-#s they implement. The link is one-directional: task → spec.

### 5. Implement

TDD: write failing test, implement minimal code, verify. Follow the done checklist before opening each PR. Update specs with implementation decisions as they're made.

### 6. Verify

Before claiming done:
- Run tests, lint, typecheck
- Walk the done checklist (see `handoff-lifecycle.md`)

## Rules

1. **One spec at a time.** Don't detail all specs before starting implementation.
2. **2-3 tasks at a time.** Don't break an entire spec into tasks upfront.
3. **Update specs as you go.** Stale specs cause agent drift.
4. **Acceptance test IDs must map to runnable tests.** When a test changes, update the owning AC in the same PR.
5. **Track churn as the health metric.** If PRs get rewritten within 2-4 weeks, investigate spec quality.
