# Store and web text — Popcorn & Glory 0.48.1 (release candidate, not published anywhere)

Every claim below is something the build does now (the evidence is in `RELEASE_CHECKLIST.md`). Not
claimed: that it is fun — no person has rated it yet. Not added: ads, in-app purchases, accounts,
analytics. **Nothing here has been submitted to any store or to HeyDive; that is the owner's call.**

## English

**Popcorn & Glory**

*Hold. Pop. Grow a three-floor popcorn factory.*

Press and hold the kettle, watch the heat sweep round the ring, and let go in the gold for a perfect
pop. Every perfect pop fills a row of gold kernels until the whole batch bursts.

Your popcorn rises up a glass tube to the packing floor. It is bagged and shelved there, then
served at the counter to customers who each want their own size and flavor. Watch the slow floor
light up red, and decide what to grow next:

- a kettle that changes shape as it levels up, from a street cart to a glory carnival machine;
- a sign that brings more customers, and a packing station that keeps up with them;
- forty kinds of machines across the kitchen, packing and shop floors — up to 44 running at once;
- five flavors, from Classic Butter to Cocoa Swirl, each sold to the customers who ask for it;
- news events that change the crowd for a while, and optional contests with bronze, silver and gold.

No text to read. The game shows you what to do. Your shop is saved in your browser, and it keeps
playing after it has loaded, even offline. No ads, no purchases, no account.

Plays in a web browser on phones (portrait) and computers (mouse or keyboard).

## 한국어

**팝콘 & 글로리**

*누르고, 터뜨리고, 3층 팝콘 공장을 키우세요.*

냄비를 꾹 누르면 열이 고리를 따라 돕니다. 금색에서 손을 떼면 완벽한 팝! 완벽한 팝마다 금 알갱이 줄이 차오르고, 다 차면 한 판이 통째로 터집니다.

팝콘은 유리관을 타고 포장 층으로 올라갑니다. 거기서 봉지에 담겨 진열되고, 저마다 원하는 크기와 맛이 있는 손님에게 계산대에서 건네집니다. 느린 층이 빨갛게 빛나면 다음에 무엇을 키울지 고르세요:

- 단계마다 모양이 바뀌는 냄비 — 길거리 수레에서 글로리 카니발 기계까지;
- 손님을 더 부르는 간판, 그 손님을 따라잡는 포장대;
- 부엌·포장·가게 세 층의 기계 40종 — 한 번에 44대까지;
- 클래식 버터부터 코코아 스월까지 맛 다섯, 그 맛을 원하는 손님에게;
- 한동안 손님을 바꾸는 뉴스, 동·은·금이 걸린 자유로운 대회.

읽을 글이 없습니다. 게임이 할 일을 보여 줍니다. 가게는 이 브라우저에 저장되고, 한 번 열린 뒤에는 오프라인에서도 계속됩니다. 광고·결제·계정이 없습니다.

휴대폰(세로)과 컴퓨터(마우스·키보드)의 웹 브라우저에서 합니다.

## True screenshots (`evidence/step48/store/`)

These are screenshots of the published 0.48.0 in Chromium, untouched (no editing, no mock-ups). Its factory
screens are the same in 0.48.1, which only adds the factory to the chooser. Each is set up as described:

| file | what | how it was set up |
|---|---|---|
| `01_first_screen_phone.png` | The first screen of a new factory | A fresh browser |
| `02_perfect_phone.png` | A perfect pop, 0.45 s after letting go in the gold | A fresh browser, one real hold |
| `03_minute30_phone.png` | A factory at 30 minutes: 8 machines, sign 4 | The career simulation's own save at minute 30 (`tools/sim/career39.gd`, an average hand) |
| `04_factory44_desktop.png` | 44 machines at sign 8, desktop | The prepared 44-machine save (`evidence/step47/fixtures/`, made through the dev bridge) |
| `05_factory44_phone.png` | The same factory on a phone | The same save |

## Teaser (`evidence/step48/teaser/teaser_phone_0480.webm`, 25 s, 390×844)

Genuine game footage: three cuts of Playwright's recording of the published 0.48.0 on a phone-sized
browser — a new factory and its first held pop, the career's 30-minute factory with a held pop, and the
44-machine factory with a held pop. The cuts are joined end to end, with no effects, overlays or music
added; the game's sound is not recorded in browser footage. It shows the game as it plays, so it
is not a polished trailer.

## Credits

See `CREDITS.md`. In short: code, drawings and synthesized sounds from this repository; Godot
Engine (MIT); Open Sans (SIL OFL 1.1).
