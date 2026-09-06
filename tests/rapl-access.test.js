"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const path = require("node:path");

const helper = path.join(__dirname, "..", "bin", "leakz-power-rapl-access");
const run = (args) => spawnSync("bash", [helper, ...args], { encoding: "utf8" });

test("helper rejects missing or unknown arguments with exit 2", () => {
  assert.equal(run([]).status, 2);
  assert.equal(run(["bogus"]).status, 2);
  assert.equal(run(["install", "extra"]).status, 2);
});

test("helper refuses to act without root with exit 1", () => {
  if (process.getuid && process.getuid() === 0) return;
  const r = run(["install"]);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /root/);
  assert.equal(run(["remove"]).status, 1);
});
