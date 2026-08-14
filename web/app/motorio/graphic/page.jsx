'use client';

import { game, site } from '../../../lib/links.js';
import React, { useState } from 'react';
import { OBJECTS, ITEM_NAMES } from '../../../components/graphics/objects.js';
import { ObjectCanvas } from '../../../components/graphics/Canvas.jsx';

// Every object the player can see, at the size they see it and at four times
// that, with its states side by side. The point of the page is comparison: if
// two objects disagree about light direction or shadow, it shows here first.

function Card({ object }) {
  const [state, setState] = useState(0);
  const [snow, setSnow] = useState(false);
  return (
    <section className="gfx-card">
      <header>
        <div>
          <b>{object.name}</b>
          <span className="gfx-kind">{object.kind}</span>
        </div>
        <div className="gfx-controls">
          {object.states.length > 1 &&
            object.states.map((label, index) => (
              <button
                key={label}
                className="gfx-chip"
                aria-pressed={index === state}
                onClick={() => setState(index)}
              >
                {label}
              </button>
            ))}
          <button className="gfx-chip" aria-pressed={snow} onClick={() => setSnow(!snow)}>
            {snow ? '눈밭' : '온기'}
          </button>
        </div>
      </header>
      <div className="gfx-row">
        <figure>
          <ObjectCanvas draw={object.draw} state={state} zoom={1} size={64}
            background={snow ? 'snow' : 'ground'} />
          <figcaption>실제 크기</figcaption>
        </figure>
        <figure>
          <ObjectCanvas draw={object.draw} state={state} zoom={4} size={176}
            background={snow ? 'snow' : 'ground'} />
          <figcaption>4배</figcaption>
        </figure>
      </div>
      <p className="gfx-note">{object.note}</p>
    </section>
  );
}

function Graphic() {
  return (
    <div className="gfx-page">
      <header className="gfx-head">
        <p className="gfx-crumb">
          <a href={site('/')}>Gamo</a> · <a href={game('/motorio/')}>Motorio: Motorio</a>
        </p>
        <h1>그래픽</h1>
        <p className="lede">
          게임에 등장하는 모든 사물과 구조물의 현재 모습입니다. 애니메이션은 실제로 돌아가고,
          상태 버튼으로 가동 · 정지 · 결빙 같은 변형을 바꿔 볼 수 있습니다.
        </p>
      </header>

      <div className="gfx-rules">
        <h2>그리기 규칙</h2>
        <p>
          아래 네 가지가 모든 오브젝트에 공통으로 적용됩니다. 이 규칙이 생기기 전에는 그림자 3종,
          몸통 크기 20~28px, 일회성 색 12종이 섞여 있었습니다.
        </p>
        <ol>
          <li>빛은 항상 좌측 상단에서 온다. 솟은 몸통은 위·왼쪽 면이 밝고 아래·오른쪽 면이 어둡다.</li>
          <li>땅에 선 것은 모두 같은 눌린 그림자를 자기 발밑에 만든다.</li>
          <li>
            바깥 외곽선은 언제나 같은 검정이다 — 실루엣은 모든 오브젝트가 공유한다. 설비의
            고유색은 그 <b>안쪽</b> 테두리로만 들어간다. 같은 몸통을 쓰는 설비 세 종류를 구분하기
            위한 예외이며, 바깥선을 색칠하지는 않는다.
          </li>
          <li>바닥에 눕는 것(벨트, 떨어진 자원)은 그림자 없이 파여 들어가고, 서는 것은 솟는다.</li>
        </ol>
        <p className="gfx-warn">
          이 페이지의 그림은 <code>scripts/MachineLayer.gd</code>의 그리기 코드를 JS로 옮긴
          것입니다. 게임에서 오브젝트를 바꾸면 <code>web/src/graphics/objects.js</code>도 같은
          커밋에서 함께 고쳐야 어긋나지 않습니다.
        </p>
      </div>

      <div className="gfx-grid">
        {OBJECTS.map((o) => <Card key={o.id} object={o} />)}
      </div>

      <div className="gfx-rules">
        <h2>자원 색</h2>
        <p>세 재료는 색으로만 구분되므로, 서로 최대한 멀리 떨어진 색을 씁니다.</p>
        <ul className="gfx-swatches">
          {ITEM_NAMES.map((name, index) => (
            <li key={name}>
              <span className={`gfx-swatch gfx-swatch-${index}`} />
              {name}
            </li>
          ))}
        </ul>
        <p>
          바꾸고 싶은 게 있으면 <a href={site('/motorio/graphic/proposals/')}>그래픽 제안</a>{' '}
          페이지에서 선택지를 비교할 수 있습니다.
        </p>
      </div>
    </div>
  );
}

export default Graphic;
