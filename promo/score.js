// Offline score + sound design. Everything is synthesized, so the result is identical on every render.
//   window.renderScore(cues, music, duration) → base64 of 16-bit interleaved stereo PCM at 48 kHz
(() => {
  const SR = 48000;
  const BEAT = 0.5;
  const BAR = BEAT * 4;
  const NOTE = { C: -9, D: -7, E: -5, F: -4, G: -2, A: 0, B: 2 };
  const hz = (n) => {
    const m = /^([A-G])(#|b)?(-?\d)$/.exec(n);
    const semi = NOTE[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0) + (Number(m[3]) - 4) * 12;
    return 440 * 2 ** (semi / 12);
  };
  const CHORDS = [
    { root: "D2", pad: ["D3", "A3", "D4", "F#4"], arp: ["D5", "A4", "F#5", "A4", "E5", "A4", "D5", "A5"] },
    { root: "B1", pad: ["B2", "F#3", "D4", "F#4"], arp: ["B4", "F#4", "D5", "F#4", "C#5", "F#4", "B4", "F#5"] },
    { root: "G1", pad: ["G2", "D3", "B3", "D4"], arp: ["G4", "D4", "B4", "D4", "A4", "D4", "B4", "D5"] },
    { root: "A1", pad: ["A2", "E3", "C#4", "E4"], arp: ["A4", "E4", "C#5", "E4", "B4", "E4", "C#5", "E5"] },
  ];

  function rng(seed) {
    let a = seed >>> 0;
    return () => {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  window.renderScore = async (cues, music, duration) => {
    const len = Math.ceil((duration + 0.5) * SR);
    const ctx = new OfflineAudioContext(2, len, SR);
    const rand = rng(7);

    const noise = ctx.createBuffer(2, SR * 3, SR);
    for (let c = 0; c < 2; c++) {
      const d = noise.getChannelData(c);
      for (let i = 0; i < d.length; i++) d[i] = rand() * 2 - 1;
    }
    const impulse = (secs, decay) => {
      const b = ctx.createBuffer(2, Math.floor(SR * secs), SR);
      for (let c = 0; c < 2; c++) {
        const d = b.getChannelData(c);
        for (let i = 0; i < d.length; i++) d[i] = (rand() * 2 - 1) * (1 - i / d.length) ** decay;
      }
      return b;
    };

    /* ---------- buses ---------- */
    const master = ctx.createDynamicsCompressor();
    master.threshold.value = -14;
    master.ratio.value = 3;
    master.attack.value = 0.01;
    master.release.value = 0.25;
    const fadeOut = ctx.createGain();
    master.connect(fadeOut).connect(ctx.destination);
    fadeOut.gain.setValueAtTime(1, duration - 1.6);
    fadeOut.gain.linearRampToValueAtTime(0, duration);

    const musicTone = ctx.createBiquadFilter();
    musicTone.type = "lowpass";
    musicTone.frequency.value = 18000;
    musicTone.Q.value = 0.5;
    const musicBus = ctx.createGain();
    musicTone.connect(musicBus).connect(master);

    const duck = ctx.createGain(); // pad/sub pump against the kick
    duck.connect(musicTone);
    const sfxBus = ctx.createGain();
    sfxBus.gain.value = 2.0;
    sfxBus.connect(master);

    const ir = impulse(3.2, 2.6);
    const makeVerb = (dest) => {
      const v = ctx.createConvolver();
      v.buffer = ir;
      const g = ctx.createGain();
      g.gain.value = 0.55;
      v.connect(g).connect(dest);
      return v;
    };
    const verbM = makeVerb(musicTone); // music reverb follows the music level and filter
    const verbS = makeVerb(master);

    const send = (node, amount, verb) => {
      const g = ctx.createGain();
      g.gain.value = amount;
      node.connect(g).connect(verb);
    };
    const out = (node, bus, rev = 0, pan = 0) => {
      let n = node;
      if (pan) {
        const p = ctx.createStereoPanner();
        p.pan.value = pan;
        n.connect(p);
        n = p;
      }
      n.connect(bus);
      if (rev) send(n, rev, bus === sfxBus || bus === master ? verbS : verbM);
      return n;
    };
    const env = (g, t, a, peak, d, curve = "exp") => {
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(peak, t + a);
      if (curve === "exp") g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
      else g.gain.linearRampToValueAtTime(0.0001, t + a + d);
    };
    const osc = (type, f, t, stop) => {
      const o = ctx.createOscillator();
      o.type = type;
      o.frequency.setValueAtTime(f, t);
      o.start(t);
      o.stop(stop);
      return o;
    };
    const noiseSrc = (t, dur) => {
      const s = ctx.createBufferSource();
      s.buffer = noise;
      s.loop = true;
      s.start(t, rand() * 2);
      s.stop(t + dur + 0.05);
      return s;
    };
    const filt = (type, f, q = 0.7) => {
      const b = ctx.createBiquadFilter();
      b.type = type;
      b.frequency.value = f;
      b.Q.value = q;
      return b;
    };

    /* ---------- instruments ---------- */
    function pad(t, dur, notes, gain, { attack = 0.9, release = 1.4, cutoff = 1500 } = {}) {
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(gain, t + attack);
      g.gain.setValueAtTime(gain, t + dur);
      g.gain.linearRampToValueAtTime(0.0001, t + dur + release);
      const lp = filt("lowpass", cutoff, 0.6);
      lp.connect(g);
      notes.forEach((n, i) => {
        [-7, 7].forEach((cents) => {
          const o = osc("sawtooth", hz(n), t, t + dur + release + 0.1);
          o.detune.value = cents + i * 1.5;
          const p = ctx.createStereoPanner();
          p.pan.value = cents > 0 ? 0.45 : -0.45;
          const lv = ctx.createGain();
          lv.gain.value = 0.11 / notes.length;
          o.connect(lv).connect(p).connect(lp);
        });
      });
      out(g, duck, 0.45);
    }

    function pluck(t, f, gain, pan = 0, rev = 0.3) {
      const car = osc("sine", f, t, t + 1.4);
      const mod = osc("sine", f * 2, t, t + 1.4);
      const mi = ctx.createGain();
      mi.gain.setValueAtTime(f * 1.6, t);
      mi.gain.exponentialRampToValueAtTime(f * 0.05, t + 0.35);
      mod.connect(mi).connect(car.frequency);
      const g = ctx.createGain();
      env(g, t, 0.004, gain, 1.1);
      car.connect(g);
      out(g, musicTone, rev, pan);
    }

    function bell(t, f, gain, pan = 0, decay = 2.6, bus = musicTone) {
      const car = osc("sine", f, t, t + decay + 0.2);
      const mod = osc("sine", f * 3.5, t, t + decay + 0.2);
      const mi = ctx.createGain();
      mi.gain.setValueAtTime(f * 2.2, t);
      mi.gain.exponentialRampToValueAtTime(f * 0.02, t + decay * 0.6);
      mod.connect(mi).connect(car.frequency);
      const g = ctx.createGain();
      env(g, t, 0.003, gain, decay);
      car.connect(g);
      out(g, bus, 0.6, pan);
    }

    function sub(t, dur, f, gain) {
      const o = osc("sine", f, t, t + dur + 0.3);
      const o2 = osc("triangle", f * 2, t, t + dur + 0.3);
      const lv2 = ctx.createGain();
      lv2.gain.value = 0.18;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.linearRampToValueAtTime(gain, t + 0.04);
      g.gain.setValueAtTime(gain, t + dur - 0.05);
      g.gain.linearRampToValueAtTime(0.0001, t + dur + 0.2);
      o.connect(g);
      o2.connect(lv2).connect(g);
      out(g, duck);
    }

    function kick(t, gain) {
      const o = osc("sine", 150, t, t + 0.5);
      o.frequency.exponentialRampToValueAtTime(44, t + 0.13);
      const g = ctx.createGain();
      env(g, t, 0.002, gain, 0.42);
      o.connect(g);
      out(g, musicBus);
      const c = noiseSrc(t, 0.02);
      const cg = ctx.createGain();
      env(cg, t, 0.001, gain * 0.15, 0.015);
      c.connect(filt("highpass", 3000)).connect(cg);
      out(cg, musicBus);
      duck.gain.setValueAtTime(0.45, t);
      duck.gain.linearRampToValueAtTime(1, t + 0.32);
    }

    function hat(t, gain, open = false) {
      const s = noiseSrc(t, open ? 0.25 : 0.06);
      const g = ctx.createGain();
      env(g, t, 0.001, gain, open ? 0.22 : 0.045);
      s.connect(filt("highpass", 8000)).connect(g);
      out(g, musicTone, 0.08, 0.25);
    }

    function clap(t, gain) {
      const s = noiseSrc(t, 0.2);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      [0, 0.011, 0.022].forEach((d) => {
        g.gain.setValueAtTime(gain, t + d);
        g.gain.exponentialRampToValueAtTime(gain * 0.2, t + d + 0.009);
      });
      g.gain.setValueAtTime(gain * 0.8, t + 0.03);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.18);
      s.connect(filt("bandpass", 1600, 1.4)).connect(g);
      out(g, musicTone, 0.35, -0.1);
    }

    /* ---------- sound effects ---------- */
    const FX = {
      whoosh({ t, dur = 0.9, gain = 0.25, from = 500, to = 2500, pan = 0 }) {
        const s = noiseSrc(t, dur);
        const bp = filt("bandpass", from, 1.1);
        bp.frequency.exponentialRampToValueAtTime(to, t + dur);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(gain, t + dur * 0.62);
        g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        const p = ctx.createStereoPanner();
        p.pan.setValueAtTime(pan ? -pan * 0.4 : 0, t);
        p.pan.linearRampToValueAtTime(pan, t + dur);
        s.connect(bp).connect(g).connect(p);
        out(p, sfxBus, 0.25);
      },
      swish({ t, gain = 0.2, pan = 0 }) {
        FX.whoosh({ t, dur: 0.38, gain, from: 1400, to: 4200, pan });
      },
      pan({ t, dur = 0.9 }) {
        const s = noiseSrc(t, dur);
        const bp = filt("bandpass", 700, 0.9);
        bp.frequency.setValueAtTime(700, t);
        bp.frequency.exponentialRampToValueAtTime(2600, t + dur * 0.5);
        bp.frequency.exponentialRampToValueAtTime(900, t + dur);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(0.45, t + dur * 0.5);
        g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        const p = ctx.createStereoPanner();
        p.pan.setValueAtTime(0.8, t);
        p.pan.linearRampToValueAtTime(-0.8, t + dur);
        s.connect(bp).connect(g).connect(p);
        out(p, sfxBus, 0.2);
      },
      wipe({ t, dur = 1.1 }) {
        const s = noiseSrc(t, dur);
        const bp = filt("bandpass", 300, 0.8);
        bp.frequency.exponentialRampToValueAtTime(3200, t + dur * 0.55);
        bp.frequency.exponentialRampToValueAtTime(1200, t + dur);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(0.42, t + dur * 0.5);
        g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        const p = ctx.createStereoPanner();
        p.pan.setValueAtTime(-0.9, t);
        p.pan.linearRampToValueAtTime(0.9, t + dur);
        s.connect(bp).connect(g).connect(p);
        out(p, sfxBus, 0.3);
        FX.boom({ t: t + dur * 0.45, gain: 0.35, low: true });
      },
      fall({ t, dur = 0.5, gain = 0.4 }) {
        const s = noiseSrc(t, dur);
        const bp = filt("bandpass", 500, 1.6);
        bp.frequency.exponentialRampToValueAtTime(5000, t + dur);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(gain, t + dur - 0.01);
        g.gain.linearRampToValueAtTime(0.0001, t + dur);
        s.connect(bp).connect(g);
        out(g, sfxBus, 0.15);
        const o = osc("sine", 2600, t, t + dur);
        o.frequency.exponentialRampToValueAtTime(700, t + dur);
        const og = ctx.createGain();
        og.gain.setValueAtTime(0.0001, t);
        og.gain.exponentialRampToValueAtTime(gain * 0.12, t + dur - 0.01);
        og.gain.linearRampToValueAtTime(0.0001, t + dur);
        o.connect(og);
        out(og, sfxBus, 0.2);
      },
      boom({ t, gain = 1, low = false }) {
        const o = osc("sine", low ? 110 : 120, t, t + 3);
        o.frequency.exponentialRampToValueAtTime(30, t + (low ? 0.4 : 0.9));
        const g = ctx.createGain();
        env(g, t, 0.003, gain * 0.26, low ? 0.8 : 2.6);
        o.connect(g);
        out(g, sfxBus);
        const s = noiseSrc(t, 1.6);
        const lp = filt("lowpass", 3200, 0.5);
        lp.frequency.exponentialRampToValueAtTime(120, t + 1.2);
        const ng = ctx.createGain();
        env(ng, t, 0.002, gain * 0.1, low ? 0.5 : 1.4);
        s.connect(lp).connect(ng);
        out(ng, sfxBus, low ? 0.2 : 0.7);
      },
      zoom({ t, dur = 1.05 }) {
        const s = noiseSrc(t, dur);
        const bp = filt("bandpass", 250, 1.3);
        bp.frequency.exponentialRampToValueAtTime(7000, t + dur);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(0.42, t + dur - 0.02);
        g.gain.linearRampToValueAtTime(0.0001, t + dur);
        s.connect(bp).connect(g);
        out(g, sfxBus, 0.3);
        const o = osc("sawtooth", 110, t, t + dur);
        o.frequency.exponentialRampToValueAtTime(880, t + dur);
        const og = ctx.createGain();
        og.gain.setValueAtTime(0.0001, t);
        og.gain.exponentialRampToValueAtTime(0.05, t + dur - 0.02);
        og.gain.linearRampToValueAtTime(0.0001, t + dur);
        o.connect(filt("lowpass", 2400)).connect(og);
        out(og, sfxBus, 0.3);
      },
      swell({ t, dur = 1.2, gain = 0.35 }) {
        const s = noiseSrc(t, dur);
        const hp = filt("highpass", 2500);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(gain, t + dur * 0.45);
        g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
        s.connect(hp).connect(g);
        out(g, sfxBus, 0.5);
        ["D4", "A4", "D5"].forEach((n, i) => {
          const o = osc("triangle", hz(n), t, t + dur + 1);
          const og = ctx.createGain();
          og.gain.setValueAtTime(0.0001, t);
          og.gain.linearRampToValueAtTime(gain * 0.12, t + dur * 0.5);
          og.gain.exponentialRampToValueAtTime(0.0001, t + dur + 0.9);
          o.connect(og);
          out(og, sfxBus, 0.6, (i - 1) * 0.5);
        });
      },
      bloom({ t, gain = 0.3 }) {
        ["D5", "A5", "F#6"].forEach((n, i) => {
          const o = osc("sine", hz(n), t, t + 2.2);
          const g = ctx.createGain();
          g.gain.setValueAtTime(0.0001, t);
          g.gain.linearRampToValueAtTime(gain * 0.13, t + 0.25 + i * 0.05);
          g.gain.exponentialRampToValueAtTime(0.0001, t + 2);
          o.connect(g);
          out(g, sfxBus, 0.8, (i - 1) * 0.6);
        });
        const s = noiseSrc(t, 0.7);
        const g = ctx.createGain();
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(gain * 0.25, t + 0.25);
        g.gain.exponentialRampToValueAtTime(0.0001, t + 0.7);
        s.connect(filt("bandpass", 5000, 0.8)).connect(g);
        out(g, sfxBus, 0.5);
      },
      shimmer({ t, gain = 0.35 }) {
        ["D6", "F#6", "A6", "D7", "E7"].forEach((n, i) => bell(t + i * 0.055, hz(n), gain * 0.09, (i - 2) * 0.35, 2.2, sfxBus));
      },
      ping({ t, note = "A5", gain = 0.25 }) {
        bell(t, hz(note), gain * 0.35, 0.1, 1.6, sfxBus);
        const o = osc("sine", hz(note) * 2, t, t + 0.4);
        const g = ctx.createGain();
        env(g, t, 0.002, gain * 0.08, 0.3);
        o.connect(g);
        out(g, sfxBus, 0.4);
      },
      pop({ t, gain = 0.25, freq = 600 }) {
        const o = osc("sine", freq * 1.7, t, t + 0.2);
        o.frequency.exponentialRampToValueAtTime(freq, t + 0.05);
        const g = ctx.createGain();
        env(g, t, 0.002, gain, 0.14);
        o.connect(g);
        out(g, sfxBus, 0.25);
      },
      click({ t, gain = 0.6 }) {
        const s = noiseSrc(t, 0.03);
        const g = ctx.createGain();
        env(g, t, 0.0005, gain * 0.5, 0.018);
        s.connect(filt("bandpass", 3800, 2)).connect(g);
        out(g, sfxBus, 0.05);
        const o = osc("sine", 1700, t, t + 0.05);
        const og = ctx.createGain();
        env(og, t, 0.0005, gain * 0.12, 0.025);
        o.connect(og);
        out(og, sfxBus);
      },
      tock({ t, gain = 0.4 }) {
        const o = osc("sine", 880, t, t + 0.12);
        o.frequency.exponentialRampToValueAtTime(620, t + 0.05);
        const g = ctx.createGain();
        env(g, t, 0.001, gain * 0.4, 0.08);
        o.connect(g);
        out(g, sfxBus, 0.15);
      },
      key({ t, gain = 0.7, seed = 0 }) {
        const r = rng(seed + 11);
        const s = noiseSrc(t, 0.06);
        const g = ctx.createGain();
        env(g, t, 0.001, gain * 0.32, 0.045);
        s.connect(filt("bandpass", 1500 + r() * 700, 1.6)).connect(g);
        out(g, sfxBus, 0.08, (r() - 0.5) * 0.3);
        const o = osc("sine", 170 + r() * 40, t, t + 0.08);
        const og = ctx.createGain();
        env(og, t, 0.001, gain * 0.3, 0.06);
        o.connect(og);
        out(og, sfxBus);
      },
      type({ t, gain = 0.5, seed = 0 }) {
        const r = rng(seed + 101);
        const s = noiseSrc(t, 0.035);
        const g = ctx.createGain();
        env(g, t, 0.0005, gain * 0.42 * (0.7 + r() * 0.5), 0.025);
        s.connect(filt("bandpass", 2600 + r() * 1800, 1.8)).connect(g);
        out(g, sfxBus, 0.05, (r() - 0.5) * 0.4);
      },
      tick({ t, gain = 0.25, freq = 2000 }) {
        const o = osc("sine", freq, t, t + 0.06);
        const g = ctx.createGain();
        env(g, t, 0.0005, gain * 0.6, 0.035);
        o.connect(g);
        out(g, sfxBus, 0.15);
      },
      drop({ t, gain = 0.5 }) {
        const o = osc("sine", 240, t, t + 0.3);
        o.frequency.exponentialRampToValueAtTime(90, t + 0.12);
        const g = ctx.createGain();
        env(g, t, 0.002, gain * 0.7, 0.22);
        o.connect(g);
        out(g, sfxBus, 0.15);
        FX.click({ t, gain: 0.4 });
      },
      snap({ t, gain = 0.5 }) {
        const s = noiseSrc(t, 0.15);
        const g = ctx.createGain();
        env(g, t, 0.0008, gain * 0.6, 0.1);
        s.connect(filt("bandpass", 2600, 1.2)).connect(g);
        out(g, sfxBus, 0.5);
        [1320, 1980].forEach((f) => {
          const o = osc("triangle", f, t, t + 0.4);
          o.frequency.exponentialRampToValueAtTime(f * 0.7, t + 0.3);
          const og = ctx.createGain();
          env(og, t, 0.001, gain * 0.07, 0.3);
          o.connect(og);
          out(og, sfxBus, 0.6);
        });
      },
      data({ t, dur = 0.9, gain = 0.3 }) {
        const r = rng(42);
        for (let x = 0; x < dur; x += 0.045) {
          const f = 1400 + Math.floor(r() * 6) * 220;
          const o = osc("square", f, t + x, t + x + 0.03);
          const g = ctx.createGain();
          env(g, t + x, 0.001, gain * 0.12 * (0.5 + r() * 0.5), 0.025);
          o.connect(filt("lowpass", 4000)).connect(g);
          out(g, sfxBus, 0.25, (r() - 0.5) * 0.6);
        }
      },
    };

    /* ---------- the score ---------- */
    const m = music;
    const end = duration;

    // the music level is the arc of the film: hushed, then building section by section
    const level = [
      [0, 0.9], [m.impact, 0.42], [m.groove, 0.2], [m.qc, 0.24], [m.tools, 0.28],
      [m.reel, 0.31], [m.privacy, 0.4], [m.outro, 0.45],
    ];
    level.forEach(([t, v], i) => {
      if (i === 0) musicBus.gain.setValueAtTime(v, 0);
      else {
        musicBus.gain.setValueAtTime(level[i - 1][1], t - 0.02);
        musicBus.gain.linearRampToValueAtTime(v, t);
      }
    });

    // cold open: a low drone that tightens until the pin lands
    pad(0.2, m.impact - 0.35 - 0.2, ["D2", "A2", "D3"], 0.42, { attack: 3.2, release: 0.12, cutoff: 600 });
    for (let x = 1.2; x < m.impact - 0.6; x += 0.5) pluck(x, hz("A5"), 0.018 + 0.03 * (x / m.impact), 0.3, 0.5);

    // after the impact: open, warm, bells over the name
    pad(m.impact, m.groove - 1.0 - m.impact, ["D3", "A3", "D4", "F#4", "A4"], 0.55, { attack: 0.08, release: 0.5, cutoff: 2200 });
    sub(m.impact, 3.6, hz("D1") * 2, 0.32);
    ["D5", "A5", "F#5", "E5", "D5", "A4", "F#5", "A5"].forEach((n, i) => bell(5.6 + i * 0.4, hz(n), 0.05, (i % 2 ? 0.3 : -0.3), 2.4));

    // groove: D – Bm – G – A, layers build with each section
    const grooveEnd = m.privacy;
    for (let b = 0; m.groove + b * BAR < grooveEnd; b++) {
      const t0 = m.groove + b * BAR;
      const ch = CHORDS[b % 4];
      const barLen = Math.min(BAR, grooveEnd - t0);
      pad(t0, barLen - 0.05, ch.pad, t0 >= m.tools ? 0.5 : 0.42, { attack: 0.06, release: 0.35, cutoff: t0 >= m.reel ? 2600 : 1800 });
      sub(t0, barLen - 0.06, hz(ch.root) * 2, 0.3);
      for (let s = 0; s < 8; s++) {
        const t = t0 + s * BEAT / 2;
        if (t >= grooveEnd - 0.05) break;
        const lift = t >= m.reel ? 1.25 : 1;
        pluck(t, hz(ch.arp[s]), (s % 2 ? 0.045 : 0.065) * lift, s % 2 ? 0.35 : -0.35);
      }
      for (let q = 0; q < 4; q++) {
        const t = t0 + q * BEAT;
        if (t >= grooveEnd - 0.05) break;
        if (q % 2 === 0) kick(t, 0.6);
        else if (t >= m.qc) kick(t, 0.4);
        if (t >= m.qc) hat(t + BEAT / 2, 0.09, t >= m.reel && q === 3);
        if (t >= m.qc + 2) { hat(t + BEAT / 4, 0.035); hat(t + (3 * BEAT) / 4, 0.035); }
        if (t >= m.tools && q % 2 === 1) clap(t, 0.32);
      }
    }

    // privacy: drums fall away, the music goes under water
    const pv = m.privacy;
    musicTone.frequency.setValueAtTime(18000, pv);
    musicTone.frequency.exponentialRampToValueAtTime(700, pv + 1.6);
    musicTone.frequency.setValueAtTime(700, m.outro - 1.2);
    musicTone.frequency.exponentialRampToValueAtTime(18000, m.outro);
    const calm = ["D3", "A3", "D4", "F#4"];
    pad(pv, 3.8, calm, 0.55, { attack: 0.1, release: 0.6, cutoff: 1800 });
    pad(pv + 4, m.outro - 0.75 - (pv + 4), ["B2", "F#3", "D4", "E4"], 0.5, { attack: 0.6, release: 0.12, cutoff: 1500 });
    sub(pv, m.outro - 0.75 - pv, hz("D2"), 0.25);
    for (let x = pv + 0.5; x < m.outro - 1.2; x += 1) bell(x, hz(["A4", "D5", "F#5", "E5"][Math.round(x - pv) % 4]), 0.05, 0, 2);

    // outro: one big chord, the bells, ring out
    pad(m.outro, end - m.outro - 1.2, ["D2", "A2", "D3", "A3", "D4", "F#4", "A4"], 0.7, { attack: 0.05, release: 1.6, cutoff: 3200 });
    sub(m.outro, end - m.outro - 1.5, hz("D1") * 2, 0.4);
    kick(m.outro, 0.7);
    ["D5", "F#5", "A5", "D6", "A5", "F#5", "E5", "D5"].forEach((n, i) => bell(m.outro + 1.2 + i * 0.5, hz(n), 0.05, (i % 2 ? 0.35 : -0.35), 3));

    /* ---------- cues ---------- */
    for (const c of cues) if (FX[c.name]) FX[c.name](c);

    const buf = await ctx.startRendering();
    const L = buf.getChannelData(0), Rch = buf.getChannelData(1);
    let peak = 0;
    for (let i = 0; i < L.length; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(Rch[i]));
    const k = peak > 0.89 ? 0.89 / peak : 1;
    const pcm = new Int16Array(L.length * 2);
    for (let i = 0; i < L.length; i++) {
      pcm[2 * i] = Math.max(-1, Math.min(1, L[i] * k)) * 32767;
      pcm[2 * i + 1] = Math.max(-1, Math.min(1, Rch[i] * k)) * 32767;
    }
    const bytes = new Uint8Array(pcm.buffer);
    let bin = "";
    for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return { sampleRate: SR, channels: 2, peak, data: btoa(bin) };
  };
})();
