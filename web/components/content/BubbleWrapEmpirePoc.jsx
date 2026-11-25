import React from 'react';

// A proof of concept is documented as one: the question first, the answer
// honestly unknown, and what was actually measured.
export function BubbleWrapEmpirePoc() {
  return (
    <article className="doc">
      <h1>Bubble Wrap Empire</h1>
      <p className="lede">
        뽁뽁이를 가볍게 한 번 누르면 터짐이 파도처럼 번집니다. 증분 게임 POC 두 개 중 두 번째(연쇄 반응).
      </p>

      <h2>확인하려는 질문</h2>
      <blockquote>
        손은 가끔만 쓰는데도 &ldquo;큰 파도가 이어진다&rdquo;는 느낌이 재미있는가?
      </blockquote>
      <p>
        <b>아직 답이 없습니다.</b> 사람이 해 보기 전에는 재미도 피로도도 알 수 없습니다. 아래 수치는 자동
        브라우저 조작이 잰 기술 증거이고, 사람의 즐거움이나 손의 피로가 아닙니다.
      </p>

      <h2>하는 법</h2>
      <ul>
        <li>
          오른쪽 아래 칸은 시트의 <b>작은 지도</b>입니다. 엄지를 올린 곳에 대응하는 시트 위 뽁뽁이에 분홍 고리가
          뜨고, <b>놓으면</b> 거기서 터집니다. 정밀한 조준은 필요 없고, 시트를 직접 눌러도 됩니다.
        </li>
        <li>한 번 만지면 한 번만 터뜨립니다(아주 짧은 쓸기도 같은 한 번). 문지르거나 충전할 필요가 없습니다.</li>
        <li>놓은 뒤 이웃이 차례로 부풀었다 터지며 번집니다. 통화는 POP 하나, 터진 뽁뽁이는 부드럽게 다시 부풉니다.</li>
        <li>
          왼쪽 아래 다섯 버튼: 반경·연쇄(몇 칸 번지나)·값·리필 속도·메가(저절로 차오르는 큰 파도, 준비되면 엄지 칸 테두리가 금색).
        </li>
        <li>가득 찬 뽁뽁이만 터지므로 연타는 시트를 비울 뿐 더 벌지 못합니다. 기다려도 잃는 것이 없습니다.</li>
        <li>키보드: 스페이스 = 가운데에서 터뜨리기, 1–5 = 업그레이드, M = 소리, H = 숫자 숨김.</li>
      </ul>

      <h2>실측 (자동 브라우저, 폰 390×844, 실제 터치 이벤트, 새 게임으로 3분)</h2>
      <table>
        <thead>
          <tr><th>시각</th><th>마지막 파도(뽁뽁이 수)</th><th>파도 시간</th><th>업그레이드 합</th><th>시트 중 찬 것</th></tr>
        </thead>
        <tbody>
          <tr><td>10초</td><td>1</td><td>0.04초</td><td>1</td><td>68/70</td></tr>
          <tr><td>30초</td><td>5 (최대 13)</td><td>0.22초</td><td>4</td><td>65/70</td></tr>
          <tr><td>60초</td><td>16 (최대 31)</td><td>0.38초</td><td>12</td><td>54/70</td></tr>
          <tr><td>120초</td><td>70(시트 전체)</td><td>0.44초</td><td>30</td><td>7/70</td></tr>
          <tr><td>180초</td><td>70(시트 전체)</td><td>0.33초</td><td>38</td><td>70/70</td></tr>
        </tbody>
      </table>
      <p>
        첫 터짐은 첫 터치 0.6초 뒤였고, 3분 동안 39번 만졌으며 <b>39번 모두 정확히 한 번의 트리거</b>였습니다(터치 중복 없음).
        한계: 사람이 아니라 스크립트이고, 10초 안에 이해하는지·피로·다시 하고 싶은지는 <b>검증되지 않았습니다</b>.
      </p>

    </article>
  );
}
