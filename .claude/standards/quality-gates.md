# Quality Gates

> Checkpoints that must pass before a PR can be merged.

## Preflight Gate

Before starting implementation on a task, verify:

- [ ] Spec file exists and is up to date in `docs/specs/`
- [ ] Target AC-# IDs are identified
- [ ] Branch created from latest main
- [ ] Project CLAUDE.md is current

## Completion Gate

Before opening a PR:

- [ ] All target AC-# IDs are implemented
- [ ] Tests exist for each AC and pass
- [ ] Lint and typecheck pass
- [ ] No out-of-scope changes
- [ ] PR is under ~200 LOC
- [ ] Spec updated with any implementation decisions

## Version Control Gate

- [ ] Commit messages follow Conventional Commits format
- [ ] Commit messages reference AC-# IDs in footers
- [ ] PR is created as draft (`gh pr create --draft`)
- [ ] PR description lists AC-# IDs covered
- [ ] Branch name follows convention: `{type}/{short-description}` (e.g., `feat/add-auth`)

## Review Gate

- [ ] At least one review approval (human or reviewer agent + human sign-off)
- [ ] QA evidence posted as PR comment (when applicable)
- [ ] All PR comment threads resolved
- [ ] CI is green

## Merge Gate

- [ ] Only humans merge. Agents never run `gh pr merge`.
- [ ] PR is marked ready for review (not draft) by a human.
- [ ] All required gates above are satisfied.
