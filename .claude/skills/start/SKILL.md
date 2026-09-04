---
name: start
description: Begin a piece of work the right way. Issue, branch, relevant decisions, a three-line plan. Use before writing code for any non-trivial change.
---

1. **Issue.** Find the issue for this work, or create one with a title in the imperative, two
   sentences, and acceptance criteria. Trivial fixes may skip this; say so.
2. **Branch.** From the default branch, up to date: `<type>/<issue>-<slug>`.
3. **Decisions.** Read the ADRs that touch the area. Name the ones that constrain this work.
   If the work would contradict one, stop and propose a superseding ADR instead of coding around it.
4. **Plan.** Three lines: what changes, what is tested, what stays out of scope. Then start.
