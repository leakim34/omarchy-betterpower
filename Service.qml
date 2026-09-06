import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import "Model.js" as Model

// Policy engine for leakz.power. Loaded by the shell at startup as a headless
// service. It owns every side effect (processes, D-Bus, inhibitors) and is the
// single writer of the plugin's settings; the panel only reads its state and
// calls its functions.
//
// Three rules keep it from fighting the shell:
// - Nothing is written before the settle period after startup has passed;
//   the state files, shell.json and the stay-awake file already hold what was
//   applied last time.
// - Settings are read from the shell's live config in a change handler, not a
//   binding, because every write below changes that config.
// - Syncs run through Qt.callLater so a write never re-enters itself.
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

  property var rawSettings: ({})
  property var profiles: []
  property string activeProfile: ""
  readonly property var settings: Model.normalizeSettings(rawSettings, profiles)
  readonly property var strategy: Model.strategyFor(source, settings)

  property bool settled: false
  property var appliedProfile: ({})
  property var appliedIdle: null
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

  function readSettings() {
    var entry = shell ? Model.findEntry(shell.shellConfig, pluginId) : null;
    var next = entry || ({});
    if (JSON.stringify(next) === JSON.stringify(rawSettings))
      return;
    rawSettings = next;
    scheduleSync();
  }

  function saveSettings(patch) {
    var merged = {};
    for (var k in rawSettings)
      merged[k] = rawSettings[k];
    for (var p in patch)
      merged[p] = patch[p];
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline(pluginId, merged);
    else
      log("settings-not-persisted", "shell has no updateEntryInline");
  }

  Connections {
    target: root.shell
    function onShellConfigChanged() {
      root.readSettings();
    }
  }

  // Remember what is already in effect, then start syncing on changes.
  function settle() {
    if (settled)
      return;
    readSettings();
    var applied = {};
    for (var i = 0; i < Model.SOURCES.length; i++)
      applied[Model.SOURCES[i]] = settings[Model.sourceKey(Model.SOURCES[i], "profile")];
    appliedProfile = applied;
    var config = shell && shell.shellConfig ? shell.shellConfig : null;
    var idle = config && config.idle && typeof config.idle === "object" ? config.idle : {};
    var idleService = idleServiceNow();
    appliedIdle = {
      // Raw numbers, not normalizeDelay: the never sentinel sits above the
      // range user settings are clamped to.
      screensaver: Number(idle.screensaver),
      lock: Number(idle.lock),
      stayAwake: idleService ? !!idleService.stayAwake : false
    };
    settled = true;
    resolveServices();
    refreshCharge();
    syncLidInhibit();
    log("settled", "source=" + source + " profile=" + strategy.profile + " idle=" + JSON.stringify(appliedIdle));
  }

  Timer {
    id: settleTimer
    interval: 2000
    repeat: false
    onTriggered: root.settle()
  }

  // ------------------------------------------------------------------- sync

  property bool syncScheduled: false

  function scheduleSync() {
    if (!settled || syncScheduled)
      return;
    syncScheduled = true;
    Qt.callLater(root.syncAll);
  }

  function syncAll() {
    syncScheduled = false;
    if (!settled)
      return;
    // An entry that is gone means the plugin was disabled: write nothing.
    if (!shell || !Model.findEntry(shell.shellConfig, pluginId))
      return;
    syncProfiles();
    syncIdle();
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

  // ------------------------------------------------------------------- sleep

  // The first-party lock service may mount after us, so it is looked up
  // until found rather than bound once.
  property var lockService: null
  readonly property bool locked: lockService ? !!lockService.locked : false
  readonly property bool sleepArmed: settled && locked && strategy.sleep > 0

  function resolveServices() {
    if (!lockService && shell && typeof shell.serviceFor === "function")
      lockService = shell.serviceFor("omarchy.lock");
    if (!lockService)
      serviceLookupTimer.start();
  }

  Timer {
    id: serviceLookupTimer
    interval: 5000
    repeat: false
    onTriggered: root.resolveServices()
  }

  // Armed only while the session is locked: the delay counts from the lock
  // and from the last input on the lock screen, and idle inhibitors (a
  // download, a video) hold it off like they hold off the lock itself.
  IdleMonitor {
    id: sleepMonitor
    enabled: root.sleepArmed
    timeout: Math.max(1, root.strategy.sleep)
    respectInhibitors: true
    onIsIdleChanged: {
      if (isIdle && enabled)
        root.suspend("sleep-after-lock " + root.strategy.sleep + "s");
    }
  }

  onLockedChanged: log("lock", locked ? "locked" : "unlocked")
  onSleepArmedChanged: log("sleep", sleepArmed ? "armed " + strategy.sleep + "s" : "disarmed")

  function suspend(reason) {
    if (sleepProc.running)
      return;
    log("suspend", reason);
    sleepProc.command = ["systemctl", "suspend"];
    sleepProc.running = true;
  }

  Process {
    id: sleepProc
    onExited: function (exitCode) {
      if (exitCode !== 0)
        root.log("suspend-failed", "exit " + exitCode);
    }
  }

  // --------------------------------------------------------------- clamshell

  // Quickshell.screens lists the enabled outputs; with the lid closed the
  // internal panel is gone from it, so the external one is what remains.
  readonly property var screenNames: {
    var out = [];
    var screens = Quickshell.screens || [];
    for (var i = 0; i < screens.length; i++)
      out.push(screens[i].name);
    return out;
  }
  readonly property bool externalScreen: Model.hasExternalScreen(screenNames)
  readonly property var lidBehavior: Model.lidBehavior(settings.clamshell, externalScreen)
  // Held by a child process, so it dies with the shell and can never strand
  // the laptop awake in a bag.
  readonly property bool lidInhibitWanted: settled && lidBehavior.inhibit
  readonly property bool lidInhibited: lidInhibitProc.running

  Process {
    id: lidInhibitProc
    command: ["systemd-inhibit", "--what=handle-lid-switch", "--who=leakz.power", "--why=Clamshell: keep running with the lid closed", "--mode=block", "sleep", "infinity"]
    onExited: function (exitCode) {
      root.log("lid-inhibit", "released (exit " + exitCode + ")");
    }
  }

  function syncLidInhibit() {
    if (lidInhibitWanted && !lidInhibitProc.running) {
      log("lid-inhibit", "held (external screen, clamshell on)");
      lidInhibitProc.running = true;
    } else if (!lidInhibitWanted && lidInhibitProc.running) {
      lidInhibitProc.running = false;
    }
  }

  onLidInhibitWantedChanged: syncLidInhibit()

  function setShowPercentage(enabled) {
    saveSettings({
      showPercentage: !!enabled
    });
  }

  function setClamshell(enabled) {
    saveSettings({
      clamshell: !!enabled
    });
  }

  // ------------------------------------------------------------ charge limit

  // Quickshell's UPower module does not expose the charge threshold
  // properties, so they are read over D-Bus. UPower's EnableChargeThreshold
  // is allowed for the active session by polkit, so no prompt and no root.
  property var chargeState: ({
      supported: false,
      settings: 0,
      enabled: false,
      start: 0,
      end: 0
    })
  readonly property var chargeCapability: Model.chargeCapability(chargeState)
  readonly property bool chargeLimitEnabled: !!chargeState.enabled
  property bool chargeBusy: false

  readonly property string chargeProbeScript: ['dev=$(upower -e 2>/dev/null | grep -m1 BAT) || exit 0', '[ -n "$dev" ] || exit 0', 'get() { busctl get-property org.freedesktop.UPower "$dev" org.freedesktop.UPower.Device "$1" 2>/dev/null | cut -d" " -f2; }', 'printf "supported\t%s\n" "$(get ChargeThresholdSupported)"', 'printf "settings\t%s\n" "$(get ChargeThresholdSettingsSupported)"', 'printf "enabled\t%s\n" "$(get ChargeThresholdEnabled)"', 'printf "start\t%s\n" "$(get ChargeStartThreshold)"', 'printf "end\t%s\n" "$(get ChargeEndThreshold)"'].join("\n")

  function refreshCharge() {
    if (!chargeProc.running)
      chargeProc.running = true;
  }

  Process {
    id: chargeProc
    command: ["bash", "-c", root.chargeProbeScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = Model.parseChargeState(text);
        if (JSON.stringify(next) !== JSON.stringify(root.chargeState))
          root.chargeState = next;
      }
    }
  }

  function setChargeLimit(enabled) {
    if (!chargeCapability.available || chargeSetProc.running)
      return;
    var value = !!enabled;
    chargeBusy = true;
    log("charge-limit", value ? "enable" : "disable");
    chargeSetProc.command = ["bash", "-c", 'dev=$(upower -e 2>/dev/null | grep -m1 BAT) && busctl call org.freedesktop.UPower "$dev" org.freedesktop.UPower.Device EnableChargeThreshold b "$1"', "_", value ? "true" : "false"];
    chargeSetProc.running = true;
  }

  Process {
    id: chargeSetProc
    onExited: function (exitCode) {
      root.chargeBusy = false;
      if (exitCode !== 0)
        root.log("charge-limit-failed", "exit " + exitCode);
      root.refreshCharge();
    }
  }

  // -------------------------------------------------------------------- idle

  // Looked up at call time: the first-party idle service may mount after us.
  function idleServiceNow() {
    return shell && typeof shell.serviceFor === "function" ? shell.serviceFor("omarchy.idle") : null;
  }

  // Writes the current strategy's timings into shell.json, which the
  // first-party idle service reads live, and flips stay-awake when the
  // strategy has nothing to fire. Nothing is written when nothing changed.
  function syncIdle() {
    var target = Model.idleConfigFor(strategy);
    if (Model.sameIdleConfig(appliedIdle, target))
      return;
    appliedIdle = target;
    if (shell && typeof shell.mutateShellConfig === "function") {
      shell.mutateShellConfig(function (config) {
        var idle = config.idle && typeof config.idle === "object" ? config.idle : {};
        idle.screensaver = target.screensaver;
        idle.lock = target.lock;
        config.idle = idle;
      });
    } else {
      log("idle-not-persisted", "shell has no mutateShellConfig");
    }
    var idleService = idleServiceNow();
    if (idleService && typeof idleService.setIdleEnabled === "function")
      idleService.setIdleEnabled(!target.stayAwake);
    else
      log("idle-service-missing", "stay-awake not applied");
    log("idle", source + " screensaver=" + target.screensaver + " lock=" + target.lock + " stayAwake=" + target.stayAwake);
  }

  function setDelay(src, field, seconds) {
    if (["screensaver", "lock", "sleep"].indexOf(field) === -1)
      return;
    var key = Model.sourceKey(src, field);
    var patch = {};
    patch[key] = Model.normalizeDelay(seconds, settings[key]);
    saveSettings(patch);
  }

  // ------------------------------------------------------------------ status

  function statusJson() {
    return JSON.stringify({
      source: root.source,
      batteryPresent: root.batteryPresent,
      settled: root.settled,
      profiles: root.profiles,
      activeProfile: root.activeProfile,
      settings: root.settings,
      strategy: root.strategy,
      appliedProfile: root.appliedProfile,
      appliedIdle: root.appliedIdle,
      externalScreen: root.externalScreen,
      screens: root.screenNames,
      lidInhibited: root.lidInhibited,
      lidBehavior: root.lidBehavior,
      charge: root.chargeState,
      chargeCapability: root.chargeCapability,
      lockService: !!root.lockService,
      locked: root.locked,
      sleepArmed: root.sleepArmed,
      queue: root.queue.length,
      lastEvent: root.lastEvent,
      lastEventAt: root.lastEventAt
    });
  }

  onSourceChanged: {
    log("source", source);
    refreshCharge();
    // The first-party battery service re-applies the persisted profile on a
    // source switch; ours makes sure the persisted values and idle timings
    // match this source's strategy.
    scheduleSync();
  }

  onShellChanged: readSettings()

  Component.onDestruction: {
    if (lidInhibitProc.running)
      lidInhibitProc.running = false;
  }

  Component.onCompleted: {
    readSettings();
    refreshProfiles();
    settleTimer.start();
    log("service-ready", "source=" + source);
  }
}
