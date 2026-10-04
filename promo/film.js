gsap.registerPlugin(CustomEase);
CustomEase.create("swift", "0.65,0,0.35,1");

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const stage = $("#stage");
const params = new URLSearchParams(location.search);
const RENDER = params.has("render");

let stageScale = 1;
function fit() {
  stageScale = RENDER ? 1 : Math.min(innerWidth / 1920, innerHeight / 1080);
  const dx = (innerWidth - 1920 * stageScale) / 2;
  const dy = (innerHeight - 1080 * stageScale) / 2;
  stage.style.transform = `translate(${dx}px, ${dy}px) scale(${stageScale})`;
}
fit();
addEventListener("resize", fit);

function rect(el) {
  const s = stage.getBoundingClientRect();
  const r = el.getBoundingClientRect();
  const k = stageScale;
  return {
    left: (r.left - s.left) / k, top: (r.top - s.top) / k,
    width: r.width / k, height: r.height / k,
    cx: (r.left - s.left + r.width / 2) / k, cy: (r.top - s.top + r.height / 2) / k,
  };
}

function splitChars(el) {
  const text = el.textContent;
  el.textContent = "";
  return [...text].map((c) => {
    const s = document.createElement("span");
    s.textContent = c;
    el.appendChild(s);
    return s;
  });
}

const lines = (root) => $$(".ln > span", typeof root === "string" ? $(root) : root);

/* ---------------- generated DOM ---------------- */

const GHOSTS = [
  [560, 300, 600, 400, -3, "收件箱 — 42 封未读"],
  [820, 240, 560, 380, 2, "需求评审.pptx"],
  [380, 420, 520, 360, -1, "浏览器 — 37 个标签页"],
  [1000, 470, 580, 380, 3, "会议纪要 (3).docx"],
  [700, 520, 540, 340, -2, "终端 — zsh"],
  [260, 180, 480, 320, 1.5, "日历"],
  [1240, 160, 460, 320, -2.5, "Slack — 12 条新消息"],
  [620, 140, 500, 300, 1, "下载"],
  [1180, 600, 480, 330, -1.5, "Figma — Glance UI"],
  [300, 640, 500, 320, 2.5, "表格 — Q4 计划"],
  [860, 380, 520, 360, -0.5, "预览 — 合同.pdf"],
  [1400, 380, 420, 300, 2, "备忘录"],
];
const ghostsIn = $("#ghostsIn");
const ghostEls = GHOSTS.map(([x, y, w, h, r, t], i) => {
  const g = document.createElement("div");
  g.className = "ghost";
  g.style.cssText = `left:${x}px;top:${y}px;width:${w}px;height:${h}px`;
  const ls = Array.from({ length: Math.floor(h / 48) }, (_, j) => `<div class="g-ln" style="width:${40 + ((i * 37 + j * 23) % 50)}%"></div>`).join("");
  g.innerHTML = `<div class="g-tb"><i></i><i></i><i></i><span>${t}</span></div>${ls}`;
  ghostsIn.appendChild(g);
  return g;
});

const ghostPanels = $("#ghostPanels");
ghostPanels.innerHTML = $("#panels").innerHTML;
$$("[id]", ghostPanels).forEach((e) => e.removeAttribute("id"));

const ROWS = [
  ["i-pin", "今天要完成的事", "今天要完成的事 把<em class='hl'>需求</em>整理成可执行的下一步。回复邮件前先列清问题。", "面板", "12 分钟前", 0],
  ["i-pin", "本周安排", "整理<em class='hl'>需求</em> · 回复邮件 · 提交版本", "面板", "12 分钟前", 1],
  ["i-pin", "会议纪要", "# 会议纪要 · 范围保持本地优先 · Beta 先走 GitHub 与 Homebrew", "面板", "12 分钟前", -1],
  ["i-clip", "把<em class='hl'>需求</em>整理成可执行的下一步。", "把需求整理成可执行的下一步。", "剪贴板", "2 小时前", 2],
  ["i-clip", "请审核最新设计稿件", "请审核最新设计稿件", "剪贴板", "2 小时前", -1],
  ["i-clip", "git commit -m 'update'", "git commit -m 'update'", "剪贴板", "2 小时前", -1],
  ["i-tray", "版本计划.md", "MD · 4 KB", "文件架", "2 小时前", -1],
  ["i-tray", "<em class='hl'>需求</em>说明.md", "MD · 2 KB", "文件架", "2 小时前", 3],
];
const swList = $("#swList");
const rowEls = ROWS.map(([ic, t, s, src, time, slot], i) => {
  const r = document.createElement("div");
  r.className = "row";
  r.style.top = `${i * 80}px`;
  r.innerHTML = `<svg><use href="#${ic}"/></svg><b>${t}</b><small>${s}</small><div class="rm">${src}<em>${time}</em></div>`;
  r.dataset.slot = slot;
  swList.appendChild(r);
  return r;
});

const FLOW_X = [300, 740, 1180, 1620];
const flow = $("#flow");
const flowWords = [], flowNodes = [];
["Capture", "Store", "Find", "Act"].forEach((w, i) => {
  const x = FLOW_X[i];
  const fw = document.createElement("div");
  fw.className = "fw ln";
  fw.style.left = `${x - 300}px`;
  fw.innerHTML = `<span>${w}</span>`;
  const nd = document.createElement("i");
  nd.className = "node";
  nd.style.left = `${x}px`;
  flow.append(fw, nd);
  flowWords.push(fw.firstChild);
  flowNodes.push(nd);
});

const ring2 = $("#ring1").cloneNode();
ring2.id = "ring2";
$("#s8").appendChild(ring2);

// Sound cues sit next to the animation they belong to; score.js turns them into audio.
const CUES = [];
const sfx = (name, t, opts = {}) => CUES.push({ name, t, ...opts });
const MUSIC = {};

/* ---------------- build ---------------- */

