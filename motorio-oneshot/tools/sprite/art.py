"""What the source artwork is, and where each piece ended up.

One table, imported by everything that needs it: the portrait builder that cuts
game assets out of these files, and the publisher that puts them on the graphics
page. Written down once because the alternative is writing "cat_pink is the SR"
in two places and having them disagree the first time a grade is reassigned --
and the page would be the one that lied, because nothing tests a caption.
"""

## Which reference art each cat grade is cut from. SSR is absent on purpose: the
## SSR is a pig, and the pig is drawn in Icons.gd rather than cut from a file.
GRADE_ARTWORK = [
    ("o", "cat_org", "O 등급 · 기본 고양이. 게임 안의 걷기·대기·식사·작업 시트도 전부 이 그림에서 생성했습니다."),
    ("n", "cat_baby", "N 등급."),
    ("r", "cat_green", "R 등급."),
    ("sr", "cat_pink", "SR 등급."),
]

## The ground sheet the game actually draws, and what the rest are for. The note
## is the honest state of each file rather than a plan: several of these are
## bought and unused, and saying so is the point of listing them.
TILE_SHEETS = [
    ("tile_org_16", "기본 눈 바닥 · 4×4",
     "게임에서 사용 중입니다. tools/sprite/build_tiles.py가 64px 아틀라스로 잘라 바닥 전체를 이걸로 그립니다."),
    ("tile_rock_47", "바위 · 47블롭",
     "게임에서 사용 중입니다. 바닥의 10%에 1~12칸 덩어리로 깔리고, 이웃 여덟 방향에 따라 타일이 자동으로 이어집니다. 다만 이름과 달리 47가지 연결 경우가 다 들어 있지는 않아서 — 실제로는 약 15가지에 변형이 붙어 있습니다 — 없는 경우는 회전과 근사로 채웁니다."),
    ("tile_crystal_6", "수정 광맥 · 6단계", "아직 사용하지 않습니다. 현재 광맥은 코드로 그린 결정 조각입니다."),
    ("tile_copper_6", "구리 광맥 · 6단계", "아직 사용하지 않습니다."),
    ("tile_coal_6", "석탄 광맥 · 6단계", "아직 사용하지 않습니다. 석탄은 One Shot에 없는 자원입니다."),
    ("tile_iron_6", "철 광맥 · 6단계", "아직 사용하지 않습니다. 철은 One Shot에 없는 자원입니다."),
    ("tile_gold_6", "금 광맥 · 6단계", "아직 사용하지 않습니다."),
    ("tile_uranium_6", "우라늄 광맥 · 6단계", "아직 사용하지 않습니다."),
]

## Every cat reference in refs/, with what it is. The ones with no grade are the
## unspent half of the set.
CAT_NOTES = {
    "cat_org": "주황 태비 · 빨간 모자.",
    "cat_baby": "밝은 주황 · 빨간 목도리.",
    "cat_black": "턱시도 · 나비넥타이.",
    "cat_cozy": "흰 장모 · 귀마개 · 오드아이.",
    "cat_cute": "삼색 · 검은 귀.",
    "cat_artist": "주황 태비 · 베레모.",
    "cat_calm": "회색 태비 · 파란 스카프.",
    "cat_fisher": "샴 · 털모자.",
    "cat_green": "연두 · 리본.",
    "cat_pink": "보라 태비 · 연두 리본.",
}


def grade_of(name: str) -> str:
    """The grade this artwork was assigned, or an empty string."""
    for grade, source, _note in GRADE_ARTWORK:
        if source == name:
            return grade.upper()
    return ""
