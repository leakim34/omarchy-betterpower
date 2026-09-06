// Pure decisions for leakz.betterpower. No Qt imports: this file loads both from QML
// (import "Model.js" as Model) and from node (require) for the tests.

var SOURCES = ["battery", "ac"]
var PROFILES = ["power-saver", "balanced", "performance"]
var NEVER = 0
var MAX_DELAY = 86400

// Delay presets in seconds. 0 means never.
var DELAY_PRESETS = [60, 120, 300, 600, 900, 1800, 3600, NEVER]

// The idle service arms its monitor with the smaller of the two timings and a
// zero would fire at once, so a disabled step is written as a week and the
// whole cycle is switched off through stay-awake only when nothing fires.
var NEVER_IDLE_SECONDS = 604800

var DEFAULTS = {
  batteryProfile: "power-saver",
  batteryScreensaver: 120,
  batteryLock: 300,
  batterySleep: 600,
  acProfile: "performance",
  acScreensaver: NEVER,
  acLock: NEVER,
  acSleep: NEVER,
  clamshell: true,
  barMode: "off"
}

// What the bar entry shows besides the icon. Right click cycles through them.
// "both" is the percentage and the gauge together.
var BAR_MODES = ["off", "percentage", "gauge", "both"]
var GAUGE_LOW = 0.2

function normalizeBarMode(value, fallback) {
  var s = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
  return BAR_MODES.indexOf(s) >= 0 ? s : fallback
}

function barModeShows(mode) {
  var m = normalizeBarMode(mode, "off")
  return { percentage: m === "percentage" || m === "both", gauge: m === "gauge" || m === "both" }
}

function nextBarMode(mode) {
  var i = BAR_MODES.indexOf(normalizeBarMode(mode, "off"))
  return BAR_MODES[(i + 1) % BAR_MODES.length]
}

// Geometry and tone of the bar-wide gauge for a battery fraction in [0,1].
// The fill runs from the bar's start edge over `fraction` of its length.
// `low` flags the urgent tone; `alpha` is the fill opacity against the bar
// background, slightly stronger when low so it stays visible.
function gaugeSpec(fraction, charging) {
  var f = Math.max(0, Math.min(1, Number(fraction) || 0))
  var low = !charging && f > 0 && f <= GAUGE_LOW
  return { fraction: f, low: low, alpha: low ? 0.34 : 0.22 }
}

// The plugin's own entry in shell.json: a bar layout item or a plugins[]
// item whose id matches. Settings are the other fields on that entry.
function findEntry(config, id) {
  if (!config || typeof config !== "object") return null
  var sections = ["left", "center", "right"]
  var layout = config.bar && config.bar.layout && typeof config.bar.layout === "object" ? config.bar.layout : {}
  for (var s = 0; s < sections.length; s++) {
    var arr = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
    for (var i = 0; i < arr.length; i++) {
      if (arr[i] && arr[i].id === id) return arr[i]
    }
  }
  var plugins = Array.isArray(config.plugins) ? config.plugins : []
  for (var j = 0; j < plugins.length; j++) {
    if (plugins[j] && plugins[j].id === id) return plugins[j]
  }
  return null
}

function sourceKey(source, field) {
  return source + field.charAt(0).toUpperCase() + field.slice(1)
}

function sourceLabel(source) {
  return source === "battery" ? "On battery" : "Plugged in"
}

function normalizeDelay(value, fallback) {
  if (value === undefined || value === null || value === "") return fallback
  var n = Number(value)
  if (!isFinite(n) || n < 0) return fallback
  return Math.min(MAX_DELAY, Math.floor(n))
}

function normalizeProfile(value, fallback, available) {
  var list = Array.isArray(available) && available.length > 0 ? available : PROFILES
  var v = String(value === undefined || value === null ? "" : value)
  if (list.indexOf(v) !== -1) return v
  if (list.indexOf(fallback) !== -1) return fallback
  return list.indexOf("balanced") !== -1 ? "balanced" : list[0]
}

