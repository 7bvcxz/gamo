// Step 65: what the page really sends to the speakers. Installed before the
// game loads, it routes every audio node bound for a context's destination
// through one tap, and a meter on the audio thread (an AudioWorklet) keeps the
// loudest moment since it was last asked: RMS over a sliding 23 ms window,
// and the peak. On the audio thread, so a busy page (a panel opening) cannot
// make it miss a short click. A test measures the signal itself -- not a log
// that says play() ran, which is all the old checks saw while the published
// game was silent.
export const AUDIO_TAP = () => {
  window.__audio = { contexts: [], taps: [], meters: [] };
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
    registerProcessor('momo-meter', Meter);`;
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
          const m = new AudioWorkletNode(ctx, 'momo-meter', { numberOfOutputs: 1, channelCount: 1, channelCountMode: 'explicit' });
          const sink = ctx.createGain();
          sink.gain.value = 0;
          connect.call(ctx.__tap, m);
          connect.call(m, sink);
          connect.call(sink, dest);
          window.__audio.meters.push(m);
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
