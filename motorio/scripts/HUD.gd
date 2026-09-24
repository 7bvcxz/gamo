extends Control

## All screen-space UI. Immediate-mode drawing keeps the whole layout readable
## in one file; every position below is expressed against a screen edge so the
## HUD never depends on a fixed window size.

## Five places, one per corner and one along the bottom, and nothing anywhere
## else while she is walking around:
##
##   top-left      her: warmth, the day, and what she owns
##   top-right     the world: the time of day, the weather, what she is after
##   bottom-left   what just happened, and the one key that matters right now
##   bottom-right  where she is
##   bottom-centre what is in her hands
##
## Every plate is drawn by HudStyle, and every spacing below is one of its
## tokens -- so the five read as one interface rather than five that happen to
## share a screen. The middle of the screen belongs to the world.
const MARGIN := HudStyle.OUTER_MARGIN
## One width for the top-left card, rather than a width measured from its text.
## The widest thing in it is a resource row with a rate: icon, name, a
## right-aligned amount and "+12.3/분".
const COLUMN_W := 236.0
## The top-right card. A little narrower: its lines are sentences and wrap.
const WORLD_W := 232.0
const SETTINGS_BUTTON := 30.0
## Smallest logical canvas the layout is designed to hold. The height is not a
## round number: it is the status panel (190) plus the hotbar and its chip (154)
## plus the space the touch pad claims along the bottom (~180), which is the
## stack that has to coexist before anything is allowed to scale further.
const MIN_LOGICAL := Vector2(340.0, 520.0)
const SLOT_GAP := 8.0
const SLOT_MAX_W := 56.0
const SLOT_MIN_W := 44.0
const SLOT_H := 56.0

var main
var message_color: Color = Defs.COL_TEXT
## Rectangles published for the touch layer, so the pad hit-tests exactly what
## was drawn rather than recomputing the layout and drifting out of sync.
var hotbar_rects: Array[Rect2] = []
var direction_rect := Rect2()
var settings_button_rect := Rect2()
var map_button_rect := Rect2()
var log_button_rect := Rect2()
var log_card_rect := Rect2()
var quest_card_rect := Rect2()
var map_card_rect := Rect2()
var map_slider_rect := Rect2()
var dragging_map_zoom: bool = false
## The slot machine: the corner button that opens it, the card, and its three
## price buttons. Published the same way every other target is, so touch
## hit-tests exactly what was drawn instead of recomputing the layout.
var gacha_button_rect := Rect2()
var gacha_card_rect := Rect2()
var gacha_pull_rects: Array[Rect2] = []
var settings_close_rect := Rect2()
## Which slot list is up, if any: 0 none, 1 saving, 2 loading. One list serving
## both is deliberate -- the picture of what is in each slot is exactly the thing
## you need whether you are about to write over it or read it.
var slot_picker: int = 0
var slot_index: int = 1
## First slot shown in the window onto the list.
var slot_scroll: int = 0
var slot_rects: Array[Rect2] = []
## Restart is one tap from erasing a factory, so it asks once. Seconds remaining
## on the confirmation; zero means the button is in its normal state.
var restart_armed: float = 0.0
## Brief acknowledgement after a manual save, so the button visibly did something.
var saved_flash: float = 0.0
## One entry per settings row: 0 is the HUD size, 1 is the world's.
var slider_track_rects: Array[Rect2] = [Rect2(), Rect2()]
## Deliberately taller than the tracks they drive: an 8px bar is not a touch
## target, and the two rows must not steal each other's misses.
var slider_hit_rects: Array[Rect2] = [Rect2(), Rect2()]
var dragging_slider: int = -1
## Which row the keyboard is on, for players without a pointer.
var settings_row: int = 0

var _repaint := 0.0

func _process(delta: float) -> void:
	if main != null:
		_apply_scale()
		_layout()
	# Both of these are short-lived button states rather than game state, so they
	# live and expire here rather than in the orchestrator.
	restart_armed = maxf(0.0, restart_armed - delta)
	saved_flash = maxf(0.0, saved_flash - delta)
	_repaint += delta
	if _repaint < 1.0 / 30.0:
		return
	_repaint = 0.0
	queue_redraw()

## Two multipliers. The base is the platform's: desktop players sit close to a
## large screen and want the HUD out of the way, while a phone reports a logical
## viewport far wider than its physical one and needs everything enlarged just to
## stay legible. On top of that sits the player's own setting.
func _apply_scale() -> void:
	var touch_pad: bool = main.touch != null and main.touch.visible
	var view: Vector2 = get_viewport_rect().size
	var want: float = scale_for(view, touch_pad, float(main.ui_scale))
	var wanted_size: Vector2 = view / want
	# Compare the size too, so a rotation or resize is picked up even when the
	# scale itself has not moved.
	if is_equal_approx(scale.x, want) and size.is_equal_approx(wanted_size):
		return
	scale = Vector2(want, want)
	size = wanted_size

## The HUD's scale on a screen of this size. A scale the screen cannot hold is
## worse than a small one -- the status card and the hotbar start overlapping and
## the player loses the cards entirely -- so it is capped at the largest value
## that still leaves a workable canvas. Static so a test can ask it about a
## screen the machine running the test does not have.
static func scale_for(view: Vector2, touch_pad: bool, ui: float) -> float:
	var base: float = Defs.UI_SCALE_TOUCH_BASE if touch_pad else Defs.UI_SCALE_DESKTOP_BASE
	var want: float = base * ui
	want = minf(want, minf(view.x / MIN_LOGICAL.x, view.y / MIN_LOGICAL.y))
	return maxf(want, 0.1)

## The bottom edge everything along the bottom stands on: above the touch pad
## when there is one, because a panel drawn under a thumb button can never be
## read or pressed.
func floor_y() -> float:
	return size.y - MARGIN - bottom_reserved()

## Square slots. The row shrinks rather than running off the screen once the
## player scales the UI up, which is the whole point of letting them.
func hotbar_slot() -> Vector2:
	var count: float = float(main.TOOLS.size()) if main != null else 1.0
	var available: float = size.x - MARGIN * 2.0 - (count - 1.0) * SLOT_GAP
	var side: float = clampf(available / count, SLOT_MIN_W, SLOT_MAX_W)
	return Vector2(side, side)

func hotbar_origin() -> Vector2:
	var slot: Vector2 = hotbar_slot()
	var total: float = float(maxi(1, main.unlocked_tools().size())) * (slot.x + SLOT_GAP) - SLOT_GAP
	var bottom: float = floor_y() - slot.y
	# And never over the gacha button, which owns the bottom-left corner when it
	# exists. On the narrowest canvas the layout supports, centring would put the
	# first slot straight on top of it, and a button that cannot be pressed is
	# worse than a row that is slightly off centre.
	var left_limit: float = MARGIN
	if gacha_button_rect.size.x > 0.0:
		left_limit = MARGIN + GACHA_BUTTON.x + SLOT_GAP
	return Vector2(maxf(size.x * 0.5 - total * 0.5, left_limit), bottom)

## The line over the slots that names what is in her hand.
const CAPTION_H := 16.0

## The top of everything the hotbar owns, caption included. Anything that has
## to stay clear of the bottom-centre measures from here.
func hotbar_top() -> float:
	return hotbar_origin().y - CAPTION_H - HudStyle.ITEM_GAP

## The horizontal span the hotbar and its caption take up.
func hotbar_span() -> Vector2:
	var slot: Vector2 = hotbar_slot()
	var origin: Vector2 = hotbar_origin()
	var total: float = float(maxi(1, main.unlocked_tools().size())) * (slot.x + SLOT_GAP) - SLOT_GAP
	var caption: float = HudStyle.width_of(hotbar_caption(), HudStyle.TEXT_SMALL)
	var half: float = maxf(total, caption) * 0.5
	var centre: float = origin.x + total * 0.5
	return Vector2(centre - half, centre + half)

## Under the icon strip, so the gear owns the very top-left corner.
func status_top() -> float:
	return MARGIN + SETTINGS_BUTTON + HudStyle.ITEM_GAP

## Two bars: warmth, then the day. The warmth bar is the long, thick one -- the
## only readout in the corner that is ever an emergency.
const STATUS_ROW := 18.0
const STATUS_H := STATUS_ROW * 2.0
## Where a bar starts: past the glyph that says which bar it is.
const BAR_X := 18.0
const BAR_H := 8.0
const DAY_BAR_H := 5.0
## The day bar is deliberately shorter than the warmth bar.
const DAY_BAR_SHARE := 0.62

## The two bars, inside the card's padding.
func status_rect() -> Rect2:
	var card: Rect2 = status_card_rect()
	return Rect2(card.position + Vector2.ONE * HudStyle.PANEL_PADDING,
		Vector2(card.size.x - HudStyle.PANEL_PADDING * 2.0, STATUS_H))

## The whole top-left plate: the bars, and the ledger under them.
func status_card_rect() -> Rect2:
	var height: float = HudStyle.PANEL_PADDING * 2.0 + STATUS_H
	var rows: int = resource_rows().size()
	if rows > 0:
		height += HudStyle.SECTION_GAP + float(rows) * RESOURCE_ROW
	return Rect2(MARGIN, status_top(), column_width(), height)

## And never wider than the screen it is drawn on.
func column_width() -> float:
	return minf(COLUMN_W, size.x - MARGIN * 2.0)

## Whether the world card fits across the top beside the status card. On a phone
## held upright it does not, and it stacks under it instead of on top of it.
func world_beside_status() -> bool:
	return size.x >= column_width() + WORLD_W + MARGIN * 3.0

## The bottom of everything stacked in the top-left corner.
func left_column_bottom() -> float:
	var bottom: float = status_card_rect().end.y
	if not world_beside_status():
		var world: Rect2 = world_card_rect()
		if world.size.y > 0.0:
			bottom = maxf(bottom, world.end.y)
	return bottom

## Where a window that hangs in the left column (the throughput card) starts.
func meter_top() -> float:
	return left_column_bottom() + HudStyle.SECTION_GAP

## Screen space the touch pad occupies along the bottom, in HUD-local units. The
## pad is laid out in viewport pixels and the HUD in scaled ones, so the two only
## agree once this crosses the scale -- and if they disagree the hotbar ends up
## drawn underneath the thumb buttons.
func bottom_reserved() -> float:
	if main.touch == null or not main.touch.visible:
		return 0.0
	return float(main.touch.reserved_height()) / maxf(scale.x, 0.01) + 10.0

func _layout() -> void:
	# The gacha first: the hotbar keeps clear of its button, when there is one.
	var floor_line: float = floor_y()
	gacha_button_rect = Rect2(MARGIN, floor_line - GACHA_BUTTON.y, GACHA_BUTTON.x, GACHA_BUTTON.y)
	_layout_gacha()
	var slot: Vector2 = hotbar_slot()
	var origin: Vector2 = hotbar_origin()
	# One rect per tool, always -- a locked slot gets an empty rect so that
	# hotbar_rects stays parallel to TOOLS and a tap can be matched to the tool
	# it landed on. Only the unlocked ones take up space on screen.
	hotbar_rects.clear()
	hotbar_rects.resize(main.TOOLS.size())
	var shown := 0
	for index in main.TOOLS.size():
		if not main.tool_unlocked(main.TOOLS[index]):
			hotbar_rects[index] = Rect2()
			continue
		hotbar_rects[index] = Rect2(origin + Vector2(float(shown) * (slot.x + SLOT_GAP), 0), slot)
		shown += 1
	# Laid out always, drawn and hit-tested only while it means something (the
	# gun in her hand, loaded with a machine that has a front).
	var label: String = _direction_label(Vector2i.RIGHT)
	var width: float = HudStyle.width_of(label, HudStyle.TEXT_SMALL) + 40.0
	direction_rect = Rect2(size.x * 0.5 - width * 0.5, hotbar_top() - 24.0 - HudStyle.ITEM_GAP,
		width, 24.0)
	settings_button_rect = Rect2(MARGIN, MARGIN, SETTINGS_BUTTON, SETTINGS_BUTTON)
	# Beside the gear, sharing its top row. Three square buttons in the corner
	# read as one strip of controls.
	map_button_rect = Rect2(MARGIN + SETTINGS_BUTTON + HudStyle.ITEM_GAP, MARGIN,
		SETTINGS_BUTTON, SETTINGS_BUTTON)
	log_button_rect = Rect2(MARGIN + (SETTINGS_BUTTON + HudStyle.ITEM_GAP) * 2.0, MARGIN,
		SETTINGS_BUTTON, SETTINGS_BUTTON)
	var log_w: float = minf(520.0, size.x - MARGIN * 2.0)
	var log_h: float = minf(420.0, size.y - MARGIN * 2.0)
	log_card_rect = Rect2(size.x * 0.5 - log_w * 0.5, size.y * 0.5 - log_h * 0.5,
		log_w, log_h)
	# The quest list, narrower than the record and only as tall as it needs to be:
	# it is a checklist of three or four short lines, and a fixed card meant most
	# of it was empty. Measured from the same numbers the drawing uses.
	var quest_w: float = minf(430.0, size.x - MARGIN * 2.0)
	var quest_h: float = minf(quest_card_height(quest_w), size.y - MARGIN * 2.0)
	quest_card_rect = Rect2(size.x * 0.5 - quest_w * 0.5, size.y * 0.5 - quest_h * 0.5,
		quest_w, quest_h)
	_layout_map()
	minimap_rect = _minimap_box()
	_layout_settings()

## --- The slot machine ---------------------------------------------------------
## Tall enough for two rows of text with the second one's descenders inside the
## panel. At 44 the word sat on the border, which reads as a rendering fault
## rather than as a button.
const GACHA_BUTTON := Vector2(78.0, 48.0)
const GACHA_CARD_H := 396.0
const GACHA_PULL_H := 46.0
const GACHA_REEL := 56.0

func _layout_gacha() -> void:
	# An empty rect while the feature is off. Both the drawing and the tap test
	# already check the size, so zeroing it here removes the button from the
	# screen and from the touch layer at once.
	if not Defs.GACHA_ENABLED:
		gacha_button_rect = Rect2()
	gacha_card_rect = _card_rect(GACHA_CARD_H)
	var card: Rect2 = gacha_card_rect
	var gap := 10.0
	var width: float = (card.size.x - 44.0 - gap * 2.0) / float(Defs.GACHA_COUNTS.size())
	var top: float = card.size.y - 112.0
	gacha_pull_rects.clear()
	for index in Defs.GACHA_COUNTS.size():
		gacha_pull_rects.append(Rect2(
			card.position + Vector2(22.0 + float(index) * (width + gap), top),
			Vector2(width, GACHA_PULL_H)))

## Which price button a point falls on, or -1. Used by touch, which has no
## arrow keys to move the cursor with.
func gacha_button_at(point: Vector2) -> int:
	if not main.gacha_open:
		return -1
	for index in gacha_pull_rects.size():
		if (gacha_pull_rects[index] as Rect2).has_point(point):
			return index
	return -1

## Two sliders, then a row of two actions, then close. Taller than it was because
## Esc opens this panel now: it is the only stopped screen, so everything a
## player wants while stopped has to be reachable from it.
const SLOT_CARD_H := 372.0
const SETTINGS_SLIDER_H := 92.0
const SETTINGS_ACTION_H := 50.0
const SETTINGS_ROW_TOP := 88.0
## The strip: where it starts, how tall it is, and how far it is inset.
const SETTINGS_TAB_TOP := 62.0
const SETTINGS_TAB_H := 62.0
const SETTINGS_TAB_PAD := 22.0

## One ordered list, top to bottom, rather than two sliders in the middle and a
## row of buttons at the bottom.
##
## The panel had the sliders on the arrow keys and the actions on letters, which
## meant half of it was reachable by walking down it and half of it was not --
## and the half that was not is the half a player looks for while stopped. Every
## row is on the same cursor now.
const ROW_SAVE := 0
const ROW_LOAD := 1
const ROW_TITLE := 2
const ROW_GAME := 3
const ROW_UI := 4
## Closing is a row too. It was the one button on the panel the cursor could not
## reach, which on a pad with no Escape key meant the way out was a tap and only
## a tap.
const ROW_CLOSE := 5
const ROW_LABELS := ["저장하기", "불러오기", "메인화면", "게임 화면 크기", "화면 UI 크기", "닫기"]

## --- The strip -----------------------------------------------------------------
## Six things this panel can do, left to right, as pictures.
##
## It used to be one vertical list where every capability was a row of its own --
## save, load, main menu, and the two scales, each taking a full-width band, so
## the panel was six stacked rectangles and reading it meant reading five labels
## top to bottom. A strip of icons is read in one glance and leaves the body of
## the card free for whatever the chosen one needs, which is what let the guide
## exist at all: there was no room for a keyboard in a list of rows.
##
## The row constants below did not move. `settings_slider_of` still answers 0 for
## the UI scale and 1 for the game scale, because that numbering is what the
## nudge, the range and the drag all speak -- reordering the display must not
## renumber the values, and this rework reordered the display completely.
const TAB_SAVE := 0
const TAB_LOAD := 1
const TAB_GAME := 2
const TAB_GUIDE := 3
const TAB_TITLE := 4
const TAB_QUIT := 5
const TAB_LABELS := ["저장", "로드", "설정", "가이드", "메인", "종료"]

## Which of them this panel is offering. Opened from the title there is no run to
## save, load or leave, so those three are absent rather than present-and-refusing
## -- a control that is there and says no teaches the player to skip past it.
func settings_tabs() -> Array[int]:
	var out: Array[int] = []
	if main.state_before_settings != main.State.TITLE:
		out.append_array([TAB_SAVE, TAB_LOAD])
	out.append_array([TAB_GAME, TAB_GUIDE])
	if main.state_before_settings != main.State.TITLE:
		out.append(TAB_TITLE)
	# On the web there is nowhere to quit to, and an icon that does nothing is
	# worse than no icon -- the title menu already hides its own 종료 this way.
	if not OS.has_feature("web"):
		out.append(TAB_QUIT)
	return out

## Which icon the strip is on, as the TAB_ id rather than as a position in the
## list.
##
## It was a position first, and that is a bug: the strip is six icons in a run
## and three from the title, so "the third one" is 설정 in one and 종료 in the
## other. Opening the panel from the title after opening it from a run selected
## whatever happened to be third. An id cannot mean two things.
var settings_tab: int = TAB_GAME

func settings_tab_kind() -> int:
	var tabs: Array[int] = settings_tabs()
	if tabs.has(settings_tab):
		return settings_tab
	return tabs[0] if not tabs.is_empty() else TAB_GAME

## Where that icon sits right now, for the strip's own cursor and for stepping.
func settings_tab_index() -> int:
	var found: int = settings_tabs().find(settings_tab_kind())
	return maxi(0, found)

## The rows in the body of the card: only the scales have any, and only under
## their own tab. Everything else acts the moment its icon is chosen.
func settings_rows() -> Array[int]:
	# Built rather than returned from a ternary: an untyped array literal in one
	# arm makes the whole expression an untyped Array, and assigning that to an
	# `Array[int]` throws at runtime -- which aborts the layout mid-function and
	# leaves every rect it had not written yet at zero. Nothing errors on screen;
	# the sliders simply are not there.
	var out: Array[int] = []
	if settings_tab_kind() == TAB_GAME:
		out.append_array([ROW_GAME, ROW_UI])
	return out

