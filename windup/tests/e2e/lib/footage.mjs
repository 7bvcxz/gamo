// Unedited footage with the game's own sound: Playwright records the page's
// video (no audio), the page records what reaches its speakers (audio_tap.mjs
// adds a MediaRecorder on the tap), and ffmpeg puts the two together, the
// audio offset by the recorder's start against the video's.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const FFMPEG = process.env.WINDUP_FFMPEG || `${process.env.HOME}/.local/bin/ffmpeg`;

/** A context that records video; returns {context, page, startedAt}. */
export async function recordingContext(browser, viewport, dir) {
  fs.mkdirSync(dir, { recursive: true });
  const startedAt = Date.now();
  const context = await browser.newContext({ viewport, recordVideo: { dir, size: viewport } });
  const page = await context.newPage();
  return { context, page, startedAt };
}

/** Stops the page's audio recorder and returns its bytes and start time. */
export async function takeAudio(page) {
  return page.evaluate(async () => {
    const a = window.__audio;
    if (!a || !a.recorder) return { error: (a && a.recError) || 'no recorder' };
    await new Promise((done) => { a.recorder.onstop = done; a.recorder.stop(); });
    const blob = new Blob(a.chunks, { type: 'audio/webm' });
    const buf = new Uint8Array(await blob.arrayBuffer());
    let bin = '';
    for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode.apply(null, buf.subarray(i, i + 0x8000));
    return { b64: btoa(bin), start: a.recStart, bytes: buf.length };
  });
}

/** Closes the context (the video is written then) and muxes video + audio into `out` (mp4). */
export async function finishFootage({ context, page, startedAt }, audio, out) {
  const video = page.video();
  await context.close();
  const videoPath = await video.path();
  const result = { video: videoPath, out, audio_bytes: audio.bytes || 0 };
  if (audio.b64) {
    const audioPath = out.replace(/\.mp4$/, '.audio.webm');
    fs.writeFileSync(audioPath, Buffer.from(audio.b64, 'base64'));
    const offset = Math.max(0, (audio.start - startedAt) / 1000);
    execFileSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-y', '-i', videoPath, '-itsoffset', offset.toFixed(3), '-i', audioPath,
      '-map', '0:v', '-map', '1:a', '-vf', 'scale=960:-2', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '30', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '96k', out]);
    fs.unlinkSync(audioPath);
    result.audio_offset_s = offset;
  } else {
    execFileSync(FFMPEG, ['-hide_banner', '-loglevel', 'error', '-y', '-i', videoPath, '-vf', 'scale=960:-2', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '30', '-pix_fmt', 'yuv420p', out]);
    result.audio_error = audio.error;
  }
  fs.unlinkSync(videoPath);
  return result;
}
