import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { loadAgents } from "./agents.ts";
import { BUILT_IN_TOOL_PROFILES, loadConfig, resolveSpawn, type Diagnostics } from "./config.ts";

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "subagents-config-"));
  const agentDir = join(root, "agent");
  const cwd = join(root, "project");
  mkdirSync(agentDir, { recursive: true });
  mkdirSync(cwd, { recursive: true });
  return { root, agentDir, cwd };
}

function diagnostics(): Diagnostics {
  return { warnings: [] };
}

test("missing config files and agent directories are normal", () => {
  const { cwd, agentDir } = fixture();
  const diag = diagnostics();

  const config = loadConfig(cwd, true, diag, agentDir);
  const agents = loadAgents(cwd, true, diag, agentDir);

  assert.equal(config.defaultContext, "independent");
  assert.equal(config.defaultTools, "read-only");
  assert.equal(agents.size, 0);
  assert.deepEqual(diag.warnings, []);
});

test("global and trusted project config merge in order", () => {
  const { cwd, agentDir } = fixture();
  mkdirSync(join(cwd, ".pi"), { recursive: true });
  writeFileSync(join(agentDir, "subagents.json"), JSON.stringify({ defaultTools: "global-profile", toolProfiles: { "global-profile": { activeTools: ["read"] } } }));
  writeFileSync(join(cwd, ".pi", "subagents.json"), JSON.stringify({ defaultTools: "project-profile", toolProfiles: { "project-profile": { activeTools: ["ls"] } } }));

  const config = loadConfig(cwd, true, diagnostics(), agentDir);

  assert.equal(config.defaultTools, "project-profile");
  assert.deepEqual(config.toolProfiles["global-profile"].activeTools, ["read"]);
  assert.deepEqual(config.toolProfiles["project-profile"].activeTools, ["ls"]);
});

test("project config is ignored when project is untrusted", () => {
  const { cwd, agentDir } = fixture();
  mkdirSync(join(cwd, ".pi"), { recursive: true });
  writeFileSync(join(cwd, ".pi", "subagents.json"), JSON.stringify({ defaultTools: "project-profile", toolProfiles: { "project-profile": { activeTools: ["ls"] } } }));

  const config = loadConfig(cwd, false, diagnostics(), agentDir);

  assert.equal(config.defaultTools, "read-only");
  assert.equal(config.toolProfiles["project-profile"], undefined);
});

test("agents load with project precedence over user", () => {
  const { cwd, agentDir } = fixture();
  mkdirSync(join(agentDir, "agents"), { recursive: true });
  mkdirSync(join(cwd, ".pi", "agents"), { recursive: true });
  writeFileSync(join(agentDir, "agents", "review.md"), "---\nname: review\ndescription: User review\ntools: read-only\n---\nuser body\n");
  writeFileSync(join(cwd, ".pi", "agents", "review.md"), "---\nname: review\ndescription: Project review\ntools: full-tools\n---\nproject body\n");

  const agents = loadAgents(cwd, true, diagnostics(), agentDir);

  assert.equal(agents.get("review")?.description, "Project review");
  assert.equal(agents.get("review")?.body, "project body");
});

test("duplicate same-tier definitions and invalid frontmatter produce diagnostics", () => {
  const { cwd, agentDir } = fixture();
  const dir = join(agentDir, "agents");
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, "one.md"), "---\nname: same\ndescription: One\n---\none\n");
  writeFileSync(join(dir, "two.md"), "---\nname: same\ndescription: Two\n---\ntwo\n");
  writeFileSync(join(dir, "bad.md"), "---\nname: Bad Name\n---\nbad\n");
  const diag = diagnostics();

  const agents = loadAgents(cwd, true, diag, agentDir);

  assert.equal(agents.size, 1);
  assert.ok(diag.warnings.some((warning) => warning.includes("Duplicate user agent 'same'")));
  assert.ok(diag.warnings.some((warning) => warning.includes("invalid name")));
});

test("named spawn resolves overrides, frontmatter, config, and defaults", () => {
  const { cwd, agentDir } = fixture();
  mkdirSync(join(agentDir, "agents"), { recursive: true });
  writeFileSync(join(agentDir, "subagents.json"), JSON.stringify({ defaultTools: "local-review", toolProfiles: { "local-review": { activeTools: ["read"] } } }));
  writeFileSync(join(agentDir, "agents", "review.md"), "---\nname: review\ndescription: Review\ncontext: independent\nmodel: inherit\nthinking: high\ntools: local-review\n---\nagent body\n");
  const diag = diagnostics();
  const config = loadConfig(cwd, true, diag, agentDir);
  const agents = loadAgents(cwd, true, diag, agentDir);

  const resolved = resolveSpawn({ agent: "review", prompt: "check this", thinking: "low" }, config, agents);

  assert.equal(resolved.prompt, "check this");
  assert.equal(resolved.context, "independent");
  assert.equal(resolved.model, "inherit");
  assert.equal(resolved.thinking, "low");
  assert.equal(resolved.tools, "local-review");
  assert.deepEqual(resolved.toolProfile.activeTools, ["read"]);
  assert.equal(resolved.agentBody, "agent body");
});

test("built-in tool profile names cannot be overridden", () => {
  const { cwd, agentDir } = fixture();
  writeFileSync(join(agentDir, "subagents.json"), JSON.stringify({ toolProfiles: { "read-only": { activeTools: ["bash"] } } }));
  const diag = diagnostics();

  const config = loadConfig(cwd, true, diag, agentDir);

  assert.deepEqual(config.toolProfiles["read-only"], BUILT_IN_TOOL_PROFILES["read-only"]);
  assert.ok(diag.warnings.some((warning) => warning.includes("Ignoring global override for built-in tool profile 'read-only'")));
});
