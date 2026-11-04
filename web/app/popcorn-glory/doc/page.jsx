'use client';

import React from 'react';
import { game, site } from '../../../lib/links.js';
import { DocShell } from '../../../components/DocShell.jsx';
import { PopcornDoc } from '../../../components/content/PopcornDoc.jsx';

// Popcorn & Glory is a prototype looking for a fun core: this page says what it
// is trying to find out and what the answer is so far. The design stays in
// popcorn-glory/design/*.md and is linked, not copied (a copy here would go stale).
const BLOB = 'https://github.com/7bvcxz/gamo/blob/main/popcorn-glory';
const NAV = [
  {
    group: '팝콘 기계',
    items: [{ id: 'question', label: '무엇을 확인하나', render: () => <PopcornDoc /> }],
  },
  {
    group: '링크',
    links: [
      { href: game('/popcorn-glory/#stand'), label: '팝콘 가게 플레이 →' },
      { href: game('/popcorn-glory/'), label: '세 실험과 가게 (선택 화면) →' },
      { href: game('/popcorn-glory/scorecard.html'), label: '3분 점수표 →' },
      { href: game('/popcorn-glory/about.html'), label: '정보·개인정보·라이선스 →' },
      { href: `${BLOB}/design/SLICE.md`, label: '가게 설계 (GitHub) →' },
      { href: `${BLOB}/experiments/RESULTS.md`, label: '실험 비교와 결정 (GitHub) →' },
      { href: `${BLOB}/qa/READINESS.md`, label: '출시 준비도 (GitHub) →' },
      { href: `${BLOB}/RELEASE_CHECKLIST.md`, label: '출시 후보 체크리스트 (GitHub) →' },
      { href: `${BLOB}/design/EXPERIMENTS.md`, label: '세 실험 (GitHub) →' },
      { href: `${BLOB}/design/PLAYTEST.md`, label: '3분 절차·점수표 (GitHub) →' },
      { href: `${BLOB}/FUN_FIRST.md`, label: '10·30·60·180초 기준 (GitHub) →' },
      { href: `${BLOB}/PROGRESS.md`, label: '진행 기록 (GitHub) →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];

export default function Page() {
  return <DocShell brand="Popcorn & Glory" subtitle="팝콘 기계" nav={NAV} home={game('/popcorn-glory/')} />;
}
