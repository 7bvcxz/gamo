import React from 'react';

// The premise and the shared rules only. Step-by-step status lives in the GitHub
// issues and momonium/PROGRESS.md, which are updated as each step closes.
export function MomoniumDoc() {
  return (
    <article className="doc">
      <h1>Momonium</h1>
      <p className="lede">
        끝없는 바다 한가운데 2×2 잔디 섬, 그리고 $10. 밭 하나에서 시작해 땅을 한 칸씩 넓히고,
        일을 배운 모모들이 손을 대신하며 섬이 마을이 되고 문명이 됩니다.
      </p>

      <h2>시작 규칙</h2>
      <ul>
        <li>섬은 <b>2×2</b>, 돈은 <b>$10</b>, 레벨은 <b>1</b>. 미리 지어진 산업은 없습니다.</li>
        <li>하루는 실제 <b>30초</b>입니다. 하루가 넘어갈 때 창고의 작물이 팔립니다.</li>
        <li>
          밭은 심기 5초 → 물 주기 5초 × 3번(물 주기 사이 최소 30초) → 수확 5초. 연구는 이 과정을
          더 낫게 만들 뿐 건너뛰게 만들지 않습니다.
        </li>
        <li>땅은 이미 가진 땅과 맞닿은 1×1 바다 칸만 살 수 있습니다.</li>
        <li>모모는 처음에는 사람보다 4배 느리게 일하지만, 쉬지 않고 이어서 합니다.</li>
      </ul>

      <h2>원칙</h2>
      <ul>
        <li>세로 화면 우선, 위 2/5는 하늘, 아래 3/5는 섬과 바다.</li>
        <li>화면에는 최소한만. 정보는 필요할 때 여는 작은 패널에 있습니다.</li>
        <li>마법은 없습니다. 생산은 재료·시간·에너지를 쓰고, 연구는 그럴듯한 공학으로 개선합니다.</li>
        <li>게임 로직은 화면과 분리되어 있고, 수치는 데이터 파일에 있습니다.</li>
      </ul>
    </article>
  );
}
