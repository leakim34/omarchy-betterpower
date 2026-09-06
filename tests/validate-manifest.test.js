"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { validate } = require("../scripts/validate-manifest.js");

function plugin(manifest, files = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "omarchy-betterpower-"));
  for (const [name, body] of Object.entries(files)) fs.writeFileSync(path.join(dir, name), body);
  if (manifest !== null) fs.writeFileSync(path.join(dir, "manifest.json"), typeof manifest === "string" ? manifest : JSON.stringify(manifest));
  return dir;
}

const good = {
  schemaVersion: 1,
  id: "leakz.test",
  name: "Test",
  version: "0.1.0",
  author: "leakz",
  description: "d",
  license: "MIT",
  kinds: ["bar-widget", "service"],
  entryPoints: { barWidget: "BarWidget.qml", service: "Service.qml" },
  barWidget: { defaultSection: "right", defaults: { a: 1 }, schema: [{ key: "a" }] },
};
const goodFiles = { "BarWidget.qml": "", "Service.qml": "" };

test("accepts a complete manifest", () => {
  assert.deepEqual(validate(plugin(good, goodFiles)), []);
});

test("rejects missing manifest and invalid json", () => {
  assert.match(validate(plugin(null))[0], /missing manifest/);
  assert.match(validate(plugin("{nope"))[0], /not valid JSON/);
});

test("rejects reserved id, string schemaVersion and missing entry point", () => {
  const errors = validate(plugin({ ...good, id: "omarchy.x", schemaVersion: "1", entryPoints: { barWidget: "BarWidget.qml" } }, goodFiles));
  assert.ok(errors.some((e) => /reserved/.test(e)));
  assert.ok(errors.some((e) => /schemaVersion/.test(e)));
  assert.ok(errors.some((e) => /requires entryPoints.service/.test(e)));
});

test("rejects unsafe entry points and symlinks", () => {
  const dir = plugin({ ...good, entryPoints: { barWidget: "../x.qml", service: "/abs.qml" }, kinds: ["bar-widget", "service"] }, goodFiles);
  fs.symlinkSync("/etc/hostname", path.join(dir, "link"));
  const errors = validate(dir);
  assert.ok(errors.some((e) => /'\.\.'/.test(e)));
  assert.ok(errors.some((e) => /relative/.test(e)));
  assert.ok(errors.some((e) => /symlink/.test(e)));
});

test("every default needs a schema entry", () => {
  const errors = validate(plugin({ ...good, barWidget: { defaults: { b: 2 }, schema: [] } }, goodFiles));
  assert.deepEqual(errors, ["barWidget.defaults.b has no schema entry"]);
});
