# Engineering Practices Index

> Redirect — engineering practices are split into individual files.
> Read when: you need technical rules for a specific domain.

Engineering practices are split into individual files in `.claude/standards/practices/`.

## Quick File Reference

| File | Content | Relevant Roles |
|------|---------|----------------|
| `practices/architecture.md` | Layering, service objects, query objects, presenters, background jobs | developer, reviewer |
| `practices/coding-style.md` | Linter enforcement, language conventions, comment discipline | developer, reviewer |
| `practices/testing.md` | Test structure (AAA), mocking, assertions, inline variables only | developer, qa, reviewer |
| `practices/naming.md` | Naming conventions for services, queries, jobs, presenters, factories, tests | developer, reviewer |
| `practices/readme-standards.md` | Required README sections, dev paths, package tables | developer, scribe, reviewer |
| `practices/deployment-strategy.md` | Deployment patterns, environment tiers, secrets, rollback | developer, devops, reviewer |

Stack-specific rules (e.g. Rails request-spec policy) live in `agents/stacks/<stack>/` overlays, not here — this index only covers stack-agnostic practices.

## Related Standards (Separate Files)

| Standard | File |
|----------|------|
| Spec-Driven Development | `spec-driven-development.md` |
| Quality Gates | `quality-gates.md` |
| Workflow Phases | `workflow-phases.md` |
| Task Management | `task-management.md` |
| Version Control | `version-control-standards.md` |
| Done Checklist | `handoff-lifecycle.md` |
| Naming Conventions | `naming-conventions.md` |
| Agent Configuration | `agent-configuration.md` |

All files are in `.claude/standards/`.
