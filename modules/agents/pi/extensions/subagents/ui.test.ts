import assert from "node:assert/strict";
import test from "node:test";
import type { SubagentState, SubagentStatus } from "./types.ts";
import { attachedChildView, renderAttachedChildView, renderInspector, renderSummary, widget } from "./ui.ts";

function status(overrides: Partial<SubagentStatus> & { id: string; label: string; state: SubagentState }): SubagentStatus {
  return {
    adHoc: true,
    context: "independent",
    cwd: "/tmp",
    elapsedMs: 0,
    activityHistory: [],
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

test("expanded monitor shows concise current activity summaries instead of raw event types", () => {
  const rendered = widget([
    status({
      id: "sg-reading",
      label: "Audit guest enablement plan",
      state: "running",
      elapsedMs: 12_000,
      lastEvent: "message_update",
      currentActivity: {
        type: "message_update",
        summary: "read secret-notes.md",
        at: "2026-08-01T00:00:12.000Z",
      },
    }),
  ], true)().render(240);

  assert.deepEqual(rendered, ["▶ running   12s Audit guest enablement plan last: read secret-notes.md"]);
  assert.doesNotMatch(rendered.join("\n"), /message_update|private transcript body/u);
});

test("attached child view is read-only, renders transcript activity, and supports detach plus scrolling", () => {
  const child = status({ id: "sg-child", label: "Research worker", state: "running" });
  const activity = Array.from({ length: 24 }, (_, index) => ({
    type: "message_update",
    summary: `assistant message ${index + 1}`,
    at: `2026-08-01T00:00:${String(index + 1).padStart(2, "0")}.000Z`,
    role: "assistant",
    text: `captured child message ${index + 1}`,
  }));

  const bottom = renderAttachedChildView(child, activity, { width: 100, scrollOffset: 0 });
  assert.match(bottom.join("\n"), /read-only attached view/u);
  assert.match(bottom.join("\n"), /Esc\/q detach/u);
  assert.match(bottom.join("\n"), /captured child message 24/u);
  assert.doesNotMatch(bottom.join("\n"), /> |prompt|send|input channel/ui);

  const scrolled = renderAttachedChildView(child, activity, { width: 100, scrollOffset: 6 });
  assert.match(scrolled.join("\n"), /captured child message 1[0-9]/u);
  assert.doesNotMatch(scrolled.join("\n"), /captured child message 24/u);

  let detached = false;
  const component = attachedChildView({
    status: () => child,
    activity: () => activity,
    onDetach: () => {
      detached = true;
    },
  });
  component.handleInput("\u001b[A");
  assert.doesNotMatch(component.render(100).join("\n"), /captured child message 24/u);
  component.handleInput("\u001b[B");
  assert.match(component.render(100).join("\n"), /captured child message 24/u);
  component.handleInput("q");
  assert.equal(detached, true);
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
