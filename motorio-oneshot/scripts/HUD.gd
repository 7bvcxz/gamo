extends Control

## All screen-space UI. Immediate-mode drawing keeps the whole layout readable
## in one file; every position below is expressed against a screen edge so the
## HUD never depends on a fixed window size.

const MARGIN := 20.0
const PANEL_W := 232.0

var main
var message_color: Color = Defs.COL_TEXT

var _repaint := 0.0

func _process(delta: float) -> void:
	_repaint += delta
	if _repaint < 1.0 / 30.0:
		return
	_repaint = 0.0
	queue_redraw()

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
		_:
			_draw_cold_vignette()
			_draw_status()
			_draw_palette()
			_draw_message()

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
	var chill: float = clampf((60.0 - main.player.warmth) / 60.0, 0.0, 1.0)
	_draw_snow(maxf(chill, exposure * 0.7))
	if chill <= 0.0:
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
	var panel := Rect2(MARGIN, MARGIN, PANEL_W, 108)
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
	_text_in(Rect2(panel.position + Vector2(96, 76), Vector2(120, 16)), "누적 %d" % sim.total_heat, 11,
		Defs.COL_CLOCK, HORIZONTAL_ALIGNMENT_RIGHT)

	_draw_warmth_row(panel)
	_draw_objective(panel)

## The next useful action, always on screen. This is the whole onboarding: no
## modal tutorial, no text wall, just one line that keeps up with the player.
func _draw_objective(panel: Rect2) -> void:
	var text: String = main.objective()
	var width: float = _text_width(text, 12) + 26.0
	var box := Rect2(panel.position.x, panel.end.y + 10.0, width, 24.0)
	_panel(box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.88),
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, 0.45))
	draw_rect(Rect2(box.position, Vector2(3, box.size.y)), Defs.COL_CORE)
	_text(box.position + Vector2(12, 16), text, 12, Defs.COL_TEXT)

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
	if main.rescue_timer >= 0.0:
		# Below the character, never across her.
		_text_in(Rect2(0, size.y * 0.64, size.x, 20), "코어로 복귀 중…", 19, Defs.COL_DANGER)

func _draw_palette() -> void:
	var count: int = Defs.BUILDABLE.size()
	var slot := Vector2(118, 48)
	var total: float = float(count) * (slot.x + 10) - 10
	var origin := Vector2(size.x * 0.5 - total * 0.5, size.y - slot.y - MARGIN)

	# The hint sits above the hotbar in its own plate; it used to run through the
	# cards and over their cost labels.
	_draw_direction_chip(origin.y)
	var hint: String = Defs.MACHINE_HINTS[Defs.BUILDABLE[main.selected_index]]
	var hint_w: float = _text_width(hint, 12) + 20.0
	var hint_box := Rect2(size.x * 0.5 - hint_w * 0.5, origin.y - 28.0, hint_w, 22.0)
	_panel(hint_box, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.88),
		Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.5))
	_text_in(Rect2(hint_box.position + Vector2(0, 15), Vector2(hint_box.size.x, 16)), hint, 12, Defs.COL_TEXT_DIM)

	for index in count:
		var type: int = Defs.BUILDABLE[index]
		var at: Vector2 = origin + Vector2(float(index) * (slot.x + 10), 0)
		var rect := Rect2(at, slot)
		var chosen: bool = index == main.selected_index
		var afford: bool = main.sim.heat >= Defs.MACHINE_COSTS[type]
		var edge: Color = Defs.COL_CORE if chosen else Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.9)
		# Opaque so world sprites can never bleed through the card.
		_panel(rect, Defs.COL_PANEL, edge, 2.0 if chosen else 1.0)
		var label: Color = Defs.COL_TEXT if afford else Defs.COL_TEXT_DIM
		_text(at + Vector2(11, 21), "%d  %s" % [index + 1, Defs.MACHINE_NAMES[type]], 13, label)
		_text(at + Vector2(11, 39), "열 %d" % Defs.MACHINE_COSTS[type], 12, Defs.COL_CORE if afford else Defs.COL_DANGER)
		draw_circle(at + Vector2(slot.x - 17, 24), 7.5, Defs.machine_color(type))
		draw_circle(at + Vector2(slot.x - 17, 24), 7.5, Color(0, 0, 0, 0.35), false, 1.0)

	# Right-aligned inside an explicit box with a real margin, so nothing is ever
	# clipped by the viewport edge.
	_text_in(Rect2(size.x - 420.0 - MARGIN, MARGIN + 4.0, 420.0, 16),
		"Z 설치   X 회수   R 회전   Esc 일시정지", 12, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

## R rotates the output direction, but until now nothing on screen said which
## way was currently selected, so the key felt like it did nothing.
func _draw_direction_chip(hotbar_y: float) -> void:
	var dir: Vector2i = main.build_dir
	var names := {
		Vector2i.UP: "위", Vector2i.DOWN: "아래",
		Vector2i.LEFT: "왼쪽", Vector2i.RIGHT: "오른쪽",
	}
	var label: String = "R 출력 방향  %s" % String(names.get(dir, "오른쪽"))
	var width: float = _text_width(label, 12) + 44.0
	var box := Rect2(size.x * 0.5 - width * 0.5, hotbar_y - 58.0, width, 24.0)
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

func _card(height: float) -> Rect2:
	var card := Rect2(size.x * 0.5 - 210.0, size.y * 0.5 - height * 0.5, 420.0, height)
	_panel(card, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.96),
		Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.9))
	draw_rect(Rect2(card.position, Vector2(card.size.x, 3)), Defs.COL_CORE)
	return card

func _draw_title() -> void:
	# A single even dim. The banded version read as a hard seam across the art on
	# tall phone screens, where the band edge landed in open sky.
	_dim(0.55)
	var full := func(y: float) -> Rect2: return Rect2(0, y, size.x, 40)
	_text_in(full.call(size.y * 0.30), "MOTORIO", 56, Defs.COL_CORE)
	_text_in(full.call(size.y * 0.30 + 32), "O N E   S H O T", 17, Defs.COL_MACHINE_EDGE)
	_text_in(full.call(size.y * 0.52), "하룻밤 안에 공장을 세워 열을 최대한 모으세요.", 16, Defs.COL_TEXT)
	_text_in(full.call(size.y * 0.52 + 24), "코어에 광석을 넣을수록 온기가 넓어지고 더 좋은 광맥에 닿습니다.", 13, Defs.COL_TEXT_DIM)
	# Never let the one call to action fall below a readable floor.
	var blink: float = 0.82 + sin(float(Time.get_ticks_msec()) / 320.0) * 0.18
	_text_in(full.call(size.y * 0.72), "아무 키나 눌러 시작", 18,
		Color(Defs.COL_CORE.r, Defs.COL_CORE.g, Defs.COL_CORE.b, blink))
	var touch_pad: bool = main.touch != null and main.touch.visible
	var controls: String = "휠 이동   Z 설치   X 회수   Run 달리기" if touch_pad \
		else "WASD 이동   Z 설치   X 회수   R 회전   1·2·3 선택"
	_text_in(full.call(size.y * 0.84), controls, 12, Defs.COL_TEXT_DIM)

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
	_text_in(Rect2(card.position + Vector2(0, card.size.y - 42), Vector2(w, 20)), "Enter — %d일차 시작" % (main.day_number + 1), 16,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, blink))
	_text_in(Rect2(card.position + Vector2(0, card.size.y - 20), Vector2(w, 20)), "N — 새로 시작", 12, Defs.COL_TEXT_DIM)
