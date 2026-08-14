'use client';

import { game, site } from '../../../../lib/links.js';
import React, { useEffect, useState } from 'react';
import { PROPOSALS, DECIDED } from '../../../../components/graphics/proposals.js';
import { ObjectCanvas } from '../../../../components/graphics/Canvas.jsx';
import { SpriteAnimation, SpriteStrip } from '../../../../components/graphics/SpriteAnimation.jsx';
import sprites from '../../../../lib/generated/sprites.json';
import art from '../../../../lib/generated/art.json';
import objects from '../../../../lib/generated/objects.json';
import freeze from '../../../../lib/generated/freeze.json';

// Where I put the graphic decisions I could not settle myself. Each question is
// five drawable options rather than five adjectives, because "warmer" and
// "chunkier" mean nothing until you can see them side by side.
//
// A pick is stored in this browser and shown back as a line to paste into chat;
// there is no server here, so the choice has to travel by hand.

const STORE = 'motorio.graphic-picks';
const SPRITE_STORE = 'motorio.sprite-picks';
const OBJECT_STORE = 'motorio.object-picks';

// Generated animations waiting on a decision, grouped by who is in them.
//
// These are not drawings I made and cannot judge between; they are candidates a
// video model produced that already passed validation -- foot anchored, palette
// locked, silhouette continuous frame to frame. Everything measurable has been
// measured, which is exactly why the remaining question needs a person: whether
// it reads as the right character doing the right thing is not a number.
//
// Eighteen of them in one column meant scrolling past Grim's four mining
// directions to reach the cat, and comparing two of a character's states meant
// remembering the first one. One character at a time, one state at a time.

// Ordering only. Anything not listed still appears, after the ones that are, so
// a state added tomorrow shows up without this file being edited -- a hand-kept
// list that silently drops entries is the failure this ordering is trying to
// avoid, not one to import.
const MOTION_ORDER = ['idle', 'walk', 'run', 'mine', 'eat', 'work'];
const FACING_ORDER = ['s', 'e', 'n', 'w', 'se', 'sw', 'ne', 'nw'];
const FACING_NAME = { s: '정면', e: '오른쪽', w: '왼쪽', n: '뒤', se: '오른쪽 앞', sw: '왼쪽 앞', ne: '오른쪽 뒤', nw: '왼쪽 뒤' };
const CHARACTER_NAME = { grim: 'Grim — 주인공', catorg: 'cat_org — 고양이' };
// What each motion is for in the game, so the thing being judged is whether the
// clip does that job rather than whether it looks nice on its own.
const MOTION_NOTE = {
  idle: '가만히 서 있을 때. 대부분의 시간을 이 시트로 보내므로, 눈에 띄는 동작보다 호흡이 끊기지 않는 쪽이 중요합니다.',
  walk: '이동 중. 발이 미끄러지지 않고 한 주기가 매끄럽게 이어지는지가 전부입니다.',
  run: '달릴 때. 걷기보다 빠르게 재생되므로 같은 보폭이면 오히려 어색해집니다.',
  mine: '곡괭이질. 한 스윙이 약 1.5초이고, 머리가 지면에 닿는 프레임에 소리와 파편이 붙습니다.',
  eat: '밥통 앞에서 먹을 때. 정면 하나뿐이며, 게임이 밥그릇을 따로 그리므로 클립 안에 그릇이 있으면 두 개가 됩니다.',
  work: '채굴기 위에서 일할 때. 정면 하나뿐이고, 기계 앞에 서 있는 모습으로 그려집니다.',
};

function splitId(id) {
  const [character, ...rest] = id.split('-');
  const state = rest.join('-');
  const [motion, facing] = [rest[0] || '', rest[1] || ''];
  return { character, state, motion, facing };
}

function rank(list, value) {
  const index = list.indexOf(value);
  return index < 0 ? list.length : index;
}

