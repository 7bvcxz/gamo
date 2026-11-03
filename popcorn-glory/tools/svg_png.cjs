// Renders an SVG to PNG with Chromium (it has fonts; Godot's SVG rasteriser
// draws no <text>). Used for tests/results charts.
//   NODE_PATH=popcorn-glory/tests/e2e/node_modules node popcorn-glory/tools/svg_png.cjs in.svg out.png
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const [src, out] = process.argv.slice(2);
  const svg = fs.readFileSync(src, 'utf8');
  const m = svg.match(/width='(\d+)' height='(\d+)'/);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: Number(m[1]), height: Number(m[2]) } });
  await p.setContent(`<body style="margin:0">${svg}</body>`);
  await p.screenshot({ path: out });
  await b.close();
  console.log('svg_png:', out);
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
