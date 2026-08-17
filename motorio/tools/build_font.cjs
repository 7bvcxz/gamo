// Builds the game's UI font by cutting a subset out of Noto Sans CJK.
//
// Why this exists: the full NotoSansCJK-Regular.ttc is 19 MB, and Godot embeds
// the whole thing in the export. It was 16.3 MB of an 18.2 MB pack -- ninety
// percent of the download was Japanese and Chinese glyphs this game never draws.
// On a phone that is minutes of staring at a blank page before the title screen.
//
// The character set is read out of the source rather than hand-listed, because a
// hand-listed set goes stale the first time someone writes a new caption and the
// glyph comes out as a tofu box. tests/test_font.gd fails if any character the
// scripts can draw is missing from the built font, so the two cannot drift apart
// quietly -- it will be a failing test rather than a box on someone's screen.
//
//   npm install --prefix /tmp/fonttool subset-font
//   NODE_PATH=/tmp/fonttool/node_modules node motorio/tools/build_font.cjs
//
// The output is committed. This does not run at build time; re-run it when the
// test says the font is missing a character.

const { readFileSync, writeFileSync, readdirSync, statSync } = require('node:fs');
const { dirname, join, resolve } = require('node:path');

const subsetFont = require('subset-font');

const game = resolve(dirname(__filename), '..');
// Two faces. The body face is what the whole game is set in; the display face is
// used for the handful of words the opening leans on, and it is a genuinely
// different typeface rather than the same one emboldened -- a synthesised bold
// of the body text reads as the same sentence shouting, which is not what a word
// standing apart from its sentence is supposed to look like.
//
// Both are cut to the *same* character set, deliberately. The display face only
// ever draws the words marked `hot` in the cutscene table, so a tighter subset
// would be smaller -- and the first time someone marks a new word it would draw
// a tofu box. One set, one test, no way to drift.
const FACES = [
  { source: join(game, 'tools', 'NotoSansCJK-Regular.ttc'),
    output: join(game, 'assets', 'ui-font.otf') },
  { source: join(game, 'tools', 'NotoSerifCJK-Bold.ttc'),
    output: join(game, 'assets', 'ui-display.otf') },
];

// Every .gd file, plus the project file: the application name reaches the export
// shell and the browser tab.
function collect(dir, out) {
  for (const entry of readdirSync(dir)) {
    if (entry === '.godot' || entry === 'node_modules') continue;
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) collect(path, out);
    else if (entry.endsWith('.gd') || entry === 'project.godot') out.push(path);
  }
  return out;
}

// The source is a TrueType Collection: several faces sharing one pool of tables.
// Subsetters take a single font, so a face has to be lifted out first -- rebuild
// an sfnt whose table directory points at that face's tables, copied out.
//
// Layout: 'ttcf', major(2), minor(2), numFonts(4), then one absolute offset per
// face to an ordinary table directory whose entries point back into the file.
function faceCount(buffer) {
  if (buffer.toString('latin1', 0, 4) !== 'ttcf') return 0;
  return buffer.readUInt32BE(8);
}

function extractFace(buffer, index) {
  const directory = buffer.readUInt32BE(12 + index * 4);
  const numTables = buffer.readUInt16BE(directory + 4);
  const tables = [];
  for (let i = 0; i < numTables; i += 1) {
    const entry = directory + 12 + i * 16;
    tables.push({
      tag: buffer.toString('latin1', entry, entry + 4),
      checksum: buffer.readUInt32BE(entry + 4),
      offset: buffer.readUInt32BE(entry + 8),
      length: buffer.readUInt32BE(entry + 12),
    });
  }
  tables.sort((a, b) => (a.tag < b.tag ? -1 : 1));

  // Everything after the directory is padded to four bytes, which is what the
  // format requires and what a checksum-checking consumer will expect.
  const header = 12 + numTables * 16;
  const chunks = [];
  let cursor = header;
  for (const table of tables) {
    table.newOffset = cursor;
    const data = buffer.subarray(table.offset, table.offset + table.length);
    const padding = (4 - (table.length % 4)) % 4;
    chunks.push(data, Buffer.alloc(padding));
    cursor += table.length + padding;
  }

  const head = Buffer.alloc(header);
  head.write(buffer.toString('latin1', directory, directory + 4), 0, 'latin1');
  head.writeUInt16BE(numTables, 4);
  // The binary-search hints. Consumers are allowed to ignore them, but a wrong
  // value here is the kind of thing one parser in ten refuses to open.
  const power = Math.floor(Math.log2(numTables));
  head.writeUInt16BE(2 ** power * 16, 6);
  head.writeUInt16BE(power, 8);
  head.writeUInt16BE(numTables * 16 - 2 ** power * 16, 10);
  tables.forEach((table, i) => {
    const entry = 12 + i * 16;
    head.write(table.tag, entry, 'latin1');
    head.writeUInt32BE(table.checksum, entry + 4);
    head.writeUInt32BE(table.newOffset, entry + 8);
    head.writeUInt32BE(table.length, entry + 12);
  });
  return Buffer.concat([head, ...chunks]);
}

async function main() {
  const chars = new Set();
  // Printable ASCII in full. It costs almost nothing and it is what every
  // number, key hint and unit in the game is made of.
  for (let code = 0x20; code <= 0x7e; code += 1) chars.add(String.fromCodePoint(code));
  // The typographic marks the UI separates things with. Listed explicitly rather
  // than left to turn up in some source string, because they are exactly the
  // characters most likely to be added to a caption later.
  for (const mark of '·—–…×÷°％±→←↑↓≥≤「」『』“”‘’《》〈〉') chars.add(mark);

  for (const file of collect(game, [])) {
    for (const ch of readFileSync(file, 'utf8')) {
      // Anything past ASCII is a glyph the bundled font has to carry.
      if (ch.codePointAt(0) > 0x7e) chars.add(ch);
    }
  }

  const text = [...chars].sort().join('');
  const mb = (n) => `${(n / 1024 / 1024).toFixed(2)} MB`;
  console.log(`FONT_SUBSET: ${chars.size} characters`);
  for (const face of FACES) {
    const source = readFileSync(face.source);
    const faces = faceCount(source);
    // Face 0. Noto CJK's faces share one glyph pool and differ only in which
    // regional shapes the unified Han codepoints resolve to -- and this game
    // draws no Han at all, only Hangul and Latin, so the choice cannot change a
    // glyph.
    const single = faces > 0 ? extractFace(source, 0) : source;
    const subset = await subsetFont(single, text, { targetFormat: 'sfnt' });
    writeFileSync(face.output, subset);
    console.log(`FONT_SUBSET: ${mb(source.length)} -> ${mb(subset.length)}  (${face.output})`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