## The slider a row drives, or -1 for the actions. The two scales keep the
## indices they have always had -- 0 is the UI, 1 is the game -- because that is
## what `slider_range`, `slider_current` and the nudge all speak, and reordering
## the *display* must not renumber the *values*.
static func settings_slider_of(kind: int) -> int:
	match kind:
		ROW_UI: return 0
		ROW_GAME: return 1
	return -1

## Tall enough for the strip plus whatever the chosen tab puts under it. The
## guide is the tallest thing in here, and a card that resized as the player
## moved along the strip would make the icons themselves jump under the finger --
## so every tab gets the height of the largest.
func settings_body_height() -> float:
	match settings_tab_kind():
		TAB_GAME:
			return SETTINGS_SLIDER_H * 2.0
		TAB_GUIDE:
			return guide_height()
	return SETTINGS_ACTION_H

func settings_card_height() -> float:
	return SETTINGS_TAB_TOP + SETTINGS_TAB_H + 18.0 + settings_body_height() + 20.0

## The settings card, anchored by its top rather than centred.
##
## Every other card in the game is centred, and this one cannot be: its height
## follows whichever icon is chosen -- the guide is a keyboard, the scales are two
## sliders, save is nothing at all -- and a centred card of changing height slides
## the icon strip up and down under the finger that is walking it. Pinned at the
## top, the strip never moves and the body grows downward.
##
## The alternative was one height for every tab, taken from the tallest, which is
## what this did first: it kept the strip still by leaving two hundred units of
## empty card under 저장.
func settings_card_rect() -> Rect2:
	var height: float = minf(settings_card_height(), size.y - MARGIN * 2.0)
	var width: float = minf(420.0, size.x - MARGIN * 2.0)
	# Where a centred card of the tallest tab would start, so the panel sits in
	# the same place it always did rather than at the very top of the screen.
	var tallest: float = minf(SETTINGS_TAB_TOP + SETTINGS_TAB_H + 18.0 + guide_height() + 20.0,
		size.y - MARGIN * 2.0)
	var top: float = clampf(size.y * 0.5 - tallest * 0.5, MARGIN, size.y - height - MARGIN)
	return Rect2(size.x * 0.5 - width * 0.5, top, width, height)

## Where each row sits. Parallel to `settings_rows()`, so the cursor, the paint
## and the hit test are all indexing the same list.
var settings_row_rects: Array[Rect2] = []
## The icon strip, and the area under it that the chosen tab fills.
var settings_tab_rects: Array[Rect2] = []
var settings_body_rect := Rect2()

func _layout_settings() -> void:
	var card: Rect2 = settings_card_rect()
	# The strip. Even widths across the card, so the icons keep their rhythm at
	# three tabs from the title and at six from a run.
	var tabs: Array[int] = settings_tabs()
	settings_tab_rects.resize(tabs.size())
	var inner: float = card.size.x - SETTINGS_TAB_PAD * 2.0
	var step: float = inner / float(maxi(1, tabs.size()))
	for index in tabs.size():
		settings_tab_rects[index] = Rect2(
			card.position + Vector2(SETTINGS_TAB_PAD + step * float(index), SETTINGS_TAB_TOP),
			Vector2(step - 6.0, SETTINGS_TAB_H))

	var body_top: float = SETTINGS_TAB_TOP + SETTINGS_TAB_H + 18.0
	settings_body_rect = Rect2(card.position + Vector2(28.0, body_top),
		Vector2(card.size.x - 56.0, maxf(20.0, card.size.y - body_top - 20.0)))

	var rows: Array[int] = settings_rows()
	settings_row_rects.resize(rows.size())
	var y: float = body_top
	for index in rows.size():
		var kind: int = rows[index]
		var slider: int = settings_slider_of(kind)
		settings_row_rects[index] = Rect2(card.position + Vector2(34.0, y),
			Vector2(card.size.x - 68.0, SETTINGS_SLIDER_H - 8.0))
		if slider >= 0:
			var track := Rect2(card.position + Vector2(34.0, y + 52.0),
				Vector2(card.size.x - 68.0, 8.0))
			slider_track_rects[slider] = track
			# Half a row of slop above and below, so a drag that starts a little
			# off the track still belongs to that row.
			slider_hit_rects[slider] = Rect2(track.position - Vector2(26.0, 46.0),
				track.size + Vector2(52.0, 72.0))
		y += SETTINGS_SLIDER_H
	# The way out is the card's own corner now rather than a row at the bottom of
	# a list -- there is no list any more. It stays a rectangle the touch layer
	# can hit, because on a pad with no Escape key a panel with no drawn exit is
	# a panel you are stuck in.
	settings_close_rect = Rect2(card.end.x - 44.0, card.position.y + 12.0, 32.0, 32.0)
	_layout_slots()

## Which tab a point is on, or -1.
func settings_tab_at(point: Vector2) -> int:
	for index in settings_tab_rects.size():
		if (settings_tab_rects[index] as Rect2).has_point(point):
			return index
	return -1

## Which row a point is on, or -1.
func settings_row_at(point: Vector2) -> int:
	for index in settings_row_rects.size():
		if (settings_row_rects[index] as Rect2).has_point(point):
			return index
	return -1

# --- Save slots ---------------------------------------------------------------
## Thirty-one slots do not fit on a card, so the list shows a window onto them and
## the window follows the cursor. The rects published here are the visible rows;
## slot_scroll is what turns one into a slot number, and everything that hit-tests
## or draws goes through that so the two can never disagree about which row is
## which.
const SLOT_ROW := 62.0
const SLOT_VISIBLE := 5

func slot_page() -> int:
	return mini(SLOT_VISIBLE, main.SAVE_SLOTS)

func _layout_slots() -> void:
	var card: Rect2 = _card_rect(SLOT_CARD_H)
	# Keep the cursor on screen with a row of lead where there is one, so moving
	# through the list never parks the selection against the edge.
	var page: int = slot_page()
	slot_scroll = clampi(slot_scroll, maxi(0, slot_index - page + 1), slot_index)
	slot_scroll = clampi(slot_scroll, 0, maxi(0, main.SAVE_SLOTS - page))
	slot_rects.clear()
	for row in page:
		slot_rects.append(Rect2(card.position + Vector2(14.0, FRAME_HEADER + 12.0 + float(row) * SLOT_ROW),
			Vector2(card.size.x - 40.0, SLOT_ROW - 6.0)))

## The slot a point falls on, or -1. Returns the slot number, not the row.
func slot_row_at(point: Vector2) -> int:
	for row in slot_rects.size():
		if (slot_rects[row] as Rect2).has_point(point):
			return slot_scroll + row
	return -1

## The value range a row spans. Kept here rather than in the caller so drawing,
## hit-testing and the keyboard all read the same numbers.
func slider_range(index: int) -> Vector2:
	return Vector2(Defs.UI_SCALE_MIN, Defs.UI_SCALE_MAX) if index == 0 \
		else Vector2(Defs.GAME_SCALE_MIN, Defs.GAME_SCALE_MAX)

func slider_current(index: int) -> float:
	return float(main.ui_scale) if index == 0 else float(main.game_scale)

## Maps a horizontal position on a row's track to that row's scale value.
func slider_value_at(index: int, x: float) -> float:
	var track: Rect2 = slider_track_rects[index]
	var span: float = maxf(track.size.x, 1.0)
	var t: float = clampf((x - track.position.x) / span, 0.0, 1.0)
	var range: Vector2 = slider_range(index)
	return range.x + t * (range.y - range.x)

## Which row a point falls in, or -1.
func slider_at(point: Vector2) -> int:
	for index in slider_hit_rects.size():
		if (slider_hit_rects[index] as Rect2).has_point(point):
			return index
	return -1

func begin_slider_drag(index: int) -> void:
	dragging_slider = index
	# The cursor follows the drag, and the cursor counts rows rather than sliders
	# now -- the two were the same list until the actions joined it.
	var rows: Array[int] = settings_rows()
	for row in rows.size():
		if settings_slider_of(rows[row]) == index:
			settings_row = row
			break

func end_slider_drag() -> void:
	dragging_slider = -1

func _panel(rect: Rect2, fill: Color, edge: Color, width: float = 1.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, width)

# --- Panel language -----------------------------------------------------------
## Every window in the game goes through here, and here goes through HudStyle --
## the same plate, edge and corner as the corner panels, so a window opening over
## the HUD reads as more of the same interface rather than a second one. What
## changes between windows is the colour of the title, and nothing else.
##
## It used to be its own language: a near-opaque slab with a bright rule along
## the top and machined corner ticks. That read as a different, colder game
## from the one the characters are drawn in.
const FRAME_PAD := HudStyle.PANEL_PADDING
const FRAME_HEADER := HudStyle.TITLE_RULE

func _frame(rect: Rect2, accent: Color, title: String = "") -> void:
	HudStyle.panel(self, rect, HudStyle.SOLID)
	if title != "":
		HudStyle.title(self, rect, title, accent)

## Godot ignores horizontal alignment unless a width is supplied, so every
## centred string here spans an explicit box rather than a bare position.
func _text(at: Vector2, body: String, size: int, color: Color) -> void:
	HudStyle.text(self, at, body, size, color)

func _text_in(box: Rect2, body: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	HudStyle.text_in(self, box, body, size, color, align)

## The two tools that are objects in the world as well as slots in the row.
##
## They used to be drawn twice over: the pickaxe as a wedge on a stick in code
## and as a painting on the snow, and the gun not at all -- its slot showed a
## picture of whichever machine it was loaded with, which is the thing it makes
## rather than the thing it is. Same file both places now, so what she picks up
## off the snow and what sits in her hand are one object.
const PICKAXE_ART: Texture2D = preload("res://assets/objects/pickaxe.png")
const BUILD_GUN_ART: Texture2D = preload("res://assets/objects/build_gun.png")

## Fitted into the chip and centred, never stretched: these are painted at one
## aspect and a slot is square.
func _tool_art(art: Texture2D, box: Rect2) -> void:
	var source := Vector2(float(art.get_width()), float(art.get_height()))
	var fit: float = minf(box.size.x / source.x, box.size.y / source.y)
	var drawn: Vector2 = source * fit
	draw_texture_rect(art, Rect2(box.position + (box.size - drawn) * 0.5, drawn), false)

func _text_width(body: String, size: int) -> float:
	return HudStyle.width_of(body, size)

## A line that is allowed to be longer than the plate it sits on.
##
## Every card in the left column is one width now, so text can no longer be
## measured and the plate grown to fit it -- it is the other way round. The
## opening's longest line is 310 pixels of Korean in a 190 pixel column and was
## drawn straight out through the border, which on a phone was most of the
## sentence hanging over the snow.
func _text_block(at: Vector2, body: String, width: float, size: int, color: Color) -> void:
	HudStyle.block(self, at, body, width, size, color)

## How tall that comes out. The card measures with this and draws with the one
## above, so the plate and the text cannot disagree about how many lines there
## are.
func _text_block_height(body: String, width: float, size: int) -> float:
	return HudStyle.block_height(body, width, size)

func _draw() -> void:
	if main == null:
		return
	match main.state:
		main.State.TITLE: _draw_title()
		main.State.OPENING: _draw_cutscene()
		main.State.GAMEOVER: _draw_gameover()
		main.State.NIGHTFALL, main.State.DAYBREAK:
			# The sequence is the one moment the game is not asking for anything,
			# so the hotbar, the objective and the placement ghost all get out of
			# the way. The sky stays -- it is the point of the scene -- but the
			# frost vignette does not, because indoors is exactly where the player
			# is no longer in danger of freezing.
			_draw_dusk_wash()
			_draw_night_caption()
		main.State.SETTINGS:
			# Draw the screen it was opened over, so the player can see their
			# change land on the real HUD instead of on an empty backdrop.
			if main.state_before_settings == main.State.TITLE:
				_draw_title()
			else:
				_draw_status()
				_draw_world()
				_draw_hotbar()
			if slot_picker > 0:
				_draw_slot_picker()
			else:
				_draw_settings_card()
		_:
			# Frost creeping in at the edges is the cold arriving. Where the
			# cold cannot reach her it is just a dirty window.
			if Zone.freezes(main.zone()):
				_draw_cold_vignette()
			_draw_blackout()
			_draw_status()
			_draw_world()
			_draw_minimap()
			_draw_hotbar()
			_draw_feed()
			_draw_meter_card()
			_draw_gacha_button()
			_draw_build_menu()
			_draw_base_menu()
			_draw_machine_menu()
			_draw_gacha_card()
	# Below the match, so they are on every screen -- except the opening and the
	# end. Both are moments the game is not offering the player a control, and
	# two little chrome squares in the corner say otherwise; on the game over
	# card they also offer a map of a run that is finished.
	_draw_room_fade()
	if main.state == main.State.OPENING or main.state == main.State.GAMEOVER:
		return
	_draw_map_card()
	_draw_log_card()
	_draw_quest_card()
	_draw_settings_button()
	_draw_map_button()
	_draw_log_button()
	_draw_debug_badge()

## After the fall the world goes out entirely, so the cut to morning reads as
## losing consciousness rather than as a scene change.
func _draw_blackout() -> void:
	if main.blackout <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(main.blackout, 0.0, 1.0)))

## Losing body heat used to be expressed only by an 8px bar in the corner, which
## a player walking through the dark will never look at. The screen itself now
## closes in as warmth drops. Snow, frost border and ice corners are carried
## over from Motorio's climate layer.
## Most of the night is drawn here rather than by the world layers, so anything
## that shows the world has to draw it or the sky snaps back to noon. It reads
## night_level rather than the clock: during the night sequence the clock is at
## zero and then at a full day while the sun is still coming up.
## How dark the sky wash is at a given point in the day, as [evening, night]
## opacities. Asked as one function rather than computed inside the paint,
## because a test can read a predicate and cannot read a draw call -- and "night
## is darker than dusk" is a claim worth holding to.
static func night_wash(level: float) -> Array[float]:
	# The second wash starts the moment night does, and where that is comes from
	# the clock rather than from a number typed here: night is the last
	# NIGHT_SECONDS of the day, so it begins at that fraction of it. It used to
	# start at 0.86, which is a third of the way *into* the night -- so the
	# darkness the player was promised arrived after the thing it was for.
	var night_at: float = 1.0 - Defs.NIGHT_SECONDS / Defs.DAY_SECONDS
	var dusk: float = clampf((level - 0.55) / 0.45, 0.0, 1.0)
	# A step, not a ramp from zero. Night falling is an event -- the cats stop
	# working, the banner says go home -- and a second wash that starts at
	# nothing on that frame means the screen looks exactly as it did a second
	# earlier. It lands at just over half its weight and deepens from there.
	var into: float = clampf((level - night_at) / maxf(1.0 - night_at, 0.001), 0.0, 1.0)
	var deep: float = 0.0 if level < night_at else 0.55 + 0.45 * into
	return [dusk * 0.46, deep * 0.62]

func _draw_dusk_wash() -> void:
	var wash: Array[float] = night_wash(main.night_level())
	if wash[0] <= 0.0:
		return
	# Two washes rather than one. The first is the evening -- it comes on through
	# dusk and tops out at a blue the world is still legible through, which is
	# what a long golden hour should look like. The second only starts once night
	# has actually fallen and takes it most of the way down, because "밤" had
	# been a tint the player could read a book through: the torch, the core's
	# pool and the shelter window are the game's three sources of light and none
	# of them mattered while the snow itself stayed bright.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.16, wash[0]))
	if wash[1] > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.06, wash[1]))

func _draw_cold_vignette() -> void:
	_draw_dusk_wash()

	var exposure: float = 0.0
	if main.sim != null:
		var distance: float = Vector2(main.player.cell() - main.sim.core_cell).length()
		exposure = clampf((distance - main.sim.warm_radius) / 8.0, 0.0, 1.0)
	# Three named stages rather than a smooth fade, so the player can feel the
	# moment their situation gets worse.
	var warmth: float = main.player.warmth
	var stage: int = 0
	for threshold: float in Defs.FROST_STAGES:
		if warmth <= threshold:
			stage += 1
	var chill: float = float(stage) / float(Defs.FROST_STAGES.size())
	_draw_snow(maxf(chill, exposure * 0.7))
	if stage <= 0:
		return
	var pulse: float = 1.0
	if main.player.warmth < 30.0:
		pulse = 0.88 + sin(float(Time.get_ticks_msec()) / 106.0) * 0.12
	var bands := 14
	for index in bands:
		var k: float = float(index) / float(bands)
		var inset: float = k * minf(size.x, size.y) * 0.42
		var alpha: float = chill * pulse * 0.40 * pow(1.0 - k, 1.7)
		draw_rect(Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			Color(0.35, 0.55, 0.82, alpha), false, maxf(6.0, minf(size.x, size.y) * 0.03))
	# Frost creeping in from the frame edge, then ice in the corners at the end.
	var thickness: float = 10.0 + chill * 22.0
	var frost := Color(0.55, 0.9, 1.0, 0.10 + chill * 0.30)
	draw_rect(Rect2(0, 0, size.x, thickness), frost)
	draw_rect(Rect2(0, size.y - thickness, size.x, thickness), frost)
	draw_rect(Rect2(0, thickness, thickness, size.y - thickness * 2.0), frost)
	draw_rect(Rect2(size.x - thickness, thickness, thickness, size.y - thickness * 2.0), frost)
	if main.player.warmth <= 14.0:
		var ice := Color(0.7, 0.91, 1.0, 0.22)
		for corner in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:
			draw_circle(corner, 54.0, ice)

func _draw_snow(strength: float) -> void:
	if strength <= 0.0:
		return
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var flakes: int = int(12.0 + strength * 34.0)
	for index in flakes:
		var seed: float = float(index * 79 + 17)
		var x: float = fmod(seed * 13.7 + t * (22.0 + fmod(seed, 15.0)), size.x + 24.0) - 12.0
		var y: float = fmod(seed * 7.3 + t * (38.0 + fmod(seed, 21.0)), size.y + 24.0) - 12.0
		draw_circle(Vector2(x, y), 1.2 + fmod(seed, 3.0) * 0.45,
			Color(0.92, 0.98, 1.0, 0.28 + strength * 0.45))

# --- In-run UI ---------------------------------------------------------------

## Top-left: her own situation, on one plate.
##
## Two bars and a ledger. The warmth bar is the long, thick one because it is the
## only readout here that is ever an emergency; the day bar under it is shorter
## and thinner and carries the day number in its tail. No clock: a player turns
## "14:22" into "how long until dark", and the bar answers that directly.
##
## This corner was two shaded boxes and a framed ledger with corner ticks, each
## with its own margin, and the numbers were placed by eye -- so "100" floated
## above its bar and "1일차" sat on top of it. Everything is centred on its row
## by asking the font how tall it is (HudStyle.baseline_for).
func _draw_status() -> void:
	HudStyle.panel(self, status_card_rect())
	var bars: Rect2 = status_rect()
	_draw_warmth_row(bars)
	_draw_day_bar(bars)
	_draw_resources()
	_draw_collapse_warning()

