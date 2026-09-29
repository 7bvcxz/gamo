// The ```mermaid blocks in the design documents and the decisions, drawn once
// into pictures the site can show.
//
// The documents are the source: a diagram is written as text next to the prose
// it explains, in motorio/design/*.md or in a decision's body, outcome or
// comment. This renders each block to web/public/diagrams/<key>.png (the key is
// `diagramKey` of the text) and lists them in web/lib/generated/diagrams.json.
// The Markdown component shows the picture when the list has it and the source
// when it does not, so an unrendered block is visible rather than missing.
//
// PNG, not SVG, on purpose. Mermaid lays text out with the fonts of the browser
// it runs in and an SVG is drawn later with the fonts of whoever opens the page;
// with Korean labels the two disagree and the boxes no longer fit the words. A
// picture is what was measured. The Korean font is the repository's own Noto
// CJK, cut down to the characters these diagrams use.
//
// Needs a browser, so it is run by hand like decisions-snapshot, not by the
// build:
//
//     NODE_PATH=<dir with playwright-core, mermaid, subset-font>/node_modules \
//     MERMAID_CHROME=~/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome \
//       node web/scripts/mermaid-render.mjs
import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync, unlinkSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { diagramKey } from '../lib/diagram-key.mjs';

const require = createRequire(import.meta.url);
const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, '..', '..');
const OUT_DIR = join(REPO, 'web', 'public', 'diagrams');
const MANIFEST = join(REPO, 'web', 'lib', 'generated', 'diagrams.json');
const FONT = join(REPO, 'motorio', 'tools', 'NotoSansCJK-Regular.ttc');

function blocks(text) {
  const out = [];
  const lines = String(text || '').split('\n');
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() !== '```mermaid') continue;
    let end = i + 1;
    while (end < lines.length && !lines[end].startsWith('```')) end++;
    out.push(lines.slice(i + 1, end).join('\n'));
    i = end;
  }
  return out;
}

const sources = [];
const designDir = join(REPO, 'motorio', 'design');
for (const name of readdirSync(designDir).filter((n) => n.endsWith('.md'))) {
  sources.push(readFileSync(join(designDir, name), 'utf8'));
}
const decisionsFile = join(REPO, 'web', 'lib', 'generated', 'decisions.json');
if (existsSync(decisionsFile)) {
  const snapshot = JSON.parse(readFileSync(decisionsFile, 'utf8'));
  for (const item of snapshot.items || []) {
    sources.push(item.body, item.outcome);
    for (const comment of item.comments || []) sources.push(comment.body);
  }
}
const all = sources.flatMap(blocks);
const unique = new Map(all.map((code) => [diagramKey(code), code]));

const { chromium } = require('playwright-core');
const subsetFont = require('subset-font');
const chars = [...new Set([...unique.values()].join('') + 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;·→←↑↓-_()[]{}#%+=*/')].join('');
// The source is a collection; the game's own font tool lifts face 0 out of it.
const { faceCount, extractFace } = require(join(REPO, 'motorio', 'tools', 'build_font.cjs'));
const collection = readFileSync(FONT);
const face = faceCount(collection) > 0 ? extractFace(collection, 0) : collection;
const font = await subsetFont(face, chars, { targetFormat: 'woff2' });
const mermaidJs = readFileSync(require.resolve('mermaid/dist/mermaid.min.js'), 'utf8');

mkdirSync(OUT_DIR, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.MERMAID_CHROME || undefined });
const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 1400, height: 900 } });
await page.setContent(`<!doctype html><html><head><meta charset="utf-8"><style>
@font-face { font-family: 'Diagram KR'; src: url(data:font/woff2;base64,${font.toString('base64')}) format('woff2'); }
body { margin: 0; background: #ffffff; font-family: 'Diagram KR', sans-serif; }
#host { display: inline-block; padding: 18px; background: #ffffff; }
</style></head><body><div id="host"></div></body></html>`);
await page.addScriptTag({ content: mermaidJs });
await page.evaluate(async () => {
  await document.fonts.load("16px 'Diagram KR'");
  window.mermaid.initialize({
    startOnLoad: false,
    theme: 'base',
    fontFamily: "'Diagram KR', sans-serif",
    themeVariables: {
      fontFamily: "'Diagram KR', sans-serif",
      fontSize: '15px',
      primaryColor: '#f0e7df', primaryBorderColor: '#b4531f', primaryTextColor: '#1c1b19',
      lineColor: '#6b6862', secondaryColor: '#e8f0f6', tertiaryColor: '#fbfbfa',
      clusterBkg: '#fbfbfa', clusterBorder: '#e8e6e1',
    },
  });
});

const manifest = {};
for (const [key, code] of unique) {
  const file = `${key}.png`;
  const svg = await page.evaluate(async ({ key, code }) => {
    const { svg } = await window.mermaid.render(`d${key}`, code);
    return svg;
  }, { key, code });
  // Mermaid's SVG is `width: 100%` with its natural size as max-width, so in a
  // shrink-to-fit box it collapses to whatever the box guesses. Pin it to the
  // natural size: the page scales a wide picture down, never the other way.
  await page.evaluate((svg) => {
    const host = document.getElementById('host');
    host.innerHTML = svg;
    const el = host.querySelector('svg');
    const natural = parseFloat(el.style.maxWidth);
    if (natural) {
      el.style.width = `${natural}px`;
      el.style.maxWidth = 'none';
      el.removeAttribute('width');
    }
  }, svg);
  await page.locator('#host').screenshot({ path: join(OUT_DIR, file) });
  manifest[key] = `diagrams/${file}`;
  console.log(`diagram ${key}: ${code.split('\n')[0]}`);
}
await browser.close();

// Pictures for text that no longer exists in any document go, or the folder
// only ever grows.
for (const name of readdirSync(OUT_DIR)) {
  if (name.endsWith('.png') && !Object.values(manifest).includes(`diagrams/${name}`)) {
    unlinkSync(join(OUT_DIR, name));
    console.log(`diagram removed: ${name}`);
  }
}

mkdirSync(dirname(MANIFEST), { recursive: true });
writeFileSync(MANIFEST, JSON.stringify({ diagrams: manifest }, null, 1) + '\n');
console.log(`diagrams: ${Object.keys(manifest).length} -> web/lib/generated/diagrams.json`);
