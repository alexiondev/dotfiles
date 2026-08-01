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
  await runner.start("child-1", { prompt: "work" }, "/tmp", events());

  assert.equal(spawn.mock.callCount(), 1);
  const args = calls[0].args;
  const noExtensionsIndex = args.indexOf("--no-extensions");
  const extensionIndex = args.indexOf("--extension");

  assert.notEqual(noExtensionsIndex, -1, "child args keep automatic extension discovery disabled");
  assert.notEqual(extensionIndex, -1, "child args explicitly load the subagents extension entry");
  assert.equal(args[extensionIndex + 1], fileURLToPath(new URL("./index.ts", import.meta.url)));
  assert.ok(noExtensionsIndex < extensionIndex);
});