## Body heat, the full width of the card.
##
## The number stayed, small, in the tail: below a quarter the bar is a short red
## stub, and a stub does not distinguish "walk back now" from "you are not going
## to make it".
func _draw_warmth_row(bars: Rect2) -> void:
	var warmth: float = main.player.warmth
	var k: float = clampf(warmth / 100.0, 0.0, 1.0)
	var middle: float = bars.position.y + STATUS_ROW * 0.5
	var icon := Vector2(bars.position.x + 6.0, middle)
	var tint: Color = HudStyle.TEXT_SUB if k > 0.25 else HudStyle.DANGER
	# A bulb and a stem, drawn rather than typed: the font is cut from the game's
	# own strings and a glyph nobody wrote is not in it.
	draw_circle(icon + Vector2(0.0, 3.2), 3.0, tint)
	draw_line(icon + Vector2(0.0, 2.0), icon + Vector2(0.0, -5.0), tint, 2.0)
	var tail: float = 26.0
	var track := Rect2(bars.position.x + BAR_X, middle - BAR_H * 0.5,
		maxf(20.0, bars.size.x - BAR_X - tail), BAR_H)
	var fill: Color = HudStyle.ACCENT.lerp(HudStyle.DANGER, 1.0 - k)
	if k < 0.25:
		var pulse: float = 0.6 + sin(float(Time.get_ticks_msec()) / 90.0) * 0.4
		fill = HudStyle.DANGER.lerp(Color.WHITE, pulse * 0.35)
	HudStyle.bar(self, track, k, fill)
	HudStyle.text_in(self, Rect2(track.end.x, HudStyle.baseline_for(middle, HudStyle.TEXT_SMALL),
		bars.end.x - track.end.x, 14.0), "%d" % int(round(warmth)), HudStyle.TEXT_SMALL,
		HudStyle.TEXT_MAIN if k > 0.25 else HudStyle.DANGER, HORIZONTAL_ALIGNMENT_RIGHT)

## How far through today she is, and which day it is.
##
## Shorter and thinner than the warmth bar on purpose: they answer different
## sizes of question, and two equal bars read as one control split in half. The
## stretch that is already dusk is marked in the track, so "how long until I have
## to be somewhere warm" is read rather than calculated.
func _draw_day_bar(bars: Rect2) -> void:
	var night: bool = main.is_night()
	var middle: float = bars.position.y + STATUS_ROW * 1.5
	var icon := Vector2(bars.position.x + 6.0, middle)
	_draw_sun(icon, night, 1.0)
	var day_text: String = "%d일차" % main.day_number
	var tail: float = _text_width(day_text, HudStyle.TEXT_SMALL) + 8.0
	var track := Rect2(bars.position.x + BAR_X, middle - DAY_BAR_H * 0.5,
		maxf(20.0, (bars.size.x - BAR_X - tail) * DAY_BAR_SHARE), DAY_BAR_H)
	var dusk_at: float = 1.0 - Defs.DUSK_SECONDS / Defs.DAY_SECONDS
	HudStyle.bar(self, track, 0.0, HudStyle.TRACK)
	var dusk := Rect2(track.position + Vector2(track.size.x * dusk_at, 0.0),
		Vector2(track.size.x * (1.0 - dusk_at), track.size.y))
	draw_colored_polygon(HudStyle.rounded(dusk, DAY_BAR_H * 0.5),
		Color(HudStyle.DANGER.r, HudStyle.DANGER.g, HudStyle.DANGER.b, 0.35))
	HudStyle.bar(self, track, clampf(main.day_fraction(), 0.0, 1.0),
		HudStyle.ACCENT_COLD if night else Defs.COL_CLOCK_FILL, Color(0, 0, 0, 0))
	# Left-aligned against the end of the bar, in the tail the bar leaves for it,
	# so the two never overlap at any width the player can choose.
	HudStyle.text(self, Vector2(track.end.x + 8.0, HudStyle.baseline_for(middle,
		HudStyle.TEXT_SMALL)), day_text, HudStyle.TEXT_SMALL,
		HudStyle.ACCENT_COLD if night else HudStyle.TEXT_SUB)

## A sun, or once it has set, a bitten moon. Shared by the status card and the
## world card so the two say "day" and "night" with the same picture.
func _draw_sun(at: Vector2, night: bool, alpha: float) -> void:
	var marker: Color = HudStyle.ACCENT_COLD if night else HudStyle.ACCENT
	marker.a *= alpha
	draw_circle(at, 5.4, Color(marker.r, marker.g, marker.b, 0.18 * alpha))
	draw_circle(at, 3.4, marker)
	if night:
		draw_circle(at + Vector2(1.8, -1.2), 2.7, Color(0.055, 0.075, 0.125, alpha))
	else:
		for spoke in 8:
			var dir := Vector2.from_angle(float(spoke) * TAU / 8.0)
			draw_line(at + dir * 5.0, at + dir * 6.6,
				Color(marker.r, marker.g, marker.b, 0.75 * alpha), 1.0)

## The five seconds between reaching zero and falling. The one line allowed in
## the middle of the screen, because it is the one thing on it that is about to
## end the day -- and it sits low, under her, never across her.
func _draw_collapse_warning() -> void:
	if main.collapse_timer < 0.0:
		return
	var label: String = "쓰러지는 중…" if main.player.collapse > 0.0 \
		else "의식이 흐려진다  %.1f초" % maxf(0.0, main.collapse_timer)
	var width: float = _text_width(label, HudStyle.TEXT_TITLE) + HudStyle.PANEL_PADDING * 4.0
	var chip := Rect2(size.x * 0.5 - width * 0.5, size.y * 0.64, width, 30.0)
	HudStyle.panel(self, chip, HudStyle.SOLID)
	HudStyle.text_in(self, Rect2(chip.position.x, HudStyle.baseline_for(chip.get_center().y,
		HudStyle.TEXT_TITLE), chip.size.x, 18.0), label, HudStyle.TEXT_TITLE, HudStyle.DANGER)

# --- Resource ledger ----------------------------------------------------------
const RESOURCE_ROW := 18.0

## The rows under the bars, inside the same plate. Separate rows rather than a
## framed box of their own: the corner is one card, and a card inside a card is
## the thing this pass took out.
func resource_rect() -> Rect2:
	var bars: Rect2 = status_rect()
	return Rect2(Vector2(bars.position.x, bars.end.y + HudStyle.SECTION_GAP),
		Vector2(bars.size.x, float(resource_rows().size()) * RESOURCE_ROW))

## [name, amount, rate text, colour]. Heat first because it is the score; power
## last and only once something generates it, since a row reading zero of zero
## teaches nothing.
func resource_rows() -> Array[Array]:
	var sim = main.sim
	var rows: Array[Array] = []
	for item_type: int in Defs.COUNTED_ITEMS:
		var held: int = int(sim.stock.get(item_type, 0))
		var seen: bool = held > 0 or int(sim.delivered.get(item_type, 0)) > 0
		if not seen:
			continue
		rows.append([Defs.ITEM_SHORT[item_type], "%d" % held,
			_rate_text(float(sim.gain_rate.get(item_type, 0.0))), Defs.ITEM_COLORS[item_type],
			item_type])
	# Draw without capacity is a real state now: a manufacturer opens on the first
	# iron and the generator needs copper and an energy core, so a player can
	# stand in front of a machine asking for power on a grid that has none. The
	# row is how they find that out.
	if sim.power_capacity > 0.0 or sim.power_draw > 0.0 \
			or sim.machine_count(Defs.M_GENERATOR) > 0:
		# Power is a rate on both sides, so it reads as used-of-available rather
		# than as a stock with an income.
		rows.append(["전기", "%.1f/%.1f" % [sim.power_draw, sim.power_capacity], "",
			Defs.COL_MACHINE_EDGE, -1])
	return rows

## Per minute, like every other rate the game quotes. Machines are rated in
## tens-of-seconds cycles, so the same numbers per second are 0.10 and 0.03 --
## the same information in a form nobody can plan against.
func _rate_text(each_minute: float) -> String:
	if each_minute < 0.05:
		return ""
	if each_minute >= 10.0:
		return "+%.0f/분" % each_minute
	return "+%.1f/분" % each_minute

func _draw_resources() -> void:
	var rows: Array[Array] = resource_rows()
	if rows.is_empty():
		return
	var box: Rect2 = resource_rect()
	HudStyle.divider(self, box.position - Vector2(0.0, HudStyle.SECTION_GAP * 0.5), box.size.x)
	var y: float = box.position.y
	for row: Array in rows:
		var middle: float = y + RESOURCE_ROW * 0.5
		var tint: Color = row[3]
		var icon := Rect2(Vector2(box.position.x, middle - HudStyle.ICON_SMALL * 0.5),
			Vector2(HudStyle.ICON_SMALL, HudStyle.ICON_SMALL))
		if int(row[4]) >= 0:
			Icons.draw_item(self, icon, int(row[4]))
		else:
			draw_circle(icon.get_center(), 3.6, tint)
		var baseline: float = HudStyle.baseline_for(middle, HudStyle.TEXT_NORMAL)
		HudStyle.text(self, Vector2(box.position.x + HudStyle.ICON_SMALL + HudStyle.ITEM_GAP,
			baseline), String(row[0]), HudStyle.TEXT_NORMAL, HudStyle.TEXT_MAIN)
		# Amount and rate are right-aligned in their own columns, so the eye can
		# run down either one without reading the other.
		HudStyle.text_in(self, Rect2(box.end.x - 118.0, baseline, 58.0, 14.0), String(row[1]),
			HudStyle.TEXT_NORMAL, HudStyle.TEXT_MAIN, HORIZONTAL_ALIGNMENT_RIGHT)
		HudStyle.text_in(self, Rect2(box.end.x - 56.0, HudStyle.baseline_for(middle,
			HudStyle.TEXT_SMALL), 56.0, 14.0), String(row[2]), HudStyle.TEXT_SMALL, tint,
			HORIZONTAL_ALIGNMENT_RIGHT)
		y += RESOURCE_ROW

# --- The world ----------------------------------------------------------------
## Top-right: what the world is doing and what she is after.
##
## A header -- the time of day and the weather, as two pictures and two words --
## then whatever is true right now that she should act on (the cold, dusk,
## night), then up to three quests she is working on. Finished quests do not stay:
## a tick for a breath and then the next one takes the line.
##
## This used to be three different cards stacked in the left column under the
## ledger -- a state card, a goal card with an icon well, and a mission card --
## and the mission card and the quest line were drawing the same sentence twice,
## one under the other. They are one card now, reading one list.
const QUEST_SHOWN := 3
const QUEST_MARK_W := 16.0
const QUEST_BAR_H := 4.0

## "낮", "해질녘", "밤" -- or the hut, where there is no time of day.
func phase_label() -> String:
	if not Zone.clock_runs(main.zone()):
		return "숙소 안"
	if main.is_night():
		return "밤"
	if main.is_dusk():
		return "해질녘"
	return "낮"

## The weather, as it feels where she is standing. The world has one weather --
## it snows -- so what changes is whether she is inside the fire's reach.
func weather_label() -> String:
	if not Zone.has_weather(main.zone()):
		return "따뜻함"
	var warm: bool = main.sim.base_placed and main.sim.is_warm(main.player.cell())
	return "눈 · 포근함" if warm else "눈 · 추움"

## What is true right now and worth acting on, with the colour it is said in.
func world_note() -> Dictionary:
	var text: String = main.info()
	if text == "":
		return {}
	var tint: Color = HudStyle.ACCENT
	if not main.is_night() and not main.is_dusk():
		tint = HudStyle.DANGER
	elif main.is_night():
		tint = HudStyle.ACCENT_COLD
	return {"text": text, "color": tint}

## The rows the card lists: a quest that just finished (for a breath), then the
## open ones, at most three in all.
func world_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if main.quest_done_flash > 0.0:
		out.append({"title": String(main.quest_done_title), "done": true, "current": 0,
			"target": 0})
	for row: Dictionary in main.active_quests():
		if out.size() >= QUEST_SHOWN:
			break
		out.append({"title": String(row["title"]), "done": false,
			"current": int(row["current"]), "target": int(row["target"])})
	return out

## The opening's own line when it says something the quest list does not -- the
## hint that rides along while she carries the hut, say.
func world_hint() -> String:
	var text: String = main.objective()
	if text == "":
		return ""
	for row: Dictionary in main.active_quests():
		if String(row["title"]) == text:
			return ""
	return text

## The first quest line, as the tests and the old corner line read it: the tick
## while one finishes, otherwise the first open quest.
func quest_hud_text() -> String:
	var rows: Array[Dictionary] = world_quests()
	return "" if rows.is_empty() else String(rows[0]["title"])

func world_width() -> float:
	if world_beside_status():
		return minf(WORLD_W, size.x - MARGIN * 2.0)
	return column_width()

func _world_text_width() -> float:
	return world_width() - HudStyle.PANEL_PADDING * 2.0

func _quest_row_height(row: Dictionary) -> float:
	var height: float = HudStyle.block_height(String(row["title"]),
		_world_text_width() - QUEST_MARK_W, HudStyle.TEXT_NORMAL)
	if not bool(row["done"]) and int(row["target"]) > 0:
		height += HudStyle.ITEM_GAP + QUEST_BAR_H
	return height

## The card, measured from the same helpers the drawing uses.
func world_card_rect() -> Rect2:
	var width: float = world_width()
	var height: float = HudStyle.PANEL_PADDING * 2.0 + HudStyle.ROW
	var note: Dictionary = world_note()
	if not note.is_empty():
		height += HudStyle.ITEM_GAP + HudStyle.block_height(String(note["text"]),
			_world_text_width(), HudStyle.TEXT_SMALL)
	var quests: Array[Dictionary] = world_quests()
	if not quests.is_empty():
		height += HudStyle.SECTION_GAP
		for row: Dictionary in quests:
			height += _quest_row_height(row) + HudStyle.ITEM_GAP
	var hint: String = world_hint()
	if hint != "":
		height += HudStyle.ITEM_GAP + HudStyle.block_height(hint, _world_text_width() -
			QUEST_MARK_W, HudStyle.TEXT_SMALL)
	if world_beside_status():
		return Rect2(size.x - MARGIN - width, MARGIN, width, height)
	return Rect2(MARGIN, status_card_rect().end.y + HudStyle.SECTION_GAP, width, height)

## Where the quest rows sit inside the card, or a zero-high rect when there are
## none -- an empty plate labelled 임무 is worse than no plate.
func quest_hud_rect() -> Rect2:
	var quests: Array[Dictionary] = world_quests()
	var card: Rect2 = world_card_rect()
	if quests.is_empty():
		return Rect2(card.position.x, card.end.y, 0.0, 0.0)
	var top: float = card.position.y + HudStyle.PANEL_PADDING + HudStyle.ROW
	var note: Dictionary = world_note()
	if not note.is_empty():
		top += HudStyle.ITEM_GAP + HudStyle.block_height(String(note["text"]),
			_world_text_width(), HudStyle.TEXT_SMALL)
	top += HudStyle.SECTION_GAP
	var height := 0.0
	for row: Dictionary in quests:
		height += _quest_row_height(row) + HudStyle.ITEM_GAP
	return Rect2(card.position.x + HudStyle.PANEL_PADDING, top, _world_text_width(), height)

func _draw_world() -> void:
	var card: Rect2 = world_card_rect()
	HudStyle.panel(self, card)
	var x: float = card.position.x + HudStyle.PANEL_PADDING
	var middle: float = card.position.y + HudStyle.PANEL_PADDING + HudStyle.ROW * 0.5
	var night: bool = main.is_night()
	# The header: sun or moon and the time of day, then a flake and the weather.
	_draw_sun(Vector2(x + 6.0, middle), night, 1.0)
	var baseline: float = HudStyle.baseline_for(middle, HudStyle.TEXT_NORMAL)
	var phase: String = phase_label()
	HudStyle.text(self, Vector2(x + 18.0, baseline), phase, HudStyle.TEXT_NORMAL,
		HudStyle.TEXT_MAIN)
	var flake_x: float = x + 18.0 + _text_width(phase, HudStyle.TEXT_NORMAL) + 16.0
	_draw_flake(Vector2(flake_x, middle), HudStyle.ACCENT_COLD)
	HudStyle.text(self, Vector2(flake_x + 11.0, HudStyle.baseline_for(middle, HudStyle.TEXT_SMALL)),
		weather_label(), HudStyle.TEXT_SMALL, HudStyle.TEXT_SUB)
	var y: float = card.position.y + HudStyle.PANEL_PADDING + HudStyle.ROW
	var note: Dictionary = world_note()
	if not note.is_empty():
		y += HudStyle.ITEM_GAP
		var body: String = String(note["text"])
		HudStyle.block(self, Vector2(x, y + float(HudStyle.TEXT_SMALL)), body, _world_text_width(),
			HudStyle.TEXT_SMALL, note["color"])
		y += HudStyle.block_height(body, _world_text_width(), HudStyle.TEXT_SMALL)
	var quests: Array[Dictionary] = world_quests()
	if not quests.is_empty():
		HudStyle.divider(self, Vector2(x, y + HudStyle.SECTION_GAP * 0.5), _world_text_width())
		y += HudStyle.SECTION_GAP
		for row: Dictionary in quests:
			y = _draw_world_quest(x, y, row) + HudStyle.ITEM_GAP
	var hint: String = world_hint()
	if hint != "":
		y += HudStyle.ITEM_GAP
		HudStyle.block(self, Vector2(x + QUEST_MARK_W, y + float(HudStyle.TEXT_SMALL)), hint,
			_world_text_width() - QUEST_MARK_W, HudStyle.TEXT_SMALL, HudStyle.TEXT_SUB)

## One quest: a ring (or a tick, for a breath, when it is done), the sentence,
## and a thin bar with the count when it has one. The count is never inside the
## sentence -- a line with a number in it goes stale the moment the number moves.
func _draw_world_quest(x: float, y: float, row: Dictionary) -> float:
	var done: bool = bool(row["done"])
	var alpha: float = 1.0 if not done else clampf(main.quest_done_flash / 0.5, 0.0, 1.0)
	var tint: Color = HudStyle.DONE if done else HudStyle.ACCENT
	var title: String = String(row["title"])
	var width: float = _world_text_width() - QUEST_MARK_W
	var first_middle: float = y + float(HudStyle.TEXT_NORMAL) * 0.6
	var mark := Vector2(x + 5.0, first_middle)
	if done:
		draw_line(mark + Vector2(-3.5, 0.0), mark + Vector2(-1.0, 2.6),
			Color(tint.r, tint.g, tint.b, alpha), 1.8)
		draw_line(mark + Vector2(-1.0, 2.6), mark + Vector2(4.0, -3.0),
			Color(tint.r, tint.g, tint.b, alpha), 1.8)
	else:
		draw_arc(mark, 3.4, 0.0, TAU, 16, Color(tint.r, tint.g, tint.b, 0.9), 1.4)
	var body: Color = HudStyle.TEXT_SUB if done else HudStyle.TEXT_MAIN
	HudStyle.block(self, Vector2(x + QUEST_MARK_W, y + float(HudStyle.TEXT_NORMAL)), title, width,
		HudStyle.TEXT_NORMAL, Color(body.r, body.g, body.b, alpha))
	y += HudStyle.block_height(title, width, HudStyle.TEXT_NORMAL)
	if done or int(row["target"]) <= 0:
		return y
	y += HudStyle.ITEM_GAP
	var count: String = "%d / %d" % [int(row["current"]), int(row["target"])]
	var count_w: float = _text_width(count, HudStyle.TEXT_SMALL) + HudStyle.ITEM_GAP
	var track := Rect2(x + QUEST_MARK_W, y, maxf(20.0, width - count_w), QUEST_BAR_H)
	HudStyle.bar(self, track, float(row["current"]) / maxf(float(row["target"]), 1.0), tint)
	HudStyle.text_in(self, Rect2(track.end.x, HudStyle.baseline_for(track.get_center().y,
		HudStyle.TEXT_SMALL), count_w, 14.0), count, HudStyle.TEXT_SMALL, tint,
		HORIZONTAL_ALIGNMENT_RIGHT)
	return y + QUEST_BAR_H

