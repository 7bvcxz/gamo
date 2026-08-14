'use client';

import { game, site } from '../lib/links.js';
import React from 'react';

const GAMES = [
  {
    name: 'Motorio',
    path: game('/motorio/'),
    blurb:
      '얼어붙은 고원에서 고양이 작업자와 공장을 세웁니다. 하루가 끝나면 그날 모은 열이 정산되고, 공장과 온기는 다음 날로 이어집니다.',
    extra: [
      { href: site('/motorio/graphic/'), label: '그래픽' },
      { href: site('/motorio/graphic/proposals/'), label: '그래픽 제안' },
      { href: site('/motorio/doc/'), label: '문서' },
    ],
  },
  {
    name: 'Gunslinger',
    path: game('/gunslinger/'),
    blurb:
      '서부 총잡이 1대1 한방 대결. 2~6초 뒤 신호가 뜨고, 먼저 뽑은 쪽이 이깁니다. 먼저 움직이면 반칙패.',
    extra: [{ href: site('/gunslinger/doc/'), label: '문서' }],
  },
  {
    name: 'looproom',
    path: game('/looproom/'),
    blurb:
      '한 화면에 한 방. 미니맵 없이 18개의 방을 머릿속 지도로 찾아갑니다. 가짜 문을 지나면 시작 방으로 돌아갑니다.',
    extra: [{ href: site('/looproom/doc/'), label: '문서' }],
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
        <a className="btn primary" href={game('/motorio/')}>
          Motorio: Motorio 플레이
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
