import React, { useState } from 'react';

// The documentation layout, shared by every doc site in the repo: the top-level
// one and one per game. Each caller supplies its own nav, so the games get
// independent structures without three copies of a sidebar drifting apart.
//
// `nav` is a list of { group, items: [{ id, label, render }], links: [{ href, label }] }.

export function DocShell({ brand, subtitle, nav, home }) {
  const all = nav.flatMap((section) => section.items ?? []);
  const initial = all.some((item) => item.id === window.location.hash.slice(1))
    ? window.location.hash.slice(1)
    : all[0]?.id;
  const [current, setCurrent] = useState(initial);
  const page = all.find((item) => item.id === current) ?? all[0];

  const go = (id) => {
    setCurrent(id);
    window.location.hash = id;
    window.scrollTo({ top: 0 });
  };

  return (
    <div className="shell">
      <nav className="sidebar">
        <p className="brand">
          <a href={home ?? '/gamo/'}>{brand}</a> <span>{subtitle}</span>
        </p>
        {nav.map((section) => (
          <div className="group" key={section.group}>
            <p className="group-title">{section.group}</p>
            {(section.items ?? []).map((item) => (
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
      </nav>
      <main className="main">
        <article className="content">{page ? page.render() : null}</article>
      </main>
    </div>
  );
}
