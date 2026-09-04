# Decisions to make before code

Each item becomes an ADR with `/new-adr`. Tick it when the ADR is accepted.

- [x] Stack: QML on Quickshell is given by the shell; decide the test runner for `Model.js`
      (node built-in test runner or another), shell linting, and how `omarchy plugin validate`
      runs in `lint`. Then run `/setup-stack`.
- [x] Plugin id and kinds: which of `bar-widget`, `panel`, `overlay`, `menu`, `service`, `bar`,
      and what each entry point owns.
- [x] System integration: which system facilities (UPower, logind, Hyprland IPC, sysfs, `omarchy-*`
      commands) the plugin talks to, and through which shipped API or script.
- [x] Coexistence: how the plugin relates to first-party plugins covering the same area
      (replace, sit alongside, delegate to their state files or IPC).
- [x] Settings and state: which values are settings in `shell.json`, which are runtime state
      under `~/.local/state/omarchy/`, and what disable and removal must clean up.
- [x] Testing strategy: what `Model.js` tests cover, what is verified by hand in the running
      shell, and what is deliberately untested.
- [x] Release and listing: versioning, changelog, `preview.png`, and whether to submit to
      plugins.omarchy.org.
