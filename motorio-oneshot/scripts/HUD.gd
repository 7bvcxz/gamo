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
var settings_restart_rect := Rect2()
var settings_save_rect := Rect2()
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
	var total: float = float(main.TOOLS.size()) * (slot.x + SLOT_GAP) - SLOT_GAP
	# Lifted clear of the thumb controls rather than sharing the bottom strip
	# with them, which at large UI scales buried a card under the X button.
	var bottom: float = size.y - slot.y - MARGIN - bottom_reserved()
	return Vector2(size.x * 0.5 - total * 0.5, bottom)

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
	hotbar_rects.clear()
	for index in main.TOOLS.size():
		hotbar_rects.append(Rect2(origin + Vector2(float(index) * (slot.x + SLOT_GAP), 0), slot))
	var label: String = "R 출력 방향  오른쪽"
	var width: float = _text_width(label, 12) + 44.0
	direction_rect = Rect2(size.x * 0.5 - width * 0.5, origin.y - 58.0, width, 24.0)
	settings_button_rect = Rect2(MARGIN, MARGIN, SETTINGS_BUTTON, SETTINGS_BUTTON)
	_layout_settings()

## Two sliders, then a row of two actions, then close. Taller than it was because
## Esc opens this panel now: it is the only stopped screen, so everything a
## player wants while stopped has to be reachable from it.
const SETTINGS_CARD_H := 424.0
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
	var action_y: float = card.size.y - 134.0
	settings_restart_rect = Rect2(card.position + Vector2(34.0, action_y), Vector2(action_w, 44.0))
	settings_save_rect = Rect2(card.position + Vector2(34.0 + action_w + gap, action_y),
		Vector2(action_w, 44.0))
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
			_draw_settings_card()
		_:
			_draw_cold_vignette()
			_draw_blackout()
			_draw_status()
			_draw_resources()
			_draw_palette()
			_draw_meter_card()
			_draw_build_menu()
			_draw_message()
	_draw_settings_button()
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
	return box

func _draw_objective() -> void:
	var goal: Dictionary = main.objective_data()
	var text: String = String(goal["text"])
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
	var slot: Vector2 = hotbar_slot()
	var origin: Vector2 = hotbar_origin()
	_draw_direction_chip(origin.y)

	var loaded: int = main.selected_type()
	var hint: String = Defs.MACHINE_HINTS[loaded]
	if loaded == Defs.M_EXCHANGER or loaded == Defs.M_MINER:
		hint += "   ·   " + Defs.ratio_hint()
	var hint_w: float = _text_width(hint, 12) + 24.0
	var hint_box := Rect2(size.x * 0.5 - hint_w * 0.5, origin.y - 30.0, hint_w, 24.0)
	_frame(hint_box, Defs.COL_PANEL_EDGE)
	_text_in(Rect2(hint_box.position + Vector2(0, 16), Vector2(hint_box.size.x, 16)), hint, 12,
		Defs.COL_TEXT_DIM)

	for index in main.TOOLS.size():
		var rect: Rect2 = hotbar_rects[index] if index < hotbar_rects.size() \
			else Rect2(origin + Vector2(float(index) * (slot.x + SLOT_GAP), 0), slot)
		var chosen: bool = index == main.tool_index
		_frame(rect, Defs.COL_CORE if chosen else Defs.COL_PANEL_EDGE)
		_text(rect.position + Vector2(FRAME_PAD, 16.0), "%d  %s" % [index + 1, main.TOOL_NAMES[index]],
			11, Defs.COL_CORE if chosen else Defs.COL_TEXT_DIM)
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
		# Under the hotbar, not across the top: the top right belongs to the
		# mission card now, and a key legend printed over it read as one long
		# unparseable line.
		_text_in(Rect2(size.x - 480.0 - MARGIN, origin.y + slot.y + 16.0, 480.0, 16),
			"C 채굴   Z 설치   X 회수   R 회전   B 목록   Esc 설정", 11, Defs.COL_TEXT_DIM,
			HORIZONTAL_ALIGNMENT_RIGHT)

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
			"%s을 손에 넣으면 해금됩니다" % Defs.ITEM_NAMES[key_item], 11, Defs.COL_TEXT_DIM)
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

## Every full-screen card -- title, day summary, settings -- through the same
## frame as every corner panel, so the interface reads as one object.
func _card(height: float) -> Rect2:
	var card: Rect2 = _card_rect(height)
	_frame(card, Defs.COL_CORE)
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
	var objective: Rect2 = objective_rect(main.objective())
	box.position.y = objective.position.y + objective.size.y + 8.0
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

	_draw_settings_action(settings_restart_rect,
		"정말 처음부터?" if restart_armed > 0.0 else "처음부터",
		Defs.COL_DANGER if restart_armed > 0.0 else Defs.COL_TEXT_DIM)
	_draw_settings_action(settings_save_rect,
		"저장했습니다" if saved_flash > 0.0 else "저장하기",
		Defs.COL_CORE if saved_flash > 0.0 else Defs.COL_TEXT_DIM)

	var touch_pad: bool = main.touch != null and main.touch.visible
	var hint: String = "한 번 더 누르면 지금까지의 공장이 사라집니다" if restart_armed > 0.0 \
		else ("슬라이더를 드래그하세요" if touch_pad else "↑ ↓ 로 선택, ← → 로 조절")
	_text_in(Rect2(card.position + Vector2(0, SETTINGS_CARD_H - 76.0), Vector2(w, 18)), hint, 12,
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
