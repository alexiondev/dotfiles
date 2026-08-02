import type {
  ChildHandle,
  ChildRecord,
  ChildRunner,
  ContextMode,
  RunnerActivity,
  RunnerEvents,
  SpawnAccepted,
  SpawnRequest,
  SubagentResult,
  SubagentStatus,
  SubagentWaitMode,
  SubagentWaitResult,
} from "./types.ts";
import { cloneResult, cloneStatus, isTerminalState, toAccepted } from "./status.ts";

interface RunningChild {
  record: ChildRecord;
  request: SpawnRequest;
  handle?: ChildHandle;
  startTimer?: ReturnType<typeof setTimeout>;
  runTimer?: ReturnType<typeof setTimeout>;
}

interface SupervisorOptions {
  maxConcurrent?: number;
  recentTerminalLimit?: number;
  recentTerminalTtlMs?: number;
  timeouts?: {
    startMs?: number;
    runMs?: number;
  };
  onMilestone?: (status: SubagentStatus, event: string) => void;
  onChange?: (statuses: SubagentStatus[]) => void;
}

export interface BatchSpawnResult {
  accepted: SpawnAccepted[];
  failed: Array<{ index: number; error: string }>;
}

const DEFAULT_TIMEOUTS = {
  startMs: 30_000,
  runMs: 0,
};

export class Supervisor {
  private nextChild = 0;
  private readonly children = new Map<string, RunningChild>();
  private readonly queue: RunningChild[] = [];
  private readonly waiters = new Set<() => void>();

  constructor(
    private readonly runner: ChildRunner,
    private readonly cwd: string,
    private readonly options: SupervisorOptions = {},
  ) {}

  spawn(request: SpawnRequest): SpawnAccepted {
    return this.createChild(request);
  }

  spawnBatch(requests: SpawnRequest[]): BatchSpawnResult {
    const accepted: SpawnAccepted[] = [];
    const failed: Array<{ index: number; error: string }> = [];
    requests.forEach((request, index) => {
      try {
        accepted.push(this.createChild(request));
      } catch (error) {
        failed.push({ index, error: error instanceof Error ? error.message : String(error) });
      }
    });
    return { accepted, failed };
  }

  list(): SubagentStatus[] {
    const statuses = [...this.children.values()].map((child) => cloneStatus(child.record.status));
    const active = statuses.filter((status) => !isTerminal(status.state));
    const terminal = statuses
      .filter((status) => isTerminal(status.state))
      .sort((a, b) => Date.parse(b.completedAt ?? b.startedAt) - Date.parse(a.completedAt ?? a.startedAt));
    return [...active, ...terminal];
  }

  status(id: string): SubagentStatus {
    return cloneStatus(this.require(id).record.status);
  }

  result(id: string): SubagentResult {
    return cloneResult(this.require(id).record);
  }

  clearTerminal(ids?: string[]): SubagentStatus[] {
    const selectedIds = ids ? [...new Set(ids.map((id) => id.trim()).filter(Boolean))] : undefined;
    if (selectedIds) for (const id of selectedIds) this.require(id);
    const cleared: SubagentStatus[] = [];
    for (const [id, child] of this.children) {
      if (selectedIds && !selectedIds.includes(id)) continue;
      if (!isTerminal(child.record.status.state)) continue;
      cleared.push(cloneStatus(child.record.status));
      this.children.delete(id);
    }
    if (cleared.length > 0) this.emitChange();
    return cleared;
  }

  async wait(
    ids: string[],
    options: { timeoutMs?: number; signal?: AbortSignal; mode?: SubagentWaitMode } = {},
  ): Promise<SubagentWaitResult> {
    const uniqueIds = [...new Set(ids.map((id) => id.trim()).filter(Boolean))];
    if (uniqueIds.length === 0) throw new Error("at least one subagent id is required");
    for (const id of uniqueIds) this.require(id);

    const startedAt = Date.now();
    const mode = options.mode ?? "all";
    if (mode !== "all" && mode !== "any") throw new Error(`unknown wait mode: ${mode}`);
    const deadline = options.timeoutMs && options.timeoutMs > 0 ? startedAt + options.timeoutMs : undefined;
    let timedOut = false;

    while (!this.waitReady(uniqueIds, mode)) {
      if (options.signal?.aborted) throw new Error("subagent wait aborted");
      const remainingMs = deadline === undefined ? undefined : deadline - Date.now();
      if (remainingMs !== undefined && remainingMs <= 0) {
        timedOut = true;
        break;
      }
      await this.nextChange(remainingMs, options.signal).catch((error) => {
        if (error instanceof Error && error.message === "subagent wait timed out") timedOut = true;
        else throw error;
      });
      if (timedOut) break;
    }

    const results = uniqueIds.map((id) => this.result(id));
    const pending = uniqueIds
      .map((id) => this.status(id))
      .filter((status) => !isTerminal(status.state));
    return { ids: uniqueIds, mode, ready: this.waitReady(uniqueIds, mode), results, pending, timedOut, elapsedMs: Date.now() - startedAt };
  }