## A six-armed flake. Drawn, not typed, for the same reason as the thermometer.
func _draw_flake(at: Vector2, tint: Color) -> void:
	for arm in 3:
		var dir := Vector2.from_angle(float(arm) * PI / 3.0 + PI * 0.5)
		draw_line(at - dir * 4.6, at + dir * 4.6, tint, 1.2)
	draw_circle(at, 1.3, tint)

# --- The quest window ---------------------------------------------------------
## The count line under a quest in the Q window.
const QUEST_ROW_H := 16.0
## How tall the list comes out. The card and the drawing ask the same question,
## so a wrapped line cannot end up drawn past the bottom of its own plate.
func quest_card_height(width: float) -> float:
	var text_w: float = width - 44.0
	var height: float = FRAME_HEADER + 24.0
	var active: Array[Dictionary] = main.active_quests()
	var done: Array[Dictionary] = main.done_quests()
	if active.is_empty() and done.is_empty():
		return FRAME_HEADER + 60.0
	if not active.is_empty():
		height += 16.0
		for row: Dictionary in active:
			height += _quest_entry_height(row, false, text_w)
		height += 8.0
	if not done.is_empty():
		height += 24.0
		for row: Dictionary in done:
			height += _quest_entry_height(row, true, text_w)
	return height + 12.0

func _quest_entry_height(row: Dictionary, done: bool, text_w: float) -> float:
	var height: float = _text_block_height(String(row["title"]), text_w, 13) + 12.0
	if not done and int(row["target"]) > 0:
		height += QUEST_ROW_H
	return height

## Q. Everything open, then everything finished, and nothing else.
func _draw_quest_card() -> void:
	if not bool(main.get("quest_open")):
		return
	_dim(0.45)
	var card: Rect2 = quest_card_rect
	_frame(card, Defs.COL_CORE, "임무   Q 또는 X 닫기")
	var active: Array[Dictionary] = main.active_quests()
	var done: Array[Dictionary] = main.done_quests()
	var y: float = card.position.y + FRAME_HEADER + 12.0
	var text_w: float = card.size.x - 44.0
	if active.is_empty() and done.is_empty():
		_text_in(Rect2(card.position + Vector2(0.0, card.size.y * 0.5),
			Vector2(card.size.x, 20.0)), "아직 아무 일도 시작되지 않았습니다", 13,
			Defs.COL_TEXT_DIM)
		return
	if not active.is_empty():
		_text(Vector2(card.position.x + 14.0, y), "진행 중", 11,
			Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.85))
		y += 8.0
		for row: Dictionary in active:
			y = _draw_quest_entry(card, y, row, false, text_w)
		y += 8.0
	if done.is_empty():
		return
	_text(Vector2(card.position.x + 14.0, y + 8.0), "완료", 11,
		Color(Defs.COL_BELT_RIM.r, Defs.COL_BELT_RIM.g, Defs.COL_BELT_RIM.b, 0.85))
	y += 16.0
	for row: Dictionary in done:
		if y > card.end.y - 24.0:
			return
		y = _draw_quest_entry(card, y, row, true, text_w)

## One row: a mark, the sentence, and the count if it has one. Returns the y the
## next row starts at, so the two lists cannot disagree about spacing.
func _draw_quest_entry(card: Rect2, y: float, row: Dictionary, done: bool,
		text_w: float) -> float:
	var title: String = String(row["title"])
	var tint: Color = Defs.COL_BELT_RIM if done else Defs.COL_CORE
	var mark := Vector2(card.position.x + 24.0, y + 12.0)
	if done:
		draw_line(mark + Vector2(-4.0, 0.0), mark + Vector2(-1.0, 3.0), tint, 1.8)
		draw_line(mark + Vector2(-1.0, 3.0), mark + Vector2(4.5, -3.5), tint, 1.8)
	else:
		draw_arc(mark, 3.8, 0.0, TAU, 16, tint, 1.5)
	var body: Color = Defs.COL_TEXT_DIM if done else Defs.COL_TEXT
	_text_block(Vector2(card.position.x + 36.0, y + 16.0), title, text_w, 13, body)
	y += _text_block_height(title, text_w, 13) + 6.0
	if not done and int(row["target"]) > 0:
		_text(Vector2(card.position.x + 36.0, y + 12.0),
			"%d / %d" % [int(row["current"]), int(row["target"])], 11, tint)
		y += QUEST_ROW_H
	return y + 6.0

func _draw_goal_icon(rect: Rect2, goal: Dictionary) -> void:
	match String(goal["kind"]):
		"machine": Icons.draw_machine(self, rect, int(goal["id"]))
		"item": Icons.draw_item(self, rect, int(goal["id"]))
		_: Icons.draw_thing(self, rect, String(goal["id"]))

# --- What just happened, and the key that matters now -------------------------
## Bottom-left: a short feed of what the game just said, and under it the one
## key worth pressing right now.
##
## Notifications used to stack in the middle of the screen, 192 units down, on
## plates that came and went in two and a half seconds -- the world is the thing
## in the middle, and a banner that crosses it has to be waited out. They are a
## quiet feed in the corner now, newest at the bottom, each fading when its time
## is up; the whole record is still one key away (L).
##
## The key prompt used to float over Grim's head. It is the same prompt -- one
## at a time, chosen by Main from `KEY_PROMPTS`, retired once it is learned -- in
## the corner every other instruction lives in, so the world around her is left
## to the world.
const FEED_W := 300.0
const FEED_LINES := 4
const PROMPT_H := 28.0

func feed_width() -> float:
	var room: float = size.x - MARGIN * 2.0
	if minimap_visible():
		room -= minimap_rect.size.x + HudStyle.SECTION_GAP
	return clampf(room, 96.0, FEED_W)

## The line the feed stands on: the floor, unless the hotbar shares its column --
## on a narrow screen the row is as wide as the screen and the feed stacks over it.
func feed_bottom() -> float:
	var bottom: float = floor_y()
	if gacha_button_rect.size.x > 0.0:
		bottom = gacha_button_rect.position.y - HudStyle.SECTION_GAP
	if main.sim.base_placed and Zone.has_world(main.zone()):
		var span: Vector2 = hotbar_span()
		if span.x < MARGIN + feed_width() + HudStyle.SECTION_GAP:
			var top: float = hotbar_top()
			if direction_visible():
				top = direction_rect.position.y
			bottom = minf(bottom, top - HudStyle.SECTION_GAP)
	return bottom

## The prompt chip, or a zero rect when nothing is being asked.
func prompt_rect() -> Rect2:
	var row: Dictionary = _prompt_row()
	if row.is_empty():
		return Rect2(MARGIN, feed_bottom(), 0.0, 0.0)
	var width: float = _prompt_width(row)
	return Rect2(MARGIN, feed_bottom() - PROMPT_H, width, PROMPT_H)

## The whole bottom-left zone, prompt and feed together.
func feed_rect() -> Rect2:
	var prompt: Rect2 = prompt_rect()
	var bottom: float = prompt.position.y - (HudStyle.ITEM_GAP if prompt.size.y > 0.0 else 0.0)
	var top: float = bottom
	for entry: Dictionary in _feed_entries():
		top -= _feed_line_height(String(entry["text"])) + HudStyle.ITEM_GAP
	var end_y: float = prompt.end.y if prompt.size.y > 0.0 else bottom
	return Rect2(MARGIN, top, feed_width(), maxf(0.0, end_y - top))

func _feed_entries() -> Array:
	var stack: Array = main.messages
	return stack.slice(maxi(0, stack.size() - FEED_LINES))

func _feed_line_height(body: String) -> float:
	return HudStyle.block_height(body, feed_width() - HudStyle.PANEL_PADDING * 2.0,
		HudStyle.TEXT_NORMAL) + 8.0

func _prompt_row() -> Dictionary:
	var id: String = String(main.player.prompt)
	if id.is_empty():
		return {}
	return Defs.key_prompt(id)

func _prompt_keys(row: Dictionary) -> Array:
	var keys: Array = main.player.main_keys
	return keys if not keys.is_empty() else row["keys"]

const PROMPT_HOLD := "누르고 있기"

func _prompt_width(row: Dictionary) -> float:
	var width: float = HudStyle.PANEL_PADDING * 2.0
	for cap: String in _prompt_keys(row):
		width += HudStyle.cap_width(cap) + 3.0
	width += 6.0 + _text_width(String(row["verb"]), HudStyle.TEXT_NORMAL)
	if bool(row.get("hold", false)):
		width += HudStyle.ITEM_GAP * 2.0 + _text_width(PROMPT_HOLD, HudStyle.TEXT_SMALL)
	return minf(width, feed_width())

func _draw_feed() -> void:
	var prompt: Rect2 = prompt_rect()
	var y: float = prompt.position.y - (HudStyle.ITEM_GAP if prompt.size.y > 0.0 else 0.0)
	# Newest at the bottom, nearest the prompt: the eye reads up from where it
	# already is.
	var entries: Array = _feed_entries()
	for index in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		var body: String = String(entry["text"])
		var alpha: float = clampf(float(entry["life"]), 0.0, 1.0)
		var height: float = _feed_line_height(body)
		y -= height
		var text_w: float = minf(_text_width(body, HudStyle.TEXT_NORMAL),
			feed_width() - HudStyle.PANEL_PADDING * 2.0)
		var plate := Rect2(MARGIN, y, text_w + HudStyle.PANEL_PADDING * 2.0, height)
		HudStyle.panel_faded(self, plate, alpha, HudStyle.CHIP)
		var tint: Color = entry["color"]
		HudStyle.block(self, Vector2(plate.position.x + HudStyle.PANEL_PADDING,
			plate.position.y + 4.0 + float(HudStyle.TEXT_NORMAL)), body,
			feed_width() - HudStyle.PANEL_PADDING * 2.0, HudStyle.TEXT_NORMAL,
			Color(tint.r, tint.g, tint.b, alpha))
		y -= HudStyle.ITEM_GAP
	_draw_prompt(prompt)

## The key cap, and the word. Held keys say so, because pressing Z at a seam does
## nothing visible and a player who taps it once concludes the game is broken.
func _draw_prompt(rect: Rect2) -> void:
	var row: Dictionary = _prompt_row()
	if row.is_empty() or rect.size.x <= 0.0:
		return
	var fade: float = float(main.player.prompt_fade())
	HudStyle.panel_faded(self, rect, fade, HudStyle.CHIP)
	var middle: float = rect.get_center().y
	var x: float = rect.position.x + HudStyle.PANEL_PADDING
	for cap: String in _prompt_keys(row):
		x += HudStyle.keycap(self, Vector2(x, middle - HudStyle.CAP_H * 0.5), cap, fade) + 3.0
	x += 3.0
	var verb: String = String(row["verb"])
	HudStyle.text(self, Vector2(x, HudStyle.baseline_for(middle, HudStyle.TEXT_NORMAL)), verb,
		HudStyle.TEXT_NORMAL, Color(HudStyle.ACCENT.r, HudStyle.ACCENT.g, HudStyle.ACCENT.b, fade))
	if bool(row.get("hold", false)):
		x += _text_width(verb, HudStyle.TEXT_NORMAL) + HudStyle.ITEM_GAP * 2.0
		HudStyle.text(self, Vector2(x, HudStyle.baseline_for(middle, HudStyle.TEXT_SMALL)),
			PROMPT_HOLD, HudStyle.TEXT_SMALL, Color(HudStyle.TEXT_SUB.r, HudStyle.TEXT_SUB.g,
			HudStyle.TEXT_SUB.b, fade))

# --- Where she is ---------------------------------------------------------------
## Bottom-right: a round map that follows her. The explored ground, the seams and
## machines on it, the fire's reach, and -- when the fire itself is off the edge
## -- a mark on the rim pointing home. North is up, as it is everywhere else.
##
## The same drawing as the M map (Main.draw_map), cut to a circle, so the two can
## never disagree about what is where. A tap opens the full one.
const MINIMAP_R := 58.0
const MINIMAP_ZOOM := 0.8
var minimap_rect := Rect2()

func minimap_visible() -> bool:
	if main == null or main.sim == null:
		return false
	return main.sim.base_placed and Zone.has_world(main.zone())

func _minimap_box() -> Rect2:
	var radius: float = clampf(minf(size.x, size.y) * 0.12, 36.0, MINIMAP_R)
	var bottom: float = floor_y()
	# Over the hotbar rather than beside it when the row reaches this corner.
	var span: Vector2 = hotbar_span()
	if main.sim.base_placed and span.y > size.x - MARGIN - radius * 2.0 - HudStyle.SECTION_GAP:
		bottom = minf(bottom, hotbar_top() - HudStyle.SECTION_GAP)
	return Rect2(size.x - MARGIN - radius * 2.0, bottom - radius * 2.0, radius * 2.0, radius * 2.0)

func _draw_minimap() -> void:
	if not minimap_visible():
		return
	var radius: float = minimap_rect.size.x * 0.5
	var centre: Vector2 = minimap_rect.get_center()
	draw_circle(centre + Vector2(0.0, 2.0), radius + 3.0, HudStyle.PANEL_SHADOW)
	draw_circle(centre, radius, Color(0.035, 0.045, 0.075, 0.92))
	main.call("draw_map", self, minimap_rect, MINIMAP_ZOOM, radius - 2.0, 0.42)
	# The rim, then the four ticks, the brightest one north.
	draw_arc(centre, radius, 0.0, TAU, 64, Color(HudStyle.PANEL_BORDER.r, HudStyle.PANEL_BORDER.g,
		HudStyle.PANEL_BORDER.b, 0.55), 2.0, true)
	for quarter in 4:
		var dir := Vector2.from_angle(-PI * 0.5 + float(quarter) * PI * 0.5)
		var tint: Color = HudStyle.ACCENT_COLD if quarter == 0 else HudStyle.PANEL_BORDER
		draw_line(centre + dir * (radius - 5.0), centre + dir * (radius + 0.5), tint, 2.0)
	HudStyle.text_in(self, Rect2(centre.x - 8.0, centre.y - radius + 16.0, 16.0, 12.0), "N",
		HudStyle.TEXT_SMALL, HudStyle.ACCENT_COLD)
	# Home, when home is off the edge.
	var core: Vector2 = Vector2(main.sim.core_cell - main.player.cell()) \
		* Defs.MAP_CELL_PX * MINIMAP_ZOOM
	if core.length() > radius - 6.0:
		var dir: Vector2 = core.normalized()
		var tip: Vector2 = centre + dir * (radius - 3.0)
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 8.0 + perp * 5.0,
			tip - dir * 8.0 - perp * 5.0]), HudStyle.ACCENT)

# --- In her hands -----------------------------------------------------------------
## Bottom-centre: the tool row. Square slots, the number in the corner and the
## thing itself in the middle; the one in her hand is lit with the fire's colour.
## Over the row, one line naming what she is holding and what it is for.
##
## A slot she does not have yet is not drawn, and the numbers never move -- see
## Main.tool_unlocked. The row is laid out for as many tools as TOOLS lists (the
## keys go to nine); it draws only the ones she owns.
## What she is holding, and what it is for -- in her words, not a manual's.
func hotbar_caption() -> String:
	if main == null or main.unlocked_tools().is_empty():
		return ""
	match main.TOOLS[main.tool_index]:
		main.TOOL_PICKAXE:
			return "곡괭이 · 단단한 광맥을 직접 캘 수 있다"
		main.TOOL_TORCH:
			if main.sim.torch_left > 0.0:
				return "%s · 타오르는 동안은 주변이 환하고 따뜻하다" % Defs.TORCH_NAME
			return "%s · 불을 붙이면 잠시 주변이 환하고 따뜻해진다" % Defs.TORCH_NAME
	var loaded: int = main.selected_type()
	var cost := ""
	for item_type: int in Defs.MACHINE_COSTS[loaded]:
		cost += "%s %d  " % [Defs.ITEM_SHORT[item_type], int(Defs.MACHINE_COSTS[loaded][item_type])]
	return "%s · %s  %s" % [main.TOOL_NAMES[main.TOOL_BUILD_GUN], Defs.MACHINE_SHORT[loaded],
		cost.strip_edges()]

## The output-direction chip means something only while the gun is in her hand
## and loaded with a machine that has a front.
func direction_visible() -> bool:
	if main == null or not main.sim.base_placed or not Zone.has_world(main.zone()):
		return false
	return main.holding_build_gun() and Defs.DIRECTIONAL_MACHINES.has(main.selected_type())

func _direction_label(dir: Vector2i) -> String:
	var names := {
		Vector2i.UP: "위", Vector2i.DOWN: "아래",
		Vector2i.LEFT: "왼쪽", Vector2i.RIGHT: "오른쪽",
	}
	return "출력 방향  %s" % String(names.get(dir, "오른쪽"))

func _draw_hotbar() -> void:
	# Nothing in it is reachable in a place with no world in it, and nothing is
	# reachable before the fire is lit: a row of things she cannot have is the
	# game talking about the second act during the first.
	if not Zone.has_world(main.zone()) or not main.sim.base_placed:
		return
	if main.unlocked_tools().is_empty():
		return
	_draw_direction_chip()
	_draw_caption()
	for index in main.TOOLS.size():
		if not main.tool_unlocked(main.TOOLS[index]):
			continue
		var rect: Rect2 = hotbar_rects[index] if index < hotbar_rects.size() else Rect2()
		if rect.size.x <= 0.0:
			continue
		var chosen: bool = index == main.tool_index
		HudStyle.panel(self, rect, HudStyle.SLOT_ON if chosen else HudStyle.SLOT)
		var art := Rect2(rect.get_center() - Vector2.ONE * HudStyle.ICON_LARGE * 0.5,
			Vector2.ONE * HudStyle.ICON_LARGE)
		match main.TOOLS[index]:
			main.TOOL_PICKAXE:
				_tool_art(PICKAXE_ART, art)
			main.TOOL_TORCH:
				Icons.draw_thing(self, art.grow(-3.0), Icons.THING_TORCH)
				_draw_slot_count(rect, main.sim.torches, main.sim.torches > 0 or main.sim.torch_left > 0.0)
				# The burn, as a bar along the foot of the slot: a number counting
				# down is read, a bar draining is noticed.
				if main.sim.torch_left > 0.0:
					HudStyle.bar(self, Rect2(rect.position.x + 7.0, rect.end.y - 7.0,
						rect.size.x - 14.0, 3.0),
						clampf(main.sim.torch_left / Defs.TORCH_SECONDS, 0.0, 1.0), HudStyle.ACCENT)
			_:
				_tool_art(BUILD_GUN_ART, art)
				# What it is loaded with, small, in the corner -- the slot is the gun,
				# and the machine is what it makes.
				var loaded: int = main.selected_type()
				var chip := Rect2(rect.end - Vector2.ONE * (HudStyle.ICON_SMALL + 5.0),
					Vector2.ONE * HudStyle.ICON_SMALL)
				Icons.draw_machine(self, chip, loaded)
				if not main.sim.can_afford(loaded):
					draw_circle(chip.position + Vector2(1.0, 1.0), 2.6, HudStyle.DANGER)
		HudStyle.text(self, rect.position + Vector2(6.0, 13.0), "%d" % (index + 1),
			HudStyle.TEXT_SMALL, HudStyle.ACCENT if chosen else HudStyle.TEXT_SUB)

