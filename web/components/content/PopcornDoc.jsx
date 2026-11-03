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

      <h2>넣지 않는 것</h2>
      <p>
        두 번째 돈, 인벤토리, 연구, 상점, 매각, 관리 메뉴, 일곱 단계 요리, 글로 된 튜토리얼. 재미가
        확인되고 소유자가 승인하기 전에는 시스템을 더하지 않습니다. 저장도 하지 않습니다 — 실행할 때마다
        새로 시작합니다.
      </p>

      <h2>지금의 답</h2>
      <p>
        <b>아직 없습니다.</b> 세 실험을 모두 해 볼 수 있습니다(선택 화면의 A·B·C, 또는 주소 끝에
        <code>#click</code>·<code>#perfect</code>·<code>#explosion</code>). 그림은 아직 도형이고 소리는 없습니다.
        개발은 GitHub 이슈 &ldquo;Popcorn Step NN&rdquo;으로 진행하며 단계마다의 상태는 진행 기록(왼쪽 링크)에
        있습니다. 스크립트 플레이어의 수치는 무엇이 일어나는지를 말할 뿐이고, 재미의 판단은 사람이 직접 해 본
        점수로만 합니다.
      </p>
    </article>
  );
}
