/**
 * Hermetic tests for the bundle plugin. Builds a throwaway DSH_HOME with a
 * profile fixture, applies the plugin to a fake ctx, and exercises every tool
 * through its real execute() path plus its render().
 *
 * Run: node test/run.mjs     (or with the harness binary in node mode)
 */

import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";

const home = await mkdtemp(path.join(tmpdir(), "dsh-hub-test-"));
process.env.DSH_HOME = home;

const { apply, name, inject } = await import("../lib/index.js");

const profileDir = path.join(home, "profiles", "desktop");
await mkdir(path.join(profileDir, "node_modules", "dsh-hindsight"), { recursive: true });
await writeFile(
  path.join(profileDir, "package.json"),
  JSON.stringify(
    {
      name: "dsh-profile-desktop",
      private: true,
      dependencies: { "dsh-hindsight": "^0.4.0", "dsh-obsidian": "^0.2.6" },
      dsh: {
        profile: {
          bundles: ["@deepseek-ai/dsh-base", "dsh-hindsight", "dsh-obsidian"],
        },
      },
    },
    null,
    2,
  ),
);
await writeFile(
  path.join(profileDir, "node_modules", "dsh-hindsight", "package.json"),
  JSON.stringify({ name: "dsh-hindsight", version: "0.4.0" }),
);
await mkdir(path.join(home, "skills", "agent-browser"), { recursive: true });
await mkdir(path.join(home, "skills", "skill-scanner"), { recursive: true });
await writeFile(path.join(home, "skills", "NOT-A-SKILL.md"), "# stray file\n");

const registered = [];
const ctx = {
  tools: { register: (tool) => (registered.push(tool), () => {}) },
  effect: (fn) => fn(),
};
apply(ctx, { profile: "desktop", services: [{ name: "hindsight", port: 1 }] });

assert.equal(name, "dsh-control-hub");
assert.deepEqual(inject, ["tools"]);
assert.equal(registered.length, 3, "three tools registered");
assert.deepEqual(registered.map((t) => t.name).sort(), ["hub_check", "hub_plugins", "hub_route"]);

const byName = Object.fromEntries(registered.map((t) => [t.name, t]));
const asText = (tool, args, value) =>
  tool.output.render(args, value).map((b) => b.text).join("\n");

// --- hub_plugins -----------------------------------------------------------
const inv = await byName.hub_plugins.execute({});
assert.equal(inv.bundles.length, 3);
const builtin = inv.bundles.find((b) => b.name === "@deepseek-ai/dsh-base");
assert.equal(builtin.builtin, true);
assert.equal(builtin.present, true, "platform bundles are provided by the harness");
const hindsight = inv.bundles.find((b) => b.name === "dsh-hindsight");
assert.equal(hindsight.version, "0.4.0");
assert.equal(hindsight.present, true);
const obsidian = inv.bundles.find((b) => b.name === "dsh-obsidian");
assert.equal(obsidian.present, false, "declared but not on disk");
assert.deepEqual(inv.skills.map((s) => s.name).sort(), ["agent-browser", "skill-scanner"], "files are not skills");
assert.match(asText(byName.hub_plugins, {}, inv), /MISS\s+dsh-obsidian/);
assert.match(asText(byName.hub_plugins, {}, inv), /BUILTIN\s+@deepseek-ai\/dsh-base/);

// --- hub_check -------------------------------------------------------------
const check = await byName.hub_check.execute({});
const checkText = asText(byName.hub_check, {}, check);
assert.equal(check.failed, 1, "only the genuinely missing third-party bundle fails");
assert.match(checkText, /\[FAIL\]/);
assert.match(checkText, /platform bundle\(s\) provided by the harness/);
assert.match(checkText, /not listening/, "closed port warns");
assert.match(checkText, /skills directory reachable/);

// --- hub_route -------------------------------------------------------------
const route = await byName.hub_route.execute({ query: "remember this across sessions" });
assert.ok(route.matches.length > 0, "route found");
assert.equal(route.matches[0].plugin, "dsh-hindsight");
assert.equal(route.matches[0].available, "installed");
assert.match(asText(byName.hub_route, {}, route), /dsh-hindsight/);

const skillRoute = await byName.hub_route.execute({ query: "scan a skill before install" });
const sc = skillRoute.matches.find((m) => m.plugin === "skill-scanner");
assert.equal(sc.available, "installed (skill)", "skills count towards availability");

const miss = await byName.hub_route.execute({ query: "zzzznothing" });
assert.equal(miss.matches.length, 0);
assert.match(asText(byName.hub_route, {}, miss), /No routing-table entry/);

// routing table is well-formed data, not just a blob in code
const table = JSON.parse(
  await (await import("node:fs/promises")).readFile(new URL("../lib/routing-table.json", import.meta.url), "utf8"),
);
assert.ok(table.routes.length >= 10);
for (const r of table.routes) {
  assert.ok(r.intent && r.plugin && typeof r.entry === "string", `route ${r.plugin} is complete`);
}

// --- argument validation is not silently lenient ---------------------------
await assert.rejects(() => byName.hub_route.execute({}), /bad args/, "query is required");

// --- profile resolution: config wins, then DSH_PROFILE ----------------------
await mkdir(path.join(home, "profiles", "work"), { recursive: true });
await writeFile(
  path.join(home, "profiles", "work", "package.json"),
  JSON.stringify({ name: "dsh-profile-work", private: true, dsh: { profile: { bundles: [] } } }),
);
const envTools = new Map();
apply(
  { tools: { register: (t) => (envTools.set(t.name, t), () => {}) }, effect: (fn) => fn() },
  {},
);
process.env.DSH_PROFILE = "work";
const viaEnv = await envTools.get("hub_plugins").execute({});
assert.match(viaEnv.profileDir, /profiles[\\/]work$/, "DSH_PROFILE is honoured when config is empty");
process.env.DSH_PROFILE = "";
const viaConfig = await envTools.get("hub_plugins").execute({ profile: "desktop" });
assert.match(viaConfig.profileDir, /profiles[\\/]desktop$/, "explicit config still wins");

await rm(home, { recursive: true, force: true });
console.log(
  `PASS: 3 tools registered; inventory ${inv.bundles.length} bundles / ${inv.skills.length} skills; ` +
    `hub_check found ${check.failed} FAIL; routing table ${table.routes.length} entries.`,
);
