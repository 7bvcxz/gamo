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
var settings_close_rect := Rect2()
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
	var count: float = float(Defs.BUILDABLE.size())
	var available: float = size.x - MARGIN * 2.0 - (count - 1.0) * SLOT_GAP
	return Vector2(clampf(available / count, SLOT_MIN_W, SLOT_MAX_W), SLOT_H)

func hotbar_origin() -> Vector2:
	var slot: Vector2 = hotbar_slot()
	var total: float = float(Defs.BUILDABLE.size()) * (slot.x + SLOT_GAP) - SLOT_GAP
	# Lifted clear of the thumb controls rather than sharing the bottom strip
	# with them, which at large UI scales buried a card under the X button.
	var bottom: float = size.y - slot.y - MARGIN - bottom_reserved()
	return Vector2(size.x * 0.5 - total * 0.5, bottom)

## Everything above the status panel, so the gear owns the very top-left corner.
func status_top() -> float:
	return MARGIN + SETTINGS_BUTTON + 8.0

## Below the gear, and never wider than the screen it is drawn on.
func status_rect() -> Rect2:
	return Rect2(MARGIN, status_top(), minf(PANEL_W, size.x - MARGIN * 2.0), 128)

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
	hotbar_rects.clear()
	for index in Defs.BUILDABLE.size():
		hotbar_rects.append(Rect2(origin + Vector2(float(index) * (slot.x + SLOT_GAP), 0), slot))
	var label: String = "R 출력 방향  오른쪽"
	var width: float = _text_width(label, 12) + 44.0
	direction_rect = Rect2(size.x * 0.5 - width * 0.5, origin.y - 58.0, width, 24.0)
	settings_button_rect = Rect2(MARGIN, MARGIN, SETTINGS_BUTTON, SETTINGS_BUTTON)
	_layout_settings()

