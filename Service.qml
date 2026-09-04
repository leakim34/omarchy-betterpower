import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

// Policy engine for leakz.power. Loaded by the shell at startup as a headless
// service. It owns every side effect (processes, D-Bus, inhibitors); the panel
// only reads its state and calls its functions.
Item {
  id: root

  // Injected by the shell loader.
  property var shell: null

  readonly property string pluginId: "leakz.power"
  readonly property bool onBattery: UPower.onBattery
  readonly property string source: onBattery ? "battery" : "ac"
  readonly property var device: UPower.displayDevice
  readonly property bool batteryPresent: !!(device && device.isPresent)

  // Raw settings as stored on the plugin's shell.json entry; the panel pushes
  // its copy here so both sides normalize the same object.
  property var rawSettings: ({})
  readonly property var settings: Model.normalizeSettings(rawSettings, [])
  readonly property var strategy: Model.strategyFor(source, settings)

  property string lastEvent: "starting"
  property string lastEventAt: ""

  function log(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details);
    root.lastEventAt = new Date().toISOString();
    root.lastEvent = event + suffix;
    console.log(pluginId + " " + root.lastEventAt + " " + root.lastEvent);
  }

  function updateSettings(next) {
    rawSettings = next && typeof next === "object" ? next : ({});
  }

  function statusJson() {
    return JSON.stringify({
      source: root.source,
      batteryPresent: root.batteryPresent,
      settings: root.settings,
      strategy: root.strategy,
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    });
  }

  onSourceChanged: log("source", source)

  Component.onCompleted: log("service-ready", "source=" + source)
}
