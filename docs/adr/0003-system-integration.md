# 0003. Drive Omarchy and system daemons, no new privileged paths in v1

Date: 2026-09-04
Status: Accepted

## Context

Every feature maps onto something that already exists: power profiles through
`omarchy-powerprofiles-set`, idle timings through shell.json read live by the first-party idle
service, stay-awake through the idle IPC, charge limit through UPower's EnableChargeThreshold
(polkit allows the active session, no prompt), lid behavior through logind inhibitors, sleep
through `systemctl suspend`. Numeric charge thresholds need a root write to sysfs and cannot be
verified on the reference laptop, which only supports firmware mode.

## Decision

- Profile: `omarchy-powerprofiles-set ac|battery <profile>` for both persistence and apply.
- Idle: write `idle.screensaver` and `idle.lock` on shell.json via the shell's config mutator;
  "never lock" sets stay-awake through the idle service's setIdleEnabled.
- Sleep: own IdleMonitor in Service.qml, armed only after the lock has fired, running
  `systemctl suspend` (logind, no root). Hibernate is out of scope.
- Clamshell: hold `systemd-inhibit --what=handle-lid-switch --mode=block` as a child Process
  while the toggle is on and an external screen is present; release otherwise.
- Charge limit v1: UPower `EnableChargeThreshold` only. Capability from
  ChargeThresholdSupported and ChargeThresholdSettingsSupported. Numeric thresholds are a later
  release behind the pkexec helper described in docs/privileged-conventions.md.

## Consequences

No root, no polkit prompt, nothing to install. Users on ThinkPad or Framework get a toggle that
uses their firmware defaults, not a percentage, until the helper ships. Revisit when a tester with
sysfs thresholds is available.
