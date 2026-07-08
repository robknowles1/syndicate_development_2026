# Spec-Driven Development Standard

> The foundational contract. Every agent, every workflow, every quality gate traces back to this.

## Non-Negotiable Rules

1. Specs are the source of truth.
2. Agents cannot invent behavior not in the spec.
3. Tests and code must trace to spec sections.

## Required Repository Structure

- `docs/specs/` contains feature specs and the canonical spec template.
- `.claude/ai/agent-rules.md` contains deterministic agent execution rules (optional, project-level).

## Required Agent Loop

1. Read relevant spec file(s) before planning implementation.
2. Extract `Goal`, `Interfaces`, `Rules`, and `Acceptance Tests`.
3. Generate tests from acceptance criteria.
4. Implement the minimal code required to satisfy tests.
5. Validate implementation behavior against numbered spec rules.
6. Report any rule lacking acceptance-test coverage.

## Ambiguity Policy

If spec language is ambiguous, incomplete, or contradictory, stop and request clarification before coding.

## Traceability Contract

- Rules use stable IDs (`R1`, `R2`, ...).
- Edge cases use stable IDs (`E1`, `E2`, ...).
- Acceptance tests use stable IDs (`AT1`, `AT2`, ...).
- Acceptance criteria use stable IDs (`AC-1`, `AC-2`, ...).
- Acceptance tests include a `Covers:` field that references one or more rule IDs.

See `naming-conventions.md` for the complete ID format reference.

## Traceability Chain

```
Spec (AC-#) → PR references AC-# → Tests cover R#/E#
```

- PRs reference AC-# IDs in the description.
- Commits reference spec and AC IDs in the body.
- Tests map to R# and E# via the `Covers:` field.

## Spec-Task Relationship

- Specs define behavior. Tasks track execution.
- Developers own task breakdown. Each task delivers one testable behavior, targeting under ~200 LOC.
- Tasks cannot define new behavior — only implement behavior from specs.

## Spec Update Discipline

Specs are living documents. Update them as implementation reveals new information:

1. **Acceptance test IDs must map to runnable tests.** When a test changes, the spec AC that owns it gets updated in the same PR.
2. **Implementation decisions are recorded.** Use the spec's Implementation Decisions section.
3. **Additive changes are allowed** at any time.
4. **Modifications to in-progress ACs require developer notification.**
5. **Deletions of implemented ACs require documented rationale** in the spec's Change Log.

## Spec Mutability Change Log

After implementation begins, append changes to the spec:

```markdown
## Change Log
| Date | Change | Affected IDs | Rationale |
|------|--------|-------------|-----------|
```

## Design Docs and Formal Specs

Exploratory design documents are not canonical specs. They must be promoted to formal specs in `docs/specs/` before implementation begins.

The promotion path: exploratory draft → formal spec in `docs/specs/`. The spec agent or developer reviews the design doc and produces the canonical spec with numbered rules (R#), acceptance criteria (AC-#), and acceptance tests (AT#).

Traceability always starts from `docs/specs/`.
