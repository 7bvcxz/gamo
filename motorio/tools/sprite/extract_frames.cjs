// Pulls frames out of a video, without ffmpeg.
//
//   npm install --prefix /tmp/pw playwright
//   NODE_PATH=/tmp/pw/node_modules node tools/sprite/extract_frames.cjs <video> <out_dir> [--fps 12]
//
// ffmpeg is not available in this environment and cannot be installed (no sudo).
// A headless browser already is, and it has a complete video decoder: load the
// file into a <video>, seek to an exact timestamp, draw that frame into a canvas
// and read the pixels back. Deterministic, lossless at the frame level, and it
// decodes anything Chromium decodes -- which is everything a generator will hand
// back.
//
// The seek has to be awaited properly. Setting currentTime and screenshotting on
// the next tick gives you whatever frame happened to be presented, which for a
// dense extraction means duplicates and gaps in no particular order. Every seek
// here waits for the 'seeked' event and then one animation frame, so the frame
// on the canvas is the frame that was asked for.

const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 ? process.argv[index + 1] : fallback;
}

async function main() {
  const source = process.argv[2];
  const outDir = process.argv[3];
  if (!source || !outDir) {
    console.error('usage: extract_frames.cjs <video> <out_dir> [--fps 12] [--start 0] [--end 0]');
    process.exit(2);
  }
  const fps = Number(arg('fps', 12));
  const start = Number(arg('start', 0));
  const endArg = Number(arg('end', 0));

  fs.mkdirSync(outDir, { recursive: true });

  // Served over HTTP rather than opened as a file:// URL. Drawing a video into a
  // canvas taints it unless the two share an origin, and a tainted canvas
  // refuses toDataURL -- which is the whole mechanism here. A data: URI would
  // also be same-origin but generated clips run to megabytes and base64 is a
  // third larger again, so this streams the bytes instead.
  const body = fs.readFileSync(path.resolve(source));
  const type = source.endsWith('.webm') ? 'video/webm' : 'video/mp4';
  const server = http.createServer((req, res) => {
    // The page itself is served, rather than pushed in with setContent after a
    // navigation to a 404. That was a race -- the navigation and the content
    // injection could land in either order, and when they landed wrong the run
    // died with "execution context was destroyed". One document, one load.
    if (req.url === '/' || req.url === '/index.html') {
      const html = '<body style="margin:0;background:#000">'
        + '<video src="/clip" preload="auto"></video></body>';
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
      return;
    }
    if (req.url !== '/clip') { res.writeHead(404).end(); return; }
    // Range support: Chromium asks for byte ranges when seeking, and a server
    // that answers 200 with the whole body to every range request makes seeks
    // slow and, on longer clips, unreliable.
    const range = req.headers.range;
    if (range) {
      const [startByte, endByte] = range.replace('bytes=', '').split('-');
      const from = Number(startByte);
      const to = endByte ? Number(endByte) : body.length - 1;
      res.writeHead(206, {
        'Content-Type': type,
        'Content-Range': `bytes ${from}-${to}/${body.length}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': to - from + 1,
      });
      res.end(body.subarray(from, to + 1));
      return;
    }
    res.writeHead(200, { 'Content-Type': type, 'Content-Length': body.length,
      'Accept-Ranges': 'bytes' });
    res.end(body);
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  // Not every Playwright install can decode H.264, and the generated clips are
  // all avc1. A build without the codec does not fail -- the <video> simply
  // never reaches loadedmetadata, so this script sat for ten minutes printing
  // nothing before anyone thought to check. SPRITE_CHROME points at a build that
  // has it; the check below turns the hang into a sentence.
  const browser = await chromium.launch(
    process.env.SPRITE_CHROME ? { executablePath: process.env.SPRITE_CHROME } : {});
  const page = await browser.newPage({ viewport: { width: 1280, height: 1280 } });
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'domcontentloaded' });

  const meta = await page.evaluate(async () => {
    const video = document.querySelector('video');
    if (!video) return null;
    if (Number.isNaN(video.duration) || !Number.isFinite(video.duration)) {
      const how = await Promise.race([
        new Promise((r) => video.addEventListener('loadedmetadata', () => r('ok'), { once: true })),
        new Promise((r) => video.addEventListener('error', () => r('error'), { once: true })),
        new Promise((r) => setTimeout(() => r('timeout'), 20000)),
      ]);
      if (how !== 'ok') {
        return { failed: how, codec: video.canPlayType('video/mp4; codecs="avc1.42E01E"') };
      }
    }
    video.pause();
    return { duration: video.duration, width: video.videoWidth, height: video.videoHeight };
  });
  if (meta && meta.failed) {
    console.error(`EXTRACT_FAIL: this browser did not decode the clip (${meta.failed}).` +
      (meta.codec ? '' : ' It has no H.264 decoder -- set SPRITE_CHROME to a Chromium' +
        ' build that does; Playwright ships some with the codec and some without.'));
    await browser.close();
    server.close();
    process.exit(1);
  }
  if (!meta) {
    console.error('EXTRACT: no <video> element -- is this a video file?');
    await browser.close();
    server.close();
    process.exit(1);
  }

  const end = endArg > 0 ? Math.min(endArg, meta.duration) : meta.duration;
  // Half a frame in from each end. The first and last presented frames of a
  // generated clip are routinely the worst ones -- a fade in, a settle -- and
  // they are exactly the frames a loop finder would otherwise anchor on.
  const step = 1 / fps;
  const times = [];
  for (let t = start + step * 0.5; t < end - step * 0.25; t += step) times.push(t);

  const written = [];
  for (let i = 0; i < times.length; i += 1) {
    const dataUrl = await page.evaluate(async (time) => {
      const video = document.querySelector('video');
      await new Promise((resolve) => {
        const done = () => resolve();
        video.addEventListener('seeked', done, { once: true });
        video.currentTime = time;
      });
      // One more frame so the decoded picture is actually presented before it is
      // read back. Without this the canvas can still hold the previous frame.
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
      const canvas = document.createElement('canvas');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      canvas.getContext('2d').drawImage(video, 0, 0);
      return canvas.toDataURL('image/png');
    }, times[i]);

    const name = `f${String(i).padStart(4, '0')}.png`;
    fs.writeFileSync(path.join(outDir, name),
      Buffer.from(dataUrl.split(',')[1], 'base64'));
    written.push(name);
  }

  await browser.close();
  server.close();
  console.log(`EXTRACT: ${meta.width}x${meta.height}, ${meta.duration.toFixed(2)}s -> ${written.length} frames at ${fps}fps`);
}

main().catch((error) => {
  console.error('EXTRACT_FAIL:', error.message);
  process.exit(1);
});
