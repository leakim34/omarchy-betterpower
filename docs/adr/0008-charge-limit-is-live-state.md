# 0008. The charge limit is live UPower state, not a plugin setting

Date: 2026-09-04
Status: Accepted. Amends 0005.

## Context

ADR 0005 listed `chargeLimit` among the settings stored in shell.json. The firmware keeps the
charge mode across reboots by itself, and UPower reports it live with change signals. A stored
copy would either be redundant or, when they disagree (a change made in the BIOS or from
another OS), force the plugin to overwrite hardware state at startup, which the kind
conventions forbid.

## Decision

The battery protection toggle reads and writes UPower only. `chargeLimit` is removed from the
manifest schema and defaults. The panel shows the control only when the device reports
`ChargeThresholdSupported`, with wording taken from `ChargeThresholdSettingsSupported`.

## Consequences

One source of truth and a silent startup. The plugin cannot apply a charge preference on a
machine where the firmware forgot it; that is the firmware's job. Revisit if a device family
turns out to reset the mode on every boot.
