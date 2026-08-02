import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { loadAgents } from "./agents.ts";
import { loadConfig, resolveSpawn, type Diagnostics } from "./config.ts";
import { SubprocessRpcRunner } from "./runner.ts";
import { Supervisor } from "./supervisor.ts";
import { milestoneNotification } from "./status.ts";
import type { SpawnRequest, SubagentStatus } from "./types.ts";
import { attachedChildView, widget } from "./ui.ts";

let supervisor: Supervisor | undefined;
let lastDiagnostics: Diagnostics = { warnings: [] };
let lastStatuses: SubagentStatus[] = [];
let uiExpanded = false;

export default function subagents(pi: ExtensionAPI) {
  const getSupervisor = (ctx: ExtensionContext): Supervisor => {
    if (supervisor) return supervisor;
    const diagnostics: Diagnostics = { warnings: [] };
    const cwd = cwdOf(ctx);
    const config = loadConfig(cwd, isProjectTrusted(ctx), diagnostics);
    lastDiagnostics = diagnostics;
    uiExpanded = config.ui.defaultExpanded;
    supervisor = new Supervisor(new SubprocessRpcRunner(), cwd, {
      maxConcurrent: config.maxConcurrent,
      recentTerminalTtlMs: config.recentTerminalTtlMs,
      onMilestone: (status, event) => {
        pi.appendEntry("subagent_milestone", { event, status });
        const notification = milestoneNotification(status, event);
        if (notification) ctx.ui?.notify?.(notification.message, notification.level);
      },
      onChange: (statuses) => {
        lastStatuses = statuses;
        updateUi(ctx, config.ui.enabled);
      },
    });
    updateUi(ctx, config.ui.enabled);
    return supervisor;
  };

  const resolve = (ctx: ExtensionContext, request: SpawnRequest): SpawnRequest => {
    const diagnostics: Diagnostics = { warnings: [] };
    const cwd = cwdOf(ctx);
    const trusted = isProjectTrusted(ctx);
    const config = loadConfig(cwd, trusted, diagnostics);
    const agents = loadAgents(cwd, trusted, diagnostics);
    lastDiagnostics = diagnostics;
    const resolved = resolveSpawn(request, config, agents);
    if (resolved.context === "fork") resolved.parentSessionFile = ctx.sessionManager.getSessionFile();
    return resolved;
  };

  pi.registerTool({
    name: "subagent_spawn",
    label: "Spawn subagent",
    description: "Start one ad hoc independent subagent and return immediately with its child id",
    parameters: Type.Object({
      prompt: Type.String({ description: "Prompt for the delegated subagent" }),
      label: Type.Optional(Type.String({ description: "Human-readable label for this work item" })),
      agent: Type.Optional(Type.String({ description: "Named agent definition to use" })),
      context: Type.Optional(Type.Union([Type.Literal("independent"), Type.Literal("fork")])),
      model: Type.Optional(Type.String({ description: "Optional model selector for the child" })),
      thinking: Type.Optional(Type.String({ description: "Optional thinking level for the child" })),
      tools: Type.Optional(Type.String({ description: "Tool profile name" })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const accepted = getSupervisor(ctx).spawn(resolve(ctx, params as SpawnRequest));
      ctx.ui?.notify?.(`Started subagent ${accepted.label}`, "info");
      return textResult(accepted);
    },
  });

  pi.registerTool({
    name: "subagent_batch",
    label: "Spawn subagent batch",
    description: "Start multiple subagents and return immediately with accepted child ids and per-entry failures",
    parameters: Type.Object({
      subagents: Type.Array(
        Type.Object({
          prompt: Type.String({ description: "Prompt for the delegated subagent" }),
          label: Type.Optional(Type.String({ description: "Human-readable label for this work item" })),
          agent: Type.Optional(Type.String({ description: "Named agent definition to use" })),
          context: Type.Optional(Type.Union([Type.Literal("independent"), Type.Literal("fork")])),
          model: Type.Optional(Type.String({ description: "Optional model selector for the child" })),
          thinking: Type.Optional(Type.String({ description: "Optional thinking level for the child" })),
          tools: Type.Optional(Type.String({ description: "Tool profile name" })),
        }),
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const requests = Array.isArray((params as { subagents?: unknown }).subagents) ? ((params as { subagents: SpawnRequest[] }).subagents) : [];
      const accepted: SpawnRequest[] = [];
      const failed: Array<{ index: number; error: string }> = [];
      requests.forEach((request, index) => {
        try {
          accepted.push(resolve(ctx, request));
        } catch (error) {
          failed.push({ index, error: error instanceof Error ? error.message : String(error) });
        }
      });
      const result = getSupervisor(ctx).spawnBatch(accepted);
      return textResult({ accepted: result.accepted, failed: [...failed, ...result.failed] });
    },
  });

  pi.registerTool({
    name: "subagent_list",
    label: "List subagents",
    description: "List active and terminal subagents for this parent session until terminal entries are cleared",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      return textResult(getSupervisor(ctx).list());
    },
  });

  pi.registerTool({
    name: "subagent_status",
    label: "Get subagent status",
    description: "Get current lifecycle status for one subagent",
    parameters: Type.Object({
      id: Type.String({ description: "Subagent id returned by subagent_spawn" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      return textResult(getSupervisor(ctx).status(String((params as { id: unknown }).id)));
    },
  });

  pi.registerTool({
    name: "subagent_result",
    label: "Get subagent result",
    description: "Return still-running before completion and the final answer after completion",
    parameters: Type.Object({
      id: Type.String({ description: "Subagent id returned by subagent_spawn" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      return textResult(getSupervisor(ctx).result(String((params as { id: unknown }).id)));
    },
  });

  pi.registerTool({
    name: "subagent_wait",
    label: "Wait for subagents",
    description: "Block until multiple subagents are terminal or a timeout expires. Prefer setting timeoutMs so the parent turn cannot hang forever",
    parameters: Type.Object({
      ids: Type.Array(Type.String({ description: "Subagent id returned by subagent_spawn or subagent_batch" })),
      timeoutMs: Type.Optional(Type.Number({ description: "Maximum milliseconds to wait. Omit or use 0 to wait indefinitely" })),
      mode: Type.Optional(Type.Union([Type.Literal("all"), Type.Literal("any")], { description: "Wait for all ids by default, or return after any id is terminal" })),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const input = params as { ids?: unknown; timeoutMs?: unknown; mode?: unknown };
      const ids = Array.isArray(input.ids) ? input.ids.map(String) : [];
      const timeoutMs = typeof input.timeoutMs === "number" && Number.isFinite(input.timeoutMs) ? input.timeoutMs : undefined;
      const mode = input.mode === "any" ? "any" : "all";
      return textResult(await getSupervisor(ctx).wait(ids, { timeoutMs, mode, signal }));
    },
  });

  pi.registerTool({
    name: "subagent_cancel",
    label: "Cancel subagent",
    description: "Cancel a running subagent",
    parameters: Type.Object({
      id: Type.String({ description: "Subagent id returned by subagent_spawn" }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      return textResult(await getSupervisor(ctx).cancel(String((params as { id: unknown }).id)));
    },
  });

  pi.registerTool({
    name: "subagent_clear",
    label: "Clear terminal subagents",
    description: "Remove terminal subagents from the current-session visible work set. Omitting ids clears all terminal children",
    parameters: Type.Object({
      ids: Type.Optional(Type.Array(Type.String({ description: "Subagent id returned by subagent_spawn or subagent_batch" }))),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const input = params as { ids?: unknown };
      const ids = Array.isArray(input.ids) ? input.ids.map(String) : undefined;
      return textResult({ cleared: getSupervisor(ctx).clearTerminal(ids) });
    },
  });

  pi.registerCommand("subagent-spawn", {
    description: "Start an ad hoc independent subagent",
    handler: async (args, ctx) => {
      const accepted = getSupervisor(ctx).spawn(resolve(ctx, parseSpawnArgs(args)));
      ctx.ui.notify(`Started subagent ${accepted.label}`, "info");
    },
  });

  pi.registerCommand("subagent-batch", {
    description: "Start ad hoc independent subagents split by |",
    handler: async (args, ctx) => {
      const requests = args
        .split("|")
        .map((prompt) => prompt.trim())
        .filter(Boolean)
        .map((prompt) => resolve(ctx, { prompt }));
      ctx.ui.notify(JSON.stringify(getSupervisor(ctx).spawnBatch(requests), null, 2), "info");
    },
  });

  pi.registerCommand("subagent-list", {
    description: "Show subagent status records",
    handler: async (_args, ctx) => {
      ctx.ui.notify(JSON.stringify(getSupervisor(ctx).list(), null, 2), "info");
    },
  });

  pi.registerCommand("subagent-clear", {
    description: "Clear terminal subagent records. Pass ids to clear selected terminal records only",
    handler: async (args, ctx) => {
      const ids = args.trim().split(/\s+/u).filter(Boolean);
      ctx.ui.notify(JSON.stringify({ cleared: getSupervisor(ctx).clearTerminal(ids.length > 0 ? ids : undefined) }, null, 2), "info");
    },
  });

  pi.registerCommand("subagent-status", {
    description: "Show a subagent status by id",
    handler: async (args, ctx) => {
      ctx.ui.notify(JSON.stringify(getSupervisor(ctx).status(args.trim()), null, 2), "info");
    },
  });

  pi.registerCommand("subagent-result", {
    description: "Show a subagent result by id",
    handler: async (args, ctx) => {
      ctx.ui.notify(JSON.stringify(getSupervisor(ctx).result(args.trim()), null, 2), "info");
    },
  });

  pi.registerCommand("subagent-attach", {
    description: "Open a read-only attached view for a subagent id",
    handler: async (args, ctx) => {
      const id = args.trim();
      if (!id) {
        ctx.ui.notify("Usage: /subagent-attach <id>", "warning");
        return;
      }
      const currentSupervisor = getSupervisor(ctx);
      currentSupervisor.status(id);
      await ctx.ui.custom<void>((tui, _theme, _keybindings, done) => attachedChildView({
        status: () => currentSupervisor.status(id),
        activity: () => currentSupervisor.activity(id),
        onDetach: () => done(),
        onChange: () => tui.requestRender(),
      }), {
        overlay: true,
        overlayOptions: { width: "90%", maxHeight: "90%", minWidth: 60 },
      });
    },
  });

  pi.registerCommand("subagent-wait", {
    description: "Wait for subagent ids separated by spaces",
    handler: async (args, ctx) => {
      const { ids, timeoutMs, mode } = parseWaitArgs(args);
      ctx.ui.notify(JSON.stringify(await getSupervisor(ctx).wait(ids, { timeoutMs, mode }), null, 2), "info");
    },
  });

  pi.registerCommand("subagent-ui", {
    description: "Toggle the bundled subagent status inspector",
    handler: async (_args, ctx) => {
      uiExpanded = !uiExpanded;
      updateUi(ctx, true);
      ctx.ui.notify(`Subagent inspector ${uiExpanded ? "expanded" : "collapsed"}`, "info");
    },
  });

  pi.registerCommand("subagent-diagnostics", {
    description: "Show subagent configuration diagnostics from the last load",
    handler: async (_args, ctx) => {
      ctx.ui.notify(JSON.stringify(lastDiagnostics, null, 2), "info");
    },
  });

  pi.registerCommand("subagent-cancel", {
    description: "Cancel a running subagent by id",
    handler: async (args, ctx) => {
      ctx.ui.notify(JSON.stringify(await getSupervisor(ctx).cancel(args.trim()), null, 2), "info");
    },
  });

  pi.on("session_shutdown", async () => {
    await supervisor?.shutdown();
    supervisor = undefined;
  });
}

function updateUi(ctx: ExtensionContext, enabled: boolean) {
  if (!ctx.hasUI) return;
  ctx.ui.setWidget("subagents", enabled ? widget(lastStatuses, uiExpanded) : undefined);
}

function parseSpawnArgs(args: string): SpawnRequest {
  const parts = args.trim().split(/\s+/u);
  const request: Partial<SpawnRequest> = {};
  while (parts.length >= 2 && parts[0].startsWith("--")) {
    const flag = parts.shift();
    const value = parts.shift();
    if (flag === "--agent") request.agent = value;
    else if (flag === "--label") request.label = value;
    else if (flag === "--context" && (value === "independent" || value === "fork")) request.context = value;
    else if (flag === "--tools") request.tools = value;
    else if (flag === "--model") request.model = value;
    else if (flag === "--thinking") request.thinking = value;
  }
  return { ...request, prompt: parts.join(" ") || args } as SpawnRequest;
}

function parseWaitArgs(args: string): { ids: string[]; timeoutMs?: number; mode?: "all" | "any" } {
  const parts = args.trim().split(/\s+/u).filter(Boolean);
  let timeoutMs: number | undefined;
  let mode: "all" | "any" | undefined;
  const ids: string[] = [];
  while (parts.length > 0) {
    const part = parts.shift();
    if (!part) continue;
    if (part === "--timeout-ms" && parts[0]) {
      const parsed = Number(parts.shift());
      if (Number.isFinite(parsed)) timeoutMs = parsed;
    } else if (part === "--mode" && (parts[0] === "all" || parts[0] === "any")) {
      mode = parts.shift() as "all" | "any";
    } else {
      ids.push(part);
    }
  }
  return { ids, timeoutMs, mode };
}

function isProjectTrusted(ctx: ExtensionContext): boolean {
  const value = (ctx as unknown as { isProjectTrusted?: () => boolean }).isProjectTrusted?.();
  return value === true;
}

function cwdOf(ctx: ExtensionContext): string {
  const sessionCwd = (ctx as unknown as { sessionManager?: { getCwd?: () => string }; cwd?: string }).sessionManager?.getCwd?.();
  return sessionCwd ?? (ctx as unknown as { cwd?: string }).cwd ?? process.cwd();
}

function textResult(value: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(value, null, 2) }],
    details: value,
  };
}