// The shell's settings screen stores enum toggles as "On"/"Off" strings while
// the panel stores booleans; both must read the same.
function normalizeBool(value, fallback) {
  if (typeof value === "boolean") return value
  if (typeof value === "number") return value !== 0
  var s = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
  if (s === "on" || s === "true" || s === "1" || s === "yes") return true
  if (s === "off" || s === "false" || s === "0" || s === "no") return false
  return fallback
}

// Every setting the plugin reads, coerced to a valid value. `available` is the
// profile list reported by omarchy-powerprofiles-list, or empty when unknown.
function normalizeSettings(raw, available) {
  var s = raw && typeof raw === "object" ? raw : {}
  var out = {}
  for (var i = 0; i < SOURCES.length; i++) {
    var src = SOURCES[i]
    var p = sourceKey(src, "profile")
    out[p] = normalizeProfile(s[p], DEFAULTS[p], available)
    var fields = ["screensaver", "lock", "sleep"]
    for (var j = 0; j < fields.length; j++) {
      var k = sourceKey(src, fields[j])
      out[k] = normalizeDelay(s[k], DEFAULTS[k])
    }
  }
  out.clamshell = normalizeBool(s.clamshell, DEFAULTS.clamshell)
  // Legacy `showPercentage: true` (pre 0.2.0) reads as the percentage mode.
  var legacy = normalizeBool(s.showPercentage, false) ? "percentage" : DEFAULTS.barMode
  out.barMode = normalizeBarMode(s.barMode, legacy)
  return out
}

// The strategy the service must apply for one source.
function strategyFor(source, settings) {
  var s = normalizeSettings(settings)
  var lock = s[sourceKey(source, "lock")]
  return {
    source: source,
    profile: s[sourceKey(source, "profile")],
    screensaver: s[sourceKey(source, "screensaver")],
    lock: lock,
    // Sleep is armed only after the lock fired, so never-lock implies never-sleep.
    sleep: lock === NEVER ? NEVER : s[sourceKey(source, "sleep")],
    stayAwake: lock === NEVER && s[sourceKey(source, "screensaver")] === NEVER
  }
}

// What the service writes for one strategy: the idle keys of shell.json and
// whether the idle cycle must be disabled altogether.
function idleConfigFor(strategy) {
  var screensaver = strategy.screensaver === NEVER ? NEVER_IDLE_SECONDS : strategy.screensaver
  var lock = strategy.lock === NEVER ? NEVER_IDLE_SECONDS : strategy.lock
  return { screensaver: screensaver, lock: lock, stayAwake: !!strategy.stayAwake }
}

function sameIdleConfig(a, b) {
  if (!a || !b) return false
  return a.screensaver === b.screensaver && a.lock === b.lock && a.stayAwake === b.stayAwake
}

// UPower's ChargeThresholdSettingsSupported bitmask.
var CHARGE_START = 1
var CHARGE_END = 2
var CHARGE_FIRMWARE = 4

// Output of the charge probe script: "key\tvalue" lines from busctl.
function parseChargeState(raw) {
  var out = { supported: false, settings: 0, enabled: false, start: 0, end: 0 }
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t")
    var key = String(parts[0] || "").trim()
    var value = String(parts[1] || "").trim()
    if (key === "supported") out.supported = value === "true"
    else if (key === "settings") out.settings = Number(value) || 0
    else if (key === "enabled") out.enabled = value === "true"
    else if (key === "start") out.start = Number(value) || 0
    else if (key === "end") out.end = Number(value) || 0
  }
  return out
}

