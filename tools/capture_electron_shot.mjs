// Screenshot the source (Three.js) build at a fixed logical size and device
// pixel ratio, on the GPU, for pixel comparison against a Godot capture.
//
//   node tools/capture_electron_shot.mjs out.png [query] [width height dpr] [script|@file]
//
// Unlike the source's own shot.mjs this runs ANGLE on Metal (a real GPU, so
// WebGL MSAA is the MSAA the Electron app gets) and emulates the Retina DPR the
// Electron window sees, so the PNG is width*dpr by height*dpr physical pixels.
// Serve the build first: python3 -m http.server 8123 -d dist  (or vite preview).
import { spawn } from "node:child_process";
import { writeFileSync, existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { guardChrome } from "./capture_browser.mjs";

const OUT = process.argv[2] ?? "electron-shot.png";
const QUERY = process.argv[3] ?? "?seed=7&title=0&grow=1,1,1,1&daylen=0&hud=0&aurora=0&bow=0&tod=0.35&wx=shroud:0,cloud:0.06,mist:0.02,haze:0.03,wind:0.4&cam=43,1.13,1.8893,0,3,0";
const WIDTH = Number(process.argv[4] ?? 1440);
const HEIGHT = Number(process.argv[5] ?? 900);
const DPR = Number(process.argv[6] ?? 2);
const URL_BASE = process.env.ZS_URL ?? "http://localhost:8123/";
const SETTLE_MS = Number(process.env.ZS_SETTLE ?? 6000);
// Optional page script run once the scene is up, before the settle; "@file"
// reads it from disk. Whatever it returns is printed.
const SCRIPT_ARG = process.argv[7] ?? "";
const SCRIPT = SCRIPT_ARG.startsWith("@") ? (await import("node:fs")).readFileSync(SCRIPT_ARG.slice(1), "utf8") : SCRIPT_ARG;

const root = join(homedir(), ".cache/puppeteer/chrome");
if (!existsSync(root)) throw new Error("no cached Chrome at " + root);
const ver = readdirSync(root).sort().pop();
const BIN = join(root, ver, "chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing");

const PORT = 9333 + (process.pid % 400);
const PROFILE = "/tmp/zs-electron-shot-" + process.pid;
const chrome = spawn(BIN, [
  `--remote-debugging-port=${PORT}`,
  "--headless=new",
  `--window-size=${WIDTH},${HEIGHT}`,
  "--use-angle=metal",
  "--enable-gpu-rasterization",
  "--ignore-gpu-blocklist",
  "--use-mock-keychain",
  "--password-store=basic",
  "--no-first-run",
  "--no-sandbox",
  "--user-data-dir=" + PROFILE,
  "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });
const reapChrome = guardChrome(chrome, PROFILE);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let wsUrl = null;
for (let i = 0; i < 100 && !wsUrl; i++) {
  try { wsUrl = (await (await fetch(`http://127.0.0.1:${PORT}/json/version`)).json()).webSocketDebuggerUrl; }
  catch { await sleep(100); }
}
if (!wsUrl) throw new Error("chrome never came up");
const ws = new WebSocket(wsUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
const noise = [];
ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  else if (msg.method === "Runtime.exceptionThrown") noise.push("[pageerror] " + (msg.params.exceptionDetails?.exception?.description ?? ""));
  else if (msg.method === "Runtime.consoleAPICalled" && msg.params.type === "error") noise.push("[error] " + (msg.params.args ?? []).map((a) => a.value ?? a.description ?? "").join(" "));
};
const send = (method, params = {}, sessionId) =>
  new Promise((res) => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params, sessionId })); });

const { result: { targetId } } = await send("Target.createTarget", { url: "about:blank" });
const { result: { sessionId } } = await send("Target.attachToTarget", { targetId, flatten: true });
await send("Runtime.enable", {}, sessionId);
await send("Page.enable", {}, sessionId);
await send("Emulation.setDeviceMetricsOverride", { width: WIDTH, height: HEIGHT, deviceScaleFactor: DPR, mobile: false }, sessionId);
await send("Page.navigate", { url: URL_BASE + QUERY }, sessionId);

const evalJs = async (expr) => {
  const r = await send("Runtime.evaluate", { expression: `(async () => (${expr}))()`, awaitPromise: true, returnByValue: true }, sessionId);
  if (r.result?.exceptionDetails) throw new Error(JSON.stringify(r.result.exceptionDetails.exception));
  return r.result?.result?.value;
};
const started = Date.now();
while (Date.now() - started < 60000) {
  if ((await evalJs("window.__dbg ? __dbg.frames : -1")) > 8) break;
  await sleep(300);
}
const info = await evalJs(`(() => { const d = __dbg; d.controls.autoRotate = false; const gl = d.renderer.getContext(); return { dpr: d.renderer.getPixelRatio(), buffer: [d.renderer.domElement.width, d.renderer.domElement.height], samples: gl.getParameter(gl.SAMPLES), renderer: gl.getExtension("WEBGL_debug_renderer_info") ? gl.getParameter(gl.getExtension("WEBGL_debug_renderer_info").UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER), exposure: d.renderer.toneMappingExposure, tone: d.renderer.toneMapping, frames: d.frames }; })()`).catch((e) => ({ error: String(e) }));
console.log("source renderer:", JSON.stringify(info));
if (SCRIPT) console.log("script:", JSON.stringify(await evalJs(SCRIPT).catch((e) => ({ error: String(e) }))));
await sleep(SETTLE_MS);
const shot = await send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false }, sessionId);
if (shot.result?.data) {
  writeFileSync(OUT, Buffer.from(shot.result.data, "base64"));
  console.log(`wrote ${OUT}`);
} else {
  console.error("no screenshot:", JSON.stringify(shot).slice(0, 400));
}
if (noise.length) console.log(noise.slice(0, 10).join("\n"));
ws.close();
reapChrome();
process.exit(0);
