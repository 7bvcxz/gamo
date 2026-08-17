extends Control

## All screen-space UI. Immediate-mode drawing keeps the whole layout readable
## in one file; every position below is expressed against a screen edge so the
## HUD never depends on a fixed window size.

const MARGIN := 20.0
const PANEL_W := 232.0
const SETTINGS_BUTTON := 34.0
## Smallest logical canvas the layout is designed to hold. The height is not a
## round number: it is the status panel (190) plus the hotbar and its chip (154)
## plus the space the touch pad claims along the bottom (~180), which is the
## stack that has to coexist before anything is allowed to scale further.
const MIN_LOGICAL := Vector2(340.0, 520.0)
const SLOT_GAP := 10.0
const SLOT_MAX_W := 118.0
const SLOT_MIN_W := 54.0
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
var settings_restart_rect := Rect2()
var settings_save_rect := Rect2()
var settings_load_rect := Rect2()
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
	var base: float = Defs.UI_SCALE_TOUCH_BASE if touch_pad else Defs.UI_SCALE_DESKTOP_BASE
	var want: float = base * float(main.ui_scale)
	# A scale the screen cannot hold is worse than a small one: the status panel
	# and the hotbar start overlapping and the player loses the cards entirely.
	# Cap it at the largest value that still leaves a workable canvas.
	var view: Vector2 = get_viewport_rect().size
	want = minf(want, minf(view.x / MIN_LOGICAL.x, view.y / MIN_LOGICAL.y))
	want = maxf(want, 0.1)
	var wanted_size: Vector2 = view / want
	# Compare the size too, so a rotation or resize is picked up even when the
	# scale itself has not moved.
	if is_equal_approx(scale.x, want) and size.is_equal_approx(wanted_size):
		return
	scale = Vector2(want, want)
	size = wanted_size

## The row shrinks rather than running off the screen once the player scales the
## UI up, which is the whole point of letting them scale it up.
func hotbar_slot() -> Vector2:
	var count: float = float(main.TOOLS.size()) if main != null else 1.0
	var available: float = size.x - MARGIN * 2.0 - (count - 1.0) * SLOT_GAP
	return Vector2(clampf(available / count, SLOT_MIN_W, SLOT_MAX_W), SLOT_H)

func hotbar_origin() -> Vector2:
	var slot: Vector2 = hotbar_slot()
	var total: float = float(maxi(1, main.unlocked_tools().size())) * (slot.x + SLOT_GAP) - SLOT_GAP
	# Lifted clear of the thumb controls rather than sharing the bottom strip
	# with them, which at large UI scales buried a card under the X button.
	var bottom: float = size.y - slot.y - MARGIN - bottom_reserved()
	# And never over the gacha button, which owns the bottom-left corner. On any
	# real screen the centred row is nowhere near it; on the narrowest canvas the
	# layout supports, centring puts the first card straight on top of it, and a
	# button that cannot be pressed is worse than a row that is slightly off
	# centre.
	var left_limit: float = MARGIN + GACHA_BUTTON.x + SLOT_GAP
	return Vector2(maxf(size.x * 0.5 - total * 0.5, left_limit), bottom)

## Everything above the status panel, so the gear owns the very top-left corner.
func status_top() -> float:
	return MARGIN + SETTINGS_BUTTON + 8.0

## Below the gear, and never wider than the screen it is drawn on.
func status_rect() -> Rect2:
	return Rect2(MARGIN, status_top(), minf(PANEL_W, size.x - MARGIN * 2.0), 108)

## Screen space the touch pad occupies along the bottom, in HUD-local units. The
## pad is laid out in viewport pixels and the HUD in scaled ones, so the two only
## agree once this crosses the scale -- and if they disagree the hotbar ends up
## drawn underneath the thumb buttons.
func bottom_reserved() -> float:
	if main.touch == null or not main.touch.visible:
		return 0.0
	return float(main.touch.reserved_height()) / maxf(scale.x, 0.01) + 10.0

func _layout() -> void:
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
	var label: String = "R 출력 방향  오른쪽"
	var width: float = _text_width(label, 12) + 44.0
	direction_rect = Rect2(size.x * 0.5 - width * 0.5, origin.y - 58.0, width, 24.0)
	settings_button_rect = Rect2(MARGIN, MARGIN, SETTINGS_BUTTON, SETTINGS_BUTTON)
	# Beside the gear, sharing its top row. Two square buttons in the corner read
	# as one strip of controls; putting the map anywhere else would make it a
	# thing to hunt for.
	map_button_rect = Rect2(MARGIN + SETTINGS_BUTTON + 6.0, MARGIN,
		SETTINGS_BUTTON, SETTINGS_BUTTON)
	# And the record, third in the same strip.
	log_button_rect = Rect2(MARGIN + (SETTINGS_BUTTON + 6.0) * 2.0, MARGIN,
		SETTINGS_BUTTON, SETTINGS_BUTTON)
	var log_w: float = minf(520.0, size.x - MARGIN * 2.0)
	var log_h: float = minf(420.0, size.y - MARGIN * 2.0)
	log_card_rect = Rect2(size.x * 0.5 - log_w * 0.5, size.y * 0.5 - log_h * 0.5,
		log_w, log_h)
	_layout_map()
	# Bottom-left, bottom-aligned with the hotbar row so the two read as one
	# strip, and above whatever the touch pad claims -- on a phone that corner is
	# four thumb buttons and a button drawn under them can never be pressed.
	var floor_y: float = size.y - MARGIN - bottom_reserved()
	gacha_button_rect = Rect2(MARGIN, floor_y - GACHA_BUTTON.y, GACHA_BUTTON.x, GACHA_BUTTON.y)
	_layout_gacha()
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
const SETTINGS_CARD_H := 476.0
const SLOT_CARD_H := 372.0
const SETTINGS_ROW_H := 92.0
const SETTINGS_ROW_TOP := 96.0
const SLIDER_LABELS := ["화면 UI 크기", "게임 화면 크기"]

func _layout_settings() -> void:
	var card: Rect2 = _card_rect(SETTINGS_CARD_H)
	for index in SLIDER_LABELS.size():
		var top: float = SETTINGS_ROW_TOP + float(index) * SETTINGS_ROW_H
		var track := Rect2(card.position + Vector2(34.0, top + 46.0), Vector2(card.size.x - 68.0, 8.0))
		slider_track_rects[index] = track
		# Half a row of slop above and below, so the two rows tile the card
		# without overlapping and every pixel between them belongs to someone.
		slider_hit_rects[index] = Rect2(track.position - Vector2(26.0, 34.0),
			track.size + Vector2(52.0, 68.0))
	var gap := 12.0
	var action_w: float = (card.size.x - 68.0 - gap) * 0.5
	var action_y: float = card.size.y - 186.0
	settings_save_rect = Rect2(card.position + Vector2(34.0, action_y), Vector2(action_w, 44.0))
	settings_load_rect = Rect2(card.position + Vector2(34.0 + action_w + gap, action_y),
		Vector2(action_w, 44.0))
	settings_restart_rect = Rect2(card.position + Vector2(34.0, action_y + 56.0),
		Vector2(card.size.x - 68.0, 44.0))
	settings_close_rect = Rect2(card.position + Vector2(card.size.x * 0.5 - 72.0, card.size.y - 62.0),
		Vector2(144.0, 42.0))
	_layout_slots()

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
	settings_row = index

