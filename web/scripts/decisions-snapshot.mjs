// The decisions, from the running server into the repository.
//
// The site is a static export served from three hosts and the server runs on
// one machine, so the public page cannot ask it anything. This is what it reads
// instead: a snapshot, committed, so the decisions are legible from a phone even
// though they can only be edited from here.
//
//     node scripts/decisions-snapshot.mjs
//
// Run before committing, the same way the balance dump is. If the server is not
// up it leaves the existing snapshot alone and says so -- an empty file would
// silently publish "there are no decisions", which is a different claim from
// "nobody asked".
import { writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, '..', 'lib', 'generated', 'decisions.json');
const API = process.env.GAMO_DECISIONS_API || 'http://127.0.0.1:8790';

const response = await fetch(`${API}/api/gamo/v1/decisions`).catch(() => null);
if (!response || !response.ok) {
  console.error(`decisions: ${API} 에 닿지 않아 스냅샷을 그대로 둡니다.`);
  if (!existsSync(OUT)) {
    mkdirSync(dirname(OUT), { recursive: true });
    writeFileSync(OUT, JSON.stringify({ items: [], capturedAt: null }, null, 1) + '\n');
    console.error('decisions: 빈 스냅샷을 만들었습니다 (빌드가 깨지지 않도록).');
  }
  process.exit(0);
}

const body = await response.json();
const items = body.items || [];
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(
  OUT,
  JSON.stringify({ items, capturedAt: new Date().toISOString() }, null, 1) + '\n',
);
const comments = items.reduce((sum, item) => sum + item.comments.length, 0);
console.log(`decisions: ${items.length}건 · 의견 ${comments}개 -> lib/generated/decisions.json`);
