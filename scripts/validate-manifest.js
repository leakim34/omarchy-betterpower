#!/usr/bin/env node
// Mirrors the checks of `omarchy plugin validate` so lint and CI can run on a
// machine without Omarchy. When omarchy is installed, scripts/lint.sh runs the
// real validator as well; this one is the floor, never a replacement.
"use strict";
const fs = require("node:fs");
const path = require("node:path");

const KIND_ENTRY = {
  bar: "bar",
  "bar-widget": "barWidget",
  menu: "menu",
  overlay: "overlay",
  panel: "panel",
  service: "service",
};

function walkForSymlinks(dir, out) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === ".git" || entry.name === "node_modules") continue;
    const full = path.join(dir, entry.name);
    if (entry.isSymbolicLink()) out.push(full);
    else if (entry.isDirectory()) walkForSymlinks(full, out);
  }
  return out;
}

function validate(pluginDir) {
  const errors = [];
  const manifestPath = path.join(pluginDir, "manifest.json");
  if (!fs.existsSync(manifestPath)) return ["missing manifest.json"];
  let m;
  try {
    m = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  } catch (e) {
    return ["manifest.json is not valid JSON: " + e.message];
  }
  if (m.schemaVersion !== 1) errors.push("schemaVersion must be the number 1");
  for (const f of ["id", "name", "version", "kinds", "entryPoints"]) {
    if (!(f in m)) errors.push("missing required field '" + f + "'");
  }
  for (const f of ["author", "description", "license"]) {
    if (!m[f]) errors.push("marketplace field '" + f + "' is empty");
  }
  const id = String(m.id || "");
  if (!id) errors.push("id is empty");
  else if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(id) || id.includes("..")) errors.push("invalid id '" + id + "'");
  else if (id.startsWith("omarchy.")) errors.push("id uses the reserved omarchy.* namespace");
  if (!Array.isArray(m.kinds) || m.kinds.length === 0) errors.push("kinds must be a non-empty array");
  if (!m.entryPoints || typeof m.entryPoints !== "object" || Array.isArray(m.entryPoints)) {
    errors.push("entryPoints must be an object");
  } else {
    for (const [key, ep] of Object.entries(m.entryPoints)) {
      const p = String(ep);
      if (!p) errors.push("entry point '" + key + "' is empty");
      else if (p.includes("\n")) errors.push("entry point '" + key + "' contains a newline");
      else if (p.startsWith("/")) errors.push("entry point '" + key + "' must be relative");
      else if (p.includes("..")) errors.push("entry point '" + key + "' may not contain '..'");
      else if (!fs.existsSync(path.join(pluginDir, p))) errors.push("entry point file not found: '" + p + "'");
    }
    for (const kind of Array.isArray(m.kinds) ? m.kinds : []) {
      const ep = KIND_ENTRY[kind];
      if (ep && !(ep in m.entryPoints)) errors.push("kind '" + kind + "' requires entryPoints." + ep);
    }
  }
  if (m.barWidget && typeof m.barWidget === "object") {
    const s = m.barWidget.defaultSection;
    if (s !== undefined && !["left", "center", "right"].includes(s)) errors.push("barWidget.defaultSection must be left, center, or right");
    const schema = Array.isArray(m.barWidget.schema) ? m.barWidget.schema : [];
    const defaults = m.barWidget.defaults || {};
    for (const key of Object.keys(defaults)) {
      if (!schema.some((entry) => entry && entry.key === key)) errors.push("barWidget.defaults." + key + " has no schema entry");
    }
  }
  for (const link of walkForSymlinks(pluginDir, [])) errors.push("symlink inside plugin folder: " + link);
  return errors;
}

module.exports = { validate };

if (require.main === module) {
  const dir = path.resolve(process.argv[2] || ".");
  const errors = validate(dir);
  for (const e of errors) console.error("validate-manifest: " + e);
  process.exit(errors.length ? 1 : 0);
}
