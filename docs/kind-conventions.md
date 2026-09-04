# Kind conventions: Omarchy shell plugin

Owned by the kit `omarchy-plugin` profile. Rules for code that runs inside `omarchy-shell`
(Quickshell, QML). Sources: `shell/README.md` and `shell/plugins/README.md` in the Omarchy
repo, the plugin chapter of the Omarchy manual, and the first-party plugins under
`$OMARCHY_PATH/shell/plugins/`, which are the reference implementation.

## Contract with the shell

- The repo root is the plugin: `manifest.json` at the root, `schemaVersion: 1`, and `id`, `name`,
  `version`, `author`, `description`, `kinds`, `entryPoints`, `license` all filled. `omarchy.*`
  ids are reserved; use `<handle>.<plugin>`.
- Every kind in `kinds` has its entry point: `barWidget`, `panel`, `overlay`, `menu`, `service`,
  `bar`. Entry points are relative paths with no `..`, and nothing in the tree is a symlink.
- A bar widget ships the `barWidget` block: `displayName`, `description`, `category`,
  `allowMultiple`, `defaultSection`, `defaults`, and a `schema` for every user setting so the
  shell's own settings screen can edit it.
- Settings live inline on the plugin's entry in `~/.config/omarchy/shell.json`, read through
  `setting(name, fallback)` and written through `shell.updateEntryInline`. No private config
  file, no merge layers.
- Persisted runtime state, when a plugin needs any, goes under `~/.local/state/omarchy/` and is
  documented in the README with its exact path.
- `omarchy plugin validate .` passes at every commit. It is part of `lint`.

## Structure

- Mirror the first-party layout: a thin `BarWidget.qml` host, a `Panel.qml` for the UI, a
  `Service.qml` for headless logic, and a `Model.js` that holds every pure decision.
- `Model.js` is plain JavaScript with no Qt imports and a `module.exports` guard, so it runs
  under node in tests. QML files bind and wire; they do not decide.
- Talk to the system the way the shell does: `Quickshell.Services.UPower`, `Quickshell.Hyprland`,
  `Quickshell.Io.Process` with an argv array. Never build a shell string from user data.
- Reuse shipped Omarchy commands (`omarchy-*` in `$OMARCHY_PATH/bin`) before writing a script.
  When a script is needed it lives in `bin/`, passes `shellcheck`, and is invoked by name.
- One `IpcHandler` per plugin target, named after the plugin id. Every method it exposes is
  listed in the README.

## Theme and UI

- Colors, fonts and spacing come only from `qs.Commons` (`Color`, `Style`) and the bar
  (`bar.foreground`, `bar.fontFamily`). No literal colors, pixel sizes or font names in QML;
  a theme switch must restyle the plugin with no restart.
- Build from `qs.Ui` components (`Panel`, `KeyboardPanel`, `PanelHero`, `PanelSectionHeader`,
  `PanelSeparator`, `Toggle`, `ToggleSwitch`, `ButtonGroup`, `Dropdown`, `PanelSlider`,
  `NumberField`, `Button`). Add a custom control only when the kit has none, and state why in
  the file header.
- Every panel is fully keyboard driven through `PanelKeyCatcher`: arrows move a cursor, Enter
  activates, Escape closes, Tab switches panels. Mouse hover and keyboard cursor share one state.
- Panels keep the last known good data across transient empty reads so sections never collapse
  mid-refresh. Refresh timers run only while the panel is open.

## Runtime discipline

- The plugin runs unsandboxed for the whole session inside the shell process. No busy loops, no
  polling faster than the first-party widgets (5 s open, 30 s background), no `Process` left
  running without an owner, and no work at all while the panel is closed unless the manifest
  declares a `service`.
- A `Process` is guarded by `running` so a second trigger never spawns a second copy; queue the
  intent instead, as the first-party battery service does.
- Startup must be silent: no notifications, no writes, no system changes until the user acts,
  except restoring state the user chose earlier.
- Fail closed. A missing tool, an unsupported device or an unreadable file hides the control and
  explains why in the panel; it never leaves a control that looks live and does nothing.
- Log through `console.log` with the plugin id as prefix, one line per event, so
  `omarchy-shell` output stays greppable.

## Distribution

- `README.md` covers: what it does, every setting with its default, every IPC method, every
  file the plugin writes, install (`omarchy plugin add <url> --enable`), and removal, which
  must leave the system as it was.
- `preview.png` shows the panel on a default theme. `LICENSE` is present.
- Version in `manifest.json` follows SemVer and is bumped in the same commit as `CHANGELOG.md`.
- Listing on plugins.omarchy.org goes through the marketplace issue form with category and tags;
  the repository must be public at that point.

## Definition of done, additional

- [ ] `omarchy plugin validate .` passes.
- [ ] Verified in the running shell after `omarchy-shell shell rescanPlugins` on at least two
      themes, one light and one dark, with no restart.
- [ ] Every code path with a decision is covered by a node test on `Model.js`.
- [ ] Panel walked end to end with the keyboard only.
- [ ] Disable then enable through `omarchy plugin disable` / `enable` leaves no timer, process or
      inhibitor behind. Removal leaves no state the README does not list.
- [ ] Manifest version, changelog and README updated together.

## Audit, additional checks

- Literal colors, sizes or fonts in QML. Controls built by hand where `qs.Ui` has one.
- Decisions in QML that belong in `Model.js`. Untested branches in `Model.js`.
- `Process` without a `running` guard, timers alive while the panel is closed, shell strings
  built from user data.
- Settings not declared in the manifest `schema`. State files not listed in the README.
- Controls shown on hardware that cannot honor them. Actions taken at startup without user intent.
