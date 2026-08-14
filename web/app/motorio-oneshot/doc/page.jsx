'use client';

import { game, site } from '../../../lib/links.js';
import React from 'react';
import { DocShell } from '../../../components/DocShell.jsx';
import { Identity } from '../../../components/content/oneshot/Identity.jsx';
import { Economy } from '../../../components/content/oneshot/Economy.jsx';
import { Automation } from '../../../components/content/oneshot/Automation.jsx';
import { DevTools } from '../../../components/content/oneshot/DevTools.jsx';
import { OneShotLevelDesign } from '../../../components/content/OneShotLevelDesign.jsx';
import { OneShotTodo } from '../../../components/content/OneShotTodo.jsx';
import { OneShotReleases } from '../../../components/content/OneShotReleases.jsx';
import { DesignDoc } from '../../../components/content/oneshot/DesignDoc.jsx';
import design from '../../../lib/generated/design.json';

// One Shot's own documentation, independent of every other game's. Split by how
// often each part changes: identity almost never, level design when the map
// moves, balance constantly -- and balance is generated rather than written.
//
// The nav is in English while the pages themselves are in Korean. Deliberate:
// these are short category labels sitting next to Todo, Releases and the item
// ids, and translating half of them produced a sidebar that read as a mix. The
// English words are also the ones the design conversation actually uses.
// The long-range design documents, straight from motorio-oneshot/design/. Built
// from the manifest rather than listed here: a file added to that folder appears
// on the site without this page being edited, which is the only arrangement that
// does not eventually disagree with the folder.
//
// Above everything else on purpose. These are the standard the rest of the page
// is measured against -- what the game is for comes before what it currently
// does.
const VISION = {
  group: 'Vision',
  items: (design.docs || [])
    .filter((doc) => doc.file !== 'entity-scenes.md')
    .map((doc) => ({
      id: `design-${doc.id}`,
      label: doc.label,
      render: () => <DesignDoc id={doc.id} />,
    })),
};

const NAV = [
  VISION,
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
    // A link rather than a rendered panel: the decisions page talks to a server
    // and this shell renders static panels. DocShell takes external links here.
    links: [{ href: site('/motorio-oneshot/decisions/'), label: 'Decisions →' }],
  },
  {
    group: 'Development',
    items: [{ id: 'devtools', label: 'Debug Tools', render: () => <DevTools /> }],
  },
  {
    group: 'Graphics',
    links: [
      { href: site('/motorio-oneshot/graphic/'), label: 'Object Gallery →' },
      { href: site('/motorio-oneshot/graphic/proposals/'), label: 'Graphic Proposals →' },
    ],
  },
  {
    group: 'Links',
    links: [
      { href: game('/motorio-oneshot/'), label: 'Play →' },
      { href: site('/doc/'), label: 'Repo Docs →' },
      { href: site('/'), label: 'All Games →' },
    ],
  },
];


export default function Page() {
  return <DocShell brand="One Shot" subtitle="Docs" nav={NAV} home={game('/motorio-oneshot/')} />;
}