async function build() {
  await Promise.all([
    document.fonts.load("500 200px NY"),
    document.fonts.load("italic 136px NY"),
    document.fonts.load("600 20px SFP"),
    document.fonts.load("20px SFM"),
  ]);
  await document.fonts.ready;

  // measure everything in its resting layout before any transforms are applied
  const pill = $("#pill");
  const pillW = pill.getBoundingClientRect().width / stageScale;
  pill.style.width = `${pillW}px`;
  pill.style.left = `${960 - pillW / 2}px`;

  const M = {
    mbPin: rect($("#mbPin")),
    cb2: rect($("#cb2")),
    pChd: rect($("#pChd")),
    qcType: rect($("#qcType")),
    snip: rect($("#tSnip")),
    keys: rect($("#keys4")),
    k4slot: rect($("#k4slot")),
    tClip: rect($("#tClip")),
    rwClip: rect($("#rwClip")),
    ddoc: rect($("#ddoc")),
    fileIcon: rect($("#fileNew .doc")),
  };
  const chip = $("#chip");
  chip.style.left = `${M.qcType.left - 68}px`;
  chip.style.top = `${M.qcType.top - 16}px`;
  M.chip = rect(chip);

  const lenOf = (el) => el.getTotalLength();
  const flowPath = $("#flowPath");
  const flowLen = lenOf(flowPath);
  const lp = [$("#lpScreen"), $("#lpBase")];
  lp.forEach((el) => { const l = lenOf(el); gsap.set(el, { strokeDasharray: l, strokeDashoffset: l }); });
  gsap.set(flowPath, { strokeDasharray: flowLen, strokeDashoffset: flowLen });

  const word1 = splitChars($("#word1 .wm"));
  const word2 = splitChars($("#word2 .wm"));
  const qcChars = splitChars($("#qcType"));
  const swChars = splitChars($("#swType"));
  const brewChars = splitChars($("#brew"));

  // cloud → laptop connection, drawn as two halves that can snap apart
  const C = { x: 1640, y: 172 }, L = { x: 1347, y: 262 };
  const Mid = { x: (C.x + L.x) / 2, y: (C.y + L.y) / 2 };
  const placeSeg = (el, a, b) => {
    const len = Math.hypot(b.x - a.x, b.y - a.y);
    const ang = (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI;
    el.style.cssText = `left:${a.x}px;top:${a.y - 1}px;width:${len}px`;
    gsap.set(el, { rotation: ang, transformOrigin: "0% 50%" });
    return ang;
  };
  const angA = placeSeg($("#segA"), C, Mid);
  const angB = placeSeg($("#segB"), L, Mid);
  gsap.set($("#snap"), { left: Mid.x, top: Mid.y });

  /* ---------- initial states ---------- */
  const [body1, shadow1, note1] = $$("#mark1 > div");
  const [body2, shadow2, note2, stem2, dot2] = $$("#mark2 > div");
  const pin1 = $("#pin1");
  const cursor = $("#cursor");

  gsap.set([body1, body2], { autoAlpha: 0, scale: 0.56 });
  gsap.set([shadow1, shadow2], { autoAlpha: 0, x: -16, y: -16 });
  gsap.set(note1, { autoAlpha: 0, scale: 0.92 });
  gsap.set(note2, { autoAlpha: 0, y: 60, scale: 0.9 });
  gsap.set(pin1, { y: -820 });
  gsap.set([stem2, dot2], { y: -820 });
  gsap.set(ghostEls, { z: -1600, y: 60, autoAlpha: 0, filter: "blur(0px)" });
  gsap.set(ghostsIn, { rotationX: 10, rotationY: -10 });
  gsap.set("#s1cam", { scale: 1.06, filter: "blur(0px)" });
  gsap.set([...word1, ...word2], { yPercent: 112, rotation: 7 });
  gsap.set(["#tag1 span", "#tag2"], { autoAlpha: 0, y: 18, filter: "blur(8px)" });
  gsap.set($$(".ln > span"), { yPercent: 112 });

  gsap.set("#s3cam", { autoAlpha: 0, scale: 1.12, filter: "blur(14px) brightness(1)" });
  gsap.set("#mb", { y: -40 });
  gsap.set("#mbPin", { autoAlpha: 0, scale: 1.6 });
  gsap.set(["#pA", "#pB", "#pC"], { y: 150, rotationX: -28, transformPerspective: 1400, transformOrigin: "50% 100%", autoAlpha: 0, filter: "blur(10px)" });
  gsap.set(["#aw1", "#aw2"], { y: 920 });
  gsap.set("#ck2", { scale: 0 });
  gsap.set(cursor, { x: 1180, y: 1010, transformOrigin: "4px 3px" });

  const kbds = $$("#keys4 kbd");
  const kbdShadow = getComputedStyle(kbds[0]).boxShadow;
  gsap.set(kbds, { y: 60, autoAlpha: 0, scale: 0.9 });
  gsap.set("#qc", { autoAlpha: 0, scale: 0.92, y: 40, filter: "blur(16px)" });
  gsap.set([...qcChars, ...swChars, ...brewChars], { display: "none" });
  gsap.set("#qcKind", { autoAlpha: 0, x: -12 });
  gsap.set(["#opt1", "#opt2", "#opt3"], { autoAlpha: 0, x: 24 });
  gsap.set("#qcHl", { autoAlpha: 0, scaleX: 0.94 });
  gsap.set("#qcOk", { scale: 0 });
  gsap.set(chip, { autoAlpha: 0 });

  const tiles = $$(".tile");
  const revealAt = `${M.chip.cx}px ${M.chip.cy - 14}px`;
  gsap.set("#s5", { clipPath: `circle(0px at ${revealAt})` });
  gsap.set(tiles, { autoAlpha: 0, y: 90, rotationX: -24, transformOrigin: "50% 100%", filter: "blur(0px)" });
  gsap.set(flowNodes, { scale: 0 });

  gsap.set("#track", { filter: "blur(0px)" });
  gsap.set("#clipNew", { autoAlpha: 0, y: -30 });
  gsap.set("#fileNew", { autoAlpha: 0, scale: 0.97 });
  gsap.set(["#clipSel", "#fileSel", "#snipSel", "#linkSel"], { autoAlpha: 0 });
  gsap.set($$(".toast"), { xPercent: -50, autoAlpha: 0, y: 14 });
  gsap.set("#ddoc", { rotation: 14 });
  gsap.set("#morph", { left: M.tClip.left, top: M.tClip.top, width: M.tClip.width, height: M.tClip.height, borderRadius: 32 });

  const T = 57; // half the horizontal travel of the skewed bar between top and bottom
  const wipePoly = (e) => `polygon(-400px 0px, ${e + T}px 0px, ${e - T}px 1080px, -400px 1080px)`;
  gsap.set("#s6", { clipPath: wipePoly(-180), filter: "blur(0px)" });
  gsap.set("#wipebar", { x: -300 });
  gsap.set("#sw", { y: 30, scale: 0.97, filter: "blur(0px)" });
  gsap.set("#fs", { autoAlpha: 0, x: 220 });
  gsap.set($$("#k6 .kc"), { autoAlpha: 0, y: 10 });
  gsap.set("#lb2", { autoAlpha: 0, y: 8 });
  gsap.set("#swSel", { autoAlpha: 0 });
  gsap.set("#s6cam", { filter: "blur(0px)" });
  gsap.set(["#laptop", "#privH"], { filter: "blur(0px)" });
  gsap.set("#cloud", { autoAlpha: 0, y: -12 });
  gsap.set("#segA", { clipPath: "inset(0% 100% 0% 0%)" });
  gsap.set("#segB", { clipPath: "inset(0% 0% 0% 100%)" });

  gsap.set(["#glow"], { autoAlpha: 0, scale: 0.6, x: 300, y: 80 });
  gsap.set("#pill", { autoAlpha: 0, y: 24 });

  /* ---------- timeline ---------- */
  const tl = gsap.timeline({ paused: true, defaults: { ease: "expo.out", duration: 1 } });

  const blink = (el, from, to) => {
    const period = 0.53;
    let n = Math.max(1, Math.floor((to - from) / period) - 1);
    if (n % 2 === 0) n -= 1;
    if (n < 1) return;
    tl.to(el, { opacity: 0, duration: period, ease: "steps(1)", repeat: n, yoyo: true }, from);
  };
  const type = (chars, at, cps, gain = 1) => chars.forEach((c, i) => {
    tl.set(c, { display: "inline" }, at + i / cps);
    if (c.textContent.trim()) sfx("type", at + i / cps, { gain, seed: i });
  });

  // S1 — a single note, buried by windows
  tl.to(note1, { autoAlpha: 1, scale: 1, duration: 1.4 }, 0.15);
  tl.to("#s1cam", { scale: 1, duration: 4.4, ease: "sine.out" }, 0);
  tl.to(ghostsIn, { rotationX: 2, rotationY: 4, duration: 4.6, ease: "sine.inOut" }, 0);
  tl.to(ghostEls, { z: 0, y: 0, autoAlpha: 1, duration: 1.3, stagger: 0.19 }, 0.85);
  ghostEls.forEach((_, i) => sfx("swish", 0.85 + i * 0.19, { gain: 0.16 + (i % 3) * 0.05, pan: ((i * 7) % 5) / 2 - 1 }));
  tl.to(lines("#head1"), { yPercent: 0, duration: 1.2 }, 1.6);
  tl.to(lines("#head1"), { yPercent: -112, duration: 0.6, ease: "power3.in" }, 3.5);
  tl.set("#head1", { autoAlpha: 0 }, 4.2);

  // the pin goes through everything
  const IMPACT = 4.45;
  MUSIC.impact = IMPACT;
  tl.to(pin1, { y: 0, duration: 0.5, ease: "power4.in" }, IMPACT - 0.5);
  sfx("fall", IMPACT - 0.5, { dur: 0.5 });
  sfx("boom", IMPACT, { gain: 1 });
  tl.to(pin1, { keyframes: { y: [0, 9, -5, 2, 0] }, duration: 0.45, ease: "none" }, IMPACT);
  tl.to("#s1cam", { keyframes: { y: [0, 9, -5, 2, 0] }, duration: 0.45, ease: "none" }, IMPACT);
  tl.fromTo("#ring1", { scale: 0.4, autoAlpha: 0.9 }, { scale: 7, autoAlpha: 0, duration: 1.3, immediateRender: false }, IMPACT);
  tl.to("#flood", { clipPath: "circle(1400px at 960px 540px)", duration: 1.5 }, IMPACT + 0.02);
  tl.to(body1, { autoAlpha: 1, scale: 1, duration: 1.3 }, IMPACT);
  tl.to(shadow1, { autoAlpha: 1, x: 0, y: 0 }, IMPACT + 0.25);
  ghostEls.forEach((g, i) => {
    const [x, y, w, h, r] = GHOSTS[i];
    const dx = x + w / 2 - 960, dy = y + h / 2 - 540;
    const d = Math.hypot(dx, dy) || 1;
    const push = 900 + (i % 3) * 260;
    tl.to(g, {
      x: (dx / d) * push, y: (dy / d) * push * 0.75, z: 420, rotation: r * 7,
      autoAlpha: 0, filter: "blur(18px)", duration: 1.15, ease: "power3.out",
    }, IMPACT + d / 5000);
  });

  // S2 — the mark and the name
  tl.to([$("#mark1"), pin1], { x: -310, y: -70, scale: 0.5, duration: 1.25, ease: "swift" }, 5.5);
  sfx("whoosh", 5.5, { dur: 1.2, gain: 0.22, from: 600, to: 2400 });
  tl.to(word1, { yPercent: 0, rotation: 0, duration: 1.3, stagger: 0.05 }, 5.95);
  sfx("shimmer", 5.95, { gain: 0.35 });
  tl.to("#tag1 span", { autoAlpha: 1, y: 0, filter: "blur(0px)", duration: 1.3 }, 6.7);

  // match cut: the pin lifts off, the camera falls into the note
  const ps = 19 / 168;
  const pinTx = M.mbPin.cx - 960;
  const pinTy = M.mbPin.top + 9.5 - 540 + 43 * ps;
  tl.to(pin1, { y: -150, duration: 0.5, ease: "power2.out" }, 8.15);
  sfx("tick", 8.15, { gain: 0.35, freq: 2600 });
  tl.to(pin1, { x: pinTx, duration: 1.1, ease: "power2.inOut" }, 8.6);
  tl.to(pin1, { y: pinTy, duration: 1.1, ease: "power3.inOut" }, 8.6);
  tl.to(pin1, { scale: ps, duration: 1.1, ease: "power3.inOut" }, 8.6);
  tl.set("#s1cam", { transformOrigin: "650.5px 474.5px" }, 8.35);
  tl.to("#s1cam", { scale: 18, duration: 1.05, ease: "expo.in" }, 8.4);
  tl.to("#s1cam", { x: 960 - 650.5, y: 540 - 474.5, duration: 1.05, ease: "power2.inOut" }, 8.4);
  tl.to("#s1cam", { filter: "blur(10px)", duration: 0.4, ease: "power2.in" }, 9.05);
  sfx("zoom", 8.4, { dur: 1.05 });

  // S3 — panels on the desktop
  MUSIC.groove = 9.4;
  tl.set("#s3", { autoAlpha: 1 }, 9.38);
  tl.to("#s3cam", { autoAlpha: 1, duration: 0.45, ease: "power2.out" }, 9.38);
  tl.to("#s3cam", { scale: 1, filter: "blur(0px) brightness(1)", duration: 1.7 }, 9.38);
  tl.set("#s1", { autoAlpha: 0 }, 9.9);
  tl.to("#mb", { y: 0, duration: 0.9 }, 9.4);
  tl.set(pin1, { autoAlpha: 0 }, 9.72);
  tl.set("#mbPin", { autoAlpha: 1 }, 9.7);
  tl.to("#mbPin", { scale: 1, duration: 0.7, ease: "back.out(3)" }, 9.7);
  sfx("ping", 9.72, { note: "A6", gain: 0.22 });
  tl.to(["#pA", "#pB", "#pC"], { y: 0, rotationX: 0, autoAlpha: 1, filter: "blur(0px)", duration: 1.5, stagger: 0.13 }, 9.55);
  [0, 1, 2].forEach((i) => sfx("pop", 9.7 + i * 0.13, { gain: 0.22, freq: 520 + i * 90 }));
  tl.to(lines("#cap3"), { yPercent: 0, duration: 1.2, stagger: 0.08 }, 10.3);

  tl.to(cursor, { autoAlpha: 1, duration: 0.3, ease: "power1.out" }, 10.7);
  tl.to(cursor, { x: M.cb2.cx - 4, y: M.cb2.cy - 3, duration: 0.95, ease: "power3.inOut" }, 10.7);
  tl.to(cursor, { scale: 0.85, duration: 0.08, yoyo: true, repeat: 1, ease: "power1.inOut" }, 11.68);
  sfx("click", 11.68);
  tl.to("#cb2", { backgroundColor: "#b5b5bb", borderColor: "#b5b5bb", duration: 0.25, ease: "power2.out" }, 11.74);
  tl.to("#ck2", { scale: 1, duration: 0.5, ease: "back.out(3)" }, 11.76);
  sfx("ping", 11.78, { note: "E6", gain: 0.2 });
  tl.to("#tx2", { color: "#b0b0b5", duration: 0.3, ease: "power1.out" }, 11.78);

  const grabX = M.pChd.left + 170, grabY = M.pChd.cy;
  tl.to(cursor, { x: grabX - 4, y: grabY - 3, duration: 0.85, ease: "power3.inOut" }, 12.1);
  tl.to(cursor, { scale: 0.88, duration: 0.1, ease: "power1.out" }, 12.98);
  sfx("click", 12.98, { gain: 0.7 });
  tl.to("#pC", { scale: 1.025, boxShadow: "0 0 0 1px rgba(0,0,0,.07), 0 60px 110px rgba(30,40,60,.3)", duration: 0.35, ease: "power2.out" }, 13.0);
  tl.to(cursor, { x: `+=${-110}`, y: `+=${70}`, duration: 0.85, ease: "power2.inOut" }, 13.08);
  tl.to("#pC", { x: -110, y: 70, duration: 0.85, ease: "power2.inOut" }, 13.08);
  tl.to("#pC", { keyframes: { rotation: [0, -2.4, 0] }, duration: 0.95, ease: "sine.inOut" }, 13.08);
  sfx("swish", 13.1, { gain: 0.12, pan: -0.3 });
  tl.to(cursor, { scale: 1, duration: 0.12, ease: "power1.out" }, 13.95);
  sfx("click", 13.95, { gain: 0.5 });
  tl.to("#pC", { scale: 1, boxShadow: "0 0 0 1px rgba(0,0,0,.07), 0 24px 60px rgba(30,40,60,.16)", duration: 0.5, ease: "power2.out" }, 13.95);
  tl.to(cursor, { autoAlpha: 0, duration: 0.4, ease: "power1.in" }, 14.5);
  tl.to(["#aw2", "#aw1"], { y: 0, duration: 1.5, stagger: 0.16 }, 13.4);
  sfx("whoosh", 13.4, { dur: 1.0, gain: 0.22, from: 300, to: 1200 });

  // rack focus into Quick Capture
  tl.to(lines("#cap3"), { yPercent: -112, duration: 0.6, stagger: 0.04, ease: "power3.in" }, 15.0);
  tl.to("#s3cam", { filter: "blur(18px) brightness(0.93)", scale: 1.05, duration: 1.0, ease: "power2.inOut" }, 15.2);
  sfx("whoosh", 15.15, { dur: 0.9, gain: 0.2, from: 2200, to: 400 });

  // S4 — ⌥⌘J
  MUSIC.qc = 15.4;
  tl.set("#s4", { autoAlpha: 1 }, 15.3);
  tl.to(kbds, { y: 0, autoAlpha: 1, scale: 1, duration: 0.9, stagger: 0.07 }, 15.45);
  const pressed = "0 0 0 1px rgba(0,0,0,.1), 0 1px 0 #c8c8ce, 0 12px 26px rgba(20,24,32,.2)";
  kbds.forEach((k, i) => {
    tl.to(k, { y: 6, boxShadow: pressed, duration: 0.1, ease: "power2.out" }, 16.0 + i * 0.11);
    sfx("key", 16.0 + i * 0.11, { gain: 0.9, seed: i });
  });
  tl.to(kbds, { y: 0, boxShadow: kbdShadow, duration: 0.3, ease: "power2.out" }, 16.55);
  const kTx = M.k4slot.left + (436 * 0.42) / 2 - M.keys.cx;
  const kTy = M.k4slot.cy - M.keys.cy;
  tl.to("#keys4", { x: kTx, y: kTy, scale: 0.42, duration: 1.0, ease: "swift" }, 16.75);
  tl.to(lines("#cap4"), { yPercent: 0, duration: 1.2, stagger: 0.08 }, 16.8);
  tl.to("#qc", { autoAlpha: 1, scale: 1, y: 0, filter: "blur(0px)", duration: 1.1 }, 16.85);
  sfx("bloom", 16.85, { gain: 0.35 });
  blink("#qcCaret", 17.0, 17.5);
  type(qcChars, 17.5, 13, 0.55);
  blink("#qcCaret", 18.65, 20.1);
  tl.to("#qcKind", { autoAlpha: 1, x: 0, duration: 0.8 }, 18.75);
  tl.to(["#opt1", "#opt2", "#opt3"], { autoAlpha: 1, x: 0, duration: 0.8, stagger: 0.08 }, 18.85);
  tl.to("#qcHl", { autoAlpha: 1, scaleX: 1, duration: 0.5 }, 19.25);
  sfx("tick", 19.25, { gain: 0.3 });
  tl.to("#opt1i", { color: "#0a84ff", duration: 0.3, ease: "power1.out" }, 19.25);
  tl.to("#qcOk", { scale: 1, duration: 0.5, ease: "back.out(3)" }, 19.4);
  tl.to("#qcHl", { keyframes: { scale: [1, 0.97, 1] }, duration: 0.3, ease: "power1.inOut" }, 19.95);
  sfx("key", 19.95, { gain: 0.7, seed: 5 });

  // the note becomes a chip and travels into the snippet library
  tl.set(chip, { autoAlpha: 1 }, 20.15);
  tl.set(["#qcType", "#qcCaret"], { autoAlpha: 0 }, 20.15);
  tl.to(chip, { scale: 1.06, y: -14, duration: 0.45, ease: "power2.out" }, 20.15);
  sfx("pop", 20.15, { gain: 0.3, freq: 700 });
  tl.to("#qc", { scale: 0.94, autoAlpha: 0, filter: "blur(8px)", duration: 0.6, ease: "power3.in" }, 20.35);
  tl.to(lines("#cap4"), { yPercent: -112, duration: 0.5, stagger: 0.04, ease: "power3.in" }, 20.25);
  tl.to("#keys4", { autoAlpha: 0, duration: 0.4, ease: "power1.in" }, 20.3);

  // S5 — six tools
  MUSIC.tools = 20.4;
  tl.set("#s5", { autoAlpha: 1 }, 20.4);
  tl.to("#s5", { clipPath: `circle(2100px at ${revealAt})`, duration: 1.3, ease: "power4.inOut" }, 20.4);
  sfx("swell", 20.4, { dur: 1.2, gain: 0.35 });
  tl.set(["#s3", "#s4"], { autoAlpha: 0 }, 21.8);
  tl.to(lines("#head5"), { yPercent: 0, duration: 1.3, stagger: 0.1 }, 20.95);
  tl.to(tiles, { autoAlpha: 1, y: 0, rotationX: 0, duration: 1.3, stagger: { each: 0.07, grid: [2, 3], from: "start" } }, 21.0);
  tiles.forEach((_, i) => sfx("tick", 21.05 + i * 0.07, { gain: 0.1, freq: 1800 + i * 160 }));
  tl.to("#s5cam", { scale: 1.025, duration: 3.8, ease: "none" }, 21.2);

  const cdx = M.snip.cx - M.chip.cx, cdy = M.snip.cy - M.chip.cy + 30;
  tl.to(chip, { x: cdx, duration: 1.2, ease: "power2.inOut" }, 20.65);
  tl.to(chip, { y: cdy, duration: 1.2, ease: "back.in(1.6)" }, 20.65);
  sfx("whoosh", 20.7, { dur: 1.1, gain: 0.18, from: 900, to: 2600 });
  tl.to(chip, { scale: 0.3, autoAlpha: 0, duration: 0.35, ease: "power2.in" }, 21.55);
  tl.to("#tFlash", { opacity: 1, duration: 0.15, ease: "power1.out" }, 21.85);
  tl.to("#tFlash", { opacity: 0, duration: 1.0, ease: "power2.out" }, 22.0);
  tl.to("#tSnipIc", { keyframes: { scale: [1, 1.2, 1] }, duration: 0.55, ease: "power2.out" }, 21.85);
  sfx("ping", 21.85, { note: "D6", gain: 0.35 });

  // Capture → Store → Find → Act (shifted behind the reel below)
  const DRAW = 25.9, DRAW_D = 2.4;
  tl.to(flowPath, { strokeDashoffset: 0, duration: DRAW_D, ease: "none" }, DRAW);
  FLOW_X.forEach((x, i) => {
    const t = DRAW + ((x - 140) / 1640) * DRAW_D;
    tl.to(flowNodes[i], { scale: 1, duration: 0.6, ease: "back.out(3)" }, t);
    tl.to(flowWords[i], { yPercent: 0, duration: 1.1 }, t - 0.05);
    sfx("ping", t, { note: ["D5", "F#5", "A5", "D6"][i], gain: 0.4 });
  });
  const dim = [0, 1, 3];
  tl.to([...dim.map((i) => flowWords[i]), ...dim.map((i) => flowNodes[i])], { opacity: 0.2, duration: 0.6, ease: "power2.out" }, 28.4);
  tl.to(flowWords[2], { color: "#c65d3b", scale: 1.06, duration: 0.6, ease: "power2.out" }, 28.4);
  sfx("shimmer", 28.4, { gain: 0.3 });

  // the pin's stem sweeps the next scene in
  MUSIC.wipe = 28.95;
  tl.set("#s6", { autoAlpha: 1 }, 28.95);
  tl.to("#s6", { clipPath: wipePoly(2160), duration: 1.1, ease: "power3.inOut" }, 28.95);
  tl.to("#wipebar", { x: 2040, duration: 1.1, ease: "power3.inOut" }, 28.95);
  sfx("wipe", 28.95, { dur: 1.1 });
  tl.set("#s5", { autoAlpha: 0 }, 30.2);

  // S6 — global search
  tl.to("#sw", { y: 0, scale: 1, duration: 1.4 }, 29.3);
  tl.to(lines("#cap6"), { yPercent: 0, duration: 1.2, stagger: 0.08 }, 29.7);
  tl.to($$("#k6 .kc"), { autoAlpha: 1, y: 0, duration: 0.7, stagger: 0.06 }, 30.1);
  blink("#swCaret", 29.6, 30.75);
  tl.set("#swPh", { autoAlpha: 0 }, 30.75);
  type(swChars, 30.75, 4, 0.6);
  blink("#swCaret", 31.15, 34.2);

  const nonRows = rowEls.filter((r) => r.dataset.slot === "-1");
  const hitRows = rowEls.filter((r) => r.dataset.slot !== "-1");
  tl.to(nonRows, { autoAlpha: 0, x: -24, duration: 0.4, stagger: 0.03, ease: "power2.in" }, 31.3);
  sfx("whoosh", 31.3, { dur: 0.6, gain: 0.12, from: 3200, to: 1200 });
  hitRows.forEach((r, k) => {
    const i = rowEls.indexOf(r);
    tl.to(r, { y: (Number(r.dataset.slot) - i) * 80, duration: 0.7, ease: "swift" }, 31.5 + k * 0.04);
  });
  tl.to($$(".hl", swList), { backgroundColor: "rgba(198,93,59,.18)", color: "#b0482a", duration: 0.4, ease: "power1.out" }, 31.75);
  tl.to("#lb1", { autoAlpha: 0, y: -8, duration: 0.3, ease: "power2.in" }, 31.3);
  tl.to("#lb2", { autoAlpha: 1, y: 0, duration: 0.5 }, 31.45);
  tl.to("#swSel", { autoAlpha: 1, duration: 0.3, ease: "power1.out" }, 31.95);
  [80, 160, 240].forEach((y, i) => {
    tl.to("#swSel", { y, duration: 0.3, ease: "power3.out" }, 32.5 + i * 0.45);
    sfx("tick", 32.5 + i * 0.45, { gain: 0.28, freq: 2200 + i * 200 });
  });
  tl.to("#ftSrc", { backgroundColor: "rgba(198,93,59,.16)", color: "#b0482a", duration: 0.3, ease: "power1.out" }, 33.9);
  tl.to("#ftSrc kbd", { keyframes: { scale: [1, 0.86, 1] }, duration: 0.3, ease: "power1.inOut" }, 33.95);
  sfx("key", 33.95, { gain: 0.8, seed: 7 });

  tl.to("#sw", { x: -160, scale: 0.9, autoAlpha: 0, filter: "blur(6px)", duration: 0.75, ease: "power3.in" }, 34.3);
  sfx("whoosh", 34.3, { dur: 0.8, gain: 0.2, from: 2000, to: 600, pan: -0.5 });
  tl.to("#fs", { autoAlpha: 1, x: 0, duration: 1.2 }, 34.75);
  sfx("bloom", 34.75, { gain: 0.3 });
  [35.4, 36.2].forEach((t) => {
    tl.to("#fsRing", { opacity: 1, duration: 0.2, ease: "power1.out" }, t);
    tl.to("#fsRing", { opacity: 0, duration: 0.6, ease: "power2.out" }, t + 0.25);
    sfx("ping", t, { note: "A5", gain: 0.18 });
  });

  // S7 — pull back: everything lives on this one machine
  MUSIC.privacy = 37.0;
  tl.to("#cap6", { autoAlpha: 0, y: -20, duration: 0.6, ease: "power3.in" }, 36.9);
  tl.set("#s7bg", { opacity: 1 }, 37.0);
  tl.to("#s6cam", { scale: 0.38, y: -110, borderRadius: 80, duration: 1.5, ease: "swift" }, 37.0);
  sfx("whoosh", 37.0, { dur: 1.5, gain: 0.35, from: 1600, to: 180 });
  tl.to(lp, { strokeDashoffset: 0, duration: 1.2, stagger: 0.2, ease: "power2.inOut" }, 37.9);
  tl.to(lines("#privH"), { yPercent: 0, duration: 1.3 }, 38.8);
  tl.to("#cloud", { autoAlpha: 1, y: 0, duration: 0.9 }, 39.6);
  tl.to("#segA", { clipPath: "inset(0% 0% 0% 0%)", duration: 0.45, ease: "power1.in" }, 40.0);
  tl.to("#segB", { clipPath: "inset(0% 0% 0% 0%)", duration: 0.45, ease: "power1.out" }, 40.45);
  sfx("data", 40.0, { dur: 0.9 });
  tl.to("#segA", { rotation: angA - 22, y: -8, autoAlpha: 0, duration: 0.9, ease: "power2.out" }, 41.05);
  tl.to("#segB", { rotation: angB + 22, y: 10, autoAlpha: 0, duration: 0.9, ease: "power2.out" }, 41.05);
  tl.fromTo("#snap", { scale: 0.3, opacity: 1 }, { scale: 2.4, opacity: 0, duration: 0.9, immediateRender: false }, 41.05);
  sfx("snap", 41.05);
  tl.to("#cloud", { autoAlpha: 0.22, y: -18, duration: 1.3, ease: "power2.out" }, 41.15);
  tl.to(["#s6cam", "#laptop", "#privH", "#cloud"], { autoAlpha: 0, y: "-=30", filter: "blur(10px)", duration: 0.8, stagger: 0.05, ease: "power3.in" }, 42.6);
  sfx("whoosh", 42.6, { dur: 0.8, gain: 0.2, from: 800, to: 3000 });

  // S8 — outro
  tl.set("#s8", { autoAlpha: 1 }, 43.45);
  tl.set("#s6", { autoAlpha: 0 }, 43.5);
  tl.to(note2, { autoAlpha: 1, y: 0, scale: 1, duration: 1.2 }, 43.45);
  const I2 = 44.35;
  MUSIC.outro = I2;
  tl.to([stem2, dot2], { y: 0, duration: 0.5, ease: "power4.in" }, I2 - 0.5);
  sfx("fall", I2 - 0.5, { dur: 0.5 });
  sfx("boom", I2, { gain: 1.1 });
  tl.fromTo(ring2, { scale: 0.4, autoAlpha: 0.7 }, { scale: 6, autoAlpha: 0, duration: 1.3, immediateRender: false }, I2);
  tl.to(body2, { autoAlpha: 1, scale: 1, duration: 1.3 }, I2);
  tl.to(shadow2, { autoAlpha: 1, x: 0, y: 0 }, I2 + 0.2);
  tl.to("#glow", { autoAlpha: 1, scale: 1, duration: 2, ease: "power2.out" }, I2);
  tl.to("#mark2", { x: -310, y: -100, scale: 0.5, duration: 1.25, ease: "swift" }, 45.1);
  tl.to("#glow", { x: 0, y: 0, duration: 1.25, ease: "swift" }, 45.1);
  sfx("whoosh", 45.1, { dur: 1.2, gain: 0.18, from: 600, to: 2400 });
  tl.to(word2, { yPercent: 0, rotation: 0, duration: 1.3, stagger: 0.05 }, 45.5);
  sfx("shimmer", 45.5, { gain: 0.4 });
  tl.to("#tag2", { autoAlpha: 1, y: 0, filter: "blur(0px)", duration: 1.2 }, 46.1);
  tl.to("#pill", { autoAlpha: 1, y: 0, duration: 1.0 }, 46.8);
  blink("#brewCaret", 46.8, 47.2);
  type(brewChars, 47.2, 34, 0.3);
  blink("#brewCaret", 48.8, 50.6);
  tl.to("#black", { opacity: 1, duration: 1.0, ease: "power2.in" }, 50.6);

  /* ---------- the tool reel, inserted after the tool grid ---------- */
  const RS = 23.4; // reel start: the 剪贴板 tile opens into its window
  const RE = RS + 16; // the cream workflow page has slid fully in
  const SHIFT_FROM = 24.99;
  const R = RE - 25.6;
  tl.shiftChildren(R, false, SHIFT_FROM);
  CUES.forEach((c) => { if (c.t >= SHIFT_FROM) c.t += R; });
  for (const k in MUSIC) if (MUSIC[k] >= SHIFT_FROM) MUSIC[k] += R;
  MUSIC.reel = RS;
  MUSIC.flow = RE;

  // the 剪贴板 tile becomes the 剪贴板 window
  const others = tiles.filter((t) => t.id !== "tClip");
  const k = 1 + (0.025 * (RS - 21.2)) / 3.8; // #s5cam's slow push-in at RS
  tl.set("#morph", {
    opacity: 1, left: 960 + (M.tClip.left - 960) * k, top: 540 + (M.tClip.top - 540) * k,
    width: M.tClip.width * k, height: M.tClip.height * k,
  }, RS);
  tl.set("#tClip", { autoAlpha: 0 }, RS);
  tl.to("#morph", { left: M.rwClip.left, top: M.rwClip.top, width: M.rwClip.width, height: M.rwClip.height, borderRadius: 24, backgroundColor: "#ffffff", duration: 0.85, ease: "power3.inOut" }, RS);
  tl.to([...others, ...lines("#head5")], { autoAlpha: 0, scale: 0.96, duration: 0.3, stagger: 0.015, ease: "power2.in" }, RS);
  sfx("whoosh", RS, { dur: 0.85, gain: 0.25, from: 500, to: 2600 });
  tl.set("#s5r", { autoAlpha: 1 }, RS + 0.35);
  tl.fromTo("#s5r", { opacity: 0 }, { opacity: 1, duration: 0.45, ease: "power1.out", immediateRender: false }, RS + 0.35);
  tl.to("#morph", { opacity: 0, duration: 0.3, ease: "power1.out" }, RS + 0.85);
  sfx("bloom", RS + 0.8, { gain: 0.25 });

  const caps = $$(".rc");
  const stations = [
    { at: RS, capIn: RS + 0.6 },
    { at: RS + 4, capIn: RS + 3.85 },
    { at: RS + 8, capIn: RS + 7.85 },
    { at: RS + 12, capIn: RS + 11.85 },
  ];
  stations.forEach((s, i) => {
    tl.to(lines(caps[i]), { yPercent: 0, duration: 1.1, stagger: 0.07 }, s.capIn);
    tl.to(lines(caps[i]), { yPercent: -112, duration: 0.45, stagger: 0.04, ease: "power3.in" }, s.at + 2.65);
    const pan = s.at + 3.1;
    tl.to("#track", { x: -1920 * (i + 1), duration: 0.9, ease: "expo.inOut" }, pan);
    tl.to("#track", { keyframes: { filter: ["blur(0px)", "blur(10px)", "blur(0px)"] }, duration: 0.9, ease: "none" }, pan);
    tl.to("#rWall", { x: -70 * (i + 1), duration: 0.9, ease: "expo.inOut" }, pan);
    sfx("pan", pan, { dur: 0.9 });
  });

  // 剪贴板 — a new copy arrives on top
  const c0 = RS;
  tl.to(".clipOld", { y: 84, duration: 0.6, ease: "swift" }, c0 + 1.3);
  tl.to("#clipNew", { autoAlpha: 1, y: 0, duration: 0.7 }, c0 + 1.4);
  sfx("pop", c0 + 1.4, { gain: 0.3, freq: 640 });
  tl.to("#clipSel", { autoAlpha: 1, duration: 0.25, ease: "power1.out" }, c0 + 1.8);
  sfx("tick", c0 + 1.8, { gain: 0.25 });
  tl.to("#clipKey", { backgroundColor: "rgba(198,93,59,.16)", color: "#b0482a", duration: 0.25, ease: "power1.out" }, c0 + 2.3);
  sfx("key", c0 + 2.3, { gain: 0.7, seed: 2 });
  tl.to("#clipToast", { autoAlpha: 1, y: 0, duration: 0.5 }, c0 + 2.35);
  sfx("ping", c0 + 2.35, { note: "B5", gain: 0.22 });

  // 文件架 — a PDF is dropped onto the shelf
  const f0 = RS + 4;
  const dx = M.fileIcon.cx - M.ddoc.cx, dy = M.fileIcon.cy - M.ddoc.cy;
  tl.to("#ddoc", { x: dx, duration: 0.9, ease: "power3.out" }, f0 + 0.3);
  tl.to("#ddoc", { y: dy, duration: 0.9, ease: "power2.in" }, f0 + 0.3);
  tl.to("#ddoc", { rotation: 0, scale: M.fileIcon.height / M.ddoc.height, duration: 0.9, ease: "power2.inOut" }, f0 + 0.3);
  sfx("whoosh", f0 + 0.3, { dur: 0.9, gain: 0.2, from: 1800, to: 500, pan: -0.4 });
  tl.to(".fileOld", { y: 84, duration: 0.5, ease: "swift" }, f0 + 0.85);
  tl.set("#ddoc", { autoAlpha: 0 }, f0 + 1.2);
  tl.to("#fileNew", { autoAlpha: 1, scale: 1, duration: 0.5 }, f0 + 1.18);
  sfx("drop", f0 + 1.2);
  tl.to("#fileSel", { autoAlpha: 1, duration: 0.25, ease: "power1.out" }, f0 + 1.6);
  sfx("tick", f0 + 1.6, { gain: 0.25 });
  tl.to("#fileKey", { backgroundColor: "rgba(198,93,59,.16)", color: "#b0482a", duration: 0.25, ease: "power1.out" }, f0 + 2.1);
  sfx("key", f0 + 2.1, { gain: 0.7, seed: 3 });

  // 片段库 — the note captured earlier is already here; pick another, copy it
  const s0 = RS + 8;
  tl.to("#snipSel", { autoAlpha: 1, duration: 0.25, ease: "power1.out" }, s0 + 0.3);
  sfx("tick", s0 + 0.3, { gain: 0.25 });
  [84, 168].forEach((y, i) => {
    tl.to("#snipSel", { y, duration: 0.28, ease: "power3.out" }, s0 + 0.9 + i * 0.35);
    sfx("tick", s0 + 0.9 + i * 0.35, { gain: 0.25, freq: 2300 + i * 200 });
  });
  tl.to("#snipKey", { backgroundColor: "rgba(198,93,59,.16)", color: "#b0482a", duration: 0.25, ease: "power1.out" }, s0 + 1.8);
  sfx("key", s0 + 1.8, { gain: 0.7, seed: 4 });
  tl.to("#snipToast", { autoAlpha: 1, y: 0, duration: 0.5 }, s0 + 1.85);
  sfx("ping", s0 + 1.85, { note: "B5", gain: 0.22 });

  // 链接库 — open a saved page
  const l0 = RS + 12;
  tl.to("#linkSel", { autoAlpha: 1, duration: 0.25, ease: "power1.out" }, l0 + 0.3);
  sfx("tick", l0 + 0.3, { gain: 0.25 });
  tl.to("#linkKey", { backgroundColor: "rgba(198,93,59,.16)", color: "#b0482a", duration: 0.25, ease: "power1.out" }, l0 + 1.2);
  sfx("key", l0 + 1.2, { gain: 0.7, seed: 6 });
  tl.to("#linkToast", { autoAlpha: 1, y: 0, duration: 0.5 }, l0 + 1.25);
  sfx("ping", l0 + 1.25, { note: "D6", gain: 0.22 });

  // the cream workflow page arrives as the next stop on the same pan
  tl.set(lines("#head5"), { autoAlpha: 0 }, RS + 1);
  tl.set(tiles, { autoAlpha: 0 }, RS + 1);
  tl.set("#s5", { x: 1920, zIndex: 6 }, RE - 0.95);
  tl.to("#s5", { x: 0, duration: 0.9, ease: "expo.inOut" }, RE - 0.9);
  tl.set("#s5r", { autoAlpha: 0 }, RE + 0.05);

  MUSIC.end = tl.duration();
  tl.to("#grain", { backgroundPosition: "61300px 40900px", duration: tl.duration(), ease: `steps(${Math.round(tl.duration() * 12)})` }, 0);

  tl.progress(1, true).progress(0, true);
  return { tl }; // a timeline is thenable, so it can't be the resolved value itself
}

build().then(({ tl }) => {
  CUES.sort((a, b) => a.t - b.t);
  window.__film = { duration: tl.duration(), seek: (t) => { tl.totalTime(t, false); }, cues: CUES, music: MUSIC };
  if (RENDER) {
    $("#hud").remove();
    window.__ready = true;
    return;
  }
  const start = Number(params.get("t") || 0);
  tl.totalTime(start);
  if (params.has("still")) return;
  tl.play();
  const bar = $("#hudBar");
  gsap.ticker.add(() => { bar.style.width = `${(tl.totalTime() / tl.duration()) * 100}%`; });
  addEventListener("keydown", (e) => {
    if (e.code === "Space") tl.paused(!tl.paused());
    if (e.code === "ArrowRight") tl.totalTime(Math.min(tl.duration(), tl.totalTime() + 2));
    if (e.code === "ArrowLeft") tl.totalTime(Math.max(0, tl.totalTime() - 2));
    if (e.code === "KeyR") tl.restart();
  });
}).catch((e) => console.error(e.stack || e));
