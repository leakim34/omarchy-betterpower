# Conventions

Generic rules shared by every kit project. Owned by the kit; change them there.

## Tooling contract

Every project, whatever the stack, exposes the same tasks through `.kit/run <task>`:
`install`, `test`, `lint`, `format`, `typecheck`, `build`, `run`, plus the built-in `guard`.
They are defined in `.kit.toml` under `[commands]`, set by a preset or by `/setup-stack`.
CI runs lint, typecheck, test and guard through them. The pre-commit hook runs lint and guard.
A task that does not apply is set to `skip`, never left empty.

## Git

- Default branch is protected in spirit: work on branches, merge when CI is green.
- Branch names: `<type>/<issue-number>-<short-slug>`, e.g. `feat/12-export-csv`.
- Conventional commits: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `build`, `ci`.
  Breaking changes carry `!` and a `BREAKING CHANGE:` footer.
- Squash merge. The squash message follows the same format.

## Issues

- Three labels: `bug`, `feature`, `chore`. Add `blocked` when waiting on something external.
- Every non-trivial change references its issue in the commit body or PR.

## Architecture decisions

- A decision that would be expensive to reverse gets an ADR in `docs/adr/`. See the README there.
- ADRs are immutable. To change a decision, write a new ADR that supersedes the old one.

## Dependencies

- Prefer twenty lines of code over a new dependency.
- A new runtime dependency needs one line in the commit body saying why it beat writing it.
- Pin to a major version. Bump dependencies as a dedicated `chore` commit, never mixed with features.

## Environment and secrets

- `.env.example` lists every variable the project reads, with placeholder values, and is committed.
- `.env` holds real values and is never committed. Secrets never appear in code, docs or issues.
- Configuration is read once at startup and validated. Missing required variables fail loudly.

## Security baseline

- Validate and bound every input at the boundary: CLI arguments, HTTP requests, files, env.
- Dependency vulnerability scanning runs in CI when the ecosystem supports it.
- Least privilege for tokens and keys. Rotate anything that leaks, then fix the leak.

## Releases

- Semantic versioning. The version is derived from conventional commits since the last tag.
- Every release updates `CHANGELOG.md` and creates a tag `vX.Y.Z`.

## Rhythm

- `/start` before a change, `/done` before declaring it finished.
- `/audit` monthly or before a minor release. Findings become issues or ADRs.
- `kit doctor` when returning to a project after a while, `kit doctor --run` before a release.