func end_slider_drag() -> void:
	dragging_slider = -1

func _panel(rect: Rect2, fill: Color, edge: Color, width: float = 1.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, width)

# --- Panel language -----------------------------------------------------------
## One frame for every panel in the game.
##
## The HUD had grown a different box for every purpose: some outlined, some not,
## edges in four colours, no shared spacing, nothing to tell the eye that two
## panels belonged to the same interface. The genre this game is aiming at --
## Factorio, Satisfactory, Planet Crafter -- gets a lot of its readability from
## the opposite: every window is obviously the same window, and the only thing
## that changes is the accent colour saying what kind of thing you are looking
## at. So there is one function, and everything goes through it.
##
## Four parts: a drop shadow so the panel sits above the world rather than being
## painted on it, a near-opaque body because ore silhouettes crawling behind text
## is what made the old status panel unreadable, a bright accent rule along the
## top edge, and corner ticks. The ticks are the cheapest way to make a plain
## rectangle read as a machined object instead of a div.
const FRAME_PAD := 10.0
const FRAME_HEADER := 22.0

func _frame(rect: Rect2, accent: Color, title: String = "") -> void:
	draw_rect(Rect2(rect.position + Vector2(2.0, 3.0), rect.size), Color(0.02, 0.03, 0.06, 0.35))
	draw_rect(rect, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.97))
	# A hairline inside the border catches the light and gives the edge depth
	# without a second colour.
	draw_rect(rect.grow(-1.0), Color(1, 1, 1, 0.045), false, 1.0)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.55), false, 1.0)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), accent)
	var tick: float = minf(9.0, rect.size.x * 0.16)
	for corner: Array in [[rect.position + Vector2(0.0, rect.size.y), Vector2(1.0, -1.0)],
			[rect.end, Vector2(-1.0, -1.0)]]:
		var at: Vector2 = corner[0]
		var step: Vector2 = corner[1]
		draw_line(at, at + Vector2(tick * step.x, 0.0), Color(accent.r, accent.g, accent.b, 0.8), 2.0)
		draw_line(at, at + Vector2(0.0, tick * step.y), Color(accent.r, accent.g, accent.b, 0.8), 2.0)
	if title != "":
		_text(rect.position + Vector2(FRAME_PAD, 16.0), title, 11, Color(accent.r, accent.g, accent.b, 0.95))
		draw_line(rect.position + Vector2(FRAME_PAD, FRAME_HEADER),
			rect.position + Vector2(rect.size.x - FRAME_PAD, FRAME_HEADER),
			Color(accent.r, accent.g, accent.b, 0.22), 1.0)

