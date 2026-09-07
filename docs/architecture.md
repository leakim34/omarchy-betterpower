# Architecture

## Purpose

An Omarchy shell plugin that turns power management into one explicit, per-source strategy.
For each power source (battery, plugged in) the user picks a power profile, a screensaver delay,
a lock delay and a sleep delay. On top, a battery protection toggle (charge limit) and a
clamshell toggle (keep running with the lid closed while an external screen is connected).
Everything follows the active Omarchy theme and is fully keyboard driven.

## Overview

```mermaid
flowchart LR
  subgraph shell["omarchy-shell (Quickshell)"]
    BW[BarWidget.qml] --> P[Panel.qml]
    P -->|reads state, calls actions| S[Service.qml]
    P --> M[Model.js]
    S --> M
    S -->|idle.screensaver / idle.lock / stay-awake| IDLE[omarchy.idle service]
    S -->|omarchy-powerprofiles-set ac|battery profile| PPD[power-profiles-daemon]
    S -->|EnableChargeThreshold| UP[UPower D-Bus]
    S -->|systemd-inhibit handle-lid-switch| LOGIND[logind]
    S -->|systemctl suspend after lock| LOGIND
  end
  CFG[(~/.config/omarchy/shell.json)] <-->|settings inline on the plugin entry| S
```

## Modules

**Model.js**. Pure decisions, no Qt imports: which strategy applies for a source, what the
effective idle timings are, whether a capability is supported from the UPower bitmask,
what the clamshell state label reads, preset lists and their labels. Everything the tests cover
lives here. It must never touch a process, a file or a D-Bus object.

**Service.qml** (kind `service`). The policy engine. Probes the lid switch once at startup and
derives, with the UPower battery device, the `hardware` capability set from Model.js that every
module hides controls by. Watches `UPower.onBattery`, the UPower
battery device, `Quickshell.screens` and the plugin settings. On each change it computes the
target state through Model.js and applies the difference: writes idle timings and stay-awake
through the first-party idle service, persists the profile choice through
`omarchy-powerprofiles-set`, holds or releases a lid inhibitor, runs its own idle monitor for
sleep, and toggles or writes the charge limit. It is the only module that spawns processes or
calls D-Bus. It must never draw and never block: every process is guarded by `running`.

**Panel.qml**. The UI, opened from the bar widget. Reads state from the service, calls its
functions, and never computes policy itself. Built from `qs.Ui`, styled only through
`qs.Commons` and the bar's foreground. Owns the keyboard cursor over its controls.

**BarWidget.qml** (kind `bar-widget`). Thin host: an icon button showing battery state and a
protection marker, opens the panel, exposes the IPC target. No logic beyond delegation. In gauge mode it also
owns a rectangle reparented onto the bar window's content item, below the sections, that paints
the battery level across the whole bar (ADR 0010).

## Boundaries

- Policy is computed in Model.js and applied in Service.qml. Panel.qml never calls a process,
  never writes a file. Reviewer check: no `Process`, `FileView` or D-Bus in Panel.qml.
- The plugin does not replace Omarchy's mechanisms; it drives them. Idle timings go through
  `shell.json` and the first-party idle service, profiles through `omarchy-powerprofiles-set`,
  lock through the existing lock pipeline. The only new behavior is sleep after lock and the lid
  inhibitor. (ADR: coexistence)
- Nothing runs as root. Battery protection goes through UPower's `EnableChargeThreshold`,
  which polkit allows for the active session. Numeric thresholds, if they ever land, follow
  `docs/privileged-conventions.md`. (ADR: system integration)
- Every capability is detected before its control is shown. Unsupported hardware hides the
  control with a one-line reason. The set is computed once, in `Model.hardware`, from the
  battery presence and the lid probe: a desktop gets one source and no battery feature at all,
  a machine without a lid gets no clamshell. (kind conventions)
- Runtime state the plugin owns (lid inhibitor, sleep timer) lives in the shell process and
  dies with it. The only on-disk state is the settings entry in `shell.json` and the state files
  Omarchy already owns. Disable and removal must leave nothing else. (ADR: settings and state)
- Settings schema in `manifest.json` is the single list of user settings. A setting missing from
  the schema is a bug.

## Decisions

See `docs/adr/`.
