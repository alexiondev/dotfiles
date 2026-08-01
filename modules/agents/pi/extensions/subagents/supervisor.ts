import type { ChildHandle, ChildRecord, ChildRunner, ContextMode, RunnerEvents, SpawnAccepted, SpawnRequest, SubagentResult, SubagentStatus } from "./types.ts";
import { cloneResult, cloneStatus, toAccepted } from "./status.ts";

interface RunningChild {
  record: ChildRecord;
  handle?: ChildHandle;
  startTimer?: ReturnType<typeof setTimeout>;
  runTimer?: ReturnType<typeof setTimeout>;
}

interface SupervisorOptions {
  timeouts?: {
    startMs?: number;
    runMs?: number;
  };
}

const DEFAULT_TIMEOUTS = {
  startMs: 30_000,
  runMs: 0,
};

export class Supervisor {
  private nextChild = 0;
  private readonly children = new Map<string, RunningChild>();

  constructor(
    private readonly runner: ChildRunner,
    private readonly cwd: string,
    private readonly options: SupervisorOptions = {},
  ) {}

  spawn(request: SpawnRequest): SpawnAccepted {
    const prompt = typeof request.prompt === "string" ? request.prompt.trim() : "";
    if (!prompt) throw new Error("prompt is required");

    const id = this.allocateId();
    const now = new Date().toISOString();
    const status: SubagentStatus = {
      id,
      label: request.agent ?? `ad-hoc ${id}`,
      agent: request.agent,
      adHoc: !request.agent,
      context: this.resolveContext(request.context),
      state: "queued",
      cwd: this.cwd,
      model: request.model,
      thinking: request.thinking,
      tools: "pi-default",
      startedAt: now,
      elapsedMs: 0,
      lastEvent: "queued",
      lastEventAt: now,
      resultAvailable: false,
    };
    const child: RunningChild = { record: { status } };
    this.children.set(id, child);
    this.setState(child.record.status, "starting", "starting");
    this.armStartTimer(child);

    setTimeout(() => {
      if (isTerminal(child.record.status.state)) return;
      void this.runner
        .start(id, { ...request, prompt, context: status.context, tools: status.tools }, this.cwd, this.eventsFor(child.record))
        .then((handle) => {
          child.handle = handle;
          if (isTerminal(child.record.status.state)) void handle.cancel();
        })
        .catch((error) => {
          this.fail(child.record, error instanceof Error ? error.message : String(error));
        });
    }, 0);

    return toAccepted(cloneStatus(status));
  }

  list(): SubagentStatus[] {
    return [...this.children.values()].map((child) => cloneStatus(child.record.status));
  }

  status(id: string): SubagentStatus {
    return cloneStatus(this.require(id).record.status);
  }

  result(id: string): SubagentResult {
    return cloneResult(this.require(id).record);
  }

  async cancel(id: string): Promise<SubagentStatus> {
    const child = this.require(id);
    if (isTerminal(child.record.status.state)) return cloneStatus(child.record.status);
    await child.handle?.cancel();
    this.completeWithoutResult(child, "cancelled", "cancelled");
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
        record.status.stopReason = stopReason;
        record.status.resultAvailable = true;
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
    record.status.error = error;
    record.status.stopReason = "failed";
  }

  private completeWithoutResult(child: RunningChild, state: "cancelled" | "timed_out", reason: string) {
    if (isTerminal(child.record.status.state)) return;
    this.clearTimers(child);
    const now = new Date().toISOString();
    child.record.status.state = state;
    child.record.status.completedAt = now;
    child.record.status.lastEvent = state;
    child.record.status.lastEventAt = now;
    child.record.status.stopReason = reason;
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

  private setState(status: SubagentStatus, state: SubagentStatus["state"], event: string) {
    if (isTerminal(status.state)) return;
    const now = new Date().toISOString();
    status.state = state;
    status.lastEvent = event;
    status.lastEventAt = now;
  }

  private require(id: string): RunningChild {
    const child = this.children.get(id);
    if (!child) throw new Error(`unknown subagent id: ${id}`);
    return child;
  }

  private resolveContext(context: ContextMode | undefined): ContextMode {
    if (context === undefined) return "independent";
    if (context !== "independent") throw new Error("only independent context is implemented in this tracer bullet");
    return context;
  }

  private allocateId(): string {
    this.nextChild += 1;
    return `sg-${Date.now().toString(36)}-${this.nextChild.toString(36)}`;
  }
}

function isTerminal(state: SubagentStatus["state"]): boolean {
  return ["completed", "failed", "cancelled", "timed_out", "orphaned"].includes(state);
}
