import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const GAMES = [
  {
    name: 'Motorio: One Shot',
    path: '/gamo/motorio-oneshot/',
    blurb:
      '얼어붙은 고원에서 고양이 작업자와 공장을 세웁니다. 하루가 끝나면 그날 모은 열이 정산되고, 공장과 온기는 다음 날로 이어집니다.',
  },
  {
    name: 'Motorio',
    path: '/gamo/motorio/',
    blurb: '기지를 키워 온기 반경을 넓히고 더 먼 자원에 닿는 장기 진행형 자동화 게임.',
  },
  {
    name: 'Nowhere',
    path: '/gamo/nowhere/',
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
        <a className="btn primary" href="/gamo/motorio-oneshot/">
          Motorio: One Shot 플레이
        </a>
        <a className="btn" href="/gamo/doc/">
          문서
        </a>
      </header>
      <section className="games">
        <div className="cards">
          {GAMES.map((game) => (
            <a className="card" href={game.path} key={game.path}>
              <b>{game.name}</b>
              <span>{game.blurb}</span>
            </a>
          ))}
        </div>
      </section>
    </>
  );
}

createRoot(document.getElementById('root')).render(<Home />);
