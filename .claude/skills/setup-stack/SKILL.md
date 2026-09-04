---
name: setup-stack
description: Install and wire the stack tooling after the stack has been decided in an ADR. Produces working lint, format, typecheck, test, hooks and CI, and records the commands in .kit.toml.
---

Precondition: an accepted ADR in `docs/adr/` names the language, framework and package manager.
If there is none, stop and offer to write it with `/new-adr` first. Never choose a stack here.

Deliver every item below. For each, report done, or not applicable with a one-line reason.

1. **Toolchain.** Install the package manager and dependencies. Keep the lockfile.
2. **Commands.** Make these work from the project root and write them to `.kit.toml` under
   `[commands]`: `install`, `test`, `lint`, `format`, `typecheck`, `build`, `run`.
   Use `skip` for a command that does not apply (typecheck for a language without one, run for a library).
   Every command must exit non-zero on failure.
3. **CLAUDE.md.** Update the Commands table to match `.kit.toml`. Update the stack line.
4. **CI.** Write `.kit/ci-setup.sh` so a fresh Ubuntu runner can install the toolchain.
   Do not edit `.github/workflows/ci.yml`; it is owned by kit and calls `.kit/run`.
5. **Hooks.** `.kit/hooks/pre-commit` runs lint and guard through `.kit/run`. Confirm
   `git config core.hooksPath` is `.kit/hooks`. Make lint fast enough to run on every commit.
6. **Stack conventions.** Write `docs/stack-conventions.md`: decisions only, nothing derivable from
   config files. Layout, where the version lives, error handling, release steps. Under fifteen lines.
7. **Gitignore.** Add the stack's build, cache and environment folders.
8. **Verify.** Run `.kit/run lint`, `.kit/run typecheck`, `.kit/run test`, `.kit/run guard`, then
   `kit doctor --run`. All must pass. Commit as `chore: set up <stack> tooling`.
