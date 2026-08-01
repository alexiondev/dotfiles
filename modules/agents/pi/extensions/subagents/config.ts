import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ContextMode, SpawnRequest, ToolProfile } from "./types.ts";
import type { AgentDefinition } from "./agents.ts";

export interface Diagnostics {
  warnings: string[];
}

export interface SubagentsConfig {
  defaultContext: ContextMode;
  defaultTools: string;
  toolProfiles: Record<string, ToolProfile>;
}

export interface ResolvedSpawnRequest extends SpawnRequest {
  prompt: string;
  context: ContextMode;
  tools: string;
  toolProfile: ToolProfile;
  agentBody?: string;
}

export const BUILT_IN_TOOL_PROFILES: Record<string, ToolProfile> = {
  none: { activeTools: [] },
  "read-only": { activeTools: ["read", "grep", "find", "ls"] },
  "read-only-with-safe-bash": { activeTools: ["read", "grep", "find", "ls", "bash"] },
  "full-tools": { activeTools: null },
};

const DEFAULT_CONFIG: SubagentsConfig = {
  defaultContext: "independent",
  defaultTools: "read-only",
  toolProfiles: { ...BUILT_IN_TOOL_PROFILES },
};

export function loadConfig(cwd: string, projectTrusted: boolean, diagnostics: Diagnostics, agentDir = defaultAgentDir()): SubagentsConfig {
  let config = cloneConfig(DEFAULT_CONFIG);
  config = mergeConfig(config, readConfig(join(agentDir, "subagents.json"), diagnostics, "global"), diagnostics, "global");
  if (projectTrusted) {
    config = mergeConfig(config, readConfig(join(cwd, ".pi", "subagents.json"), diagnostics, "project"), diagnostics, "project");
  }
  if (!config.toolProfiles[config.defaultTools]) {
    diagnostics.warnings.push(`Unknown defaultTools profile '${config.defaultTools}', using read-only`);
    config.defaultTools = "read-only";
  }
  return config;
}

export function resolveSpawn(request: SpawnRequest, config: SubagentsConfig, agents: Map<string, AgentDefinition>): ResolvedSpawnRequest {
  const prompt = typeof request.prompt === "string" ? request.prompt.trim() : "";
  if (!prompt) throw new Error("prompt is required");
  const agent = request.agent ? agents.get(request.agent) : undefined;
  if (request.agent && !agent) throw new Error(`unknown subagent agent: ${request.agent}`);

  const context = request.context ?? agent?.context ?? config.defaultContext;
  if (context !== "independent" && context !== "fork") throw new Error(`unsupported context: ${context}`);
  if (agent?.allowedContexts && !agent.allowedContexts.includes(context)) {
    throw new Error(`agent '${agent.name}' does not allow ${context} context`);
  }

  const tools = request.tools ?? agent?.tools ?? config.defaultTools;
  const toolProfile = config.toolProfiles[tools];
  if (!toolProfile) throw new Error(`unknown tool profile: ${tools}`);

  return {
    ...request,
    prompt,
    agent: agent?.name ?? request.agent,
    context,
    model: request.model ?? agent?.model,
    thinking: request.thinking ?? agent?.thinking,
    tools,
    toolProfile,
    agentBody: agent?.body,
  };
}

function readConfig(path: string, diagnostics: Diagnostics, label: string): Partial<SubagentsConfig> | undefined {
  if (!existsSync(path)) return undefined;
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    return normalizeConfig(parsed, diagnostics, label);
  } catch (error) {
    diagnostics.warnings.push(`Invalid ${label} subagents.json: ${error instanceof Error ? error.message : String(error)}`);
    return undefined;
  }
}

function normalizeConfig(raw: unknown, diagnostics: Diagnostics, label: string): Partial<SubagentsConfig> | undefined {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    diagnostics.warnings.push(`Invalid ${label} subagents.json: root must be an object`);
    return undefined;
  }
  const input = raw as Record<string, unknown>;
  const config: Partial<SubagentsConfig> = {};
  if (input.defaultContext === "independent" || input.defaultContext === "fork") config.defaultContext = input.defaultContext;
  else if (input.defaultContext !== undefined) diagnostics.warnings.push(`Invalid ${label} defaultContext ignored`);
  if (typeof input.defaultTools === "string") config.defaultTools = input.defaultTools;
  else if (input.defaultTools !== undefined) diagnostics.warnings.push(`Invalid ${label} defaultTools ignored`);
  if (input.toolProfiles !== undefined) config.toolProfiles = normalizeProfiles(input.toolProfiles, diagnostics, label);
  return config;
}

function normalizeProfiles(raw: unknown, diagnostics: Diagnostics, label: string): Record<string, ToolProfile> {
  const profiles: Record<string, ToolProfile> = {};
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    diagnostics.warnings.push(`Invalid ${label} toolProfiles ignored`);
    return profiles;
  }
  for (const [name, value] of Object.entries(raw as Record<string, unknown>)) {
    if (name in BUILT_IN_TOOL_PROFILES) {
      diagnostics.warnings.push(`Ignoring ${label} override for built-in tool profile '${name}'`);
      continue;
    }
    const profile = normalizeProfile(value);
    if (!profile) {
      diagnostics.warnings.push(`Invalid ${label} tool profile '${name}' ignored`);
      continue;
    }
    profiles[name] = profile;
  }
  return profiles;
}

function normalizeProfile(raw: unknown): ToolProfile | undefined {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return undefined;
  const activeTools = (raw as { activeTools?: unknown }).activeTools;
  if (!Array.isArray(activeTools) || !activeTools.every((tool) => typeof tool === "string")) return undefined;
  return { activeTools };
}

function mergeConfig(base: SubagentsConfig, override: Partial<SubagentsConfig> | undefined, diagnostics: Diagnostics, label: string): SubagentsConfig {
  if (!override) return base;
  const merged = cloneConfig(base);
  if (override.defaultContext) merged.defaultContext = override.defaultContext;
  if (override.defaultTools) merged.defaultTools = override.defaultTools;
  if (override.toolProfiles) merged.toolProfiles = { ...merged.toolProfiles, ...override.toolProfiles };
  for (const key of Object.keys(merged.toolProfiles)) {
    if (key in BUILT_IN_TOOL_PROFILES) merged.toolProfiles[key] = BUILT_IN_TOOL_PROFILES[key];
  }
  return merged;
}

function cloneConfig(config: SubagentsConfig): SubagentsConfig {
  return { ...config, toolProfiles: { ...config.toolProfiles } };
}

function defaultAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}
