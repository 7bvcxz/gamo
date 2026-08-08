import React from 'react';

// Gunslinger is a proof of concept, and its documentation is written as one: the
// question first, the answer honestly unknown, and the numbers that were chosen
// to make the question answerable. A doc page that reads like a feature list
// would be describing a different kind of thing.
export function GunslingerPoc() {
  return (
    <article className="doc">
      <h1>Gunslinger</h1>
      <p className="lede">
        서부 총잡이 1대1 한방 대결. 한 가지를 확인하려고 만든 프로토타입입니다.
      </p>

      <h2>확인하려는 질문</h2>
      <blockquote>
        &ldquo;대기 → 신호 → 순간 반응&rdquo;의 긴장감이 반복 플레이하고 싶을 만큼
        재미있는가?
      </blockquote>
      <p>
        총을 뽑기 전의 정적, 언제 올지 모르는 신호, 손가락이 머리보다 먼저 움직이는 순간.
        이것만으로 &ldquo;한 판 더&rdquo;가 나오는지를 봅니다. 나오지 않는다면 무엇을 더
        붙여도 소용없고, 나온다면 나머지는 그 위에 얹는 살입니다.
      </p>
      <p>
        <b>아직 답이 없습니다.</b> 조건은 전부 채웠지만 재미있는지는 사람이 해봐야 알 수 있고,
        그 판단이 이 프로토타입의 유일한 산출물입니다. 재미없다는 결론도 성공한 검증입니다 —
        큰 것을 짓기 전에 알아낸 것이니까요.
      </p>

      <h2>규칙</h2>
      <ul>
        <li>대결이 시작되면 <b>2~6초 사이 무작위 시점</b>에 DRAW! 신호가 뜹니다.</li>
        <li>신호 후 먼저 입력한 쪽이 이기고, 반응시간이 ms로 표시됩니다.</li>
        <li>신호 전에 누르면 <b>반칙패</b>입니다. 이 규칙이 대기에 비용을 붙입니다.</li>
        <li>3판 2선승. 한 번의 운으로 승부가 갈리지 않는 가장 짧은 형식입니다.</li>
      </ul>

      <h2>난이도</h2>
      <p>
        사람의 단순 시각 반응이 대략 200~250ms이고 훈련하면 180ms 근처까지 갑니다. 세 단계는
        그 사실에 맞춰 골랐습니다.
      </p>
      <table>
        <thead>
          <tr><th>단계</th><th>AI 반응</th><th>느낌</th></tr>
        </thead>
        <tbody>
          <tr><td>GREENHORN</td><td>420 ms</td><td>신호가 뭔지 익히는 동안에도 이깁니다</td></tr>
          <tr><td>OUTLAW</td><td>300 ms</td><td>집중해야 합니다</td></tr>
          <tr><td>LEGEND</td><td>200 ms</td><td>사람이 낼 수 있는 한계선입니다</td></tr>
        </tbody>
      </table>

      <h2>조작</h2>
      <p>
        아무 키, 클릭, 터치 전부 &ldquo;뽑기&rdquo;입니다. 타이틀에서 <b>1 / 2 / 3</b>으로
        난이도를 고릅니다. 반응 게임에 조작이 두 개일 이유가 없습니다.
      </p>

      <h2>만듦새에 대해</h2>
      <p>
        아트는 도형과 색만 씁니다. 이 프로토타입이 답하려는 질문에 그림 실력은 변수가
        아니고, 그림에 시간을 쓰면 답을 늦게 얻습니다. 반응시간은 프레임이 아니라 시스템
        시계로 잽니다 — 60fps의 한 프레임 17ms는 빠른 반응과 느린 반응의 차이 중 3분의
        1이라, 프레임으로 반올림하면 재려던 것이 사라집니다.
      </p>
      <p>
        완료 조건과 진행 기록은 저장소의 <code>gunslinger/GOAL.md</code>와{' '}
        <code>gunslinger/PROGRESS.md</code>에 있습니다. 조건에 없어서 만들지 않은 아이디어도
        그곳 <code>제안</code>에 남겨 두었습니다.
      </p>
    </article>
  );
}