function SpritePanel({ request, picked, onPick }) {
  // Zoom is derived from the cell so a 64 and a 128 sheet appear the same size
  // on screen. Comparing cell sizes is the whole point of showing both, and a
  // fixed zoom would render the 128 one twice as large and settle the question
  // by presentation instead of by pixels.
  const zoom = Math.max(1, Math.round(256 / request.cell[0]));
  const stripZoom = Math.max(1, Math.round(128 / request.cell[0]));
  const { motion, facing } = splitId(request.id);
  return (
    <div className="sprite-panel">
      <div className="sprite-block">
        <span className="sprite-label">애니메이션</span>
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

      <div className="sprite-block">
        <span className="sprite-label">사진 — 펼친 프레임</span>
        {request.candidates.map((candidate) => (
          <div className="sprite-strip-row" key={candidate.id}>
            <span>{candidate.id.toUpperCase()}</span>
            <SpriteStrip sheet={site(candidate.sheet)} frames={candidate.frames} zoom={stripZoom} />
          </div>
        ))}
        <p className="sprite-note">
          같은 시트를 펼친 것입니다. 재생만으로는 어느 프레임이 튀는지 짚을 수 없어서, 잘못된
          한 장을 지목할 때 이쪽을 봅니다.
        </p>
      </div>

      {request.source_video && (
        // The footage the sheet was cut from. Without it there is no telling a
        // weak generation from a good one the pipeline then damaged, and those
        // two want opposite fixes: ask the model again, or fix the normaliser.
        <div className="sprite-block">
          <span className="sprite-label">원본 영상</span>
          <div className="sprite-source">
            <video src={site(request.source_video)} controls loop muted playsInline preload="metadata" />
            <p>
              생성 결과 그대로입니다. 640×640 · 4초 · 캐릭터 키 약 530px(480p로 요청했지만
              실제로는 640이 왔습니다). 위 스프라이트는 여기서 {request.candidates[0]?.frames ?? 8}프레임을
              골라 {request.cell[0]}px 셀로 줄인 것이라, 둘을 비교하면 화질이 생성 단계에서 정해진
              것인지 축소에서 잃은 것인지 구분됩니다.
            </p>
          </div>
        </div>
      )}

      <div className="sprite-block">
        <span className="sprite-label">설명</span>
        <p className="sprite-note">
          <b>{request.motion}</b> · {FACING_NAME[request.facing] || request.facing} 방향 ·{' '}
          {request.cell[0]}×{request.cell[1]} 셀 · 후보 {request.candidates.length}개.
        </p>
        {MOTION_NOTE[motion] && <p className="sprite-note">{MOTION_NOTE[motion]}</p>}
        <p className="sprite-note">
          이음매 숫자는 마지막 프레임과 첫 프레임의 차이입니다. 0에 가까울수록 반복이 끊기지
          않으며, 여기 있는 것은 전부 발 기준점·팔레트·실루엣 검사를 이미 통과했습니다. 남은
          판단은 <b>이 캐릭터가 이 동작을 하는 것으로 보이는가</b> 하나뿐이고, 그건 숫자로 잴 수
          없어서 여기 올라와 있습니다.
        </p>
      </div>
    </div>
  );
}

function CharacterSprites({ name, requests, picks, onPick }) {
  const [active, setActive] = useState(requests[0].id);
  const request = requests.find((r) => r.id === active) || requests[0];
  return (
    <section className="prop">
      <h2>{CHARACTER_NAME[name] || name}</h2>
      <p className="prop-why">
        상태 {requests.length}개. 탭을 고르면 그 동작의 애니메이션과 펼친 프레임, 잘라낸 원본
        영상을 함께 봅니다.
      </p>
      <div className="sprite-tabs" role="tablist" aria-label={name}>
        {requests.map((r) => (
          <button
            key={r.id}
            role="tab"
            type="button"
            className="sprite-tab"
            aria-selected={r.id === active}
            onClick={() => setActive(r.id)}
          >
            {splitId(r.id).state}
            {picks[r.id] && <i className="sprite-tab-dot" aria-label="고름" />}
          </button>
        ))}
      </div>
      <SpritePanel request={request} picked={picks[request.id]} onPick={onPick} />
    </section>
  );
}

