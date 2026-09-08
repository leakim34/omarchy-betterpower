# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Changed

- Agent instructions (`CLAUDE.md`, `.claude/`) are no longer tracked. The marketplace security review flagged them as publisher-controlled instructions that an agent running in the installed plugin directory could execute. They stay on disk for contributors, ignored.

## [0.3.0] - 2026-09-07

### Changed

- The plugin adapts to the hardware. Without a battery (a desktop) the panel shows one plugged-in strategy, a hero that names the active profile, and no battery hero, stats, protection toggle or note; the bar's percentage and gauge modes are inert and a right click leaves the mode alone; no battery profile is persisted. Without a lid switch the clamshell toggle is gone and no lid inhibitor is ever held. `status` reports `hardware`, `lidPresent` and `lidProbed`.
- Developer scaffolding (`.kit/`) is no longer tracked; CI installs nothing with sudo. The README no longer shows a sudo command in the hardware notes.

## [0.2.1] - 2026-09-06

### Fixed

- The charging shimmer on the bar gauge ran past the battery level; it now stops at the fill edge.

## [0.2.0] - 2026-09-06

### Changed

- Renamed to BetterPower: id `leakz.betterpower`, IPC target and repository follow. Pre-release, no migration.

### Added

- Battery hero from the first-party Power panel: icon, status line with charging phrases, large percentage, progress bar with charging pulse, and the stats grid (size, cycles, charge limit, state). The charge limit cell reads the plugin's own UPower state (#9).
- Right click on the bar icon cycles the bar display mode: nothing, the percentage next to the icon, a battery gauge painted across the whole bar, or both in the theme accent, turning urgent under 20% and shimmering while charging. Persisted as the `barMode` setting. IPC `setBarMode`, `cycleBarMode` (#11, #12).

## [0.1.0] - 2026-09-04

### Added

- Plugin skeleton: `leakz.betterpower` bar widget with a panel showing the battery state and the strategy per power source, a headless service exposing `status` over IPC, and settings normalization (#1).
- Power profile per source: pick eco, balanced or performance for battery and for plugged in; the current source applies immediately, the other is persisted for the next switch. IPC `setProfile <source> <profile>` (#2).
- Screensaver and lock delay per source, written live into the shell's idle settings; when neither fires on a source, stay-awake is enabled so the coffee-cup indicator shows it. IPC `setDelay <source> <screensaver|lock> <seconds>` (#3).
- Sleep after lock per source: once the session is locked, an idle monitor that respects idle inhibitors suspends the machine after the configured delay; never on a source whose lock is never (#4).
- Battery protection toggle driven by UPower's charge threshold API, shown only when the battery reports charge control, with wording taken from what the hardware supports. IPC `setChargeLimit true|false` (#5).
- Clamshell toggle: while on and an external screen is connected, a logind lid-switch inhibitor held by the shell keeps the session running with the lid closed; released on disconnect, disable or shell exit. IPC `setClamshell true|false` (#6).
- Keyboard cursor over every control, IPC `status` reports the open state and cursor, preview image (#7).

- Project bootstrapped with kit 0.2.0 (profile omarchy-plugin, project).
