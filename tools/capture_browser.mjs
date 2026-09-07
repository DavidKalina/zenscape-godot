// Every headless probe spawns a Chrome that outlives it if we aren't careful:
// swiftshader keeps rendering the scene at ~300% CPU forever, and the profile
// dir keeps its megabytes. The old `chrome.kill()` at the bottom of each probe
// only ran on the happy path, so a thrown assert, a Ctrl-C, or an EPIPE from
// `probe | head` left an orphan behind. This wires the browser's life to the
// probe's, on every exit path there is.
import { spawn } from "node:child_process";
import { existsSync, readdirSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, basename, join } from "node:path";

// The probe's own waits are all bounded; this is the backstop for the ones
// that aren't — a CDP connect that never resolves, a page that never loads.
const DEFAULT_TIMEOUT_MS = 180_000;

// The exit-time cleanup below is best-effort: Chrome's helpers keep writing to
// the profile for a moment after the root dies, and a SIGKILL'd probe never
// gets to run a handler at all. So each run also sweeps the leavings of every
// dead run that shared its prefix — that's the path that actually keeps /tmp
// from growing without bound.
function sweepStaleProfiles(profileDir) {
  const prefix = basename(profileDir).replace(/-\d+$/, "");
  const parent = dirname(profileDir);
  for (const name of readdirSync(parent)) {
    const m = name.match(new RegExp(`^${prefix}-(\\d+)$`));
    if (!m) continue;
    const pid = Number(m[1]);
    if (pid === process.pid) continue;
    try { process.kill(pid, 0); continue; } catch (e) { if (e.code === "EPERM") continue; }  // still alive
    try { rmSync(join(parent, name), { recursive: true, force: true }); } catch {}
  }
}

export function guardChrome(chrome, profileDir, { timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  try { sweepStaleProfiles(profileDir); } catch {}
  let done = false;
  // Must stay synchronous: process "exit" handlers can't await anything.
  const reap = () => {
    if (done) return;
    done = true;
    try { chrome.kill("SIGKILL"); } catch {}          // helpers are its children, they go too
    try { rmSync(profileDir, { recursive: true, force: true }); } catch {}
  };

  // A throw (or an EPIPE from a closed stdout) unwinds into "exit"; signals
  // don't, so they get their own handlers and set the exit code themselves.
  process.on("exit", reap);
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
    process.on(sig, () => { reap(); process.exit(1); });
  }

  // unref'd so it never holds the process open — it only fires if we're still
  // alive and stuck at the deadline.
  const watchdog = setTimeout(() => {
    console.error(`\nprobe-chrome: watchdog fired after ${timeoutMs}ms — killing Chrome`);
    reap();
    process.exit(1);
  }, timeoutMs);
  watchdog.unref();

  return reap;
}

// ---------------------------------------------------------------------------
// openBrowser(name) — a headless page with the app in it, and a way to ask it
// questions.
//
// Every CDP probe here was the same eighty lines before its first assertion:
// find puppeteer's cached Chrome, spawn it on a debugging port, wait for the
// socket, attach to a target, and wrap Runtime.evaluate. That is boilerplate,
// it was diverging copy by copy, and none of it is what any probe is about.
// (shot.mjs keeps its own: it also pipes console and takes pictures, which is
// a different job.)
//
// The flags are the ones headless macOS actually needs — swiftshader because
// there is no GPU, mock-keychain because otherwise Chromium raises a real
// prompt AT THE USER.
// ---------------------------------------------------------------------------
export async function openBrowser(name, { flags = [] } = {}) {
  const urlBase = process.env.ZS_URL ?? "http://localhost:8123/";
  const root = join(homedir(), ".cache/puppeteer/chrome");
  if (!existsSync(root)) throw new Error("no cached Chrome at " + root);
  const ver = readdirSync(root).sort().pop();
  const BIN = join(root, ver, "chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing");

  const port = 9333 + (process.pid % 400);
  const profile = `/tmp/zs-${name}-${process.pid}`;
  const chrome = spawn(BIN, [
    `--remote-debugging-port=${port}`,
    "--headless=new",
    "--window-size=1280,800",
    "--use-angle=swiftshader",
    "--enable-unsafe-swiftshader",
    "--use-mock-keychain",
    "--password-store=basic",
    "--no-first-run",
    "--no-sandbox",
    "--user-data-dir=" + profile,
    // …plus whatever this probe needs that the rest do not. The audio probes
    // need --autoplay-policy=no-user-gesture-required: a synthetic keydown is
    // not a trusted gesture, and without it the context sits suspended and
    // proves nothing.
    ...flags,
    "about:blank",
  ], { stdio: ["ignore", "ignore", "pipe"] });
  guardChrome(chrome, profile);

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  let wsUrl = null;
  for (let i = 0; i < 100 && !wsUrl; i++) {
    try {
      wsUrl = (await (await fetch(`http://127.0.0.1:${port}/json/version`)).json()).webSocketDebuggerUrl;
    } catch { await sleep(100); }
  }
  if (!wsUrl) throw new Error("chrome never came up");

  const ws = new WebSocket(wsUrl);
  ws.onerror = (e) => { console.error("Capture websocket error", e.message); process.exit(1); };
  ws.onclose = (e) => { console.error("Capture websocket closed", e.code, e.reason); process.exit(1); };
  await new Promise((r) => (ws.onopen = r));
  let id = 0;
  const pending = new Map();
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  };
  const send = (method, params = {}, sessionId) =>
    new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params, sessionId })); });

  const { result: { targetId } } = await send("Target.createTarget", { url: "about:blank" });
  const { result: { sessionId } } = await send("Target.attachToTarget", { targetId, flatten: true });
  await send("Runtime.enable", {}, sessionId);
  await send("Page.enable", {}, sessionId);

  // Every expression is awaited and returned by value, so a probe can `await`
  // in the page and read a plain object back. An exception in there is thrown
  // HERE rather than resolved as undefined — a probe that quietly reads
  // undefined out of a broken page prints a wall of confident nonsense.
  const evalJs = async (expr) => {
    const r = await send(
      "Runtime.evaluate",
      { expression: `(async () => (${expr}))()`, awaitPromise: true, returnByValue: true },
      sessionId
    );
    if (r.result?.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails.exception));
    return r.result?.result?.value;
  };

  // Navigate and wait for the app to be RUNNING, not merely loaded: a page that
  // has parsed main.js but never linked its shaders answers questions about a
  // world that does not exist yet.
  async function open(query) {
    await send("Page.navigate", { url: urlBase + query }, sessionId);
    const started = Date.now();
    while (Date.now() - started < 30000) {
      if ((await evalJs("window.__dbg ? __dbg.frames : -1")) > 8) return;
      await sleep(300);
    }
    throw new Error("the app never rendered a frame at " + query);
  }

  return { evalJs, open, sleep };
}

// The scoreboard every probe here keeps. Detail is printed only on a failure:
// half of these are the reading and half are the diagnosis, and a diagnosis
// beside an "ok" reads like a bug report.
export function makeChecks() {
  let fails = 0;
  const check = (name, ok, detail = "") => {
    console.log(`${ok ? " ok " : "FAIL"} ${name}${!ok && detail ? ` — ${detail}` : ""}`);
    if (!ok) fails++;
  };
  check.done = (msg) => {
    console.log(fails ? `\n${fails} FAILED` : `\n${msg}`);
    process.exit(fails ? 1 : 0);
  };
  return check;
}
