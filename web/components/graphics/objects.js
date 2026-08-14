// A port of motorio's object drawing, so the graphic gallery shows what
// the game actually draws rather than an artist's impression of it.
//
// IT IS A PORT, AND PORTS DRIFT. The rules and constants below mirror
// motorio/scripts/Defs.gd and MachineLayer.gd. If you change how an
// object is drawn in the game, change it here in the same commit. The gallery
// page states this, so nobody trusts it further than it deserves.

export const TILE = 32;

// --- Defs.gd -----------------------------------------------------------------
export const PALETTE = {
  void: '#0e1320',
  snowCold: '#222c44',
  core: '#ffb347',
  coreDeep: '#e0702a',
  brass: '#d8a34a',
  machineEdge: '#6fd2c8',
  beltBody: 'rgb(56,67,79)',
  beltBodyCold: 'rgb(38,46,56)',
  beltRim: 'rgb(255,211,160)',
  beltGlow: 'rgb(255,154,60)',
  beltChevron: 'rgb(255,196,120)',
  frozenChevron: 'rgb(120,140,160)',
  catFur: 'rgb(168,90,36)',
  catFace: 'rgb(250,226,190)',
  outline: 'rgb(16,20,28)',
  shadow: 'rgba(5,10,20,0.34)',
  text: '#e6eef7',
  textDim: '#8fa0bd',
  danger: '#e8574c',
};

export const MACHINE_EDGE = {
  miner: 'rgb(168,90,36)',
  exchanger: 'rgb(210,120,52)',
  generator: 'rgb(120,190,235)',
};

export const ITEM_COLORS = ['rgb(127,212,232)', 'rgb(252,104,46)', 'rgb(255,217,138)'];
export const ITEM_NAMES = ['수정조각', '구리광석', '에너지결정'];

const SHADOW_SQUASH = 0.42;
const MACHINE_BODY = 23;
const FACE_LIGHT = 0.2;
const FACE_DARK = 0.24;
const FACE_BAND = 3;

// --- helpers, mirroring MachineLayer._shadow and ._body -----------------------

function shade(rgb, amount) {
  const m = rgb.match(/\d+/g).map(Number);
  const f = amount >= 0 ? (c) => c + (255 - c) * amount : (c) => c * (1 + amount);
  return `rgb(${m.slice(0, 3).map((c) => Math.round(Math.min(255, Math.max(0, f(c))))).join(',')})`;
}

