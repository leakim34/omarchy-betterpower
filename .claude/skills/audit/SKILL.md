---
name: audit
description: Find contradictions between the docs, the decisions and the code, and report them as actionable findings. Run monthly or before a minor release.
---

Read `CLAUDE.md`, `docs/architecture.md`, every ADR in `docs/adr/`, and `docs/kit-conventions.md`.
Then read the codebase with that context in mind. Report, in this order:

1. Architecture drift: modules or boundaries described in `docs/architecture.md` that the code no longer matches, and code structure that the doc does not mention.
2. Decision drift: ADRs the code no longer follows. Quote the ADR and the offending location.
3. Convention drift: dependency added without rationale, secrets or config outside `.env.example`, missing changelog entries since the last tag, commits not following the format.
4. Hygiene: dead code, unused dependencies, TODOs older than the last release, tests that do not assert anything.
5. Documentation: anything in `CLAUDE.md` or the docs that is derivable from the code and should be deleted, and anything the AI needs that is missing.

For each finding give: severity (fix now, fix soon, note), the file, one sentence, and the proposed action: an issue, a new ADR, or a direct fix. Do not fix anything during the audit. End with the list of issues and ADRs to create, ready to paste.
