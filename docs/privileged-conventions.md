# Privileged actions

Owned by the kit `omarchy-plugin` profile. Applies because the plugin needs root for some action.

## Rules

- The plugin installer never runs sudo, install hooks or plugin code. Nothing privileged may be
  required to install, enable, disable or remove the plugin.
- Prefer a system daemon that already holds the privilege and gates it with polkit (UPower,
  logind, NetworkManager, power-profiles-daemon). A D-Bus call the active session is allowed to
  make beats any helper script.
- When a write really needs root, it goes through one helper script in `bin/`, run with
  `pkexec`, so the shell's polkit agent shows a themed prompt. The helper takes a fixed, validated
  argument set, writes exactly one thing, and exits. No shell interpolation of its arguments.
- One prompt per user action, never at startup, never on a timer, never to restore state.
  If a privileged state must survive reboot, say so in the README and make it the user's choice.
- Every privileged path has an unprivileged fallback: the control is hidden or disabled with a
  one-line reason when the helper, the polkit action or the device file is missing.
- The README lists every privileged action, what it writes, and how to undo it by hand.

## Definition of done, additional

- [ ] Each privileged action was exercised once through the real polkit prompt.
- [ ] Denying the prompt leaves the UI consistent and logs one line.
- [ ] The helper rejects malformed arguments in a test.

## Audit, additional checks

- `sudo` anywhere in the plugin. Privileged calls at startup or on timers.
- Helper arguments interpolated into a shell string. Helpers that write more than one thing.
- Privileged actions missing from the README.
