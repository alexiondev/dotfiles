import assert from "node:assert/strict";
import test from "node:test";
import { Supervisor } from "./supervisor.ts";
import type { ChildHandle, ChildRunner, RunnerEvents, SpawnRequest } from "./types.ts";

class FakeHandle implements ChildHandle {
  cancelCalls = 0;

  async cancel(): Promise<void> {
    this.cancelCalls += 1;
  }
}

class FakeRunner implements ChildRunner {
  starts: Array<{ id: string; request: SpawnRequest; events: RunnerEvents; handle: FakeHandle }> = [];
  autoAccept = true;

  async start(id: string, request: SpawnRequest, _cwd: string, events: RunnerEvents): Promise<ChildHandle> {
    const handle = new FakeHandle();
    this.starts.push({ id, request, events, handle });
    if (this.autoAccept) events.accepted(`session-${id}`);
    return handle;
  }
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function spawnStarted(supervisor: Supervisor, prompt = "work") {
  const accepted = supervisor.spawn({ prompt });
  await sleep(0);
  return accepted;
}

test("cancel is idempotent and reaches cancelled", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const accepted = await spawnStarted(supervisor);

  const first = await supervisor.cancel(accepted.id);
  const second = await supervisor.cancel(accepted.id);

  assert.equal(first.state, "cancelled");
  assert.equal(second.state, "cancelled");
  assert.equal(runner.starts[0].handle.cancelCalls, 1);
});

test("startup timeout reaches timed_out", async () => {
  const runner = new FakeRunner();
  runner.autoAccept = false;
  const supervisor = new Supervisor(runner, "/tmp", { timeouts: { startMs: 5 } });
  const accepted = await spawnStarted(supervisor);

  await sleep(20);

  const status = supervisor.status(accepted.id);
  assert.equal(status.state, "timed_out");
  assert.equal(status.stopReason, "start_timeout");
  assert.equal(runner.starts[0].handle.cancelCalls, 1);
});

test("runtime timeout reaches timed_out", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp", { timeouts: { runMs: 5 } });
  const accepted = await spawnStarted(supervisor);

  await sleep(20);

  const status = supervisor.status(accepted.id);
  assert.equal(status.state, "timed_out");
  assert.equal(status.stopReason, "run_timeout");
  assert.equal(runner.starts[0].handle.cancelCalls, 1);
});

test("process failure reaches failed with diagnostics", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const accepted = await spawnStarted(supervisor);

  runner.starts[0].events.failed("process closed with code 1");

  const status = supervisor.status(accepted.id);
  assert.equal(status.state, "failed");
  assert.equal(status.error, "process closed with code 1");
});

test("shutdown cancels running children", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const accepted = await spawnStarted(supervisor);

  await supervisor.shutdown();

  const status = supervisor.status(accepted.id);
  assert.equal(status.state, "cancelled");
  assert.equal(status.stopReason, "shutdown");
  assert.equal(runner.starts[0].handle.cancelCalls, 1);
});

test("completed children ignore later cancel", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const accepted = await spawnStarted(supervisor);

  runner.starts[0].events.completed("done", "agent_settled");
  await supervisor.cancel(accepted.id);

  const result = supervisor.result(accepted.id);
  assert.equal(result.state, "completed");
  assert.equal(result.result, "done");
  assert.equal(runner.starts[0].handle.cancelCalls, 0);
});

test("batch spawn returns accepted ids and per-entry failures", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");

  const result = supervisor.spawnBatch([{ prompt: "one" }, { prompt: "" }, { prompt: "two" }]);
  await sleep(0);

  assert.equal(result.accepted.length, 2);
  assert.equal(result.failed.length, 1);
  assert.equal(result.failed[0].index, 1);
  assert.equal(runner.starts.length, 2);
});