## How many are left, in the corner opposite the slot's number -- the foot of the
## slot is where the burn bar runs.
func _draw_slot_count(rect: Rect2, count: int, has_any: bool) -> void:
	HudStyle.text_in(self, Rect2(rect.position.x, rect.position.y + 13.0, rect.size.x - 6.0, 12.0),
		"%d" % count, HudStyle.TEXT_SMALL, HudStyle.TEXT_MAIN if has_any else HudStyle.DANGER,
		HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_caption() -> void:
	var caption: String = hotbar_caption()
	if caption == "":
		return
	var middle: float = hotbar_origin().y - HudStyle.ITEM_GAP - CAPTION_H * 0.5
	var parts: PackedStringArray = caption.split(" · ", true, 1)
	var name_w: float = _text_width(parts[0], HudStyle.TEXT_SMALL)
	var rest: String = (" · " + parts[1]) if parts.size() > 1 else ""
	var total: float = name_w + _text_width(rest, HudStyle.TEXT_SMALL)
	var x: float = size.x * 0.5 - total * 0.5
	var span: Vector2 = hotbar_span()
	x = maxf(x, minf(span.x, size.x * 0.5 - total * 0.5))
	var baseline: float = HudStyle.baseline_for(middle, HudStyle.TEXT_SMALL)
	HudStyle.text(self, Vector2(x, baseline), parts[0], HudStyle.TEXT_SMALL, HudStyle.TEXT_MAIN)
	var afford: bool = not main.holding_build_gun() or main.sim.can_afford(main.selected_type())
	HudStyle.text(self, Vector2(x + name_w, baseline), rest, HudStyle.TEXT_SMALL,
		HudStyle.TEXT_SUB if afford else HudStyle.DANGER)

# --- Build menu ---------------------------------------------------------------
## What the gun can be loaded with, with room to say what each thing does.
##
## The old hotbar had a name, a cost and a nine-pixel throughput line per machine
## and no space for anything else, so a player met the splitter as the word
## "분배기" and had to build one to find out. Here every entry gets its picture,
## its cost, and three lines saying what goes in, what comes out and what is
## peculiar about it -- which is the information the genre runs on.
const MENU_ROW := 74.0
## The shortest a build row is allowed to get. An icon is 40 tall and the two
## lines of text sit at 22 and 42, so this is the height at which the row still
## says everything it says.
const BUILD_ROW_MIN := 52.0
const MENU_W := 500.0

## How tall one row of the build list is.
##
## The card has always clamped its own height and the rows never did, so a list
## long enough to overflow drew its last machines *below* the card -- on a phone
## at the largest interface size, the two machines this ladder just added. The
## rows give way instead: the list is a catalogue and a shorter row is still a
## readable one, where a row drawn outside the window is not a row at all.
func build_menu_row_height() -> float:
	var rows: float = float(maxi(1, main.build_list().size()))
	var room: float = size.y - MARGIN * 2.0 - FRAME_HEADER - 42.0
	return clampf(room / rows, BUILD_ROW_MIN, MENU_ROW)

func build_menu_rect() -> Rect2:
	var rows: float = float(maxi(1, main.build_list().size()))
	var height: float = FRAME_HEADER + 12.0 + rows * build_menu_row_height() + 30.0
	var width: float = minf(MENU_W, size.x - MARGIN * 2.0)
	height = minf(height, size.y - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

func build_menu_row_rect(index: int) -> Rect2:
	var card: Rect2 = build_menu_rect()
	var step: float = build_menu_row_height()
	return Rect2(card.position + Vector2(8.0, FRAME_HEADER + 8.0 + float(index) * step),
		Vector2(card.size.x - 16.0, step - 4.0))

## Which row a point falls in, or -1. Used by touch, which has no arrow keys.
func build_menu_row_at(point: Vector2) -> int:
	if not main.build_menu_open:
		return -1
	# Returns the index into Defs.BUILDABLE, not the row on screen: the caller
	# loads the gun with it, and the gun's number is the table's.
	var list: Array[int] = main.build_list()
	for row in list.size():
		if build_menu_row_rect(row).has_point(point):
			return list[row]
	return -1

## The fire's window. What went in on the way here, and what can be made out of
## what is left.
##
## Deliberately small. The build list is a catalogue with a row per machine; this
## is one thing to make, and a card the size of the catalogue would be mostly
## empty space announcing how little there is.
# --- Inside the hut -----------------------------------------------------------
## The room used to be drawn here, as a card with its own cells, its own mover,
## its own facing rule and its own copies of the walk sheets. It is a place on
## the world grid now and the world layers draw it, which is what makes "she
## behaves the same indoors and out" a fact rather than a maintenance promise.
##
## What is left in the HUD is the light going out and coming back, because that
## is a thing done to the screen rather than to the room.
## Whether the black sheet is painted this frame.
##
## A predicate rather than a branch inside the draw call, because the failure it
## guards is invisible to a screenshot: a black screen and a black screen with
## the day's summary underneath it are the same picture.
func room_fade_visible() -> bool:
	return main.room_fade > 0.0

func _draw_room_fade() -> void:
	if not room_fade_visible():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf(main.room_fade, 0.0, 1.0)))

## How far below the title bar the first row starts. One constant, because the
## card's height and the rows' positions are the same measurement and the last
## time a window's two halves each had their own copy of a number, the plate hung
## fourteen pixels off the bottom of the screen.
const BASE_MENU_TOP := 14.0

func base_menu_rect() -> Rect2:
	var rows: float = float(maxi(1, main.base_rows().size()))
	# No state lines above the rows any more, so the card is 46px shorter and the
	# first row starts where they used to. Both numbers live here rather than
	# being written twice: `base_menu_row_rect` reads the same offset.
	var height: float = FRAME_HEADER + BASE_MENU_TOP + rows * MENU_ROW + 18.0
	var width: float = minf(MENU_W, size.x - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

## Which row of the fire's window a point is on, or -1.
##
## The window had no hit test at all, because it was reachable only by keyboard
## -- and on a phone that meant it opened and then could not be used: no cursor
## to move, no key to confirm, and every tap falling through to the tool row
## underneath. Which reads, from the outside, as the base doing nothing.
func base_menu_row_at(point: Vector2) -> int:
	for index in main.base_rows().size():
		if base_menu_row_rect(index).has_point(point):
			return index
	return -1

func base_menu_row_rect(index: int) -> Rect2:
	var card: Rect2 = base_menu_rect()
	return Rect2(card.position + Vector2(8.0, FRAME_HEADER + BASE_MENU_TOP - 4.0
		+ float(index) * MENU_ROW), Vector2(card.size.x - 16.0, MENU_ROW - 4.0))

# --- The machine window -------------------------------------------------------
## What this machine could make, and what it is doing about the one it is on.
##
## The rows are the recipe registry's, so a recipe added later appears here
## without this file being edited -- the same arrangement the build list has.

func machine_menu_rect() -> Rect2:
	var rows: float = float(maxi(1, main.machine_rows().size()))
	# One extra row's worth of header, which is where the machine's own state
	# goes: what is in it, what it is holding, and whether the grid is carrying
	# it. A window that only offers choices cannot explain why nothing is
	# happening.
	var height: float = FRAME_HEADER + BASE_MENU_TOP + 26.0 + rows * MENU_ROW + 18.0
	var width: float = minf(MENU_W, size.x - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

func machine_menu_row_rect(index: int) -> Rect2:
	var card: Rect2 = machine_menu_rect()
	return Rect2(card.position + Vector2(8.0, FRAME_HEADER + BASE_MENU_TOP + 26.0 - 4.0
		+ float(index) * MENU_ROW), Vector2(card.size.x - 16.0, MENU_ROW - 4.0))

func machine_menu_row_at(point: Vector2) -> int:
	for index in main.machine_rows().size():
		if machine_menu_row_rect(index).has_point(point):
			return index
	return -1

func _draw_machine_menu() -> void:
	if not main.machine_menu_open:
		return
	var machine = main.sim.machine_at(main.machine_menu_cell)
	if machine == null:
		return
	_dim(0.45)
	var card: Rect2 = machine_menu_rect()
	_frame(card, Defs.COL_CORE, Defs.machine_name(machine.type))

	# The machine's own state, on one line under the title: what it is holding on
	# the way in, how far through it is, what it is holding on the way out, and
	# what the grid is doing. Four facts, and the one that is wrong is the answer
	# to "why is nothing coming out".
	var running: Dictionary = main.sim.recipe_of(machine)
	var state: Array[String] = []
	if not running.is_empty():
		state.append("입력 %s" % _held(machine.buffer, running["inputs"], true))
		state.append("출력 %s" % _held(machine.outbox, running["outputs"], false))
	state.append(main.sim.meter_status(machine))
	_text(Vector2(card.position.x + 14.0, card.position.y + FRAME_HEADER + 16.0),
		"  ·  ".join(state), 12, Defs.COL_TEXT_DIM)
	# The bar is the progress, drawn rather than written: a number ticking from 0
	# to 3 is arithmetic and a bar that fills is the machine working.
	if not running.is_empty():
		var span: float = maxf(float(running["seconds"]), 0.001)
		var track := Rect2(card.position + Vector2(card.size.x - 130.0,
			FRAME_HEADER + 8.0), Vector2(116.0, 6.0))
		draw_rect(track, Color(1, 1, 1, 0.10))
		draw_rect(Rect2(track.position, Vector2(track.size.x
			* clampf(machine.progress / span, 0.0, 1.0), track.size.y)), Defs.COL_CORE)

	var rows: Array[Dictionary] = main.machine_rows()
	for index in rows.size():
		_draw_machine_row(index, rows[index], machine)

## What the machine is holding on one side of its recipe, or "없음".
##
## The going-in side is written against what a cycle costs -- "철판 1/2 · 전선 4/4"
## -- because with two materials the useful fact is not how much is in there, it
## is which one is short. The coming-out side has no target: it is a count of
## things waiting for somewhere to go.
func _held(store: Dictionary, ports: Array, needed: bool) -> String:
	var parts: Array[String] = []
	for port: Dictionary in ports:
		var item_type: int = int(port["item"])
		var have: int = int(store.get(item_type, 0))
		if needed:
			parts.append("%s %d/%d" % [Defs.ITEM_SHORT[item_type], have, int(port["amount"])])
		else:
			parts.append("%s %d" % [Defs.ITEM_SHORT[item_type], have])
	return " · ".join(parts) if not parts.is_empty() else "없음"

func _draw_machine_row(index: int, row: Dictionary, machine) -> void:
	var rect: Rect2 = machine_menu_row_rect(index)
	var on_cursor: bool = index == main.menu_index
	var running: bool = main.sim.recipe_of(machine) == row
	var accent: Color = Defs.COL_CORE
	if on_cursor:
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.14))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), accent)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.022))
	# The thing it makes, as its own picture. A row of Korean nouns is four rows
	# of Korean nouns once there are four recipes.
	var made: int = int((row["outputs"] as Array)[0]["item"])
	var icon := Rect2(rect.position + Vector2(10.0, rect.size.y * 0.5 - 20.0), Vector2(40.0, 40.0))
	draw_rect(icon.grow(3.0), Color(0, 0, 0, 0.30))
	draw_rect(icon.grow(3.0), Color(accent.r, accent.g, accent.b, 0.30), false, 1.0)
	Icons.draw_item(self, icon, made)
	var text_x: float = rect.position.x + 62.0
	_text(Vector2(text_x, rect.position.y + 22.0), String(row["name"]), 14, Defs.COL_TEXT)
	# The sentence the recipe is: what goes in, what comes out, how long.
	_text(Vector2(text_x, rect.position.y + 42.0),
		"%s → %s · %.0f초" % [Defs.ports_text(row["inputs"]), Defs.ports_text(row["outputs"]),
			float(row["seconds"])], 11, Defs.COL_TEXT_DIM)
	# Which one it is on, said on the row rather than only by the cursor -- the
	# cursor moves and this does not.
	if running:
		_text_in(Rect2(rect.position + Vector2(rect.size.x - 96.0, 22.0), Vector2(86.0, 16.0)),
			"생산 중", 12, accent, HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_base_menu() -> void:
	if not main.base_menu_open:
		return
	_dim(0.45)
	var card: Rect2 = base_menu_rect()
	# The title, and nothing about the keys. The window has a cursor on a row and
	# rows with prices on them; a player looking at that has already been told
	# what up and down do by the thing moving when they press them.
	_frame(card, Defs.COL_CORE, "기지")
	# Which step it is on, in the header opposite the title. The ladder is what
	# this window is for and the number was nowhere in it: the row underneath
	# says what the next rung costs, and "3개" means one thing on the second rung
	# and another on the ninth.
	_text_in(Rect2(card.position + Vector2(card.size.x - 90.0, 16.0), Vector2(80.0, 14.0)),
		"Lv %d" % Defs.base_level_shown(main.sim.base_level), 12,
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.95),
		HORIZONTAL_ALIGNMENT_RIGHT)
	# Two lines of state used to sit here: the circle and the stones in the fire
	# on one, the torches and their seconds on the other. Both are gone.
	#
	# The first said what the upgrade row already says better -- that row reads
	# "온기 7칸 → 9칸" next to its price, which is the same fact with the reason
	# to care attached. The second was a torch's countdown in a window about the
	# fire: the torch is in her hand, its clock is drawn on the tool it belongs
	# to, and a number repeated somewhere it does not belong is a number the
	# player has to check twice.
	var rows: Array[Dictionary] = main.base_rows()
	for index in rows.size():
		_draw_base_row(index, rows[index])

func _draw_base_row(index: int, row: Dictionary) -> void:
	var rect: Rect2 = base_menu_row_rect(index)
	var on_cursor: bool = index == main.menu_index
	var accent: Color = Defs.COL_CORE
	if String(row["kind"]) == "fuel":
		_draw_base_fuel_row(rect, on_cursor, accent)
		return
	var craft: Dictionary = Defs.BASE_CRAFTS[int(row["craft"])]
	var affordable: bool = main.sim.can_craft(String(craft["id"]))
	# A bin already standing is not unaffordable, it is done.
	var already: bool = String(craft["id"]) == "food_bin" and main.sim.food_placed
	if on_cursor:
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.14))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), accent)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.022))
	var icon := Rect2(rect.position + Vector2(10.0, rect.size.y * 0.5 - 20.0), Vector2(40.0, 40.0))
	draw_rect(icon.grow(3.0), Color(0, 0, 0, 0.30))
	draw_rect(icon.grow(3.0), Color(accent.r, accent.g, accent.b, 0.30), false, 1.0)
	Icons.draw_thing(self, icon,
		Icons.THING_FOOD if String(craft["id"]) == "food_bin" else Icons.THING_TORCH)
	var text_x: float = rect.position.x + 62.0
	_text(Vector2(text_x, rect.position.y + 22.0), String(craft["name"]), 14,
		Defs.COL_TEXT if affordable and not already else Defs.COL_TEXT_DIM)
	_text(Vector2(text_x, rect.position.y + 42.0), String(craft["note"]), 11, Defs.COL_TEXT_DIM)
	# The cost, on the right, coloured by whether it is actually payable.
	var cost: Dictionary = craft["cost"]
	var parts: Array[String] = []
	for item_type: int in cost:
		parts.append("%s %d" % [Defs.ITEM_SHORT[item_type], int(cost[item_type])])
	_text(Vector2(rect.position.x + rect.size.x - 96.0, rect.position.y + 32.0),
		"세워짐" if already else " · ".join(parts), 13,
		Defs.COL_TEXT_DIM if already else (Defs.COL_TEXT if affordable else Defs.COL_DANGER))

## The row that hands the fire what she is carrying. Shown only while there is
## something to hand over, so it is never a row that refuses.
func _draw_base_fuel_row(rect: Rect2, on_cursor: bool, accent: Color) -> void:
	if on_cursor:
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.14))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), accent)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.022))
	var icon := Rect2(rect.position + Vector2(10.0, rect.size.y * 0.5 - 20.0), Vector2(40.0, 40.0))
	draw_rect(icon.grow(3.0), Color(0, 0, 0, 0.30))
	draw_rect(icon.grow(3.0), Color(accent.r, accent.g, accent.b, 0.30), false, 1.0)
	Icons.draw_thing(self, icon, Icons.THING_CORE)
	var sim = main.sim
	# Through `fuel_progress()` rather than recomputed here. The number the player
	# reads and the number the code computes were two separate calculations of the
	# same thing -- this one drawn, that one asserted by the golden test -- which
	# is a pair that can only ever drift apart quietly.
	var span: Array[int] = main.fuel_progress()
	var have: int = span[0]
	var want: int = span[1]
	var ready: bool = sim.can_feed_base()
	var text_x: float = rect.position.x + 62.0
	# "연료 투입" described the gesture -- tipping a pack into a fire -- and left
	# the player to work out what it bought. This row is the only way the circle
	# ever grows, so it is named after that. "강화" rather than "업그레이드"
	# because what happens is that the fire gets stronger, and a loanword for a
	# menu operation says less about it than the plain word does.
	_text(Vector2(text_x, rect.position.y + 22.0), "기지 강화", 14,
		Defs.COL_TEXT if ready else Defs.COL_TEXT_DIM)
	# What it does under the title and what it costs on the right, exactly like
	# every other row in this window. The previous version spelled out a running
	# sum -- "다음 단계까지 열석 3개 · 3개 부족" -- which is a sentence about
	# arithmetic where the rest of the window has a price tag, and a reader who
	# had learned where to look had to read this one differently.
	# What it does, without the two numbers it used to do it with. "온기 7칸 →
	# 9칸" is the circle on the snow written out in figures, and the circle is
	# already on the snow -- a player who feeds the fire watches it widen. The
	# top of the ladder still says something, because there the row refuses and a
	# refusal with no reason is a broken key.
	var next_level: Dictionary = Defs.next_base_level(sim.stones_in)
	var effect: String = "온기가 더 넓어지지 않습니다" if next_level.is_empty() \
		else "불이 더 멀리까지 닿는다"
	_text(Vector2(text_x, rect.position.y + 42.0), effect, 11,
		Defs.COL_CORE if ready else Defs.COL_TEXT_DIM)
	if want > 0:
		# Have against need, not need alone. "열석 3" answers what it costs and
		# leaves "how far am I" to arithmetic; 0/3 is the same fact with the
		# player's half already in it.
		_text(Vector2(rect.position.x + rect.size.x - 96.0, rect.position.y + 32.0),
			"%s %d/%d" % [Defs.ITEM_SHORT[Defs.ITEM_HEATSTONE], have, want], 13,
			Defs.COL_TEXT if ready else Defs.COL_DANGER)

func _draw_build_menu() -> void:
	if not main.build_menu_open:
		return
	_dim(0.45)
	var card: Rect2 = build_menu_rect()
	_frame(card, Defs.COL_CORE, "건설 목록")
	var list: Array[int] = main.build_list()
	for row in list.size():
		_draw_build_row(row, list[row])

