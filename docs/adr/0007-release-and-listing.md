# 0007. SemVer in the manifest, GitHub releases, marketplace listing when public

Date: 2026-09-04
Status: Amended by 0011 (public from 0.2.0)

## Context

The marketplace requires a public repo, manifest with author and description, README, LICENSE,
and an optional preview.png. The version shown is the manifest's.

## Decision

- manifest.json version follows SemVer and is bumped with the CHANGELOG entry in one commit;
  tags `vX.Y.Z` match it.
- preview.png is regenerated for every minor release from the default theme.
- The repo starts private. Listing on plugins.omarchy.org happens after 1.0.0, when the repo goes
  public, through the marketplace issue form.

## Consequences

One version to maintain. Until public, install is by git URL over SSH or by linking the
checkout into ~/.config/omarchy/plugins.
