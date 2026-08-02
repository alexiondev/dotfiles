import type { SubagentState, SubagentStatus } from "./types.ts";

const COMPACT_GROUPS: Array<{ label: string; states: SubagentState[] }> = [
  { label: "queued", states: ["queued"] },
  { label: "running", states: ["starting", "running"] },
  { label: "settling", states: ["settling"] },
  { label: "completed", states: ["completed"] },
  { label: "failed", states: ["failed"] },
  { label: "timed out", states: ["timed_out"] },
  { label: "cancelled", states: ["cancelled"] },
  { label: "orphaned", states: ["orphaned"] },
];

const STATE_PRESENTATION: Record<SubagentState, { icon: string; label: string }> = {
  queued: { icon: "…", label: "queued" },
  starting: { icon: "◌", label: "starting" },
  running: { icon: "▶", label: "running" },
  settling: { icon: "◒", label: "settling" },
  completed: { icon: "✓", label: "completed" },
  failed: { icon: "✗", label: "failed" },
  cancelled: { icon: "■", label: "cancelled" },
  timed_out: { icon: "⏱", label: "timed out" },
  orphaned: { icon: "?", label: "orphaned" },
};

export function renderSummary(statuses: SubagentStatus[]): string[] {
  const groups = COMPACT_GROUPS.map((group) => ({
    label: group.label,
    count: statuses.filter((status) => group.states.includes(status.state)).length,
  })).filter((group) => group.count > 0);

  if (groups.length === 0) return [];
  return [`subagents: ${groups.map((group) => `${group.label} ${group.count}`).join(" · ")}`];
}

export function renderInspector(statuses: SubagentStatus[]): string[] {
  return statuses.map((status) => renderStatusRow(status));
}

export function widget(statuses: SubagentStatus[], expanded: boolean) {
  return () => ({
    invalidate() {},
    render(width: number) {
      return (expanded ? renderInspector(statuses) : renderSummary(statuses)).map((line) => truncateLine(line, width));
    },
  });
}

function renderStatusRow(status: SubagentStatus): string {
  const presentation = STATE_PRESENTATION[status.state];
  const marker = statusMarker(status);
  return `${presentation.icon} ${presentation.label.padEnd(9)} ${formatDuration(status.elapsedMs)} ${status.label}${marker ? ` ${marker}` : ""}`;
}

function statusMarker(status: SubagentStatus): string | undefined {
  if (status.error) return `error: ${status.error}`;
  if (status.resultAvailable) return "result: available";
  if (status.currentActivity) return `last: ${status.currentActivity.summary}`;
  if (status.lastEvent) return `last: ${status.lastEvent}`;
  if (status.state === "queued") return "waiting";
  if (status.state === "settling") return "settling";
  return undefined;
}

function formatDuration(elapsedMs: number): string {
  const totalSeconds = Math.max(0, Math.round(elapsedMs / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  if (hours > 0) return `${hours}h${String(minutes).padStart(2, "0")}m${String(seconds).padStart(2, "0")}s`;
  if (minutes > 0) return `${minutes}m${String(seconds).padStart(2, "0")}s`;
  return `${seconds}s`;
}

function truncateLine(line: string, width: number): string {
  if (width <= 0) return "";
  if (line.length <= width) return line;
  if (width === 1) return "…";
  return `${line.slice(0, width - 1)}…`;
}
