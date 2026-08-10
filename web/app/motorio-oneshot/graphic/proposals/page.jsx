'use client';

import { game, site } from '../../../../lib/links.js';
import React, { useEffect, useState } from 'react';
import { PROPOSALS, DECIDED } from '../../../../components/graphics/proposals.js';
import { ObjectCanvas } from '../../../../components/graphics/Canvas.jsx';
import { SpriteAnimation, SpriteStrip } from '../../../../components/graphics/SpriteAnimation.jsx';
import sprites from '../../../../lib/generated/sprites.json';
import art from '../../../../lib/generated/art.json';

// Where I put the graphic decisions I could not settle myself. Each question is
// five drawable options rather than five adjectives, because "warmer" and
// "chunkier" mean nothing until you can see them side by side.
//
// A pick is stored in this browser and shown back as a line to paste into chat;
// there is no server here, so the choice has to travel by hand.

const STORE = 'motorio-oneshot.graphic-picks';
const SPRITE_STORE = 'motorio-oneshot.sprite-picks';

// Generated animations waiting on a decision.
//
// These are not drawings I made and cannot judge between; they are candidates a
// video model produced that already passed validation -- foot anchored, palette
// locked, silhouette continuous frame to frame. Everything measurable has been
// measured, which is exactly why the remaining question needs a person: whether
// it reads as the right character doing the right thing is not a number.
function SpriteRequest({ request, picked, onPick }) {
  // Zoom is derived from the cell so a 64 and a 128 sheet appear the same size
  // on screen. Comparing cell sizes is the whole point of showing both, and a
  // fixed zoom would render the 128 one twice as large and settle the question
  // by presentation instead of by pixels.
  const zoom = Math.max(1, Math.round(256 / request.cell[0]));
  const stripZoom = Math.max(1, Math.round(128 / request.cell[0]));
  return (
    <section className="prop">
      <h2>{request.id}</h2>
      <p className="prop-why">
        {request.motion} · {request.facing} 방향 · {request.cell[0]}×{request.cell[1]} ·
        후보 {request.candidates.length}개. 정지 화면으로는 판단할 수 없어서 실제로
        재생합니다. 아래 띠는 같은 시트를 펼친 것으로, 어느 프레임이 틀렸는지 볼 때 씁니다.
      </p>
      <div className="prop-options">
        {request.candidates.map((candidate) => (
          <button
            key={candidate.id}
            className="prop-option"
            aria-pressed={picked === candidate.id}
            onClick={() => onPick(request.id, candidate.id)}
          >
            <SpriteAnimation
              sheet={site(candidate.sheet)}
              frames={candidate.frames}
              fps={candidate.fps}
              zoom={zoom}
            />
            <b>{candidate.id.toUpperCase()}</b>
            <span>
              {candidate.frames}프레임 · {candidate.fps}fps · 이음매 {candidate.closure}
              {candidate.seed >= 0 && <> · seed {candidate.seed}</>}
            </span>
            {candidate.note && <span className="prop-note">{candidate.note}</span>}
          </button>
        ))}
      </div>
      {request.mirrors && (
        // The direction this one covers for free. Shown because the decision to
        // mirror rather than generate is only sound if the mirrored result is
        // actually usable, and that is a thing to look at, not to assume.
        <div className="sprite-mirror">
          <span>{request.mirrors} 방향 — 같은 시트의 좌우반전</span>
          <div className="sprite-mirror-pair">
            {request.candidates.map((candidate) => (
              <SpriteAnimation
                key={candidate.id}
                sheet={site(candidate.sheet)}
                frames={candidate.frames}
                fps={candidate.fps}
                zoom={zoom}
                mirrored
              />
            ))}
          </div>
          <p>
            별도 시트를 만들지 않습니다. 발 기준점이 셀의 세로 중심선 위에 있어서 반전해도
            기준점이 자기 자신으로 옮겨가고, 사본을 두면 언젠가 원본과 어긋나기 때문입니다.
          </p>
        </div>
      )}
      {request.candidates.map((candidate) => (
        <div className="sprite-strip-row" key={candidate.id}>
          <span>{candidate.id.toUpperCase()}</span>
          <SpriteStrip sheet={site(candidate.sheet)} frames={candidate.frames} zoom={stripZoom} />
        </div>
      ))}
      {request.source_video && (
        // The footage the sheet was cut from. Without it there is no telling a
        // weak generation from a good one the pipeline then damaged, and those
        // two want opposite fixes: ask the model again, or fix the normaliser.
        <div className="sprite-source">
          <span>원본 영상</span>
          <video src={site(request.source_video)} controls loop muted playsInline preload="metadata" />
          <p>
            생성 결과 그대로입니다. 640×640 · 4초 · 캐릭터 키 약 530px(480p로 요청했지만
            실제로는 640이 왔습니다). 위 스프라이트는 여기서 8프레임을 골라 {request.cell[0]}px
            셀로 줄인 것이라, 둘을 비교하면 화질이 생성 단계에서 정해진 것인지 축소에서 잃은
            것인지 구분됩니다.
          </p>
        </div>
      )}
    </section>
  );
}