test("maxConcurrent preserves queued records", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp", { maxConcurrent: 1 });

  const result = supervisor.spawnBatch([{ prompt: "one" }, { prompt: "two" }]);
  await sleep(0);

  assert.equal(result.accepted.length, 2);
  assert.equal(runner.starts.length, 1);
  assert.equal(supervisor.status(result.accepted[1].id).state, "queued");

  runner.starts[0].events.completed("done", "agent_settled");
  await sleep(0);

  assert.equal(runner.starts.length, 2);
});

test("wait blocks until multiple subagents are terminal", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const first = await spawnStarted(supervisor, "one");
  const second = await spawnStarted(supervisor, "two");

  const waiting = supervisor.wait([first.id, second.id], { timeoutMs: 100 });
  runner.starts[0].events.completed("one done", "agent_settled");
  await sleep(0);

  assert.equal(await Promise.race([waiting.then(() => "done"), sleep(10).then(() => "pending")]), "pending");

  runner.starts[1].events.failed("two failed");
  const result = await waiting;

  assert.equal(result.timedOut, false);
  assert.equal(result.ready, true);
  assert.deepEqual(result.ids, [first.id, second.id]);
  assert.equal(result.pending.length, 0);
  assert.deepEqual(result.results.map((item) => item.state), ["completed", "failed"]);
  assert.equal(result.results[0].result, "one done");
  assert.equal(result.results[1].error, "two failed");
});

test("wait returns pending statuses on timeout", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const first = await spawnStarted(supervisor, "one");
  const second = await spawnStarted(supervisor, "two");

  runner.starts[0].events.completed("one done", "agent_settled");
  const result = await supervisor.wait([first.id, second.id], { timeoutMs: 5 });

  assert.equal(result.timedOut, true);
  assert.equal(result.ready, false);
  assert.deepEqual(result.results.map((item) => item.state), ["completed", "running"]);
  assert.deepEqual(result.pending.map((item) => item.id), [second.id]);
});

test("wait any returns after the first terminal subagent", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const first = await spawnStarted(supervisor, "one");
  const second = await spawnStarted(supervisor, "two");

  const waiting = supervisor.wait([first.id, second.id], { mode: "any", timeoutMs: 100 });
  runner.starts[1].events.completed("two done", "agent_settled");
  const result = await waiting;

  assert.equal(result.timedOut, false);
  assert.equal(result.ready, true);
  assert.deepEqual(result.results.map((item) => item.state), ["running", "completed"]);
  assert.deepEqual(result.pending.map((item) => item.id), [first.id]);
});

test("wait rejects unknown and empty id sets", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");

  await assert.rejects(() => supervisor.wait([]), /at least one subagent id is required/);
  await assert.rejects(() => supervisor.wait(["missing"]), /unknown subagent id: missing/);
});

test("wait abort rejects without cancelling child", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp");
  const accepted = await spawnStarted(supervisor, "one");
  const controller = new AbortController();

  const waiting = supervisor.wait([accepted.id], { signal: controller.signal });
  controller.abort();

  await assert.rejects(waiting, /subagent wait aborted/);
  assert.equal(runner.starts[0].handle.cancelCalls, 0);
});

test("wait follows queued subagents through queue start and completion", async () => {
  const runner = new FakeRunner();
  const supervisor = new Supervisor(runner, "/tmp", { maxConcurrent: 1 });
  const batch = supervisor.spawnBatch([{ prompt: "one" }, { prompt: "two" }]);
  await sleep(0);

  const waiting = supervisor.wait([batch.accepted[1].id], { timeoutMs: 100 });
  assert.equal(await Promise.race([waiting.then(() => "done"), sleep(10).then(() => "pending")]), "pending");

  runner.starts[0].events.completed("one done", "agent_settled");
  await sleep(0);
  runner.starts[1].events.completed("two done", "agent_settled");
  const result = await waiting;

  assert.equal(result.timedOut, false);
  assert.equal(result.ready, true);
  assert.deepEqual(result.results.map((item) => item.result), ["two done"]);
});
