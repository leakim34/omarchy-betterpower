# 0001. Use QML on Quickshell with node tests for Model.js and shellcheck for helpers

Date: 2026-09-04
Status: Accepted

## Context

The runtime is imposed: plugins are QML loaded by omarchy-shell (Quickshell, Qt 6). The only
choices are how pure logic is tested and how the repo is linted. The first-party plugins keep
decisions in a plain JavaScript Model.js with a module.exports guard and test it with node.
Node 26 is installed through mise. No package manager or dependency is needed.

## Decision

- Runtime: QML on Quickshell, no build step. The repo is the plugin; no bundling.
- Tests: node's built-in test runner (`node --test tests/`) over Model.js and any other pure
  JavaScript. No test framework dependency.
- Lint: `omarchy plugin validate .`, `shellcheck bin/*`, and `qmlformat --check` when it is
  installed. Format: `qmlformat -i`. Typecheck: skip. Build: skip.
- Run: `omarchy-shell shell rescanPlugins` after linking the checkout into
  `~/.config/omarchy/plugins/leakz.power`.

## Consequences

Zero dependencies and a lockfile-free repo. QML itself is only verified in the running shell,
so the definition of done keeps a manual check on two themes. Revisit if a QML unit test
runner becomes available in Omarchy's toolchain.
