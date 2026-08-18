import React from 'react';

// One image for the whole level design. Inline SVG rather than a raster file so
// it stays crisp at any width, picks up the page's light/dark variables, and can
// be corrected in the same commit as the constants it documents.
//
// Every radius, second and item value below is read from motorio-motorio's
// Defs.gd. If a number here disagrees with the game, the game is right.

const CX = 480;
const CY = 300;
const MAX_TILES = 22; // Defs.WARM_MAX
const R = 230; // pixels at MAX_TILES
const t = (tiles) => (tiles * R) / MAX_TILES;
const diag = (tiles) => t(tiles) * 0.7071;

const FROST = '#5fbcdd';
const COPPER = '#e2703a';
const IRON = '#efc072';

// An annulus drawn as a fat stroke, which keeps the band's two radii legible in
// the markup instead of hiding them inside an arc path.
function Band({ from, to, color, opacity }) {
  return (
    <circle
      cx={CX}
      cy={CY}
      r={(t(from) + t(to)) / 2}
      fill="none"
      stroke={color}
      strokeWidth={t(to) - t(from)}
      opacity={opacity}
    />
  );
}

function Callout({ from, to, side, title, note }) {
  const anchor = side === 'left' ? 'end' : 'start';
  return (
    <>
      <line x1={from[0]} y1={from[1]} x2={to[0]} y2={to[1]} className="fig-leader" />
      <circle cx={from[0]} cy={from[1]} r="3.5" className="fig-dot" />
      <text x={to[0]} y={to[1]} textAnchor={anchor} className="fig-label">
        {title}
      </text>
      <text x={to[0]} y={to[1] + 20} textAnchor={anchor} className="fig-note">
        {note}
      </text>
    </>
  );
}

function Card({ x, title, children }) {
  return (
    <>
      <rect x={x} y="572" width="300" height="256" rx="12" className="fig-card" />
      <text x={x + 20} y="606" className="fig-card-title">
        {title}
      </text>
      {children}
    </>
  );
}