function SpriteCharacters({ requests, picks, onPick }) {
  if (requests.length === 0) return null;
  const groups = new Map();
  for (const request of requests) {
    const { character } = splitId(request.id);
    if (!groups.has(character)) groups.set(character, []);
    groups.get(character).push(request);
  }
  for (const list of groups.values()) {
    list.sort((a, b) => {
      const left = splitId(a.id);
      const right = splitId(b.id);
      return (
        rank(MOTION_ORDER, left.motion) - rank(MOTION_ORDER, right.motion) ||
        rank(FACING_ORDER, left.facing) - rank(FACING_ORDER, right.facing) ||
        a.id.localeCompare(b.id)
      );
    });
  }
  const order = [...groups.keys()].sort(
    (a, b) => rank(Object.keys(CHARACTER_NAME), a) - rank(Object.keys(CHARACTER_NAME), b) || a.localeCompare(b),
  );
  return (
    <>
      <h2 className="prop-section">애니메이션 후보</h2>
      {order.map((name) => (
        <CharacterSprites
          key={name}
          name={name}
          requests={groups.get(name)}
          picks={picks}
          onPick={onPick}
        />
      ))}
    </>
  );
}

// Object candidates: buildings and machines, three or six of each.
//
// Generated renders rather than drawings, waiting on the same kind of decision
// the animations are waiting on -- which one is worth turning into pixels. Shown
// at 128 and at 64 because that is the question: 128 is what a pixel pass traces
// from, 64 is nearer what the game shows, and several of these read at one and
// turn to mush at the other.
//
// Everything here comes from web/lib/generated/objects.json, written by
// tools/sprite/build_objects.py out of the originals in tools/sprite/objects/.
const OBJECT_NAME = {
  base: '기지 코어',
  home: '숙소',
  feedbox: '밥통',
  miner: '채굴 기계',
  mine: '채굴장',
};
const OBJECT_NOTE = {
  base: '월드 한가운데의 열 코어. 지금은 코드로 그린 한 칸짜리 원입니다.',
  home: '남서쪽 숙소. 밤에 들어가 자고, 고양이도 여기로 돌아옵니다.',
  feedbox: '숙소 옆 사료통. 허기진 고양이가 여기로 와서 먹습니다.',
  miner:
    '광맥 위에 놓는 기계. 고양이가 올라서면 돌아가며, 위를 보게 놓으면 위 칸으로 뱉습니다. ' +
    '고양이 앞에 놓고 위아래로 떨게 하려면 세로로 긴 그림은 고양이를 가립니다.',
  mine:
    '캘 수 있는 자리. 지금 후보 셋은 광산 시설 건물이라 게임에 그런 것이 없습니다 — ' +
    '바닥의 광맥과 그 위의 기계뿐이므로 이 묶음은 다시 만들어야 합니다.',
};

// What the game draws right now, for every object it draws from a picture.
//
// Above the candidates rather than below them, because the first question anyone
// arriving here has is "what does it look like at the moment", and until this
// existed the page could only answer "here are six things one of which it might
// be". These are the files in assets/objects/ -- not the candidates they came
// from, which are cropped and resized on the way in.
//
// Shown at the size the game draws them as well as large. The small one is the
// one that decides whether a piece works: the miner is 43 screen pixels at the
// default zoom and 115 zoomed in, and detail that only exists at 128 is detail
// nobody ever sees.
function Shipped() {
  const chosen = objects.adopted || [];
  if (chosen.length === 0) return null;
  return (
    <section className="prop">
      <h2>지금 게임에 들어 있는 그림</h2>
      <p className="prop-why">
        후보가 아니라 <b>게임이 실제로 불러오는 파일</b>입니다. 왼쪽이 게임에서 그려지는 크기,
        오른쪽이 원본입니다. 작은 쪽이 판단 기준입니다 — 128에만 있는 디테일은 아무도 보지 않는
        디테일입니다.
      </p>
      <div className="shipped-grid">
        {chosen.map((item) => (
          <figure key={item.role} className="shipped">
            <div className="shipped-pair">
              <img
                src={site(item.sizes[String(Math.round(item.draw))])}
                alt={`${item.name} · 게임 크기`}
                width={Math.round(item.draw)}
                height={Math.round(item.draw)}
              />
              <img src={site(item.sizes['128'])} alt={item.name} width={128} height={128} />
            </div>
            <figcaption>
              <b>{item.name}</b>
              <span>
                {Math.round(item.draw)}px로 그림 · {item.stored}px 저장 · {item.from}
              </span>
            </figcaption>
          </figure>
        ))}
      </div>
      {objects.belt_loop && (
        <div className="shipped-loop">
          <h3>컨베이어가 이어지는 방식</h3>
          <p className="prop-why">
            직선·코너·분배기 세 조각뿐입니다. 생성한 벨트 그림에서 <b>단면 하나</b>를 재서 길을
            따라 쓸어 만들었기 때문에, 모든 팔이 칸 경계에 직각으로 닿고 경계의 픽셀이 곧 그
            단면입니다. 만나는 두 타일은 비슷한 게 아니라 같은 숫자입니다.
          </p>
          <img src={site(objects.belt_loop)} alt="벨트 고리" className="shipped-loop-img" />
        </div>
      )}
    </section>
  );
}

