# Development Workflow

This project uses a three-agent spec-driven development pipeline.

## Agents

| Agent | Slash Command | Primary Input | Primary Output |
|-------|--------------|---------------|----------------|
| PM | `/pm` | Feature idea, bug report, user story | Spec file in `docs/specs/` |
| Developer | `/developer` | Spec file (SPEC-NNN) | Code + RSpec tests |
| QA | `/qa` | Implemented feature (SPEC-NNN) | QA report, pass/fail |

## Standard Flow

```
1. PM Agent
   Input:  "I need X feature / fix Y bug"
   Output: docs/specs/feature-name.md (Status: ready)

2. Developer Agent
   Input:  "Implement SPEC-NNN"
   Output: - app/models/..., app/controllers/..., app/views/...
           - spec/models/..., spec/requests/..., spec/system/...
           - All RSpec tests passing, rubocop clean

3. QA Agent
   Input:  "QA SPEC-NNN"
   Output: QA report
           PASS → spec Status: done
           FAIL → itemized issues returned to developer
```

## How to Invoke an Agent

In Claude Code, use the `--agent` flag or mention the agent by name:

```
# Start with the PM
"pm agent: I need user authentication with email/password login"

# Hand off to developer
"developer agent: implement SPEC-001"

# QA sign-off
"qa agent: review SPEC-001"
```

## Testing Stack

- **RSpec** for all tests (models, requests, system)
- **FactoryBot** for test data
- **Capybara + Selenium (headless Chrome)** for system tests
- **Shoulda Matchers** for model assertion shorthand

### Setup (first time)

```bash
bundle install
bin/rails generate rspec:install
```

### Run tests

```bash
bundle exec rspec                    # all tests
bundle exec rspec spec/models/       # models only
bundle exec rspec spec/requests/     # requests only
bundle exec rspec spec/system/       # system/E2E only
```

## Linting & Security

```bash
bin/rubocop           # style lint
bin/rubocop -a        # auto-fix
bin/brakeman --no-pager   # security scan
bin/bundler-audit         # gem vulnerability check
```

## Spec Location

All specs live in `docs/specs/`. See `docs/specs/README.md` for the index.