## Godot ignores horizontal alignment unless a width is supplied, so every
## centred string here spans an explicit box rather than a bare position.
func _text(at: Vector2, body: String, size: int, color: Color) -> void:
	draw_string(UIFont.FONT, at + Vector2(1, 1), body, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.02, 0.03, 0.06, 0.75))
	draw_string(UIFont.FONT, at, body, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _text_in(box: Rect2, body: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(UIFont.FONT, box.position + Vector2(1, 1), body, align, box.size.x, size, Color(0.02, 0.03, 0.06, 0.75))
	draw_string(UIFont.FONT, box.position, body, align, box.size.x, size, color)

func _text_width(body: String, size: int) -> float:
	return UIFont.FONT.get_string_size(body, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _draw() -> void:
	if main == null:
		return
	match main.state:
		main.State.TITLE: _draw_title()
		main.State.OPENING: _draw_cutscene()
		main.State.RESULT: _draw_result()
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
				_draw_resources()
				_draw_palette()
			if slot_picker > 0:
				_draw_slot_picker()
			else:
				_draw_settings_card()
		_:
			_draw_cold_vignette()
			_draw_blackout()
			_draw_status()
			_draw_resources()
			_draw_palette()
			_draw_meter_card()
			_draw_gacha_button()
			_draw_build_menu()
			_draw_base_menu()
			_draw_gacha_card()
			_draw_message()
	# Below the match, so they are on every screen -- except the opening. The
	# scene is the one moment the game is not offering the player a control, and
	# two little chrome squares in the corner of a painting say otherwise.
	if main.state == main.State.OPENING:
		return
	_draw_map_card()
	_draw_log_card()
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
func _draw_dusk_wash() -> void:
	var dusk: float = clampf((main.night_level() - 0.55) / 0.45, 0.0, 1.0)
	if dusk > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.16, dusk * 0.38))

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

func _draw_status() -> void:
	var panel: Rect2 = status_rect()
	_frame(panel, Defs.COL_CLOCK_FILL)

	# Time, daylight, warmth, body heat. Everything in this box is about the
	# player's own situation; what they own moved to the ledger below it, because
	# a box that grew a row per resource was slowly burying the clock.
	var seconds: int = int(ceil(main.time_left))
	var urgent: bool = seconds <= 45
	var clock: Color = Defs.COL_DANGER if urgent else Color8(226, 236, 248)
	_text(panel.position + Vector2(14, 40), "%02d:%02d" % [seconds / 60, seconds % 60], 26, clock)
	# The phase rides on the day line rather than under the arc: a caption there
	# lands exactly on the body-temperature readout at the panel's right edge.
	var phase: String = "밤" if main.is_night() else ("해질녘" if main.is_dusk() else "낮")
	_text(panel.position + Vector2(14, 56), "%d일차 · %s" % [main.day_number, phase], 11,
		Defs.COL_DANGER if main.is_night() else Defs.COL_CLOCK)
	_draw_day_arc(panel)
	_text(panel.position + Vector2(14, 76), "온기 %.1f칸" % main.sim.warm_radius, 14,
		Defs.COL_MACHINE_EDGE)

	_draw_warmth_row(panel)
	_draw_info()
	_draw_objective()

## Daylight as a half circle the sun crosses, left to right. A bar told the
## player how much time was left as a number they had to convert; an arc tells
## them where in the day they are at a glance, which is the thing they actually
## act on. The stretch that is already dusk is marked, so "how long until I have
## to walk home" is read rather than calculated.
func _draw_day_arc(panel: Rect2) -> void:
	var centre: Vector2 = panel.position + Vector2(panel.size.x - 54.0, 68.0)
	var radius := 30.0
	draw_arc(centre, radius, PI, TAU, 32, Color8(28, 36, 54), 5.0, true)
	var dusk_at: float = 1.0 - Defs.DUSK_SECONDS / Defs.DAY_SECONDS
	draw_arc(centre, radius, PI + PI * dusk_at, TAU, 20,
		Color(Defs.COL_DANGER.r, Defs.COL_DANGER.g, Defs.COL_DANGER.b, 0.45), 5.0, true)

	var travelled: float = clampf(main.day_fraction(), 0.0, 1.0)
	var angle: float = PI + PI * travelled
	if travelled > 0.005:
		draw_arc(centre, radius, PI, angle, 28, Defs.COL_CLOCK_FILL, 5.0, true)
	var at: Vector2 = centre + Vector2.from_angle(angle) * radius
	var night: bool = main.is_night()
	var marker: Color = Color8(196, 212, 240) if night else Defs.COL_CORE
	draw_circle(at, 9.0, Color(marker.r, marker.g, marker.b, 0.22))
	draw_circle(at, 5.0, marker)
	if night:
		# Bitten with the panel colour rather than drawn as an arc: a crescent is
		# what tells the player at a glance that the sun is no longer up.
		draw_circle(at + Vector2(2.6, -1.8), 3.8, Defs.COL_PANEL)

# --- Resource ledger ----------------------------------------------------------
const RESOURCE_ROW := 17.0

## What the player owns and how fast it is arriving, one row each. Separate from
## the status panel: they answer different questions, and every resource added to
## the game used to make the clock above it harder to read.
func resource_rect() -> Rect2:
	var panel: Rect2 = status_rect()
	return Rect2(panel.position + Vector2(0.0, panel.size.y + 8.0),
		Vector2(panel.size.x, FRAME_HEADER + 14.0 + float(resource_rows().size()) * RESOURCE_ROW))

## [name, amount, rate text, colour]. Heat first because it is the score; power
## last and only once something generates it, since a row reading zero of zero
## teaches nothing.
func resource_rows() -> Array[Array]:
	var sim = main.sim
	var rows: Array[Array] = []
	rows.append(["열", "%d" % sim.heat, _rate_text(sim.heat_rate), Defs.COL_CORE, -1])
	for item_type: int in Defs.COUNTED_ITEMS:
		var held: int = int(sim.stock.get(item_type, 0))
		var seen: bool = held > 0 or int(sim.delivered.get(item_type, 0)) > 0
		if not seen:
			continue
		rows.append([Defs.ITEM_SHORT[item_type], "%d" % held,
			_rate_text(float(sim.gain_rate.get(item_type, 0.0))), Defs.ITEM_COLORS[item_type],
			item_type])
	if sim.power_capacity > 0.0 or sim.machine_count(Defs.M_GENERATOR) > 0:
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
	_frame(box, Defs.COL_CORE, "자원")
	var y: float = FRAME_HEADER + 2.0
	for row: Array in rows:
		var tint: Color = row[3]
		if int(row[4]) >= 0:
			Icons.draw_item(self, Rect2(box.position + Vector2(FRAME_PAD, y - 2.0),
				Vector2(15.0, 15.0)), int(row[4]))
		else:
			draw_circle(box.position + Vector2(FRAME_PAD + 7.0, y + 5.0), 3.6, tint)
		_text(box.position + Vector2(FRAME_PAD + 20.0, y + 9.0), String(row[0]), 12, Defs.COL_TEXT)
		# Amount and rate are right-aligned in their own columns, so the eye can
		# run down either one without reading the other.
		_text_in(Rect2(box.position + Vector2(box.size.x - 146.0, y + 9.0), Vector2(70.0, 14)),
			String(row[1]), 13, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		# Wider than it was: "+12.3/분" needs more room than the per-second form
		# it replaced, and a clipped rate is worse than no rate.
		_text_in(Rect2(box.position + Vector2(box.size.x - 70.0, y + 9.0), Vector2(58.0, 14)),
			String(row[2]), 11, tint, HORIZONTAL_ALIGNMENT_RIGHT)
		y += RESOURCE_ROW

## The next useful action, always on screen. This is the whole onboarding: no
## modal tutorial, no text wall, just one line that keeps up with the player.
## Split out from the drawing so the placement can be asserted directly; the
## overlap this avoids only appears at scales a test has to drive deliberately.
## The mission card: a header, a picture of the thing being asked for, and the
## line. The picture is the point -- "고양이 상자 3개를 모으세요" means nothing until
## you know what a cat crate looks like, and the genre's answer to that has always
## been to put the item next to the sentence rather than to describe it.
const OBJECTIVE_ICON := 44.0
const OBJECTIVE_H := 68.0

## The state card. Shorter than the goal card -- it has no icon well and one line
## -- and it takes the top-right corner, with the goal card sliding under it.
const INFO_H := 40.0
const INFO_GAP := 6.0

func info_rect(text: String) -> Rect2:
	var width: float = minf(_text_width(text, 12) + INFO_H + 34.0, size.x - MARGIN * 2.0)
	var box := Rect2(size.x - width - MARGIN, MARGIN, width, INFO_H)
	var panel: Rect2 = status_rect()
	if box.position.x < panel.position.x + panel.size.x + 8.0:
		box.position.y = panel.position.y + panel.size.y + 8.0
	return box

func objective_rect(text: String) -> Rect2:
	# The trailing pad has to clear the last glyph's advance, not just sit flush
	# against it, or the closing bracket lands on the plate border.
	var width: float = minf(_text_width(text, 12) + OBJECTIVE_ICON + 50.0, size.x - MARGIN * 2.0)
	var box := Rect2(size.x - width - MARGIN, MARGIN, width, OBJECTIVE_H)
	# Once the UI is scaled up there is no longer room for both across the top,
	# so the objective drops underneath the panel instead of across it.
	var panel: Rect2 = status_rect()
	if box.position.x < panel.position.x + panel.size.x + 8.0:
		box.position.y = panel.position.y + panel.size.y + 8.0
	# And under the state card whenever the world has something to say, which is
	# what "above the goal" means: the thing that is true right now sits over the
	# thing being worked towards, and neither evicts the other.
	var state: String = main.info()
	if state != "":
		var above: Rect2 = info_rect(state)
		box.position.y = maxf(box.position.y, above.position.y + above.size.y + INFO_GAP)
	return box

## Drawn before the goal card, because the goal card's own rectangle is measured
## from this one and a reader following the paint order should meet them in that
## order too.
func _draw_info() -> void:
	var row: Dictionary = main.info_data()
	if not row.has("text"):
		return
	var text: String = String(row["text"])
	var box: Rect2 = info_rect(text)
	# Its own colour, not the goal's. The two cards are stacked and the same
	# amber twice reads as one panel that grew a line.
	_panel(box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.90),
		Color(Defs.COL_BELT_RIM.r, Defs.COL_BELT_RIM.g, Defs.COL_BELT_RIM.b, 0.75), 1.0)
	var slot := Rect2(box.position + Vector2(9.0, 9.0), Vector2.ONE * (INFO_H - 18.0))
	_draw_goal_icon(slot, row)
	_text(box.position + Vector2(INFO_H + 4.0, INFO_H * 0.5 + 4.0), text, 12, Defs.COL_TEXT)

## The mission card: the open rungs of all three tracks.
##
## One line was wrong for this game. The fire's next step, the animal in the ice
## and the first belt are three things the player is working towards at once, and
## a single card meant whichever one happened to be showing was the only one that
## existed. Grouped by track, because "기지" and "고양이" are different kinds of
## wanting and reading them as one list makes them look like a queue.
const MISSION_ROW_H := 17.0
const MISSION_HEAD_H := 15.0

func mission_card_rect() -> Rect2:
	var rows: Array[Dictionary] = main.open_missions()
	var tracks := {}
	for row: Dictionary in rows:
		tracks[int(row["track"])] = true
	var height: float = FRAME_HEADER + 10.0 + float(rows.size()) * MISSION_ROW_H \
		+ float(tracks.size()) * MISSION_HEAD_H
	var width: float = 0.0
	for row: Dictionary in rows:
		width = maxf(width, _text_width(String(row["line"]), 12) + 46.0)
	width = clampf(width, 150.0, size.x - MARGIN * 2.0)
	var box := Rect2(size.x - width - MARGIN, MARGIN, width, maxf(height, 44.0))
	var panel: Rect2 = status_rect()
	if box.position.x < panel.position.x + panel.size.x + 8.0:
		box.position.y = panel.position.y + panel.size.y + 8.0
	var state: String = main.info()
	if state != "":
		var above: Rect2 = info_rect(state)
		box.position.y = maxf(box.position.y, above.position.y + above.size.y + INFO_GAP)
	return box

## Whichever card is in the top-right corner right now: the opening speaks in one
## line and everything after it is the three tracks. Anything that has to sit
## below "the goal" asks this rather than picking one of the two.
func goal_area() -> Rect2:
	var text: String = main.objective()
	if text != "":
		return objective_rect(text)
	if main.open_missions().is_empty():
		var state: String = main.info()
		return info_rect(state) if state != "" else Rect2(size.x - MARGIN, MARGIN, 0.0, 0.0)
	return mission_card_rect()

func _draw_missions() -> void:
	var rows: Array[Dictionary] = main.open_missions()
	# Nothing open is a real state -- the opening, and the gaps between rungs --
	# and an empty framed card in the corner is worse than no card.
	if rows.is_empty():
		return
	var box: Rect2 = mission_card_rect()
	_frame(box, Defs.COL_CORE, "임무")
	var y: float = box.position.y + FRAME_HEADER + 4.0
	var track := -1
	for row: Dictionary in rows:
		if int(row["track"]) != track:
			track = int(row["track"])
			y += MISSION_HEAD_H
			_text(Vector2(box.position.x + 12.0, y - 3.0), Defs.TRACK_NAMES[track], 11,
				Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.85))
		y += MISSION_ROW_H
		# A dot rather than a bullet character: the font is subset from the source
		# and a glyph nobody wrote into a string is a glyph that is not in it.
		draw_circle(Vector2(box.position.x + 18.0, y - 8.0), 2.0, Defs.COL_TEXT_DIM)
		_text(Vector2(box.position.x + 26.0, y - 4.0), String(row["line"]), 12,
			Defs.COL_TEXT)