  async cancel(id: string): Promise<SubagentStatus> {
    const child = this.require(id);
    if (isTerminal(child.record.status.state)) return cloneStatus(child.record.status);
    await child.handle?.cancel();
    this.completeWithoutResult(child, "cancelled", "cancelled");
    this.pumpQueue();
    return cloneStatus(child.record.status);
  }

  async shutdown(): Promise<void> {
    await Promise.allSettled(
      [...this.children.values()].map(async (child) => {
        if (!isTerminal(child.record.status.state)) {
          await child.handle?.cancel();
          this.completeWithoutResult(child, "cancelled", "shutdown");
        }
      }),
    );
  }

  private createChild(request: SpawnRequest): SpawnAccepted {
    const prompt = typeof request.prompt === "string" ? request.prompt.trim() : "";
    if (!prompt) throw new Error("prompt is required");

    const id = this.allocateId();
    const now = new Date().toISOString();
    const status: SubagentStatus = {
      id,
      label: deriveLabel(request, id),
      agent: request.agent,
      adHoc: !request.agent,
      context: this.resolveContext(request.context),
      state: "queued",
      cwd: this.cwd,
      model: request.model,
      thinking: request.thinking,
      tools: request.tools ?? "read-only",
      startedAt: now,
      elapsedMs: 0,
      lastEvent: "queued",
      lastEventAt: now,
      currentActivity: { type: "queued", summary: "queued", at: now },
      activityHistory: [{ type: "queued", summary: "queued", at: now }],
      resultAvailable: false,
    };
    const child: RunningChild = { record: { status, activityEvents: [{ type: "queued", summary: "queued", at: now }] }, request: { ...request, prompt, label: status.label, context: status.context, tools: status.tools } };
    this.children.set(id, child);
    this.emitMilestone(child, "accepted");
    this.queue.push(child);
    this.pumpQueue();
    return toAccepted(cloneStatus(status));
  }

  private pumpQueue() {
    while (this.runningCount() < this.maxConcurrent()) {
      const child = this.queue.shift();
      if (!child) break;
      if (isTerminal(child.record.status.state)) continue;
      this.start(child);
    }
    this.emitChange();
  }

  private start(child: RunningChild) {
    this.setState(child.record.status, "starting", "starting");
    this.armStartTimer(child);
    setTimeout(() => {
      if (isTerminal(child.record.status.state)) return;
      void this.runner
        .start(child.record.status.id, child.request, this.cwd, this.eventsFor(child.record))
        .then((handle) => {
          child.handle = handle;
          if (isTerminal(child.record.status.state)) void handle.cancel();
        })
        .catch((error) => {
          this.fail(child.record, error instanceof Error ? error.message : String(error));
        });
    }, 0);
  }

  private eventsFor(record: ChildRecord): RunnerEvents {
    return {
      accepted: (childSession) => {
        const child = this.findChild(record);
        if (child) {
          this.clearTimer(child, "startTimer");
          this.armRunTimer(child);
        }
        if (childSession) record.status.childSession = childSession;
        this.setState(record.status, "running", "prompt accepted");
      },
      running: (event) => {
        if (!isTerminal(record.status.state)) this.setState(record.status, "running", event);
      },
      settling: () => {
        if (!isTerminal(record.status.state)) this.setState(record.status, "settling", "agent_settled");
      },
      completed: (result, stopReason) => {
        const now = new Date().toISOString();
        const child = this.findChild(record);
        if (child) this.clearTimers(child);
        record.result = result;
        record.status.state = "completed";
        record.status.completedAt = now;
        record.status.lastEvent = "completed";
        record.status.lastEventAt = now;
        this.recordActivity(record, "completed", now);
        record.status.stopReason = stopReason;
        record.status.resultAvailable = true;
        if (child) this.emitMilestone(child, "completed");
        this.pumpQueue();
      },
      failed: (error) => this.fail(record, error),
    };
  }

  private fail(record: ChildRecord, error: string) {
    if (isTerminal(record.status.state)) return;
    const child = this.findChild(record);
    if (child) this.clearTimers(child);
    const now = new Date().toISOString();
    record.status.state = "failed";
    record.status.completedAt = now;
    record.status.lastEvent = "failed";
    record.status.lastEventAt = now;
    this.recordActivity(record, "failed", now);
    record.status.error = error;
    record.status.stopReason = "failed";
    if (child) this.emitMilestone(child, "failed");
    this.pumpQueue();
  }

