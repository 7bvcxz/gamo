import React, { useEffect, useRef, useState } from 'react';

// Plays a sprite sheet, at whole-number zoom, with no smoothing.
//
// An animation cannot be judged from a still, which is the whole reason this
// component exists: the failure this pipeline was built to catch -- frames that
// are each fine and do not belong to one cycle -- is invisible until the frames
// are moving. Two versions of this game's character shipped looking correct in a
// screenshot and wobbling in play.
//
// Nearest-neighbour and an integer zoom, both non-negotiable. The sprite is 64
// pixels and the game draws it at 1:1; a preview that resampled it would be
// showing something the player will never see, and smoothing is exactly what
// hides a one-pixel jitter.

export function SpriteAnimation({ sheet, frames, fps, zoom = 4, playing = true }) {
  const canvasRef = useRef(null);
  const [image, setImage] = useState(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    const img = new Image();
    img.onload = () => setImage(img);
    img.onerror = () => setError(true);
    img.src = sheet;
    return () => { img.onload = null; img.onerror = null; };
  }, [sheet]);

  useEffect(() => {
    if (!image || !canvasRef.current) return undefined;
    const cell = Math.round(image.width / frames);
    const canvas = canvasRef.current;
    canvas.width = cell * zoom;
    canvas.height = image.height * zoom;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;

    let frame = 0;
    let raf = 0;
    let last = 0;
    const draw = (time) => {
      // Advance on elapsed time rather than per animation frame: the browser
      // runs at whatever rate the display does, and a sprite cycle played at
      // 60fps instead of 10 is a different animation.
      if (!last || time - last >= 1000 / fps) {
        last = time;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.drawImage(image, frame * cell, 0, cell, image.height,
          0, 0, canvas.width, canvas.height);
        frame = playing ? (frame + 1) % frames : frame;
      }
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [image, frames, fps, zoom, playing]);

  if (error) return <div className="sprite-missing">시트를 불러오지 못했습니다</div>;
  return <canvas ref={canvasRef} className="sprite-anim" />;
}

// The same sheet laid out flat. Motion shows whether the cycle holds together;
// the strip shows which single frame is wrong when it does not, and the two
// questions are different enough to be worth both.
export function SpriteStrip({ sheet, frames, zoom = 2 }) {
  const [image, setImage] = useState(null);
  const canvasRef = useRef(null);

  useEffect(() => {
    const img = new Image();
    img.onload = () => setImage(img);
    img.src = sheet;
    return () => { img.onload = null; };
  }, [sheet]);

  useEffect(() => {
    if (!image || !canvasRef.current) return;
    const canvas = canvasRef.current;
    canvas.width = image.width * zoom;
    canvas.height = image.height * zoom;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
    // A rule on every cell boundary. The registration is the thing under review
    // and it is much easier to see a foot drifting against a fixed line than
    // against the frame beside it.
    const cell = Math.round(image.width / frames) * zoom;
    ctx.strokeStyle = 'rgba(255,179,71,0.30)';
    ctx.lineWidth = 1;
    for (let i = 1; i < frames; i += 1) {
      ctx.beginPath();
      ctx.moveTo(i * cell + 0.5, 0);
      ctx.lineTo(i * cell + 0.5, canvas.height);
      ctx.stroke();
    }
  }, [image, frames, zoom]);

  return <canvas ref={canvasRef} className="sprite-strip" />;
}