func _draw_objective() -> void:
	var goal: Dictionary = main.objective_data()
	var text: String = String(goal["text"])
	# The opening still speaks in one line, and once it is over the card becomes
	# the three tracks.
	if text == "":
		_draw_missions()
		return
	var box: Rect2 = objective_rect(text)
	_frame(box, Defs.COL_CORE, "목표")
	var slot := Rect2(box.position + Vector2(FRAME_PAD, FRAME_HEADER + 7.0),
		Vector2(OBJECTIVE_ICON, OBJECTIVE_ICON) * 0.76)
	# The icon sits in its own recessed well, which is what stops a drawn object
	# from reading as debris that happened to land on the panel.
	draw_rect(slot.grow(3.0), Color(0, 0, 0, 0.28))
	draw_rect(slot.grow(3.0), Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.30), false, 1.0)
	_draw_goal_icon(slot, goal)
	_text(box.position + Vector2(FRAME_PAD + OBJECTIVE_ICON * 0.76 + 16.0, FRAME_HEADER + 27.0),
		text, 12, Defs.COL_TEXT)

func _draw_goal_icon(rect: Rect2, goal: Dictionary) -> void:
	match String(goal["kind"]):
		"machine": Icons.draw_machine(self, rect, int(goal["id"]))
		"item": Icons.draw_item(self, rect, int(goal["id"]))
		_: Icons.draw_thing(self, rect, String(goal["id"]))

## Docked into the status panel and always present, so it can never pop in and
## shift the layout at the exact moment the player is in danger.
func _draw_warmth_row(panel: Rect2) -> void:
	var warmth: float = main.player.warmth
	var k: float = clampf(warmth / 100.0, 0.0, 1.0)
	var origin: Vector2 = panel.position + Vector2(14, 88)
	_text(origin + Vector2(0, 10), "체온", 11, Defs.COL_TEXT_DIM)
	_text_in(Rect2(origin + Vector2(166, -2), Vector2(36, 16)), "%d%%" % int(round(warmth)), 11,
		Defs.COL_TEXT if k > 0.25 else Defs.COL_DANGER, HORIZONTAL_ALIGNMENT_RIGHT)
	var track := Rect2(origin + Vector2(40, 2), Vector2(122, 9))
	draw_rect(track, Color8(28, 36, 54))
	var col: Color = Defs.COL_CORE.lerp(Defs.COL_DANGER, 1.0 - k)
	if k < 0.25:
		var pulse: float = 0.6 + sin(float(Time.get_ticks_msec()) / 90.0) * 0.4
		col = Defs.COL_DANGER.lerp(Color.WHITE, pulse * 0.35)
	draw_rect(Rect2(track.position, Vector2(track.size.x * k, track.size.y)), col)
	draw_rect(track, Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.6), false, 1.0)
	if main.collapse_timer >= 0.0:
		# Below the character, never across her.
		var label: String = "쓰러지는 중…" if main.player.collapse > 0.0 \
			else "의식이 흐려집니다  %.1f초" % maxf(0.0, main.collapse_timer)
		_text_in(Rect2(0, size.y * 0.64, size.x, 20), label, 19, Defs.COL_DANGER)