  private completeWithoutResult(child: RunningChild, state: "cancelled" | "timed_out", reason: string) {
    if (isTerminal(child.record.status.state)) return;
    this.clearTimers(child);
    const now = new Date().toISOString();
    child.record.status.state = state;
    child.record.status.completedAt = now;
    child.record.status.lastEvent = state;
    child.record.status.lastEventAt = now;
    this.recordActivity(child.record, state, now);
    child.record.status.stopReason = reason;
    this.emitMilestone(child, state);
  }

  private armStartTimer(child: RunningChild) {
    const timeout = this.options.timeouts?.startMs ?? DEFAULT_TIMEOUTS.startMs;
    if (timeout <= 0) return;
    child.startTimer = setTimeout(() => {
      this.timeout(child, "start_timeout");
    }, timeout);
  }

  private armRunTimer(child: RunningChild) {
    const timeout = this.options.timeouts?.runMs ?? DEFAULT_TIMEOUTS.runMs;
    if (timeout <= 0) return;
    child.runTimer = setTimeout(() => {
      this.timeout(child, "run_timeout");
    }, timeout);
  }

  private timeout(child: RunningChild, reason: string) {
    if (isTerminal(child.record.status.state)) return;
    void child.handle?.cancel();
    this.completeWithoutResult(child, "timed_out", reason);
    this.pumpQueue();
  }

  private clearTimers(child: RunningChild) {
    this.clearTimer(child, "startTimer");
    this.clearTimer(child, "runTimer");
  }

  private clearTimer(child: RunningChild, key: "startTimer" | "runTimer") {
    const timer = child[key];
    if (!timer) return;
    clearTimeout(timer);
    child[key] = undefined;
  }

  private findChild(record: ChildRecord): RunningChild | undefined {
    return [...this.children.values()].find((child) => child.record === record);
  }

  activity(id: string) {
    return this.require(id).record.activityEvents.map((event) => ({ ...event }));
  }

  private setState(status: SubagentStatus, state: SubagentStatus["state"], event: RunnerActivity) {
    if (isTerminal(status.state)) return;
    const record = this.require(status.id).record;
    const now = new Date().toISOString();
    const activity = this.recordActivity(record, event, now);
    status.state = state;
    status.lastEvent = activity.type;
    status.lastEventAt = now;
    this.emitChange();
  }

  private recordActivity(record: ChildRecord, event: RunnerActivity, at: string) {
    const activity = normalizeActivity(event, at);
    record.activityEvents.push(activity);
    const summary = summarizeActivity(activity);
    record.status.currentActivity = summary;
    record.status.activityHistory.push(summary);
    return activity;
  }

  private require(id: string): RunningChild {
    const child = this.children.get(id);
    if (!child) throw new Error(`unknown subagent id: ${id}`);
    return child;
  }

  private resolveContext(context: ContextMode | undefined): ContextMode {
    if (context === undefined) return "independent";
    if (context !== "independent" && context !== "fork") throw new Error(`unknown context: ${context}`);
    return context;
  }

  private maxConcurrent(): number {
    return Math.max(1, this.options.maxConcurrent ?? 3);
  }

  private runningCount(): number {
    return [...this.children.values()].filter((child) => ["starting", "running", "settling"].includes(child.record.status.state)).length;
  }

  private emitMilestone(child: RunningChild, event: string) {
    this.options.onMilestone?.(cloneStatus(child.record.status), event);
    this.emitChange();
  }

  private emitChange() {
    this.options.onChange?.(this.list());
    for (const waiter of this.waiters) waiter();
  }

  private waitReady(ids: string[], mode: SubagentWaitMode): boolean {
    const terminal = (id: string) => isTerminal(this.require(id).record.status.state);
    return mode === "all" ? ids.every(terminal) : ids.some(terminal);
  }

  private nextChange(timeoutMs: number | undefined, signal: AbortSignal | undefined): Promise<void> {
    return new Promise((resolve, reject) => {
      let timer: ReturnType<typeof setTimeout> | undefined;
      const cleanup = () => {
        this.waiters.delete(resolveOnce);
        if (timer) clearTimeout(timer);
        signal?.removeEventListener("abort", abort);
      };
      const resolveOnce = () => {
        cleanup();
        resolve();
      };
      const abort = () => {
        cleanup();
        reject(new Error("subagent wait aborted"));
      };
      this.waiters.add(resolveOnce);
      signal?.addEventListener("abort", abort, { once: true });
      if (timeoutMs !== undefined) {
        timer = setTimeout(() => {
          cleanup();
          reject(new Error("subagent wait timed out"));
        }, timeoutMs);
      }
    });
  }

