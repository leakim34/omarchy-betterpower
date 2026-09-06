# 0010. The bar gauge reparents a rectangle into the bar window

Date: 2026-09-06
Status: Accepted

## Context

The bar widget contract gives a widget one slot and a `bar` object exposing colors, size and
helpers. A battery gauge across the whole bar cannot be drawn from a slot. Replacing the bar
with a `bar` kind plugin would be far heavier than the feature warrants.

## Decision

- BarWidget.qml creates a Rectangle and sets its `parent` to `Window.window.contentItem`, at
  `z: -1`, so it paints under the sections but over the bar's own background.
- Every lookup is guarded; when the window or content item is missing the rectangle is simply
  hidden. The gauge must never throw or leave the bar in a broken state.
- Fill color is the theme accent at low alpha (`Model.gaugeSpec`), the bar urgent color under
  20% when not charging. No per-theme tables.

## Consequences

The feature depends on Quickshell's window item tree rather than the documented widget API.
An Omarchy shell change can silently disable it; the fallback is a bar without the gauge.
Re-check after shell updates. If the shell ever offers a supported hook for painting behind
the bar, move to it and supersede this ADR.
