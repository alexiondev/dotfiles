export type ContextMode = "independent" | "fork";

export const SUBAGENT_STATES = ["queued", "starting", "running", "settling", "completed", "failed", "cancelled", "timed_out", "orphaned"] as const;
export const SUBAGENT_TERMINAL_STATES = ["completed", "failed", "cancelled", "timed_out", "orphaned"] as const;

export type SubagentState = (typeof SUBAGENT_STATES)[number];

export interface ToolProfile {
  activeTools: string[] | null;
}

export interface SpawnRequest {
  prompt: string;
  label?: string;
  context?: ContextMode;
  agent?: string;
  model?: string;
  thinking?: string;
  tools?: string;
  toolProfile?: ToolProfile;
  agentBody?: string;
  parentSessionFile?: string;
}

export interface SpawnAccepted {
  id: string;
  label: string;
  context: ContextMode;
  tools: string;
  state: SubagentState;
  hint: string;
}

export interface SubagentStatus {
  id: string;
  label: string;
  agent?: string;
  adHoc: boolean;
  context: ContextMode;
  state: SubagentState;
  cwd: string;
  model?: string;
  thinking?: string;
  tools: string;
  startedAt: string;
  completedAt?: string;
  elapsedMs: number;
  lastEvent?: string;
  lastEventAt?: string;
  stopReason?: string;
  resultAvailable: boolean;
  childSession?: string;
  error?: string;
}

export interface SubagentResult {
  id: string;
  label: string;
  state: SubagentState;
  running: boolean;
  resultAvailable: boolean;
  result?: string;
  error?: string;
  completedAt?: string;
  elapsedMs: number;
}

export type SubagentWaitMode = "all" | "any";

export interface SubagentWaitResult {
  ids: string[];
  mode: SubagentWaitMode;
  ready: boolean;
  results: SubagentResult[];
  pending: SubagentStatus[];
  timedOut: boolean;
  elapsedMs: number;
}

export interface ChildRecord {
  status: SubagentStatus;
  result?: string;
}

export interface RunnerEvents {
  accepted(childSession?: string): void;
  running(event: string): void;
  settling(): void;
  completed(result: string, stopReason?: string): void;
  failed(error: string): void;
}

export interface ChildHandle {
  cancel(): Promise<void>;
}

export interface ChildRunner {
  start(id: string, request: SpawnRequest, cwd: string, events: RunnerEvents): Promise<ChildHandle>;
}
