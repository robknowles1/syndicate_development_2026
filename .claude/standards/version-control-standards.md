# Version Control Standards

> Commit message format, branch naming, and PR standards.

## Git Commit Message Policy

Based on [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).

### Format

```
<type>[(scope)][!]: <description>

[optional body]

[optional footer(s)]
```

### Type (Required)

| Type | When to use |
|------|-------------|
| `feat` | New functionality |
| `fix` | Bug fix |
| `refactor` | Code restructuring, no behavior change |
| `test` | Adding or updating tests only |
| `docs` | Documentation only |
| `chore` | Build, tooling, dependency updates |
| `ci` | CI/CD pipeline changes |
| `perf` | Performance improvement, no behavior change |
| `style` | Formatting, whitespace — no logic change |

### Scope (Optional)

A noun in parentheses describing the affected section: `feat(auth):`, `fix(parser):`.

### Breaking Changes

- Append `!` after the type/scope to flag a breaking change: `feat(api)!: remove v1 endpoints`.
- Include a `BREAKING CHANGE:` footer with a description of the impact.

### Description Rules

- Use imperative mood: "add", "fix", "refactor" (not "added", "fixes")
- Lowercase the first letter
- No trailing period
- Soft limit: 50 characters total. Hard limit: 72 characters.

### Body Rules

- Separate subject from body with a blank line
- Wrap body at 72 characters
- Explain **why** the change was made, not what

### Footer Rules

Standard footers:

- `Spec: SPEC-###` — link to the governing spec
- `AC: AC-1, AC-2` — acceptance criteria addressed
- `BREAKING CHANGE: <description>` — required when `!` is used
- `Co-Authored-By:` — attribution when applicable

### Good Examples

```
feat(auth): add login endpoint skeleton

Implement POST /api/auth/login with request validation.
Returns 501 until credential logic is added in the next slice.

Spec: SPEC-003
AC: AC-1
```

```
fix(auth): correct session token expiry off-by-one

The expiry comparison used `>` instead of `>=`, allowing
tokens to be valid for one second past their TTL.

Spec: SPEC-003
AC: AC-4
```

### Bad Examples

- `fixed stuff` — missing type, no context
- `feat: Updated the login controller and changed the test` — past tense, narrates code
- `feat: add auth system, session management, and logout` — multiple changes in one commit

## PR Title Format

PR titles follow the same conventional commits format as commit subjects.

```
<type>[(scope)][!]: <description>
```

Rules:
- Same type, scope, and description rules as commit messages.
- No issue IDs in the title. Reference these in the PR body.

## Branch Naming Convention

Format: `{type}/{short-description}`

Examples:
```
feat/add-auth
fix/login-redirect
chore/upgrade-rails
refactor/extract-auth-service
docs/api-usage-guide
```

Optional, when work is tied to a GitHub issue: `{type}/{issue-number}-{short-description}` (e.g. `feat/142-status-page`). See `naming-conventions.md` § 2.

Rules:
- Always branch from `main`
- No uppercase letters
- Kebab-case, 2-4 words for the description

## PR Size and Scope Policy

- Target: 1-3 commits per PR, narrowly scoped to a single spec slice
- Soft guideline: under 300 LOC of meaningful change — a forcing function to keep PRs to one testable behavior, not a hard rule
- Hard threshold: PRs over ~500 LOC require a **PR Slicing Plan** justifying why they cannot be split
- Mega PRs (multiple features, multiple spec slices, or cross-cutting concerns) are prohibited

## PR Slicing Plan

When work spans more than one logical change:

1. List each logical slice with its spec/AC references
2. Define the commit/PR boundary for each slice
3. Identify ordering dependencies between slices

## Merge Gate

- **Only humans merge.** Agents never run `gh pr merge`.
- PR must be marked ready for review (not draft) by a human before merging.

## Task Sizing: Fibonacci Complexity Points

### Allowed Values

1, 2, 3, 5, 8, 13 (Fibonacci sequence).

### What Points Represent

Points measure **complexity, risk, and unknowns** — not time.

| Points | Meaning |
|--------|---------|
| 1 | Trivial change, well-understood, minimal risk |
| 2 | Small change, clear approach, low risk |
| 3 | Moderate change, some moving parts, manageable risk |
| 5 | Significant complexity or unknowns; **must be reviewed for splitting** |
| 8 | High complexity; **must be split** unless explicitly accepted with documented rationale |
| 13 | Epic-level; **always split** into smaller tasks |

### Splitting Rule

- Tasks estimated at **5 points**: review and decide whether to split before starting.
- Tasks estimated at **8+ points**: split into smaller tasks before work begins.
- If splitting is not possible, document the rationale and accept the risk in the spec or PR description.

## Complexity Escalation Loop

When `/developer` discovers during implementation that a task is more complex than estimated, or scope is creeping:

### Escalation Steps

1. **Pause** — Stop implementation at the smallest safe checkpoint. Commit work done so far.
2. **Report** — Write a Complexity Report documenting:
   - What was discovered (unknowns, risks, dependencies).
   - Why the task is larger than expected.
   - What has been completed so far.
   - Suggested breakdown if apparent.
3. **Hand back** — Return the task to `/pm` for triage.
4. **Optional gates** — `/pm` may pull in `/architect` for architecture-driven complexity or `/ux` for product/UX-driven complexity.
5. **Resume** — Work resumes only after `/pm` produces an updated task breakdown and documents the triage decision.

### Quality Gate

No agent may continue work on an over-complex task without a documented `/pm` triage decision. Continuing without triage is a blocking violation.
