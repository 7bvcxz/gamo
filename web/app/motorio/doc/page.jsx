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
import { Timeline } from '../../../components/content/motorio/Timeline.jsx';
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
//
// Two kinds of file live in that folder and they are read for different
// reasons: what the game is meant to be (Vision), and what a piece of work did
// (a report, and the overview of all of them). The reports sit under Progress,
// next to Todo and Releases, because that is the question they answer. Which is
// which is read off the file name -- a report says so in its name -- so a new
// report lands in the right group without this page being edited.
const isReport = (doc) => /REPORT|_PASS_|AUDIT/.test(doc.file);
const asItem = (doc) => ({
  id: `design-${doc.id}`,
  label: doc.label,
  render: () => <DesignDoc id={doc.id} />,
});
const DOCS = (design.docs || []).filter((doc) => doc.file !== 'entity-scenes.md');
const OVERVIEW = DOCS.find((doc) => doc.file === 'PROGRESS.md');
const VISION = {
  group: 'Vision',
  items: DOCS.filter((doc) => doc.file !== 'PROGRESS.md' && !isReport(doc)).map(asItem),
};
const REPORTS = {
  group: 'Reports',
  items: DOCS.filter(isReport).map(asItem),
};

const NAV = [
  // First, because v0.1 is defined as "this timeline runs end to end" and every
  // other page on this site is a detail of one of its bands. It draws the table
  // out of VERTICAL_SLICE.md rather than holding one of its own.
  //
  // Ahead of it since 2026-09-29, the overview: where the game is now, in one
  // page with its diagrams and pictures (motorio/design/PROGRESS.md). The page
  // opens on the first item, and "where are we" is the first question.
  {
    group: 'Plan',
    items: [
      ...(OVERVIEW ? [asItem(OVERVIEW)] : []),
      { id: 'timeline', label: 'Timeline', render: () => <Timeline /> },
    ],
  },
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
  REPORTS,
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
