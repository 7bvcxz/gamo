// Puts a GAMO_TARGET=pages export into docs/, beside the games.
//
// Two hosts serve this site and they want different builds: Vercel serves it at
// the root, GitHub Pages under /gamo/. `npm run build` makes the first; this
// script is the second half of `build:pages`.
//
// It replaces only the site's own files. docs/ also holds three Godot exports of
// 150MB, and wiping the directory would delete them -- the same trap the old
// Vite config carried a comment about, now in a different shape.
import { cp, readdir, rm, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const web = dirname(dirname(fileURLToPath(import.meta.url)));
const out = join(web, 'out');
const docs = join(dirname(web), 'docs');

// Everything at the top of docs/ that the site does not own. Anything not in
// here is replaced wholesale by the export.
//
// Derived rather than listed, because a hand-kept list has now eaten three
// directories. sprite-ref held the generation references and went on the first
// run. engine/ holds the 38MB runtime every game loads and went on every run
// after it was created, which left four games unable to start. gunslinger was
// added as a game and never added to the list, so its build went too. Each time
// the deletion was committed without being noticed, because a site build that
// removes something unrelated looks exactly like one that worked.
//
// A game is a top-level directory with a project.godot, which is the same thing
// deploy-web.sh means by a game, so the two cannot disagree. Only `engine` is
// named, and only because it is the one thing here that is neither a game nor
// site output.
const repo = dirname(web);
const games = (await readdir(repo, { withFileTypes: true }))
  .filter((entry) => entry.isDirectory() && existsSync(join(repo, entry.name, 'project.godot')))
  .map((entry) => entry.name);
const KEEP = new Set([...games, 'engine']);

if (!existsSync(out)) {
  console.error('to-docs: no out/ -- run with GAMO_TARGET=pages first');
  process.exit(1);
}

// Site pages live *inside* the game directories -- /motorio/doc/ is a
// page from web/, /motorio/ is a Godot build -- so skipping a game
// wholesale would leave stale site bundles under it forever. What gets removed
// is derived from the export itself: whatever the site publishes under a game's
// path is replaced, and everything else there belongs to the game and is left.
for (const name of await readdir(docs)) {
  if (name === '.nojekyll') continue;
  if (!KEEP.has(name)) {
    await rm(join(docs, name), { recursive: true, force: true });
    continue;
  }
  if (!existsSync(join(out, name))) continue;
  for (const owned of await readdir(join(out, name))) {
    await rm(join(docs, name, owned), { recursive: true, force: true });
  }
}
await cp(out, docs, { recursive: true });

const count = async (dir) => {
  let n = 0;
  for (const entry of await readdir(dir, { withFileTypes: true, recursive: true })) {
    if (entry.isFile()) n += 1;
  }
  return n;
};
console.log(`to-docs: ${await count(out)} files -> docs/ (kept: ${[...KEEP].join(', ')})`);