  private allocateId(): string {
    this.nextChild += 1;
    return `sg-${Date.now().toString(36)}-${this.nextChild.toString(36)}`;
  }
}

function deriveLabel(request: SpawnRequest, id: string): string {
  const explicit = normalizeLabel(request.label);
  if (explicit) return explicit;
  const agent = normalizeLabel(request.agent);
  if (agent) return agent;
  return promptLabel(request.prompt) ?? `ad-hoc ${id}`;
}

function promptLabel(prompt: string): string | undefined {
  const normalized = normalizeLabel(prompt);
  if (!normalized) return undefined;
  return truncateLabel(normalized);
}

function normalizeLabel(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const normalized = value.replace(/\s+/gu, " ").trim();
  return normalized || undefined;
}

function truncateLabel(label: string): string {
  const maxLength = 80;
  if (label.length <= maxLength) return label;
  return `${label.slice(0, maxLength - 1).trimEnd()}…`;
}

function isTerminal(state: SubagentStatus["state"]): boolean {
  return isTerminalState(state);
}

function normalizeActivity(event: RunnerActivity, at: string) {
  if (typeof event === "string") return { type: event, summary: event, at };
  const type = typeof event.type === "string" ? event.type : "activity";
  const role = typeof event.role === "string" ? event.role : undefined;
  const tool = toolFromActivity(event);
  const phase = typeof event.phase === "string" ? event.phase : phaseFromType(type, event);
  const text = textFromActivity(event);
  const input = inputFromActivity(event);
  const output = "output" in event ? event.output : "result" in event ? event.result : "partialResult" in event ? event.partialResult : undefined;
  const error = typeof event.error === "string" ? event.error : undefined;
  return { type, summary: summaryFor({ type, role, tool, phase, input, output, error }), at, role, tool, phase, text, input, output, error, payload: { ...event } };
}

function summarizeActivity(activity: ReturnType<typeof normalizeActivity>) {
  const { type, summary, at, role, tool, phase } = activity;
  return { type, summary, at, role, tool, phase };
}

function toolFromActivity(event: Record<string, unknown>): string | undefined {
  for (const key of ["tool", "toolName", "name"]) {
    const value = event[key];
    if (typeof value === "string") return value;
  }
  return undefined;
}

function phaseFromType(type: string, event: Record<string, unknown>): string | undefined {
  const assistantEvent = event.assistantMessageEvent;
  if (assistantEvent && typeof assistantEvent === "object" && !Array.isArray(assistantEvent)) {
    const assistantType = (assistantEvent as { type?: unknown }).type;
    if (typeof assistantType === "string") return assistantType;
  }
  if (type.endsWith("_start")) return "started";
  if (type.endsWith("_started")) return "started";
  if (type.endsWith("_update")) return "update";
  if (type.endsWith("_delta")) return "delta";
  if (type.endsWith("_end")) return "completed";
  if (type.endsWith("_completed")) return "completed";
  if (type.endsWith("_failed")) return "failed";
  return undefined;
}

function textFromActivity(event: Record<string, unknown>): string | undefined {
  for (const key of ["text", "body", "content", "delta"]) {
    const value = event[key];
    if (typeof value === "string") return value;
  }
  const assistantEvent = event.assistantMessageEvent;
  if (assistantEvent && typeof assistantEvent === "object" && !Array.isArray(assistantEvent)) {
    for (const key of ["delta", "content"]) {
      const value = (assistantEvent as Record<string, unknown>)[key];
      if (typeof value === "string") return value;
    }
  }
  return undefined;
}

function inputFromActivity(event: Record<string, unknown>): unknown {
  if ("input" in event) return event.input;
  if ("args" in event) return event.args;
  return undefined;
}

function summaryFor(activity: { type: string; role?: string; tool?: string; phase?: string; input?: unknown; output?: unknown; error?: string }): string {
  if (activity.error) return `${activity.tool ?? activity.type} failed: ${activity.error}`;
  if (activity.tool) return `${activity.tool}${inputHint(activity.input)}`;
  if (activity.type.startsWith("message")) return `${activity.role ?? "assistant"} message${activity.phase ? ` ${activity.phase}` : ""}`;
  return activity.type;
}

function inputHint(input: unknown): string {
  if (!input || typeof input !== "object" || Array.isArray(input)) return "";
  const path = (input as { path?: unknown }).path;
  if (typeof path === "string" && path.trim()) return ` ${path.trim()}`;
  const command = (input as { command?: unknown }).command;
  if (typeof command === "string" && command.trim()) return ` ${truncateActivityHint(command.trim())}`;
  return "";
}

function truncateActivityHint(value: string): string {
  return value.length <= 80 ? value : `${value.slice(0, 79).trimEnd()}…`;
}
