import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { fileURLToPath } from "node:url";
import type { ChildHandle, ChildRunner, RunnerEvents, SpawnRequest } from "./types.ts";

interface PendingResponse {
  resolve(value: unknown): void;
  reject(error: Error): void;
  command: string;
}

interface RpcLine {
  id?: string;
  type?: string;
  command?: string;
  success?: boolean;
  data?: unknown;
  error?: string;
  message?: string;
}

class RpcChildHandle implements ChildHandle {
  private buffer = "";
  private nextRequest = 0;
  private settled = false;
  private finishing = false;
  private cancelling = false;
  private killed = false;
  private readonly pending = new Map<string, PendingResponse>();

  constructor(
    private readonly child: ChildProcessWithoutNullStreams,
    private readonly events: RunnerEvents,
  ) {
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => this.onStdout(chunk));
    child.stderr.on("data", (chunk) => this.events.running(`stderr: ${String(chunk).trim().slice(0, 200)}`));
    child.on("error", (error) => this.fail(error.message));
    child.on("close", (code, signal) => {
      for (const pending of this.pending.values()) {
        pending.reject(new Error(`RPC process closed before ${pending.command} response`));
      }
      this.pending.clear();
      if (!this.settled) this.fail(`RPC process closed with code ${code ?? "null"} signal ${signal ?? "null"}`);
    });
  }

  async prompt(message: string): Promise<void> {
    await this.send("prompt", { message });
  }

  async cancel(): Promise<void> {
    if (this.cancelling) return;
    this.cancelling = true;
    try {
      await Promise.race([this.send("abort", {}), delay(200)]);
    } catch {}
    this.terminate();
  }

  private onStdout(chunk: string) {
    this.buffer += chunk;
    while (true) {
      const newline = this.buffer.indexOf("\n");
      if (newline === -1) return;
      const line = this.buffer.slice(0, newline).replace(/\r$/, "");
      this.buffer = this.buffer.slice(newline + 1);
      if (line.trim() === "") continue;
      this.onLine(line);
    }
  }

  private onLine(line: string) {
    let payload: RpcLine;
    try {
      payload = JSON.parse(line);
    } catch {
      this.events.running(`non-json rpc output: ${line.slice(0, 200)}`);
      return;
    }

    if (payload.type === "response" && payload.id) {
      const pending = this.pending.get(payload.id);
      if (!pending) return;
      this.pending.delete(payload.id);
      if (payload.success) pending.resolve(payload.data);
      else pending.reject(new Error(payload.error ?? payload.message ?? `${pending.command} failed`));
      return;
    }

    if (payload.type === "agent_started") {
      this.events.running(payload as Record<string, unknown>);
      return;
    }

    if (payload.type === "agent_settled") {
      this.events.running(payload as Record<string, unknown>);
      this.finish().catch((error) => this.fail(error instanceof Error ? error.message : String(error)));
      return;
    }

    if (payload.type) this.events.running(payload as Record<string, unknown>);
  }

  private async finish() {
    if (this.settled || this.finishing) return;
    this.finishing = true;
    this.events.settling();
    const result = await this.send("get_last_assistant_text", {});
    const text = typeof result === "string" ? result : result && typeof result === "object" && "text" in result ? String((result as { text: unknown }).text) : "";
    this.settled = true;
    this.events.completed(text, "agent_settled");
    this.terminate();
  }

  private terminate() {
    if (this.killed) return;
    this.killed = true;
    this.child.stdin.end();
    if (this.child.killed) return;
    if (process.platform !== "win32" && this.child.pid) {
      try {
        process.kill(-this.child.pid, "SIGTERM");
      } catch {
        this.child.kill("SIGTERM");
      }
      setTimeout(() => {
        if (this.child.killed || !this.child.pid) return;
        try {
          process.kill(-this.child.pid, "SIGKILL");
        } catch {
          this.child.kill("SIGKILL");
        }
      }, 2_000).unref();
      return;
    }
    this.child.kill("SIGTERM");
  }

  private fail(error: string) {
    if (this.settled) return;
    this.settled = true;
    this.events.failed(error);
  }

  private send(command: string, body: Record<string, unknown>): Promise<unknown> {
    const id = `subagent-${++this.nextRequest}`;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, command });
      this.child.stdin.write(`${JSON.stringify({ id, type: command, ...body })}\n`, (error) => {
        if (!error) return;
        this.pending.delete(id);
        reject(error);
      });
    });
  }
}

export class SubprocessRpcRunner implements ChildRunner {
  async start(id: string, request: SpawnRequest, cwd: string, events: RunnerEvents): Promise<ChildHandle> {
    const args = [process.argv[1], "--mode", "rpc", "--no-extensions", "--extension", subagentsExtensionPath(), "--name", `subagent ${request.label ?? id}`, ...contextArgs(request), ...toolArgs(request), ...modelArgs(request)];
    const child = spawn(process.execPath, args, {
      cwd,
      env: childEnvironment(),
      stdio: ["pipe", "pipe", "pipe"],
      detached: process.platform !== "win32",
    });
    const handle = new RpcChildHandle(child, events);
    events.accepted();
    void handle.prompt(independentPrompt(request)).catch((error) => events.failed(error instanceof Error ? error.message : String(error)));
    return handle;
  }
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function subagentsExtensionPath(): string {
  return fileURLToPath(new URL("./index.ts", import.meta.url));
}

function contextArgs(request: SpawnRequest): string[] {
  if (request.context !== "fork" || !request.parentSessionFile) return [];
  return ["--fork", request.parentSessionFile];
}

function toolArgs(request: SpawnRequest): string[] {
  const activeTools = request.toolProfile?.activeTools;
  if (activeTools === undefined || activeTools === null) return [];
  if (activeTools.length === 0) return ["--no-tools"];
  return ["--tools", activeTools.join(",")];
}

function modelArgs(request: SpawnRequest): string[] {
  const args: string[] = [];
  if (request.model && request.model !== "inherit") args.push("--model", request.model);
  if (request.thinking) args.push("--thinking", request.thinking);
  return args;
}

function childEnvironment(): NodeJS.ProcessEnv {
  const env = { ...process.env };
  delete env.PI_SESSION_ID;
  delete env.PI_SESSION_FILE;
  delete env.PI_PROVIDER;
  delete env.PI_MODEL;
  delete env.PI_REASONING_LEVEL;
  return env;
}

function independentPrompt(request: SpawnRequest): string {
  const base = request.agentBody ? `${request.agentBody}\n\n` : "";
  if (request.context === "fork") {
    return `${base}You are running as a delegated subagent in fork context.\nUse the inherited parent session context, then return a concise final answer for the parent agent.\n\nTask:\n${request.prompt}`;
  }
  return `${base}You are running as a delegated subagent in independent context.\nDo not assume access to the parent conversation transcript.\nReturn a concise final answer for the parent agent.\n\nTask:\n${request.prompt}`;
}