// The rescue, one picture per stage.
//
// This is not a question with five options -- the sheet is cut from a generated
// melt and there is only one of it. It is here because the one thing about it
// that cannot be measured is whether the animal is in the same place before and
// after the ice goes, and that is exactly the failure the first cut had: the cap
// sat at 56, 50, 42, 40 and the cat visibly sank between stages one and two.
// The tool now refuses a sheet whose cap moves more than three pixels, so what
// is left to look at is whether it reads as one cat melting rather than four
// drawings of a cat.
//
// The live sprite is on the end for the same reason. What follows the last stage
// in the game is that picture, and a step between them is a jump at the exact
// moment the rescue pays off.
function Frozen() {
  if (!freeze || !freeze.stages) return null;
  const zoom = 2;
  const size = freeze.cell * zoom;
  return (
    <section className="prop">
      <h2>얼어붙은 고양이 — 녹는 4단계</h2>
      <p className="prop-why">
        게임이 실제로 불러오는 시트입니다. 얼어붙은 고양이를 안고 와서 <b>기지 2칸 안</b>에
        내려놓으면 {freeze.stages.length}단계에 걸쳐 {' '}
        <b>12초</b> 동안 녹고, 마지막 그림 다음에 오는 것이 맨 오른쪽의 살아있는 고양이입니다.
        단계는 시간이 아니라 <b>남은 얼음의 양</b>으로 골랐습니다 — 생성된 영상은 처음에 빠르게
        녹고 끝에서 느려서, 시간을 4등분하면 앞의 둘이 거의 같은 그림이 됩니다.
      </p>
      <div className="freeze-row">
        {freeze.stages.map((stage) => (
          <figure key={stage.index} className="freeze-cell">
            <img
              src={site(stage.image)}
              alt={`${stage.index + 1}단계`}
              width={size}
              height={size}
            />
            <figcaption>
              <b>{stage.index + 1}단계</b>
              <span>얼음 {Math.round(stage.ice * 100)}%</span>
            </figcaption>
          </figure>
        ))}
        <figure className="freeze-cell freeze-live">
          <img src={site(freeze.live)} alt="깨어난 고양이" width={size} height={size} />
          <figcaption>
            <b>깨어난 뒤</b>
            <span>기존 고양이 시트</span>
          </figcaption>
        </figure>
      </div>
      <p className="sprite-note">
        마지막 단계에 일부러 얼음이 조금 남아 있습니다. 그 다음에 오는 것이 새 그림이 아니라
        평소의 고양이 시트라서, 완전히 녹은 단계는 게임이 이미 그리고 있는 것의 사본이 됩니다.
      </p>
    </section>
  );
}