## The toolbar. One card, holding the build gun, showing what it is loaded with.
##
## It used to be five machine slots picked with the number keys. That put the
## whole buildable list permanently across the bottom of the screen and left no
## room to ever say what any of them did -- the cards were down to a name, a cost
## and a nine-pixel rate line. The gun moves the choice into a menu that has room
## to explain itself, and the bar goes back to being about what is in your hands.
func _draw_palette() -> void:
	# Nothing in the row is reachable before the fire is lit: there is no base to
	# build from, the pickaxe is still in the case, and every machine in it costs
	# a resource she has not seen. A row of things she cannot have is the game
	# talking about the second act during the first.
	if not main.sim.base_placed:
		return
	var slot: Vector2 = hotbar_slot()
	var origin: Vector2 = hotbar_origin()
	_draw_direction_chip(origin.y)

	var loaded: int = main.selected_type()
	if main.unlocked_tools().is_empty():
		return
	# The hint line belongs to whatever is in her hands. With the pickaxe out the
	# machine the gun happens to be loaded with is not what Z will do, and saying
	# so anyway is how a player learns the wrong thing about their own keys.
	var hint: String = Defs.MACHINE_HINTS[loaded]
	if main.holding_pickaxe():
		hint = "광맥을 바라보고 Z를 누르고 있으면 직접 캡니다"
	elif loaded == Defs.M_EXCHANGER or loaded == Defs.M_MINER:
		hint += "   ·   " + Defs.ratio_hint()
	var hint_w: float = _text_width(hint, 12) + 24.0
	var hint_box := Rect2(size.x * 0.5 - hint_w * 0.5, origin.y - 30.0, hint_w, 24.0)
	_frame(hint_box, Defs.COL_PANEL_EDGE)
	_text_in(Rect2(hint_box.position + Vector2(0, 16), Vector2(hint_box.size.x, 16)), hint, 12,
		Defs.COL_TEXT_DIM)

	for index in main.TOOLS.size():
		if not main.tool_unlocked(main.TOOLS[index]):
			continue
		var rect: Rect2 = hotbar_rects[index] if index < hotbar_rects.size() \
			else Rect2(origin + Vector2(float(index) * (slot.x + SLOT_GAP), 0), slot)
		var chosen: bool = index == main.tool_index
		_frame(rect, Defs.COL_CORE if chosen else Defs.COL_PANEL_EDGE)
		_text(rect.position + Vector2(FRAME_PAD, 16.0), "%d  %s" % [index + 1, main.TOOL_NAMES[index]],
			11, Defs.COL_CORE if chosen else Defs.COL_TEXT_DIM)
		# The pickaxe holds nothing, so its slot says what it is for instead of
		# borrowing the gun's magazine.
		if main.TOOLS[index] == main.TOOL_PICKAXE:
			Icons.draw_pickaxe(self, Rect2(rect.position + Vector2(FRAME_PAD, FRAME_HEADER + 4.0),
				Vector2(24.0, 24.0)))
			_text(rect.position + Vector2(FRAME_PAD + 30.0, FRAME_HEADER + 14.0),
				"직접 채굴", 13, Defs.COL_TEXT)
			_text(rect.position + Vector2(FRAME_PAD + 30.0, FRAME_HEADER + 27.0),
				"%.0f초/개" % Defs.HAND_MINE_PERIOD, 10, Defs.COL_TEXT_DIM)
			continue
		# The torch holds nothing either. Its slot is the two numbers that decide
		# whether taking it out is worth it: how many are left, and how long the
		# one in her hand has.
		if main.TOOLS[index] == main.TOOL_TORCH:
			Icons.draw_thing(self, Rect2(rect.position + Vector2(FRAME_PAD, FRAME_HEADER + 4.0),
				Vector2(24.0, 24.0)), Icons.THING_TORCH)
			var lit: bool = main.holding_torch()
			_text(rect.position + Vector2(FRAME_PAD + 30.0, FRAME_HEADER + 14.0),
				"%d개" % main.sim.torches, 13,
				Defs.COL_TEXT if main.sim.torches > 0 or lit else Defs.COL_DANGER)
			_text(rect.position + Vector2(FRAME_PAD + 30.0, FRAME_HEADER + 27.0),
				"%.0f초 남음" % main.sim.torch_left if main.sim.torch_left > 0.0 else "꺼짐",
				10, Defs.COL_CORE if lit else Defs.COL_TEXT_DIM)
			# The burn, as a bar under the slot, because a number counting down is
			# something you read and a bar draining is something you notice.
			if main.sim.torch_left > 0.0:
				var track := Rect2(rect.position.x + FRAME_PAD,
					rect.position.y + rect.size.y - 9.0,
					rect.size.x - FRAME_PAD * 2.0, 3.0)
				draw_rect(track, Color(0.10, 0.13, 0.20, 0.85))
				draw_rect(Rect2(track.position,
					Vector2(track.size.x * clampf(main.sim.torch_left / Defs.TORCH_SECONDS, 0.0, 1.0),
						track.size.y)), Defs.COL_CORE if lit else Defs.COL_TEXT_DIM)
			continue
		# What the gun is loaded with, as the thing itself rather than its name.
		var chip := Rect2(rect.position + Vector2(FRAME_PAD, FRAME_HEADER + 4.0),
			Vector2(24.0, 24.0))
		Icons.draw_machine(self, chip, loaded)
		var afford: bool = main.sim.can_afford(loaded)
		_text(rect.position + Vector2(FRAME_PAD + 30.0, FRAME_HEADER + 14.0),
			Defs.MACHINE_SHORT[loaded], 13, Defs.COL_TEXT if afford else Defs.COL_DANGER)
		var cost_text := ""
		for item_type: int in Defs.MACHINE_COSTS[loaded]:
			cost_text += "%s %d " % [Defs.ITEM_SHORT[item_type], int(Defs.MACHINE_COSTS[loaded][item_type])]
		_text(rect.position + Vector2(FRAME_PAD + 30.0, FRAME_HEADER + 27.0), cost_text.strip_edges(),
			10, Defs.COL_CORE if afford else Defs.COL_DANGER)
		_text_in(Rect2(rect.position + Vector2(0.0, rect.size.y - 6.0), Vector2(rect.size.x - FRAME_PAD, 12)),
			"B 목록", 10, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

	if main.touch == null or not main.touch.visible:
		_draw_key_legend()

## The key legend, under the hotbar rather than across the top: the top right
## belongs to the mission card, and a legend printed over it read as one long
## unparseable line.
##
## On a panel, and that is not decoration. It used to be dim grey text laid
## straight onto the world, which over snow is grey on grey -- a playtest
## screenshot of it is barely legible, and the ground it sits on changes colour
## all day. The panel is sized to the text because a panel has to hug what it is
## backing: the line measures 321 units against the 480 the old box reserved, and
## a plate with 159 units of empty tail reads as a misplaced rectangle.
##
## Two keys were missing from it: G, which opens the gacha, and the zoom pair,
## both added recently. A legend is a list that goes stale the moment someone
## adds a key and forgets it, so the game's own hint hangs off the same place the
## keys do -- there is a test that reads this string.
## What the game answers to, composed rather than written out, so a key that is
## switched off cannot go on being advertised. A legend that names a dead key is
## the exact fault test_hints exists to catch -- the objective card told players
## to press C for eight versions after C stopped mining.
static func key_legend() -> String:
	var keys: Array[String] = ["Z 사용", "X 회수", "R 회전", "C 계기", "B 목록"]
	if Defs.GACHA_ENABLED:
		keys.append("G 가챠")
	keys.append_array(["M 지도", "L 기록", "-/= 크기", "Esc 설정"])
	return "   ".join(keys)

## Anchored to the bottom of the screen rather than measured down from the
## hotbar. The first version took the hotbar's baseline and used it as the top of
## the plate -- but `_text_in` treats its y as a baseline and `draw_rect` treats
## its y as a top edge, so the plate hung fourteen pixels off the bottom of the
## window and took its own text with it. The legend had been readable before I
## put it on a plate.
func _draw_key_legend() -> void:
	var width: float = minf(_text_width(key_legend(), 11) + 20.0, size.x - MARGIN * 2.0)
	var floor_y: float = size.y - 4.0 - bottom_reserved()
	var box := Rect2(size.x - width - MARGIN, floor_y - 18.0, width, 18.0)
	draw_rect(box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.55))
	_text_in(Rect2(box.position + Vector2(0.0, 13.0), Vector2(box.size.x, 14.0)),
		key_legend(), 11, Defs.COL_TEXT_DIM)

