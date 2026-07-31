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
    note: '현재 체인은 서리광석 + 구리 → 철 한 단계뿐입니다.',
    items: [
      { state: 'todo', title: '수정 · 강철', body: '철 다음 단계의 가공 라인.' },
      { state: 'todo', title: '물 · 석유', body: '지형과 얽히는 자원. 다리와 펌프가 함께 필요합니다.' },
      { state: 'todo', title: '전기', body: '설비 가동 조건을 거리에서 인프라로 옮기는 축.' },
      { state: 'todo', title: '방사선', body: '후반 위험 요소. 온기와 대비되는 두 번째 압력.' },
      { state: 'todo', title: '농사 · 요리 · 생선', body: '고양이 허기 순환을 사료 상자 밖으로 확장.' },
      { state: 'todo', title: '특수 물체', body: '한 판에 하나씩 등장하는 규칙 파괴 요소.' },
    ],
  },
  {
    title: '물류와 공간',
    items: [
      {
        state: 'todo',
        title: '분리기',
        body: '들어온 자원을 좌우로 번갈아 보내는 설비. 라인이 갈라지기 시작하는 지점입니다.',
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
