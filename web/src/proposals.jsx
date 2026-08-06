import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { PROPOSALS, DECIDED } from './graphics/proposals.js';
import { ObjectCanvas } from './graphics/Canvas.jsx';
import { SpriteAnimation, SpriteStrip } from './graphics/SpriteAnimation.jsx';
import sprites from './generated/sprites.json';

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
              sheet={candidate.sheet}
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
      {request.candidates.map((candidate) => (
        <div className="sprite-strip-row" key={candidate.id}>
          <span>{candidate.id.toUpperCase()}</span>
          <SpriteStrip sheet={candidate.sheet} frames={candidate.frames} zoom={stripZoom} />
        </div>
      ))}
      {request.source_video && (
        // The footage the sheet was cut from. Without it there is no telling a
        // weak generation from a good one the pipeline then damaged, and those
        // two want opposite fixes: ask the model again, or fix the normaliser.
        <div className="sprite-source">
          <span>원본 영상</span>
          <video src={request.source_video} controls loop muted playsInline preload="metadata" />
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
          <a href="/gamo/">Gamo</a> · <a href="/gamo/motorio-oneshot/">Motorio: One Shot</a> ·{' '}
          <a href="/gamo/motorio-oneshot/graphic/">그래픽</a>
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

createRoot(document.getElementById('root')).render(<Proposals />);
