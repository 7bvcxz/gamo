// What at the top of docs/ belongs to a Godot export rather than to the site,
// derived from the repository (see to-docs.mjs for why it is never a list).
//
// A game is a top-level directory with a project.godot -- what deploy-web.sh
// calls a game. A project nested one level inside a game is that game's side
// project and publishes to docs/<game>-<folder>/: momonium/experiments/ (the
// Fun Lab, Step 86) is docs/momonium-experiments/, the folder its own
// tools/deploy.sh writes. `engine` is the one shared runtime every game loads.
import { readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';

export function keptDirs(repo) {
  const dirs = (path) => readdirSync(path, { withFileTypes: true }).filter((e) => e.isDirectory() && !e.name.startsWith('.'));
  const games = dirs(repo).filter((e) => existsSync(join(repo, e.name, 'project.godot'))).map((e) => e.name);
  const nested = games.flatMap((game) => dirs(join(repo, game))
    .filter((e) => existsSync(join(repo, game, e.name, 'project.godot')))
    .map((e) => `${game}-${e.name}`));
  return new Set([...games, ...nested, 'engine']);
}
