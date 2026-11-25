'use client';

import React from 'react';
import { game, site } from '../../../lib/links.js';
import { DocShell } from '../../../components/DocShell.jsx';
import { SnowballRelayPoc } from '../../../components/content/SnowballRelayPoc.jsx';

const NAV = [
  {
    group: 'POC',
    items: [{ id: 'poc', label: '무엇을 확인하나', render: () => <SnowballRelayPoc /> }],
  },
  {
    group: '링크',
    links: [
      { href: game('/snowball-relay/'), label: '플레이 →' },
      { href: site('/doc/'), label: '저장소 문서 →' },
      { href: site('/'), label: '게임 목록 →' },
    ],
  },
];

export default function Page() {
  return <DocShell brand="Snowball Relay" subtitle="POC" nav={NAV} home={game('/snowball-relay/')} />;
}
