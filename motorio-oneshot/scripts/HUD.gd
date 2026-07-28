extends Control

## All screen-space UI. Immediate-mode drawing keeps the whole layout readable
## in one file; every position below is expressed against a screen edge so the
## HUD never depends on a fixed window size.

const MARGIN := 20.0
const PANEL_W := 232.0

var main
var message_color: Color = Defs.COL_TEXT

func _process(_delta: float) -> void:
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
			_draw_status()
			_draw_palette()
			_draw_message()

# --- In-run UI ---------------------------------------------------------------

func _draw_status() -> void:
	var sim = main.sim
	var panel := Rect2(MARGIN, MARGIN, PANEL_W, 108)
	_panel(panel, Color(Defs.COL_PANEL.r, Defs.COL_PANEL.g, Defs.COL_PANEL.b, 0.92),
		Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.85))

	# The clock is the cold pressure, so it is rendered cold and never outranks
	# the core in brightness.
	var seconds: int = int(ceil(main.time_left))
	var urgent: bool = seconds <= 45
	var clock: Color = Defs.COL_DANGER if urgent else Defs.COL_CLOCK
	_text(panel.position + Vector2(14, 34), "%02d:%02d" % [seconds / 60, seconds % 60], 21, clock)
	var track := Rect2(panel.position + Vector2(88, 22), Vector2(128, 6))
	draw_rect(track, Color8(28, 36, 54))
	var fill: float = clampf(main.time_left / Defs.DAY_SECONDS, 0.0, 1.0)
	draw_rect(Rect2(track.position, Vector2(track.size.x * fill, track.size.y)),
		Defs.COL_DANGER if urgent else Defs.COL_CLOCK_FILL)
	_text(panel.position + Vector2(88, 44), "남은 시간", 11, Defs.COL_TEXT_DIM)

	# Heat is the score, the currency and the map key, so it gets the warm accent.
	_text(panel.position + Vector2(14, 66), "열 %d" % sim.heat, 19, Defs.COL_CORE)
	_text(panel.position + Vector2(112, 62), "누적 %d" % sim.total_heat, 12, Defs.COL_TEXT_DIM)
	_text(panel.position + Vector2(112, 78), "온기 %.1f칸" % sim.warm_radius, 12, Defs.COL_TEXT_DIM)

	_draw_warmth_row(panel)

## Docked into the status panel and always present, so it can never pop in and
## shift the layout at the exact moment the player is in danger.
func _draw_warmth_row(panel: Rect2) -> void:
	var warmth: float = main.player.warmth
	var k: float = clampf(warmth / 100.0, 0.0, 1.0)
	var origin: Vector2 = panel.position + Vector2(14, 88)
	_text(origin + Vector2(0, 10), "체온", 11, Defs.COL_TEXT_DIM)
	var track := Rect2(origin + Vector2(40, 2), Vector2(162, 9))
	draw_rect(track, Color8(28, 36, 54))
	var col: Color = Defs.COL_CORE.lerp(Defs.COL_DANGER, 1.0 - k)
	if k < 0.25:
		var pulse: float = 0.6 + sin(float(Time.get_ticks_msec()) / 90.0) * 0.4
		col = Defs.COL_DANGER.lerp(Color.WHITE, pulse * 0.35)
	draw_rect(Rect2(track.position, Vector2(track.size.x * k, track.size.y)), col)
	draw_rect(track, Color(Defs.COL_PANEL_EDGE.r, Defs.COL_PANEL_EDGE.g, Defs.COL_PANEL_EDGE.b, 0.6), false, 1.0)
	if main.rescue_timer >= 0.0:
		_text_in(Rect2(0, size.y * 0.5, size.x, 20), "코어로 복귀 중…", 19, Defs.COL_DANGER)