const SETTINGS_CARD_H := 346.0
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
	settings_close_rect = Rect2(card.position + Vector2(card.size.x * 0.5 - 72.0, card.size.y - 62.0),
		Vector2(144.0, 42.0))

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
		main.State.RESULT: _draw_result()
		main.State.PAUSED:
			# Dim the world only. Pause is when the player stops to read the HUD,
			# so the HUD itself must stay at full brightness.
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, 0.55))
			_draw_status()
			_draw_palette()
			_draw_pause_card()
		main.State.SETTINGS:
			# Draw the screen it was opened over, so the player can see their
			# change land on the real HUD instead of on an empty backdrop.
			if main.state_before_settings == main.State.TITLE:
				_draw_title()
			else:
				_draw_status()
				_draw_palette()
			_draw_settings_card()
		_:
			_draw_cold_vignette()
			_draw_blackout()
			_draw_status()
			_draw_palette()
			_draw_message()
	_draw_settings_button()

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
func _draw_cold_vignette() -> void:
	var dusk: float = clampf((main.day_fraction() - 0.55) / 0.45, 0.0, 1.0)
	if dusk > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.07, 0.16, dusk * 0.38))

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
	var sim = main.sim
	var panel: Rect2 = status_rect()
	# Fully opaque: ore silhouettes were crawling behind the temperature row.
	_panel(panel, Defs.COL_PANEL, Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.9))

	# The clock is the cold pressure, so it is rendered cold and never outranks
	# the core in brightness.
	var seconds: int = int(ceil(main.time_left))
	var urgent: bool = seconds <= 45
	# In a five-minute one-shot the clock is the game; it gets the top of the
	# hierarchy back, while its caption drops well below it.
	var clock: Color = Defs.COL_DANGER if urgent else Color8(226, 236, 248)
	_text(panel.position + Vector2(14, 38), "%02d:%02d" % [seconds / 60, seconds % 60], 26, clock)
	var track := Rect2(panel.position + Vector2(104, 22), Vector2(112, 6))
	draw_rect(track, Color8(28, 36, 54))
	var fill: float = clampf(main.time_left / Defs.DAY_SECONDS, 0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(track.size.x * fill, track.size.y)),
		Defs.COL_DANGER if urgent else Defs.COL_CLOCK_FILL)
	_text(panel.position + Vector2(104, 44), "%d일차 · 해질녘까지" % main.day_number, 11, Defs.COL_CLOCK)

	# Heat is the score, the currency and the map key, so it gets the warm accent.
	# The warm radius is what the run is actually about, so it is promoted above
	# the running totals rather than tucked into the panel's dead corner.
	_text(panel.position + Vector2(14, 70), "열 %d" % sim.heat, 19, Defs.COL_CORE)
	_text_in(Rect2(panel.position + Vector2(96, 58), Vector2(120, 20)), "온기 %.1f칸" % sim.warm_radius, 15,
		Defs.COL_MACHINE_EDGE, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(panel.position + Vector2(70, 70), "%+.0f/분" % sim.heat_rate, 13,
		Defs.COL_CORE if sim.heat_rate > 0.0 else Defs.COL_TEXT_DIM)
	_text_in(Rect2(panel.position + Vector2(96, 76), Vector2(120, 16)), "누적 %d" % sim.total_heat, 11,
		Defs.COL_CLOCK, HORIZONTAL_ALIGNMENT_RIGHT)
	# Copper and iron are materials, not currency, so they get their own row.
	var materials: Vector2 = panel.position + Vector2(14, 92)
	draw_circle(materials + Vector2(4, -4), 4.5, Defs.ITEM_COLORS[Defs.ITEM_COPPER])
	# Stock, not lifetime totals: this is the number the player spends, so it is
	# the number that has to be on screen.
	var slot_x: float = 0.0
	for item_type: int in Defs.COUNTED_ITEMS:
		var held: int = int(sim.stock.get(item_type, 0))
		draw_circle(materials + Vector2(slot_x + 5, -4), 4.0, Defs.ITEM_COLORS[item_type])
		var short: String = Defs.ITEM_SHORT[item_type]
		_text(materials + Vector2(slot_x + 13, 0), "%s %d" % [short, held], 12,
			Defs.COL_TEXT if held > 0 else Defs.COL_TEXT_DIM)
		slot_x += 68.0

	_draw_warmth_row(panel)
	_draw_objective()

## The next useful action, always on screen. This is the whole onboarding: no
## modal tutorial, no text wall, just one line that keeps up with the player.
## Split out from the drawing so the placement can be asserted directly; the
## overlap this avoids only appears at scales a test has to drive deliberately.
func objective_rect(text: String) -> Rect2:
	# The trailing pad has to clear the last glyph's advance, not just sit flush
	# against it, or the closing bracket lands on the plate border.
	var width: float = minf(_text_width(text, 12) + 34.0, size.x - MARGIN * 2.0)
	# Pinned to the top right, away from the status panel and the hotbar.
	var box := Rect2(size.x - width - MARGIN, MARGIN + 26.0, width, 24.0)
	# Once the UI is scaled up there is no longer room for both across the top,
	# so the objective drops underneath the panel instead of across it.
	var panel: Rect2 = status_rect()
	if box.position.x < panel.position.x + panel.size.x + 8.0:
		box.position.y = panel.position.y + panel.size.y + 8.0
	return box

func _draw_objective() -> void:
	var text: String = main.objective()
	var box: Rect2 = objective_rect(text)
	_panel(box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.88),
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.45))
	draw_rect(Rect2(box.position, Vector2(3, box.size.y)), Defs.COL_CORE)
	_text(box.position + Vector2(12, 16), text, 12, Defs.COL_TEXT)

## Docked into the status panel and always present, so it can never pop in and
## shift the layout at the exact moment the player is in danger.
func _draw_warmth_row(panel: Rect2) -> void:
	var warmth: float = main.player.warmth
	var k: float = clampf(warmth / 100.0, 0.0, 1.0)
	var origin: Vector2 = panel.position + Vector2(14, 108)
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

