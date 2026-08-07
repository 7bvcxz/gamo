'use client';

import { game, site } from '../../../lib/links.js';
import React from 'react';
import { DocShell } from '../../../components/DocShell.jsx';
import { MotorioLevelDesign } from '../../../components/content/MotorioLevelDesign.jsx';
import { MotorioKeyFactor } from '../../../components/content/MotorioKeyFactor.jsx';

// Motorio's documentation. The game itself is the earlier, longer-form version
// that One Shot was cut down from, and its design notes live in motorio/design/
// as markdown as well.
const NAV = [
  {
    group: '설계',
    items: [
      { id: 'level-design', label: '레벨 디자인', render: () => <MotorioLevelDesign /> },
      { id: 'key-factor', label: 'Key Factor', render: () => <MotorioKeyFactor /> },
    ],
  },
  {
    group: '링크',
    links: [
      { href: game('/motorio/'), label: '플레이 →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];


export default function Page() {
  return <DocShell brand="Motorio" subtitle="문서" nav={NAV} home={game('/motorio/')} />;
}
