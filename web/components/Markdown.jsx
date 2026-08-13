'use client';

import React from 'react';

// A very small markdown renderer, for the design documents.
//
// Not a library: the site is a static export with no dependencies beyond Next
// itself, and what these documents use is a short list -- headings, paragraphs,
// lists, fenced code, tables, blockquotes, and inline bold and code. Pulling in
// a parser to render six files would be a larger commitment than writing the
// eighty lines that cover them.
//
// It renders what it understands and passes anything else through as text, so a
// document that starts using something new degrades to plain text rather than
// disappearing.

function inline(text, keyBase) {
  // Bold and code, in one pass, so `**a `b` c**` does not need nesting rules
  // this does not have. Split keeps the delimiters, and the index tells us
  // which kind each fragment is.
  const parts = String(text).split(/(\*\*[^*]+\*\*|`[^`]+`)/g);
  return parts.map((part, index) => {
    const key = `${keyBase}-${index}`;
    if (part.startsWith('**') && part.endsWith('**') && part.length > 4) {
      return <b key={key}>{part.slice(2, -2)}</b>;
    }
    if (part.startsWith('`') && part.endsWith('`') && part.length > 2) {
      return <code key={key}>{part.slice(1, -1)}</code>;
    }
    return <React.Fragment key={key}>{part}</React.Fragment>;
  });
}

function tableRow(line) {
  return line
    .replace(/^\||\|$/g, '')
    .split('|')
    .map((cell) => cell.trim());
}

export function Markdown({ body }) {
  const lines = String(body || '').split('\n');
  const out = [];
  let index = 0;
  let key = 0;

  while (index < lines.length) {
    const line = lines[index];

    // Fenced code. Taken verbatim, including the diagrams these documents lean
    // on -- they are drawn with box characters and any reflow destroys them.
    if (line.startsWith('```')) {
      const start = index + 1;
      let end = start;
      while (end < lines.length && !lines[end].startsWith('```')) end++;
      out.push(<pre key={key++}><code>{lines.slice(start, end).join('\n')}</code></pre>);
      index = end + 1;
      continue;
    }

    const heading = line.match(/^(#{1,4})\s+(.*)$/);
    if (heading) {
      const level = heading[1].length;
      const Tag = `h${Math.min(level + 1, 5)}`;
      out.push(<Tag key={key++}>{inline(heading[2], key)}</Tag>);
      index++;
      continue;
    }

    if (/^\s*---+\s*$/.test(line)) {
      out.push(<hr key={key++} />);
      index++;
      continue;
    }

    // Tables: a header row, a separator, then body rows.
    if (line.trim().startsWith('|') && (lines[index + 1] || '').includes('---')) {
      const header = tableRow(line);
      let cursor = index + 2;
      const rows = [];
      while (cursor < lines.length && lines[cursor].trim().startsWith('|')) {
        rows.push(tableRow(lines[cursor]));
        cursor++;
      }
      out.push(
        <div className="md-table" key={key++}>
          <table>
            <thead>
              <tr>{header.map((cell, i) => <th key={i}>{inline(cell, `h${i}`)}</th>)}</tr>
            </thead>
            <tbody>
              {rows.map((row, r) => (
                <tr key={r}>{row.map((cell, c) => <td key={c}>{inline(cell, `${r}-${c}`)}</td>)}</tr>
              ))}
            </tbody>
          </table>
        </div>,
      );
      index = cursor;
      continue;
    }

    if (/^\s*>\s?/.test(line)) {
      const quote = [];
      while (index < lines.length && /^\s*>\s?/.test(lines[index])) {
        quote.push(lines[index].replace(/^\s*>\s?/, ''));
        index++;
      }
      out.push(<blockquote key={key++}>{inline(quote.join(' '), key)}</blockquote>);
      continue;
    }

    if (/^\s*(?:[-*]|\d+\.)\s+/.test(line)) {
      const ordered = /^\s*\d+\./.test(line);
      const items = [];
      while (index < lines.length && /^\s*(?:[-*]|\d+\.)\s+/.test(lines[index])) {
        items.push(lines[index].replace(/^\s*(?:[-*]|\d+\.)\s+/, ''));
        index++;
      }
      const List = ordered ? 'ol' : 'ul';
      out.push(
        <List key={key++}>
          {items.map((item, i) => <li key={i}>{inline(item, `${key}-${i}`)}</li>)}
        </List>,
      );
      continue;
    }

    if (line.trim() === '') {
      index++;
      continue;
    }

    // A paragraph runs until a blank line or anything else that starts a block.
    const paragraph = [];
    while (
      index < lines.length &&
      lines[index].trim() !== '' &&
      !lines[index].startsWith('```') &&
      !/^#{1,4}\s/.test(lines[index]) &&
      !/^\s*>/.test(lines[index]) &&
      !/^\s*(?:[-*]|\d+\.)\s+/.test(lines[index]) &&
      !/^\s*---+\s*$/.test(lines[index]) &&
      !lines[index].trim().startsWith('|')
    ) {
      paragraph.push(lines[index]);
      index++;
    }
    out.push(<p key={key++}>{inline(paragraph.join(' '), key)}</p>);
  }

  return <div className="md">{out}</div>;
}

export default Markdown;
