import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { SubprocessRpcRunner } from "./runner.ts";
import { Supervisor } from "./supervisor.ts";
import type { SpawnRequest } from "./types.ts";

let supervisor: Supervisor | undefined;

export default function subagents(pi: ExtensionAPI) {
  const getSupervisor = (ctx: ExtensionContext): Supervisor => {
    if (!supervisor) supervisor = new Supervisor(new SubprocessRpcRunner(), cwdOf(ctx));
    return supervisor;
  };

  pi.registerTool({
    name: "subagent_spawn",
    label: "Spawn subagent",
    description: "Start one ad hoc independent subagent and return immediately with its child id",
    parameters: Type.Object({
      prompt: Type.String({ description: "Prompt for the delegated subagent" }),
      context: Type.Optional(Type.Literal("independent")),
      model: Type.Optional(Type.String({ description: "Optional model selector for status metadata" })),
      thinking: Type.Optional(Type.String({ description: "Optional thinking level for status metadata" })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const accepted = getSupervisor(ctx).spawn(params as SpawnRequest);
      ctx.ui?.notify?.(`Started subagent ${accepted.id}`, "info");
      return textResult(accepted);
    },
  });

  pi.registerTool({
    name: "subagent_list",
    label: "List subagents",
    description: "List active and recent subagents for this parent session",
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

  pi.registerCommand("subagent-spawn", {
    description: "Start an ad hoc independent subagent",
    handler: async (args, ctx) => {
      const accepted = getSupervisor(ctx).spawn({ prompt: args });
      ctx.ui.notify(`Started subagent ${accepted.id}`, "info");
    },
  });

  pi.registerCommand("subagent-list", {
    description: "Show subagent status records",
    handler: async (_args, ctx) => {
      ctx.ui.notify(JSON.stringify(getSupervisor(ctx).list(), null, 2), "info");
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