## `row` is where it sits on screen; `index` is which entry of Defs.BUILDABLE it
## is. They stopped being the same number when the list started leaving out
## machines the player has never had a reason to hear of.
func _draw_build_row(row: int, index: int) -> void:
	var type: int = Defs.BUILDABLE[index]
	var rect: Rect2 = build_menu_row_rect(row)
	var on_cursor: bool = index == main.menu_index
	var loaded: bool = index == main.selected_index
	var locked: bool = not main.sim.is_unlocked(type)
	var accent: Color = Defs.machine_color(type)

	if on_cursor:
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.14))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(3.0, rect.size.y)), accent)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.022))

	var icon := Rect2(rect.position + Vector2(10.0, rect.size.y * 0.5 - 20.0), Vector2(40.0, 40.0))
	draw_rect(icon.grow(3.0), Color(0, 0, 0, 0.30))
	draw_rect(icon.grow(3.0), Color(accent.r, accent.g, accent.b, 0.30), false, 1.0)
	Icons.draw_machine(self, icon, type)
	# Freshly unlocked since the list was last open: a small NEW over the icon,
	# gone the next time the menu opens. The generator is the first machine that
	# arrives *into* an existing list, and without this it is just another row.
	if main.new_in_menu.has(type):
		var chip := Rect2(icon.position + Vector2(-6.0, -8.0), Vector2(34.0, 14.0))
		draw_rect(chip, Defs.COL_CORE)
		_text_in(Rect2(chip.position + Vector2(0, 11.0), Vector2(chip.size.x, 12.0)),
			"NEW", 9, Color(0.1, 0.08, 0.05), HORIZONTAL_ALIGNMENT_CENTER)

	var text_x: float = rect.position.x + 62.0
	# The three input/output lines stack down the right half rather than sitting
	# in three columns across the row. Laid out horizontally they were about 145
	# pixels of text in a 124 pixel column, so every one of them ran into the
	# next -- measured, not guessed, after the first version did exactly that.
	var io_x: float = rect.position.x + rect.size.x - 196.0
	_text(Vector2(text_x, rect.position.y + 20.0), Defs.MACHINE_NAMES[type], 14,
		Defs.COL_TEXT_DIM if locked else Defs.COL_TEXT)
	if loaded and not locked:
		_text(Vector2(text_x, rect.position.y + 58.0), "장전됨", 11, accent)

	if locked:
		# Locked entries stay visible and say what opens them. Seeing what is
		# coming is half of why a build list exists at all.
		# The sentence comes from Defs, which owns the table. This used to index
		# the table here and build the line itself, and when a condition grew to
		# two materials that copy would have gone on naming one of them.
		var line: String = Defs.unlock_line(type)
		_text(Vector2(text_x, rect.position.y + 38.0), line, 11, Defs.COL_TEXT_DIM)
		draw_rect(rect, Color(0.02, 0.03, 0.06, 0.34))
		return

	_text(Vector2(text_x, rect.position.y + 38.0), Defs.MACHINE_HINTS[type], 10, Defs.COL_TEXT_DIM)
	if not loaded:
		var cost := ""
		for item_type: int in Defs.MACHINE_COSTS[type]:
			cost += "%s %d  " % [Defs.ITEM_SHORT[item_type], int(Defs.MACHINE_COSTS[type][item_type])]
		_text(Vector2(text_x, rect.position.y + 58.0), cost.strip_edges(), 11,
			Defs.COL_CORE if main.sim.can_afford(type) else Defs.COL_DANGER)
	var lines: Array[String] = Defs.machine_io(type)
	for line_index in lines.size():
		_text(Vector2(io_x, rect.position.y + 20.0 + float(line_index) * 15.0),
			lines[line_index], 9, Defs.COL_MACHINE_EDGE)

## R rotates the output direction, but until now nothing on screen said which
## way was currently selected, so the key felt like it did nothing.
func _draw_direction_chip() -> void:
	if not direction_visible():
		return
	var dir: Vector2i = main.build_dir
	var label: String = _direction_label(dir)
	var box: Rect2 = direction_rect
	HudStyle.panel(self, box, HudStyle.CHIP)
	var middle: float = box.get_center().y
	HudStyle.text(self, Vector2(box.position.x + HudStyle.PANEL_PADDING,
		HudStyle.baseline_for(middle, HudStyle.TEXT_SMALL)), label, HudStyle.TEXT_SMALL,
		HudStyle.TEXT_MAIN)
	# The same arrow the world preview draws, so the two read as one statement.
	var at := Vector2(box.end.x - 16.0, middle)
	var d := Vector2(dir)
	var perp := Vector2(-d.y, d.x)
	var tip: Vector2 = at + d * 6.0
	draw_line(at - d * 5.0, tip - d * 3.0, HudStyle.ACCENT, 2.2)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - d * 4.5 + perp * 3.2, tip - d * 4.5 - perp * 3.2]), HudStyle.ACCENT)

# --- Overlays ----------------------------------------------------------------

func _dim(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, alpha))

## Geometry only, so the settings layout can be computed without drawing. Narrows
## on small screens rather than hanging off both edges.
func _card_rect(height: float) -> Rect2:
	var width: float = minf(420.0, size.x - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

## Every full-screen card -- title, day summary, settings -- through the same
## frame as every corner panel, so the interface reads as one object.
func _card(height: float) -> Rect2:
	var card: Rect2 = _card_rect(height)
	_frame(card, Defs.COL_CORE)
	return card

## Where the title painting goes. Static and handed its own size, so the one
## thing that can go wrong here can be measured rather than looked for.
static func title_rect(screen: Vector2) -> Rect2:
	var source := Vector2(float(TITLE_ART.get_width()), float(TITLE_ART.get_height()))
	var scale: float = maxf(screen.x / source.x, screen.y / source.y)
	var drawn: Vector2 = source * scale
	return Rect2((screen - drawn) * 0.5, drawn)

## The rows, and where each one is drawn.
##
## Measured rather than drawn straight, so a test can ask where a row is and a
## touch can ask which row it landed on. One list, one geometry: the picture and
## the hit test cannot come to disagree about where 처음부터 is.
const TITLE_ROW_H := 30.0
const TITLE_MENU_W := 210.0

func title_menu_rect(index: int) -> Rect2:
	var rows: int = main.title_menu().size()
	var block: float = float(rows) * TITLE_ROW_H
	var top: float = size.y * 0.64 - block * 0.5
	return Rect2(size.x * 0.5 - TITLE_MENU_W * 0.5, top + float(index) * TITLE_ROW_H,
		TITLE_MENU_W, TITLE_ROW_H - 4.0)

## Which row a point is on, or -1. Used by the pad.
func title_menu_at(point: Vector2) -> int:
	for index in main.title_menu().size():
		if title_menu_rect(index).has_point(point):
			return index
	return -1

func _draw_title_menu() -> void:
	var rows: Array[int] = main.title_menu()
	var cursor: int = clampi(main.title_index, 0, maxi(0, rows.size() - 1))
	for index in rows.size():
		var box: Rect2 = title_menu_rect(index)
		var chosen: bool = index == cursor
		if chosen:
			# The selected row is a lit plate rather than a coloured word: on a
			# painting, colour alone is not enough to say which line is armed.
			var beat: float = 0.72 + sin(float(Time.get_ticks_msec()) / 380.0) * 0.14
			_panel(box, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.22 * beat),
				Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.85), 1.0)
		_text_in(Rect2(box.position + Vector2(0.0, box.size.y * 0.5 + 6.0),
			Vector2(box.size.x, 20.0)), main.MENU_LABELS[rows[index]], 17,
			Defs.COL_CORE if chosen else Defs.COL_TEXT)

## The painting behind the title.
##
## It used to be the live world, dimmed: whatever tiles the run happened to be
## looking at when the game opened. That is a screenshot of a save file, not a
## first impression, and on a fresh install it was an empty snowfield.
##
## Painted in the sprite style rather than the cutscene's watercolour, because
## this is the first picture of Grim anyone sees and the one they compare the
## character against a minute later.
const TITLE_ART: Texture2D = preload("res://assets/title.webp")

func _draw_title() -> void:
	# Cover, not fit: the painting is 16:9 and so is the game, but a phone held
	# upright is not, and a letterboxed title on a phone is mostly letterbox.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 1.0))
	draw_texture_rect(TITLE_ART, title_rect(size), false)
	# One even dim, and nothing cleverer.
	#
	# The lines that would not read were not fighting the brightness, they were
	# fighting their own colour: COL_TEXT_DIM is a muted blue-grey picked against
	# the HUD's dark panels, and on a painted sky it is almost exactly the
	# background's luminance. Brightening those two fixed it.
	#
	# A graded scrim under the text was tried first and made it worse in a way a
	# contrast number does not show: twenty flat strips across a smooth sky are
	# twenty visible bands. The repository already had "a hard edge across the art
	# reads as a seam" written down about the previous version of this line, and
	# a soft edge built out of steps is the same fault with more steps.
	_dim(0.38)
	var full := func(y: float) -> Rect2: return Rect2(0, y, size.x, 40)
	_text_in(full.call(size.y * 0.30), "MOTORIO", 56, Defs.COL_CORE)
	# The subtitle used to read "O N E   S H O T". It survived the rename because
	# every search for the old name looked for motorio-oneshot, motorio_oneshot,
	# OneShot, One Shot and oneshot -- and none of those match a string with a
	# space between every letter. It was on the first screen of the game for four
	# versions after the name it referred to stopped existing.
	# What the game is now, rather than what it was. This read "하룻밤 안에 공장을
	# 세워 열을 최대한 모으세요" -- the one-night score run, which has not been the
	# shape of this game since the day stopped ending it.
	_text_in(full.call(size.y * 0.52), "얼어붙은 행성에 불을 피우고, 그 불을 키워 나가세요.", 16, Defs.COL_TEXT)
	# Brighter than COL_TEXT_DIM, which is a muted blue-grey chosen against the
	# HUD's dark panels. On a painted sky it is almost exactly the background's
	# own luminance, and a line the same brightness as what it sits on is a line
	# nobody reads however dark you make the picture behind it.
	_text_in(full.call(size.y * 0.52 + 24), "불에 열석을 넣을수록 온기가 넓어지고, 더 먼 곳에 닿는다.",
		13, Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, 0.82))
	_draw_title_menu()
	# There was a line of controls here ("←↑→↓ 이동  Z 사용  X 회수 ..."), the last
	# permanent key legend in the game. Gone in 1.0.41: the first key the game
	# names is the MOVE prompt in the corner, the moment it is needed, and the
	# whole list lives behind Esc in the guide. `test_hints` checks that prompt
	# against the bindings the way it checked this line.
	# So a player can say which build they are on without opening anything.
	_text_in(Rect2(0, size.y - MARGIN, size.x - MARGIN, 16), "v%s" % version_string(), 11,
		Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

## The opening. One picture at a time, filling the screen, with its line under
## it and nothing else -- no status, no hotbar, no frost vignette. The scene is
## the only thing the game is asking the player to look at.
##
## Drawn here rather than as its own node for the reason the night sequence is:
## the HUD paints a full-screen wash of its own, and a second overlay that does
## not know about it produced a night that looked like noon once already. One
## place decides what covers the screen.
func _draw_cutscene() -> void:
	var panels: Array[Dictionary] = Defs.CUTSCENE_PANELS
	var index: int = clampi(main.cutscene_panel, 0, panels.size() - 1)
	var elapsed: float = main.cutscene_time
	var span: float = Defs.cutscene_panel_seconds()
	# In, hold, out. Written as two ramps rather than a curve so the hold really
	# is a hold: a fade that never quite reaches one reads as a dirty screen.
	var alpha: float = 1.0
	if elapsed < Defs.CUTSCENE_FADE:
		alpha = elapsed / Defs.CUTSCENE_FADE
	elif elapsed > span - Defs.CUTSCENE_FADE:
		alpha = maxf(0.0, (span - elapsed) / Defs.CUTSCENE_FADE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 1.0))
	var art: Texture2D = panels[index]["art"]
	draw_texture_rect(art, cutscene_rect(size, index, elapsed), false, Color(1, 1, 1, alpha))
	# The line sits on a band of its own. Over watercolour, an outline alone is
	# not enough -- half of these panels have a bright sky exactly where the text
	# goes.
	var band := Rect2(0.0, size.y * 0.78, size.x, size.y * 0.22)
	draw_rect(band, Color(0.02, 0.03, 0.06, 0.62 * alpha))
	_draw_cutscene_lines(index, elapsed, alpha, band)
	var hint: String = "화면을 눌러 넘기기" if main.touch != null and main.touch.visible \
		else "아무 키나 눌러 넘기기   ·   Esc 건너뛰기"
	_text_in(Rect2(MARGIN, size.y - MARGIN, size.x - MARGIN * 2.0, 16.0), hint, 11,
		Color(Defs.COL_TEXT_DIM, alpha * 0.75))

## The caption, laid out run by run.
##
## Two things it has to do that one `draw_string` cannot. The lines are written
## with their own breaks -- a caption that decides its own break lands the comma
## where the writer put it, and the automatic one puts it wherever the window
## happens to be wide -- and the marked words are set in another face, bold, and
## will not sit still.
##
## Every run is measured in its own font before anything is drawn, because a
## centred line whose runs are measured in the body face and drawn in a wider one
## comes out off-centre by exactly the difference.
const CUTSCENE_TEXT := 17
const CUTSCENE_LINE_H := 26.0

func _draw_cutscene_lines(index: int, elapsed: float, alpha: float, band: Rect2) -> void:
	var lines: Array[Dictionary] = Defs.cutscene_runs(index)
	if lines.is_empty():
		return
	var point: int = cutscene_text_size(index)
	var line_height: float = CUTSCENE_LINE_H * float(point) / float(CUTSCENE_TEXT)
	var block: float = float(lines.size()) * line_height
	var top: float = band.position.y + (band.size.y - block) * 0.5 + line_height * 0.72
	for row in lines.size():
		var runs: Array = lines[row]["runs"]
		var width := 0.0
		for run: Dictionary in runs:
			width += _run_width(run, point)
		var cursor: float = size.x * 0.5 - width * 0.5
		var baseline: float = top + float(row) * line_height
		for run: Dictionary in runs:
			var text: String = String(run["text"])
			if text != "":
				var hot: bool = bool(run["hot"])
				var font: Font = UIFont.DISPLAY if hot else UIFont.FONT
				var at := Vector2(cursor, baseline)
				if hot:
					at += Defs.cutscene_word_shake(int(run["index"]), elapsed)
				draw_string(font, at + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					point, Color(0.02, 0.03, 0.06, 0.8 * alpha))
				draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, point,
					Color(Defs.COL_CORE if hot else Defs.COL_TEXT, alpha))
			cursor += _run_width(run, point)

