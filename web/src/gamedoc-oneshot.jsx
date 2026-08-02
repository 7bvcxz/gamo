import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { DocShell } from './DocShell.jsx';
import { Identity } from './pages/oneshot/Identity.jsx';
import { Economy } from './pages/oneshot/Economy.jsx';
import { Automation } from './pages/oneshot/Automation.jsx';
import { OneShotLevelDesign } from './pages/OneShotLevelDesign.jsx';
import { OneShotTodo } from './pages/OneShotTodo.jsx';
import { OneShotReleases } from './pages/OneShotReleases.jsx';

// One Shot's own documentation, independent of every other game's. Split by how
// often each part changes: identity almost never, level design when the map
// moves, balance constantly -- and balance is generated rather than written.
const NAV = [
  {
    group: '설계',
    items: [
      { id: 'identity', label: '정체성', render: () => <Identity /> },
      { id: 'level-design', label: '레벨 디자인', render: () => <OneShotLevelDesign /> },
      { id: 'automation', label: '자동화 설계', render: () => <Automation /> },
    ],
  },
  {
    group: '수치',
    items: [{ id: 'economy', label: '경제 · 밸런스', render: () => <Economy /> }],
  },
  {
    group: '진행',
    items: [
      { id: 'todo', label: 'Todo', render: () => <OneShotTodo /> },
      { id: 'releases', label: 'Releases', render: () => <OneShotReleases /> },
    ],
  },
  {
    group: '그래픽',
    links: [
      { href: '/gamo/motorio-oneshot/graphic/', label: '오브젝트 갤러리 →' },
      { href: '/gamo/motorio-oneshot/graphic/proposals/', label: '그래픽 제안 →' },
    ],
  },
  {
    group: '링크',
    links: [
      { href: '/gamo/motorio-oneshot/', label: '플레이 →' },
      { href: '/gamo/doc/', label: '저장소 문서 →' },
      { href: '/gamo/', label: '게임 목록 →' },
    ],
  },
];

createRoot(document.getElementById('root')).render(
  <DocShell brand="One Shot" subtitle="문서" nav={NAV} home="/gamo/motorio-oneshot/" />
);
