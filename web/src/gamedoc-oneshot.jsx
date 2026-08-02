import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { DocShell } from './DocShell.jsx';
import { Identity } from './pages/oneshot/Identity.jsx';
import { Economy } from './pages/oneshot/Economy.jsx';
import { Automation } from './pages/oneshot/Automation.jsx';
import { DevTools } from './pages/oneshot/DevTools.jsx';
import { OneShotLevelDesign } from './pages/OneShotLevelDesign.jsx';
import { OneShotTodo } from './pages/OneShotTodo.jsx';
import { OneShotReleases } from './pages/OneShotReleases.jsx';

// One Shot's own documentation, independent of every other game's. Split by how
// often each part changes: identity almost never, level design when the map
// moves, balance constantly -- and balance is generated rather than written.
//
// The nav is in English while the pages themselves are in Korean. Deliberate:
// these are short category labels sitting next to Todo, Releases and the item
// ids, and translating half of them produced a sidebar that read as a mix. The
// English words are also the ones the design conversation actually uses.
const NAV = [
  {
    group: 'Design',
    items: [
      { id: 'identity', label: 'Identity', render: () => <Identity /> },
      { id: 'level-design', label: 'Level Design', render: () => <OneShotLevelDesign /> },
      { id: 'automation', label: 'Automation', render: () => <Automation /> },
    ],
  },
  {
    group: 'Numbers',
    items: [{ id: 'economy', label: 'Economy & Balance', render: () => <Economy /> }],
  },
  {
    group: 'Progress',
    items: [
      { id: 'todo', label: 'Todo', render: () => <OneShotTodo /> },
      { id: 'releases', label: 'Releases', render: () => <OneShotReleases /> },
    ],
  },
  {
    group: 'Development',
    items: [{ id: 'devtools', label: 'Debug Tools', render: () => <DevTools /> }],
  },
  {
    group: 'Graphics',
    links: [
      { href: '/gamo/motorio-oneshot/graphic/', label: 'Object Gallery →' },
      { href: '/gamo/motorio-oneshot/graphic/proposals/', label: 'Graphic Proposals →' },
    ],
  },
  {
    group: 'Links',
    links: [
      { href: '/gamo/motorio-oneshot/', label: 'Play →' },
      { href: '/gamo/doc/', label: 'Repo Docs →' },
      { href: '/gamo/', label: 'All Games →' },
    ],
  },
];

createRoot(document.getElementById('root')).render(
  <DocShell brand="One Shot" subtitle="Docs" nav={NAV} home="/gamo/motorio-oneshot/" />
);
