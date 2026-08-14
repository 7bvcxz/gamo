'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { game, site } from '../../../lib/links.js';
import { Markdown } from '../../../components/Markdown.jsx';
import snapshot from '../../../lib/generated/decisions.json';
import {
  AUTHOR_LABEL,
  PRIORITIES,
  STATUSES,
  STATUS_LABEL,
  addComment,
  apiBase,
  create,
  list,
  ping,
  remove,
  removeComment,
  update,
} from '../../../lib/decisions.js';

// What has been decided about One Shot, what has not, and the argument that got
// there. Modelled on the admin page in modulo: a filtered list down the left, one
// decision open on the right, comments underneath it.
//
// Two things about this page are shaped by where it is served from. It is a
// static export with no server of its own, so it asks a separate API and, when
// nobody answers, falls back to a snapshot committed into the repository -- the
// public site is readable from a phone and editable from the machine the server
// runs on. And there are exactly two comment authors, enforced by the database
// rather than typed in, because a thread whose speakers cannot be told apart is
// a thread nobody re-reads.

const BLANK = {
  title: '',
  body: '',
  status: 'OPEN',
  priority: 'P1',
  category: 'general',
  outcome: '',
};

function Chip({ active, onClick, children }) {
  return (
    <button type="button" className={`chip${active ? ' chip-on' : ''}`} onClick={onClick}>
      {children}
    </button>
  );
}

function Comment({ comment, onDelete, editable }) {
  const mine = comment.author === 'CLAUDE';
  return (
    <li className={`cmt${mine ? ' cmt-claude' : ''}`}>
      <div className="cmt-head">
        <b>{AUTHOR_LABEL[comment.author] || comment.author}</b>
        <time>{String(comment.createdAt).replace('T', ' ').slice(0, 16)}</time>
        {editable && (
          <button type="button" className="ghost" onClick={() => onDelete(comment.id)}>
            삭제
          </button>
        )}
      </div>
      <Markdown body={comment.body} />
    </li>
  );
}

function Detail({ item, editable, onChanged, onEdit, onDelete, notify }) {
  const [author, setAuthor] = useState('HUMAN');
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);

  if (!item) {
    return <div className="empty">왼쪽에서 하나를 고르세요.</div>;
  }

  const send = async (event) => {
    event.preventDefault();
    if (!text.trim() || busy) return;
    setBusy(true);
    try {
      onChanged(await addComment(item.id, { author, body: text.trim() }));
      setText('');
    } catch (error) {
      notify(String(error.message || error));
    } finally {
      setBusy(false);
    }
  };

  const dropComment = async (commentId) => {
    try {
      onChanged(await removeComment(item.id, commentId));
    } catch (error) {
      notify(String(error.message || error));
    }
  };

  return (
    <div className="d-body">
      <div className="d-head">
        <div>
          <span className={`tag pri-${item.priority}`}>{item.priority}</span>
          <span className={`tag st-${item.status}`}>{STATUS_LABEL[item.status] || item.status}</span>
          <span className="tag tag-cat">{item.category}</span>
        </div>
        {editable && (
          <div className="d-actions">
            <button type="button" className="ghost" onClick={() => onEdit(item)}>
              수정
            </button>
            <button type="button" className="ghost danger" onClick={() => onDelete(item)}>
              삭제
            </button>
          </div>
        )}
      </div>
      <h2>{item.title}</h2>
      {item.body && <Markdown body={item.body} />}
      {item.outcome && (
        <div className="outcome">
          <h4>결론</h4>
          <Markdown body={item.outcome} />
        </div>
      )}

      <h4 className="cmt-title">의견 {item.comments.length}개</h4>
      {item.comments.length === 0 && <p className="empty">아직 의견이 없습니다.</p>}
      <ul className="cmts">
        {item.comments.map((comment) => (
          <Comment key={comment.id} comment={comment} editable={editable} onDelete={dropComment} />
        ))}
      </ul>

      {editable && (
        <form className="cmt-form" onSubmit={send}>
          <div className="who">
            {['HUMAN', 'CLAUDE'].map((value) => (
              <Chip key={value} active={author === value} onClick={() => setAuthor(value)}>
                {AUTHOR_LABEL[value]}
              </Chip>
            ))}
          </div>
          <textarea
            rows={3}
            value={text}
            placeholder="의견을 적습니다. 마크다운이 됩니다."
            onChange={(event) => setText(event.target.value)}
          />
          <button className="btn" type="submit" disabled={busy || !text.trim()}>
            남기기
          </button>
        </form>
      )}
    </div>
  );
}

