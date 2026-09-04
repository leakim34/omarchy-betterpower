# 0004. Sit alongside the first-party Power widget and delegate to its state

Date: 2026-09-04
Status: Accepted

## Context

Omarchy ships a Power bar widget (profile picker, stats), a battery service (low warning,
re-applies the per-source profile), an idle service and a stay-awake indicator. Duplicating
them would create two sources of truth for the same state files.

## Decision

- The plugin writes only through the mechanisms those plugins already read: the powerprofiles
  state files, shell.json idle keys, the stay-awake state file via IPC.
- The first-party Power widget stays in the bar during development; replacing it is a layout
  choice for the user, documented in the README, never forced by the plugin.
- The plugin never disables or patches a first-party plugin.

## Consequences

Both panels always agree. The plugin cannot offer behavior the underlying mechanism lacks
without an ADR that adds it explicitly (sleep after lock is the one such addition, ADR 0003).
