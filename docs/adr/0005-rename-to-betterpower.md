# 0005. Rename to leakz.betterpower / BetterPower

Date: 2026-09-06
Status: Accepted. Amends 0002.

## Context

The plugin was named "Power" with id `leakz.power`, the same display name as the first-party
Power widget it replaces. Two "Power" entries in the plugin picker are confusing, and the id is
copied into every user's shell.json, so it must be settled before the first public release.

## Decision

- Id: `leakz.betterpower`. Name and bar display name: "BetterPower".
- IPC target follows the id: `omarchy-shell leakz.betterpower <method>`.
- Repository: `leakim34/omarchy-betterpower`.
- Everything else in 0002 stands.

## Consequences

Pre-release, so no migration. Anyone who installed the private repo must remove `leakz.power`
from shell.json and re-add the plugin.
