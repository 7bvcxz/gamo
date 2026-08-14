// Where the decisions API lives, and whether we can reach it.
//
// The same shape modulo uses: the host decides. This site is a static export
// served from three places and the server behind it runs on one machine, so a
// hard-coded URL would be wrong from two of the three -- and an unreachable API
// has to degrade into a readable page rather than an error.

const LOCAL = 'http://127.0.0.1:8790';

export function apiBase() {
  if (typeof window === 'undefined') return '';
  const host = window.location.hostname;
  // Served from this machine -- the dev server, the docs preview, the nginx
  // mirror -- so the server is on this machine too.
  if (host === 'localhost' || host === '127.0.0.1') return LOCAL;
  // Somewhere else. There is no public endpoint yet; when the server goes
  // behind the tunnel this is the one line that changes, and until then the
  // page falls back to the committed snapshot.
  return process.env.NEXT_PUBLIC_DECISIONS_API || '';
}

export const PATH = '/api/gamo/v1/decisions';

async function call(path, options) {
  const base = apiBase();
  if (!base) throw new Error('offline');
  const response = await fetch(base + PATH + (path || ''), {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : {};
  if (!response.ok) throw new Error(body.error || `HTTP ${response.status}`);
  return body;
}

/** Is the server there? Used once, to decide whether to offer editing at all --
 *  buttons that fail when pressed are worse than buttons that are not shown. */
export async function ping() {
  const base = apiBase();
  if (!base) return false;
  try {
    const response = await fetch(base + '/api/ping', { cache: 'no-store' });
    return response.ok;
  } catch {
    return false;
  }
}

export const list = (query) => call(query ? `?${query}` : '');
export const create = (payload) => call('', { method: 'POST', body: JSON.stringify(payload) });
export const update = (id, payload) =>
  call(`/${id}`, { method: 'PATCH', body: JSON.stringify(payload) });
export const remove = (id) => call(`/${id}`, { method: 'DELETE' });
export const addComment = (id, payload) =>
  call(`/${id}/comments`, { method: 'POST', body: JSON.stringify(payload) });
export const removeComment = (id, commentId) =>
  call(`/${id}/comments/${commentId}`, { method: 'DELETE' });

export const STATUSES = ['OPEN', 'DECIDED', 'DEFERRED', 'DROPPED'];
export const PRIORITIES = ['P0', 'P1', 'P2', 'P3', 'P4'];

export const STATUS_LABEL = {
  OPEN: '열림',
  DECIDED: '결정됨',
  DEFERRED: '보류',
  DROPPED: '버림',
};

export const AUTHOR_LABEL = { HUMAN: '사람', CLAUDE: 'Claude Code' };