function ObjectSubject({ subject, picks, onPick }) {
  const [active, setActive] = useState(subject.candidates[0].id);
  const candidate = subject.candidates.find((c) => c.id === active) || subject.candidates[0];
  return (
    <section className="prop">
      <h2>{OBJECT_NAME[subject.id] || subject.id}</h2>
      <p className="prop-why">
        후보 {subject.candidates.length}개. {OBJECT_NOTE[subject.id]}
      </p>
      <div className="sprite-tabs" role="tablist" aria-label={subject.id}>
        {subject.candidates.map((c) => (
          <button
            key={c.id}
            role="tab"
            type="button"
            className="sprite-tab"
            aria-selected={c.id === active}
            onClick={() => setActive(c.id)}
          >
            {c.id}
            {picks[subject.id] === c.id && <i className="sprite-tab-dot" aria-label="고름" />}
          </button>
        ))}
      </div>
      <div className="sprite-panel">
        <div className="sprite-block">
          <span className="sprite-label">128 — 픽셀로 옮길 원본 크기</span>
          <div className="object-row">
            <img className="object-shot object-128" src={site(candidate.sizes['128'])} alt={candidate.id} />
            <div className="object-side">
              <span className="sprite-label">64 — 게임에 가까운 크기</span>
              <img className="object-shot object-64" src={site(candidate.sizes['64'])} alt={candidate.id} />
            </div>
          </div>
        </div>
        <button
          className="btn"
          type="button"
          aria-pressed={picks[subject.id] === candidate.id}
          onClick={() => onPick(subject.id, candidate.id)}
        >
          {picks[subject.id] === candidate.id ? `${candidate.id} 선택됨` : `${candidate.id} 고르기`}
        </button>
        <p className="sprite-note">
          원본 {candidate.source[0]}×{candidate.source[1]}. 정사각형에 넣을 때 비율을 지키고 아래쪽에
          맞췄습니다 — 전부 타일 위에 놓이는 물건이라, 자기 발자국보다 떠 있으면 아트가 아니라 게임
          버그처럼 보입니다.
        </p>
      </div>
    </section>
  );
}

function ObjectCandidates({ picks, onPick }) {
  const subjects = objects.subjects || [];
  if (subjects.length === 0) return null;
  return (
    <>
      <h2 className="prop-section">오브젝트 후보</h2>
      {subjects.map((subject) => (
        <ObjectSubject key={subject.id} subject={subject} picks={picks} onPick={onPick} />
      ))}
    </>
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

  const [objectPicks, setObjectPicks] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem(OBJECT_STORE) || '{}');
    } catch {
      return {};
    }
  });
  useEffect(() => {
    localStorage.setItem(OBJECT_STORE, JSON.stringify(objectPicks));
  }, [objectPicks]);

  const pick = (id, index) => setPicks((p) => ({ ...p, [id]: index }));
  const pickObject = (id, candidate) => setObjectPicks((p) => ({ ...p, [id]: candidate }));
  const pickSprite = (id, candidate) => setSpritePicks((p) => ({ ...p, [id]: candidate }));
  const spriteRequests = sprites.requests || [];
  const spriteSummary = spriteRequests
    .filter((r) => spritePicks[r.id])
    .map((r) => `${r.id} → ${spritePicks[r.id]}`)
    .join('\n');
  const objectSummary = (objects.subjects || [])
    .filter((s) => objectPicks[s.id])
    .map((s) => `${OBJECT_NAME[s.id] || s.id} → ${objectPicks[s.id]}`)
    .join('\n');
  const chosen = PROPOSALS.filter((p) => picks[p.id] != null);
  const summary = [
    ...chosen.map((p) => `${p.title} → ${picks[p.id] + 1}. ${p.options[picks[p.id]].name}`),
    ...(spriteSummary ? [spriteSummary] : []),
    ...(objectSummary ? [objectSummary] : []),
  ].join('\n');

  return (
    <div className="gfx-page">
      <header className="gfx-head">
        <p className="gfx-crumb">
          <a href={site('/')}>Gamo</a> · <a href={game('/motorio/')}>Motorio: Motorio</a> ·{' '}
          <a href={site('/motorio/graphic/')}>그래픽</a>
        </p>
        <h1>그래픽 제안</h1>
        <p className="lede">
          그래픽을 바꿀 만한 지점 중에서 <b>제가 어느 쪽이 나은지 판단하지 못한 것</b>만 올립니다.
          각 질문은 다섯 가지 선택지로, 설명이 아니라 실제로 그려진 모습으로 비교합니다.
          1번은 언제나 현재 모습입니다.
        </p>
      </header>

      <Shipped />

      <Frozen />

      <SpriteCharacters requests={spriteRequests} picks={spritePicks} onPick={pickSprite} />

      <ObjectCandidates picks={objectPicks} onPick={pickObject} />

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
        {chosen.length === 0 && !spriteSummary && !objectSummary ? (
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
