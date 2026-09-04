# 0006. Test every decision in Model.js, verify QML by hand in the shell

Date: 2026-09-04
Status: Accepted

## Context

There is no QML unit runner in the toolchain. First-party plugins test their Model.js with node
and rely on the running shell for the rest.

## Decision

- Model.js holds strategy resolution, capability detection from UPower values, label and preset
  logic, and settings normalization. Each branch has a node test.
- Service.qml and Panel.qml are verified by a checklist in the definition of done: rescan on two
  themes, keyboard walk, source switch with a charger, lid close with an external screen,
  disable and enable.
- Deliberately untested: pixel layout, Quickshell bindings, the systemd and UPower calls
  themselves.

## Consequences

Fast tests with no dependencies. QML regressions are caught only by the manual checklist, so
the checklist stays short enough to run every time.
