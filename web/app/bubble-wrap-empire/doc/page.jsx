'use client';

import React from 'react';
import { game, site } from '../../../lib/links.js';
import { DocShell } from '../../../components/DocShell.jsx';
import { BubbleWrapEmpirePoc } from '../../../components/content/BubbleWrapEmpirePoc.jsx';

const NAV = [
  {
    group: 'POC',
    items: [{ id: 'poc', label: '무엇을 확인하나', render: () => <BubbleWrapEmpirePoc /> }],
  },
  {
    group: '링크',
    links: [
      { href: game('/bubble-wrap-empire/'), label: '플레이 →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];

export default function Page() {
  return <DocShell brand="Bubble Wrap Empire" subtitle="POC" nav={NAV} home={game('/bubble-wrap-empire/')} />;
}