// The artwork the repository owns, most of which is not in the game.
//
// About 39 MB of it, and until now the only way to look at it was to open the
// files locally -- which meant deciding what to use next was a decision nobody
// could make from a phone. These are downscaled copies; the caption carries the
// source resolution so it is clear what was cut and what is simply the picture.
//
// Both lists and every caption come from web/lib/generated/art.json, written by
// tools/sprite/publish_art.py out of the same table the portrait builder reads.
// Nothing here is typed by hand, because a caption is exactly the kind of thing
// no test catches when it goes stale.
function ArtPiece({ piece, badge }) {
  return (
    <figure className="art-piece">
      <img src={site(piece.image)} alt={piece.id} loading="lazy" />
      <figcaption>
        <b>
          {piece.id}
          {badge && <span className="prop-current">{badge}</span>}
        </b>
        <span>
          {piece.source[0]}×{piece.source[1]} · {(piece.bytes / 1e6).toFixed(1)} MB
        </span>
        {piece.note && <span className="prop-note">{piece.note}</span>}
      </figcaption>
    </figure>
  );
}

function SourceArt() {
  const tiles = art.tiles || [];
  const cats = art.cats || [];
  if (tiles.length === 0 && cats.length === 0) return null;
  return (
    <>
      <h2 className="prop-section">가지고 있는 소재</h2>
      <section className="prop">
        <h2>타일</h2>
        <p className="prop-why">
          바닥과 지형용으로 사 둔 시트입니다. 지금 게임이 쓰는 것은 첫 번째 하나뿐이고, 나머지는
          아직 어디에도 들어가지 않았습니다. 6단계 광맥 시트는 자원 하나가 캐이면서 줄어드는 모습을
          여섯 칸으로 나눠 그린 것이라, 지금 코드로 그리는 결정 조각을 대체할 수 있습니다.
        </p>
        <div className="art-grid">
          {tiles.map((piece) => (
            <ArtPiece key={piece.id} piece={piece} badge={piece.id === 'tile_org_16' ? '사용 중' : null} />
          ))}
        </div>
      </section>
      <section className="prop">
        <h2>고양이</h2>
        <p className="prop-why">
          열 마리 전부입니다. 네 마리는 가챠 등급으로 배정됐고 — 결과창에 이 그림이 그대로
          나옵니다 — 나머지 여섯은 아직 쓰지 않았습니다. 월드에서는 아직 모든 등급이 cat_org로
          생성한 시트를 재생합니다. 등급마다 다르게 걷게 하려면 한 마리당 클립 여섯 개를 생성해야
          합니다.
        </p>
        <div className="art-grid">
          {cats.map((piece) => (
            <ArtPiece key={piece.id} piece={piece} badge={piece.grade || null} />
          ))}
        </div>
      </section>
    </>
  );
}

function Proposal({ proposal, picked, onPick }) {
  return (
    <section className="prop">
      <h2>{proposal.title}</h2>
      <p className="prop-why">{proposal.why}</p>
      <div className="prop-options">
        {proposal.options.map((option, index) => (
          <button
            key={option.name}
            className="prop-option"
            aria-pressed={picked === index}
            onClick={() => onPick(proposal.id, index)}
          >
            <ObjectCanvas draw={option.draw} zoom={4} size={132} />
            <b>
              {index + 1}. {option.name}
              {index === 0 && <span className="prop-current">현재</span>}
            </b>
            <span>{option.note}</span>
          </button>
        ))}
      </div>
      {picked != null && (
        <p className="prop-picked">
          선택: <b>{proposal.options[picked].name}</b>
        </p>
      )}
    </section>
  );
}

