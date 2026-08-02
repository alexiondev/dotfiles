import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { EventEmitter } from "node:events";
import { fileURLToPath } from "node:url";
import test from "node:test";
import type { RunnerEvents } from "./types.ts";

class FakeStream extends EventEmitter {
  setEncoding(_encoding: BufferEncoding): void {}

  write(_chunk: string, callback?: (error?: Error | null) => void): boolean {
    callback?.();
    return true;
  }

  end(): void {}
}

function events(): RunnerEvents {
  return {
    accepted: () => {},
    running: () => {},
    settling: () => {},
    completed: () => {},
    failed: () => {},
  };
}

test("child RPC process forwards structured activity before collecting the final result", async (t) => {
  const running: unknown[] = [];
  const completed: Array<{ result: string; stopReason?: string }> = [];
  const fakeChild = new EventEmitter() as EventEmitter & {
    stdout: FakeStream;
    stderr: FakeStream;
    stdin: FakeStream;
    killed: boolean;
    pid?: number;
    kill(signal?: NodeJS.Signals): boolean;
  };
  fakeChild.stdout = new FakeStream();
  fakeChild.stderr = new FakeStream();
  fakeChild.stdin = new FakeStream();
  fakeChild.killed = false;
  fakeChild.kill = () => {
    fakeChild.killed = true;
    return true;
  };
  t.mock.method(fakeChild.stdin, "write", (chunk, callback?: (error?: Error | null) => void) => {
    const request = JSON.parse(String(chunk)) as { id: string; type: string };
    callback?.();
    if (request.type === "get_last_assistant_text") {
      queueMicrotask(() => {
        fakeChild.stdout.emit("data", `${JSON.stringify({ id: request.id, type: "response", success: true, data: { text: "final answer" } })}\n`);
      });
    }
    return true;
  });
  t.mock.method(childProcess, "spawn", () => fakeChild as unknown as childProcess.ChildProcessWithoutNullStreams);

  const { SubprocessRpcRunner } = await import("./runner.ts");
  const runner = new SubprocessRpcRunner();
  await runner.start("child-1", { prompt: "work", label: "Review migration" }, "/tmp", {
    ...events(),
    running: (event) => running.push(event),
    completed: (result, stopReason) => completed.push({ result, stopReason }),
  });

  const firstActivity = { type: "message_start", role: "assistant", message: { id: "msg-1" } };
  const secondActivity = { type: "tool_execution_start", tool: "read", input: { path: "runner.ts" } };
  const settledActivity = { type: "agent_settled" };
  fakeChild.stdout.emit("data", `${JSON.stringify(firstActivity)}\n${JSON.stringify(secondActivity)}\n${JSON.stringify(settledActivity)}\n`);
  await new Promise((resolve) => setImmediate(resolve));

  assert.deepEqual(running, [firstActivity, secondActivity, settledActivity]);
  assert.deepEqual(completed, [{ result: "final answer", stopReason: "agent_settled" }]);
});

test("child RPC process disables discovery while explicitly loading subagents extension", async (t) => {
  const calls: Array<{ command: string; args: string[] }> = [];
  const fakeChild = new EventEmitter() as EventEmitter & {
    stdout: FakeStream;
    stderr: FakeStream;
    stdin: FakeStream;
    killed: boolean;
    pid?: number;
    kill(signal?: NodeJS.Signals): boolean;
  };
  fakeChild.stdout = new FakeStream();
  fakeChild.stderr = new FakeStream();
  fakeChild.stdin = new FakeStream();
  fakeChild.killed = false;
  fakeChild.kill = () => {
    fakeChild.killed = true;
    return true;
  };
  const spawn = t.mock.method(childProcess, "spawn", (command, args) => {
    calls.push({ command: String(command), args: Array.isArray(args) ? args.map(String) : [] });
    return fakeChild as unknown as childProcess.ChildProcessWithoutNullStreams;
  });

  const { SubprocessRpcRunner } = await import("./runner.ts");
  const runner = new SubprocessRpcRunner();
  await runner.start("child-1", { prompt: "work", label: "Review migration" }, "/tmp", events());

  assert.equal(spawn.mock.callCount(), 1);
  const args = calls[0].args;
  const noExtensionsIndex = args.indexOf("--no-extensions");
  const extensionIndex = args.indexOf("--extension");

  const nameIndex = args.indexOf("--name");

  assert.notEqual(noExtensionsIndex, -1, "child args keep automatic extension discovery disabled");
  assert.notEqual(nameIndex, -1, "child args include a process name");
  assert.equal(args[nameIndex + 1], "subagent Review migration");
  assert.notEqual(extensionIndex, -1, "child args explicitly load the subagents extension entry");
  assert.equal(args[extensionIndex + 1], fileURLToPath(new URL("./index.ts", import.meta.url)));
  assert.ok(noExtensionsIndex < extensionIndex);
});