export function shadow(ctx, x, y, radius) {
  ctx.save();
  ctx.scale(1, SHADOW_SQUASH);
  ctx.fillStyle = PALETTE.shadow;
  ctx.beginPath();
  ctx.arc(x, y / SHADOW_SQUASH, radius, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();
}

// One footprint, one outline, light from the top-left.
export function body(ctx, cx, cy, size, base, edge = null) {
  const half = size / 2;
  const x = cx - half;
  const y = cy - half;
  ctx.fillStyle = PALETTE.outline;
  ctx.fillRect(x - 2, y - 2, size + 4, size + 4);
  ctx.fillStyle = base;
  ctx.fillRect(x, y, size, size);
  ctx.fillStyle = shade(base, FACE_LIGHT);
  ctx.fillRect(x, y, size, FACE_BAND);
  ctx.fillStyle = shade(base, FACE_LIGHT * 0.55);
  ctx.fillRect(x, y, FACE_BAND, size);
  ctx.fillStyle = shade(base, -FACE_DARK);
  ctx.fillRect(x, y + size - FACE_BAND, size, FACE_BAND);
  ctx.fillStyle = shade(base, -FACE_DARK * 0.55);
  ctx.fillRect(x + size - FACE_BAND, y, FACE_BAND, size);
  // Identity rim, inside the shared black outline rather than replacing it.
  if (edge) {
    ctx.strokeStyle = edge;
    ctx.lineWidth = 2;
    ctx.strokeRect(x + 1, y + 1, size - 2, size - 2);
  }
  return { x, y, size };
}

function circle(ctx, x, y, r, fill) {
  ctx.fillStyle = fill;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fill();
}

function ring(ctx, x, y, r, stroke, width = 1) {
  ctx.strokeStyle = stroke;
  ctx.lineWidth = width;
  ctx.beginPath();
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.stroke();
}

function pip(ctx, x, y, itemType, count) {
  for (let i = 0; i < Math.min(count, 4); i++) {
    circle(ctx, x - 6 + i * 4.5, y, 1.8, ITEM_COLORS[itemType]);
  }
}

// --- the objects -------------------------------------------------------------
// Each takes (ctx, t, state) where t is seconds and state selects a variant.

export const OBJECTS = [
  {
    id: 'core',
    name: '열 코어',
    kind: '구조물',
    note: '기지의 심장. 모든 자원이 여기로 모이고, 에너지결정만이 열이 된다.',
    states: ['가동'],
    draw(ctx, t) {
      const c = 0;
      const beat = 1 + Math.sin(t * 2.2) * 0.05;
      shadow(ctx, c, 22, 20);
      circle(ctx, c, c, 52 * beat, 'rgba(255,171,79,0.10)');
      circle(ctx, c, c, 38 * beat, 'rgba(255,171,79,0.16)');
      circle(ctx, c, c, 30, 'rgb(28,64,68)');
      circle(ctx, c, c, 26, PALETTE.coreDeep);
      circle(ctx, c, c, 18 * beat, PALETTE.core);
      circle(ctx, c, c, 10 * beat, '#fff0c9');
      for (let i = 0; i < 10; i++) {
        const a = (Math.PI * 2 * i) / 10 + t * 0.25;
        circle(ctx, Math.cos(a) * 33, Math.sin(a) * 33, 2.6, PALETTE.brass);
      }
      ring(ctx, c, c, 44, 'rgba(255,176,92,0.30)', 2);
    },
  },
  {
    id: 'shelter',
    name: '숙소',
    kind: '구조물',
    note: '하루가 끝나는 곳. 밤이 될수록 창문이 밝아진다.',
    states: ['낮', '밤'],
    draw(ctx, t, state) {
      const night = state === 1 ? 1 : 0;
      const lit = 0.3 + night * 0.7;
      const flicker = 1 + Math.sin(t * 5.3) * 0.06 + Math.sin(t * 2.1) * 0.04;
      circle(ctx, 0, 0, 30 * flicker, `rgba(255,158,66,${0.05 + night * 0.16})`);
      circle(ctx, 0, 0, 20 * flicker, `rgba(255,168,77,${0.07 + night * 0.2})`);
      shadow(ctx, 0, 13, 13);
      const wall = 'rgb(84,52,40)';
      ctx.fillStyle = wall;
      ctx.fillRect(-12, -2, 24, 16);
      ctx.fillStyle = 'rgb(104,66,50)';
      ctx.fillRect(-12, -2, 24 * 0.42, 16);
      ctx.strokeStyle = 'rgba(5,8,13,0.55)';
      ctx.lineWidth = 1;
      ctx.strokeRect(-12, -2, 24, 16);
      ctx.fillStyle = 'rgb(74,50,40)';
      ctx.beginPath();
      ctx.moveTo(-15, -1); ctx.lineTo(0, -15); ctx.lineTo(0, -1); ctx.fill();
      ctx.fillStyle = 'rgb(58,38,32)';
      ctx.beginPath();
      ctx.moveTo(0, -15); ctx.lineTo(15, -1); ctx.lineTo(0, -1); ctx.fill();
      ctx.strokeStyle = shade('rgb(216,163,74)', -0.35);
      ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.moveTo(-15, -1); ctx.lineTo(15, -1); ctx.stroke();
      ctx.fillStyle = 'rgba(5,8,13,0.60)';
      ctx.fillRect(-5.5, 0.5, 11, 11);
      ctx.fillStyle = `rgba(255,189,92,${lit})`;
      ctx.fillRect(-4, 2, 8, 8);
      ctx.fillStyle = `rgba(255,230,158,${lit})`;
      ctx.fillRect(-4, 2, 8, 2);
      circle(ctx, 0, 7, 9 * flicker, `rgba(255,179,82,${0.1 * lit})`);
      ctx.fillStyle = 'rgb(58,38,32)';
      ctx.fillRect(6, -15, 4, 7);
      for (let i = 0; i < 3; i++) {
        const rise = (t * 0.5 + i * 0.34) % 1;
        circle(ctx, 8 + Math.sin(rise * 4 + i) * 3, -17 - rise * 13,
          1.4 + rise * 1.8, `rgba(219,224,235,${(1 - rise) * 0.22})`);
      }
    },
  },
  {
    id: 'miner',
    name: '채굴기',
    kind: '설비',
    note: '광맥 위에만 설치할 수 있고, 고양이가 올라가야 돈다. 테두리 색이 설비 종류를 구분한다.',
    states: ['가동', '정지'],
    draw(ctx, t, state) {
      const operated = state === 0;
      const base = 'rgb(74,86,100)';
      shadow(ctx, 0, 12, 11);
      const plate = body(ctx, 0, 0, MACHINE_BODY, base, MACHINE_EDGE.miner);
      ctx.fillStyle = PALETTE.beltRim;
      ctx.fillRect(plate.x, plate.y, plate.size, 2.5);
      const spin = operated ? t * 5 : 0;
      for (let i = 0; i < 3; i++) {
        const a = spin + (Math.PI * 2 * i) / 3;
        ctx.strokeStyle = operated ? PALETTE.beltChevron : 'rgb(120,132,148)';
        ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(0, 0);
        ctx.lineTo(Math.cos(a) * 7, Math.sin(a) * 7); ctx.stroke();
      }
      if (operated) {
        const work = (t % 10) / 10;
        ctx.strokeStyle = 'rgba(255,255,255,0.42)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(0, 0, 15, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * work);
        ctx.stroke();
      } else {
        ring(ctx, 0, 0, 15, `rgba(191,199,217,${0.45 + Math.sin(t * 3) * 0.3})`, 1.5);
      }
    },
  },
  {
    id: 'exchanger',
    name: '수정에너지교환기',
    kind: '설비',
    note: '수정조각 2개를 5초마다 에너지결정 1개로 바꾼다. 재료가 모이면 창이 밝아진다.',
    states: ['가동', '재료 부족'],
    draw(ctx, t, state) {
      const ready = state === 0;
      const base = 'rgb(64,76,90)';
      const glow = ready ? 0.45 + Math.sin(t * 6) * 0.25 : 0.12;
      shadow(ctx, 0, 12, 11);
      const plate = body(ctx, 0, 0, MACHINE_BODY, base, MACHINE_EDGE.exchanger);
      ctx.fillStyle = `rgba(255,140,51,${glow})`;
      ctx.fillRect(-6, -4, 12, 10);
      ctx.strokeStyle = PALETTE.outline;
      ctx.lineWidth = 1;
      ctx.strokeRect(-6, -4, 12, 10);
      ctx.fillStyle = PALETTE.beltRim;
      ctx.fillRect(plate.x, plate.y, plate.size, 2.5);
      pip(ctx, 0, 13, 0, ready ? 2 : 1);
    },
  },
  {
    id: 'generator',
    name: '발전기',
    kind: '설비',
    note: '에너지결정을 10초마다 하나 태워 전력 1.0을 공급한다. 빛은 일부러 따뜻하지 않다.',
    states: ['공급 중', '연료 없음'],
    draw(ctx, t, state) {
      const live = state === 0;
      shadow(ctx, 0, 12, 11);
      body(ctx, 0, 0, MACHINE_BODY, 'rgb(64,76,90)', MACHINE_EDGE.generator);
      const beat = live ? 0.65 + Math.sin(t * 4) * 0.25 : 0.16;
      circle(ctx, 0, 0, 7.5, `rgba(77,148,199,${beat * 0.7})`);
      circle(ctx, 0, 0, 5, `rgba(140,209,250,${beat})`);
      circle(ctx, 0, 0, 2.2, `rgba(235,252,255,${beat})`);
      ring(ctx, 0, 0, 7.5, PALETTE.outline, 1);
      pip(ctx, 0, 13, 2, live ? 3 : 0);
    },
  },
  {
    id: 'belt',
    name: '컨테이너 벨트',
    kind: '설비 (바닥)',
    note: '바닥에 깔리므로 그림자가 없고 안쪽으로 들어간다. 전력 0.1을 쓰고, 부족하면 느려진다.',
    states: ['가동', '결빙'],
    draw(ctx, t, state) {
      const frost = state === 1 ? 1 : 0;
      const base = frost ? PALETTE.beltBodyCold : PALETTE.beltBody;
      circle(ctx, 0, 0, 19, `rgba(255,154,60,${0.3 * (1 - frost) + 0.05})`);
      ctx.fillStyle = PALETTE.outline;
      ctx.fillRect(-15, -15, 30, 30);
      ctx.fillStyle = base;
      ctx.fillRect(-14, -14, 28, 28);
      const rim = frost ? shade(PALETTE.beltRim, -0.5) : PALETTE.beltRim;
      ctx.fillStyle = rim;
      ctx.fillRect(-14, -14, 28, 2.5);
      ctx.fillStyle = rim;
      ctx.globalAlpha = 0.6;
      ctx.fillRect(-14, -14, 2.5, 28);
      ctx.globalAlpha = 1;
      for (let i = 0; i < 2; i++) {
        const off = (t * 2.6 * 0.5 + i * 0.5) % 1;
        const along = (off - 0.5) * TILE;
        ctx.strokeStyle = frost ? PALETTE.frozenChevron : PALETTE.beltChevron;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(along - 2, -5); ctx.lineTo(along + 5, 0);
        ctx.moveTo(along - 2, 5); ctx.lineTo(along + 5, 0);
        ctx.stroke();
      }
    },
  },
  {
    id: 'ore',
    name: '광맥',
    kind: '구조물',
    note: '지형의 일부라 통과할 수 없다. 온기 밖에서는 채도가 떨어지고 가끔 반짝인다.',
    states: ['수정 · 온기 안', '구리 · 온기 밖'],
    draw(ctx, t, state) {
      const copper = state === 1;
      const warm = !copper;
      const base = ITEM_COLORS[copper ? 1 : 0];
      const tint = warm ? base : shade(base, -0.15);
      shadow(ctx, 0, 8, 10);
      ctx.fillStyle = PALETTE.outline;
      ctx.beginPath();
      ctx.moveTo(-10, 7); ctx.lineTo(-5, -9); ctx.lineTo(4, -8);
      ctx.lineTo(10, 2); ctx.lineTo(8, 9); ctx.fill();
      ctx.fillStyle = shade(tint, -0.28);
      ctx.beginPath();
      ctx.moveTo(-9, 6); ctx.lineTo(-4, -8); ctx.lineTo(2, -3); ctx.lineTo(0, 8); ctx.fill();
      ctx.fillStyle = tint;
      ctx.beginPath();
      ctx.moveTo(0, 8); ctx.lineTo(3, -6); ctx.lineTo(9, 1); ctx.lineTo(7, 8); ctx.fill();
      ctx.strokeStyle = shade(tint, 0.5);
      ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(-4, -7); ctx.lineTo(-1, 2); ctx.stroke();
      if (copper) circle(ctx, 1, -1, 3, 'rgb(255,238,205)');
      circle(ctx, 3, -3, 1.8, `rgba(255,255,255,${warm ? 0.7 : 0.5})`);
      if (!warm) {
        const glint = Math.max(0, Math.sin(t * 0.8));
        if (glint > 0.9) circle(ctx, -3, -5, 2.4, `rgba(255,255,255,${(glint - 0.9) * 5})`);
      }
    },
  },
  // The cat crate used to be here. It is gone from the game -- cats are found
  // frozen and carried home now -- and a port of something the game no longer
  // draws is worse than no entry at all. What replaced it is a sprite, not code,
  // so it lives on the proposals page with the four melting stages rather than
  // in this gallery of canvas drawings.
  {
    id: 'foodbin',
    name: '사료통',
    kind: '구조물',
    note: '고양이가 배고파지면 스스로 여기로 걸어온다.',
    states: ['기본'],
    draw(ctx) {
      shadow(ctx, 0, 10, 10);
      const bin = body(ctx, 0, 0, 19, 'rgb(84,96,112)');
      ctx.fillStyle = 'rgb(46,54,66)';
      ctx.fillRect(bin.x + 3, bin.y + 3, bin.size - 6, 5);
      ctx.strokeStyle = PALETTE.outline;
      ctx.lineWidth = 1;
      ctx.strokeRect(bin.x + 3, bin.y + 3, bin.size - 6, 5);
    },
  },
  {
    id: 'grounditem',
    name: '바닥의 자원',
    kind: '수집물 (바닥)',
    note: '손으로 캐거나 채굴기가 뱉으면 바닥에 떨어진다. 밟으면 줍고, 한가한 고양이가 나른다.',
    states: ['수정조각', '구리광석', '에너지결정'],
    draw(ctx, t, state) {
      const colour = ITEM_COLORS[state];
      const bob = Math.sin(t * 3) * 1.6;
      shadow(ctx, 0, 7, 5);
      circle(ctx, 0, bob, 7, colour.replace('rgb', 'rgba').replace(')', ',0.28)'));
      circle(ctx, 0, bob, 4.2, colour);
      ring(ctx, 0, bob, 4.2, PALETTE.outline, 1);
      circle(ctx, -1.4, bob - 1.4, 1.2, 'rgba(255,255,255,0.55)');
    },
  },
];