// What the panel shows for a charge state: whether the control exists and
// how to describe what enabling it does on this hardware.
function chargeCapability(state) {
  var s = state || {}
  var mask = Number(s.settings) || 0
  var firmware = (mask & CHARGE_FIRMWARE) !== 0
  var end = (mask & CHARGE_END) !== 0
  var start = (mask & CHARGE_START) !== 0
  if (!s.supported || (!firmware && !end)) {
    return { available: false, mode: "none", description: "This battery does not report charge control." }
  }
  if (end) {
    var range = s.enabled && Number(s.end) > 0
      ? (start && Number(s.start) > 0 ? "Charges between " + s.start + "% and " + s.end + "%." : "Charging stops at " + s.end + "%.")
      : "Stops charging before full to preserve battery life."
    return { available: true, mode: "threshold", description: range }
  }
  return {
    available: true,
    mode: "firmware",
    description: "The firmware limits the charge to preserve battery life (conservation mode)."
  }
}

// Internal panels are eDP, LVDS or DSI connectors; anything else is external.
function isExternalScreen(name) {
  return !/^(eDP|LVDS|DSI)-/i.test(String(name || ""))
}

function hasExternalScreen(names) {
  var list = Array.isArray(names) ? names : []
  for (var i = 0; i < list.length; i++) {
    if (isExternalScreen(list[i])) return true
  }
  return false
}

// Whether the lid inhibitor must be held, and the sentence the panel shows.
function lidBehavior(clamshell, external) {
  if (!external) {
    return { inhibit: false, description: "No external screen: closing the lid locks and follows the system's lid setting." }
  }
  if (clamshell) {
    return { inhibit: true, description: "Closing the lid keeps the session running on the external screen." }
  }
  return { inhibit: false, description: "Closing the lid follows the system's lid setting." }
}

// ---- Battery hero. Ported from the first-party power panel (Omarchy,
// shell/plugins/panels/power/Model.js) so both panels read the same way.

// Output of `omarchy-battery-status --shell`: "key\tvalue" lines.
function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf("\t")
    if (idx <= 0) continue
    next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
  }
  return next
}

function batteryFraction(device) {
  return device && device.isPresent ? Math.max(0, Math.min(1, Number(device.percentage) || 0)) : 0
}

// `states` carries the UPowerDeviceState enum values the QML side knows.
function chargeThresholdActive(device, onBattery, states) {
  var d = device || {}
  var s = states || {}
  if (!(d.isPresent && !onBattery)) return false
  var fraction = batteryFraction(d)
  if (d.state === s.Discharging) return false
  if (d.state === s.PendingCharge) return true
  if (d.state === s.FullyCharged && fraction < 0.99) return true
  if (d.state !== s.Charging || fraction >= 0.99) return false
  return Number(d.changeRate || 0) <= 0.2 || Number(d.timeToFull || 0) >= 8 * 60 * 60
}

var CHARGING_ICONS = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
var LEVEL_ICONS = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

function batteryIcon(device, onBattery, states) {
  var d = device || {}
  if (!d.isPresent) return "󰚥"
  var index = Math.max(0, Math.min(9, Math.floor(batteryFraction(d) * 10)))
  if (chargeThresholdActive(d, onBattery, states)) return LEVEL_ICONS[index]
  if (states && d.state === states.FullyCharged) return "󰂅"
  if (!onBattery) return CHARGING_ICONS[index]
  return LEVEL_ICONS[index]
}

function modeLabel(device, onBattery, states) {
  var d = device || {}
  if (!d.isPresent) return "No battery"
  if (chargeThresholdActive(d, onBattery, states)) return "Threshold"
  if (onBattery) return "On battery"
  if (batteryFraction(d) >= 1) return "Fully charged"
  return "Charging"
}

var CHARGING_PHRASES = ["Pumping power", "Injecting electrons", "Pouring juice", "Amassing watts", "Hoarding joules", "Topping reserves", "Soaking amps"]
var ON_BATTERY_PHRASES = ["Slurping power", "Spending joules", "Draining watts", "Burning electrons", "Sipping juice", "Munching reserves"]

// What the charge limit cell reads: the plugin's live UPower state, with the
// threshold string from omarchy-battery-status when the hardware reports one.
function chargeLimitLabel(chargeState, thresholdText) {
  var s = chargeState || {}
  if (!s.supported) return "-"
  if (!s.enabled) return "Off"
  if (thresholdText) return String(thresholdText)
  if (Number(s.end) > 0) return s.end + "%"
  return "On"
}