func _draw_palette() -> void:
	var count: int = Defs.BUILDABLE.size()
	var slot: Vector2 = hotbar_slot()
	var origin: Vector2 = hotbar_origin()

	# The hint sits above the hotbar in its own plate; it used to run through the
	# cards and over their cost labels.
	_draw_direction_chip(origin.y)
	var selected: int = Defs.BUILDABLE[main.selected_index]
	var hint: String = Defs.MACHINE_HINTS[selected]
	if selected == Defs.M_EXCHANGER or selected == Defs.M_MINER:
		hint += "   ·   " + Defs.ratio_hint()
	var hint_w: float = _text_width(hint, 12) + 20.0
	var hint_box := Rect2(size.x * 0.5 - hint_w * 0.5, origin.y - 28.0, hint_w, 22.0)
	_panel(hint_box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.88),
		Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.5))
	_text_in(Rect2(hint_box.position + Vector2(0, 15), Vector2(hint_box.size.x, 16)), hint, 12, Defs.COL_TEXT_DIM)

	for index in count:
		var type: int = Defs.BUILDABLE[index]
		var rect: Rect2 = hotbar_rects[index] if index < hotbar_rects.size() \
			else Rect2(origin + Vector2(float(index) * (slot.x + SLOT_GAP), 0), slot)
		var at: Vector2 = rect.position
		var chosen: bool = index == main.selected_index
		var afford: bool = main.sim.can_afford(type)
		var locked: bool = not main.sim.is_unlocked(type)
		var edge: Color = Defs.COL_CORE if chosen else Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.9)
		# Opaque so world sprites can never bleed through the card.
		_panel(rect, Defs.COL_PANEL, edge, 2.0 if chosen else 1.0)

		var label: Color = Defs.COL_TEXT if afford else Defs.COL_TEXT_DIM
		if locked:
			label = Defs.COL_TEXT_DIM
		_text(at + Vector2(11, 21), "%d  %s" % [index + 1, Defs.MACHINE_SHORT[type]], 13, label)
		if locked:
			# Say what opens it. A locked slot the player cannot work toward is
			# just a hole in the row.
			var key_item: int = Defs.MACHINE_UNLOCK_ITEM[type]
			_text(at + Vector2(11, 39), "%s을 찾으면 해금" % Defs.ITEM_NAMES[key_item], 11,
				Defs.COL_TEXT_DIM)
			draw_rect(rect, Color(0.02, 0.03, 0.06, 0.34))
		else:
			var cost_text := ""
			for item_type: int in Defs.MACHINE_COSTS[type]:
				cost_text += "%s %d  " % [Defs.ITEM_NAMES[item_type], int(Defs.MACHINE_COSTS[type][item_type])]
			if type == Defs.M_BELT:
				cost_text += "· 전력 %.1f" % Defs.BELT_POWER_DRAW
			_text(at + Vector2(11, 37), cost_text.strip_edges(), 11,
				Defs.COL_CORE if afford else Defs.COL_DANGER)
			# The rate is what makes a machine plannable rather than a mystery.
			_text(at + Vector2(11, 47), Defs.throughput_line(type), 9, Defs.COL_TEXT_DIM)
		draw_circle(at + Vector2(slot.x - 17, 24), 7.5, Defs.machine_color(type))
		draw_circle(at + Vector2(slot.x - 17, 24), 7.5, Color(0, 0, 0, 0.35), false, 1.0)

	# Right-aligned inside an explicit box with a real margin, so nothing is ever
	# clipped by the viewport edge.
	# On a phone the keyboard legend is noise; the pad already carries the verbs.
	if main.touch == null or not main.touch.visible:
		_text_in(Rect2(size.x - 460.0 - MARGIN, MARGIN + 2.0, 460.0, 16),
			"C 채굴   Z 설치   X 회수   R 회전   F 제법   Esc 일시정지", 12, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

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

func _draw_message() -> void:
	if main.message_life <= 0.0:
		return
	var alpha: float = clampf(main.message_life, 0.0, 1.0)
	var box := Rect2(0, 196, size.x, 20)
	_text_in(box, main.message, 15, Color(message_color.r, message_color.g, message_color.b, alpha))

# --- Overlays ----------------------------------------------------------------

func _dim(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, alpha))

## Geometry only, so the settings layout can be computed without drawing. Narrows
## on small screens rather than hanging off both edges.
func _card_rect(height: float) -> Rect2:
	var width: float = minf(420.0, size.x - MARGIN * 2.0)
	return Rect2(size.x * 0.5 - width * 0.5, size.y * 0.5 - height * 0.5, width, height)

func _card(height: float) -> Rect2:
	var card: Rect2 = _card_rect(height)
	_panel(card, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.96),
		Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.9))
	draw_rect(Rect2(card.position, Vector2(card.size.x, 3)), Defs.COL_CORE)
	return card

