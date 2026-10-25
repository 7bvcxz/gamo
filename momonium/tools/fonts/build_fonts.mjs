// Builds Momonium's UI fonts: one small subset of Noto Sans CJK per language.
//
// Why per language: Han characters share code points across Japanese, Chinese
// and Korean but are drawn differently in each. 研究 set in the Korean face looks
// subtly wrong to a Japanese reader. Each language gets the face of its region,
// cut down to exactly the characters that language's strings use (+ ASCII), and
// the game puts the current language's face first with the others as fallback.
//
// The full collection is 19 MB; these subsets are tens of kilobytes. The set is
// read from data/i18n/*.csv and every .gd file, never listed by hand, and
// tests/unit/ui/test_locale.gd fails if any character is missing -- a failing
// test instead of a tofu box on someone's phone.
//
//   (cd momonium/tools/fonts && npm install && node build_fonts.mjs)
//
// Source: NOTO_CJK_TTC, or the copy the repository already carries for motorio
// (read only). The output is committed; this does not run at build time.
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import subsetFont from 'subset-font';

const here = dirname(fileURLToPath(import.meta.url));
const game = resolve(here, '../..');
const source = process.env.NOTO_CJK_TTC || resolve(game, '../motorio/tools/NotoSansCJK-Regular.ttc');
// Face indices inside NotoSansCJK-Regular.ttc: 0 JP, 1 KR, 2 SC.
const LANGS = [
  { code: 'ko', face: 1, column: 'ko', out: 'ui_ko.otf' },
  { code: 'ja', face: 0, column: 'ja', out: 'ui_ja.otf' },
  { code: 'zh_CN', face: 2, column: 'zh_CN', out: 'ui_zh.otf' },
];

function parseCsv(text) {
  const rows = [];
  let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c !== '\r') field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows;
}

function collect(dir, ext, out) {
  for (const entry of readdirSync(dir)) {
    if (['.godot', 'node_modules', 'tests', 'tools', 'design'].includes(entry)) continue;
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) collect(path, ext, out);
    else if (entry.endsWith(ext)) out.push(path);
  }
  return out;
}

// A TrueType Collection shares tables between faces; subsetters want one face,
// so rebuild a standalone sfnt whose directory points at that face's tables.
function extractFace(buffer, index) {
  const directory = buffer.readUInt32BE(12 + index * 4);
  const numTables = buffer.readUInt16BE(directory + 4);
  const tables = [];
  for (let i = 0; i < numTables; i++) {
    const e = directory + 12 + i * 16;
    tables.push({ tag: buffer.toString('latin1', e, e + 4), checksum: buffer.readUInt32BE(e + 4), offset: buffer.readUInt32BE(e + 8), length: buffer.readUInt32BE(e + 12) });
  }
  tables.sort((a, b) => (a.tag < b.tag ? -1 : 1));
  const header = 12 + numTables * 16;
  const chunks = [];
  let cursor = header;
  for (const t of tables) {
    t.newOffset = cursor;
    const pad = (4 - (t.length % 4)) % 4;
    chunks.push(buffer.subarray(t.offset, t.offset + t.length), Buffer.alloc(pad));
    cursor += t.length + pad;
  }
  const head = Buffer.alloc(header);
  head.write(buffer.toString('latin1', directory, directory + 4), 0, 'latin1');
  head.writeUInt16BE(numTables, 4);
  const power = Math.floor(Math.log2(numTables));
  head.writeUInt16BE(2 ** power * 16, 6);
  head.writeUInt16BE(power, 8);
  head.writeUInt16BE(numTables * 16 - 2 ** power * 16, 10);
  tables.forEach((t, i) => {
    const e = 12 + i * 16;
    head.write(t.tag, e, 'latin1');
    head.writeUInt32BE(t.checksum, e + 4);
    head.writeUInt32BE(t.newOffset, e + 8);
    head.writeUInt32BE(t.length, e + 12);
  });
  return Buffer.concat([head, ...chunks]);
}

const base = new Set();
for (let c = 0x20; c <= 0x7e; c++) base.add(String.fromCodePoint(c));
for (const mark of '·—–…×°→←↑↓✓✕') base.add(mark);
// Non-ASCII in scripts goes to every face (symbols, separators).
for (const file of collect(game, '.gd', [])) {
  for (const ch of readFileSync(file, 'utf8')) if (ch.codePointAt(0) > 0x7e) base.add(ch);
}

const perLang = Object.fromEntries(LANGS.map((l) => [l.code, new Set(base)]));
for (const csv of readdirSync(join(game, 'data', 'i18n')).filter((f) => f.endsWith('.csv'))) {
  const rows = parseCsv(readFileSync(join(game, 'data', 'i18n', csv), 'utf8'));
  const header = rows[0];
  for (const row of rows.slice(1)) {
    LANGS.forEach((l) => {
      const col = header.indexOf(l.column);
      for (const ch of row[col] || '') perLang[l.code].add(ch);
    });
    // Language names are shown in their own script in every language's menu.
    const nameRow = row[0] === 'lang.name';
    if (nameRow) LANGS.forEach((l) => { for (const cell of row.slice(1)) for (const ch of cell) perLang[l.code].add(ch); });
  }
}

const collection = readFileSync(source);
for (const l of LANGS) {
  const face = extractFace(collection, l.face);
  const text = [...perLang[l.code]].sort().join('');
  const out = await subsetFont(face, text, { targetFormat: 'sfnt' });
  writeFileSync(join(game, 'assets', 'fonts', l.out), out);
  console.log(`${l.out}: ${perLang[l.code].size} chars, ${(out.length / 1024).toFixed(1)} KB`);
}
