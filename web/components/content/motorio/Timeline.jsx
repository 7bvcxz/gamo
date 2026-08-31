'use client';

import React from 'react';
import design from '../../../lib/generated/design.json';

// The 30 minutes v0.1 is made of, drawn from the table that defines them.
//
// The table lives in motorio/design/VERTICAL_SLICE.md and is read here rather
// than retyped, for the reason this repository keeps writing down: a second copy
// is always the one that goes stale. Editing the markdown moves this page; there
// is nothing here to remember to update.
//
// What the drawing adds over the markdown is proportion. A table gives every row
// the same height, so "0:00–1:30" and "24:00–30:00" look like the same amount of
// game -- and the whole argument of the document is about where the thirty
// minutes go. Here a band is as tall as its share of the half hour, which makes
// the shape of the budget the first thing on the screen.

const SOURCE_ID = 'vertical-slice';

// The section between "## 시간 예산" and the next heading of the same level.
function section(body, heading) {
  const parts = body.split(/^## /m);
  return parts.find((part) => part.startsWith(heading)) || '';
}

function tableRows(text) {
  const lines = text.split('\n').filter((line) => line.trim().startsWith('|'));
  // Header, separator, then the rows.
  return lines.slice(2).map((line) =>
    line
      .split('|')
      .slice(1, -1)
      .map((cell) => cell.trim()),
  );
}

// "0:00–1:30" with an en dash, which is what the document uses.
function span(label) {
  const match = label.match(/(\d+):(\d+)\s*[–-]\s*(\d+):(\d+)/);
  if (!match) return null;
  const at = (m, s) => Number(m) + Number(s) / 60;
  return { from: at(match[1], match[2]), to: at(match[3], match[4]) };
}

// Emphasis in the table marks the two Aha moments. It is the document's own
// signal, so it is read rather than a list of names kept here.
const emphasised = (cell) => /^\*\*.+\*\*$/.test(cell);
const plain = (cell) => cell.replace(/\*\*/g, '');

// The blockquote under the table, as paragraphs. Markdown soft-wraps, so the
// lines of one paragraph join with a space; a bare ">" is the break between two.
function quoted(text) {
  const lines = text
    .split('\n')
    .filter((line) => line.startsWith('>'))
    .map((line) => line.replace(/^>\s?/, ''));
  return lines
    .join('\n')
    .split(/\n\s*\n/)
    .map((para) => para.split('\n').join(' ').trim())
    .filter(Boolean);
}

// Just the two marks the design documents actually use inline. Anything more
// wants the Markdown component, and this is one paragraph of prose.
function inline(text, keyBase) {
  return text.split(/(\*\*[^*]+\*\*|`[^`]+`)/g).map((part, index) => {
    const key = `${keyBase}-${index}`;
    if (/^\*\*[^*]+\*\*$/.test(part)) return <b key={key}>{part.slice(2, -2)}</b>;
    if (/^`[^`]+`$/.test(part)) return <code key={key}>{part.slice(1, -1)}</code>;
    return <React.Fragment key={key}>{part}</React.Fragment>;
  });
}

const STATUS = {
  있음: { tone: 'tag-add', note: '코드에 있다' },
  절반: { tone: 'tag-warn', note: '시스템은 있고 연출이 없다' },
  미확인: { tone: 'tag-change', note: '아직 아무도 재지 않았다' },
};

export function Timeline() {
  const doc = (design.docs || []).find((entry) => entry.id === SOURCE_ID);
  if (!doc) {
    return (
      <section className="prop">
        <h2>타임라인 원본을 찾을 수 없습니다</h2>
        <p className="prop-why">
          <code>motorio/design/VERTICAL_SLICE.md</code> 가 있는지, 사이트 빌드가
          <code> scripts/design-to-json.mjs</code> 를 돌렸는지 확인하세요.
        </p>
      </section>
    );
  }

  const budget = section(doc.body, '시간 예산');
  const rows = tableRows(budget)
    .map((cells) => ({
      name: plain(cells[0]),
      key: emphasised(cells[0]),
      at: plain(cells[1]),
      window: span(cells[1]),
      gain: plain(cells[2] || ''),
      status: plain(cells[3] || ''),
    }))
    .filter((row) => row.window);

  const total = rows.length ? rows[rows.length - 1].window.to : 30;
  const note = quoted(budget);

  const unlocks = (section(doc.body, '해금 순서').match(/```\n([\s\S]*?)```/) || [, ''])[1].trim();

  const done = rows.filter((row) => row.status === '있음').length;

  return (
    <section className="prop">
      <h2>Timeline — v0.1</h2>
      <p className="lede">
        v0.1은 이 {total}분이 끝까지 돌아가는 것입니다. 그 이상은 v0.1이 아닙니다.
      </p>
      <p className="prop-why">
        이 페이지는 <code>motorio/design/VERTICAL_SLICE.md</code> 의 시간 예산표를 그대로 읽어
        그립니다. 표를 고치면 여기가 따라옵니다 — 옮겨 적은 사본은 없습니다.
      </p>

      <p className="timeline-tally">
        {rows.length}칸 중 <b>{done}칸</b>이 코드에 있고,{' '}
        <b>{rows.length - done}칸</b>이 남았습니다.
      </p>

      <div className="timeline">
        {rows.map((row) => {
          const length = row.window.to - row.window.from;
          const tone = STATUS[row.status];
          return (
            <div
              className={`tl-row${row.key ? ' tl-key' : ''}`}
              key={row.name}
              style={{ '--tl-span': length / total }}
            >
              <div className="tl-when">{row.at}</div>
              <div className="tl-bar" aria-hidden="true">
                <span className="tl-dot" />
              </div>
              <div className="tl-body">
                <p className="tl-name">
                  {row.name}
                  {row.key && <span className="tl-aha">Aha</span>}
                  {tone && (
                    <span className={`tag ${tone.tone}`} title={tone.note}>
                      {row.status}
                    </span>
                  )}
                </p>
                <p className="tl-gain">{row.gain}</p>
              </div>
            </div>
          );
        })}
      </div>

      {note.length > 0 && (
        <div className="timeline-note">
          {note.map((para, index) => (
            <p key={index}>{inline(para, `note-${index}`)}</p>
          ))}
        </div>
      )}

      {unlocks && (
        <>
          <h3>해금 순서</h3>
          <pre className="md-table">{unlocks}</pre>
        </>
      )}
    </section>
  );
}

export default Timeline;