## A run's advance, in the face it will actually be drawn in.
func _run_width(run: Dictionary, point: int) -> float:
	var font: Font = UIFont.DISPLAY if bool(run["hot"]) else UIFont.FONT
	return font.get_string_size(String(run["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, point).x

## How wide the widest line of a panel's caption is at a given size, so a test
## can ask whether it fits without drawing it.
func cutscene_text_width(index: int, point: int = CUTSCENE_TEXT) -> float:
	var widest := 0.0
	for line: Dictionary in Defs.cutscene_runs(index):
		var width := 0.0
		for run: Dictionary in line["runs"]:
			width += _run_width(run, point)
		widest = maxf(widest, width)
	return widest

## The size the caption is actually set at.
##
## The lines break where they are written, which is the point -- a caption that
## breaks itself puts the comma wherever the window happens to be wide. But a
## written break cannot know the screen is 390 pixels across, so the type comes
## down until the longest line fits. Shrinking rather than re-breaking, because
## the break is the writing and the size is not.
func cutscene_text_size(index: int) -> int:
	var room: float = size.x - MARGIN * 2.0
	var point: int = CUTSCENE_TEXT
	while point > 9 and cutscene_text_width(index, point) > room:
		point -= 1
	return point

## Where the picture goes. Static and handed its own size, so the one thing that
## can go wrong here can be measured rather than looked for.
##
## Cover, not fit: the panels are 16:9 and so is the game, but a phone held
## upright is not, and a letterboxed opening on a phone is mostly letterbox.
##
## And overscanned by however far this panel shakes. At exactly 16:9 a covering
## fit is the screen *exactly*, so any offset at all slides the picture off one
## edge and shows the background behind it -- the shake would put a black bar
## down the side of the frame it is supposed to make feel solid.
static func cutscene_rect(screen: Vector2, index: int, elapsed: float) -> Rect2:
	var panels: Array[Dictionary] = Defs.CUTSCENE_PANELS
	var panel: Dictionary = panels[clampi(index, 0, panels.size() - 1)]
	var art: Texture2D = panel["art"]
	var source := Vector2(float(art.get_width()), float(art.get_height()))
	# cutscene_shake never exceeds the panel's own amount on either axis, so
	# growing by that much on each side is exactly enough and no more.
	var pad: float = float(panel["shake"])
	var scale: float = maxf((screen.x + pad * 2.0) / source.x,
		(screen.y + pad * 2.0) / source.y)
	var drawn: Vector2 = source * scale
	var at: Vector2 = (screen - drawn) * 0.5 + Defs.cutscene_shake(index, elapsed)
	return Rect2(at, drawn)

## Read from the project settings rather than duplicated here, so the number on
## screen can never disagree with the one that was shipped.
func version_string() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## Top-left corner, on every screen including the title. A player whose HUD is
## too small to read has to be able to find this without reading anything, so it
## is an icon in a fixed corner rather than an entry in a menu.
## Unmissable while it is on. A sped-up run that looks like a normal one is how
## you end up drawing balance conclusions from a game running at ten times rate.
func _draw_debug_badge() -> void:
	if main.speed_index <= 0:
		return
	var label: String = "DEBUG  %.0f배속  (F2)" % main.debug_speed()
	var width: float = _text_width(label, 12) + 22.0
	var box := Rect2(size.x * 0.5 - width * 0.5, MARGIN, width, 24.0)
	_panel(box, Color(Defs.COL_DANGER.r, Defs.COL_DANGER.g, Defs.COL_DANGER.b, 0.22),
		Defs.COL_DANGER, 2.0)
	_text_in(Rect2(box.position + Vector2(0, 16), Vector2(box.size.x, 16)), label, 12,
		Defs.COL_DANGER)

## One line at the foot of the screen naming what is happening, so the sequence
## is legible the first time rather than a few seconds of the game apparently
## ignoring the player.
func _draw_night_caption() -> void:
	var text: String = ""
	match main.night_phase:
		main.Phase.GATHER: text = "고양이들이 숙소로 돌아옵니다"
		main.Phase.GLOW: text = "%d일차 밤 · 모두 숙소에 들어왔습니다" % main.day_number
		main.Phase.DAWN: text = "아침이 밝아옵니다"
		main.Phase.SPILL: text = "%d일차 아침" % main.day_number
	if text == "":
		return
	var width: float = _text_width(text, 14) + 48.0
	var box := Rect2(size.x * 0.5 - width * 0.5, size.y * 0.78, width, 34.0)
	_frame(box, Defs.COL_CORE)
	_text_in(Rect2(box.position + Vector2(0, 23), Vector2(box.size.x, 18)), text, 14,
		Defs.COL_TEXT)

# --- Throughput panel --------------------------------------------------------
## Rates are quoted per minute, matching every other number in the game. Per
## second would read 0.10 and 0.03 for machines on ten- and twenty-second cycles,
## which is a worse unit for the same information.
const METER_W := 244.0
const METER_ROW := 19.0
const METER_HEAD := 70.0
const METER_FOOT := 40.0

## Sized to its contents, then placed where it will not sit on top of anything
## the player also needs: under the objective chip, above the hotbar.
func meter_rect() -> Rect2:
	var machine = main.sim.machine_at(main.meter_cell)
	if machine == null:
		return Rect2()
	var rows: int = main.sim.meter_items(machine, false).size() \
		+ main.sim.meter_items(machine, true).size()
	var sections: int = 0
	if not main.sim.meter_items(machine, false).is_empty():
		sections += 1
	if not main.sim.meter_items(machine, true).is_empty():
		sections += 1
	var height: float = METER_HEAD + float(sections) * 20.0 + float(rows) * METER_ROW + METER_FOOT
	var width: float = column_width()
	# Directly under the materials, in the left column with everything else the
	# player reads. It used to hang off the top-right corner under the goal card.
	var box := Rect2(MARGIN, meter_top(), width, height)
	# The hotbar and the touch pad own the bottom of the screen. If the card no
	# longer fits between them, it rides up rather than being drawn underneath.
	var floor_line: float = hotbar_top() - HudStyle.SECTION_GAP
	if box.position.y + box.size.y > floor_line:
		box.position.y = maxf(status_top(), floor_line - box.size.y)
	return box

func _draw_meter_card() -> void:
	if main.meter_cell == Vector2i(9999, 9999):
		return
	var sim = main.sim
	var machine = sim.machine_at(main.meter_cell)
	if machine == null:
		return
	var box: Rect2 = meter_rect()
	_frame(box, Defs.machine_color(machine.type), "처리량")
	var origin: Vector2 = box.position

	var chip := Rect2(origin + Vector2(FRAME_PAD, FRAME_HEADER + 4.0), Vector2(20.0, 20.0))
	Icons.draw_machine(self, chip, machine.type)
	_text(origin + Vector2(FRAME_PAD + 26.0, FRAME_HEADER + 19.0),
		Defs.MACHINE_NAMES[machine.type], 15, Defs.COL_TEXT)
	# C, not X. The meter is the one panel the world keeps running behind, so X
	# there is still 회수 -- and a label naming it would be inviting the player to
	# demolish the machine they are reading.
	_text_in(Rect2(origin + Vector2(box.size.x - 74, 16), Vector2(62, 14)), "C 닫기", 11,
		Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	var status: String = sim.meter_status(machine)
	# The status line is the diagnosis, so it is coloured by whether anything is
	# wrong rather than being one more grey caption.
	var healthy: bool = status.begins_with("가동") or status == "운반 중" or status == "반입구"
	_text(origin + Vector2(FRAME_PAD, FRAME_HEADER + 36.0), status, 12,
		Defs.COL_CORE if healthy else Defs.COL_DANGER)

	var y: float = METER_HEAD
	y = _draw_meter_side(machine, box, y, false)
	y = _draw_meter_side(machine, box, y, true)

	draw_line(origin + Vector2(12, y + 4), origin + Vector2(box.size.x - 12, y + 4),
		Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.7), 1.0)
	_text(origin + Vector2(FRAME_PAD, y + 22), sim.meter_buffer(machine), 11, Defs.COL_TEXT_DIM)
	var span: float = sim.meter_span(machine)
	var note: String = "측정 중…" if span < Defs.METER_WINDOW else "최근 %d초 평균" % int(Defs.METER_WINDOW)
	# On the same baseline as the buffer line: at y+12 the note's ascenders ran
	# through the divider rule above it.
	_text_in(Rect2(origin + Vector2(box.size.x - 116, y + 22), Vector2(104, 14)), note, 11,
		Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

## One half of the card. Returns the y it finished at, so the two sides stack
## without either needing to know how many rows the other drew.
func _draw_meter_side(machine, box: Rect2, y: float, outgoing: bool) -> float:
	var sim = main.sim
	var items: Array[int] = sim.meter_items(machine, outgoing)
	if items.is_empty():
		return y
	var origin: Vector2 = box.position
	var rated: Dictionary = sim.design_rates(machine)[("out" if outgoing else "in")]
	_text(origin + Vector2(FRAME_PAD, y + 12), "출력" if outgoing else "입력", 11, Defs.COL_MACHINE_EDGE)
	_text_in(Rect2(origin + Vector2(box.size.x - 150, y + 2), Vector2(138, 14)),
		"실측 / 설계 (개/분)", 10, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	y += 20.0
	for item_type: int in items:
		var measured: float = sim.meter_rate(machine, item_type, outgoing)
		# Belts and splitters are rated for a throughput, not for a material, so
		# their figure is filed under -1 and applies to whatever passes through.
		var design: float = float(rated.get(item_type, rated.get(-1, 0.0)))
		Icons.draw_item(self, Rect2(origin + Vector2(FRAME_PAD, y), Vector2(16.0, 16.0)), item_type)
		_text(origin + Vector2(FRAME_PAD + 20.0, y + 12), Defs.ITEM_SHORT[item_type], 12, Defs.COL_TEXT)
		# Falling short of the rated figure is the whole reason to open this panel,
		# so the measured number carries the warning colour and the rated one stays
		# quiet -- the rated number is never the problem.
		var short: bool = design > 0.0 and measured < design * 0.9
		_text_in(Rect2(origin + Vector2(box.size.x - 150, y + 12), Vector2(80, 14)),
			"%.1f" % measured, 13, Defs.COL_DANGER if short else Defs.COL_CORE,
			HORIZONTAL_ALIGNMENT_RIGHT)
		var design_label: String = "/ %.1f" % design if design > 0.0 else "/ —"
		_text_in(Rect2(origin + Vector2(box.size.x - 66, y + 12), Vector2(54, 14)),
			design_label, 12, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		y += METER_ROW
	return y

# --- The slot machine ---------------------------------------------------------

## The coin, drawn once and reused everywhere a number of them appears, so the
## corner button and the card cannot end up depicting different currencies.
func _coin(at: Vector2, radius: float) -> void:
	var gold: Color = Defs.RARITY_COLORS[Defs.RARITY_SSR]
	draw_circle(at, radius, gold)
	draw_circle(at - Vector2(radius * 0.28, radius * 0.30), radius * 0.42, gold.lightened(0.35))
	draw_arc(at, radius, 0.0, TAU, 18, Defs.OUTLINE, maxf(1.0, radius * 0.16))

## The corner button. Coin, count, word: the icon alone does not say what the
## machine gives you and the word alone does not say it costs something.
func _draw_gacha_button() -> void:
	var rect: Rect2 = gacha_button_rect
	if rect.size.x <= 0.0:
		return
	var accent: Color = Defs.RARITY_COLORS[Defs.RARITY_SSR]
	var edge: float = 0.55
	if main.gacha_open:
		edge = 0.95
	_panel(rect, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.92),
		Color(accent.r, accent.g, accent.b, edge))
	_coin(rect.position + Vector2(17.0, 18.0), 7.0)
	_text(rect.position + Vector2(29.0, 23.0), "%d" % main.sim.coins, 14, Defs.COL_TEXT)
	_text_in(Rect2(rect.position + Vector2(0.0, 39.0), Vector2(rect.size.x, 14.0)),
		"가챠", 11, accent)
	# While the reels turn with the window shut, the corner still says so.
	if main.gacha_spin >= 0.0 and not main.gacha_open:
		var sweep: float = clampf(1.0 - main.gacha_spin / Defs.GACHA_SPIN_SECONDS, 0.0, 1.0)
		draw_arc(rect.position + Vector2(17.0, 17.0), 12.0, -PI * 0.5,
			-PI * 0.5 + TAU * sweep, 24, accent, 2.0)

func _draw_gacha_card() -> void:
	if not main.gacha_open:
		return
	_dim(0.45)
	var card: Rect2 = gacha_card_rect
	var accent: Color = Defs.RARITY_COLORS[Defs.RARITY_SSR]
	_frame(card, accent, "가챠 슬롯머신   ← → 선택 · Z 돌리기 · X 닫기")
	# The purse, top right, because every button below is priced in it.
	_coin(card.position + Vector2(card.size.x - 62.0, FRAME_HEADER + 24.0), 9.0)
	_text(card.position + Vector2(card.size.x - 46.0, FRAME_HEADER + 30.0),
		"%d" % main.sim.coins, 16, Defs.COL_TEXT)
	_draw_gacha_stage(card)
	_draw_gacha_odds(card)
	for index in gacha_pull_rects.size():
		_draw_gacha_pull(index)

## The window inside the window: three reels while they turn, and what came out
## once they stop. One area for both, because the result *is* what the reels
## landed on -- a separate result panel would give the machine two places to look
## at exactly the moment the player is looking hardest.
func _draw_gacha_stage(card: Rect2) -> void:
	var area := Rect2(card.position + Vector2(22.0, FRAME_HEADER + 44.0),
		Vector2(card.size.x - 44.0, 150.0))
	draw_rect(area, Color(0.02, 0.03, 0.06, 0.55))
	draw_rect(area, Color(1, 1, 1, 0.06), false, 1.0)
	if main.gacha_spin >= 0.0:
		_draw_gacha_reels(area)
		return
	if main.gacha_results.is_empty():
		_text_in(Rect2(area.position + Vector2(0.0, area.size.y * 0.5 + 6.0),
			Vector2(area.size.x, 22.0)), "코인을 넣고 돌리세요", 14, Defs.COL_TEXT_DIM)
		return
	_draw_gacha_results(area)

## Three reels, each a little slower than the last and all of them easing down,
## so they settle one after another instead of stopping in unison.
func _draw_gacha_reels(area: Rect2) -> void:
	var elapsed: float = Defs.GACHA_SPIN_SECONDS - maxf(main.gacha_spin, 0.0)
	var brake: float = 1.0 - clampf(elapsed / Defs.GACHA_SPIN_SECONDS, 0.0, 1.0) * 0.88
	var gap := 14.0
	var tile: float = minf(GACHA_REEL, (area.size.x - gap * 4.0) / 3.0)
	var top: float = area.position.y + area.size.y * 0.5 - tile * 0.5 - 8.0
	for reel in 3:
		var box := Rect2(area.get_center().x + (float(reel) - 1.0) * (tile + gap) - tile * 0.5,
			top, tile, tile)
		var face: int = int(elapsed * (24.0 - float(reel) * 6.0) * brake) % Defs.RARITY_NAMES.size()
		var tint: Color = Defs.RARITY_COLORS[face]
		draw_rect(box, Color(tint.r, tint.g, tint.b, 0.16))
		draw_rect(box, Color(tint.r, tint.g, tint.b, 0.7), false, 1.0)
		_text_in(Rect2(box.position + Vector2(0.0, box.size.y * 0.5 + 9.0),
			Vector2(box.size.x, 24.0)), Defs.RARITY_NAMES[face], 22, tint)
	_text_in(Rect2(area.position + Vector2(0.0, area.size.y - 16.0), Vector2(area.size.x, 18.0)),
		"돌리는 중", 12, Defs.COL_TEXT_DIM)

## What came out, one tile per cat, five to a row so a ten-pull is two tidy rows
## rather than a list nobody reads.
func _draw_gacha_results(area: Rect2) -> void:
	var pulls: Array[int] = main.gacha_results
	var columns: int = clampi(pulls.size(), 1, 5)
	var rows: int = int(ceil(float(pulls.size()) / float(columns)))
	var gap := 8.0
	var tile: float = minf((area.size.x - gap * float(columns + 1)) / float(columns),
		(area.size.y - 30.0 - gap * float(rows + 1)) / float(rows))
	var block_w: float = float(columns) * tile + float(columns - 1) * gap
	var origin := Vector2(area.get_center().x - block_w * 0.5, area.position.y + 10.0)
	var counts: Array[int] = []
	for _grade in Defs.RARITY_NAMES.size():
		counts.append(0)
	for index in pulls.size():
		var grade: int = pulls[index]
		counts[grade] += 1
		var column: int = index % columns
		var row: int = index / columns
		var box := Rect2(origin + Vector2(float(column) * (tile + gap), float(row) * (tile + gap)),
			Vector2(tile, tile))
		var tint: Color = Defs.RARITY_COLORS[grade]
		draw_rect(box, Color(tint.r, tint.g, tint.b, 0.18))
		draw_rect(box, Color(tint.r, tint.g, tint.b, 0.85), false, 1.0)
		# The animal gets the top of the tile and the grade gets a band of its own
		# underneath. The band is a text height rather than a fraction, because
		# the letter does not shrink with the tile: at ten pulls the tiles are
		# half the size and a proportional band put the letter back on the cat's
		# paws, which is the thing it was moved out of.
		var band: float = minf(15.0, tile * 0.34)
		var art := Rect2(box.position + Vector2(tile * 0.06, tile * 0.03),
			Vector2(tile * 0.88, box.size.y - band - tile * 0.05))
		Icons.draw_grade(self, art, grade)
		_text_in(Rect2(box.position + Vector2(0.0, box.size.y - 5.0), Vector2(box.size.x, 14.0)),
			Defs.RARITY_NAMES[grade], 11, tint)
	var parts: Array[String] = []
	for grade in Defs.RARITY_NAMES.size():
		if counts[grade] > 0:
			parts.append("%s %d" % [Defs.RARITY_NAMES[grade], counts[grade]])
	_text_in(Rect2(area.position + Vector2(0.0, area.size.y - 12.0), Vector2(area.size.x, 16.0)),
		" · ".join(parts), 12, Defs.COL_TEXT)

## The table itself, on the machine. A gacha that will not show its own numbers
## is asking to be trusted about the one thing the player cannot check.
func _draw_gacha_odds(card: Rect2) -> void:
	var row := Rect2(card.position + Vector2(22.0, card.size.y - 156.0),
		Vector2(card.size.x - 44.0, 16.0))
	var width: float = row.size.x / float(Defs.RARITY_NAMES.size())
	for grade in Defs.RARITY_NAMES.size():
		var tint: Color = Defs.RARITY_COLORS[grade]
		var box := Rect2(row.position + Vector2(float(grade) * width, 0.0),
			Vector2(width, row.size.y))
		_text_in(box, Defs.RARITY_NAMES[grade], 12, tint)
		_text_in(Rect2(box.position + Vector2(0.0, 15.0), Vector2(box.size.x, 14.0)),
			"%.1f%%" % Defs.RARITY_PERCENT[grade], 10, Defs.COL_TEXT_DIM)

func _draw_gacha_pull(index: int) -> void:
	var rect: Rect2 = gacha_pull_rects[index]
	var count: int = Defs.GACHA_COUNTS[index]
	var ready: bool = main.sim.coins >= count and main.gacha_spin < 0.0
	var tint: Color = Defs.COL_CORE
	if not ready:
		tint = Defs.COL_TEXT_DIM
	var fill: float = 0.10
	if index == main.gacha_index:
		fill = 0.24
	_panel(rect, Color(tint.r, tint.g, tint.b, fill), Color(tint.r, tint.g, tint.b, 0.8))
	_coin(rect.position + Vector2(16.0, 19.0), 6.0)
	_text(rect.position + Vector2(26.0, 24.0), "%d" % count, 16, Defs.COL_TEXT)
	_text_in(Rect2(rect.position + Vector2(0.0, rect.size.y - 6.0), Vector2(rect.size.x, 14.0)),
		"%d마리" % count, 10, Defs.COL_TEXT_DIM)

func _draw_settings_button() -> void:
	var rect: Rect2 = settings_button_rect
	if rect.size.x <= 0.0:
		return
	var open: bool = main.state == main.State.SETTINGS
	HudStyle.panel(self, rect, HudStyle.BUTTON_ON if open else HudStyle.BUTTON)
	var centre: Vector2 = rect.position + rect.size * 0.5
	var radius: float = rect.size.x * 0.24
	var tint: Color = HudStyle.ACCENT if open else HudStyle.TEXT_MAIN
	for tooth in 8:
		var dir := Vector2.from_angle(float(tooth) * TAU / 8.0)
		draw_line(centre + dir * radius, centre + dir * (radius + rect.size.x * 0.14), tint, 2.0)
	draw_arc(centre, radius, 0.0, TAU, 24, tint, 2.2)
	draw_circle(centre, radius * 0.38, tint)

# --- The guide ------------------------------------------------------------------
## The controls, drawn as a keyboard rather than listed as sentences.
##
## This is where the legend that used to sit in the corner of the play screen
## went. A permanent list of controls is the opposite of what the rest of this
## game does -- everything else is taught by a prompt that appears when it is
## wanted and never comes back -- but the list still has to exist somewhere, and
## behind Esc is where a player goes when they want it.
##
## Every cap here is read from `Defs.KEY_GUIDE`, which names either the InputMap
## action or the raw keycode behind it. Nothing is spelled twice, so a key that
## is rebound or switched off cannot go on being advertised here; `test_hints`
## walks the same table and checks each cap against what is really bound.
const CAP := 30.0
const CAP_GAP := 6.0
const GUIDE_PANE_GAP := 18.0

## Four bands, and the window band wraps to a second line at every width the
## card is ever given -- there are six keys in it and the card is 420 wide.
func guide_height() -> float:
	return 5.0 * (CAP + 18.0) + GUIDE_PANE_GAP + 12.0

## One key cap, with its meaning beside it. Returns the x the next cap starts at.
## The same key the corner prompt draws (HudStyle.keycap), only larger -- a
## player who learned Z from the prompt finds the same Z here.
func _draw_cap(at: Vector2, label: String) -> float:
	return at.x + HudStyle.keycap(self, at, label, 1.0, CAP) + CAP_GAP

## How wide one entry comes out: its caps, then its meaning.
func _guide_entry_width(row: Dictionary) -> float:
	var wide := 0.0
	for cap: String in row["keys"]:
		wide += HudStyle.cap_width(cap, CAP) + CAP_GAP
	return wide + _text_width(String(row["label"]), 12) + 20.0

func _draw_guide(body: Rect2) -> void:
	var y: float = body.position.y + 4.0
	for pane: int in [Defs.PANE_MOVE, Defs.PANE_ACT, Defs.PANE_TOOL, Defs.PANE_WINDOW]:
		var rows: Array[Dictionary] = Defs.key_guide_pane(pane)
		if rows.is_empty():
			continue
		var x: float = body.position.x + 4.0
		for row: Dictionary in rows:
			# Wrapped whole rather than by the cap. Breaking between two caps of
			# one entry left "-" at the end of a line with its meaning on the
			# next, which reads as a key that does nothing: the zoom pair is one
			# control and has to stay one row.
			if x > body.position.x + 4.0 \
					and x + _guide_entry_width(row) > body.end.x - 4.0:
				x = body.position.x + 4.0
				y += CAP + 14.0
			for cap: String in row["keys"]:
				x = _draw_cap(Vector2(x, y), cap)
			_text(Vector2(x + 2.0, y + CAP * 0.5 + 5.0), String(row["label"]), 12,
				Defs.COL_TEXT_DIM)
			x += _text_width(String(row["label"]), 12) + 20.0
		y += CAP + 18.0

func _draw_settings_card() -> void:
	_dim(0.72)
	var card: Rect2 = settings_card_rect()
	_frame(card, Defs.COL_CORE)
	var w: float = card.size.x
	_text_in(Rect2(card.position + Vector2(0, 40), Vector2(w, 30)), "설정", 22, Defs.COL_TEXT)
	# The way out, in the corner. Drawn as the mark rather than the word, because
	# it is the one control on this panel whose meaning nobody has to be told.
	var x_at: Vector2 = settings_close_rect.position + settings_close_rect.size * 0.5
	draw_line(x_at + Vector2(-6.0, -6.0), x_at + Vector2(6.0, 6.0), Defs.COL_TEXT_DIM, 1.8)
	draw_line(x_at + Vector2(6.0, -6.0), x_at + Vector2(-6.0, 6.0), Defs.COL_TEXT_DIM, 1.8)

	var tabs: Array[int] = settings_tabs()
	for index in tabs.size():
		_draw_settings_tab(index, tabs[index])

	match settings_tab_kind():
		TAB_GAME:
			var rows: Array[int] = settings_rows()
			for index in rows.size():
				_draw_settings_row(index, rows[index])
		TAB_GUIDE:
			_draw_guide(settings_body_rect)
		_:
			# Save, load, main menu and quit act the moment they are chosen --
			# the slot list opens over this card, the other two leave. Nothing is
			# drawn in the body for them, and an explanatory paragraph under an
			# icon that has already done its job is the thing this panel was
			# rebuilt to stop having.
			pass

## One icon in the strip. The chosen one is lit and underlined; the rest are
## quiet. No labels-plus-descriptions: a picture and one word each.
func _draw_settings_tab(index: int, kind: int) -> void:
	var rect: Rect2 = settings_tab_rects[index]
	var on: bool = kind == settings_tab_kind()
	var tint: Color = Defs.COL_CORE if on else Defs.COL_TEXT_DIM
	if on:
		_panel(rect, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.12),
			Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.70))
	var centre := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 20.0)
	_draw_settings_icon(kind, centre, tint)
	_text_in(Rect2(Vector2(rect.position.x, rect.position.y + rect.size.y - 8.0),
		Vector2(rect.size.x, 14.0)), TAB_LABELS[kind], 11, tint)

## The six pictures, drawn from primitives. The font is subset from the game's
## own strings, so a glyph nobody typed is a glyph that is not in the file --
## which rules out the emoji these would otherwise be.
func _draw_settings_icon(kind: int, at: Vector2, tint: Color) -> void:
	match kind:
		TAB_SAVE:
			# A disk: a body, a shutter, a label.
			draw_rect(Rect2(at - Vector2(9, 9), Vector2(18, 18)), tint, false, 1.6)
			draw_rect(Rect2(at - Vector2(5, 9), Vector2(10, 6)), tint)
			draw_rect(Rect2(at - Vector2(6, 1), Vector2(12, 9)), tint, false, 1.2)
		TAB_LOAD:
			# A folder, open at the top.
			draw_rect(Rect2(at - Vector2(10, 6), Vector2(20, 13)), tint, false, 1.6)
			draw_line(at + Vector2(-10, -6), at + Vector2(-3, -10), tint, 1.6)
			draw_line(at + Vector2(-3, -10), at + Vector2(2, -6), tint, 1.6)
		TAB_GAME:
			# The same gear the corner button draws, smaller.
			for tooth in 8:
				var dir := Vector2.from_angle(float(tooth) * TAU / 8.0)
				draw_line(at + dir * 6.0, at + dir * 9.5, tint, 1.8)
			draw_arc(at, 6.0, 0.0, TAU, 20, tint, 1.8)
		TAB_GUIDE:
			# A keyboard: an outline and three rows of keys.
			draw_rect(Rect2(at - Vector2(11, 7), Vector2(22, 14)), tint, false, 1.5)
			for row in 2:
				for col in 4:
					draw_rect(Rect2(at + Vector2(-8.5 + float(col) * 4.5,
						-4.0 + float(row) * 4.5), Vector2(2.6, 2.6)), tint)
			draw_rect(Rect2(at + Vector2(-4.0, 3.4), Vector2(8.0, 2.2)), tint)
		TAB_TITLE:
			# A house.
			draw_line(at + Vector2(-10, 0), at + Vector2(0, -9), tint, 1.8)
			draw_line(at + Vector2(0, -9), at + Vector2(10, 0), tint, 1.8)
			draw_rect(Rect2(at + Vector2(-7, 0), Vector2(14, 9)), tint, false, 1.6)
		TAB_QUIT:
			# The power mark: a broken ring with a stem through the gap.
			draw_arc(at, 8.0, -PI * 0.35, PI * 1.35, 24, tint, 1.8)
			draw_line(at + Vector2(0, -10), at + Vector2(0, -2), tint, 1.8)

## The slot list, used for both saving and loading. Each row carries its number,
## when it was written, how far that run got, and a small drawing of the factory
## itself -- which is the thing that actually tells two saves apart.
func _draw_slot_picker() -> void:
	_dim(0.72)
	var card: Rect2 = _card(SLOT_CARD_H)
	_text_in(Rect2(card.position + Vector2(0, 30.0), Vector2(card.size.x, 22)),
		"저장할 슬롯" if slot_picker == 1 else "불러올 슬롯", 17, Defs.COL_TEXT)
	var cards: Array[Dictionary] = main.slot_cards()
	for row in slot_rects.size():
		var index: int = slot_scroll + row
		if index < cards.size():
			_draw_slot_row(row, index, cards[index])
	_draw_slot_scrollbar(card)
	_text_in(Rect2(card.position + Vector2(0, card.size.y - 16.0), Vector2(card.size.x, 16)),
		"↑ ↓ 선택 · Z 확인 · Esc 또는 X 취소     %d / %d" % [slot_index, main.SAVE_SLOTS - 1], 11,
		Defs.COL_TEXT_DIM)

## Where in the list the window is. With thirty-one slots a player needs to know
## whether they are near the top or the bottom, and a scrollbar says it without
## costing a row.
func _draw_slot_scrollbar(card: Rect2) -> void:
	var page: int = slot_page()
	if main.SAVE_SLOTS <= page:
		return
	var track := Rect2(card.position + Vector2(card.size.x - 20.0, FRAME_HEADER + 12.0),
		Vector2(4.0, float(page) * SLOT_ROW - 6.0))
	draw_rect(track, Color(1, 1, 1, 0.07))
	var span: float = float(page) / float(main.SAVE_SLOTS)
	var at: float = float(slot_scroll) / float(main.SAVE_SLOTS)
	draw_rect(Rect2(track.position + Vector2(0.0, track.size.y * at),
		Vector2(track.size.x, maxf(12.0, track.size.y * span))),
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.55))

func _draw_slot_row(row: int, index: int, card: Dictionary) -> void:
	if row >= slot_rects.size():
		return
	var rect: Rect2 = slot_rects[row]
	var on_cursor: bool = index == slot_index
	var exists: bool = bool(card["exists"])
	var accent: Color = Defs.COL_CORE if slot_picker == 1 else Defs.COL_MACHINE_EDGE
	if on_cursor:
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.14))
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.85), false, 1.0)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.025))

	var shot := Rect2(rect.position + Vector2(8.0, 6.0), Vector2(72.0, SLOT_ROW - 18.0))
	draw_rect(shot, Color(0.04, 0.05, 0.09, 0.9))
	draw_rect(shot, Color(accent.r, accent.g, accent.b, 0.25), false, 1.0)
	_draw_slot_thumbnail(shot, card["machines"])

	var label: String = "자동 저장" if index == 0 else "슬롯 %d" % index
	_text(rect.position + Vector2(92.0, 24.0), label, 13,
		Defs.COL_TEXT if exists else Defs.COL_TEXT_DIM)
	if exists:
		_text(rect.position + Vector2(92.0, 42.0),
			"%d일차 · 열석 %d개" % [int(card["day"]), int(card.get("stones", 0))], 11,
			Defs.COL_TEXT_DIM)
		_text_in(Rect2(rect.position + Vector2(rect.size.x - 180.0, 42.0), Vector2(170.0, 14)),
			main.slot_when(float(card["saved_at"])), 11, Defs.COL_TEXT_DIM,
			HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_text(rect.position + Vector2(92.0, 42.0), "비어 있음", 11, Defs.COL_TEXT_DIM)

## The factory, drawn from the cells the save recorded. The core sits in the
## middle and everything else is placed relative to it, so the picture is of the
## shape the player built rather than of wherever the camera happened to be.
func _draw_slot_thumbnail(rect: Rect2, cells) -> void:
	var list: Array = cells as Array
	if list.is_empty():
		return
	var span := 26.0
	var scale: float = minf(rect.size.x, rect.size.y) / span
	var centre: Vector2 = rect.get_center()
	var dot: float = maxf(1.0, scale * 0.9)
	for entry in list:
		var row: Array = entry as Array
		if row.size() < 3:
			continue
		var at: Vector2 = centre + Vector2(float(row[0]), float(row[1])) * scale
		if not rect.has_point(at):
			continue
		draw_rect(Rect2(at - Vector2(dot, dot) * 0.5, Vector2(dot, dot)),
			Defs.machine_color(int(row[2])))

## One row: an action, or a scale with its track.
##
## The focus ring is the same shape on both, because the cursor walks through
## both and a cursor that changes what it looks like halfway down a list reads
## as two lists.
func _draw_settings_row(index: int, kind: int) -> void:
	var rect: Rect2 = settings_row_rects[index]
	var focused: bool = settings_row == index and (main.touch == null or not main.touch.visible)
	if focused:
		_panel(rect.grow(2.0), Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.10),
			Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.75))
	var slider: int = settings_slider_of(kind)
	var label: String = ROW_LABELS[kind]
	if kind == ROW_SAVE and saved_flash > 0.0:
		label = "저장했습니다"
	if slider < 0:
		# The way out is filled rather than outlined: it is the one row that is
		# always the right answer to "I am done here".
		if kind == ROW_CLOSE:
			_panel(rect, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.18),
				Defs.COL_CORE)
		_text_in(Rect2(rect.position + Vector2(0, rect.size.y * 0.5 + 6.0),
			Vector2(rect.size.x, 22)), label, 16,
			Defs.COL_CORE if (kind == ROW_SAVE and saved_flash > 0.0) else Defs.COL_TEXT)
		return
	_text_in(Rect2(rect.position + Vector2(0, 20.0), Vector2(rect.size.x, 22)),
		label, 14, Defs.COL_TEXT if focused else Defs.COL_TEXT_DIM)
	_text_in(Rect2(rect.position + Vector2(0, 46.0), Vector2(rect.size.x, 26)),
		"%d%%" % int(round(slider_current(slider) * 100.0)), 20, Defs.COL_CORE)

	var range: Vector2 = slider_range(slider)
	var span: float = maxf(range.y - range.x, 0.001)
	var t: float = clampf((slider_current(slider) - range.x) / span, 0.0, 1.0)
	var track: Rect2 = slider_track_rects[slider]
	draw_rect(track, Color8(28, 36, 54))
	draw_rect(Rect2(track.position, Vector2(track.size.x * t, track.size.y)), Defs.COL_CORE)
	var knob := Vector2(track.position.x + track.size.x * t, track.position.y + track.size.y * 0.5)
	var held: bool = dragging_slider == slider
	draw_circle(knob, 17.0 if held else 15.0, Defs.COL_CORE)
	draw_circle(knob, 17.0 if held else 15.0, Color(0.02, 0.03, 0.06, 0.45), false, 1.6)

