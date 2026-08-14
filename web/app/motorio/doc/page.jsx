'use client';

import { game, site } from '../../../lib/links.js';
import React from 'react';
import { DocShell } from '../../../components/DocShell.jsx';
import { Identity } from '../../../components/content/motorio/Identity.jsx';
import { Economy } from '../../../components/content/motorio/Economy.jsx';
import { Automation } from '../../../components/content/motorio/Automation.jsx';
import { DevTools } from '../../../components/content/motorio/DevTools.jsx';
import { MotorioLevelDesign } from '../../../components/content/MotorioLevelDesign.jsx';
import { MotorioTodo } from '../../../components/content/MotorioTodo.jsx';
import { MotorioReleases } from '../../../components/content/MotorioReleases.jsx';
import { DesignDoc } from '../../../components/content/motorio/DesignDoc.jsx';
import design from '../../../lib/generated/design.json';

// Motorio's own documentation, independent of every other game's. Split by how
// often each part changes: identity almost never, level design when the map
// moves, balance constantly -- and balance is generated rather than written.
//
// The nav is in English while the pages themselves are in Korean. Deliberate:
// these are short category labels sitting next to Todo, Releases and the item
// ids, and translating half of them produced a sidebar that read as a mix. The
// English words are also the ones the design conversation actually uses.
// The long-range design documents, straight from motorio/design/. Built
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
      { id: 'level-design', label: 'Level Design', render: () => <MotorioLevelDesign /> },
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
      { id: 'todo', label: 'Todo', render: () => <MotorioTodo /> },
      { id: 'releases', label: 'Releases', render: () => <MotorioReleases /> },
    ],
    // A link rather than a rendered panel: the decisions page talks to a server
    // and this shell renders static panels. DocShell takes external links here.
    links: [{ href: site('/motorio/decisions/'), label: 'Decisions →' }],
  },
  {
    group: 'Development',
    items: [{ id: 'devtools', label: 'Debug Tools', render: () => <DevTools /> }],
  },
  {
    group: 'Graphics',
    links: [
      { href: site('/motorio/graphic/'), label: 'Object Gallery →' },
      { href: site('/motorio/graphic/proposals/'), label: 'Graphic Proposals →' },
    ],
  },
  {
    group: 'Links',
    links: [
      { href: game('/motorio/'), label: 'Play →' },
      { href: site('/doc/'), label: 'Repo Docs →' },
      { href: site('/'), label: 'All Games →' },
    ],
  },
];


export default function Page() {
  return <DocShell brand="Motorio" subtitle="Docs" nav={NAV} home={game('/motorio/')} />;
}
