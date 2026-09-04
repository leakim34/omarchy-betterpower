---
name: release
description: Cut a release. Derives the version from conventional commits, updates the changelog, tags, and runs the profile's release steps.
---

1. Confirm the working tree is clean and on the default branch. Stop otherwise.
2. Run the test and lint commands from `CLAUDE.md`. Stop on failure.
3. List commits since the last `v*` tag. Derive the bump: any `!` or `BREAKING CHANGE` gives major, any `feat` gives minor, otherwise patch. State the current and next version and ask for confirmation.
4. Move the Unreleased section of `CHANGELOG.md` under the new version with today's date, grouped Added / Changed / Fixed / Removed. Rewrite commit subjects into user-facing sentences.
5. Bump the version wherever `docs/stack-conventions.md` says it lives.
6. Commit `chore(release): vX.Y.Z`, tag `vX.Y.Z`, push branch and tag.
7. Run the release steps listed in `docs/stack-conventions.md`, if any. Report the result and the tag URL.
