# Done Checklist

> Developers own their workflow. Walk this checklist before opening PRs.

## Before Opening a PR

Every developer verifies before opening a PR:

- [ ] All spec ACs addressed by this task are implemented
- [ ] Tests exist for each AC and pass locally
- [ ] No out-of-scope changes included
- [ ] Spec updated if implementation revealed new decisions or edge cases
- [ ] Lint and typecheck pass
- [ ] PR is under ~200 LOC (if over, decompose before opening)
- [ ] Commit messages reference AC-# IDs
- [ ] PR description lists which AC-#s are covered

## Before Requesting QA

- [ ] PR is in draft, CI is green
- [ ] Test instructions are clear enough for QA to reproduce expected behavior
- [ ] Any environment setup needed is documented in the PR

## Before Requesting Review

- [ ] QA has validated (or developer has self-validated with evidence)
- [ ] All PR comments and feedback addressed
- [ ] No merge conflicts with base branch
