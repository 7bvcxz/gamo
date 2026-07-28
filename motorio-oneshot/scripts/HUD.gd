extends Control

## All screen-space UI: run status, build palette, and the title / pause /
## result overlays. Immediate-mode drawing keeps the layout in one readable file.

var main
var message_color: Color = Defs.COL_TEXT

func _process(_delta: float) -> void:
	queue_redraw()

func _panel(rect: Rect2, fill: Color, edge: Color, width: float = 1.0) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, width)

func _text(at: Vector2, body: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(UIFont.FONT, at + Vector2(1, 1), body, align, width, size, Color(0.02, 0.03, 0.06, 0.75))
	draw_string(UIFont.FONT, at, body, align, width, size, color)

func _draw() -> void:
	if main == null:
		return
	match main.state:
		main.State.TITLE: _draw_title()
		main.State.RESULT: _draw_result()
		_:
			_draw_status()
			_draw_palette()
			_draw_message()
			if main.state == main.State.PAUSED:
				_draw_pause()

# --- In-run UI ---------------------------------------------------------------

func _draw_status() -> void:
	var sim = main.sim
	var panel := Rect2(14, 12, 214, 84)
	_panel(panel, Color(0.05, 0.07, 0.11, 0.78), Color(Defs.COL_BRASS.r, Defs.COL_BRASS.g, Defs.COL_BRASS.b, 0.45))

	# Time is the run's whole pressure, so it gets the largest type on screen.
	var seconds: int = int(ceil(main.time_left))
	var urgent: bool = seconds <= 45
	var clock: Color = Defs.COL_DANGER if urgent else Defs.COL_TEXT
	_text(Vector2(26, 40), "%02d:%02d" % [seconds / 60, seconds % 60], 26, clock)
	_text(Vector2(112, 32), "남은 시간", 11, Defs.COL_TEXT_DIM)

	var bar := Rect2(112, 36, 104, 7)
	draw_rect(bar, Color(0.10, 0.13, 0.19, 0.9))
	var fill: float = clampf(main.time_left / Defs.DAY_SECONDS, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), clock)

	_text(Vector2(26, 66), "열 %d" % sim.heat, 17, Defs.COL_CORE)
	_text(Vector2(112, 62), "누적 %d" % sim.total_heat, 12, Defs.COL_TEXT_DIM)
	_text(Vector2(112, 78), "온기 %.1f칸" % sim.warm_radius, 12, Defs.COL_TEXT_DIM)

	_draw_warmth_bar()

