# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- Plugin skeleton: `leakz.power` bar widget with a panel showing the battery state and the strategy per power source, a headless service exposing `status` over IPC, and settings normalization (#1).
- Power profile per source: pick eco, balanced or performance for battery and for plugged in; the current source applies immediately, the other is persisted for the next switch. IPC `setProfile <source> <profile>` (#2).

- Project bootstrapped with kit 0.2.0 (profile omarchy-plugin, project).
