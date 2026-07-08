# Agent Configuration Standard

> Reference for agent YAML frontmatter fields. Consult when creating or modifying an agent in `agents/base/` or a stack overlay in `agents/stacks/`.

## Supported Frontmatter Fields

| Field | Type | Purpose |
|-------|------|---------|
| name | string (required) | Unique agent identifier (kebab-case) |
| description | string (required) | When Claude should delegate to this agent |
| model | string | Claude model: `opus`, `sonnet`, `haiku`, `inherit` (default: inherit) |
| permissionMode | string | Permission handling: `default`, `acceptEdits`, `plan`, `dontAsk`, `bypassPermissions` |
| maxTurns | integer | Maximum agentic turns before stopping |
| tools | list | Allowlisted tools (if specified, ONLY these are available) |
| disallowedTools | list | Denylisted tools (blocked even if parent allows) |
| mcpServers | object | MCP servers (if specified, REPLACES parent servers — use with caution) |
| isolation | string | `worktree` for isolated git worktree |

## Canonical Field Order

```yaml
name:
description:
model:
permissionMode:
maxTurns:
tools:
disallowedTools:
mcpServers:
isolation:
```

Omit fields that use defaults. `scripts/merge-agents.sh` writes `name`, `description`, `model`, and `allowed-tools` for every generated agent — any other field must be added manually to the base agent file so it survives the merge.

## Model Assignment (this repo's 11 base agents)

| Agent | Model | Why |
|-------|-------|-----|
| qa | opus | Quality gate — cost of a missed regression outweighs speed/cost. |
| reviewer | opus | Quality gate — same reasoning as qa. |
| security | opus | Audit/gate work — cost of a missed vulnerability is high. |
| pm | sonnet | Template-following business documentation, not a gate. |
| spec | sonnet | Template-following spec authoring, not a gate. |
| scribe | sonnet | Template-following documentation, not a gate. |
| developer | inherit | Implementation — the user's own cost/capability tradeoff. |
| devops | inherit | Same reasoning as developer. |
| ux | inherit | Same reasoning as developer. |
| architect | inherit | Design-decision work adjacent to implementation, not a hard gate. |
| cross-review | inherit | Coordinates other reviews rather than being the gate itself. |

`scripts/merge-agents.sh` looks up this table per agent name (see the `AGENT_MODELS` map in the script) instead of stamping one model onto every agent.

## Design Principles

1. **Quality gates get Opus.** qa, reviewer, and security use `model: opus` because gate quality matters more than speed or cost.
2. **Implementation inherits.** developer, devops, ux, architect, and cross-review use `model: inherit` — the user chose their model based on their own cost/capability tradeoff.
3. **Template-following work uses Sonnet.** pm, spec, and scribe produce structured documents from templates — speed matters more than frontier reasoning depth.
4. **`disallowedTools` blocks tool names, not specific arguments.** You cannot block `gh pr merge` via frontmatter while allowing other `Bash` usage — use a safety hook in `.claude/settings.local.json` for command-level blocking instead.
5. **`model` does not cascade to subagents.** Each agent needs its own frontmatter.
6. **Specifying `mcpServers` replaces parent servers.** Omit the field to inherit.
7. **Specifying `tools` is an allowlist.** Only listed tools work — omit to inherit the parent's tool set.

## Overriding in a Target Project

This repo's install flow (`scripts/merge-agents.sh`) generates `<TARGET>/.claude/agents/<name>/AGENT.md` by merging `agents/base/<name>.md` with the matching `agents/stacks/<STACK>/<name>.md` overlay, if one exists. To change behavior for one project:

- **Preferred:** edit the base agent or its stack overlay in this repo, then re-run `make init STACK=<stack> TARGET=<path>` to regenerate.
- **One-off:** edit the generated `<TARGET>/.claude/agents/<name>/AGENT.md` directly. It will be overwritten the next time the install script runs for that project, so this is for throwaway experiments only, not a durable override mechanism.

## Key Gotchas

- Agents do NOT inherit the parent's system prompt — only the markdown body.
- Specifying `mcpServers` REPLACES parent servers — omit to inherit.
- Specifying `tools` is an allowlist — only listed tools work.
- `model` does NOT cascade to subagents — each agent needs its own.
- Re-running the install script overwrites the target project's generated agent files — durable customizations belong in this repo, not the generated output.
