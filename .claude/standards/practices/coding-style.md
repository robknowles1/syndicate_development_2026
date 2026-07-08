# Coding Style Rules

> Linter enforcement, language-specific conventions.
> Read when: writing or reviewing any code

### 2.1 Linter-Enforced Style

Every project must have a linter configuration checked into the repo. Style rules are enforced by tooling, not convention alone.

Rules:
- All lint exceptions must be declared in config files, not scattered as inline suppression comments.
- Metric limits (method length, complexity, class size) are kept enabled.
- New projects adopt the strictest feasible defaults and relax intentionally.

**Ruby**: RuboCop with `rubocop-rails` minimum. Add `rubocop-rspec` and `rubocop-capybara` for new projects.

Mandatory Ruby style settings:

| Rule                              | Setting                            |
| --------------------------------- | ---------------------------------- |
| String literals                   | Single quotes                      |
| Method chain line breaks          | Leading dot                        |
| Boolean operators in conditionals | `&&`/`\|\|` (not `and`/`or`)      |
| Multiline call indentation        | Indented                           |

**TypeScript**: ESLint with shared config packages, extended from `eslint:recommended` and `prettier`.

Mandatory TypeScript settings:

| Rule              | Setting                                  |
| ----------------- | ---------------------------------------- |
| Type definitions  | `type` keyword (not `interface`)         |
| Strict mode       | `strict: true`, `strictNullChecks: true` |
| Type imports      | `import type { X } from "..."`           |
| Module resolution | `NodeNext`                               |

### 2.2 No Whitespace Alignment

Do not use extra whitespace to vertically align values, attributes, or assignments.

**Wrong:**
```ruby
short_name  = 'foo'
longer_name = 'bar'
```

**Right:**
```ruby
short_name = 'foo'
longer_name = 'bar'
```

### 2.3 Language-Specific Conventions

**Ruby:**
- Memoize expensive computations: `@var ||= ...`
- Use `options.fetch(:key, default)` for required/optional parameters
- Use `Struct` for lightweight return types. Freeze all constant collections.
- In tests, use `described_class` instead of repeating the class name.

**TypeScript:**
- Explicit return types on all exported functions.
- Union types for domain variants; discriminated unions when appropriate.
- `const` arrow functions for module-level functions.
- Optional chaining (`?.`) and nullish coalescing (`??`) over manual null checks.
- Factory functions for test data: `const makeRecord = (args?: Partial<T>): T => ({ ...defaults, ...args })`

### 2.4 Comments

**Specs are the source of truth. Comments are not a place to duplicate them.**

Do not restate what the code does — well-named identifiers already do that. Do not paraphrase acceptance criteria, spec rules (R#), or task descriptions in the code. If a reader needs to know the rule, they read the spec. If the code drifts from the spec, we do not want two copies to keep in sync.

**Only write a comment when the WHY is non-obvious:**

- A hidden constraint the code cannot express (e.g. "batch size capped at 500 — Postgres query planner regresses past this").
- A workaround for a specific bug in an upstream library or platform (link the issue).
- A subtle invariant a future editor could break without noticing (e.g. "order matters — `apply_tax` must run before `apply_discount` per R14").
- Behavior that would surprise a reader with the domain knowledge already assumed by the file.

If removing the comment would not confuse a competent reader who has read the spec, do not write it.

**Never write:**

- Comments that narrate the next few lines (`# Set the user's name`, `# Loop through orders`). The code says this.
- Comments that reference the current task, ticket, or PR (`# Added for issue #215`, `# Handles the case from ticket #123`). Those belong in the commit message and PR description. In the code they rot as ownership and context change.
- Multi-line commentary blocks that reproduce spec text, AC lists, or ticket descriptions. Reference the spec ID (R# / AC-#) in the commit trailer instead.
- Section banner comments (`# ============ SETUP ============`). If a file needs section banners it needs to be split.
- Commented-out code. Delete it. Version control is the archive.

**Test files follow the same rule, with one exception:** the AAA structure comments (`# Arrange`, `# Act`, `# Assert`) required by `practices/testing.md` § 3.1 are mandated. Everything above still applies to any other comments in test files.
