import type { SubagentActivityEvent, SubagentState, SubagentStatus } from "./types.ts";

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

export interface AttachedChildViewOptions {
  status: () => SubagentStatus;
  activity: () => SubagentActivityEvent[];
  onDetach: () => void;
  onChange?: () => void;
}

export function attachedChildView(options: AttachedChildViewOptions) {
  let scrollOffset = 0;
  return {
    invalidate() {},
    render(width: number) {
      const status = options.status();
      const activity = options.activity();
      const lines = renderAttachedChildView(status, activity, { width, scrollOffset });
      scrollOffset = clampScrollOffset(scrollOffset, transcriptLines(activity).length, attachedViewportHeight(width));
      return lines;
    },
    handleInput(data: string) {
      const key = keyName(data);
      if (key === "escape" || data === "q") {
        options.onDetach();
        return;
      }
      const viewportHeight = attachedViewportHeight(80);
      if (key === "up") scrollOffset += 1;
      else if (key === "down") scrollOffset -= 1;
      else if (key === "pageup") scrollOffset += viewportHeight;
      else if (key === "pagedown") scrollOffset -= viewportHeight;
      else return;
      scrollOffset = clampScrollOffset(scrollOffset, options.activity().length, viewportHeight);
      options.onChange?.();
    },
  };
}

export function renderAttachedChildView(status: SubagentStatus, activity: SubagentActivityEvent[], options: { width: number; scrollOffset?: number }): string[] {
  const viewportHeight = attachedViewportHeight(options.width);
  const body = transcriptLines(activity);
  const offset = clampScrollOffset(options.scrollOffset ?? 0, body.length, viewportHeight);
  const start = Math.max(0, body.length - viewportHeight - offset);
  const visible = body.slice(start, start + viewportHeight);
  const scrollHint = body.length > viewportHeight ? ` · ${start + 1}-${start + visible.length}/${body.length}` : "";
  const lines = [
    `subagent ${status.id} · ${status.label} · ${STATE_PRESENTATION[status.state].label}`,
    `read-only attached view · ↑/↓ scroll · PgUp/PgDn · Esc/q detach${scrollHint}`,
    "",
    ...(visible.length > 0 ? visible : ["system  no captured child activity yet"]),
  ];
  return lines.map((line) => truncateLine(line, options.width));
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

function attachedViewportHeight(width: number): number {
  return width < 60 ? 8 : 18;
}

function transcriptLines(activity: SubagentActivityEvent[]): string[] {
  return activity.map((event) => transcriptLine(event));
}

function transcriptLine(event: SubagentActivityEvent): string {
  if (event.error) return `tool    ${event.tool ?? event.type} failed: ${event.error}`;
  if (event.tool) return `tool    ${event.tool}${event.phase ? ` ${event.phase}` : ""}${valueHint(event.input)}`;
  if (event.text) return `${(event.role ?? "assistant").padEnd(8)} ${event.text}`;
  if (event.output !== undefined) return `tool    ${event.type} output${valueHint(event.output)}`;
  return `system  ${event.summary}`;
}

function valueHint(value: unknown): string {
  if (value === undefined) return "";
  if (typeof value === "string") return ` ${truncateActivityHint(value)}`;
  if (!value || typeof value !== "object" || Array.isArray(value)) return "";
  const path = (value as { path?: unknown }).path;
  if (typeof path === "string" && path.trim()) return ` ${path.trim()}`;
  const command = (value as { command?: unknown }).command;
  if (typeof command === "string" && command.trim()) return ` ${truncateActivityHint(command.trim())}`;
  return "";
}

function truncateActivityHint(value: string): string {
  return value.length <= 80 ? value : `${value.slice(0, 79).trimEnd()}…`;
}

function clampScrollOffset(offset: number, lineCount: number, viewportHeight: number): number {
  return Math.max(0, Math.min(offset, Math.max(0, lineCount - viewportHeight)));
}

function keyName(data: string): string {
  if (data === "\u001b") return "escape";
  if (data === "\u001b[A") return "up";
  if (data === "\u001b[B") return "down";
  if (data === "\u001b[5~") return "pageup";
  if (data === "\u001b[6~") return "pagedown";
  return data;
}
