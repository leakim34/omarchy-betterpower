"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("../Model.js");

test("defaults apply when settings are missing or garbage", () => {
  assert.deepEqual(M.normalizeSettings(undefined), M.DEFAULTS);
  const s = M.normalizeSettings({ batteryLock: "nope", acProfile: 42, clamshell: "maybe", batterySleep: -5 });
  assert.equal(s.batteryLock, M.DEFAULTS.batteryLock);
  assert.equal(s.acProfile, M.DEFAULTS.acProfile);
  assert.equal(s.clamshell, M.DEFAULTS.clamshell);
  assert.equal("chargeLimit" in s, false);
  assert.equal(s.batterySleep, M.DEFAULTS.batterySleep);
});

test("delays are floored, clamped and accept numeric strings", () => {
  assert.equal(M.normalizeDelay("90.7", 1), 90);
  assert.equal(M.normalizeDelay(1e9, 1), 86400);
  assert.equal(M.normalizeDelay(0, 1), 0);
  assert.equal(M.normalizeDelay(null, 7), 7);
});

test("profiles fall back to what the system offers", () => {
  assert.equal(M.normalizeProfile("performance", "balanced", ["balanced", "power-saver"]), "balanced");
  assert.equal(M.normalizeProfile("x", "performance", ["power-saver"]), "power-saver");
  assert.equal(M.normalizeProfile("power-saver", "balanced", []), "power-saver");
});

test("booleans read the settings screen's On/Off strings", () => {
  assert.equal(M.normalizeBool("On", false), true);
  assert.equal(M.normalizeBool("off", true), false);
  assert.equal(M.normalizeBool(1, false), true);
  assert.equal(M.normalizeBool("", true), true);
});

test("strategy: never-lock implies never-sleep and stay-awake only when nothing fires", () => {
  const ac = M.strategyFor("ac", { acLock: 0, acSleep: 600, acScreensaver: 0 });
  assert.equal(ac.sleep, 0);
  assert.equal(ac.stayAwake, true);
  const acSaver = M.strategyFor("ac", { acLock: 0, acScreensaver: 120 });
  assert.equal(acSaver.stayAwake, false);
  const bat = M.strategyFor("battery", {});
  assert.deepEqual(bat, { source: "battery", profile: "power-saver", screensaver: 120, lock: 300, sleep: 600, stayAwake: false });
});

test("delay labels and options", () => {
  assert.equal(M.delayLabel(0), "Never");
  assert.equal(M.delayLabel(45), "45 s");
  assert.equal(M.delayLabel(600), "10 min");
  assert.equal(M.delayLabel(3600), "1 h");
  assert.equal(M.delayLabel(90), "1 min 30 s");
  const opts = M.delayOptions(420);
  assert.equal(opts[opts.length - 1].label, "Never");
  assert.ok(opts.some((o) => o.value === "420" && o.label === "7 min"));
  assert.equal(M.delayOptions(600).length, M.DELAY_PRESETS.length);
});

test("labels and icons", () => {
  assert.equal(M.profileLabel("power-saver"), "Eco");
  assert.equal(M.profileLabel("balanced"), "Balanced");
  assert.equal(M.sourceLabel("ac"), "Plugged in");
  assert.equal(M.sourceKey("battery", "lock"), "batteryLock");
  assert.notEqual(M.profileIcon("performance"), M.profileIcon("balanced"));
});

test("parses the powerprofiles list with its active marker", () => {
  const r = M.parseProfiles("power-saver\t0\nbalanced\t1\nperformance\t0\n");
  assert.deepEqual(r, { profiles: ["power-saver", "balanced", "performance"], active: "balanced" });
  assert.deepEqual(M.parseProfiles(""), { profiles: [], active: "" });
  assert.deepEqual(M.parseProfiles("balanced\n"), { profiles: ["balanced"], active: "" });
});

test("profile options carry label and icon and fall back to the known set", () => {
  const opts = M.profileOptions(["balanced", "power-saver"]);
  assert.deepEqual(opts.map((o) => o.value), ["balanced", "power-saver"]);
  assert.equal(opts[1].label, "Eco");
  assert.ok(opts.every((o) => o.icon.length > 0));
  assert.equal(M.profileOptions([]).length, M.PROFILES.length);
});

test("idle config maps never to a week and disables the cycle only when nothing fires", () => {
  const both = M.idleConfigFor(M.strategyFor("ac", { acScreensaver: 0, acLock: 0 }));
  assert.deepEqual(both, { screensaver: M.NEVER_IDLE_SECONDS, lock: M.NEVER_IDLE_SECONDS, stayAwake: true });
  const saverOnly = M.idleConfigFor(M.strategyFor("ac", { acScreensaver: 120, acLock: 0 }));
  assert.deepEqual(saverOnly, { screensaver: 120, lock: M.NEVER_IDLE_SECONDS, stayAwake: false });
  const lockOnly = M.idleConfigFor(M.strategyFor("battery", { batteryScreensaver: 0, batteryLock: 300 }));
  assert.deepEqual(lockOnly, { screensaver: M.NEVER_IDLE_SECONDS, lock: 300, stayAwake: false });
  assert.ok(M.sameIdleConfig(both, M.idleConfigFor(M.strategyFor("ac", { acScreensaver: 0, acLock: 0 }))));
  assert.ok(!M.sameIdleConfig(both, saverOnly));
  assert.ok(!M.sameIdleConfig(null, both));
});

