# gamo web

The repository's site: landing, docs, object gallery, graphic proposals. Next.js
App Router, static export, no server code — there is not one `fetch` or `/api`
call in it.

```sh
npm run dev           # local
npm run build         # Vercel shape: base /, games linked absolutely
npm run build:pages   # GitHub Pages shape: base /gamo, copied into ../docs/
```

## Two hosts, and why

The site and the games are deployed separately, and the split is by size and
rate of change rather than by kind.

| | where | why |
|---|---|---|
| site | Vercel | a few hundred KB, changes many times a day, wants seconds |
| games | GitHub Pages | 150MB of wasm and packs, changes rarely |

The games cannot go on Vercel: `docs/` is 161MB against a 100MB static upload
limit on Hobby, and a cold game load pulls ~12MB, which would meter against the
100GB monthly transfer allowance at roughly 8,300 loads.

Because of the split, no path is written down whole. `lib/links.js` exports two
functions and they return different values per target:

- `site('/doc/')` — a page built from this directory
- `game('/motorio-oneshot/')` — a Godot build, possibly on another origin

## vercel.json

The schema sets `additionalProperties: false`, so the file cannot carry comments
— not even `//`-prefixed keys, which Vercel rejects with *"should NOT have
additional property"*. The reasoning lives here instead.

**`ignoreCommand: git diff --quiet HEAD^ HEAD ./`** — most commits to this
repository are game work. A Godot export rewrites 18MB of pack and never touches
`web/`, and without this each one would spend one of Hobby's 100 daily
deployments rebuilding an unchanged site. The command runs from the Root
Directory, so `./` is `web/`, and everything the site is built from is inside it:
pages, components, the generated balance and sprite JSON, and the candidate
sheets in `public/`. Exit 0 ignores the build, exit 1 continues it, and
`git diff --quiet` exits 0 when nothing changed.

**`redirects`, temporary rather than permanent** — the games are not deployed
here, so a guessed URL is sent to the host that has them. A 308 would be cached
by browsers and would outlive the decision about where the games live.

**`regions: ["icn1"]`** — matches heydive-client.

## Vercel project settings

Only one field differs from the defaults:

- **Root Directory: `web`**

Framework preset is detected as Next.js. No environment variables: leaving
`GAMO_TARGET` unset is what selects the Vercel shape.

## Layout

```
app/         routes; each page.jsx is a client component
components/  DocShell, graphics/ (canvas), content/ (the doc pages)
lib/         links.js, generated/{balance,sprites}.json
public/      deploy.html, sprite-candidates/
scripts/     to-docs.mjs — puts a pages-shaped export into ../docs/
```

`lib/generated/` is written by tools in the game project —
`tools/dump_balance.gd` and `tools/sprite/sprite_tool.py`. Those files are
generated, never hand-edited, and AGENTS.md requires regenerating them in the
same commit as the change they describe.

`scripts/to-docs.mjs` replaces the site's files in `docs/` and must leave the
three game directories alone — except for the site pages that live *inside*
them, like `/motorio-oneshot/doc/`. What it removes is derived from the export
itself rather than from a list, so a page moving or disappearing cannot strand a
stale copy.
