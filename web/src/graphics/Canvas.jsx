import React, { useEffect, useRef } from 'react';

// One animated tile. The draw function is handed a context already translated to
// the tile's centre and scaled, so every object can be written in the same world
// units the game uses -- a port that had to convert coordinates would drift from
// the original within a week.
export function ObjectCanvas({ draw, state = 0, zoom = 3, size = 120, background = 'ground' }) {
  const ref = useRef(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return undefined;
    const ctx = canvas.getContext('2d');
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = size * dpr;
    canvas.height = size * dpr;

    let raf = 0;
    const started = performance.now();
    const frame = () => {
      const t = (performance.now() - started) / 1000;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      // The game has exactly two grounds, and an object that reads on one can
      // vanish on the other, so the gallery can put either behind it.
      ctx.fillStyle = background === 'snow' ? '#d3dbe6' : '#8a6a45';
      ctx.fillRect(0, 0, size, size);
      ctx.strokeStyle = 'rgba(96,116,156,0.22)';
      ctx.lineWidth = 1;
      const step = 32 * (zoom / 3);
      for (let g = (size / 2) % step; g <= size; g += step) {
        ctx.beginPath(); ctx.moveTo(g, 0); ctx.lineTo(g, size); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0, g); ctx.lineTo(size, g); ctx.stroke();
      }
      ctx.save();
      ctx.translate(size / 2, size / 2);
      ctx.scale(zoom, zoom);
      ctx.imageSmoothingEnabled = false;
      draw(ctx, t, state);
      ctx.restore();
      raf = requestAnimationFrame(frame);
    };
    frame();
    return () => cancelAnimationFrame(raf);
  }, [draw, state, zoom, size, background]);

  return (
    <canvas
      ref={ref}
      style={{ width: size, height: size, borderRadius: 10, display: 'block' }}
    />
  );
}
