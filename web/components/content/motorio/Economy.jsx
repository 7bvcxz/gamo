import React from 'react';
import balance from '../../../lib/generated/balance.json';

// Every number on this page is read from generated/balance.json, which is dumped
// straight out of Defs.gd. Nothing here is typed by hand, because hand-copied
// balance figures rot: belt speed once changed by a factor of ten and the design
// page went on quoting the old one for three versions.

const n = (value, digits = 0) => Number(value).toFixed(digits);

export function Economy() {
  return (
    <>
      <h1>경제 · 밸런스</h1>
      <p className="lede">
        이 페이지의 모든 숫자는 <code>Defs.gd</code>에서 자동으로 추출됩니다. 손으로 적지 않으므로
        게임과 어긋날 수 없습니다. 밸런스를 바꾸면{' '}
        <code>godot --headless --path motorio --script res://tools/dump_balance.gd</code>{' '}
        를 실행해 같은 커밋에 포함하세요.
      </p>
      <p className="gfx-warn">
        기준 버전 <b>v{balance.version}</b> · 출처 <code>{balance.generated_by}</code>
      </p>

      <h2>재료</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>재료</th><th>연료</th><th>역할</th></tr>
          </thead>
          <tbody>
            {balance.items.names.map((name, index) => (
              <tr key={name}>
                <td>{name}</td>
                <td>{name === balance.items.fuel ? '기지 연료' : '—'}</td>
                <td>
                  {index === 0 && '손으로 캘 수 있는 유일한 자원. 발전기의 연료'}
                  {index === 1 && '설비 재료. 채굴 속도가 절반'}
                  {index === 2 && '발전기 연료'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p>
        <b>열은 건설비가 아닙니다.</b> 설비는 기지에 쌓인 재료로 짓고, 열은 오직 온기 반경입니다.
        이 분리가 이 게임의 유일한 진짜 결정을 만듭니다 — 수정을 <b>거리</b>로 바꿀 것인가{' '}
        <b>생산</b>으로 바꿀 것인가.
      </p>

      <h2>속도</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>행동</th><th>주기</th><th>분당</th></tr>
          </thead>
          <tbody>
            <tr><td>손 채굴</td><td>{n(balance.rates.hand_mine_seconds, 1)}초</td><td>{n(60 / balance.rates.hand_mine_seconds, 1)}</td></tr>
            <tr><td>채굴기 (수정)</td><td>{n(balance.rates.miner_seconds, 1)}초</td><td>{n(60 / balance.rates.miner_seconds, 1)}</td></tr>
            <tr><td>채굴기 (구리)</td><td>{n(balance.rates.copper_seconds, 1)}초</td><td>{n(60 / balance.rates.copper_seconds, 1)}</td></tr>
            <tr><td>발전기 연료 소모</td><td>{n(balance.rates.generator_seconds, 1)}초</td><td>{n(60 / balance.rates.generator_seconds, 1)}</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        손 채굴과 채굴기가 <b>같은 속도</b>인 것은 의도입니다. 첫 채굴기는 더 빠른 것이 아니라{' '}
        <b>다른 곳에 있는 것</b>이고, 자동화의 동기는 속도가 아니라 병렬성입니다.
      </p>
      <p className="quote-ish"><b>{balance.rates.ratio_hint}</b></p>

      <h2>광맥 순도</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>등급</th><th>배율</th><th>수정/분</th><th>거리</th></tr>
          </thead>
          <tbody>
            {balance.purity.map((grade, index) => (
              <tr key={grade.name}>
                <td>{grade.name}</td>
                <td>{n(grade.multiplier, 1)}배</td>
                <td>{n(grade.crystal_per_minute, 1)}</td>
                <td>
                  {index === 0 && `${balance.rings.purity_rich}칸 안쪽`}
                  {index === 1 && `${balance.rings.purity_rich}칸 밖`}
                  {index === 2 && `${balance.rings.purity_pure}칸 밖`}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2>벨트 등급</h2>
      <div className="table-wrap">
        <table>
          <thead>
            <tr><th>등급</th><th>칸당</th><th>10칸</th><th>분당</th><th>구리</th></tr>
          </thead>
          <tbody>
            {balance.belts.map((belt) => (
              <tr key={belt.name}>
                <td>{belt.name}</td>
                <td>{n(belt.seconds_per_tile, 1)}초</td>
                <td>{n(belt.ten_tile_seconds)}초</td>
                <td>{n(belt.items_per_minute)}</td>
                <td>{belt.copper}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p>
        등급은 <b>처리량 게이트가 아닙니다.</b> 가장 느린 등급도 최고 광맥 채굴기(
        {n(balance.purity[balance.purity.length - 1].crystal_per_minute, 1)}/분)의 몇 배를
        나릅니다. 등급이 사는 것은 <b>도착 시간</b>이고, 그래서 무시해도 되는 선택입니다.
      </p>

      <h2>전력</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>항목</th><th>값</th></tr></thead>
          <tbody>
            <tr><td>발전기 공급</td><td>{n(balance.power.generator_output, 1)}</td></tr>
            <tr><td>고양이 없는 채굴기 소비</td><td>{n(balance.power.miner_draw, 1)}</td></tr>
            <tr><td>발전기 1대가 감당하는 채굴기</td><td>{n(balance.power.miners_per_generator)}대</td></tr>
          </tbody>
        </table>
      </div>
      <p>
        전력은 <b>저장되지 않는 비율</b>입니다. 부족하면 소비 설비가 비례해서 느려질 뿐 멈추지
        않습니다. 전력이 채굴기를 돌릴 수 있다는 것이 중요합니다 — 그것이 없으면 공장 규모가 고양이
        수, 즉 탐험량에 묶여 공학 문제가 아니게 됩니다.
      </p>

      <h2>진행의 관문</h2>
      <p>
        구리 지대(반경 {balance.rings.copper[0]}칸)에 닿는 것이 초중반 유일한 큰 관문입니다.
      </p>
      <div className="table-wrap">
        <table>
          <thead><tr><th>필요</th><th>값</th></tr></thead>
          <tbody>
            <tr><td>불에 넣은 열석</td><td>{n(balance.gate_to_copper.stones)}개</td></tr>
            <tr><td><b>채굴기 2대 기준</b></td><td><b>{n(balance.gate_to_copper.days_two_miners, 1)}일</b></td></tr>
          </tbody>
        </table>
      </div>
      <p>
        이 수치는 <code>tests/test_progression.gd</code>가 매 실행마다 검증합니다. 6일을 넘거나
        1일 안에 끝나면 테스트가 실패합니다. 설계 초안에서는 같은 관문이 910개 · 50일이었습니다.
      </p>

      <h2>설비 비용</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>설비</th><th>비용</th><th>처리량</th><th>해금</th></tr></thead>
          <tbody>
            {balance.machines.map((machine) => (
              <tr key={machine.name}>
                <td>{machine.name}</td>
                <td>{machine.cost.map((c) => `${c.item} ${c.count}`).join(' + ') || '—'}</td>
                <td>{machine.throughput}</td>
                <td>{machine.unlock.join(' · ') || '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <h2>추위</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>항목</th><th>값</th></tr></thead>
          <tbody>
            <tr><td>온기 반경</td><td>기지 단계별 고정 (시작 {balance.warmth.base_radius}칸 · 최대 {balance.warmth.max_radius}칸)</td></tr>
            <tr><td>반경 밖 설비 속도</td><td>{Math.round(balance.warmth.outside_speed * 100)}%</td></tr>
            <tr><td>반경 밖 체온 감소</td><td>초당 {n(balance.warmth.cold_drain, 1)}</td></tr>
            <tr><td>밤 추가 감소</td><td>초당 {n(balance.warmth.night_drain, 1)}</td></tr>
            <tr><td>체온 0 후 유예</td><td>{n(balance.warmth.collapse_grace, 1)}초</td></tr>
          </tbody>
        </table>
      </div>

      <h2>고양이</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>항목</th><th>값</th></tr></thead>
          <tbody>
            <tr><td>고양이 1마리당 상자</td><td>{balance.cats.boxes_per_cat}개</td></tr>
            <tr><td>상자 밀도</td><td>{balance.cats.tiles_per_box}칸당 1개</td></tr>
            <tr><td>이동 속도</td><td>{n(balance.cats.speed)}px/초</td></tr>
            <tr><td>사료 시작량</td><td>{balance.cats.food_start}</td></tr>
          </tbody>
        </table>
      </div>
    </>
  );
}
