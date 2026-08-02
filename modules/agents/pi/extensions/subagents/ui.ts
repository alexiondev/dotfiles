import { isTerminalState } from "./status.ts";
import type { SubagentStatus } from "./types.ts";

export function renderSummary(statuses: SubagentStatus[]): string[] {
  const running = statuses.filter((status) => ["starting", "running", "settling"].includes(status.state)).length;
  const queued = statuses.filter((status) => status.state === "queued").length;
  const terminal = statuses.filter((status) => isTerminalState(status.state)).length;
  if (running === 0 && queued === 0 && terminal === 0) return [];
  return [`subagents: ${running} running · ${queued} queued · ${terminal} recent`];
}

export function renderInspector(statuses: SubagentStatus[]): string[] {
  const lines = renderSummary(statuses);
  for (const status of statuses) {
    lines.push(
      `${status.id} ${status.label} ${status.context} ${status.state} ${Math.round(status.elapsedMs / 1000)}s ${status.model ?? "inherit"} ${status.tools} ${status.lastEvent ?? "none"} result:${status.resultAvailable ? "yes" : "no"}`,
    );
  }
  return lines;
}

export function widget(statuses: SubagentStatus[], expanded: boolean) {
  return () => ({
    invalidate() {},
    render(width: number) {
      return (expanded ? renderInspector(statuses) : renderSummary(statuses)).map((line) => (line.length > width ? line.slice(0, Math.max(0, width - 1)) : line));
    },
  });
}
