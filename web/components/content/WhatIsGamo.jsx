'use client';

import React from 'react';
import { game, site } from '../../lib/links.js';

export function WhatIsGamo() {
  return (
    <>
      <h1>What is Gamo?</h1>
      <p className="lede">
        Gamo는 Godot으로 만든 게임들을 한 저장소에서 관리하고, 브라우저에서 바로 실행할 수 있게
        배포하는 프로젝트입니다. 설치 없이 링크 하나로 플레이할 수 있는 것을 첫 목표로 잡습니다.
      </p>

      <p>
        게임마다 독립된 Godot 프로젝트가 저장소 최상단 폴더로 존재하고, 하나의 스크립트가 전부를
        웹으로 내보냅니다. 새 게임을 추가하는 일은 폴더 하나를 만들고 Web export 프리셋을 넣는
        것으로 끝나며, 배포 주소는 폴더 이름에서 곧바로 결정됩니다.
      </p>

      <h2>지금 있는 게임</h2>
      <div className="cards">
        <a className="card" href={game('/motorio/')}>
          <b>Motorio</b>
          <span>
            얼어붙은 고원에서 고양이 작업자와 공장을 세우는 탑다운 자동화 게임. 하루가 끝나면 그날
            모은 열이 정산되고, 공장과 온기는 다음 날로 이어집니다.
          </span>
        </a>
        <a className="card" href={game('/gunslinger/')}>
          <b>Gunslinger</b>
          <span>
            서부 총잡이 1대1 한방 대결. &ldquo;대기 → 신호 → 순간 반응&rdquo;이 반복
            플레이할 만큼 재미있는지 한 가지만 확인하려고 만든 프로토타입입니다.
          </span>
        </a>
        <a className="card" href={game('/looproom/')}>
          <b>looproom</b>
          <span>
            한 화면에 한 방. 발견하는 재미와 회귀당하는 긴장이 함께 있을 때
            &ldquo;한 번 더&rdquo;가 나오는지 확인하려고 만든 프로토타입입니다.
          </span>
        </a>
        <a className="card" href={game('/nowhere/')}>
          <b>Nowhere</b>
          <span>
            방과 방을 오가는 실험용 프로토타입. 벽에 닿으면 반대편에서 새 방이 시작됩니다.
          </span>
        </a>
      </div>

      <h2>어떻게 동작하나</h2>
      <p>
        <code>deploy-web.sh</code>가 각 게임을 Godot의 Web(WebAssembly) 타깃으로 내보내
        <code>docs/&lt;게임명&gt;/</code>에 넣고, GitHub Pages가 <code>main</code> 브랜치의{' '}
        <code>docs/</code>를 그대로 서비스합니다. 이 문서 사이트도 같은 폴더에 함께 빌드됩니다.
      </p>
      <p>
        빌드 파일에는 내용 해시가 붙습니다. GitHub Pages의 CDN이 파일을 수 분간 캐시하기 때문에,
        고정된 이름의 파일만 쓰면 갱신해도 예전 빌드가 계속 보이는 문제가 있었습니다. 지금은 고정
        주소의 로더가 저장소 API에서 최신 빌드 정보를 읽어 해시가 붙은 파일을 직접 내려받고,
        주소창은 <code>/gamo/&lt;게임명&gt;/</code>로 유지됩니다.
      </p>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>경로</th>
              <th>무엇이 있나</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>
                <code>motorio/</code>, <code>gunslinger/</code>, <code>nowhere/</code>
              </td>
              <td>각 게임의 Godot 프로젝트 소스</td>
            </tr>
            <tr>
              <td>
                <code>docs/</code>
              </td>
              <td>GitHub Pages가 서비스하는 웹 빌드와 이 문서 사이트</td>
            </tr>
            <tr>
              <td>
                <code>web/</code>
              </td>
              <td>이 문서 사이트의 소스 (React + Vite)</td>
            </tr>
            <tr>
              <td>
                <code>AGENTS.md</code>
              </td>
              <td>공동 작업 규칙의 단일 원본. Codex와 Claude가 함께 읽습니다</td>
            </tr>
            <tr>
              <td>
                <code>Progress.md</code>
              </td>
              <td>버전별 진행 기록과 검증 방법</td>
            </tr>
          </tbody>
        </table>
      </div>

      <h2>설계 문서</h2>
      <p>
        게임별 상세 설계는 게임 옆에 둡니다. Motorio의 비전 · 코어 루프 · 진행 · 세계관 · 첫 30분
        설계는 <code>motorio/design/</code>의 마크다운이 원본이고,{' '}
        <a href={site('/motorio/doc/')}>Motorio 문서</a>의 Vision 절이 그 파일을 그대로 렌더합니다.
        JSX로 옮겨 적지 않으므로 사본이 낡을 자리가 없습니다.
      </p>
      <p>
        무엇이 정해졌고 무엇이 아직 열려 있는지는{' '}
        <a href={site('/motorio/decisions/')}>Decisions</a>에 모읍니다.
      </p>
    </>
  );
}
