// Builds a synthetic test clip with a known correct answer.
//
//   NODE_PATH=/tmp/pw/node_modules node tools/sprite/make_test_clip.cjs <frames_dir> <out.webm> [--fps 12] [--seconds 4] [--cycle 4]
//
// The pipeline has to be testable without spending money on a generator, and
// more importantly it has to be testable against a sequence whose right answer
// is already known. This records a handful of PNG frames looping on a flat
// background, at a stated frame rate, for a stated length -- so afterwards we can
// assert that the extractor recovered the frames, that the loop finder found a
// cycle of exactly the length that went in, and that the normaliser put every
// one of them on the same anchor.
//
// It is also how the extractor gets tested at all: ffmpeg is not available here,
// and Chromium's MediaRecorder is the only encoder in the environment. The same
// browser that decodes video for extract_frames.cjs encodes it here, which is a
// little circular but only for the container -- the frames themselves come from
// real PNGs, so a bug in one direction does not hide a bug in the other.
//
// Deliberately imperfect on purpose: the clip is recorded at a wall-clock rate
// that will not divide evenly into the extraction rate, and the background is a
// flat colour rather than transparent. That is what a generated clip looks like,
// and a test that fed the pipeline something cleaner than reality would prove
// nothing about reality.

const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? Number(process.argv[index + 1]) : fallback;
}

async function main() {
  const framesDir = process.argv[2];
  const out = process.argv[3];
  if (!framesDir || !out) {
    console.error('usage: make_test_clip.cjs <frames_dir> <out.webm> [--fps 12] [--seconds 4] [--cycle 4]');
    process.exit(2);
  }
  const fps = arg('fps', 12);
  const seconds = arg('seconds', 4);
  const cycle = arg('cycle', 0);

  const files = fs.readdirSync(framesDir).filter((f) => f.endsWith('.png')).sort();
  if (!files.length) {
    console.error('MAKE_CLIP: no PNG frames in', framesDir);
    process.exit(1);
  }
  const images = files.map((f) =>
    'data:image/png;base64,' + fs.readFileSync(path.join(framesDir, f)).toString('base64'));
  const cycleLength = cycle > 0 ? cycle : images.length;

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 640, height: 640 } });
  await page.goto('about:blank');

  const base64 = await page.evaluate(async ({ images, fps, seconds, cycleLength }) => {
    const loaded = await Promise.all(images.map((src) => new Promise((resolve) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.src = src;
    })));

    const canvas = document.createElement('canvas');
    canvas.width = 512; canvas.height = 512;
    const ctx = canvas.getContext('2d');
    document.body.appendChild(canvas);

    const stream = canvas.captureStream(fps);
    const chunks = [];
    const recorder = new MediaRecorder(stream, { mimeType: 'video/webm' });
    recorder.ondataavailable = (event) => chunks.push(event.data);
    recorder.start();

    const total = Math.round(fps * seconds);
    for (let i = 0; i < total; i += 1) {
      const image = loaded[i % cycleLength % loaded.length];
      // Flat magenta: what a generator is asked for when the frames have to be
      // keyed out afterwards, and a colour that appears nowhere in the art.
      ctx.fillStyle = '#ff00ff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      const scale = Math.min(canvas.width / image.width, canvas.height / image.height) * 0.8;
      const w = image.width * scale;
      const h = image.height * scale;
      ctx.drawImage(image, (canvas.width - w) / 2, canvas.height - h - 40, w, h);
      await new Promise((resolve) => setTimeout(resolve, 1000 / fps));
    }
    await new Promise((resolve) => setTimeout(resolve, 200));

    const blob = await new Promise((resolve) => {
      recorder.onstop = () => resolve(new Blob(chunks, { type: 'video/webm' }));
      recorder.stop();
    });
    const buffer = await blob.arrayBuffer();
    let binary = '';
    const bytes = new Uint8Array(buffer);
    for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
    return btoa(binary);
  }, { images, fps, seconds, cycleLength });

  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  fs.writeFileSync(out, Buffer.from(base64, 'base64'));
  await browser.close();
  const size = fs.statSync(out).size;
  console.log(`MAKE_CLIP: ${files.length} frames, cycle ${cycleLength}, ${seconds}s at ${fps}fps -> ${out} (${size} bytes)`);
}

main().catch((error) => {
  console.error('MAKE_CLIP_FAIL:', error.message);
  process.exit(1);
});