function Editor({ draft, setDraft, onSave, onCancel, busy }) {
  const set = (key) => (event) => setDraft({ ...draft, [key]: event.target.value });
  return (
    <form
      className="d-body editor"
      onSubmit={(event) => {
        event.preventDefault();
        onSave();
      }}
    >
      <h2>{draft.id ? '수정' : '새 Decision'}</h2>
      <label>
        주제
        <input value={draft.title} onChange={set('title')} placeholder="무엇에 관한 결정인가" />
      </label>
      <label>
        설명
        <textarea rows={6} value={draft.body} onChange={set('body')} />
      </label>
      <div className="row">
        <label>
          상태
          <select value={draft.status} onChange={set('status')}>
            {STATUSES.map((value) => (
              <option key={value} value={value}>
                {STATUS_LABEL[value]}
              </option>
            ))}
          </select>
        </label>
        <label>
          우선순위
          <select value={draft.priority} onChange={set('priority')}>
            {PRIORITIES.map((value) => (
              <option key={value} value={value}>
                {value}
              </option>
            ))}
          </select>
        </label>
        <label>
          분류
          <input value={draft.category} onChange={set('category')} />
        </label>
      </div>
      <label>
        결론
        <textarea
          rows={3}
          value={draft.outcome}
          onChange={set('outcome')}
          placeholder="정해졌다면 무엇으로 정해졌는가"
        />
      </label>
      <div className="d-actions">
        <button className="btn" type="submit" disabled={busy || !draft.title.trim()}>
          저장
        </button>
        <button className="ghost" type="button" onClick={onCancel}>
          취소
        </button>
      </div>
    </form>
  );
}

