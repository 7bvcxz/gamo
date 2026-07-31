import React from 'react';

// Reconstructed from git history for everything before 0.5.0, which is the first
// version the project actually tagged. Entries are grouped by what shipped
// together rather than by commit, so the list reads as changes a player would
// notice.

const RELEASES = [
  {
    version: '0.5.4',
    date: '2026-07-31',
    current: true,
    headline: '멈췄을 때 바라보는 방향',
    items: [
      ['수정', '왼쪽으로 걷다 멈추면 주인공이 오른쪽을 보던 문제. 마지막으로 이동한 좌우 방향을 유지한다'],
      ['변경', '위아래로만 걸으면 좌우 방향은 그대로 둔다'],
    ],
  },
  {
    version: '0.5.3',
    date: '2026-07-31',
    headline: '고양이를 안고 있는 것이 보인다',
    items: [
      ['수정', '고양이를 안으면 화면에서 사라지던 문제. 이제 주인공 바로 앞 0.3칸에 그려진다'],
      ['추가', '안긴 고양이가 주인공과 같은 방향을 바라본다. 주인공이 돌면 같이 돈다'],
      ['변경', '고양이를 안고 있는 동안에는 X로 설비를 회수할 수 없다. 내려놓으면 풀린다'],
    ],
  },
  {
    version: '0.5.2',
    date: '2026-07-31',
    headline: '광맥에 채굴기를 놓을 수 없던 문제',
    items: [
      [
        '수정',
        "광맥을 보고 Z를 눌러도 '구조물은 들 수 없습니다'만 뜨고 채굴기가 설치되지 않던 문제. 0.4.0에서 광맥이 구조물이 될 때 함께 들어온 결함으로, 게임의 핵심 배치가 막혀 있었다",
      ],
      ['개선', '설치가 거절되면 이유를 정확히 알려준다 (광맥 위에는 불가, 이미 설비가 있음 등)'],
    ],
  },
  {
    version: '0.5.1',
    date: '2026-07-31',
    headline: '코어에 구조물 속성',
    items: [
      ['변경', '코어가 구조물이 되어 주인공이 통과할 수 없다. 회수는 원래부터 불가능했다'],
      ['수정', '구조물 안에 있는 상태로 저장이 복원되면 빠져나올 수 없던 문제'],
      ['문서', '채굴기는 광맥 위에만 놓을 수 있고, 광맥이 구조물이라 채굴기 칸도 계속 몸을 막는다는 점을 Level Design에 명시'],
    ],
  },
  {
    version: '0.5.0',
    date: '2026-07-31',
    headline: '모바일 가독성과 화면 크기 설정',
    items: [
      ['추가', '좌측 최상단 설정 버튼과 UI 크기 · 게임 화면 크기 슬라이더 (60–160%)'],
      ['추가', '모바일 UI 기본 배율 2배, 게임 화면 기본 배율 PC 대비 160%'],
      ['수정', '터치로는 고양이를 들거나 놓을 수 없어 모바일에서 진행이 막히던 문제'],
      ['수정', '액션 버튼 히트 영역이 서로 겹쳐 오탭이 나던 문제'],
      ['수정', '목표 문구가 판을 넘쳐 마지막 글자가 잘리던 문제'],
      ['개선', '배율에 따라 핫바 폭·위치와 목표 문구 위치가 따라 바뀌는 반응형 레이아웃'],
      ['개선', '설정을 여는 동안 시계와 체온이 멈춘다'],
    ],
  },
  {
    version: '0.4.0',
    date: '2026-07-30',
    headline: '타일 속성과 고양이 노동',
    items: [
      ['추가', "타일 속성 '구조물' — 통과 불가, Z로 회수 불가. 광맥이 첫 사례"],
      ['추가', '고양이를 Z로 안아 채굴기에 올려 배정하는 조작'],
      ['추가', '아침마다 모든 고양이가 숙소에서 나와 배정된 기계로 걸어간다'],
      ['추가', '밥 먹는 모션과 허기 순환'],
      ['추가', '저장 · 불러오기와 30초 자동 저장'],
      ['추가', '체온 경사, 결빙 3단계, 유예 5초 뒤 쓰러짐과 암전'],
      ['변경', '자원 밀도와 채굴 속도를 1/5로, 구리와 철을 따로 집계'],
    ],
  },
  {
    version: '0.3.0',
    date: '2026-07-30',
    headline: '캐릭터 애니메이션',
    items: [
      ['추가', '8방향 페이싱과 프레임 순환 애니메이션'],
      ['수정', '스프라이트 시트가 균일 격자가 아니라 주인공이 프레임마다 순간이동하던 결함'],
      ['추가', 'Z 홀드 회전, PC UI 절반 크기, 목표 우측 상단 고정'],
    ],
  },
  {
    version: '0.2.0',
    date: '2026-07-29',
    headline: '누적되는 하루와 모바일 조작',
    items: [
      ['변경', '점수 런에서 다음 날로 이어지는 누적 구조로 전환'],
      ['추가', '밤에는 온기 안에서도 체온이 떨어져 숙소 취침이 필요해진다'],
      ['추가', 'Motorio의 주인공 · 고양이 아트와 한랭 연출'],
      ['추가', '모바일 터치 조작 (8방향 휠, Run · Z · X)'],
      ['수정', '모바일에서 게임을 시작할 수 없던 문제'],
      ['변경', '제련로가 출력면을 제외한 모든 면으로 입력을 받는다'],
    ],
  },
  {
    version: '0.1.0',
    date: '2026-07-28',
    headline: '첫 플레이 가능 빌드',
    items: [
      ['추가', '5분 스코어 런 구조의 초기 플레이 가능 빌드'],
      ['추가', '채굴기 · 벨트 · 제련로와 온기 반경 시스템'],
      ['개선', '5차에 걸친 시각 비평 반영 — 앰버 온기 램프, 자체발광 설비, HSV 그라데이션'],
      ['개선', '온기 그라데이션을 텍스처로 구워 프레임 타임 절반으로 단축'],
    ],
  },
];

const TAG_CLASS = {
  추가: 'tag-add',
  수정: 'tag-fix',
  변경: 'tag-change',
  개선: 'tag-improve',
  문서: 'tag-doc',
};

export function OneShotReleases() {
  return (
    <>
      <h1>One Shot — Releases</h1>
      <p className="lede">
        버전은 <code>motorio-oneshot/project.godot</code>의{' '}
        <code>application/config/version</code>이 단일 원본입니다. 개발이 한 번 끝날 때마다 patch를
        0.0.1 올리고, minor와 major는 요청이 있을 때만 올립니다.
      </p>

      {RELEASES.map((release) => (
        <section className="release" key={release.version}>
          <h2>
            {release.version}
            {release.current && <span className="release-current">현재</span>}
            <span className="release-date">{release.date}</span>
          </h2>
          <p className="release-headline">{release.headline}</p>
          <ul className="release-list">
            {release.items.map(([tag, text]) => (
              <li key={text}>
                <span className={`tag ${TAG_CLASS[tag]}`}>{tag}</span>
                {text}
              </li>
            ))}
          </ul>
        </section>
      ))}

      <h2>표기 규칙</h2>
      <p>
        0.5.0이 처음으로 실제 기록된 버전이고, 그 이전 항목은 git 이력에서 되짚어 묶은 것입니다.
        날짜와 내용은 커밋에 근거하지만 당시에 그 번호로 배포된 적은 없습니다.
      </p>
    </>
  );
}
