import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { DocShell } from './DocShell.jsx';
import { MotorioLevelDesign } from './pages/MotorioLevelDesign.jsx';
import { MotorioKeyFactor } from './pages/MotorioKeyFactor.jsx';

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
      { href: '/gamo/motorio/', label: '플레이 →' },
      { href: '/gamo/doc/', label: '저장소 문서 →' },
      { href: '/gamo/', label: '게임 목록 →' },
    ],
  },
];

createRoot(document.getElementById('root')).render(
  <DocShell brand="Motorio" subtitle="문서" nav={NAV} home="/gamo/motorio/" />
);
