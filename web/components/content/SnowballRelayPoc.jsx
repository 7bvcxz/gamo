import React from 'react';

// A proof of concept is documented as one: the question first, the answer
// honestly unknown, and what was actually measured.
export function SnowballRelayPoc() {
  return (
    <article className="doc">
      <h1>Snowball Relay</h1>
      <p className="lede">
        눈덩이를 가볍게 한 번 밀면 혼자 굴러가며 눈을 모읍니다. 증분 게임 POC 두 개 중 첫 번째(관성).
      </p>

      <h2>확인하려는 질문</h2>
      <blockquote>
        손은 가끔만 쓰는데도 &ldquo;계속 자라고 있다&rdquo;는 느낌이 재미있는가?
      </blockquote>
      <p>
        <b>아직 답이 없습니다.</b> 사람이 해 보기 전에는 재미도 피로도도 알 수 없습니다. 아래 수치는 자동
        브라우저 조작이 잰 기술 증거이고, 사람의 즐거움이나 손의 피로가 아닙니다.
      </p>

      <h2>하는 법</h2>
      <ul>
        <li>오른쪽 아래 칸(또는 버튼이 아닌 아무 곳)을 <b>짧게 쓸어</b> 눈덩이를 밉니다. 방향은 상관없습니다.</li>
        <li>놓은 뒤에도 눈덩이가 굴러가며 눈(통화는 이것 하나)을 모으고 커집니다. 질량은 쓰는 돈이 아니라 눈덩이의 상태입니다.</li>
        <li>왼쪽 아래 다섯 버튼: 질량·힘·관성(오래 구름)·끌어당김·충격(부서지는 소품 보상). 모은 눈만큼 차오르고, 살 수 있으면 반짝입니다.</li>
        <li>연타는 쓸모가 줄어듭니다(속도 상한과 연속 입력 감쇠). 기다려도 잃는 것이 없고, 누르고 있을 필요도 없습니다.</li>
        <li>키보드: 스페이스/방향키 = 밀기, 1–5 = 업그레이드, M = 소리, H = 숫자 숨김.</li>
      </ul>

      <h2>실측 (자동 브라우저, 폰 390×844, 실제 터치 이벤트, 새 게임으로 3분)</h2>
      <table>
        <thead>
          <tr><th>시각</th><th>공 반지름(시작=1)</th><th>구르는 시간</th><th>업그레이드 합</th></tr>
        </thead>
        <tbody>
          <tr><td>10초</td><td>1.25</td><td>2.8초</td><td>2</td></tr>
          <tr><td>30초</td><td>1.73</td><td>5.6초</td><td>8</td></tr>
          <tr><td>60초</td><td>2.85</td><td>7.5초</td><td>17</td></tr>
          <tr><td>120초</td><td>4.87</td><td>13.0초</td><td>29</td></tr>
          <tr><td>180초</td><td>6.65</td><td>17.8초</td><td>36</td></tr>
        </tbody>
      </table>
      <p>
        첫 눈은 첫 밀기 1.1초 뒤, 첫 구매는 3.4초 뒤였습니다. 3분 동안 17번 밀었습니다. 한계: 사람이 아니라
        스크립트이고, 10초 안에 입력을 이해하는지·피로·다시 하고 싶은지는 <b>검증되지 않았습니다</b>.
      </p>
    </article>
  );
}
