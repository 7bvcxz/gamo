'use client';

import React from 'react';
import { Markdown } from '../../Markdown.jsx';
import design from '../../../lib/generated/design.json';

// One design document, rendered from the file in the repository.
//
// The nav in the doc page builds one of these per document, so adding a
// markdown file to motorio/design/ puts it on the site -- there is no
// list here to forget to update.

const STATUS_NOTE = {
  '[확정]': '이대로 만든다.',
  '[초안]': '방향은 맞으나 수치와 형태는 바뀔 수 있다.',
  '[질문]': '사용자 결정 없이 구현하지 않는다.',
};

export function DesignDoc({ id }) {
  const doc = (design.docs || []).find((entry) => entry.id === id);
  if (!doc) {
    return (
      <section className="prop">
        <h2>문서를 찾을 수 없습니다</h2>
        <p className="prop-why">
          <code>motorio/design/</code> 에 파일이 있는지, 사이트 빌드가
          <code> scripts/design-to-json.mjs</code> 를 돌렸는지 확인하세요.
        </p>
      </section>
    );
  }
  return (
    <section className="prop design-doc">
      {doc.status && (
        <p className="design-status">
          <span className={`tag ${doc.status === '[질문]' ? 'tag-warn' : 'tag-add'}`}>
            {doc.status}
          </span>
          {STATUS_NOTE[doc.status]}
          <span className="design-source">
            원본: <code>motorio/design/{doc.file}</code>
          </span>
        </p>
      )}
      <Markdown body={doc.body} />
    </section>
  );
}

export default DesignDoc;
