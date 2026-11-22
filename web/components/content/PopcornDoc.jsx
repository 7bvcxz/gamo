import React from 'react';

// The question first, then the current answer (the three-floor factory, a
// release candidate); whether it is fun stays unknown until people have played it.
// Numbers and the step-by-step state live in the repository
// (popcorn-glory/design, popcorn-glory/PROGRESS.md) and are linked, not copied.
export function PopcornDoc() {
  return (
    <article className="doc">
      <h1>Popcorn &amp; Glory</h1>
      <p className="lede">
        누르고, 터뜨리고, 3층 팝콘 공장을 키웁니다. 처음에는 냄비 하나, 돈 하나, 주된 행동 하나였습니다.
      </p>

      <h2>확인하려는 질문</h2>
      <blockquote>
        같은 기계·같은 돈으로, 무엇이 3분 동안 계속하고 싶게 만드는가? 누르면 바로 터지는 손맛(A Click
        &amp; Pop), 딱 맞춘 순간에 떼는 숙련(B Perfect Pop), 모았다가 한 번에 터지는 볼거리(C Pop
        Explosion).
      </blockquote>
      <p>
        처음 해 보는 사람이 10초 안에 무엇을 할지 알고, 30초에 보상을 받고, 60초에 기계가 눈에 띄게
        바뀌고, 180초에 다음 변화가 궁금한지를 잽니다. 이 시간들은 보장이 아니라 측정할 목표이고, 지금의
        수치는 모두 가설입니다.
      </p>

      <h2>지금의 답 — 3층 공장 (출시 후보 0.48.1)</h2>
      <p>
        세 실험(A·B·C)을 같은 조건에서 비교한 뒤 소유자가 <b>B, 딱 맞춘 순간에 떼기</b>를 골랐습니다
        (2026-11-03). 그 손맛 위에 먼저 팝콘 가게(<code>#stand</code>)를 만들었고, 이어서{' '}
        <b>3층 공장</b>(<code>#factory</code>, 선택 화면의 첫 칸)을 만들었습니다.
      </p>
      <p>
        냄비를 누르고 금색에서 떼면 팝콘이 터집니다. 팝콘은 유리관을 타고 포장 층으로 올라가 봉지에 담기고,
        진열대를 지나 계산대에서 저마다 원하는 크기와 맛이 있는 손님에게 갑니다. 만든 것은 사라지지 않고
        늘 어딘가에 있습니다. 느린 층이 빨갛게 빛나면 다음에 무엇을 키울지 고릅니다. 세 층의 기계 40종을
        한 번에 44대까지, 맛 다섯, 한동안 손님을 바꾸는 뉴스, 동·은·금이 걸린 대회가 있습니다. 진행은 이
        브라우저에 저장되고, 한 번 열린 뒤에는 오프라인에서도 계속됩니다.
      </p>
      <p>
        0.48.1은 공개 주소의 빌드로 전체 시험(헤드리스 354 통과·0 실패, 브라우저 314 통과·0 실패)과 실제 폰
        (Samsung S23)에서 확인한 출시 후보이고, 소유자의 결정(Go/No-Go)을 기다립니다. 알려진 가장 큰 한계는
        폰에서 공장이 커질수록 느려지는 것입니다(S23, 기계 44대에서 13fps).
      </p>
      <p>
        재미의 판단은 아직 사람의 점수가 없습니다. 블라인드 AI 플레이어와 시뮬레이션은 무엇이 일어나는지를
        말할 뿐입니다. 해 보고 점수표에 남겨 주세요. 팝콘 가게와 세 실험은 선택 화면에 그대로 남아 있습니다.
      </p>

      <h2>넣지 않는 것</h2>
      <p>
        광고, 결제, 계정, 분석, 글로 된 튜토리얼. 스토어 출시와 HeyDive 등록도 소유자가 정하기 전에는 하지
        않습니다.
      </p>
    </article>
  );
}
