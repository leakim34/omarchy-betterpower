---
name: done
description: Verify a change is actually done before declaring it. Runs the checks, walks the definition of done, reports pass or an exact list of what is missing. Run before every commit that closes work.
---

Never say a task is finished without this. Report each line as pass, fail, or not applicable
with a reason. Fix what you can, then re-run. Stop on the first item you cannot fix and say why.

1. `.kit/run lint`, `.kit/run typecheck`, `.kit/run test`, `.kit/run guard`. All pass.
2. `docs/definition-of-done.md`, every line, plus the additions in `docs/kind-conventions.md`.
3. The diff contains only what the issue asked for. List anything extra and remove it or justify it.
4. `CHANGELOG.md` has an entry under Unreleased if the change is user-visible.
5. A decision that would be expensive to reverse has an ADR. If in doubt, name the decision and ask.
6. The commit message is a conventional commit that references the issue.
