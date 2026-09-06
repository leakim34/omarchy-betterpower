# Stack conventions: QML on Quickshell

Decisions only; the commands live in `.kit.toml`.

- The repo root is the plugin. No build, no bundling, no `package.json`: node is used only for
  tests and the manifest validator, with built-in modules.
- `Model.js` and anything under `scripts/` is CommonJS with a `module.exports` guard so the same
  file loads in QML and in node.
- QML is formatted by `qmlformat`; the check is part of lint when the tool is present.
- The version lives in `manifest.json` only. Tags `vX.Y.Z` match it.
- Errors are logged with the `leakz.betterpower` prefix through `console.log`, one line per event.
- Release: bump `manifest.json` and `CHANGELOG.md` in one commit, tag, `gh release create`.
- Local run: `.kit/run run` links the checkout into `~/.config/omarchy/plugins/` and rescans,
  which hot-reloads the bar widget only. `.kit/run run --restart` restarts the shell, needed
  after a change to Panel.qml or Service.qml.
