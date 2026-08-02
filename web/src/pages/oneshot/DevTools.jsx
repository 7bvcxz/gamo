import React from 'react';

// The list of things in the build that exist for testing rather than for
// playing. Kept as its own page because it will grow, and because a reader
// needs to be able to tell at a glance which keys are not part of the game.

export function DevTools() {
  return (
    <>
      <h1>개발 도구</h1>
      <p className="lede">
        게임을 <b>끝까지 직접 돌려보기 위한</b> 기능들입니다. 플레이 경험의 일부가 아니며, 저장
        파일에도 남지 않습니다. 여기 있는 기능으로 관측한 결과를 밸런스 근거로 쓸 때는 배속이
        걸린 상태였는지 반드시 확인해야 합니다.
      </p>

      <h2>단축키</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>키</th><th>기능</th><th>비고</th></tr>
          </thead>
          <tbody>
            <tr>
              <td><code>F2</code></td>
              <td>배속 순환 — 1배 → 4배 → 10배 → 1배</td>
              <td>배속 중에는 화면 상단에 빨간 <code>DEBUG</code> 배지</td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2>배속이 무엇을 빠르게 하는가</h2>
      <p>
        <code>Engine.time_scale</code>을 바꾸는 방식이라 <b>델타를 쓰는 모든 것</b>이 함께 빨라집니다.
        시뮬레이션만 따로 돌리지 않은 이유가 이것입니다 — 기계만 빨라지고 하루 시계나 체온이 그대로면
        10배속으로 관측한 “하루에 얼마나 모이는가”가 실제와 달라져, 도구가 답을 왜곡합니다.
      </p>
      <ul>
        <li>채굴기 · 교환기 · 발전기의 주기</li>
        <li>벨트 위 물건의 이동, 분배기의 교대</li>
        <li>고양이의 이동 · 운반 · 사료 소모</li>
        <li>하루 시계, 해질녘, 체온 감소와 쓰러짐 유예</li>
        <li>플레이어 이동과 모든 애니메이션 · 연출</li>
      </ul>

      <h2>안전장치</h2>
      <ul>
        <li>
          <code>Engine.time_scale</code>은 전역이고 씬을 새로 불러도 유지되므로, 배속 상태로 끝난 판이
          다음 판에 그대로 넘어가지 않도록 <code>Main._ready()</code>에서 항상 1배로 되돌립니다.
        </li>
        <li>저장 스키마에 배속이 들어가지 않습니다. 불러오기는 언제나 1배로 시작합니다.</li>
        <li>
          <code>tests/test_debug.gd</code>가 위 두 가지와 순환 순서를 고정합니다.
        </li>
      </ul>
    </>
  );
}
