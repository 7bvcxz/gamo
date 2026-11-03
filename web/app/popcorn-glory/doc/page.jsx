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
      { href: game('/popcorn-glory/'), label: '플레이 →' },
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
