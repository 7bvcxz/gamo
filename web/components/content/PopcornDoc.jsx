import React from 'react';

// The question first; the answer stays "unknown" until people have played it.
// Numbers and the step-by-step state live in the repository
// (popcorn-glory/design, popcorn-glory/PROGRESS.md) and are linked, not copied.
export function PopcornDoc() {
  return (
    <article className="doc">
      <h1>Popcorn &amp; Glory</h1>
      <p className="lede">
        팝콘 기계 하나, 돈 하나, 주된 행동 하나. 누르면 팝콘이 터지고, 번 돈으로 기계를 키웁니다.
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

      <h2>지금의 답 — 팝콘 가게</h2>
      <p>
        세 실험(A·B·C)을 같은 조건에서 비교한 뒤 소유자가 <b>B, 딱 맞춘 순간에 떼기</b>를 골랐습니다
        (2026-11-03). 그 손맛 위에 만든 것이 <b>팝콘 가게</b>(<code>#stand</code>, 선택 화면 맨 위의 별)입니다.
        누르고 금색에서 떼면 팝콘이 터지고, 가게가 자라면서 흔들기·양념 셋·자동화(모터, 조수 냄비)가 하나씩
        열립니다. 손님이 봉지를 받아 가고, 다 사면 걸린 시간이 남습니다. 진행은 이 브라우저에 저장됩니다.
      </p>
      <p>
        재미의 판단은 아직 사람의 점수가 없습니다. 블라인드 AI 플레이어와 시뮬레이션은 무엇이 일어나는지를
        말할 뿐입니다. 해 보고 점수표에 남겨 주세요. 세 실험은 비교의 기준선으로 그대로 남아 있습니다.
      </p>

      <h2>넣지 않는 것</h2>
      <p>
        두 번째 돈, 연구, 상점, 광고, 결제, 프레스티지, 계절 초기화, 글로 된 튜토리얼. 재미가 확인되고
        소유자가 승인하기 전에는 시스템을 더하지 않습니다.
      </p>
    </article>
  );
}
