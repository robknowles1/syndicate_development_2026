# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview

<!-- TODO: one paragraph — what this project does and who it is for -->

## Stack

<!-- TODO: fill in your stack -->
- Language/Framework:
- Database:
- Frontend:
- Styling:
- Testing:
- Deployment:

## Key Commands

```bash
# Start development server
# TODO

# Run tests
# TODO

# Run linter
# TODO

# Deploy
# TODO
```

## Agent Workflow

This project uses the Claude Playbook agent system. Recommended workflow:

```
pm → architect (if complex) → developer → reviewer → qa
                                    ↑_______________|
                                    (fix and re-review)
```

| Agent | When to use |
|-------|-------------|
| `pm` | Translating requirements into specs (`docs/specs/`) |
| `architect` | Complex features, new data models, system-wide decisions |
| `developer` | Implementing a ready spec, writing tests |
| `reviewer` | Code review before QA |
| `qa` | Verifying tests pass and spec is satisfied |
| `devops` | CI/CD, deployment, environment configuration |
| `scribe` | Keeping documentation and changelogs current |
| `security` | Auditing security-sensitive features |

## Conventions

<!-- TODO: project-specific conventions not covered by the agents -->

## Architecture Notes

<!-- TODO: anything non-obvious about this project's design -->
<!-- See docs/architecture/ for ADRs -->
