// Step 95: how long from a press to its sound reaching the output, measured
// on the audio thread. Installed before the Lab loads, it routes everything
// bound for a context's destination through one tap with a small worklet
// that reports the audio clock of every onset -- the first sample louder than
// a threshold after at least 20 ms of quiet. Every pointerdown notes the page
// clock and the context's output timestamp (which audio time is leaving the
// speakers at which page time); a press's sound is the first onset after it,
// placed on the page clock through that timestamp. Quiet the music first
// (funlab dev_quiet), or there is no quiet to start from.
// Two ways that measured nothing: arming the meter from the press (the
// message reached the audio thread after the sound had begun), and comparing
// the onset with ctx.currentTime at the press -- the browser renders audio
// ahead in chunks, so currentTime at the press is often already past where
// the sound will start, and every press read 0.1 ms. The momonium game's
// audio_tap.mjs (Step 65) is the same routing with a level meter.
export const ONSET = () => {
  const o = (window.__onset = { ctx: null, node: null, downs: [], onsets: [] });
  const CODE = `
    class Onset extends AudioWorkletProcessor {
      constructor() { super(); this.th = 0.02; this.quiet = 0; }
      process(inputs) {
        const ch = inputs[0] && inputs[0][0];
        if (ch) {
          const need = 0.02 * sampleRate;
          for (let k = 0; k < ch.length; k++) {
            if (Math.abs(ch[k]) > this.th) {
              if (this.quiet >= need) this.port.postMessage(currentTime + k / sampleRate);
              this.quiet = 0;
            } else {
              this.quiet++;
            }
          }
        }
        return true;
      }
    }
    registerProcessor('funlab-onset', Onset);`;
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function (dest, ...rest) {
    if (dest instanceof AudioDestinationNode) {
      const ctx = dest.context;
      if (!ctx.__tap) {
        ctx.__tap = ctx.createGain();
        connect.call(ctx.__tap, dest);
        o.ctx = ctx;
        const url = URL.createObjectURL(new Blob([CODE], { type: 'application/javascript' }));
        ctx.audioWorklet.addModule(url).then(() => {
          const n = new AudioWorkletNode(ctx, 'funlab-onset', { numberOfOutputs: 1, channelCount: 1, channelCountMode: 'explicit' });
          const sink = ctx.createGain();
          sink.gain.value = 0;
          connect.call(ctx.__tap, n);
          connect.call(n, sink);
          connect.call(sink, dest);
          n.port.onmessage = (e) => o.onsets.push(e.data);
          o.node = n;
        });
      }
      return connect.call(this, ctx.__tap, ...rest);
    }
    return connect.call(this, dest, ...rest);
  };
  window.addEventListener('pointerdown', () => {
    if (!o.ctx) return;
    const ts = o.ctx.getOutputTimestamp();
    o.downs.push({ perf: performance.now(), ctx: ts.contextTime, at: ts.performanceTime });
  }, true);
};

// Forget the presses and onsets so far (before a measured series).
export const resetOnsets = (page) => page.evaluate(() => { window.__onset.downs = []; window.__onset.onsets = []; });

// Each press's press-to-output time in ms (null: no sound before the next
// press or within a second).
export function onsetTimes(page) {
  return page.evaluate(() => {
    const o = window.__onset;
    return o.downs.map((d, i) => {
      const next = i + 1 < o.downs.length ? o.downs[i + 1].ctx : d.ctx + 1.0;
      const hit = o.onsets.find((t) => t >= d.ctx && t < next);
      return hit === undefined ? null : d.at + (hit - d.ctx) * 1000 - d.perf;
    });
  });
}
