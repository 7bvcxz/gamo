'use client';

import { site } from '../../lib/links.js';
import React from 'react';
import { DocShell } from '../../components/DocShell.jsx';
import { WhatIsGamo } from '../../components/content/WhatIsGamo.jsx';
import { SatisfactoryLevelDesign } from '../../components/content/SatisfactoryLevelDesign.jsx';

// Repository-level documentation only. Each game's design docs now live under
// its own path -- /gamo/<game>/doc/ -- so a game can restructure its
// documentation without touching anyone else's, which is the whole point of
// splitting them.
const NAV = [
  {
    group: 'START',
    items: [{ id: 'what-is-gamo', label: 'What is Gamo?', render: () => <WhatIsGamo /> }],
  },
  {
    group: 'REFERENCE',
    items: [
      {
        id: 'satisfactory-level-design',
        label: 'Satisfactory 레벨 디자인',
        render: () => <SatisfactoryLevelDesign />,
      },
    ],
  },
  {
    group: '게임별 문서',
    links: [
      { href: site('/motorio-oneshot/doc/'), label: 'Motorio: One Shot →' },
      { href: site('/motorio/doc/'), label: 'Motorio →' },
      { href: site('/gunslinger/doc/'), label: 'Gunslinger →' },
      { href: site('/looproom/doc/'), label: 'looproom →' },
    ],
  },
  {
    group: 'LINKS',
    links: [
      { href: site('/'), label: '게임 목록 →' },
      { href: 'https://github.com/7bvcxz/gamo', label: 'GitHub →' },
    ],
  },
];


export default function Page() {
  return <DocShell brand="gamo" subtitle="docs" nav={NAV} />;
}
