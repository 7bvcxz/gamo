// Static export, deliberately. Nothing in this site calls a server -- there is
// not one fetch or /api in it -- so an export is the honest build: the same
// files work on Vercel, on GitHub Pages and on the nginx in deploy/, and none of
// them needs a runtime. Choosing SSR here would buy nothing and would tie the
// site to one host.
//
// Two targets, because the games and the site are splitting hosts. The games are
// 150MB of wasm and pack binaries, which exceeds Vercel's 100MB static upload
// limit on Hobby and would meter ~12MB against its transfer quota on every cold
// load, so they stay on GitHub Pages under /gamo/ while the site moves to a host
// that serves it at the root.
const pages = process.env.GAMO_TARGET === 'pages';

const nextConfig = {
  output: 'export',
  // Pages serves this repository under a project path; Vercel serves it at the
  // root. Everything downstream reads this rather than writing a path down.
  basePath: pages ? '/gamo' : '',
  // Trailing slashes so an exported directory answers at the URL people already
  // have -- /doc/ rather than /doc.html.
  trailingSlash: true,
  images: { unoptimized: true },
  env: {
    // basePath is passed through explicitly because Next only applies it to
    // <Link> and next/image. Every link in this site is a plain <a>, which Next
    // leaves alone, so lib/links.js has to add the prefix itself.
    NEXT_PUBLIC_BASE_PATH: pages ? '/gamo' : '',
    // Absolute when the games are on another origin, empty when they sit beside
    // the site. lib/links.js is the only thing that reads it.
    NEXT_PUBLIC_GAME_ORIGIN: pages ? '' : 'https://7bvcxz.github.io/gamo',
  },
};

export default nextConfig;
