import assert from "node:assert/strict";
import test from "node:test";
import type { SubagentState, SubagentStatus } from "./types.ts";
import { renderInspector, renderSummary, widget } from "./ui.ts";

function status(overrides: Partial<SubagentStatus> & { id: string; label: string; state: SubagentState }): SubagentStatus {
  return {
    adHoc: true,
    context: "independent",
    cwd: "/tmp",
    elapsedMs: 0,
    resultAvailable: false,
    startedAt: "2026-08-01T00:00:00.000Z",
    tools: "inherit",
    ...overrides,
  };
}

test("compact monitor aggregates visible children by actionable lifecycle group", () => {
  assert.deepEqual(renderSummary([]), []);

  assert.deepEqual(
    renderSummary([
      status({ id: "queued", label: "Queued", state: "queued" }),
      status({ id: "starting", label: "Starting", state: "starting" }),
      status({ id: "running", label: "Running", state: "running" }),
      status({ id: "settling", label: "Settling", state: "settling" }),
      status({ id: "completed", label: "Completed", state: "completed", resultAvailable: true }),
      status({ id: "failed", label: "Failed", state: "failed", error: "boom" }),
      status({ id: "timed-out", label: "Timed out", state: "timed_out" }),
      status({ id: "cancelled", label: "Cancelled", state: "cancelled" }),
    ]),
    ["subagents: queued 1 · running 2 · settling 1 · completed 1 · failed 1 · timed out 1 · cancelled 1"],
  );
});

test("expanded monitor renders one truncated row per child with state, elapsed time, and activity marker", () => {
  const lines = renderInspector([
    status({
      id: "sg-running",
      label: "Audit unusually verbose guest enablement migration plan",
      state: "running",
      elapsedMs: 65_000,
      lastEvent: "message_update",
    }),
    status({
      id: "sg-completed",
      label: "Summarize review",
      state: "completed",
      elapsedMs: 3_600_000,
      lastEvent: "completed",
      resultAvailable: true,
    }),
    status({ id: "sg-failed", label: "Run risky test", state: "failed", elapsedMs: 2_000, error: "exit 1" }),
  ]);

  assert.equal(lines.length, 3);
  assert.match(lines[0], /^▶ running +1m05s +Audit unusually verbose guest enablement migration plan +last: message_update$/u);
  assert.equal(lines[1], "✓ completed 1h00m00s Summarize review result: available");
  assert.equal(lines[2], "✗ failed    2s Run risky test error: exit 1");

  const rendered = widget([
    status({ id: "sg-running", label: "Audit unusually verbose guest enablement migration plan", state: "running", elapsedMs: 65_000, lastEvent: "message_update" }),
  ], true)().render(32);

  assert.deepEqual(rendered, ["▶ running   1m05s Audit unusual…"]);
  assert.ok(rendered.every((line) => line.length <= 32));
});
