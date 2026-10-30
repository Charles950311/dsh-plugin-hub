/**
 * dsh-control-hub — inventory, health checks and dispatch routing for the
 * plugins and skills installed in a DeepSeek Harness profile.
 *
 * Read-only by design: nothing here installs, removes or patches a plugin.
 * Every answer is derived from local files plus optional TCP probes.
 */

import net from "node:net";
import path from "node:path";
import { homedir } from "node:os";
import { lstat, readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { defineTool } from "@deepseek-ai/dsh-tools";

const name = "dsh-control-hub";
const inject = ["tools"];

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROUTING_TABLE = path.join(HERE, "routing-table.json");
const DEFAULT_SERVICES = [{ name: "hindsight", port: 8888 }];

function dshHome() {
  return process.env.DSH_HOME || path.join(homedir(), ".dsh");
}

function profileDir(cfg) {
  return path.join(dshHome(), "profiles", cfg?.profile || "desktop");
}

function skillsDir(cfg) {
  return cfg?.skillsDir || path.join(dshHome(), "skills");
}

async function readJson(file) {
  try {
    return JSON.parse(await readFile(file, "utf8"));
  } catch {
    return null;
  }
}

async function exists(p) {
  try {
    await lstat(p);
    return true;
  } catch {
    return false;
  }
}

/** TCP probe with a hard timeout; resolves false instead of throwing. */
function portOpen(port, timeoutMs = 700) {
  return new Promise((resolve) => {
    const socket = new net.Socket();
    let settled = false;
    const done = (value) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(value);
    };
    socket.setTimeout(timeoutMs);
    socket.once("connect", () => done(true));
    socket.once("timeout", () => done(false));
    socket.once("error", () => done(false));
    socket.connect(port, "127.0.0.1");
  });
}

/**
 * Bundles declared by the profile manifest, cross-checked against disk.
 * A `link:` or `file:` dependency still has to be present under node_modules
 * for the harness to load it, so presence on disk is the honest signal.
 * `@deepseek-ai/*` bundles ship inside the harness itself (app.asar), so a
 * missing node_modules copy is normal and must not read as a fault.
 */
async function inventory(cfg) {
  const dir = profileDir(cfg);
  const manifest = await readJson(path.join(dir, "package.json"));
  const deps = manifest?.dependencies ?? {};
  const declared = manifest?.dsh?.profile?.bundles ?? Object.keys(deps);
  const rows = [];

  for (const bundle of declared) {
    const spec = deps[bundle] ?? null;
    const builtin = bundle.startsWith("@deepseek-ai/");
    const installed = await readJson(
      path.join(dir, "node_modules", ...bundle.split("/"), "package.json"),
    );
    let version = installed?.version ?? null;
    if (!version && spec) {
      const v = /^[\^~]?(\d+\.\d+\.\d+.*)$/.exec(spec);
      version = v ? v[1].replace(/^[~^]/, "") : spec.startsWith("link:") || spec.startsWith("file:") ? "local" : null;
    }
    if (!version && builtin) version = "built-in";
    rows.push({
      bundle,
      version: version ?? "unknown",
      builtin,
      declared: true,
      present:
        builtin ||
        Boolean(installed) ||
        (await exists(path.join(dir, "node_modules", ...bundle.split("/")))),
    });
  }
  return { dir, manifest, rows };
}

/**
 * Entries under the harness skills directory, with junction targets when
 * available. Only directories and links count — a stray file is not a skill.
 */
async function skills(cfg) {
  const dir = skillsDir(cfg);
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return { dir, present: false, rows: [] };
  }
  const rows = [];
  for (const entry of entries) {
    if (!entry.isDirectory() && !entry.isSymbolicLink()) continue;
    let target = "";
    try {
      const stat = await lstat(path.join(dir, entry.name));
      if (stat.isSymbolicLink()) {
        const { readlink } = await import("node:fs/promises");
        target = await readlink(path.join(dir, entry.name)).catch(() => "");
      }
    } catch {
      target = "";
    }
    rows.push({ name: entry.name, target });
  }
  return { dir, present: true, rows };
}

async function routingTable() {
  return (await readJson(ROUTING_TABLE)) ?? { routes: [] };
}

function text(value) {
  return [{ type: "text", text: value }];
}