export function MotorioLevelMap() {
  return (
    <figure className="figure">
      <svg viewBox="0 0 960 860" role="img" aria-labelledby="lvlmap-t lvlmap-d">
        <title id="lvlmap-t">Motorio: Motorio 레벨 디자인 요약도</title>
        <desc id="lvlmap-d">
          코어를 중심으로 한 동심원 자원 배치도와 세 가지 관문, 하루 180초의 구성,
          생산 체인을 한 장에 담은 다이어그램.
        </desc>

        {/* ---------- radial resource map ----------
            Warmth goes underneath the ore bands. Drawn on top it greys them out,
            which reads as the starting radius hiding the resources it reaches. */}
        <circle cx={CX} cy={CY} r={R} className="fig-ring-max" />
        <circle cx={CX} cy={CY} r={t(7)} className="fig-warm" />
        <Band from={11} to={17} color={COPPER} opacity="0.28" />
        <Band from={4} to={9.5} color={FROST} opacity="0.32" />
        <circle cx={CX} cy={CY} r={t(7)} className="fig-warm-edge" />

        <circle cx={CX} cy={CY - t(9)} r="8" fill={COPPER} />
        <circle cx={CX} cy={CY + t(3)} r="8" fill={FROST} />
        <rect
          x={CX - t(2.5) - 7}
          y={CY + t(2.5) - 7}
          width="14"
          height="14"
          rx="3"
          className="fig-shelter"
        />
        <circle cx={CX} cy={CY} r="17" className="fig-core-halo" />
        <circle cx={CX} cy={CY} r="9" className="fig-core" />

        <Callout
          from={[CX, CY - t(9)]}
          to={[735, 120]}
          side="right"
          title="구리 광맥 · 북쪽 9칸"
          note="보장 배치 · 채굴기 전용"
        />
        <Callout
          from={[CX + t(14.5), CY - t(4)]}
          to={[735, 232]}
          side="right"
          title="구리 지대 · 반경 11–17칸"
          note="시작 시점에는 닿을 수 없다"
        />
        <Callout
          from={[CX + diag(7), CY + diag(7)]}
          to={[735, 372]}
          side="right"
          title="시작 온기 · 7칸"
          note="기지 단계마다 한 번에 넓어진다"
        />
        <Callout
          from={[CX + diag(22), CY + diag(22)]}
          to={[735, 470]}
          side="right"
          title="온기 최대 · 22칸"
          note="밖에서는 설비가 45% 속도"
        />
        <Callout
          from={[CX - t(7.5), CY - t(3)]}
          to={[225, 150]}
          side="left"
          title="수정 광맥 · 4–9.5칸"
          note="손으로 캘 수 있는 유일한 자원"
        />
        <Callout
          from={[CX, CY + t(3)]}
          to={[225, 330]}
          side="left"
          title="시작 수정 · 남쪽 3칸"
          note="모든 시드에서 보장"
        />
        <Callout
          from={[CX - t(2.5), CY + t(2.5)]}
          to={[225, 452]}
          side="left"
          title="숙소 · 남서 2.5칸"
          note="상자 3개 → 고양이 1마리"
        />

        <text x={CX} y="548" textAnchor="middle" className="fig-caption">
          자원은 월드 생성 시점에 고정된다. 열을 벌어도 자원이 생기지 않고 온기가 자랄 뿐이다
        </text>

        {/* ---------- three gates ---------- */}
        <Card x="20" title="세 가지 관문">
          {[
            ['온기', '갈 수 있는 거리'],
            ['일손', '동시에 돌릴 채굴기 수'],
            ['시간', '하루에 할 수 있는 양'],
          ].map(([key, value], i) => (
            <text key={key} x="40" y={648 + i * 46} className="fig-row">
              <tspan className="fig-key">{key}</tspan>
              <tspan x="40" dy="20" className="fig-note">
                {value}
              </tspan>
            </text>
          ))}
        </Card>

        {/* ---------- the day ---------- */}
        <Card x="330" title="하루 180초">
          <rect x="350" y="638" width="113" height="22" rx="3" className="fig-day" />
          <rect x="463" y="638" width="60" height="22" className="fig-dusk" />
          <rect x="523" y="638" width="67" height="22" rx="3" className="fig-night" />
          <text x="350" y="682" className="fig-note">
            낮 85초
          </text>
          <text x="463" y="682" className="fig-note">
            해질녘 45
          </text>
          <text x="590" y="682" textAnchor="end" className="fig-note">
            밤 50
          </text>
          <text x="350" y="722" className="fig-body">
            밤에는 온기 안에서도 체온이 떨어진다.
          </text>
          <text x="350" y="746" className="fig-body">
            코어 옆에 서 있기가 전략이 되지 않으므로
          </text>
          <text x="350" y="770" className="fig-body">
            숙소로 들어가는 것이 선택이 아니라 필요가 된다.
          </text>
          <text x="350" y="800" className="fig-note">
            자지 않고 넘기면 고양이들이 데려온다
          </text>
        </Card>

        {/* ---------- production chain ---------- */}
        <Card x="640" title="생산 체인">
          <circle cx="672" cy="646" r="11" fill={FROST} />
          <text x="694" y="651" className="fig-body">
            수정조각 <tspan className="fig-note">×2</tspan>
          </text>
          <path d="M 672 662 L 672 686" className="fig-arrow" />
          <circle cx="672" cy="706" r="11" fill={IRON} />
          <text x="694" y="711" className="fig-body">
            에너지결정 <tspan className="fig-note">열 5</tspan>
          </text>
          <text x="660" y="742" className="fig-note">
            교환기 5초 · 채굴기 4대와 맞물린다
          </text>
          <circle cx="672" cy="776" r="11" fill={COPPER} />
          <text x="694" y="781" className="fig-body">
            구리광석 <tspan className="fig-note">발전기 · 벨트</tspan>
          </text>
          <text x="660" y="812" className="fig-note">
            열은 오직 에너지결정에서만 나온다
          </text>
        </Card>
      </svg>
      <figcaption>
        모든 수치는 <code>motorio-motorio/scripts/Defs.gd</code>에서 가져왔습니다.
      </figcaption>
    </figure>
  );
}