func _draw_title() -> void:
	# A single even dim. The banded version read as a hard seam across the art on
	# tall phone screens, where the band edge landed in open sky.
	_dim(0.55)
	var full := func(y: float) -> Rect2: return Rect2(0, y, size.x, 40)
	var touch_pad: bool = main.touch != null and main.touch.visible
	_text_in(full.call(size.y * 0.30), "MOTORIO", 56, Defs.COL_CORE)
	_text_in(full.call(size.y * 0.30 + 32), "O N E   S H O T", 17, Defs.COL_MACHINE_EDGE)
	_text_in(full.call(size.y * 0.52), "하룻밤 안에 공장을 세워 열을 최대한 모으세요.", 16, Defs.COL_TEXT)
	_text_in(full.call(size.y * 0.52 + 24), "코어에 광석을 넣을수록 온기가 넓어지고 더 좋은 광맥에 닿습니다.", 13, Defs.COL_TEXT_DIM)
	# Never let the one call to action fall below a readable floor.
	var blink: float = 0.82 + sin(float(Time.get_ticks_msec()) / 320.0) * 0.18
	_text_in(full.call(size.y * 0.72), "화면을 눌러 시작" if touch_pad else "아무 키나 눌러 시작", 18,
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, blink))
	var controls: String = "휠 이동   Z 설치   X 회수   Run 달리기" if touch_pad \
		else "WASD 이동   Z 설치   X 회수   R 회전   1·2·3 선택"
	_text_in(full.call(size.y * 0.84), controls, 12, Defs.COL_TEXT_DIM)
	# So a player can say which build they are on without opening anything.
	_text_in(Rect2(0, size.y - MARGIN, size.x - MARGIN, 16), "v%s" % version_string(), 11,
		Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)

## Read from the project settings rather than duplicated here, so the number on
## screen can never disagree with the one that was shipped.
func version_string() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## Top-left corner, on every screen including the title. A player whose HUD is
## too small to read has to be able to find this without reading anything, so it
## is an icon in a fixed corner rather than an entry in a menu.
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

	var touch_pad: bool = main.touch != null and main.touch.visible
	_text_in(Rect2(card.position + Vector2(0, SETTINGS_CARD_H - 76.0), Vector2(w, 18)),
		"슬라이더를 드래그하세요" if touch_pad else "↑ ↓ 로 선택, ← → 로 조절", 12, Defs.COL_TEXT_DIM)
	var close: Rect2 = settings_close_rect
	_panel(close, Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.18), Defs.COL_CORE)
	_text_in(Rect2(close.position + Vector2(0, 28), Vector2(close.size.x, 22)), "닫기", 16, Defs.COL_TEXT)

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

func _draw_pause_card() -> void:
	var card := _card(150.0)
	_text_in(Rect2(card.position + Vector2(0, 62), Vector2(card.size.x, 40)), "일시정지", 32, Defs.COL_TEXT)
	_text_in(Rect2(card.position + Vector2(0, 104), Vector2(card.size.x, 20)), "Esc 로 계속", 14, Defs.COL_TEXT_DIM)

func _draw_result() -> void:
	_dim(0.82)
	var sim = main.sim
	var card := _card(340.0)
	var w: float = card.size.x
	var headline: String = "%d일차 · 고양이들이 데려왔습니다" % main.day_number if main.rescued_tonight else "%d일차 · 숙소에서 잤습니다" % main.day_number
	_text_in(Rect2(card.position + Vector2(0, 44), Vector2(w, 30)), headline, 21,
		Defs.COL_DANGER if main.rescued_tonight else Defs.COL_TEXT)
	_text_in(Rect2(card.position + Vector2(0, 106), Vector2(w, 70)), "+%d" % main.day_heat(), 52, Defs.COL_CORE)
	_text_in(Rect2(card.position + Vector2(0, 130), Vector2(w, 20)), "오늘 모은 열", 13, Defs.COL_TEXT_DIM)

	var rows := [
		["누적 열", "%d" % sim.total_heat, Defs.COL_CORE],
		["온기 반경", "%.1f칸" % sim.warm_radius, Defs.COL_MACHINE_EDGE],
		["최고 하루", "%d" % main.best_day_heat, Defs.COL_TEXT_DIM],
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
	_text_in(Rect2(card.position + Vector2(0, card.size.y - 20), Vector2(w, 20)), "N — 새로 시작", 12, Defs.COL_TEXT_DIM)