test("finds the plugin entry in the bar layout or the plugins list", () => {
  const cfg = { bar: { layout: { left: [], right: [{ id: "x" }, { id: "leakz.power", acLock: 5 }] } }, plugins: [{ id: "leakz.power", acLock: 9 }] };
  assert.equal(M.findEntry(cfg, "leakz.power").acLock, 5);
  assert.equal(M.findEntry({ plugins: [{ id: "leakz.power", acLock: 9 }] }, "leakz.power").acLock, 9);
  assert.equal(M.findEntry({}, "leakz.power"), null);
  assert.equal(M.findEntry(null, "leakz.power"), null);
});

test("charge state parses busctl lines and tolerates garbage", () => {
  const st = M.parseChargeState("supported\ttrue\nsettings\t4\nenabled\tfalse\nstart\t0\nend\t0\n");
  assert.deepEqual(st, { supported: true, settings: 4, enabled: false, start: 0, end: 0 });
  assert.deepEqual(M.parseChargeState(""), { supported: false, settings: 0, enabled: false, start: 0, end: 0 });
  assert.equal(M.parseChargeState("settings\tabc\n").settings, 0);
});

test("charge capability follows the settings bitmask", () => {
  assert.equal(M.chargeCapability({ supported: false, settings: 4 }).available, false);
  assert.equal(M.chargeCapability({ supported: true, settings: 0 }).available, false);
  const fw = M.chargeCapability({ supported: true, settings: 4, enabled: true });
  assert.equal(fw.mode, "firmware");
  const th = M.chargeCapability({ supported: true, settings: 2, enabled: true, end: 80 });
  assert.equal(th.mode, "threshold");
  assert.match(th.description, /80%/);
  const both = M.chargeCapability({ supported: true, settings: 3, enabled: true, start: 60, end: 80 });
  assert.match(both.description, /60% and 80%/);
  assert.match(M.chargeCapability({ supported: true, settings: 2, enabled: false }).description, /before full/);
  assert.equal(M.chargeCapability(null).available, false);
});

test("external screens are anything but eDP, LVDS and DSI", () => {
  assert.equal(M.isExternalScreen("eDP-1"), false);
  assert.equal(M.isExternalScreen("LVDS-1"), false);
  assert.equal(M.isExternalScreen("DP-1"), true);
  assert.equal(M.isExternalScreen("HDMI-A-1"), true);
  assert.equal(M.hasExternalScreen(["eDP-1"]), false);
  assert.equal(M.hasExternalScreen(["eDP-1", "DP-3"]), true);
  assert.equal(M.hasExternalScreen([]), false);
});

test("lid behavior inhibits only with the toggle on and an external screen", () => {
  assert.equal(M.lidBehavior(true, true).inhibit, true);
  assert.equal(M.lidBehavior(true, false).inhibit, false);
  assert.equal(M.lidBehavior(false, true).inhibit, false);
  assert.match(M.lidBehavior(true, false).description, /No external screen/);
});

const STATES = { Charging: 1, Discharging: 2, FullyCharged: 4, PendingCharge: 5 };

test("battery hero: key/value parsing, fraction, icon and label", () => {
  assert.deepEqual(M.parseKeyValue("percentage\t83%\nstate\tpending-charge\nbad line\n"), { percentage: "83%", state: "pending-charge" });
  assert.equal(M.batteryFraction({ isPresent: true, percentage: 0.83 }), 0.83);
  assert.equal(M.batteryFraction({ isPresent: false, percentage: 0.5 }), 0);
  const holding = { isPresent: true, percentage: 0.83, state: STATES.PendingCharge };
  assert.equal(M.chargeThresholdActive(holding, false, STATES), true);
  assert.equal(M.chargeThresholdActive(holding, true, STATES), false);
  assert.equal(M.modeLabel(holding, false, STATES), "Threshold");
  assert.equal(M.modeLabel({ isPresent: true, percentage: 0.5, state: STATES.Discharging }, true, STATES), "On battery");
  assert.equal(M.modeLabel({ isPresent: true, percentage: 1, state: STATES.FullyCharged }, false, STATES), "Fully charged");
  assert.equal(M.modeLabel({ isPresent: false }, false, STATES), "No battery");
  assert.equal(M.batteryIcon({ isPresent: true, percentage: 0.5, state: STATES.Charging, changeRate: 20 }, false, STATES), "󰂉");
  assert.equal(M.batteryIcon({ isPresent: true, percentage: 0.5, state: STATES.Discharging }, true, STATES), "󰁿");
  assert.equal(M.batteryIcon({ isPresent: false }, true, STATES), "󰚥");
});

test("charge limit label follows the plugin's UPower state", () => {
  assert.equal(M.chargeLimitLabel({ supported: false }, ""), "-");
  assert.equal(M.chargeLimitLabel({ supported: true, enabled: false }, "80%"), "Off");
  assert.equal(M.chargeLimitLabel({ supported: true, enabled: true }, "60-80%"), "60-80%");
  assert.equal(M.chargeLimitLabel({ supported: true, enabled: true, end: 80 }, ""), "80%");
  assert.equal(M.chargeLimitLabel({ supported: true, enabled: true }, ""), "On");
});
