---
name: new-adr
description: Draft a correctly numbered architecture decision record from a short description of the decision.
---

1. Find the highest number in `docs/adr/` and use the next one, zero-padded to four digits.
2. Copy `docs/adr/0000-template.md` to `NNNN-<short-slug>.md`. Fill Date with today, Status `Proposed`.
3. Write Context, Decision and Consequences from what the user told you. Ask at most two questions if the context is unclear. Keep it under forty lines.
4. If it replaces an existing decision, reference it and remind the user to mark the old one `Superseded by NNNN` once accepted.
5. Show the draft. Do not commit.
