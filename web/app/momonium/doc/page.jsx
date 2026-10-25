'use client';

import React from 'react';
import { game, site } from '../../../lib/links.js';
import { DocShell } from '../../../components/DocShell.jsx';
import { MomoniumDoc } from '../../../components/content/MomoniumDoc.jsx';

// Momonium is built in numbered steps tracked as GitHub issues. This page holds
// what does not change from step to step -- the premise and the rules the steps
// share -- and links to the issues and the in-repository progress record for
// everything that does, so nothing here has to be rewritten every deploy.
const ISSUES = 'https://github.com/7bvcxz/gamo/issues?q=is%3Aissue+momonium-step';
const PROGRESS = 'https://github.com/7bvcxz/gamo/blob/main/momonium/PROGRESS.md';

const NAV = [
  {
    group: 'Momonium',
    items: [{ id: 'about', label: '어떤 게임인가', render: () => <MomoniumDoc /> }],
  },
  {
    group: '링크',
    links: [
      { href: game('/momonium/'), label: '플레이 →' },
      { href: ISSUES, label: '개발 단계 (Issues) →' },
      { href: PROGRESS, label: '진행 기록 →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];

export default function Page() {
  return <DocShell brand="Momonium" subtitle="섬 경영" nav={NAV} home={game('/momonium/')} />;
}
