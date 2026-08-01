import type { ChildHandle, ChildRecord, ChildRunner, ContextMode, RunnerEvents, SpawnAccepted, SpawnRequest, SubagentResult, SubagentStatus } from "./types.ts";
import { cloneResult, cloneStatus, toAccepted } from "./status.ts";

interface RunningChild {
  record: ChildRecord;
  handle?: ChildHandle;
}

export class Supervisor {
  private nextChild = 0;
  private readonly children = new Map<string, RunningChild>();

  constructor(
    private readonly runner: ChildRunner,
    private readonly cwd: string,
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

    setTimeout(() => {
      if (isTerminal(child.record.status.state)) return;
      void this.runner
        .start(id, { ...request, prompt, context: status.context, tools: status.tools }, this.cwd, this.eventsFor(child.record))
        .then((handle) => {
          child.handle = handle;
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
    const now = new Date().toISOString();
    child.record.status.state = "cancelled";
    child.record.status.completedAt = now;
    child.record.status.lastEvent = "cancelled";
    child.record.status.lastEventAt = now;
    child.record.status.stopReason = "cancelled";
    return cloneStatus(child.record.status);
  }

  async shutdown(): Promise<void> {
    await Promise.allSettled(
      [...this.children.values()].map(async (child) => {
        if (!isTerminal(child.record.status.state)) await child.handle?.cancel();
      }),
    );
  }

  private eventsFor(record: ChildRecord): RunnerEvents {
    return {
      accepted: (childSession) => {
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
    const now = new Date().toISOString();
    record.status.state = "failed";
    record.status.completedAt = now;
    record.status.lastEvent = "failed";
    record.status.lastEventAt = now;
    record.status.error = error;
    record.status.stopReason = "failed";
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