export default function Decisions() {
  const [items, setItems] = useState(snapshot.items || []);
  const [live, setLive] = useState(false);
  // Null until the browser has looked. Rendering anything that depends on the
  // host before this is set is a hydration mismatch waiting to happen.
  const [reachable, setReachable] = useState(null);
  const [base, setBase] = useState('');
  const [selected, setSelected] = useState(null);
  const [draft, setDraft] = useState(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState('');
  const [status, setStatus] = useState('');
  const [priority, setPriority] = useState('');
  const [query, setQuery] = useState('');

  const reload = useCallback(async () => {
    const params = new URLSearchParams();
    if (status) params.set('status', status);
    if (priority) params.set('priority', priority);
    if (query.trim()) params.set('q', query.trim());
    try {
      const body = await list(params.toString());
      setItems(body.items || []);
      return true;
    } catch {
      return false;
    }
  }, [status, priority, query]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setBase(apiBase());
      const answered = await ping();
      if (cancelled) return;
      setReachable(answered);
      setLive(answered);
      if (answered) await reload();
    })();
    return () => {
      cancelled = true;
    };
  }, [reload]);

  useEffect(() => {
    if (live) reload();
  }, [live, reload]);

  // Filtering happens on the server when there is one; the snapshot has to do it
  // here, or the chips would silently do nothing on the public site.
  const shown = useMemo(() => {
    if (live) return items;
    const text = query.trim().toLowerCase();
    return items.filter(
      (item) =>
        (!status || item.status === status) &&
        (!priority || item.priority === priority) &&
        (!text ||
          `${item.title} ${item.body} ${item.outcome}`.toLowerCase().includes(text)),
    );
  }, [items, live, status, priority, query]);

  const current = shown.find((item) => item.id === selected) || null;

  const refresh = async (updated) => {
    await reload();
    if (updated) setSelected(updated.id);
  };

  const save = async () => {
    setBusy(true);
    try {
      const payload = {
        title: draft.title,
        body: draft.body,
        status: draft.status,
        priority: draft.priority,
        category: draft.category,
        outcome: draft.outcome,
      };
      const saved = draft.id ? await update(draft.id, payload) : await create(payload);
      setDraft(null);
      await refresh(saved);
    } catch (error) {
      setMessage(String(error.message || error));
    } finally {
      setBusy(false);
    }
  };

  const drop = async (item) => {
    if (!window.confirm(`"${item.title}" 를 지웁니다.`)) return;
    try {
      await remove(item.id);
      setSelected(null);
      await reload();
    } catch (error) {
      setMessage(String(error.message || error));
    }
  };

  return (
    <div className="gfx-page decisions">
      <header className="gfx-head">
        <p className="gfx-crumb">
          <a href={site('/')}>Gamo</a> · <a href={game('/motorio-oneshot/')}>Motorio: One Shot</a> ·{' '}
          <a href={site('/motorio-oneshot/doc/')}>Docs</a>
        </p>
        <h1>Decisions</h1>
        <p className="lede">
          One Shot에 대해 무엇이 정해졌고 무엇이 아직 열려 있는지, 그리고 거기에 이르기까지 오간
          의견입니다. 작성자는 <b>사람</b>과 <b>Claude Code</b> 둘뿐입니다.
        </p>
        {!live && (
          // `reachable` starts null and only becomes a boolean after the effect
          // has run, so the first client render matches what was prerendered.
          // Asking apiBase() during render did not: there is no window on the
          // server, so the sentence differed between the two passes and React
          // threw a hydration error on a page that was otherwise working.
          <p className="offline">
            읽기 전용입니다 — 이 목록은 저장소에 커밋된 스냅샷이고, 편집은 서버가 도는 곳에서
            합니다. <code>docker compose -f server/docker-compose.yml up -d</code>
            {reachable === false && base === '' ? ' (공개 주소에서는 서버에 닿지 않습니다)' : ''}
          </p>
        )}
        {message && (
          <p className="offline danger" onClick={() => setMessage('')}>
            {message}
          </p>
        )}
      </header>

      <div className="dec-wrap">
        <aside className="dec-list">
          <div className="toolbar">
            <input
              className="search"
              value={query}
              placeholder="검색"
              onChange={(event) => setQuery(event.target.value)}
            />
            {live && (
              <button className="btn" type="button" onClick={() => setDraft({ ...BLANK })}>
                새로 만들기
              </button>
            )}
          </div>
          <div className="chips">
            <Chip active={!status} onClick={() => setStatus('')}>
              전체
            </Chip>
            {STATUSES.map((value) => (
              <Chip key={value} active={status === value} onClick={() => setStatus(value)}>
                {STATUS_LABEL[value]}
              </Chip>
            ))}
          </div>
          <div className="chips">
            <Chip active={!priority} onClick={() => setPriority('')}>
              P 전체
            </Chip>
            {PRIORITIES.map((value) => (
              <Chip key={value} active={priority === value} onClick={() => setPriority(value)}>
                {value}
              </Chip>
            ))}
          </div>
          {shown.length === 0 && <div className="empty">해당하는 것이 없습니다.</div>}
          <ul className="items">
            {shown.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  className={`item${selected === item.id ? ' item-on' : ''}`}
                  onClick={() => {
                    setSelected(item.id);
                    setDraft(null);
                  }}
                >
                  <div className="t">{item.title}</div>
                  <div className="m">
                    <span className={`tag pri-${item.priority}`}>{item.priority}</span>
                    <span className={`tag st-${item.status}`}>
                      {STATUS_LABEL[item.status] || item.status}
                    </span>
                    <span className="muted">{item.category}</span>
                    <span className="muted">의견 {item.comments.length}</span>
                  </div>
                </button>
              </li>
            ))}
          </ul>
        </aside>

        <section className="dec-detail">
          {draft ? (
            <Editor
              draft={draft}
              setDraft={setDraft}
              onSave={save}
              onCancel={() => setDraft(null)}
              busy={busy}
            />
          ) : (
            <Detail
              item={current}
              editable={live}
              onChanged={refresh}
              onEdit={(item) => setDraft({ ...item })}
              onDelete={drop}
              notify={setMessage}
            />
          )}
        </section>
      </div>
    </div>
  );
}
