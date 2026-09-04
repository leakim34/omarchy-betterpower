# Architecture decision records

One file per decision, numbered, immutable. Copy `0000-template.md` to `NNNN-short-title.md`.

Write an ADR when a decision would be expensive to reverse: a storage engine, an auth model,
a module boundary, a third-party service, a public interface. Do not write one for a
naming choice or a refactor.

To change a decision, write a new ADR with status `Accepted` that names the one it
supersedes, and set the old one's status to `Superseded by NNNN`.

The `/new-adr` skill produces a correctly numbered draft.
