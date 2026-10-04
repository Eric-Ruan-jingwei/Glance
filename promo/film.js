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
  g.dataset.r = r;
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
const flowWords = [], flowZh = [], flowNodes = [];
["Capture", "Store", "Find", "Act"].forEach((w, i) => {
  const x = FLOW_X[i];
  const fw = document.createElement("div");
  fw.className = "fw ln";
  fw.style.left = `${x - 300}px`;
  fw.innerHTML = `<span>${w}</span>`;
  const fz = document.createElement("div");
  fz.className = "fz";
  fz.style.left = `${x - 150}px`;
  fz.textContent = ["记下", "存放", "找回", "行动"][i];
  const nd = document.createElement("i");
  nd.className = "node";
  nd.style.left = `${x}px`;
  flow.append(fw, fz, nd);
  flowWords.push(fw.firstChild);
  flowZh.push(fz);
  flowNodes.push(nd);
});

const ring2 = $("#ring1").cloneNode();
ring2.id = "ring2";
$("#s8").appendChild(ring2);

/* ---------------- build ---------------- */

async function build() {
  await Promise.all([
    document.fonts.load("500 200px NY"),
    document.fonts.load("italic 136px NY"),
    document.fonts.load("20px SFP"),
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
    qc: rect($("#qc")),
    snip: rect($("#tSnip")),
    keys: rect($("#keys4")),
    k4slot: rect($("#k4slot")),
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
  gsap.set("#meta1", { autoAlpha: 0, letterSpacing: "0.7em" });
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
  gsap.set("#sub5", { autoAlpha: 0, y: 20 });
  gsap.set(tiles, { autoAlpha: 0, y: 90, rotationX: -24, transformOrigin: "50% 100%", filter: "blur(0px)" });
  gsap.set(["#flowOver", ...flowZh], { autoAlpha: 0, y: 14 });
  gsap.set(flowNodes, { scale: 0 });

  const T = 57; // half the horizontal travel of the skewed bar between top and bottom
  const wipePoly = (e) => `polygon(-400px 0px, ${e + T}px 0px, ${e - T}px 1080px, -400px 1080px)`;
  gsap.set("#s6", { clipPath: wipePoly(-180), filter: "blur(0px)" });
  gsap.set("#wipebar", { x: -300 });
  gsap.set("#sw", { y: 30, scale: 0.97, filter: "blur(0px)" });
  gsap.set("#fs", { autoAlpha: 0, x: 220 });
  gsap.set($$("#k6 .kc"), { autoAlpha: 0, y: 10 });
  gsap.set(["#cap6b", "#lb2"], { autoAlpha: 0, y: 8 });
  gsap.set("#swSel", { autoAlpha: 0 });
  gsap.set("#s6cam", { filter: "blur(0px)" });
  gsap.set(["#laptop", "#privH", "#privI"], { filter: "blur(0px)" });
  gsap.set($$("#privI span"), { autoAlpha: 0, y: 14 });
  gsap.set("#cloud", { autoAlpha: 0, y: -12 });
  gsap.set("#segA", { clipPath: "inset(0% 100% 0% 0%)" });
  gsap.set("#segB", { clipPath: "inset(0% 0% 0% 100%)" });

  gsap.set(["#glow"], { autoAlpha: 0, scale: 0.6, x: 300, y: 80 });
  gsap.set("#pill", { autoAlpha: 0, y: 24 });
  gsap.set("#foot", { autoAlpha: 0 });

  /* ---------- timeline ---------- */
  const tl = gsap.timeline({ paused: true, defaults: { ease: "expo.out", duration: 1 } });

  const blink = (el, from, to) => {
    const period = 0.53;
    let n = Math.max(1, Math.floor((to - from) / period) - 1);
    if (n % 2 === 0) n -= 1;
    if (n < 1) return;
    tl.to(el, { opacity: 0, duration: period, ease: "steps(1)", repeat: n, yoyo: true }, from);
  };
  const type = (chars, at, cps) => chars.forEach((c, i) => tl.set(c, { display: "inline" }, at + i / cps));

  // S1 — a single note, buried by windows
  tl.to(note1, { autoAlpha: 1, scale: 1, duration: 1.4 }, 0.15);
  tl.to("#s1cam", { scale: 1, duration: 4.4, ease: "sine.out" }, 0);
  tl.to(ghostsIn, { rotationX: 2, rotationY: 4, duration: 4.6, ease: "sine.inOut" }, 0);
  tl.to(ghostEls, { z: 0, y: 0, autoAlpha: 1, duration: 1.3, stagger: 0.19 }, 0.85);
  tl.to(lines("#head1"), { yPercent: 0, duration: 1.2, stagger: 0.12 }, 1.5);
  tl.to(lines("#head1"), { yPercent: -112, duration: 0.6, stagger: 0.06, ease: "power3.in" }, 3.5);
  tl.set("#head1", { autoAlpha: 0 }, 4.2);

  // the pin goes through everything
  const IMPACT = 4.45;
  tl.to(pin1, { y: 0, duration: 0.5, ease: "power4.in" }, IMPACT - 0.5);
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
  tl.to(word1, { yPercent: 0, rotation: 0, duration: 1.3, stagger: 0.05 }, 5.95);
  tl.to("#tag1 span", { autoAlpha: 1, y: 0, filter: "blur(0px)", duration: 1.2, stagger: 0.22 }, 6.6);
  tl.to("#meta1", { autoAlpha: 1, letterSpacing: "0.42em", duration: 1.8 }, 7.1);

  // match cut: the pin lifts off, the camera falls into the note
  const ps = 19 / 168;
  const pinTx = M.mbPin.cx - 960;
  const pinTy = M.mbPin.top + 9.5 - 540 + 43 * ps;
  tl.to(pin1, { y: -150, duration: 0.5, ease: "power2.out" }, 8.15);
  tl.to(pin1, { x: pinTx, duration: 1.1, ease: "power2.inOut" }, 8.6);
  tl.to(pin1, { y: pinTy, duration: 1.1, ease: "power3.inOut" }, 8.6);
  tl.to(pin1, { scale: ps, duration: 1.1, ease: "power3.inOut" }, 8.6);
  tl.set("#s1cam", { transformOrigin: "650.5px 474.5px" }, 8.35);
  tl.to("#s1cam", { scale: 18, duration: 1.05, ease: "expo.in" }, 8.4);
  tl.to("#s1cam", { x: 960 - 650.5, y: 540 - 474.5, duration: 1.05, ease: "power2.inOut" }, 8.4);
  tl.to("#s1cam", { filter: "blur(10px)", duration: 0.4, ease: "power2.in" }, 9.05);

  // S3 — panels on the desktop
  tl.set("#s3", { autoAlpha: 1 }, 9.38);
  tl.to("#s3cam", { autoAlpha: 1, duration: 0.45, ease: "power2.out" }, 9.38);
  tl.to("#s3cam", { scale: 1, filter: "blur(0px) brightness(1)", duration: 1.7 }, 9.38);
  tl.set("#s1", { autoAlpha: 0 }, 9.9);
  tl.to("#mb", { y: 0, duration: 0.9 }, 9.4);
  tl.set(pin1, { autoAlpha: 0 }, 9.72);
  tl.set("#mbPin", { autoAlpha: 1 }, 9.7);
  tl.to("#mbPin", { scale: 1, duration: 0.7, ease: "back.out(3)" }, 9.7);
  tl.to(["#pA", "#pB", "#pC"], { y: 0, rotationX: 0, autoAlpha: 1, filter: "blur(0px)", duration: 1.5, stagger: 0.13 }, 9.55);
  tl.to(lines("#cap3"), { yPercent: 0, duration: 1.2, stagger: 0.08 }, 10.3);

  tl.to(cursor, { autoAlpha: 1, duration: 0.3, ease: "power1.out" }, 10.7);
  tl.to(cursor, { x: M.cb2.cx - 4, y: M.cb2.cy - 3, duration: 0.95, ease: "power3.inOut" }, 10.7);
  tl.to(cursor, { scale: 0.85, duration: 0.08, yoyo: true, repeat: 1, ease: "power1.inOut" }, 11.68);
  tl.to("#cb2", { backgroundColor: "#b5b5bb", borderColor: "#b5b5bb", duration: 0.25, ease: "power2.out" }, 11.74);
  tl.to("#ck2", { scale: 1, duration: 0.5, ease: "back.out(3)" }, 11.76);
  tl.to("#tx2", { color: "#b0b0b5", duration: 0.3, ease: "power1.out" }, 11.78);

  const grabX = M.pChd.left + 170, grabY = M.pChd.cy;
  tl.to(cursor, { x: grabX - 4, y: grabY - 3, duration: 0.85, ease: "power3.inOut" }, 12.1);
  tl.to(cursor, { scale: 0.88, duration: 0.1, ease: "power1.out" }, 12.98);
  tl.to("#pC", { scale: 1.025, boxShadow: "0 0 0 1px rgba(0,0,0,.07), 0 60px 110px rgba(30,40,60,.3)", duration: 0.35, ease: "power2.out" }, 13.0);
  tl.to(cursor, { x: `+=${-110}`, y: `+=${70}`, duration: 0.85, ease: "power2.inOut" }, 13.08);
  tl.to("#pC", { x: -110, y: 70, duration: 0.85, ease: "power2.inOut" }, 13.08);
  tl.to("#pC", { keyframes: { rotation: [0, -2.4, 0] }, duration: 0.95, ease: "sine.inOut" }, 13.08);
  tl.to(cursor, { scale: 1, duration: 0.12, ease: "power1.out" }, 13.95);
  tl.to("#pC", { scale: 1, boxShadow: "0 0 0 1px rgba(0,0,0,.07), 0 24px 60px rgba(30,40,60,.16)", duration: 0.5, ease: "power2.out" }, 13.95);
  tl.to(cursor, { autoAlpha: 0, duration: 0.4, ease: "power1.in" }, 14.5);
  tl.to(["#aw2", "#aw1"], { y: 0, duration: 1.5, stagger: 0.16 }, 13.4);

  // rack focus into Quick Capture
  tl.to(lines("#cap3"), { yPercent: -112, duration: 0.6, stagger: 0.04, ease: "power3.in" }, 15.0);
  tl.to("#s3cam", { filter: "blur(18px) brightness(0.93)", scale: 1.05, duration: 1.0, ease: "power2.inOut" }, 15.2);

  // S4 — ⌥⌘J
  tl.set("#s4", { autoAlpha: 1 }, 15.3);
  tl.to(kbds, { y: 0, autoAlpha: 1, scale: 1, duration: 0.9, stagger: 0.07 }, 15.45);
  const pressed = "0 0 0 1px rgba(0,0,0,.1), 0 1px 0 #c8c8ce, 0 12px 26px rgba(20,24,32,.2)";
  kbds.forEach((k, i) => tl.to(k, { y: 6, boxShadow: pressed, duration: 0.1, ease: "power2.out" }, 16.0 + i * 0.11));
  tl.to(kbds, { y: 0, boxShadow: kbdShadow, duration: 0.3, ease: "power2.out" }, 16.55);
  const kTx = M.k4slot.left + (436 * 0.42) / 2 - M.keys.cx;
  const kTy = M.k4slot.cy - M.keys.cy;
  tl.to("#keys4", { x: kTx, y: kTy, scale: 0.42, duration: 1.0, ease: "swift" }, 16.75);
  tl.to(lines("#cap4"), { yPercent: 0, duration: 1.2, stagger: 0.08 }, 16.9);
  tl.to("#qc", { autoAlpha: 1, scale: 1, y: 0, filter: "blur(0px)", duration: 1.1 }, 16.85);
  blink("#qcCaret", 17.0, 17.5);
  type(qcChars, 17.5, 13);
  blink("#qcCaret", 18.65, 20.1);
  tl.to("#qcKind", { autoAlpha: 1, x: 0, duration: 0.8 }, 18.75);
  tl.to(["#opt1", "#opt2", "#opt3"], { autoAlpha: 1, x: 0, duration: 0.8, stagger: 0.08 }, 18.85);
  tl.to("#qcHl", { autoAlpha: 1, scaleX: 1, duration: 0.5 }, 19.25);
  tl.to("#opt1i", { color: "#0a84ff", duration: 0.3, ease: "power1.out" }, 19.25);
  tl.to("#qcOk", { scale: 1, duration: 0.5, ease: "back.out(3)" }, 19.4);
  tl.to("#qcHl", { keyframes: { scale: [1, 0.97, 1] }, duration: 0.3, ease: "power1.inOut" }, 19.95);

  // the note becomes a chip and travels into the snippet library
  tl.set(chip, { autoAlpha: 1 }, 20.15);
  tl.set(["#qcType", "#qcCaret"], { autoAlpha: 0 }, 20.15);
  tl.to(chip, { scale: 1.06, y: -14, duration: 0.45, ease: "power2.out" }, 20.15);
  tl.to("#qc", { scale: 0.94, autoAlpha: 0, filter: "blur(8px)", duration: 0.6, ease: "power3.in" }, 20.35);
  tl.to(lines("#cap4"), { yPercent: -112, duration: 0.5, stagger: 0.04, ease: "power3.in" }, 20.25);
  tl.to("#keys4", { autoAlpha: 0, duration: 0.4, ease: "power1.in" }, 20.3);

  // S5 — six tools
  tl.set("#s5", { autoAlpha: 1 }, 20.4);
  tl.to("#s5", { clipPath: `circle(2100px at ${revealAt})`, duration: 1.3, ease: "power4.inOut" }, 20.4);
  tl.set(["#s3", "#s4"], { autoAlpha: 0 }, 21.8);
  tl.to(lines("#head5"), { yPercent: 0, duration: 1.3, stagger: 0.1 }, 20.95);
  tl.to("#sub5", { autoAlpha: 1, y: 0, duration: 1.2 }, 21.4);
  tl.to(tiles, { autoAlpha: 1, y: 0, rotationX: 0, duration: 1.3, stagger: { each: 0.07, grid: [2, 3], from: "start" } }, 21.0);
  tl.to("#s5cam", { scale: 1.025, duration: 3.8, ease: "none" }, 21.2);

  const cdx = M.snip.cx - M.chip.cx, cdy = M.snip.cy - M.chip.cy + 30;
  tl.to(chip, { x: cdx, duration: 1.2, ease: "power2.inOut" }, 20.65);
  tl.to(chip, { y: cdy, duration: 1.2, ease: "back.in(1.6)" }, 20.65);
  tl.to(chip, { scale: 0.3, autoAlpha: 0, duration: 0.35, ease: "power2.in" }, 21.55);
  tl.to("#tFlash", { opacity: 1, duration: 0.15, ease: "power1.out" }, 21.85);
  tl.to("#tFlash", { opacity: 0, duration: 1.0, ease: "power2.out" }, 22.0);
  tl.to("#tSnipIc", { keyframes: { scale: [1, 1.2, 1] }, duration: 0.55, ease: "power2.out" }, 21.85);

  // Capture → Store → Find → Act
  tl.to(lines("#head5"), { yPercent: -112, duration: 0.7, stagger: 0.06, ease: "power3.in" }, 25.0);
  tl.to("#sub5", { autoAlpha: 0, y: -20, duration: 0.6, ease: "power3.in" }, 25.05);
  tl.to(tiles, { autoAlpha: 0, y: -50, scale: 0.94, filter: "blur(8px)", duration: 0.7, stagger: { each: 0.04, from: "end" }, ease: "power3.in" }, 25.0);
  tl.to("#flowOver", { autoAlpha: 1, y: 0, duration: 1.2 }, 25.7);
  const DRAW = 25.9, DRAW_D = 2.4;
  tl.to(flowPath, { strokeDashoffset: 0, duration: DRAW_D, ease: "none" }, DRAW);
  FLOW_X.forEach((x, i) => {
    const t = DRAW + ((x - 140) / 1640) * DRAW_D;
    tl.to(flowNodes[i], { scale: 1, duration: 0.6, ease: "back.out(3)" }, t);
    tl.to(flowWords[i], { yPercent: 0, duration: 1.1 }, t - 0.05);
    tl.to(flowZh[i], { autoAlpha: 1, y: 0, duration: 0.9 }, t + 0.1);
  });
  const dim = [0, 1, 3];
  tl.to([...dim.map((i) => flowWords[i]), ...dim.map((i) => flowZh[i]), ...dim.map((i) => flowNodes[i]), "#flowOver"], { opacity: 0.2, duration: 0.6, ease: "power2.out" }, 28.4);
  tl.to(flowWords[2], { color: "#c65d3b", scale: 1.06, duration: 0.6, ease: "power2.out" }, 28.4);

  // the pin's stem sweeps the next scene in
  tl.set("#s6", { autoAlpha: 1 }, 28.95);
  tl.to("#s6", { clipPath: wipePoly(2160), duration: 1.1, ease: "power3.inOut" }, 28.95);
  tl.to("#wipebar", { x: 2040, duration: 1.1, ease: "power3.inOut" }, 28.95);
  tl.set("#s5", { autoAlpha: 0 }, 30.2);

  // S6 — global search
  tl.to("#sw", { y: 0, scale: 1, duration: 1.4 }, 29.3);
  tl.to(lines("#cap6"), { yPercent: 0, duration: 1.2, stagger: 0.08 }, 29.7);
  tl.to($$("#k6 .kc"), { autoAlpha: 1, y: 0, duration: 0.7, stagger: 0.06 }, 30.1);
  blink("#swCaret", 29.6, 30.75);
  tl.set("#swPh", { autoAlpha: 0 }, 30.75);
  type(swChars, 30.75, 4);
  blink("#swCaret", 31.15, 34.2);

  const nonRows = rowEls.filter((r) => r.dataset.slot === "-1");
  const hitRows = rowEls.filter((r) => r.dataset.slot !== "-1");
  tl.to(nonRows, { autoAlpha: 0, x: -24, duration: 0.4, stagger: 0.03, ease: "power2.in" }, 31.3);
  hitRows.forEach((r, k) => {
    const i = rowEls.indexOf(r);
    tl.to(r, { y: (Number(r.dataset.slot) - i) * 80, duration: 0.7, ease: "swift" }, 31.5 + k * 0.04);
  });
  tl.to($$(".hl", swList), { backgroundColor: "rgba(198,93,59,.18)", color: "#b0482a", duration: 0.4, ease: "power1.out" }, 31.75);
  tl.to("#lb1", { autoAlpha: 0, y: -8, duration: 0.3, ease: "power2.in" }, 31.3);
  tl.to("#lb2", { autoAlpha: 1, y: 0, duration: 0.5 }, 31.45);
  tl.to("#swSel", { autoAlpha: 1, duration: 0.3, ease: "power1.out" }, 31.95);
  [80, 160, 240].forEach((y, i) => tl.to("#swSel", { y, duration: 0.3, ease: "power3.out" }, 32.5 + i * 0.45));
  tl.to("#ftSrc", { backgroundColor: "rgba(198,93,59,.16)", color: "#b0482a", duration: 0.3, ease: "power1.out" }, 33.9);
  tl.to("#ftSrc kbd", { keyframes: { scale: [1, 0.86, 1] }, duration: 0.3, ease: "power1.inOut" }, 33.95);

  tl.to("#sw", { x: -160, scale: 0.9, autoAlpha: 0, filter: "blur(6px)", duration: 0.75, ease: "power3.in" }, 34.3);
  tl.to("#fs", { autoAlpha: 1, x: 0, duration: 1.2 }, 34.75);
  tl.to("#cap6b", { autoAlpha: 1, y: 0, duration: 1.0 }, 34.85);
  [35.4, 36.2].forEach((t) => {
    tl.to("#fsRing", { opacity: 1, duration: 0.2, ease: "power1.out" }, t);
    tl.to("#fsRing", { opacity: 0, duration: 0.6, ease: "power2.out" }, t + 0.25);
  });

  // S7 — pull back: everything lives on this one machine
  tl.to("#cap6", { autoAlpha: 0, y: -20, duration: 0.6, ease: "power3.in" }, 36.9);
  tl.set("#s7bg", { opacity: 1 }, 37.0);
  tl.to("#s6cam", { scale: 0.38, y: -110, borderRadius: 80, duration: 1.5, ease: "swift" }, 37.0);
  tl.to(lp, { strokeDashoffset: 0, duration: 1.2, stagger: 0.2, ease: "power2.inOut" }, 37.9);
  tl.to(lines("#privH"), { yPercent: 0, duration: 1.3 }, 38.8);
  tl.to($$("#privI span"), { autoAlpha: 1, y: 0, duration: 0.9, stagger: 0.12 }, 39.3);
  tl.to("#cloud", { autoAlpha: 1, y: 0, duration: 0.9 }, 39.9);
  tl.to("#segA", { clipPath: "inset(0% 0% 0% 0%)", duration: 0.45, ease: "power1.in" }, 40.2);
  tl.to("#segB", { clipPath: "inset(0% 0% 0% 0%)", duration: 0.45, ease: "power1.out" }, 40.65);
  tl.to("#segA", { rotation: angA - 22, y: -8, autoAlpha: 0, duration: 0.9, ease: "power2.out" }, 41.25);
  tl.to("#segB", { rotation: angB + 22, y: 10, autoAlpha: 0, duration: 0.9, ease: "power2.out" }, 41.25);
  tl.fromTo("#snap", { scale: 0.3, opacity: 1 }, { scale: 2.4, opacity: 0, duration: 0.9, immediateRender: false }, 41.25);
  tl.to("#cloud", { autoAlpha: 0.22, y: -18, duration: 1.3, ease: "power2.out" }, 41.35);
  tl.to(["#s6cam", "#laptop", "#privH", "#privI", "#cloud"], { autoAlpha: 0, y: "-=30", filter: "blur(10px)", duration: 0.8, stagger: 0.05, ease: "power3.in" }, 42.6);

  // S8 — outro
  tl.set("#s8", { autoAlpha: 1 }, 43.45);
  tl.set("#s6", { autoAlpha: 0 }, 43.5);
  tl.to(note2, { autoAlpha: 1, y: 0, scale: 1, duration: 1.2 }, 43.45);
  const I2 = 44.35;
  tl.to([stem2, dot2], { y: 0, duration: 0.5, ease: "power4.in" }, I2 - 0.5);
  tl.fromTo(ring2, { scale: 0.4, autoAlpha: 0.7 }, { scale: 6, autoAlpha: 0, duration: 1.3, immediateRender: false }, I2);
  tl.to(body2, { autoAlpha: 1, scale: 1, duration: 1.3 }, I2);
  tl.to(shadow2, { autoAlpha: 1, x: 0, y: 0 }, I2 + 0.2);
  tl.to("#glow", { autoAlpha: 1, scale: 1, duration: 2, ease: "power2.out" }, I2);
  tl.to("#mark2", { x: -310, y: -100, scale: 0.5, duration: 1.25, ease: "swift" }, 45.1);
  tl.to("#glow", { x: 0, y: 0, duration: 1.25, ease: "swift" }, 45.1);
  tl.to(word2, { yPercent: 0, rotation: 0, duration: 1.3, stagger: 0.05 }, 45.5);
  tl.to("#tag2", { autoAlpha: 1, y: 0, filter: "blur(0px)", duration: 1.2 }, 46.1);
  tl.to("#pill", { autoAlpha: 1, y: 0, duration: 1.0 }, 46.6);
  blink("#brewCaret", 46.6, 47.0);
  type(brewChars, 47.0, 34);
  blink("#brewCaret", 48.6, 50.4);
  tl.to("#foot", { autoAlpha: 1, duration: 1.4, ease: "power2.out" }, 48.6);
  tl.to("#black", { opacity: 1, duration: 0.9, ease: "power2.in" }, 50.4);
  tl.to("#grain", { backgroundPosition: "61300px 40900px", duration: tl.duration(), ease: `steps(${Math.round(tl.duration() * 12)})` }, 0);

  tl.progress(1, true).progress(0, true);
  return { tl }; // a timeline is thenable, so it can't be the resolved value itself
}

build().then(({ tl }) => {
  window.__film = { duration: tl.duration(), seek: (t) => { tl.totalTime(t, false); } };
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