function registerTools(ctx, cfg) {
  const unregister = [];

  unregister.push(
    ctx.tools.register(
      defineTool({
        name: "hub_plugins",
        description:
          "List the plugin bundles and skill directories installed in the current DeepSeek Harness profile, with version and whether each bundle is present on disk. Use when the user asks what is installed, which version something is, or whether a plugin is actually there.",
        parameters: {
          profile: {
            type: "string",
            description: "DSH profile name to inspect. Defaults to the configured profile (desktop).",
          },
        },
        output: {
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              profileDir: { type: "string", required: true },
              bundles: {
                type: "array",
                required: true,
                  items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    name: { type: "string", required: true },
                    version: { type: "string", required: true },
                    present: { type: "boolean", required: true },
                    builtin: { type: "boolean", required: true },
                  },
                },
              },
              skills: {
                type: "array",
                required: true,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    name: { type: "string", required: true },
                    target: { type: "string", required: true },
                  },
                },
              },
            },
          },
          render: (_args, value) => {
            const lines = [`profile: ${value.profileDir}`];
            lines.push("", `bundles (${value.bundles.length}):`);
            for (const b of value.bundles) {
              const flag = b.builtin ? "BUILTIN" : b.present ? "OK" : "MISS";
              lines.push(`  ${flag.padEnd(8)} ${b.name}@${b.version}`);
            }
            lines.push("", `skills (${value.skills.length}):`);
            for (const s of value.skills) {
              lines.push(`  ${s.name}${s.target ? ` -> ${s.target}` : ""}`);
            }
            return text(lines.join("\n"));
          },
        },
        execute: async (args) => {
          const effective = { ...cfg, ...(args.profile ? { profile: args.profile } : {}) };
          const inv = await inventory(effective);
          const sk = await skills(effective);
          return {
            profileDir: inv.dir,
            bundles: inv.rows.map((r) => ({
              name: r.bundle,
              version: r.version,
              present: r.present,
              builtin: r.builtin,
            })),
            skills: sk.rows.map((r) => ({ name: r.name, target: r.target })),
          };
        },
      }),
    ),
  );

  unregister.push(
    ctx.tools.register(
      defineTool({
        name: "hub_check",
        description:
          "Run health checks over the DeepSeek Harness install: profile manifest readable, every declared bundle present on disk, skills directory reachable, and configured local services listening. Returns PASS/WARN/FAIL/INFO per check with a fix hint. Use before dispatching to a plugin, or when the user says a plugin is not working.",
        parameters: {},
        output: {
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              checks: {
                type: "array",
                required: true,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    level: { type: "string", required: true },
                    check: { type: "string", required: true },
                    detail: { type: "string", required: true },
                    fix: { type: "string", required: true },
                  },
                },
              },
              failed: { type: "integer", required: true },
            },
          },
          render: (_args, value) => {
            const lines = value.checks.map(
              (c) =>
                `[${c.level.padEnd(4)}] ${c.check}` +
                (c.detail ? `\n         ${c.detail}` : "") +
                (c.fix ? `\n         fix: ${c.fix}` : ""),
            );
            lines.push("", value.failed === 0 ? "hub_check: no FAIL items." : `hub_check: ${value.failed} FAIL item(s).`);
            return text(lines.join("\n"));
          },
        },
        execute: async () => {
          const checks = [];
          const add = (level, check, detail = "", fix = "") => checks.push({ level, check, detail, fix });

          const inv = await inventory(cfg);
          if (inv.manifest) {
            add("PASS", "profile manifest readable", `${inv.dir}\\package.json`);
          } else {
            add(
              "FAIL",
              "profile manifest unreadable",
              path.join(profileDir(cfg), "package.json"),
              "check the profile name, or run `dsh plugin --profile <name> list`",
            );
          }

          const builtins = inv.rows.filter((r) => r.builtin);
          const missing = inv.rows.filter((r) => !r.present && !r.builtin);
          if (inv.rows.length === 0) {
            add("INFO", "no bundles declared in this profile", inv.dir);
          } else {
            if (builtins.length > 0) {
              add(
                "PASS",
                `${builtins.length} platform bundle(s) provided by the harness`,
                builtins.map((b) => b.bundle).join(", "),
              );
            }
            const thirdParty = inv.rows.length - builtins.length;
            if (missing.length === 0) {
              add("PASS", `${thirdParty} third-party bundle(s) present on disk`);
            } else {
              add(
                "FAIL",
                `${missing.length} of ${thirdParty} third-party bundle(s) missing from node_modules`,
                missing.map((m) => m.bundle).join(", "),
                "run `dsh plugin --profile <name> install` to restore the dependency tree",
              );
            }
          }

          const sk = await skills(cfg);
          if (!sk.present) {
            add("WARN", "skills directory missing", sk.dir, "create it, or point `skillsDir` at your skills root");
          } else {
            add("PASS", `skills directory reachable (${sk.rows.length} entries)`, sk.dir);
          }

          for (const service of cfg?.services ?? DEFAULT_SERVICES) {
            const up = await portOpen(service.port);
            if (up) {
              add("PASS", `service ${service.name} listening`, `127.0.0.1:${service.port}`);
            } else {
              add(
                "WARN",
                `service ${service.name} not listening`,
                `127.0.0.1:${service.port}`,
                `start ${service.name} before dispatching to a plugin that depends on it`,
              );
            }
          }

          const failed = checks.filter((c) => c.level === "FAIL").length;
          return { checks, failed };
        },
      }),
    ),
  );

  unregister.push(
    ctx.tools.register(
      defineTool({
        name: "hub_route",
        description:
          "Answer 'which plugin handles X' from the maintained routing table: matches the query against intents, plugin names and entry points, and reports whether each matching bundle is present in the current profile. Use instead of guessing from memory which plugin or built-in tool does a task.",
        parameters: {
          query: {
            type: "string",
            required: true,
            description: "What the user wants to do, in their own words (e.g. 'remember this', 'web scraping', 'transcribe audio').",
          },
          limit: {
            type: "integer",
            description: "Maximum matches to return (default 5).",
          },
        },
        output: {
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              matches: {
                type: "array",
                required: true,
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    intent: { type: "string", required: true },
                    plugin: { type: "string", required: true },
                    entry: { type: "string", required: true },
                    note: { type: "string", required: true },
                    available: { type: "string", required: true },
                  },
                },
              },
            },
          },
          render: (_args, value) => {
            if (value.matches.length === 0) {
              return text("No routing-table entry matches. This may be a built-in capability or an unlisted plugin.");
            }
            return text(
              value.matches
                .map(
                  (m) =>
                    `${m.plugin} — ${m.entry} [${m.available}]\n  intent: ${m.intent}` +
                    (m.note ? `\n  note: ${m.note}` : ""),
                )
                .join("\n\n"),
            );
          },
        },
        execute: async (args) => {
          const table = await routingTable();
          const needle = String(args.query || "").toLowerCase();
          const terms = needle.split(/[^a-z0-9\u4e00-\u9fff]+/i).filter((t) => t.length > 1);
          const inv = await inventory(cfg);
          const present = new Map(inv.rows.map((r) => [r.bundle, r.present]));
          const skillNames = new Set((await skills(cfg)).rows.map((r) => r.name));

          const scored = table.routes
            .map((route) => {
              const haystack = `${route.intent} ${route.plugin} ${route.entry} ${route.note}`.toLowerCase();
              let score = 0;
              if (haystack.includes(needle)) score += 3;
              for (const term of terms) if (haystack.includes(term)) score += 1;
              return { route, score };
            })
            .filter((x) => x.score > 0)
            .sort((a, b) => b.score - a.score)
            .slice(0, Math.max(1, args.limit ?? 5));

          return {
            matches: scored.map(({ route }) => {
              let available;
              if (route.plugin === "built-in") available = "built-in";
              else if (present.has(route.plugin)) available = present.get(route.plugin) ? "installed" : "declared but missing";
              else if (skillNames.has(route.plugin)) available = "installed (skill)";
              else available = "not installed";
              return {
                intent: route.intent,
                plugin: route.plugin,
                entry: route.entry,
                note: route.note,
                available,
              };
            }),
          };
        },
      }),
    ),
  );

  return () => {
    for (const remove of unregister.reverse()) remove();
  };
}

const Config = {
  profile: "desktop",
  skillsDir: "",
  services: DEFAULT_SERVICES,
};

function apply(ctx, config = {}) {
  const cfg = { ...Config, ...config };
  if (!cfg.services?.length) cfg.services = DEFAULT_SERVICES;
  // cordis owns the disposer; stay compatible with ctx objects that lack it.
  if (typeof ctx.effect === "function") ctx.effect(() => registerTools(ctx, cfg));
  else registerTools(ctx, cfg);
}

export { Config, apply, inject, name };
