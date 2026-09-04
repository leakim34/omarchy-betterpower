---
name: triage
description: Turn a milestone description or a list of wishes into well-formed GitHub issues, labelled and ordered.
---

Given a description of what should be built next:

1. Split it into issues that are each one focused change, deliverable in a single branch.
2. For each issue write: a title in the imperative, a two-sentence description, acceptance criteria as a checklist, and one label from `bug`, `feature`, `chore`.
3. Order them by dependency, then by value. Note dependencies explicitly.
4. Show the list. On confirmation, create them with `gh issue create`, and print the numbers.
