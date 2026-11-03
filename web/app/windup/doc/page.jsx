'use client';

import React from 'react';
import { game, site } from '../../../lib/links.js';
import { DocShell } from '../../../components/DocShell.jsx';
import { WindupDoc } from '../../../components/content/WindupDoc.jsx';

// Windup is a prototype looking for a fun core, so its page says what it is
// trying to find out and what the answer is so far. The design itself stays in
// windup/design/*.md and is linked, not copied: a copy here would go stale.
const NAV = [
  {
    group: '태엽 공방',
    items: [{ id: 'question', label: '무엇을 확인하나', render: () => <WindupDoc /> }],
  },
  {
    group: '링크',
    links: [
      { href: game('/windup/'), label: '플레이 →' },
      { href: 'https://github.com/7bvcxz/gamo/blob/main/windup/design/CORE_LOOP.md', label: '핵심 루프 (GitHub) →' },
      { href: 'https://github.com/7bvcxz/gamo/blob/main/windup/design/PLAYTEST_3MIN.md', label: '3분 측정 (GitHub) →' },
      { href: 'https://github.com/7bvcxz/gamo/blob/main/windup/PROGRESS.md', label: '진행 기록 (GitHub) →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];

export default function Page() {
  return <DocShell brand="Windup" subtitle="태엽 공방" nav={NAV} home={game('/windup/')} />;
}