func _draw_warmth_bar() -> void:
	var warmth: float = main.player.warmth
	if warmth >= 99.5 and main.rescue_timer < 0.0:
		return
	var bar := Rect2(size.x * 0.5 - 90, size.y - 96, 180, 12)
	_panel(bar, Color(0.05, 0.07, 0.11, 0.8), Color(Defs.COL_DANGER.r, Defs.COL_DANGER.g, Defs.COL_DANGER.b, 0.5))
	var k: float = clampf(warmth / 100.0, 0.0, 1.0)
	var col: Color = Defs.COL_DANGER.lerp(Defs.COL_CORE, k)
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * k, bar.size.y - 4)), col)
	_text(bar.position + Vector2(bar.size.x * 0.5, -6), "체온", 11, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if main.rescue_timer >= 0.0:
		_text(bar.position + Vector2(bar.size.x * 0.5, 34), "코어로 복귀 중…", 14, Defs.COL_DANGER, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_palette() -> void:
	var count: int = Defs.BUILDABLE.size()
	var slot := Vector2(112, 46)
	var total: float = float(count) * (slot.x + 8) - 8
	var origin := Vector2(size.x * 0.5 - total * 0.5, size.y - 66)
	for index in count:
		var type: int = Defs.BUILDABLE[index]
		var at: Vector2 = origin + Vector2(float(index) * (slot.x + 8), 0)
		var rect := Rect2(at, slot)
		var chosen: bool = index == main.selected_index
		var afford: bool = main.sim.heat >= Defs.MACHINE_COSTS[type]
		var edge: Color = Defs.COL_CORE if chosen else Color(Defs.COL_BRASS.r, Defs.COL_BRASS.g, Defs.COL_BRASS.b, 0.35)
		_panel(rect, Color(0.05, 0.07, 0.11, 0.86 if chosen else 0.66), edge, 2.0 if chosen else 1.0)
		var label: Color = Defs.COL_TEXT if afford else Color(Defs.COL_TEXT_DIM.r, Defs.COL_TEXT_DIM.g, Defs.COL_TEXT_DIM.b, 0.75)
		_text(at + Vector2(10, 20), "%d  %s" % [index + 1, Defs.MACHINE_NAMES[type]], 13, label)
		var cost: Color = Defs.COL_CORE if afford else Defs.COL_DANGER
		_text(at + Vector2(10, 38), "열 %d" % Defs.MACHINE_COSTS[type], 12, cost)
		draw_circle(at + Vector2(slot.x - 16, 23), 7.0, Defs.machine_color(type))
	var hint: int = Defs.BUILDABLE[main.selected_index]
	_text(Vector2(size.x * 0.5, size.y - 14), Defs.MACHINE_HINTS[hint], 12, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(size.x - 16, size.y - 14), "Z 설치   X 회수   R 회전   Esc 일시정지", 12,
		Color(Defs.COL_TEXT_DIM.r, Defs.COL_TEXT_DIM.g, Defs.COL_TEXT_DIM.b, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)

func _draw_message() -> void:
	if main.message_life <= 0.0:
		return
	var alpha: float = clampf(main.message_life, 0.0, 1.0)
	var at := Vector2(size.x * 0.5, 128)
	_text(at, main.message, 15, Color(message_color.r, message_color.g, message_color.b, alpha), HORIZONTAL_ALIGNMENT_CENTER)

# --- Overlays ----------------------------------------------------------------

func _dim(alpha: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.06, alpha))

func _draw_title() -> void:
	_dim(0.72)
	var centre: float = size.x * 0.5
	_text(Vector2(centre, size.y * 0.34), "MOTORIO", 54, Defs.COL_CORE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(centre, size.y * 0.34 + 30), "O N E   S H O T", 17, Defs.COL_MACHINE_EDGE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(centre, size.y * 0.52), "하룻밤 안에 공장을 세워 열을 최대한 모으세요.", 15, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(centre, size.y * 0.52 + 22), "코어에 광석을 넣을수록 온기가 넓어지고, 더 좋은 광맥에 닿습니다.", 13, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var blink: float = 0.55 + sin(Time.get_ticks_msec() / 320.0) * 0.45
	_text(Vector2(centre, size.y * 0.72), "아무 키나 눌러 시작", 17, Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, blink), HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(centre, size.y * 0.82), "WASD 이동   Z 설치   X 회수   R 회전   1·2·3 선택", 12, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_pause() -> void:
	_dim(0.62)
	_text(Vector2(size.x * 0.5, size.y * 0.44), "일시정지", 34, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(size.x * 0.5, size.y * 0.56), "Esc 로 계속", 15, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_result() -> void:
	_dim(0.80)
	var sim = main.sim
	var centre: float = size.x * 0.5
	_text(Vector2(centre, size.y * 0.22), "밤이 내렸습니다", 30, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(centre, size.y * 0.36), "%d" % sim.total_heat, 60, Defs.COL_CORE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(centre, size.y * 0.36 + 24), "누적 열", 14, Defs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)

	var rows := [
		["서리광석", sim.delivered.get(Defs.ITEM_FROST, 0), Defs.ITEM_COLORS[Defs.ITEM_FROST]],
		["잉걸광석", sim.delivered.get(Defs.ITEM_EMBER, 0), Defs.ITEM_COLORS[Defs.ITEM_EMBER]],
		["합금", sim.delivered.get(Defs.ITEM_ALLOY, 0), Defs.ITEM_COLORS[Defs.ITEM_ALLOY]],
	]
	var y: float = size.y * 0.56
	for row in rows:
		_text(Vector2(centre - 90, y), String(row[0]), 14, row[2])
		_text(Vector2(centre + 90, y), "%d" % int(row[1]), 14, Defs.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 22.0
	_text(Vector2(centre, y + 12), "최고 기록 %d" % main.best_heat, 14, Defs.COL_MACHINE_EDGE, HORIZONTAL_ALIGNMENT_CENTER)
	var blink: float = 0.55 + sin(Time.get_ticks_msec() / 320.0) * 0.45
	_text(Vector2(centre, size.y * 0.88), "Enter 로 다시 도전", 17,
		Color(Defs.COL_TEXT.r, Defs.COL_TEXT.g, Defs.COL_TEXT.b, blink), HORIZONTAL_ALIGNMENT_CENTER)
