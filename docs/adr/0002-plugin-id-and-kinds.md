# 0002. Id leakz.power with kinds bar-widget and service

Date: 2026-09-04
Status: Accepted

## Context

The omarchy.* namespace is reserved. The plugin needs a headless policy engine that runs from
shell startup and a bar entry to open the panel. The shell mounts a third-party service as soon
as its id appears anywhere in shell.json, so placing the bar widget enables the service.

## Decision

- Id: `leakz.power`. Name: "Power". Category: System. `allowMultiple: false`,
  `defaultSection: right`.
- Kinds: `bar-widget` (entry BarWidget.qml, hosting Panel.qml) and `service` (Service.qml).
- One IPC target `leakz.power` with open, close, toggle, status, and one method per action
  (setProfile, setLimit, setClamshell) so keybindings and scripts can drive it.
- No overlay, menu or bar kinds.

## Consequences

Enabling is one step for the user. The service must tolerate being loaded while the widget is
absent (no bar layout yet) and must never assume the panel exists. Adding a kind later is a
manifest change and an ADR.
