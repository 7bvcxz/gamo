import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { DocShell } from './DocShell.jsx';
import { WhatIsGamo } from './pages/WhatIsGamo.jsx';
import { SatisfactoryLevelDesign } from './pages/SatisfactoryLevelDesign.jsx';

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
      { href: '/gamo/motorio-oneshot/doc/', label: 'Motorio: One Shot →' },
      { href: '/gamo/motorio/doc/', label: 'Motorio →' },
    ],
  },
  {
    group: 'LINKS',
    links: [
      { href: '/gamo/', label: '게임 목록 →' },
      { href: 'https://github.com/7bvcxz/gamo', label: 'GitHub →' },
    ],
  },
];

createRoot(document.getElementById('root')).render(
  <DocShell brand="gamo" subtitle="docs" nav={NAV} />
);