# --- Build menu ---------------------------------------------------------------
## What the gun can be loaded with, with room to say what each thing does.
##
## The old hotbar had a name, a cost and a nine-pixel throughput line per machine
## and no space for anything else, so a player met the splitter as the word
## "분배기" and had to build one to find out. Here every entry gets its picture,
## its cost, and three lines saying what goes in, what comes out and what is
## peculiar about it -- which is the information the genre runs on.
const MENU_ROW := 74.0
const MENU_W := 500.0

func build_menu_rect() -> Rect2:
	var rows: float = float(Defs.BUILDABLE.size())
	var height: float = FRAME_HEADER + 12.0 + rows * MENU_ROW + 30.0
	var width: float = minf(MENU_W, size.x - MARGIN * 2.0)
	height = minf(height, size.y - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

func build_menu_row_rect(index: int) -> Rect2:
	var card: Rect2 = build_menu_rect()
	return Rect2(card.position + Vector2(8.0, FRAME_HEADER + 8.0 + float(index) * MENU_ROW),
		Vector2(card.size.x - 16.0, MENU_ROW - 4.0))

## Which row a point falls in, or -1. Used by touch, which has no arrow keys.
func build_menu_row_at(point: Vector2) -> int:
	if not main.build_menu_open:
		return -1
	for index in Defs.BUILDABLE.size():
		if build_menu_row_rect(index).has_point(point):
			return index
	return -1

## The fire's window. What went in on the way here, and what can be made out of
## what is left.
##
## Deliberately small. The build list is a catalogue with a row per machine; this
## is one thing to make, and a card the size of the catalogue would be mostly
## empty space announcing how little there is.
func base_menu_rect() -> Rect2:
	var rows: float = float(maxi(1, main.base_rows().size()))
	var height: float = FRAME_HEADER + 60.0 + rows * MENU_ROW + 18.0
	var width: float = minf(MENU_W, size.x - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

func base_menu_row_rect(index: int) -> Rect2:
	var card: Rect2 = base_menu_rect()
	return Rect2(card.position + Vector2(8.0, FRAME_HEADER + 56.0 + float(index) * MENU_ROW),
		Vector2(card.size.x - 16.0, MENU_ROW - 4.0))

func _draw_base_menu() -> void:
	if not main.base_menu_open:
		return
	_dim(0.45)
	var card: Rect2 = base_menu_rect()
	_frame(card, Defs.COL_CORE, "기지   ↑↓ 선택 · Z 제작 · X 닫기")
	var sim = main.sim
	# The state of the fire, in one line: how far it reaches and what the next
	# step of that costs. It is the only number the player is working towards.
	var next_level: Dictionary = Defs.next_base_level(sim.total_heat)
	var line: String = "온기 %.0f칸  ·  누적 열 %d" % [sim.warm_radius, sim.total_heat]
	if not next_level.is_empty():
		line += "   →   %d 에서 %.0f칸" % [int(next_level["heat"]), float(next_level["radius"])]
	_text(card.position + Vector2(14.0, FRAME_HEADER + 22.0), line, 13, Defs.COL_TEXT_DIM)
	_text(card.position + Vector2(14.0, FRAME_HEADER + 42.0),
		"%s %d개  ·  남은 시간 %.0f초" % [Defs.TORCH_NAME, sim.torches, sim.torch_left],
		12, Defs.COL_BELT_RIM)
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
	var text_x: float = rect.position.x + 62.0
	_text(Vector2(text_x, rect.position.y + 22.0), "연료 투입", 14, Defs.COL_TEXT)
	var parts: Array[String] = []
	var gain: int = 0
	for item_type: int in Defs.COUNTED_ITEMS:
		var count: int = int(main.sim.stock.get(item_type, 0))
		if int(Defs.ITEM_VALUES[item_type]) <= 0 or count <= 0:
			continue
		parts.append("%s %d" % [Defs.ITEM_SHORT[item_type], count])
		gain += int(Defs.ITEM_VALUES[item_type]) * count
	# What it does under the title, what it costs on the right -- the same way
	# round as every other row in this window and in the build list. This one was
	# mirrored, so a reader who had learned where to look in the window had to
	# unlearn it for one line.
	var next_level: Dictionary = Defs.next_base_level(main.sim.total_heat)
	var effect: String = "+%d 열" % gain
	if not next_level.is_empty():
		var short: int = maxi(0, int(next_level["heat"]) - main.sim.total_heat - gain)
		effect += "   다음 단계까지 %d" % short if short > 0 else "   다음 단계에 닿습니다"
	_text(Vector2(text_x, rect.position.y + 42.0), effect, 11, Defs.COL_CORE)
	_text(Vector2(rect.position.x + rect.size.x - 96.0, rect.position.y + 32.0),
		" · ".join(parts), 13, Defs.COL_TEXT)

func _draw_build_menu() -> void:
	if not main.build_menu_open:
		return
	_dim(0.45)
	var card: Rect2 = build_menu_rect()
	_frame(card, Defs.COL_CORE, "건설 목록   ↑↓ 선택 · Z 장전 · B 닫기")
	for index in Defs.BUILDABLE.size():
		_draw_build_row(index)

func _draw_build_row(index: int) -> void:
	var type: int = Defs.BUILDABLE[index]
	var rect: Rect2 = build_menu_row_rect(index)
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

	var text_x: float = rect.position.x + 62.0
	# The three input/output lines stack down the right half rather than sitting
	# in three columns across the row. Laid out horizontally they were about 145
	# pixels of text in a 124 pixel column, so every one of them ran into the
	# next -- measured, not guessed, after the first version did exactly that.
	var io_x: float = rect.position.x + rect.size.x - 196.0
	_text(Vector2(text_x, rect.position.y + 20.0), Defs.MACHINE_NAMES[type], 14,
		Defs.COL_TEXT_DIM if locked else Defs.COL_TEXT)
	if loaded:
		_text(Vector2(text_x, rect.position.y + 58.0), "장전됨", 11, accent)

	if locked:
		# Locked entries stay visible and say what opens them. Seeing what is
		# coming is half of why a build list exists at all.
		var key_item: int = Defs.MACHINE_UNLOCK_ITEM[type]
		_text(Vector2(text_x, rect.position.y + 38.0),
			"%s%s 손에 넣으면 해금됩니다"
				% [Defs.ITEM_NAMES[key_item], Defs.object_of(Defs.ITEM_NAMES[key_item])],
				11, Defs.COL_TEXT_DIM)
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
func _draw_direction_chip(hotbar_y: float) -> void:
	var dir: Vector2i = main.build_dir
	var names := {
		Vector2i.UP: "위", Vector2i.DOWN: "아래",
		Vector2i.LEFT: "왼쪽", Vector2i.RIGHT: "오른쪽",
	}
	var label: String = "출력 방향  %s" % String(names.get(dir, "오른쪽"))
	var width: float = _text_width(label, 12) + 44.0
	var box: Rect2 = direction_rect if direction_rect.size.x > 0.0 \
		else Rect2(size.x * 0.5 - width * 0.5, hotbar_y - 58.0, width, 24.0)
	_panel(box, Defs.COL_PANEL, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.55))
	_text(box.position + Vector2(12, 16), label, 12, Defs.COL_TEXT)
	# The same arrow the world preview draws, so the two read as one statement.
	var at: Vector2 = box.position + Vector2(box.size.x - 20.0, 12.0)
	var d := Vector2(dir)
	var perp := Vector2(-d.y, d.x)
	var tip: Vector2 = at + d * 7.0
	draw_line(at - d * 6.0, tip - d * 3.0, Defs.COL_CORE, 2.5)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - d * 5.0 + perp * 3.6, tip - d * 5.0 - perp * 3.6]), Defs.COL_CORE)

