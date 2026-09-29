// The name a ```mermaid block's picture is stored under: a hash of its text.
//
// Shared by the script that renders the pictures (scripts/mermaid-render.mjs)
// and the page that shows them (components/Markdown.jsx), so the two cannot
// disagree about which file belongs to which block. A block that changes gets a
// new name, which is also what keeps a stale picture from being shown for new
// text -- the page falls back to showing the source until it is rendered again.
//
// FNV-1a over UTF-16 code units: no crypto in the browser, and deterministic.
export function diagramKey(code) {
  const text = String(code).trim();
  let hash = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, '0');
}
