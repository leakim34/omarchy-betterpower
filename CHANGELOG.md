# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- Plugin skeleton: `leakz.power` bar widget with a panel showing the battery state and the strategy per power source, a headless service exposing `status` over IPC, and settings normalization (#1).
- Power profile per source: pick eco, balanced or performance for battery and for plugged in; the current source applies immediately, the other is persisted for the next switch. IPC `setProfile <source> <profile>` (#2).
- Screensaver and lock delay per source, written live into the shell's idle settings; when neither fires on a source, stay-awake is enabled so the coffee-cup indicator shows it. IPC `setDelay <source> <screensaver|lock> <seconds>` (#3).
- Sleep after lock per source: once the session is locked, an idle monitor that respects idle inhibitors suspends the machine after the configured delay; never on a source whose lock is never (#4).

- Project bootstrapped with kit 0.2.0 (profile omarchy-plugin, project).
