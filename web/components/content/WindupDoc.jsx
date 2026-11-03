import React from 'react';

// The question first, the answer honestly unknown until people have played it.
// Numbers and the step-by-step state live in the repository (windup/design,
// windup/PROGRESS.md); this page links there instead of copying them.
export function WindupDoc() {
  return (
    <article className="doc">
      <h1>태엽 공방 (The Wind-Up Atelier)</h1>
      <p className="lede">
        잊힌 양복점 공방에서 작은 정령이 큰 놋쇠 태엽을 감습니다. 감은 힘이 잠든 태엽 인형을
        깨우고, 깨어난 인형은 다음 인형의 태엽을 함께 감습니다.
      </p>

      <h2>확인하려는 질문</h2>
      <blockquote>
        죽은 공방을 살려 내는 것 자체가 즐거운가? 행동 하나(감기), 통화 하나(태엽 힘),
        자라는 것 하나(공방 전체)만으로.
      </blockquote>
      <p>
        처음 해 보는 사람이 10초 안에 무엇을 할지 알고, 30초에 첫 보상을 받고, 60초에 공방이 눈에 띄게
        달라지고, 180초에 다음이 궁금한지를 잽니다. 이 시간들은 보장이 아니라 측정할 목표입니다.
      </p>

      <h2>넣지 않는 것</h2>
      <p>
        인벤토리, 연구 트리, 두 번째 통화, 상점, 업그레이드 버튼, 일정, 인형 배치·강화, Prestige,
        오프라인 진행, 글로 된 튜토리얼. 재미가 모자랄 때 이것들을 몰래 더해 해결하지 않습니다.
      </p>

      <h2>지금의 답</h2>
      <p>
        <b>아직 없습니다.</b> 개발은 GitHub 이슈 &ldquo;Windup Step NN&rdquo;으로 진행하며, 단계마다의
        상태는 진행 기록(왼쪽 링크)에 있습니다. 재미의 판단은 사람이 직접 해 본 점수로만 합니다.
      </p>
    </article>
  );
}
