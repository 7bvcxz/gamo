// Where a link points depends on which host is serving the page, so no path in
// this site is written down whole.
//
// The site and the games used to share one origin and every href was a literal
// '/gamo/...'. They are splitting: the site is a few hundred KB and changes many
// times a day, which suits a host that redeploys in seconds, while the games are
// 150MB that cannot go there at all. Two functions rather than one, because that
// split is exactly the distinction between them and one base cannot express it.

const SITE = (process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/$/, '');
const GAMES = process.env.NEXT_PUBLIC_GAME_ORIGIN || SITE;

/** A page built from this repository's web/ sources. */
export const site = (path) => `${SITE}${path}`;

/** A Godot build. May live on a different origin than the page linking to it. */
export const game = (path) => `${GAMES}${path}`;
