// The design documents, from the repository into the site, as data.
//
// They live in motorio/design/ as markdown and that is the only place
// they are written. Retyping them into JSX would create a second copy, and the
// second copy is always the one that goes stale -- this repository has watched a
// level-design page quote a belt speed that had been ten times different for
// three versions, and has a standing rule because of it: numbers and documents
// are generated, never transcribed.
//
// Run from the build, not by hand, for the same reason. A generated file that
// someone has to remember to regenerate is a hand-written file with extra steps.
//
//     node scripts/design-to-json.mjs
//
// Writes web/lib/generated/design.json.
import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, '..', '..');
const SOURCE = join(REPO, 'motorio', 'design');
const OUT = join(REPO, 'web', 'lib', 'generated', 'design.json');

// The order they are meant to be read in, which is not alphabetical: vision
// first because everything else answers to it, current state last because it is
// the only one that changes every week. Anything not listed still appears, after
// these -- a hand-kept list that silently drops a file is the failure this
// ordering is trying to avoid, not one to import.
const ORDER = [
  'VISION.md',
  'CORE_LOOP.md',
  'PROGRESSION.md',
  'WORLD_AND_STORY.md',
  'VERTICAL_SLICE.md',
  'CURRENT_STATE.md',
];

const LABEL = {
  'VISION.md': 'Vision',
  'CORE_LOOP.md': 'Core Loop',
  'PROGRESSION.md': 'Progression',
  'WORLD_AND_STORY.md': 'World & Story',
  'VERTICAL_SLICE.md': 'Vertical Slice',
  'CURRENT_STATE.md': 'Current State',
  'entity-scenes.md': 'Entity Scenes',
};

const files = readdirSync(SOURCE).filter((name) => name.endsWith('.md'));
const rank = (name) => {
  const index = ORDER.indexOf(name);
  return index < 0 ? ORDER.length : index;
};
files.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b));

const docs = files.map((name) => {
  const body = readFileSync(join(SOURCE, name), 'utf8');
  // The first heading is the title and the "상태:" line under it is the status.
  // Read out of the document rather than listed here, so a document that changes
  // its own status does not need this script edited to say so.
  const title = (body.match(/^#\s+(.+)$/m) || [, name])[1].trim();
  const status = (body.match(/^상태:\s*`?(\[[^\]]+\])`?/m) || [, ''])[1];
  return {
    id: name.replace(/\.md$/, '').toLowerCase().replace(/_/g, '-'),
    file: name,
    label: LABEL[name] || name.replace(/\.md$/, ''),
    title,
    status,
    body,
  };
});

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify({ docs }, null, 1) + '\n');
console.log(`design: ${docs.length} docs -> web/lib/generated/design.json`);