function delayLabel(seconds) {
  var n = normalizeDelay(seconds, NEVER)
  if (n === NEVER) return "Never"
  if (n < 60) return n + " s"
  if (n % 3600 === 0) return (n / 3600) + " h"
  if (n % 60 === 0) return (n / 60) + " min"
  return Math.floor(n / 60) + " min " + (n % 60) + " s"
}

function delayOptions(current) {
  var list = DELAY_PRESETS.slice()
  var n = normalizeDelay(current, NEVER)
  if (list.indexOf(n) === -1) list.push(n)
  list.sort(function(a, b) {
    if (a === NEVER) return 1
    if (b === NEVER) return -1
    return a - b
  })
  var out = []
  for (var i = 0; i < list.length; i++) out.push({ value: String(list[i]), label: delayLabel(list[i]) })
  return out
}

// Output of `omarchy-powerprofiles-list --active-state`: one "name\t1|0" per line.
function parseProfiles(raw) {
  var profiles = []
  var active = ""
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split("\t")
    var name = String(parts[0] || "").trim()
    if (!name) continue
    profiles.push(name)
    if (String(parts[1] || "").trim() === "1") active = name
  }
  return { profiles: profiles, active: active }
}

function profileOptions(profiles) {
  var list = Array.isArray(profiles) && profiles.length > 0 ? profiles : PROFILES
  var out = []
  for (var i = 0; i < list.length; i++) {
    out.push({ value: list[i], label: profileLabel(list[i]), icon: profileIcon(list[i]) })
  }
  return out
}

function profileIcon(name) {
  if (name === "performance") return "󰓅"
  if (name === "power-saver") return "󰌪"
  return "󰾅"
}

function profileLabel(name) {
  if (name === "power-saver") return "Eco"
  return String(name).charAt(0).toUpperCase() + String(name).slice(1)
}

if (typeof module !== "undefined") {
  module.exports = {
    SOURCES: SOURCES,
    PROFILES: PROFILES,
    NEVER: NEVER,
    DELAY_PRESETS: DELAY_PRESETS,
    NEVER_IDLE_SECONDS: NEVER_IDLE_SECONDS,
    idleConfigFor: idleConfigFor,
    CHARGE_START: CHARGE_START,
    CHARGE_END: CHARGE_END,
    CHARGE_FIRMWARE: CHARGE_FIRMWARE,
    isExternalScreen: isExternalScreen,
    hasExternalScreen: hasExternalScreen,
    lidBehavior: lidBehavior,
    parseKeyValue: parseKeyValue,
    batteryFraction: batteryFraction,
    chargeThresholdActive: chargeThresholdActive,
    batteryIcon: batteryIcon,
    modeLabel: modeLabel,
    CHARGING_PHRASES: CHARGING_PHRASES,
    ON_BATTERY_PHRASES: ON_BATTERY_PHRASES,
    chargeLimitLabel: chargeLimitLabel,
    parseChargeState: parseChargeState,
    chargeCapability: chargeCapability,
    sameIdleConfig: sameIdleConfig,
    DEFAULTS: DEFAULTS,
    findEntry: findEntry,
    sourceKey: sourceKey,
    sourceLabel: sourceLabel,
    normalizeDelay: normalizeDelay,
    normalizeProfile: normalizeProfile,
    normalizeBool: normalizeBool,
    BAR_MODES: BAR_MODES,
    GAUGE_LOW: GAUGE_LOW,
    normalizeBarMode: normalizeBarMode,
    nextBarMode: nextBarMode,
    gaugeSpec: gaugeSpec,
    barModeShows: barModeShows,
    normalizeSettings: normalizeSettings,
    strategyFor: strategyFor,
    delayLabel: delayLabel,
    delayOptions: delayOptions,
    parseProfiles: parseProfiles,
    profileOptions: profileOptions,
    profileIcon: profileIcon,
    profileLabel: profileLabel
  }
}
