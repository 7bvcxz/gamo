'use client';

import React from 'react';
import { game, site } from '../../../lib/links.js';
import { DocShell } from '../../../components/DocShell.jsx';
import { GunslingerPoc } from '../../../components/content/GunslingerPoc.jsx';

// A proof of concept gets a documentation page like anything else here, because
// the question it exists to answer is worth writing down where someone can read
// it before playing -- and because the answer, when it arrives, belongs beside
// the question rather than in a chat log.
const NAV = [
  {
    group: 'POC',
    items: [{ id: 'poc', label: '무엇을 확인하나', render: () => <GunslingerPoc /> }],
  },
  {
    group: '링크',
    links: [
      { href: game('/gunslinger/'), label: '플레이 →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];

export default function Page() {
  return <DocShell brand="Gunslinger" subtitle="POC" nav={NAV} home={game('/gunslinger/')} />;
}
