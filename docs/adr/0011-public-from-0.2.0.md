# 0011. Public and listed from 0.2.0

Date: 2026-09-06
Status: Accepted. Amends 0007.

## Context

ADR 0007 kept the repository private until 1.0.0. The plugin now covers every feature planned
for a first public version, replaces the built-in Power widget cleanly, and has been in daily
use on one laptop. Waiting for 1.0.0 only delays feedback from other hardware.

## Decision

- The repository goes public with the 0.2.0 release. Install is by HTTPS git URL.
- The marketplace listing is submitted at the same time.
- Everything else in 0007 stands: SemVer in the manifest, tag matches, preview regenerated per
  minor release.

## Consequences

Pre-1.0 semantics apply: a minor bump may change settings keys, always with a migration in the
service (as done for `showPercentage` to `barMode`).