func _draw_palette() -> void:
	var count: int = Defs.BUILDABLE.size()
	var slot := Vector2(118, 48)
	var total: float = float(count) * (slot.x + 10) - 10
	var origin := Vector2(size.x * 0.5 - total * 0.5, size.y - slot.y - MARGIN)

	# The hint sits above the hotbar in its own plate; it used to run through the
	# cards and over their cost labels.
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
		"Z 설치   X 회수   R 회전   Esc 일시정지", 12,
		Color(Defs.COL_TEXT_DIM.r, Defs.COL_TEXT_DIM.g, Defs.COL_TEXT_DIM.b, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_message() -> void:
	if main.message_life <= 0.0:
		return
	var alpha: float = clampf(main.message_life, 0.0, 1.0)
	var box := Rect2(0, 150, size.x, 20)
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
	_dim(0.74)
	var full := func(y: float) -> Rect2: return Rect2(0, y, size.x, 40)
	_text_in(full.call(size.y * 0.30), "MOTORIO", 56, Defs.COL_CORE)
	_text_in(full.call(size.y * 0.30 + 32), "O N E   S H O T", 17, Defs.COL_MACHINE_EDGE)
	_text_in(full.call(size.y * 0.52), "하룻밤 안에 공장을 세워 열을 최대한 모으세요.", 16, Defs.COL_TEXT)
	_text_in(full.call(size.y * 0.52 + 24), "코어에 광석을 넣을수록 온기가 넓어지고 더 좋은 광맥에 닿습니다.", 13, Defs.COL_TEXT_DIM)
	var blink: float = 0.55 + sin(float(Time.get_ticks_msec()) / 320.0) * 0.45
	_text_in(full.call(size.y * 0.72), "아무 키나 눌러 시작", 18,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, blink))
	_text_in(full.call(size.y * 0.84), "WASD 이동   Z 설치   X 회수   R 회전   1·2·3 선택", 12, Defs.COL_TEXT_DIM)

func _draw_pause_card() -> void:
	var card := _card(150.0)
	_text_in(Rect2(card.position + Vector2(0, 62), Vector2(card.size.x, 40)), "일시정지", 32, Defs.COL_TEXT)
	_text_in(Rect2(card.position + Vector2(0, 104), Vector2(card.size.x, 20)), "Esc 로 계속", 14, Defs.COL_TEXT_DIM)

func _draw_result() -> void:
	_dim(0.82)
	var sim = main.sim
	var card := _card(330.0)
	var w: float = card.size.x
	_text_in(Rect2(card.position + Vector2(0, 44), Vector2(w, 30)), "밤이 내렸습니다", 24, Defs.COL_TEXT)
	_text_in(Rect2(card.position + Vector2(0, 108), Vector2(w, 70)), "%d" % sim.total_heat, 58, Defs.COL_CORE)
	_text_in(Rect2(card.position + Vector2(0, 132), Vector2(w, 20)), "누적 열", 13, Defs.COL_TEXT_DIM)

	var rows := [
		["서리광석", int(sim.delivered.get(Defs.ITEM_FROST, 0)), Defs.ITEM_COLORS[Defs.ITEM_FROST]],
		["잉걸광석", int(sim.delivered.get(Defs.ITEM_EMBER, 0)), Defs.ITEM_COLORS[Defs.ITEM_EMBER]],
		["합금", int(sim.delivered.get(Defs.ITEM_ALLOY, 0)), Defs.ITEM_COLORS[Defs.ITEM_ALLOY]],
	]
	var y: float = 176.0
	for row in rows:
		draw_circle(card.position + Vector2(74, y - 5), 5.0, row[2])
		_text(card.position + Vector2(88, y), String(row[0]), 14, Defs.COL_TEXT)
		_text_in(Rect2(card.position + Vector2(w - 160, y - 14), Vector2(100, 18)), "%d" % int(row[1]), 14,
			Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 24.0
	_text_in(Rect2(card.position + Vector2(0, y + 14), Vector2(w, 20)), "최고 기록 %d" % main.best_heat, 13, Defs.COL_MACHINE_EDGE)
	var blink: float = 0.55 + sin(float(Time.get_ticks_msec()) / 320.0) * 0.45
	_text_in(Rect2(card.position + Vector2(0, card.size.y - 22), Vector2(w, 20)), "Enter 로 다시 도전", 16,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, blink))
