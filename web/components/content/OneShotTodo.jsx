import React from 'react';

// Kept honest on purpose: this lists what is actually unbuilt, including the
// architectural work that has to come first. Items move to Releases when they
// ship, not when they are started.

const GROUPS = [
  {
    title: '먼저 해야 하는 것',
    note:
      '콘텐츠를 늘리기 전에 치워야 하는 골격 작업입니다. 이걸 건너뛰고 자원을 하나씩 더하면 매번 여러 파일을 같이 고쳐야 합니다.',
    items: [
      {
        state: 'next',
        title: '레시피 · 설비를 데이터로 선언하는 층',
        body:
          '지금은 설비를 하나 추가하면 상수 배열, 색, 힌트, 배치 규칙, 저장 직렬화, 핫바까지 흩어진 곳을 함께 고쳐야 합니다. 자원 계층을 늘리기 전에 한 곳에서 선언하도록 바꿔야 합니다.',
      },
      {
        state: 'next',
        title: '다층 구조를 위한 타일 좌표계 결정',
        body:
          '2층 · 3층을 도입할 계획이라면 좌표계는 콘텐츠를 붙이기 전에 정하는 편이 훨씬 쌉니다. 나중에 바꾸면 저장 스키마와 모든 배치 코드가 함께 움직입니다.',
      },
    ],
  },
  {
    title: '자원과 생산',
    note: '현재 체인은 수정조각 → 에너지결정이고, 구리 촉매 제법이 두 번째 경로입니다.',
    items: [
      {
        state: 'todo',
        title: '등급별 월드 애니메이션',
        body:
          '결과창은 등급마다 다른 고양이를 보여주지만 월드에서는 전부 같은 시트를 재생하고 발밑 고리로만 구분됩니다. 고양이 한 마리당 클립 6개(대기 · 정면걷기 · 측면걷기 · 뒷걷기 · 식사 · 작업)를 생성해야 하며, 네 등급이면 클립 24개입니다.',
      },
      {
        state: 'next',
        title: '코인을 버는 방법',
        body:
          '가챠는 0.20.24에 들어갔지만 코인은 F3 디버그로만 나옵니다. 지금은 슬롯머신이 공장과 이어져 있지 않아서, 무엇을 하면 코인이 생기는지가 다음에 정할 것입니다.',
      },
      { state: 'todo', title: '강철', body: '구리 다음 단계의 가공 라인.' },
      { state: 'todo', title: '물 · 석유', body: '지형과 얽히는 자원. 다리와 펌프가 함께 필요합니다.' },
      { state: 'todo', title: '방사선', body: '후반 위험 요소. 온기와 대비되는 두 번째 압력.' },
      { state: 'todo', title: '농사 · 요리 · 생선', body: '고양이 허기 순환을 사료 상자 밖으로 확장.' },
      { state: 'todo', title: '특수 물체', body: '한 판에 하나씩 등장하는 규칙 파괴 요소.' },
    ],
  },
  {
    title: '물류와 공간',
    items: [
      {
        state: 'next',
        title: '스마트 분배기',
        body:
          '분배기는 0.8.0에 들어갔습니다. 다음은 출구마다 품목을 지정하는 버전 — 한 벨트로 여러 자원을 나르는 버스 설계가 성립합니다.',
      },
      {
        state: 'todo',
        title: '벨트 처리량이 의미를 갖게 하기',
        body:
          '지금 벨트는 459개/분으로 채굴기(6/분)의 76배라 절대 병목이 되지 않습니다. 벨트 등급이 의미를 가지려면 이 여유를 줄여야 합니다.',
      },
      {
        state: 'todo',
        title: '오버클럭',
        body:
          '전력을 더 써서 기계를 빠르게. 정수비가 안 맞는 상황을 버그가 아니라 퍼즐로 바꿔주는 연속적인 노브입니다.',
      },
      {
        state: 'todo',
        title: '새로운 종류를 요구하는 목표 사다리',
        body:
          'Satisfactory의 우주 엘리베이터처럼, 수량이 아니라 요구의 성격이 바뀌는 단계. 지금은 온기 반경 하나가 유일한 장기 목표입니다.',
      },
      {
        state: 'todo',
        title: '2층 · 3층 구조',
        body: '평면이 좁아졌을 때 위로 쌓는 선택지. 좌표계 결정이 선행되어야 합니다.',
      },
    ],
  },
  {
    title: '모바일과 조작',
    items: [
      {
        state: 'next',
        title: '조이스틱이 화면 오른쪽 55%를 전부 차지한다',
        body:
          '세로 제한이 없어서 우상단 목표 문구를 눌러도 이동이 시작됩니다. 휠 주변 반경으로 제한해야 합니다.',
      },
      {
        state: 'todo',
        title: '모바일에 채굴 버튼이 없다',
        body: '0.6.0의 손 채굴은 C 키 전용입니다. 터치 패드에 네 번째 버튼이 필요합니다.',
      },
      {
        state: 'todo',
        title: '게임 화면을 키우면 월드 라벨이 화면 밖으로 나간다',
        body: '`사료 200` 같은 월드 좌표 라벨이 확대 시 잘립니다.',
      },
    ],
  },
  {
    title: '정리',
    items: [
      {
        state: 'todo',
        title: 'HeyDive 게임 목록 등록',
        body: 'One Shot은 아직 정적 배포만 되어 있고 HeyDive 목록에는 올라가 있지 않습니다.',
      },
      {
        state: 'todo',
        title: '테스트 종료 시 노드 누수 경고',
        body: 'SceneTree 테스트가 Main을 해제하지 않아 ObjectDB 누수 경고가 남습니다.',
      },
    ],
  },
];

const STATE_LABEL = { next: '다음', todo: '예정' };

export function OneShotTodo() {
  return (
    <>
      <h1>One Shot — Todo</h1>
      <p className="lede">
        레벨 디자인은 전체의 일부만 완성된 상태입니다. 지금 시급한 것은 콘텐츠의 양이 아니라
        골격이고, 그래서 목록의 맨 위는 자원이 아니라 구조 작업입니다.
      </p>

      {GROUPS.map((group) => (
        <section key={group.title}>
          <h2>{group.title}</h2>
          {group.note && <p>{group.note}</p>}
          <ul className="todo-list">
            {group.items.map((item) => (
              <li key={item.title}>
                <span className={`tag tag-${item.state}`}>{STATE_LABEL[item.state]}</span>
                <b>{item.title}</b>
                <span className="todo-body">{item.body}</span>
              </li>
            ))}
          </ul>
        </section>
      ))}

      <h2>완료된 것</h2>
      <p>
        끝난 항목은 이 목록에서 빼고 <b>Releases</b>에 적습니다. 시작한 시점이 아니라 실제로
        동작하는 시점에 옮깁니다.
      </p>
    </>
  );
}
