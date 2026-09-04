// Pure decisions for leakz.power. No Qt imports: this file loads both from QML
// (import "Model.js" as Model) and from node (require) for the tests.

var SOURCES = ["battery", "ac"]
var PROFILES = ["power-saver", "balanced", "performance"]
var NEVER = 0
var MAX_DELAY = 86400

// Delay presets in seconds. 0 means never.
var DELAY_PRESETS = [60, 120, 300, 600, 900, 1800, 3600, NEVER]

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
  chargeLimit: false
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
  out.chargeLimit = normalizeBool(s.chargeLimit, DEFAULTS.chargeLimit)
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
    DEFAULTS: DEFAULTS,
    sourceKey: sourceKey,
    sourceLabel: sourceLabel,
    normalizeDelay: normalizeDelay,
    normalizeProfile: normalizeProfile,
    normalizeBool: normalizeBool,
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
