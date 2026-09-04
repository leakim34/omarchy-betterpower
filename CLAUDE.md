# omarchy-power

Omarchy shell plugin for battery protection, per-power-source lock, sleep and power profile strategies, and clamshell lid control

Kind: omarchy-plugin. Stack: none. Commands run through `.kit/run <task>`, defined in `.kit.toml`.

| Task | Command |
|---|---|
| install | `not set, run /setup-stack` |
| test | `not set, run /setup-stack` |
| lint | `not set, run /setup-stack` |
| format | `not set, run /setup-stack` |
| typecheck | `not set, run /setup-stack` |

## How we work

- Before any code: `docs/architecture.md`, the ADRs in `docs/decisions.md`, then `/setup-stack` if commands above are not set.
- Non-trivial work starts with `/start`: issue, branch, relevant ADRs, plan.
- Nothing is finished until `/done` passes. Run it yourself before saying done; do not wait to be asked.
- Read `docs/adr/` before proposing a structural change. If a change contradicts an ADR, say so and propose a superseding ADR.
- Conventional commits. Every user-facing change gets a `CHANGELOG.md` entry under Unreleased.
- Files marked owned in `.kit.toml` belong to the kit. Do not edit them here; change them in the kit and upgrade.
- Conventions: `docs/kit-conventions.md` (all projects), `docs/kind-conventions.md` (this kind), `docs/stack-conventions.md` (this stack).

## Project-specific rules

<!-- Only what cannot be derived from the code. Keep it short. -->
