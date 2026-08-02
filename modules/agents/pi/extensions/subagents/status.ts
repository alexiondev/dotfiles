import { SUBAGENT_STATES, SUBAGENT_TERMINAL_STATES } from "./types.ts";
import type { ChildRecord, SpawnAccepted, SubagentResult, SubagentState, SubagentStatus } from "./types.ts";

export function toAccepted(status: SubagentStatus): SpawnAccepted {
  return {
    id: status.id,
    label: status.label,
    context: status.context,
    tools: status.tools,
    state: status.state,
    hint: `Use subagent_status or subagent_result with id ${status.id}`,
  };
}

export function cloneStatus(status: SubagentStatus): SubagentStatus {
  return {
    ...status,
    currentActivity: status.currentActivity ? { ...status.currentActivity } : undefined,
    activityHistory: status.activityHistory.map((event) => ({ ...event })),
    elapsedMs: elapsedMs(status),
  };
}

export function cloneResult(record: ChildRecord): SubagentResult {
  const status = cloneStatus(record.status);
  const terminal = isTerminalState(status.state);
  return {
    id: status.id,
    label: status.label,
    state: status.state,
    running: !terminal,
    resultAvailable: status.resultAvailable,
    result: record.result,
    error: status.error,
    completedAt: status.completedAt,
    elapsedMs: status.elapsedMs,
  };
}

export function isTerminalState(state: SubagentState): boolean {
  return (SUBAGENT_TERMINAL_STATES as readonly string[]).includes(state);
}

export function milestoneNotification(status: SubagentStatus, event: string): { message: string; level: "info" | "error" } | undefined {
  if (!isSubagentState(event) || !isTerminalState(event)) return undefined;
  return { message: `Subagent ${status.label} ${event}`, level: event === "completed" ? "info" : "error" };
}

export function isSubagentState(value: string): value is SubagentState {
  return (SUBAGENT_STATES as readonly string[]).includes(value);
}

export function elapsedMs(status: Pick<SubagentStatus, "startedAt" | "completedAt">): number {
  const start = Date.parse(status.startedAt);
  const end = status.completedAt ? Date.parse(status.completedAt) : Date.now();
  if (!Number.isFinite(start) || !Number.isFinite(end)) return 0;
  return Math.max(0, end - start);
}
