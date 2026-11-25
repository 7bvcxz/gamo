// Copied from momonium/tests/e2e/lib/audio_tap.mjs (Step 65) so this game needs nothing from another's.
// Step 65: what the page really sends to the speakers. Installed before the
// game loads, it routes every audio node bound for a context's destination
// through one tap, and a meter on the audio thread (an AudioWorklet) keeps the
// loudest moment since it was last asked: RMS over a sliding 23 ms window,
// and the peak. On the audio thread, so a busy page (a panel opening) cannot
// make it miss a short click. A test measures the signal itself -- not a log
// that says play() ran, which is all the old checks saw while the published
// game was silent.
export const AUDIO_TAP = () => {
  // Step 43: also a stereo meter (left and right apart: panning), counts of the buffers and
  // sources the page makes (decoded samples must not grow with time), and a recorder.
  window.__audio = { contexts: [], taps: [], meters: [], stereo: [], buffers: 0, copies: 0, copy_bytes: 0, sources: 0, recorders: [] };
  const METER = `
    class Meter extends AudioWorkletProcessor {
      constructor() {
        super();
        this.n = 1024; this.ring = new Float32Array(this.n); this.i = 0; this.sum = 0; this.rms = 0; this.peak = 0;
        this.port.onmessage = (e) => {
          if (e.data === 'read') this.port.postMessage({ rms: this.rms, peak: this.peak });
          if (e.data === 'reset') { this.rms = 0; this.peak = 0; }
        };
      }
      process(inputs) {
        const ch = inputs[0] && inputs[0][0];
        if (ch) for (let k = 0; k < ch.length; k++) {
          const v = ch[k]; const sq = v * v;
          this.sum += sq - this.ring[this.i]; this.ring[this.i] = sq; this.i = (this.i + 1) % this.n;
          const r = Math.sqrt(Math.max(this.sum, 0) / this.n); if (r > this.rms) this.rms = r;
          const a = Math.abs(v); if (a > this.peak) this.peak = a;
        }
        return true;
      }
    }
    registerProcessor('pop-meter', Meter);
    class Stereo extends AudioWorkletProcessor {
      constructor() {
        super();
        this.n = 1024; this.l = new Float32Array(this.n); this.r = new Float32Array(this.n); this.i = 0;
        this.sl = 0; this.sr = 0; this.ml = 0; this.mr = 0; this.el = 0; this.er = 0; this.f = 0;
        this.port.onmessage = (e) => {
          if (e.data === 'read') this.port.postMessage({ left: this.ml, right: this.mr, energy_left: this.el, energy_right: this.er, frames: this.f });
          if (e.data === 'reset') { this.ml = 0; this.mr = 0; this.el = 0; this.er = 0; this.f = 0; }
        };
      }
      process(inputs) {
        const a = inputs[0] && inputs[0][0]; const b = inputs[0] && (inputs[0][1] || inputs[0][0]);
        if (a) for (let k = 0; k < a.length; k++) {
          const ql = a[k] * a[k], qr = b[k] * b[k];
          this.sl += ql - this.l[this.i]; this.l[this.i] = ql; this.sr += qr - this.r[this.i]; this.r[this.i] = qr;
          this.i = (this.i + 1) % this.n;
          this.el += ql; this.er += qr; this.f += 1;
          const rl = Math.sqrt(Math.max(this.sl, 0) / this.n), rr = Math.sqrt(Math.max(this.sr, 0) / this.n);
          if (rl > this.ml) this.ml = rl; if (rr > this.mr) this.mr = rr;
        }
        return true;
      }
    }
    registerProcessor('pop-stereo', Stereo);`;
  const proto = (window.BaseAudioContext || window.AudioContext).prototype;
  const cb = proto.createBuffer, cs = proto.createBufferSource;
  // Godot 4.7's web samples copy their buffer for every play (Sample.getAudioBuffer ->
  // _duplicateAudioBuffer): those copies are counted apart from the samples themselves.
  proto.createBuffer = function (...a) {
    if (String(new Error().stack).includes('_duplicateAudioBuffer')) {
      window.__audio.copies += 1;
      window.__audio.copy_bytes += Number(a[0]) * Number(a[1]) * 4;   // channels x frames x float32
    }
    else window.__audio.buffers += 1;
    return cb.apply(this, a);
  };
  proto.createBufferSource = function (...a) { window.__audio.sources += 1; return cs.apply(this, a); };
  const Orig = window.AudioContext || window.webkitAudioContext;
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...rest) {
    if (dest instanceof AudioDestinationNode) {
      const ctx = dest.context;
      if (!ctx.__tap) {
        ctx.__tap = ctx.createGain();
        connect.call(ctx.__tap, dest);
        window.__audio.taps.push(ctx.__tap);
        const url = URL.createObjectURL(new Blob([METER], { type: 'application/javascript' }));
        ctx.audioWorklet.addModule(url).then(() => {
          const m = new AudioWorkletNode(ctx, 'pop-meter', { numberOfOutputs: 1, channelCount: 1, channelCountMode: 'explicit' });
          const sink = ctx.createGain();
          sink.gain.value = 0;
          connect.call(ctx.__tap, m);
          connect.call(m, sink);
          connect.call(sink, dest);
          window.__audio.meters.push(m);
          const st = new AudioWorkletNode(ctx, 'pop-stereo', { numberOfOutputs: 1, channelCount: 2, channelCountMode: 'explicit' });
          connect.call(ctx.__tap, st);
          connect.call(st, sink);
          window.__audio.stereo.push(st);
          try {
            const md = ctx.createMediaStreamDestination();
            connect.call(ctx.__tap, md);
            window.__audio.recorders.push(md);
          } catch (e) { /* no recorder: the meters still work */ }
        });
      }
      return connect.call(this, ctx.__tap, ...rest);
    }
    return connect.call(this, dest, ...rest);
  };
  window.AudioContext = function (...a) {
    const c = new Orig(...a);
    window.__audio.contexts.push(c);
    return c;
  };
  window.AudioContext.prototype = Orig.prototype;
};

