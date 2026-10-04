// Frame-accurate renderer: seeks the paused GSAP timeline, screenshots each frame, encodes with x264.
//   node render.mjs                      → out/glance-promo.mp4 (1080p60)
//   node render.mjs --fps=30             → faster draft
//   node render.mjs --stills=4.5,12,20   → out/stills/*.png
//   node render.mjs --audio              → out/score.wav only
import { chromium } from "playwright";
import { spawn } from "node:child_process";
import { mkdir, writeFile, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const dir = path.dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.replace(/^--/, "").split("=");
    return [k, v ?? true];
  }),
);
const fps = Number(args.fps || 60);
const workers = Number(args.workers || Math.min(6, Math.max(2, os.cpus().length - 2)));
const outDir = path.join(dir, "out");
const url = `${pathToFileURL(path.join(dir, "film.html")).href}?render`;

async function openPage(browser) {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on("pageerror", (e) => console.error("pageerror:", e.message));
  page.on("console", (m) => m.type() === "error" && console.error("console:", m.text()));
  await page.goto(url);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 30000 });
  return page;
}

async function renderAudio(browser, file) {
  const page = await openPage(browser);
  const { sampleRate, channels, peak, data } = await page.evaluate(() =>
    window.renderScore(window.__film.cues, window.__film.music, window.__film.duration));
  await page.close();
  const pcm = Buffer.from(data, "base64");
  const head = Buffer.alloc(44);
  head.write("RIFF", 0);
  head.writeUInt32LE(36 + pcm.length, 4);
  head.write("WAVEfmt ", 8);
  head.writeUInt32LE(16, 16);
  head.writeUInt16LE(1, 20);
  head.writeUInt16LE(channels, 22);
  head.writeUInt32LE(sampleRate, 24);
  head.writeUInt32LE(sampleRate * channels * 2, 28);
  head.writeUInt16LE(channels * 2, 32);
  head.writeUInt16LE(16, 34);
  head.write("data", 36);
  head.writeUInt32LE(pcm.length, 40);
  await writeFile(file, Buffer.concat([head, pcm]));
  console.log(`${file}  (raw peak ${peak.toFixed(2)})`);
}

function run(cmd, argv, opts = {}) {
  const p = spawn(cmd, argv, { stdio: ["pipe", "inherit", "inherit"], ...opts });
  p.done = new Promise((res, rej) => p.on("close", (c) => (c === 0 ? res() : rej(new Error(`${cmd} exited ${c}`)))));
  return p;
}

async function renderChunk(browser, from, to, file, onFrame) {
  const page = await openPage(browser);
  const ff = run("ffmpeg", [
    "-y", "-loglevel", "error",
    "-f", "image2pipe", "-framerate", String(fps), "-c:v", "mjpeg", "-i", "-",
    "-c:v", "libx264", "-preset", "medium", "-crf", "15", "-tune", "film",
    "-pix_fmt", "yuv420p", "-r", String(fps), file,
  ]);
  for (let f = from; f < to; f++) {
    await page.evaluate((t) => window.__film.seek(t), f / fps);
    const buf = await page.screenshot({ type: "jpeg", quality: 95 });
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once("drain", r));
    onFrame();
  }
  ff.stdin.end();
  await ff.done;
  await page.close();
}

const browser = await chromium.launch({ args: ["--allow-file-access-from-files", "--font-render-hinting=none"] });

try {
  if (args.audio) {
    await mkdir(outDir, { recursive: true });
    await renderAudio(browser, path.join(outDir, "score.wav"));
  } else if (args.stills) {
    await mkdir(path.join(outDir, "stills"), { recursive: true });
    const page = await openPage(browser);
    for (const t of String(args.stills).split(",").map(Number)) {
      await page.evaluate((x) => window.__film.seek(x), t);
      const file = path.join(outDir, "stills", `${t.toFixed(2).padStart(6, "0")}.png`);
      await page.screenshot({ path: file });
      console.log(file);
    }
  } else {
    const page = await openPage(browser);
    const duration = await page.evaluate(() => window.__film.duration);
    await page.close();

    const total = Math.ceil(duration * fps);
    const segDir = path.join(outDir, "segments");
    await rm(segDir, { recursive: true, force: true });
    await mkdir(segDir, { recursive: true });

    const per = Math.ceil(total / workers);
    let done = 0;
    const t0 = Date.now();
    const tick = () => {
      done++;
      if (done % 150 === 0 || done === total) {
        const el = (Date.now() - t0) / 1000;
        console.log(`${done}/${total} frames  ${el.toFixed(0)}s elapsed  ~${((el / done) * (total - done)).toFixed(0)}s left`);
      }
    };
    const segs = [];
    const jobs = [];
    for (let w = 0; w < workers; w++) {
      const from = w * per, to = Math.min(total, from + per);
      if (from >= to) break;
      const file = path.join(segDir, `seg${w}.mp4`);
      segs.push(file);
      jobs.push(renderChunk(browser, from, to, file, tick));
    }
    const wav = path.join(outDir, "score.wav");
    jobs.push(renderAudio(browser, wav));
    await Promise.all(jobs);
    console.log();

    const list = path.join(segDir, "list.txt");
    await writeFile(list, segs.map((s) => `file '${s}'`).join("\n"));
    const name = args.out || (fps === 60 ? "glance-promo.mp4" : `glance-promo-${fps}fps.mp4`);
    const final = path.join(outDir, name);
    await run("ffmpeg", [
      "-y", "-loglevel", "error",
      "-f", "concat", "-safe", "0", "-i", list, "-i", wav,
      "-map", "0:v", "-map", "1:a", "-c:v", "copy",
      "-af", "loudnorm=I=-16:TP=-1.5:LRA=11", "-ar", "48000", "-c:a", "aac", "-b:a", "256k",
      "-t", duration.toFixed(3), "-movflags", "+faststart", final,
    ]).done;
    await rm(segDir, { recursive: true, force: true });
    console.log(`${final}  (${duration.toFixed(2)}s, ${total} frames @ ${fps}fps)`);
  }
} finally {
  await browser.close();
}
