import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { WhatIsGamo } from './pages/WhatIsGamo.jsx';
import { MotorioLevelDesign } from './pages/MotorioLevelDesign.jsx';
import { MotorioKeyFactor } from './pages/MotorioKeyFactor.jsx';
import { OneShotLevelDesign } from './pages/OneShotLevelDesign.jsx';
import { OneShotKeyFactor } from './pages/OneShotKeyFactor.jsx';
import { OneShotTodo } from './pages/OneShotTodo.jsx';
import { OneShotReleases } from './pages/OneShotReleases.jsx';

// The sidebar is data-driven: adding a page is one entry plus one component.
const NAV = [
  {
    group: 'START',
    items: [{ id: 'what-is-gamo', label: 'What is Gamo?', render: () => <WhatIsGamo /> }],
  },
  {
    group: 'MOTORIO',
    items: [
      { id: 'motorio-level-design', label: 'Level Design', render: () => <MotorioLevelDesign /> },
      { id: 'motorio-key-factor', label: 'Key Factor', render: () => <MotorioKeyFactor /> },
    ],
  },
  {
    group: 'MOTORIO: ONE SHOT',
    items: [
      { id: 'oneshot-level-design', label: 'Level Design', render: () => <OneShotLevelDesign /> },
      { id: 'oneshot-key-factor', label: 'Key Factor', render: () => <OneShotKeyFactor /> },
      { id: 'oneshot-todo', label: 'Todo', render: () => <OneShotTodo /> },
      { id: 'oneshot-releases', label: 'Releases', render: () => <OneShotReleases /> },
    ],
    links: [
      { href: '/gamo/motorio-oneshot/graphic/', label: '그래픽 →' },
      { href: '/gamo/motorio-oneshot/graphic/proposals/', label: '그래픽 제안 →' },
      { href: '/gamo/motorio-oneshot/', label: '플레이 →' },
    ],
  },
];

const ALL = NAV.flatMap((section) => section.items);

function Doc() {
  const initial = ALL.some((i) => i.id === window.location.hash.slice(1))
    ? window.location.hash.slice(1)
    : ALL[0].id;
  const [current, setCurrent] = useState(initial);
  const page = ALL.find((i) => i.id === current) ?? ALL[0];

  const go = (id) => {
    setCurrent(id);
    window.location.hash = id;
    window.scrollTo({ top: 0 });
  };

  return (
    <div className="shell">
      <nav className="sidebar">
        <p className="brand">
          gamo <span>docs</span>
        </p>
        {NAV.map((section) => (
          <div className="group" key={section.group}>
            <p className="group-title">{section.group}</p>
            {section.items.map((item) => (
              <button
                key={item.id}
                className="nav-item"
                aria-current={item.id === current}
                onClick={() => go(item.id)}
              >
                {item.label}
              </button>
            ))}
            {(section.links ?? []).map((link) => (
              <a className="nav-item" key={link.href} href={link.href}>
                {link.label}
              </a>
            ))}
          </div>
        ))}
        <div className="group">
          <p className="group-title">LINKS</p>
          <a className="nav-item" href="/gamo/">
            게임 목록 →
          </a>
          <a className="nav-item" href="https://github.com/7bvcxz/gamo">
            GitHub →
          </a>
        </div>
      </nav>
      <main className="main">
        <article className="content">{page.render()}</article>
      </main>
    </div>
  );
}

createRoot(document.getElementById('root')).render(<Doc />);
