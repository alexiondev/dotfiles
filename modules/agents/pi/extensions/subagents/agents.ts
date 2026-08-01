import { existsSync, readdirSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import type { ContextMode } from "./types.ts";
import type { Diagnostics } from "./config.ts";

export interface AgentDefinition {
  name: string;
  description: string;
  body: string;
  context?: ContextMode;
  model?: string;
  thinking?: string;
  tools?: string;
  allowedContexts?: ContextMode[];
  hidden?: boolean;
  source: string;
}

export function loadAgents(cwd: string, projectTrusted: boolean, diagnostics: Diagnostics, agentDir = defaultAgentDir()): Map<string, AgentDefinition> {
  const user = loadTier(join(agentDir, "agents"), "user", diagnostics);
  const project = projectTrusted ? loadTier(join(cwd, ".pi", "agents"), "project", diagnostics) : new Map<string, AgentDefinition>();
  return new Map([...user, ...project]);
}

function loadTier(dir: string, tier: string, diagnostics: Diagnostics): Map<string, AgentDefinition> {
  const agents = new Map<string, AgentDefinition>();
  if (!existsSync(dir)) return agents;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    const path = join(dir, entry.name);
    const parsed = parseAgent(path, diagnostics);
    if (!parsed) continue;
    if (agents.has(parsed.name)) {
      diagnostics.warnings.push(`Duplicate ${tier} agent '${parsed.name}' ignored at ${path}`);
      continue;
    }
    const stem = basename(entry.name, ".md");
    if (stem !== parsed.name) diagnostics.warnings.push(`${tier} agent file '${entry.name}' name '${parsed.name}' does not match filename`);
    agents.set(parsed.name, parsed);
  }
  return agents;
}

export function parseAgent(path: string, diagnostics: Diagnostics): AgentDefinition | undefined {
  try {
    const text = readFileSync(path, "utf8");
    const match = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/u.exec(text);
    if (!match) {
      diagnostics.warnings.push(`Agent ${path} missing YAML frontmatter`);
      return undefined;
    }
    const frontmatter = parseFrontmatter(match[1]);
    const name = stringField(frontmatter, "name");
    const description = stringField(frontmatter, "description");
    if (!name || !/^[a-z0-9-]+$/.test(name)) {
      diagnostics.warnings.push(`Agent ${path} has invalid name`);
      return undefined;
    }
    if (!description) {
      diagnostics.warnings.push(`Agent ${path} has invalid description`);
      return undefined;
    }
    const context = contextField(frontmatter.context);
    const allowedContexts = contextsField(frontmatter.allowedContexts);
    if (frontmatter.context !== undefined && !context) diagnostics.warnings.push(`Agent ${path} has invalid context`);
    if (frontmatter.allowedContexts !== undefined && !allowedContexts) diagnostics.warnings.push(`Agent ${path} has invalid allowedContexts`);
    if (context && allowedContexts && !allowedContexts.includes(context)) diagnostics.warnings.push(`Agent ${path} context is outside allowedContexts`);
    return {
      name,
      description,
      body: match[2].trim(),
      context,
      model: stringField(frontmatter, "model"),
      thinking: stringField(frontmatter, "thinking"),
      tools: stringField(frontmatter, "tools"),
      allowedContexts,
      hidden: booleanField(frontmatter, "hidden"),
      source: path,
    };
  } catch (error) {
    diagnostics.warnings.push(`Failed to load agent ${path}: ${error instanceof Error ? error.message : String(error)}`);
    return undefined;
  }
}

function parseFrontmatter(text: string): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  const lines = text.split(/\r?\n/u);
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    if (!line.trim() || line.trimStart().startsWith("#")) continue;
    const scalar = /^(\w+):\s*(.*?)\s*$/u.exec(line);
    if (!scalar) continue;
    const [, key, raw] = scalar;
    if (raw !== "") {
      result[key] = parseScalar(raw);
      continue;
    }
    const values: string[] = [];
    while (i + 1 < lines.length) {
      const item = /^\s+-\s*(.*?)\s*$/u.exec(lines[i + 1]);
      if (!item) break;
      values.push(String(parseScalar(item[1])));
      i += 1;
    }
    result[key] = values;
  }
  return result;
}

function parseScalar(raw: string): string | boolean {
  const unquoted = raw.replace(/^['"]|['"]$/gu, "");
  if (unquoted === "true") return true;
  if (unquoted === "false") return false;
  return unquoted;
}

function stringField(record: Record<string, unknown>, key: string): string | undefined {
  const value = record[key];
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function booleanField(record: Record<string, unknown>, key: string): boolean | undefined {
  const value = record[key];
  return typeof value === "boolean" ? value : undefined;
}

function contextField(value: unknown): ContextMode | undefined {
  return value === "independent" || value === "fork" ? value : undefined;
}

function contextsField(value: unknown): ContextMode[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const contexts = value.map(contextField);
  return contexts.every(Boolean) ? (contexts as ContextMode[]) : undefined;
}

function defaultAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
}
