import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

// Policy engine for leakz.power. Loaded by the shell at startup as a headless
// service. It owns every side effect (processes, D-Bus, inhibitors) and is the
// single writer of the plugin's settings; the panel only reads its state and
// calls its functions.
Item {
  id: root

  // Injected by the shell loader.
  property var shell: null

  readonly property string pluginId: "leakz.power"
  readonly property string home: Quickshell.env("HOME")
  readonly property string powerProfilesStateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/omarchy/powerprofiles"
  readonly property bool onBattery: UPower.onBattery
  readonly property string source: onBattery ? "battery" : "ac"
  readonly property var device: UPower.displayDevice
  readonly property bool batteryPresent: !!(device && device.isPresent)

  // Raw settings as stored on the plugin's shell.json entry. The bar widget
  // pushes its copy here on every change so both sides normalize one object.
  property var rawSettings: ({})
  property var profiles: []
  property string activeProfile: ""
  readonly property var settings: Model.normalizeSettings(rawSettings, profiles)
  readonly property var strategy: Model.strategyFor(source, settings)

  // Profile last applied per source, so a settings change for the current
  // source applies once and a change for the other source only persists.
  property var appliedProfile: ({})
  property var queue: []
  property string lastEvent: "starting"
  property string lastEventAt: ""

  function log(event, details) {
    var suffix = details === undefined || details === null || details === "" ? "" : ": " + String(details);
    root.lastEventAt = new Date().toISOString();
    root.lastEvent = event + suffix;
    console.log(pluginId + " " + root.lastEventAt + " " + root.lastEvent);
  }

  // ---------------------------------------------------------------- settings

  // The first injection is the state the user already chose: remember it as
  // applied so startup stays silent. Later injections come from edits (the
  // shell settings screen or our own saves) and are synced.
  property bool settingsLoaded: false

  function updateSettings(next) {
    rawSettings = next && typeof next === "object" ? next : ({});
    if (!settingsLoaded) {
      settingsLoaded = true;
      rememberApplied();
    }
  }

  function rememberApplied() {
    var applied = {};
    for (var i = 0; i < Model.SOURCES.length; i++)
      applied[Model.SOURCES[i]] = settings[Model.sourceKey(Model.SOURCES[i], "profile")];
    appliedProfile = applied;
  }

  function saveSettings(patch) {
    var merged = {};
    for (var k in rawSettings)
      merged[k] = rawSettings[k];
    for (var p in patch)
      merged[p] = patch[p];
    rawSettings = merged;
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(pluginId, merged);
    else
      log("settings-not-persisted", "shell has no updateEntryInline");
  }

  // --------------------------------------------------------------- processes

  // One action process at a time; later commands wait their turn so two
  // writers never race on the same state file.
  function enqueue(label, command) {
    var next = queue.slice();
    next.push({
      label: label,
      command: command
    });
    queue = next;
    runNext();
  }

  function runNext() {
    if (actionProc.running || queue.length === 0)
      return;
    var item = queue[0];
    queue = queue.slice(1);
    log("process-start", item.label);
    actionProc.command = item.command;
    actionProc.running = true;
  }

  Process {
    id: actionProc
    onExited: function (exitCode) {
      if (exitCode !== 0)
        root.log("process-failed", "exit " + exitCode);
      root.runNext();
      root.refreshProfiles();
    }
  }

  // ---------------------------------------------------------------- profiles

  function refreshProfiles() {
    if (!profilesProc.running)
      profilesProc.running = true;
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseProfiles(text);
        // Keep the last known list across a transient empty read.
        if (parsed.profiles.length === 0)
          return;
        root.profiles = parsed.profiles;
        root.activeProfile = parsed.active;
      }
    }
  }

  function setProfile(src, profile) {
    var key = Model.sourceKey(src, "profile");
    var value = Model.normalizeProfile(profile, settings[key], profiles);
    var patch = {};
    patch[key] = value;
    saveSettings(patch);
    syncProfile(src);
  }

  // Applies the configured profile for `src` when it is the current source, or
  // only persists it otherwise. omarchy-powerprofiles-set always applies what it
  // persists, so the other source's choice is written straight into the same
  // state file the script reads, in the same one-line format.
  function syncProfile(src) {
    var profile = settings[Model.sourceKey(src, "profile")];
    if (appliedProfile[src] === profile)
      return;
    var applied = {};
    for (var k in appliedProfile)
      applied[k] = appliedProfile[k];
    applied[src] = profile;
    appliedProfile = applied;
    if (src === source) {
      enqueue("profile " + src + " " + profile, ["omarchy-powerprofiles-set", src, profile]);
    } else {
      enqueue("profile-persist " + src + " " + profile, ["bash", "-c", 'mkdir -p "$1" && printf "%s\\n" "$3" >"$1/$2"', "_", powerProfilesStateDir, src, profile]);
    }
  }

  function syncProfiles() {
    for (var i = 0; i < Model.SOURCES.length; i++)
      syncProfile(Model.SOURCES[i]);
  }

  // ------------------------------------------------------------------ status

  function statusJson() {
    return JSON.stringify({
      source: root.source,
      batteryPresent: root.batteryPresent,
      profiles: root.profiles,
      activeProfile: root.activeProfile,
      settings: root.settings,
      strategy: root.strategy,
      appliedProfile: root.appliedProfile,
      queue: root.queue.length,
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    });
  }

  onSourceChanged: {
    log("source", source);
    // The first-party battery service re-applies the persisted profile on a
    // source switch; ours only makes sure the persisted value is current.
    syncProfiles();
  }
  onSettingsChanged: if (root.settingsLoaded)
    syncProfiles()

  Component.onCompleted: {
    // Startup is silent: remember what is configured without applying it.
    rememberApplied();
    refreshProfiles();
    log("service-ready", "source=" + source);
  }
}