function Proposals() {
  const [picks, setPicks] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(STORE) || '{}');
    } catch {
      return {};
    }
  });
  useEffect(() => {
    localStorage.setItem(STORE, JSON.stringify(picks));
  }, [picks]);

  const [spritePicks, setSpritePicks] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(SPRITE_STORE) || '{}');
    } catch {
      return {};
    }
  });
  useEffect(() => {
    localStorage.setItem(SPRITE_STORE, JSON.stringify(spritePicks));
  }, [spritePicks]);

  const pick = (id, index) => setPicks((p) => ({ ...p, [id]: index }));
  const pickSprite = (id, candidate) => setSpritePicks((p) => ({ ...p, [id]: candidate }));
  const spriteRequests = sprites.requests || [];
  const spriteSummary = spriteRequests
    .filter((r) => spritePicks[r.id])
    .map((r) => `${r.id} → ${spritePicks[r.id]}`)
    .join('\n');
  const chosen = PROPOSALS.filter((p) => picks[p.id] != null);
  const summary = [
    ...chosen.map((p) => `${p.title} → ${picks[p.id] + 1}. ${p.options[picks[p.id]].name}`),
    ...(spriteSummary ? [spriteSummary] : []),
  ].join('\n');

  return (
    <div className="gfx-page">
      <header className="gfx-head">
        <p className="gfx-crumb">
          <a href={site('/')}>Gamo</a> · <a href={game('/motorio-oneshot/')}>Motorio: One Shot</a> ·{' '}
          <a href={site('/motorio-oneshot/graphic/')}>그래픽</a>
        </p>
        <h1>그래픽 제안</h1>
        <p className="lede">
          그래픽을 바꿀 만한 지점 중에서 <b>제가 어느 쪽이 나은지 판단하지 못한 것</b>만 올립니다.
          각 질문은 다섯 가지 선택지로, 설명이 아니라 실제로 그려진 모습으로 비교합니다.
          1번은 언제나 현재 모습입니다.
        </p>
      </header>

      {spriteRequests.length > 0 && (
        <>
          <h2 className="prop-section">애니메이션 후보</h2>
          {spriteRequests.map((r) => (
            <SpriteRequest
              key={r.id}
              request={r}
              picked={spritePicks[r.id]}
              onPick={pickSprite}
            />
          ))}
        </>
      )}

      <SourceArt />

      {PROPOSALS.length === 0 ? (
        <section className="prop">
          <h2>지금은 열린 질문이 없습니다</h2>
          <p className="prop-why">
            그래픽을 바꿀 만한 지점이 생기고 제가 어느 쪽이 나은지 판단하지 못하면 여기에 다섯 가지
            선택지로 올라옵니다.
          </p>
        </section>
      ) : (
        PROPOSALS.map((p) => (
          <Proposal key={p.id} proposal={p} picked={picks[p.id]} onPick={pick} />
        ))
      )}

      <section className="prop">
        <h2>결정된 것</h2>
        <p className="prop-why">
          고른 결과와, 그 선택이 무엇을 바꿨는지입니다. 나중에 이 결정을 뒤집을 때 무엇을 뒤집는
          것인지 알 수 있도록 남겨 둡니다.
        </p>
        <ul className="todo-list">
          {DECIDED.map((d) => (
            <li key={d.title}>
              <span className="tag tag-add">{d.choice}</span>
              <b>{d.title}</b>
              <span className="todo-body">{d.note}</span>
            </li>
          ))}
        </ul>
      </section>

      <section className="prop-summary">
        <h2>고른 것</h2>
        {chosen.length === 0 && !spriteSummary ? (
          <p>아직 고른 것이 없습니다.</p>
        ) : (
          <>
            <p>아래를 그대로 복사해서 보내주시면 그대로 반영합니다.</p>
            <pre>{summary}</pre>
            <button className="btn" onClick={() => navigator.clipboard?.writeText(summary)}>
              복사
            </button>
            <button className="btn" onClick={() => setPicks({})}>
              모두 지우기
            </button>
          </>
        )}
      </section>
    </div>
  );
}

export default Proposals;
