// Open graphic questions. Each is a thing I could not settle from the code or a
// screenshot, with five drawable options rather than five adjectives.
//
// Draw functions take (ctx, t) already centred and scaled, same as objects.js.

import { PALETTE, shadow, body } from './objects.js';

function circle(ctx, x, y, r, fill) {
  ctx.fillStyle = fill;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
}
function ring(ctx, x, y, r, stroke, w = 1) {
  ctx.strokeStyle = stroke; ctx.lineWidth = w;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
}

export const PROPOSALS = [
  {
    id: 'crate-read',
    title: '고양이 상자를 무엇으로 읽히게 할까',
    why:
      '상자는 초반 유일한 수집 목표인데, 지금은 나무 상자에 발자국이 찍힌 모습이라 멀리서 보면 사료통과 헷갈립니다. 한 화면 건너에서 "저건 고양이다"가 즉시 읽혀야 합니다.',
    options: [
      {
        name: '현재 — 발자국 상자',
        note: '뚜껑 널판 + 발바닥 세 점.',
        draw(ctx) {
          shadow(ctx, 0, 9, 9);
          const c = body(ctx, 0, 0, 17, 'rgb(146,102,62)');
          ctx.fillStyle = 'rgb(196,146,92)';
          ctx.fillRect(c.x, -1.5, c.size, 3);
          circle(ctx, 0, -3, 2.4, PALETTE.catFace);
          circle(ctx, -3, -5, 1.1, PALETTE.catFace);
          circle(ctx, 3, -5, 1.1, PALETTE.catFace);
        },
      },
      {
        name: '창살 상자',
        note: '앞면이 창살이고 안에서 눈이 빛난다.',
        draw(ctx, t) {
          shadow(ctx, 0, 9, 9);
          const c = body(ctx, 0, 0, 17, 'rgb(146,102,62)');
          ctx.fillStyle = 'rgb(28,22,18)';
          ctx.fillRect(c.x + 3, c.y + 4, c.size - 6, c.size - 7);
          ctx.strokeStyle = 'rgb(196,146,92)';
          ctx.lineWidth = 1.2;
          for (let i = 0; i < 4; i++) {
            const x = c.x + 4 + i * 3;
            ctx.beginPath(); ctx.moveTo(x, c.y + 4); ctx.lineTo(x, c.y + c.size - 3); ctx.stroke();
          }
          const blink = Math.sin(t * 1.7) > 0.9 ? 0.1 : 1;
          circle(ctx, -2, 1, 1.1, `rgba(180,240,120,${blink})`);
          circle(ctx, 2, 1, 1.1, `rgba(180,240,120,${blink})`);
        },
      },
      {
        name: '귀 달린 상자',
        note: '실루엣 자체에 고양이 귀를 붙여 멀리서도 구분된다.',
        draw(ctx) {
          shadow(ctx, 0, 9, 9);
          ctx.fillStyle = PALETTE.outline;
          ctx.beginPath();
          ctx.moveTo(-7, -8); ctx.lineTo(-4, -13); ctx.lineTo(-1, -8);
          ctx.moveTo(7, -8); ctx.lineTo(4, -13); ctx.lineTo(1, -8);
          ctx.fill();
          const c = body(ctx, 0, 0, 17, 'rgb(146,102,62)');
          ctx.fillStyle = 'rgb(196,146,92)';
          ctx.fillRect(c.x, -1.5, c.size, 3);
          circle(ctx, 0, -2, 2.2, PALETTE.catFace);
        },
      },
      {
        name: '숨 쉬는 상자',
        note: '천천히 부풀었다 꺼진다. 안에 살아 있는 게 있다는 신호.',
        draw(ctx, t) {
          const breathe = 1 + Math.sin(t * 1.6) * 0.05;
          shadow(ctx, 0, 9, 9 * breathe);
          ctx.save();
          ctx.scale(breathe, breathe);
          const c = body(ctx, 0, 0, 17, 'rgb(146,102,62)');
          ctx.fillStyle = 'rgb(196,146,92)';
          ctx.fillRect(c.x, -1.5, c.size, 3);
          circle(ctx, 0, -3, 2.4, PALETTE.catFace);
          ctx.restore();
        },
      },
      {
        name: '리본 상자',
        note: '선물처럼 묶어 "받는 것"임을 강조.',
        draw(ctx) {
          shadow(ctx, 0, 9, 9);
          const c = body(ctx, 0, 0, 17, 'rgb(146,102,62)');
          ctx.fillStyle = PALETTE.beltRim;
          ctx.fillRect(-1.5, c.y, 3, c.size);
          ctx.fillRect(c.x, -1.5, c.size, 3);
          circle(ctx, -3, -2, 2, PALETTE.beltRim);
          circle(ctx, 3, -2, 2, PALETTE.beltRim);
        },
      },
    ],
  },
  {
    id: 'machine-identity',
    title: '설비 세 종류를 무엇으로 구분할까',
    why:
      '채굴기 · 교환기 · 발전기는 이제 같은 몸통을 씁니다. 통일감은 얻었지만 실루엣이 같아져서, 멀리서는 가운데 장식으로만 구분됩니다. 무엇을 구분의 축으로 삼을지가 문제입니다.',
    options: [
      {
        name: '현재 — 가운데 장식',
        note: '몸통은 같고 안쪽 모양만 다르다.',
        draw(ctx, t) {
          shadow(ctx, 0, 12, 11);
          body(ctx, 0, 0, 23, 'rgb(64,76,90)');
          const beat = 0.65 + Math.sin(t * 4) * 0.25;
          circle(ctx, 0, 0, 5, `rgba(140,209,250,${beat})`);
        },
      },
      {
        name: '지붕 실루엣',
        note: '설비마다 위에 다른 형태를 얹어 실루엣을 다르게.',
        draw(ctx, t) {
          shadow(ctx, 0, 12, 11);
          ctx.fillStyle = PALETTE.outline;
          ctx.beginPath();
          ctx.moveTo(-9, -11); ctx.lineTo(0, -18); ctx.lineTo(9, -11); ctx.fill();
          body(ctx, 0, 1, 21, 'rgb(64,76,90)');
          circle(ctx, 0, 1, 4.5, `rgba(140,209,250,${0.65 + Math.sin(t * 4) * 0.25})`);
        },
      },
      {
        name: '테두리 색',
        note: '몸통 외곽 한 줄만 설비 고유색으로.',
        draw(ctx, t) {
          shadow(ctx, 0, 12, 11);
          const b = body(ctx, 0, 0, 23, 'rgb(64,76,90)');
          ctx.strokeStyle = PALETTE.machineEdge;
          ctx.lineWidth = 2;
          ctx.strokeRect(b.x, b.y, b.size, b.size);
          circle(ctx, 0, 0, 4.5, `rgba(140,209,250,${0.65 + Math.sin(t * 4) * 0.25})`);
        },
      },
      {
        name: '몸통 비율',
        note: '설비마다 가로세로 비를 달리해 형태로 구분.',
        draw(ctx, t) {
          shadow(ctx, 0, 11, 12);
          ctx.fillStyle = PALETTE.outline;
          ctx.fillRect(-14, -9, 28, 20);
          ctx.fillStyle = 'rgb(64,76,90)';
          ctx.fillRect(-12, -7, 24, 16);
          ctx.fillStyle = 'rgb(96,112,130)';
          ctx.fillRect(-12, -7, 24, 3);
          circle(ctx, 0, 1, 4.5, `rgba(140,209,250,${0.65 + Math.sin(t * 4) * 0.25})`);
        },
      },
      {
        name: '작동 리듬',
        note: '형태는 같고, 움직이는 속도와 방식으로 구분.',
        draw(ctx, t) {
          shadow(ctx, 0, 12, 11);
          body(ctx, 0, 0, 23, 'rgb(64,76,90)');
          const step = Math.floor(t * 3) % 2;
          ctx.fillStyle = PALETTE.beltChevron;
          ctx.fillRect(-6, -2 + step * 2, 12, 3);
          ring(ctx, 0, 0, 8, `rgba(255,196,120,${step ? 0.7 : 0.2})`, 1.5);
        },
      },
    ],
  },
  {
    id: 'ground-item',
    title: '바닥에 떨어진 자원을 얼마나 눈에 띄게 할까',
    why:
      '손 채굴과 채굴기 산출물이 바닥에 떨어지고 고양이가 주워 갑니다. 너무 조용하면 플레이어가 못 보고, 너무 요란하면 화면이 자원 점으로 가득 찹니다. 자원은 곧 수십 개가 동시에 놓입니다.',
    options: [
      {
        name: '현재 — 떠 있는 구슬',
        note: '위아래로 천천히 흔들리고 하이라이트 하나.',
        draw(ctx, t) {
          const bob = Math.sin(t * 3) * 1.6;
          shadow(ctx, 0, 7, 5);
          circle(ctx, 0, bob, 7, 'rgba(127,212,232,0.28)');
          circle(ctx, 0, bob, 4.2, 'rgb(127,212,232)');
          ring(ctx, 0, bob, 4.2, PALETTE.outline, 1);
          circle(ctx, -1.4, bob - 1.4, 1.2, 'rgba(255,255,255,0.55)');
        },
      },
      {
        name: '땅에 놓인 파편',
        note: '흔들리지 않고 광맥과 같은 각진 모양. 조용하다.',
        draw(ctx) {
          shadow(ctx, 0, 6, 5);
          ctx.fillStyle = PALETTE.outline;
          ctx.beginPath();
          ctx.moveTo(-5, 3); ctx.lineTo(-2, -4); ctx.lineTo(4, -2); ctx.lineTo(3, 4); ctx.fill();
          ctx.fillStyle = 'rgb(127,212,232)';
          ctx.beginPath();
          ctx.moveTo(-4, 2); ctx.lineTo(-1.5, -3); ctx.lineTo(3, -1); ctx.lineTo(2, 3); ctx.fill();
        },
      },
      {
        name: '맥동하는 신호',
        note: '고리가 주기적으로 퍼진다. 절대 못 놓친다.',
        draw(ctx, t) {
          const p = (t % 1.4) / 1.4;
          shadow(ctx, 0, 7, 5);
          ring(ctx, 0, 0, 4 + p * 8, `rgba(127,212,232,${(1 - p) * 0.5})`, 1.5);
          circle(ctx, 0, 0, 4.2, 'rgb(127,212,232)');
          ring(ctx, 0, 0, 4.2, PALETTE.outline, 1);
        },
      },
      {
        name: '작은 자루',
        note: '자원이 아니라 "짐"으로 읽힌다. 고양이가 나른다는 게 자연스러워진다.',
        draw(ctx) {
          shadow(ctx, 0, 7, 6);
          ctx.fillStyle = PALETTE.outline;
          ctx.beginPath(); ctx.arc(0, 1, 5.5, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = 'rgb(150,132,104)';
          ctx.beginPath(); ctx.arc(0, 1, 4.5, 0, Math.PI * 2); ctx.fill();
          ctx.fillStyle = 'rgb(127,212,232)';
          ctx.fillRect(-2, -5, 4, 3);
          ctx.strokeStyle = PALETTE.outline; ctx.lineWidth = 1;
          ctx.strokeRect(-2, -5, 4, 3);
        },
      },
      {
        name: '그림자만 강조',
        note: '본체는 조용하고 그림자를 진하게. 수십 개가 놓여도 시끄럽지 않다.',
        draw(ctx) {
          shadow(ctx, 0, 6, 7);
          shadow(ctx, 0, 6, 5);
          circle(ctx, 0, -1, 3.6, 'rgb(127,212,232)');
          ring(ctx, 0, -1, 3.6, PALETTE.outline, 1);
        },
      },
    ],
  },
];