// Start listening now: the meters are reset -- and the reset has reached the
// audio thread -- before this returns; the returned function waits `ms` more
// and gives the loudest moment since: RMS (23 ms window) and peak. Start it
// BEFORE the action: a sound shorter than a late reset (the 0.14 s Momo
// chirp under a busy machine) was otherwise measured as silence.
export async function listen(page) {
  await page.waitForFunction(() => window.__audio.meters.length > 0, null, { timeout: 10_000 });
  await page.evaluate(() => Promise.all(window.__audio.meters.map((m) => new Promise((done) => {
    m.port.onmessage = (e) => done(e.data);
    m.port.postMessage('reset');
    m.port.postMessage('read');
  }))));
  return async (ms) => {
    await page.waitForTimeout(ms);
    return page.evaluate(() => Promise.all(window.__audio.meters.map((m) => new Promise((done) => {
      m.port.onmessage = (e) => done(e.data);
      m.port.postMessage('read');
    }))).then((all) => all.reduce((a, b) => ({ rms: Math.max(a.rms, b.rms), peak: Math.max(a.peak, b.peak) }), { rms: 0, peak: 0 })));
  };
}

// The loudest moment over the next `ms` (nothing started in between).
export async function loudness(page, ms) {
  return (await listen(page))(ms);
}

export const states = (page) => page.evaluate(() => window.__audio.contexts.map((c) => c.state));

// Step 43: left and right apart (RMS max over 23 ms windows, and the energy summed) since `listenStereo`.
export async function listenStereo(page) {
  await page.waitForFunction(() => window.__audio.stereo.length > 0, null, { timeout: 10_000 });
  const ask = (msg) => page.evaluate((m) => Promise.all(window.__audio.stereo.map((n) => new Promise((done) => {
    n.port.onmessage = (e) => done(e.data);
    if (m === 'reset') n.port.postMessage('reset');
    n.port.postMessage('read');
  }))).then((all) => all.reduce((a, b) => ({ left: Math.max(a.left, b.left), right: Math.max(a.right, b.right), energy_left: a.energy_left + b.energy_left, energy_right: a.energy_right + b.energy_right, frames: a.frames + b.frames }),
    { left: 0, right: 0, energy_left: 0, energy_right: 0, frames: 0 })).then((r) => ({ ...r, mean_rms: Math.sqrt((r.energy_left + r.energy_right) / 2 / Math.max(1, r.frames)) })), msg);
  await ask('reset');
  return async (ms) => { await page.waitForTimeout(ms); return ask('read'); };
}

// Buffers the page has made so far: `buffers` the samples registered (a stream copied every frame
// -- the 0.12.0 leak -- shows here as a count that keeps growing), `copies` the engine's per-play
// copies of them, `sources` the buffer sources (one per play).
export const counts = (page) => page.evaluate(() => ({ buffers: window.__audio.buffers, copies: window.__audio.copies, copy_mb: window.__audio.copy_bytes / 1048576, sources: window.__audio.sources }));

// Records what the page sends to the speakers, from `startRecord` until `stopRecord`, which
// answers the file's bytes (webm/opus). The page keeps playing in between.
export async function startRecord(page) {
  await page.waitForFunction(() => window.__audio.recorders.length > 0, null, { timeout: 10_000 });
  return page.evaluate(() => {
    if (typeof MediaRecorder === 'undefined') return false;
    const rec = new MediaRecorder(window.__audio.recorders[0].stream, { mimeType: 'audio/webm;codecs=opus', audioBitsPerSecond: 96000 });
    window.__rec = { rec, parts: [] };
    rec.ondataavailable = (e) => window.__rec.parts.push(e.data);
    rec.start(500);
    return true;
  });
}

export async function stopRecord(page) {
  const b64 = await page.evaluate(async () => {
    const r = window.__rec;
    if (!r) return '';
    const done = new Promise((ok) => { r.rec.onstop = ok; });
    r.rec.stop();
    await done;
    const buf = new Uint8Array(await new Blob(r.parts, { type: 'audio/webm' }).arrayBuffer());
    let s = '';
    for (let i = 0; i < buf.length; i += 0x8000) s += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
    window.__rec = null;
    return btoa(s);
  });
  return Buffer.from(b64, 'base64');
}
