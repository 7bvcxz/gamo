'use client';

import { game, site } from '../lib/links.js';
import React from 'react';

const GAMES = [
  {
    name: 'Motorio: One Shot',
    path: game('/motorio-oneshot/'),
    blurb:
      '얼어붙은 고원에서 고양이 작업자와 공장을 세웁니다. 하루가 끝나면 그날 모은 열이 정산되고, 공장과 온기는 다음 날로 이어집니다.',
    extra: [
      { href: site('/motorio-oneshot/graphic/'), label: '그래픽' },
      { href: site('/motorio-oneshot/graphic/proposals/'), label: '그래픽 제안' },
      { href: site('/motorio-oneshot/doc/'), label: '문서' },
    ],
  },
  {
    name: 'Motorio',
    path: game('/motorio/'),
    blurb: '기지를 키워 온기 반경을 넓히고 더 먼 자원에 닿는 장기 진행형 자동화 게임.',
    extra: [{ href: site('/motorio/doc/'), label: '문서' }],
  },
  {
    name: 'Nowhere',
    path: game('/nowhere/'),
    blurb: '방과 방을 오가는 실험용 프로토타입.',
  },
];

function Home() {
  return (
    <>
      <header className="hero">
        <h1>gamo</h1>
        <p>
          Godot으로 만든 게임 모음. 설치 없이 브라우저에서 바로 실행됩니다.
        </p>
        <a className="btn primary" href={game('/motorio-oneshot/')}>
          Motorio: One Shot 플레이
        </a>
        <a className="btn" href={site('/doc/')}>
          문서
        </a>
      </header>
      <section className="games">
        <div className="cards">
          {GAMES.map((game) => (
            <div className="card" key={game.path}>
              <a href={game.path}>
                <b>{game.name}</b>
                <span>{game.blurb}</span>
              </a>
              {game.extra && (
                <p className="card-links">
                  {game.extra.map((link) => (
                    <a key={link.href} href={link.href}>
                      {link.label}
                    </a>
                  ))}
                </p>
              )}
            </div>
          ))}
        </div>
      </section>
    </>
  );
}

export default Home;