## Every notification the game gives goes through here -- a machine unlocking, a
## warning that night is coming, a purchase it cannot afford.
##
## On a plate, because it was floating text and over snow it was very nearly
## invisible. A playtest screenshot of "아직 해금되지 않았습니다" is a grey smear on
## a pale floor; the text had a one-pixel shadow, which is enough against the
## night and nothing at all against the ground the game spends most of its time
## on. The plate fades with the message, so nothing lingers.
func _draw_message() -> void:
	if main.message_life <= 0.0:
		return
	var alpha: float = clampf(main.message_life, 0.0, 1.0)
	var width: float = minf(_text_width(main.message, 15) + 32.0, size.x - MARGIN * 2.0)
	var plate := Rect2(size.x * 0.5 - width * 0.5, 192.0, width, 26.0)
	draw_rect(plate, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.82 * alpha))
	draw_rect(plate, Color(message_color.r, message_color.g, message_color.b, 0.55 * alpha),
		false, 1.0)
	_text_in(Rect2(plate.position + Vector2(0.0, 18.0), Vector2(plate.size.x, 20.0)),
		main.message, 15, Color(message_color.r, message_color.g, message_color.b, alpha))

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

## The control line on the first screen, as a function so a test can read it.
##
## It said "WASD 이동" for as long as it existed and WASD has never been bound to
## anything -- `move_*` is the arrow keys only. It is the first sentence a new
## player reads, and it named keys that do nothing: the same fault as the
## objective that said C to mine for eight versions, in the one place nobody
## re-reads because it scrolls past before the game starts.
static func title_controls(touch_pad: bool) -> String:
	if touch_pad:
		return "휠 이동   Z 사용   X 회수   Run 달리기"
	return "←↑→↓ 이동   Z 사용   X 회수   R 회전   1·2·3 선택"

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
	var touch_pad: bool = main.touch != null and main.touch.visible
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
	_text_in(full.call(size.y * 0.52 + 24), "코어에 광석을 넣을수록 온기가 넓어지고 더 좋은 광맥에 닿습니다.",
		13, Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, 0.82))
	_draw_title_menu()
	# WASD was on this line for as long as the line existed and has never been
	# bound to anything: `move_*` is arrow keys only. It is the first screen of
	# the game, and it told every new player the wrong keys -- the same shape as
	# the objective that said C to mine for eight versions. `test_hints` now
	# checks the movement claim against the bindings like it does the letters.
	var controls: String = title_controls(touch_pad)
	_text_in(full.call(size.y * 0.84), controls, 12,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, 0.72))
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
	var width: float = minf(METER_W, size.x - MARGIN * 2.0)
	var box := Rect2(size.x - width - MARGIN, status_top(), width, height)
	# Under whichever card is up there: the opening's single line, or the three
	# tracks. Asked as one question so the meter cannot land on top of either.
	var above: Rect2 = goal_area()
	box.position.y = above.position.y + above.size.y + 8.0
	# The hotbar and the touch pad own the bottom of the screen. If the card no
	# longer fits between them, it rides up rather than being drawn underneath.
	var floor_y: float = hotbar_origin().y - 10.0
	if box.position.y + box.size.y > floor_y:
		box.position.y = maxf(status_top(), floor_y - box.size.y)
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
	_frame(card, accent, "가챠 슬롯머신   ← → 선택 · Z 돌리기 · G 닫기")
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
	_panel(rect, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.92),
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.55))
	var centre: Vector2 = rect.position + rect.size * 0.5
	var radius: float = rect.size.x * 0.24
	var tint: Color = Defs.COL_CORE if main.state == main.State.SETTINGS else Defs.COL_TEXT
	for tooth in 8:
		var dir := Vector2.from_angle(float(tooth) * TAU / 8.0)
		draw_line(centre + dir * radius, centre + dir * (radius + rect.size.x * 0.14), tint, 2.0)
	draw_arc(centre, radius, 0.0, TAU, 24, tint, 2.2)
	draw_circle(centre, radius * 0.38, tint)