## The end of a run, and the only screen in this game that says so.
##
## Nothing but the sentence and a line closing under it. There is no score to
## report -- she froze in the first minute, before there was anything to have --
## and a summary of nothing is a card that makes the loss feel small.
func _draw_gameover() -> void:
	_dim(0.9)
	var card := _card(200.0)
	var w: float = card.size.x
	_text_in(Rect2(card.position + Vector2(0, 54), Vector2(w, 40)), "얼어붙었다", 34,
		Defs.COL_FROST_TINT)
	_text_in(Rect2(card.position + Vector2(0, 104), Vector2(w, 24)),
		"불을 피우지 못했다", 15, Defs.COL_TEXT_DIM)
	# The wait, drawn as a line that closes rather than as a number counting
	# down. Five seconds of a digit ticking is five seconds of watching a digit.
	var bar := Rect2(card.position + Vector2(w * 0.25, 152.0), Vector2(w * 0.5, 3.0))
	draw_rect(bar, Color(1, 1, 1, 0.10))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * main.gameover_fraction(), bar.size.y)),
		Defs.COL_FROST_TINT)

## --- The map ------------------------------------------------------------------
## A square card, because the world is square and a wide one would show more east
## than north for no reason. Sized against the shorter screen edge so it fits a
## phone held upright as well as a desktop window.
const MAP_SLIDER_H := 44.0
const MAP_PAD := 14.0

func _layout_map() -> void:
	var span: float = minf(minf(size.x, size.y) - MARGIN * 4.0, 460.0)
	map_card_rect = Rect2(size.x * 0.5 - span * 0.5, size.y * 0.5 - span * 0.5, span, span)
	var track: float = span - MAP_PAD * 4.0
	map_slider_rect = Rect2(map_card_rect.position.x + MAP_PAD * 2.0,
		map_card_rect.end.y - MAP_SLIDER_H + 6.0, track, 8.0)

## Where the map is drawn: everything but the strip the slider sits in.
func map_view_rect() -> Rect2:
	return Rect2(map_card_rect.position + Vector2(MAP_PAD, MAP_PAD + 26.0),
		Vector2(map_card_rect.size.x - MAP_PAD * 2.0,
			map_card_rect.size.y - MAP_PAD * 2.0 - MAP_SLIDER_H - 26.0))

## The record. A page with lines on it -- next to a folded map it has to be the
## other kind of paper at a glance, so the map is all folds and this is all
## ruling.
func _draw_log_button() -> void:
	var rect: Rect2 = log_button_rect
	if rect.size.x <= 0.0:
		return
	var open: bool = bool(main.get("log_open"))
	HudStyle.panel(self, rect, HudStyle.BUTTON_ON if open else HudStyle.BUTTON)
	var tint: Color = HudStyle.ACCENT if open else HudStyle.TEXT_MAIN
	var page := Rect2(rect.position + Vector2(9.0, 7.0), rect.size - Vector2(18.0, 14.0))
	draw_rect(page, Color(tint.r, tint.g, tint.b, 0.18))
	draw_rect(page, tint, false, 1.0)
	for index in 4:
		var y: float = page.position.y + page.size.y * (0.22 + 0.19 * float(index))
		var inset: float = page.size.x * (0.30 if index == 3 else 0.16)
		draw_line(Vector2(page.position.x + page.size.x * 0.16, y),
			Vector2(page.end.x - inset, y), Color(tint.r, tint.g, tint.b, 0.85), 1.0)

## Everything the game has said this session, newest first.
##
## Newest first because the question a player opens this to answer is "what just
## happened", not "how did the run begin" -- and because the run only gets
## longer, so a list that grows downward puts the answer further away every time.
func _draw_log_card() -> void:
	if not bool(main.get("log_open")):
		return
	_dim(0.45)
	var card: Rect2 = log_card_rect
	var entries: Array = main.get("play_log")
	_frame(card, Defs.COL_CORE, "기록   %d줄 · X 닫기" % entries.size())
	if entries.is_empty():
		_text_in(Rect2(card.position + Vector2(0.0, card.size.y * 0.5),
			Vector2(card.size.x, 20.0)), "아직 아무 일도 일어나지 않았습니다", 13,
			Defs.COL_TEXT_DIM)
		return
	var row_h: float = 22.0
	var top: float = card.position.y + FRAME_HEADER + 8.0
	var rows: int = int((card.end.y - 10.0 - top) / row_h)
	for index in mini(rows, entries.size()):
		var entry: Dictionary = entries[index]
		var y: float = top + float(index) * row_h + 15.0
		if index % 2 == 1:
			draw_rect(Rect2(card.position.x + 6.0, y - 14.0, card.size.x - 12.0, row_h - 2.0),
				Color(1, 1, 1, 0.025))
		# The stamp is the run's own clock, so reading a line back says when in
		# the game it happened rather than when in the afternoon.
		_text(Vector2(card.position.x + 14.0, y),
			"%d일 %s" % [int(entry["day"]), String(entry["clock"])], 11, Defs.COL_TEXT_DIM)
		_text(Vector2(card.position.x + 86.0, y), String(entry["text"]), 12,
			entry["color"])

func _draw_map_button() -> void:
	var rect: Rect2 = map_button_rect
	if rect.size.x <= 0.0:
		return
	var open: bool = bool(main.get("map_open"))
	HudStyle.panel(self, rect, HudStyle.BUTTON_ON if open else HudStyle.BUTTON)
	var tint: Color = HudStyle.ACCENT if open else HudStyle.TEXT_MAIN
	# A folded map: three panels with the folds drawn as the zigzag of the top
	# and bottom edges, which is what makes it read as a map rather than a page.
	var inner := Rect2(rect.position + Vector2(7.0, 9.0), rect.size - Vector2(14.0, 18.0))
	var third: float = inner.size.x / 3.0
	var lift: float = inner.size.y * 0.18
	var top: Array[Vector2] = []
	var bottom: Array[Vector2] = []
	for index in 4:
		var x: float = inner.position.x + third * float(index)
		var offset: float = lift if index % 2 == 0 else 0.0
		top.append(Vector2(x, inner.position.y + offset))
		bottom.append(Vector2(x, inner.end.y - lift + offset))
	for index in 3:
		draw_line(top[index], top[index + 1], tint, 1.6)
		draw_line(bottom[index], bottom[index + 1], tint, 1.6)
	for index in 4:
		draw_line(top[index], bottom[index], tint, 1.6)

func _draw_map_card() -> void:
	if not bool(main.get("map_open")):
		return
	_dim(0.72)
	_frame(map_card_rect, Defs.COL_CORE)
	_text_in(Rect2(map_card_rect.position + Vector2(0.0, 24.0),
		Vector2(map_card_rect.size.x, 22.0)), "지도", 18, Defs.COL_TEXT)

	var view: Rect2 = map_view_rect()
	# Everything not walked is void, so the card is painted black first and the
	# known world drawn into it. Drawing fog over the world instead would mean
	# knowing where the fog is, and the whole point is that most of it is fog.
	draw_rect(view, Color(0.04, 0.05, 0.08, 1.0))
	main.call("draw_map", self, view)
	draw_rect(view, Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g,
		Defs.COL_PANEL_EDGE.b, 0.7), false, 1.0)

	# The zoom slider. Same shape as the ones in settings, because it is the same
	# gesture and a second style of slider would be a second thing to learn.
	var track: Rect2 = map_slider_rect
	draw_rect(track, Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g,
		Defs.COL_PANEL_EDGE.b, 0.6))
	var span: float = maxf(Defs.MAP_ZOOM_MAX - Defs.MAP_ZOOM_MIN, 0.001)
	var fraction: float = clampf((float(main.get("map_zoom")) - Defs.MAP_ZOOM_MIN) / span,
		0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(track.size.x * fraction, track.size.y)),
		Defs.COL_CORE)
	draw_circle(Vector2(track.position.x + track.size.x * fraction,
		track.position.y + track.size.y * 0.5), 8.0, Defs.COL_CORE)
	_text_in(Rect2(track.position + Vector2(0.0, 22.0), Vector2(track.size.x, 16.0)),
		"확대 %d%%   ←/→   X 닫기" % int(round(float(main.get("map_zoom")) * 100.0)),
		12, Defs.COL_TEXT_DIM)

## Is this point on the zoom track? Generous vertically, because the track is
## eight pixels tall and a thumb is not.
func map_slider_at(point: Vector2) -> bool:
	if map_slider_rect.size.x <= 0.0:
		return false
	return Rect2(map_slider_rect.position - Vector2(10.0, 16.0),
		map_slider_rect.size + Vector2(20.0, 32.0)).has_point(point)

func begin_map_drag() -> void:
	dragging_map_zoom = true

func end_map_drag() -> void:
	dragging_map_zoom = false
