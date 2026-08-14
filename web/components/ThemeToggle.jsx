'use client';

import React, { useEffect, useState } from 'react';

// Light or dark, chosen rather than inherited.
//
// The palette already had both, switched by prefers-color-scheme, so the site
// looked different depending on whose laptop it was and there was no way to say
// otherwise. Light is the default now and the OS is not consulted: a page whose
// background depends on a setting the reader cannot see from here is a page that
// cannot be described.
//
// The choice is stored and applied before first paint by the script in the
// layout, so a dark reader does not get a white flash on every navigation. This
// component only draws the button and keeps it in step.

const KEY = 'gamo.theme';

export function ThemeToggle() {
  // Undefined until the browser has been asked. Rendering an icon before that
  // would be rendering a guess, and the guess is wrong half the time -- which on
  // a prerendered page is a hydration mismatch rather than a cosmetic slip.
  const [theme, setTheme] = useState(null);

  useEffect(() => {
    const current = document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
    setTheme(current);
  }, []);

  const flip = () => {
    const next = theme === 'dark' ? 'light' : 'dark';
    setTheme(next);
    document.documentElement.dataset.theme = next;
    try {
      localStorage.setItem(KEY, next);
    } catch {
      // Private browsing, or storage disabled. The page still switches; it just
      // will not remember, which is better than refusing to switch.
    }
  };

  const dark = theme === 'dark';
  return (
    <button
      type="button"
      className="theme-toggle"
      onClick={flip}
      // Empty until mounted, so the server and the first client render agree.
      aria-label={theme ? (dark ? '라이트 모드로' : '다크 모드로') : '테마 전환'}
      title={theme ? (dark ? '라이트 모드로' : '다크 모드로') : '테마 전환'}
    >
      {theme === null ? null : dark ? <Moon /> : <Sun />}
    </button>
  );
}

// Drawn rather than fetched: two glyphs at 18px do not justify a font or a
// sprite, and an inline SVG inherits the text colour for free.
function Sun() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <circle cx="12" cy="12" r="4.4" fill="currentColor" />
      {[0, 45, 90, 135, 180, 225, 270, 315].map((angle) => (
        <line
          key={angle}
          x1="12"
          y1="2.6"
          x2="12"
          y2="5.4"
          stroke="currentColor"
          strokeWidth="1.9"
          strokeLinecap="round"
          transform={`rotate(${angle} 12 12)`}
        />
      ))}
    </svg>
  );
}

function Moon() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      {/* A crescent as one path: a disc with a second disc taken out of it, so
          it stays a moon at any size instead of two overlapping circles that
          only line up at one. */}
      <path
        d="M20.2 14.2A8.6 8.6 0 0 1 9.8 3.8a8.6 8.6 0 1 0 10.4 10.4Z"
        fill="currentColor"
      />
    </svg>
  );
}

export default ThemeToggle;
