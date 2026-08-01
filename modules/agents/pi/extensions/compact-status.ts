import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type QuotaState =
  | { status: "idle" | "loading" }
  | { status: "ok"; detail: string; refreshedAt: number; weeklyRemaining?: number; shortRemaining?: number }
  | { status: "missing" | "error"; detail: string; refreshedAt?: number };

const CODEX_USAGE_ENDPOINTS = [
  "https://chatgpt.com/backend-api/wham/usage",
  "https://chatgpt.com/backend-api/codex/usage",
];
const QUOTA_REFRESH_MS = 5 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 10_000;

let quotaState: QuotaState = { status: "idle" };
let quotaRefreshPromise: Promise<void> | null = null;

function shortCwd(cwd: string): string {
  const home = process.env.HOME;
  if (home && cwd.startsWith(`${home}/`)) return `~/${basename(cwd)}`;
  return basename(cwd) || cwd;
}

function gitBranch(cwd: string): string | null {
  try {
    const out = execFileSync("git", ["--no-optional-locks", "symbolic-ref", "--quiet", "--short", "HEAD"], {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    return out || null;
  } catch {
    return null;
  }
}

function authPath(): string {
  return join(process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent"), "auth.json");
}

function readCodexCredentials(): { access: string; accountId?: string } | null {
  const file = authPath();
  if (!existsSync(file)) return null;
  try {
    const auth = JSON.parse(readFileSync(file, "utf8"));
    const credential = auth?.["openai-codex"];
    if (credential?.type !== "oauth" || typeof credential.access !== "string") return null;
    if (typeof credential.expires === "number" && credential.expires <= Date.now() + 30_000) return null;
    return {
      access: credential.access,
      accountId: typeof credential.accountId === "string" ? credential.accountId : undefined,
    };
  } catch {
    return null;
  }
}

function numberValue(value: unknown): number | undefined {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return undefined;
}

function objectValue(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : undefined;
}

function windowSeconds(raw: Record<string, unknown>): number | undefined {
  const seconds = numberValue(raw.limit_window_seconds ?? raw.windowSeconds);
  if (seconds !== undefined) return seconds;
  const mins = numberValue(raw.windowDurationMins ?? raw.window_duration_mins);
  return mins === undefined ? undefined : mins * 60;
}

function usedPercent(raw: Record<string, unknown>): number | undefined {
  const value = numberValue(raw.used_percent ?? raw.usedPercent);
  if (value === undefined) return undefined;
  return Math.max(0, Math.min(100, value));
}

function collectWindows(raw: unknown, out: Array<{ seconds?: number; used: number; key: string }> = [], key = "root") {
  if (Array.isArray(raw)) {
    raw.forEach((item, index) => collectWindows(item, out, `${key}.${index}`));
    return out;
  }
  const obj = objectValue(raw);
  if (!obj) return out;
  const used = usedPercent(obj);
  if (used !== undefined) out.push({ seconds: windowSeconds(obj), used, key });
  for (const [childKey, value] of Object.entries(obj)) {
    if (value && typeof value === "object") collectWindows(value, out, `${key}.${childKey}`);
  }
  return out;
}

function pickQuotaWindows(raw: unknown): { weeklyRemaining?: number; shortRemaining?: number } | null {
  const windows = collectWindows(raw);
  if (windows.length === 0) return null;
  const weekly = windows.find((window) => window.seconds !== undefined && Math.abs(window.seconds - 604_800) <= 60 * 60)
    ?? windows.find((window) => /week|weekly|secondary/i.test(window.key));
  const short = windows.find((window) => window.seconds !== undefined && Math.abs(window.seconds - 18_000) <= 60 * 30)
    ?? windows.find((window) => /five|session|primary|short/i.test(window.key));
  return {
    weeklyRemaining: weekly ? Math.max(0, Math.min(100, 100 - weekly.used)) : undefined,
    shortRemaining: short ? Math.max(0, Math.min(100, 100 - short.used)) : undefined,
  };
}

function safeFg(theme: any, color: string, text: string): string {
  try {
    return theme.fg(color, text);
  } catch {
    return theme.fg("accent", text);
  }
}

function contextColor(percent: number): string {
  if (percent >= 90) return "error";
  if (percent >= 70) return "warning";
  return "success";
}

function quotaColor(percent: number): string {
  if (percent >= 80) return "error";
  if (percent >= 50) return "warning";
  return "border";
}

function bar(theme: any, width: number, percent: number | null, glyph: string, colorForPercent: (percent: number) => string): string {
  const barWidth = Math.max(12, width);
  if (percent === null) return theme.fg("muted", glyph.repeat(barWidth));
  const clamped = Math.max(0, Math.min(100, percent));
  const filled = Math.max(0, Math.min(barWidth, Math.round((clamped / 100) * barWidth)));
  const empty = Math.max(0, barWidth - filled);
  return safeFg(theme, colorForPercent(clamped), glyph.repeat(filled)) + theme.fg("dim", glyph.repeat(empty));
}

async function fetchCodexQuota(force = false): Promise<void> {
  const fresh = quotaState.status === "ok" && Date.now() - quotaState.refreshedAt < QUOTA_REFRESH_MS;
  if (!force && fresh) return;
  if (quotaRefreshPromise) return quotaRefreshPromise;

  quotaState = { status: "loading" };
  quotaRefreshPromise = (async () => {
    const credentials = readCodexCredentials();
    if (!credentials) {
      quotaState = { status: "missing", detail: "OpenAI Codex OAuth credentials were not found or are expired" };
      return;
    }

    let lastError = "quota unavailable";
    for (const endpoint of CODEX_USAGE_ENDPOINTS) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
      try {
        const headers: Record<string, string> = { Authorization: `Bearer ${credentials.access}` };
        if (credentials.accountId) headers["ChatGPT-Account-Id"] = credentials.accountId;
        const response = await fetch(endpoint, { headers, signal: controller.signal });
        if (!response.ok) {
          lastError = `${response.status} ${response.statusText}`;
          continue;
        }
        const windows = pickQuotaWindows(await response.json());
        if (!windows || (windows.weeklyRemaining === undefined && windows.shortRemaining === undefined)) {
          lastError = "response had no recognized quota windows";
          continue;
        }
        const details = [];
        if (windows.weeklyRemaining !== undefined) details.push(`weekly ${Math.round(windows.weeklyRemaining)}%`);
        if (windows.shortRemaining !== undefined) details.push(`short ${Math.round(windows.shortRemaining)}%`);
        quotaState = {
          status: "ok",
          detail: `Codex quota remaining: ${details.join(", ")}`,
          weeklyRemaining: windows.weeklyRemaining,
          shortRemaining: windows.shortRemaining,
          refreshedAt: Date.now(),
        };
        return;
      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);
      } finally {
        clearTimeout(timeout);
      }
    }
    quotaState = { status: "error", detail: `Codex quota failed: ${lastError}`, refreshedAt: Date.now() };
  })().finally(() => {
    quotaRefreshPromise = null;
  });
  return quotaRefreshPromise;
}

function statusLines(ctx: any, theme: any, width: number): string[] {
  const cwd = ctx.sessionManager?.getCwd?.() ?? ctx.cwd ?? process.cwd();
  const branch = gitBranch(cwd);
  const where = branch ? `󰉋 ${shortCwd(cwd)} 󰘬 ${branch}` : `󰉋 ${shortCwd(cwd)}`;
  const model = ctx.model?.id ?? process.env.PI_MODEL ?? "no-model";
  const thinking = ctx.thinkingLevel ?? process.env.PI_REASONING_LEVEL ?? "off";
  const left = theme.fg("accent", where);
  const right = theme.fg("dim", `${model} • ${thinking}`);
  const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
  const contextPercentRaw = ctx.getContextUsage?.()?.percent;
  const contextPercent = typeof contextPercentRaw === "number" && Number.isFinite(contextPercentRaw) ? contextPercentRaw : null;
  const quotaConsumed = quotaState.status === "ok" && quotaState.weeklyRemaining !== undefined
    ? 100 - quotaState.weeklyRemaining
    : null;
  return [
    truncateToWidth(left + pad + right, width),
    bar(theme, width, contextPercent, "▃", contextColor),
    bar(theme, width, quotaConsumed, "▔", quotaColor),
  ];
}

function setCompactStatusUi(ctx: any) {
  if (!ctx.hasUI) return;
  ctx.ui.setWidget("compact-status", (_tui: any, theme: any) => ({
    invalidate() {},
    render(width: number) {
      return statusLines(ctx, theme, width);
    },
  }));
  ctx.ui.setFooter(() => ({ invalidate() {}, render: () => [] }));
}

export default function compactStatus(pi: ExtensionAPI) {
  function refreshUi(ctx: any) {
    setCompactStatusUi(ctx);
  }

  pi.on("session_start", (_event, ctx) => {
    refreshUi(ctx);
    void fetchCodexQuota(false).then(() => refreshUi(ctx));
  });
  pi.on("model_select", (_event, ctx) => refreshUi(ctx));
  pi.on("agent_settled", (_event, ctx) => refreshUi(ctx));

  pi.registerCommand("codex-quota", {
    description: "Refresh and show ChatGPT Codex quota",
    handler: async (_args, ctx) => {
      refreshUi(ctx);
      await fetchCodexQuota(true);
      refreshUi(ctx);
      const level = quotaState.status === "ok" ? "info" : quotaState.status === "missing" ? "warning" : "error";
      ctx.ui.notify(quotaState.status === "idle" || quotaState.status === "loading" ? "Codex quota refresh in progress" : quotaState.detail, level);
    },
  });
}