func _draw_settings_card() -> void:
	_dim(0.72)
	var card: Rect2 = _card(SETTINGS_CARD_H)
	var w: float = card.size.x
	_text_in(Rect2(card.position + Vector2(0, 48), Vector2(w, 30)), "설정", 26, Defs.COL_TEXT)
	for index in SLIDER_LABELS.size():
		_draw_settings_row(card, index)

	_draw_settings_action(settings_save_rect,
		"저장했습니다" if saved_flash > 0.0 else "저장하기",
		Defs.COL_CORE if saved_flash > 0.0 else Defs.COL_TEXT_DIM)
	_draw_settings_action(settings_load_rect, "불러오기", Defs.COL_MACHINE_EDGE)
	_draw_settings_action(settings_restart_rect,
		"정말 처음부터?" if restart_armed > 0.0 else "처음부터",
		Defs.COL_DANGER if restart_armed > 0.0 else Defs.COL_TEXT_DIM)

	var touch_pad: bool = main.touch != null and main.touch.visible
	var hint: String = "한 번 더 누르면 지금까지의 공장이 사라집니다" if restart_armed > 0.0 \
		else ("슬라이더를 드래그하세요" if touch_pad else "↑ ↓ 로 선택, ← → 로 조절")
	# Above the buttons, not between them and 닫기: at the bottom it sat exactly on
	# the edge of 처음부터 and the two read as one smudged line.
	_text_in(Rect2(card.position + Vector2(0, SETTINGS_CARD_H - 200.0), Vector2(w, 18)), hint, 12,
		Defs.COL_DANGER if restart_armed > 0.0 else Defs.COL_TEXT_DIM)
	var close: Rect2 = settings_close_rect
	_panel(close, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.18), Defs.COL_CORE)
	_text_in(Rect2(close.position + Vector2(0, 28), Vector2(close.size.x, 22)), "닫기", 16, Defs.COL_TEXT)

## One of the two action buttons. Outlined rather than filled, so neither of them
## competes with the close button for being the obvious thing to press.
func _draw_settings_action(rect: Rect2, label: String, tint: Color) -> void:
	if rect.size.x <= 0.0:
		return
	_panel(rect, Color(tint.r, tint.g, tint.b, 0.12), Color(tint.r, tint.g, tint.b, 0.75))
	_text_in(Rect2(rect.position + Vector2(0, rect.size.y * 0.5 + 6.0), Vector2(rect.size.x, 20)),
		label, 15, Defs.COL_TEXT)

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
		"↑ ↓ 선택 · Z 확인 · Esc 취소     %d / %d" % [slot_index, main.SAVE_SLOTS - 1], 11,
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
			"%d일차 · 누적 열 %d" % [int(card["day"]), int(card["heat"])], 11, Defs.COL_TEXT_DIM)
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

func _draw_settings_row(card: Rect2, index: int) -> void:
	var w: float = card.size.x
	var top: float = SETTINGS_ROW_TOP + float(index) * SETTINGS_ROW_H
	var focused: bool = settings_row == index and (main.touch == null or not main.touch.visible)
	_text_in(Rect2(card.position + Vector2(0, top), Vector2(w, 22)),
		SLIDER_LABELS[index], 14, Defs.COL_TEXT if focused else Defs.COL_TEXT_DIM)
	_text_in(Rect2(card.position + Vector2(0, top + 30.0), Vector2(w, 26)),
		"%d%%" % int(round(slider_current(index) * 100.0)), 22, Defs.COL_CORE)

	var range: Vector2 = slider_range(index)
	var span: float = maxf(range.y - range.x, 0.001)
	var t: float = clampf((slider_current(index) - range.x) / span, 0.0, 1.0)
	var track: Rect2 = slider_track_rects[index]
	draw_rect(track, Color8(28, 36, 54))
	draw_rect(Rect2(track.position, Vector2(track.size.x * t, track.size.y)), Defs.COL_CORE)
	var knob := Vector2(track.position.x + track.size.x * t, track.position.y + track.size.y * 0.5)
	var held: bool = dragging_slider == index
	draw_circle(knob, 17.0 if held else 15.0, Defs.COL_CORE)
	draw_circle(knob, 17.0 if held else 15.0, Color(0.02, 0.03, 0.06, 0.45), false, 1.6)

func _draw_result() -> void:
	_dim(0.82)
	var sim = main.sim
	var card := _card(340.0)
	var w: float = card.size.x
	var headline: String = "%d일차 · 고양이들이 데려왔습니다" % main.day_number if main.rescued_tonight else "%d일차 · 숙소에서 잤습니다" % main.day_number
	_text_in(Rect2(card.position + Vector2(0, 44), Vector2(w, 30)), headline, 21,
		Defs.COL_DANGER if main.rescued_tonight else Defs.COL_TEXT)
	# A morning report, not a score.
	#
	# This used to lead with "+N 오늘 모은 열" at 52 point and close with a "최고
	# 하루" record, which is the shape of a run being graded. Motorio is a long
	# game -- settled on 2026-08-14 as long-form rather than score attack -- so
	# what a player needs at dawn is where the base has got to, not how well
	# yesterday scored.
	# The lead is the warm radius, because that is the thing that actually grows
	# and the thing the next day is spent extending.
	_text_in(Rect2(card.position + Vector2(0, 106), Vector2(w, 70)),
		"%.1f칸" % sim.warm_radius, 52, Defs.COL_MACHINE_EDGE)
	_text_in(Rect2(card.position + Vector2(0, 130), Vector2(w, 20)), "온기 반경", 13,
		Defs.COL_TEXT_DIM)

	var gained: int = main.day_heat()
	var rows := [
		["누적 열", "%d" % sim.total_heat, Defs.COL_CORE],
		["어제 모은 열", "+%d" % gained if gained > 0 else "-", Defs.COL_TEXT_DIM],
		["고양이", "%d마리" % sim.cats.size(), Defs.COL_TEXT_DIM],
	]
	var y: float = 176.0
	for row in rows:
		_text(card.position + Vector2(74, y), String(row[0]), 14, Defs.COL_TEXT_DIM)
		_text_in(Rect2(card.position + Vector2(w - 174, y - 14), Vector2(100, 18)), String(row[1]), 14,
			row[2], HORIZONTAL_ALIGNMENT_RIGHT)
		y += 24.0

	# The factory survives the night; that is the whole reason to keep going.
	_text_in(Rect2(card.position + Vector2(0, y + 16), Vector2(w, 20)),
		"공장과 온기는 그대로 남습니다", 12, Defs.COL_TEXT_DIM)
	var blink: float = 0.72 + sin(float(Time.get_ticks_msec()) / 320.0) * 0.28
	var touch_pad: bool = main.touch != null and main.touch.visible
	var next_label: String = "화면을 눌러 %d일차 시작" % (main.day_number + 1) if touch_pad \
		else "Enter — %d일차 시작" % (main.day_number + 1)
	_text_in(Rect2(card.position + Vector2(0, card.size.y - 42), Vector2(w, 20)), next_label, 16,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, blink))
	# No "start over" here. Settings already carries it, behind a confirmation,
	# and the summary card is the one screen a player presses through every day
	# without reading -- an unguarded key that throws the run away does not belong
	# on it.


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
	_panel(rect, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.92),
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.55))
	var tint: Color = Defs.COL_CORE if open else Defs.COL_TEXT
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
	_panel(rect, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.92),
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.55))
	var tint: Color = Defs.COL_CORE if open else Defs.COL_TEXT
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
		"확대 %d%%   ←/→   Esc 닫기" % int(round(float(main.get("map_zoom")) * 100.0)),
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
