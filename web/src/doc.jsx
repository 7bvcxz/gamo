import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import { WhatIsGamo } from './pages/WhatIsGamo.jsx';

// The sidebar is data-driven so adding a page is one entry plus one component.
// Only one page exists today by design; the grouping is already in place so the
// structure does not need rewriting when the second one lands.
const NAV = [
  {
    group: 'START',
    items: [{ id: 'what-is-gamo', label: 'What is Gamo?', render: () => <WhatIsGamo /> }],
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
