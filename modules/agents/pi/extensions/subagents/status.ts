import type { ChildRecord, SpawnAccepted, SubagentResult, SubagentStatus } from "./types.ts";

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
  return { ...status, elapsedMs: elapsedMs(status) };
}

export function cloneResult(record: ChildRecord): SubagentResult {
  const status = cloneStatus(record.status);
  const terminal = ["completed", "failed", "cancelled", "timed_out", "orphaned"].includes(status.state);
  return {
    id: status.id,
    state: status.state,
    running: !terminal,
    resultAvailable: status.resultAvailable,
    result: record.result,
    error: status.error,
    completedAt: status.completedAt,
    elapsedMs: status.elapsedMs,
  };
}

export function elapsedMs(status: Pick<SubagentStatus, "startedAt" | "completedAt">): number {
  const start = Date.parse(status.startedAt);
  const end = status.completedAt ? Date.parse(status.completedAt) : Date.now();
  if (!Number.isFinite(start) || !Number.isFinite(end)) return 0;
  return Math.max(0, end - start);
}
