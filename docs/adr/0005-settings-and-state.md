# 0005. Flat settings in shell.json, runtime state in the shell process only

Date: 2026-09-04
Status: Accepted

## Context

The shell keeps every plugin setting inline on its entry in shell.json and edits them through
the manifest schema. Nested objects would not be editable there. The plugin also holds
transient state (inhibitor, sleep timer) that must not survive the shell.

## Decision

- Settings are flat keys, all declared in the manifest schema with defaults:
  `batteryProfile`, `batteryScreensaver`, `batteryLock`, `batterySleep`,
  `acProfile`, `acScreensaver`, `acLock`, `acSleep`, `clamshell`, `chargeLimit`.
  Delays are seconds, `0` means never. Defaults: battery power-saver / 120 / 300 / 600;
  ac performance / 0 / 0 / 0; clamshell true; chargeLimit false.
- Runtime state lives in Service.qml properties. Nothing under ~/.local/state is created by
  the plugin; it only touches files Omarchy already owns.
- Disable or removal: the service releases the inhibitor and timers on destroy. Idle keys and
  profile state files keep their last values, which are Omarchy's own settings, and this is
  stated in the README.

## Consequences

The built-in settings screen and the panel edit the same keys. Renaming a key later needs a
migration in the service. Nothing to clean on removal beyond the shell.json entry.
