extends Node2D

## Orchestrator: owns game state, input routing, camera and the run timer.
## Simulation lives in Sim, drawing lives in the layers, so this file stays thin.

## RESULT is the end of a day, not the end of the game: the world, the factory
## and the warm radius all carry into the next morning.
enum State { TITLE, PLAY, PAUSED, RESULT }

const SHAKE_DECAY := 7.0
const RESCUE_SECONDS := 1.6

@onready var sim: Sim = $Sim
@onready var ground_layer: GroundLayer = $Ground
@onready var cold_fog: ColdFog = $ColdFog
@onready var world_layer: WorldLayer = $World
@onready var machine_layer: MachineLayer = $Machines
@onready var fx: FxLayer = $Fx
@onready var player: PlayerActor = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $UI/HUD
@onready var audio: Node = $Audio
@onready var touch: TouchControls = $UI/TouchControls

var state: int = State.TITLE
var time_left: float = Defs.DAY_SECONDS
var selected_index: int = 0
var build_dir := Vector2i.RIGHT
var shake: float = 0.0
var rescue_timer: float = -1.0
var run_seed: int = 0
var best_heat: int = 0
var day_number: int = 1
var day_start_heat: int = 0
var best_day_heat: int = 0
var rescued_tonight: bool = false
var message: String = ""
var message_life: float = 0.0
var night_warned: bool = false

func _ready() -> void:
	randomize()
	sim.heat_gained.connect(_on_heat_gained)
	sim.build_rejected.connect(_on_build_rejected)
	sim.warmth_changed.connect(_on_warmth_changed)
	world_layer.sim = sim
	ground_layer.sim = sim
	cold_fog.sim = sim
	machine_layer.sim = sim
	hud.set("main", self)
	touch.main_controller = self
	touch.player = player
	_start_run()
	state = State.TITLE

func _start_run() -> void:
	run_seed = randi()
	sim.setup(run_seed)
	day_number = 1
	day_start_heat = 0
	best_day_heat = 0
	time_left = Defs.DAY_SECONDS
	player.position = Vector2(sim.core_cell) * float(Defs.TILE) + Vector2(Defs.TILE * 0.5, Defs.TILE * 4.5)
	player.warmth = 100.0
	player.locked = false
	player.velocity = Vector2.ZERO
	rescue_timer = -1.0
	night_warned = false
	rescued_tonight = false
	selected_index = 0
	shake = 0.0
	message = ""
	message_life = 0.0

## A single line that always names the next useful action. Derived from world
## state rather than a script, so it stays correct however the player plays.
func objective() -> String:
	if is_night():
		return "밤입니다  숙소로 돌아가 Z로 취침하세요  (기지 옆 남서쪽)"
	if is_dusk():
		return "해가 기울고 있습니다  곧 숙소로 돌아가야 합니다"
	if sim.machine_count(Defs.M_MINER) == 0:
		return "1  광맥 위에 채굴 고양이를 설치하세요  (1 선택 → R 로 코어 방향 → Z)"
	if sim.total_heat == 0:
		return "2  벨트로 채굴 고양이와 코어를 이으세요  (2 선택 → Z)"
	if sim.delivered.get(Defs.ITEM_EMBER, 0) == 0 and sim.machine_count(Defs.M_FURNACE) == 0:
		return "3  열을 모아 온기를 넓히고 잉걸광석까지 닿으세요"
	if sim.machine_count(Defs.M_FURNACE) == 0:
		return "4  제련로에 서리광석과 잉걸광석을 함께 넣어 합금을 만드세요"
	if sim.delivered.get(Defs.ITEM_ALLOY, 0) == 0:
		return "5  제련로 출력을 코어까지 이으세요"
	return "남은 시간 동안 생산을 늘리세요"

func selected_type() -> int:
	return Defs.BUILDABLE[selected_index]

func day_fraction() -> float:
	return clampf(1.0 - time_left / Defs.DAY_SECONDS, 0.0, 1.0)

func is_night() -> bool:
	return time_left <= Defs.NIGHT_SECONDS

func is_dusk() -> bool:
	return time_left <= Defs.DUSK_SECONDS

func shelter_position() -> Vector2:
	return Vector2(sim.core_cell) * float(Defs.TILE) + Defs.SHELTER_OFFSET * float(Defs.TILE)

func shelter_nearby() -> bool:
	return player.global_position.distance_to(shelter_position()) <= Defs.SHELTER_REACH

func _process(delta: float) -> void:
	var view := _view_rect()
	world_layer.set_view(view)
	world_layer.night = day_fraction()
	ground_layer.night = day_fraction()
	ground_layer.view_rect = view
	cold_fog.view_rect = view
	cold_fog.night = day_fraction()
	machine_layer.view_rect = view
	machine_layer.night = day_fraction()

	message_life = maxf(0.0, message_life - delta)
	if shake > 0.0:
		shake = maxf(0.0, shake - SHAKE_DECAY * delta)
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		camera.offset = Vector2.ZERO

	# The title is a hero shot: no player, no placement ghost, nothing that reads
	# as leftover debug UI in the one frame that sells the game.
	var in_run: bool = state != State.TITLE
	player.visible = in_run
	machine_layer.show_preview = state == State.PLAY

	match state:
		State.PLAY: _process_play(delta)
		State.TITLE: pass
		State.PAUSED, State.RESULT: pass

func _process_play(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	sim.tick(delta)
	_update_warmth(delta)
	_update_preview()
	if not night_warned and is_night():
		night_warned = true
		_notify("밤이 옵니다 — 숙소로 돌아가 Z로 취침하세요", Defs.COL_DANGER)
		audio.call("play", "alarm")
	# Running out of night entirely means the cats come and get you.
	if time_left <= 0.0:
		_carried_home()

func _update_warmth(delta: float) -> void:
	if rescue_timer >= 0.0:
		rescue_timer -= delta
		if rescue_timer <= 0.0:
			_complete_rescue()
		return
	var warm: bool = sim.is_warm(player.cell())
	if warm and not is_night():
		player.warmth = minf(100.0, player.warmth + Defs.COLD_RECOVER * delta)
	elif warm:
		# The core still helps at night, but it no longer keeps you alive: this is
		# what makes going indoors a decision rather than an option.
		var shelter_help: float = 0.35 if shelter_nearby() else 1.0
		player.warmth = maxf(0.0, player.warmth - Defs.NIGHT_DRAIN * shelter_help * delta)
		if player.warmth <= 0.0:
			_carried_home()
	else:
		var night_extra: float = Defs.NIGHT_DRAIN if is_night() else 0.0
		player.warmth = maxf(0.0, player.warmth - (Defs.COLD_DRAIN + night_extra) * delta)
		if player.warmth <= 0.0:
			if is_night():
				_carried_home()
			else:
				_begin_rescue()

func _begin_rescue() -> void:
	rescue_timer = RESCUE_SECONDS
	player.locked = true
	player.velocity = Vector2.ZERO
	shake = 5.0
	var lost: int = sim.spend_rescue()
	_notify("동상! 열 %d 손실" % lost, Defs.COL_DANGER)
	fx.ring(player.position, Defs.COL_DANGER, 44.0)
	audio.call("play", "alarm")

func _complete_rescue() -> void:
	rescue_timer = -1.0
	player.locked = false
	player.warmth = 65.0
	player.position = Vector2(sim.core_cell) * float(Defs.TILE) + Vector2(0, Defs.TILE * 2)
	fx.ring(player.position, Defs.COL_CORE, 40.0)

func _update_preview() -> void:
	var cell: Vector2i = player.facing_cell()
	machine_layer.preview_cell = cell
	machine_layer.preview_type = selected_type()
	machine_layer.preview_dir = build_dir
	var reason: String = sim.can_build(selected_type(), cell)
	machine_layer.preview_valid = reason == ""
	machine_layer.preview_affordable = sim.heat >= Defs.MACHINE_COSTS[selected_type()]
	machine_layer.preview_occupied = sim.machine_at(cell) != null

func _view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / maxf(camera.zoom.x, 0.01)
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	match state:
		State.TITLE:
			if key.keycode == KEY_ESCAPE:
				return
			state = State.PLAY
			audio.call("play", "confirm")
			get_viewport().set_input_as_handled()
			return
		State.RESULT:
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
				_begin_next_day()
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_N:
				_start_run()
				state = State.PLAY
				audio.call("play", "confirm")
				get_viewport().set_input_as_handled()
			return
		State.PAUSED:
			if key.keycode == KEY_ESCAPE:
				state = State.PLAY
				audio.call("play", "confirm")
				get_viewport().set_input_as_handled()
			return

	if key.keycode == KEY_ESCAPE:
		state = State.PAUSED
		audio.call("play", "confirm")
		get_viewport().set_input_as_handled()
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + Defs.BUILDABLE.size():
		selected_index = key.keycode - KEY_1
		audio.call("play", "select")
		get_viewport().set_input_as_handled()
		return
	# Test the event itself rather than the Input singleton. is_action_just_pressed
	# is frame-scoped, so inside an event handler it can silently drop a press
	# when two arrive in one frame -- which reads to the player as a dead key.
	if event.is_action_pressed("rotate"):
		build_dir = Vector2i(-build_dir.y, build_dir.x)
		audio.call("play", "select")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build"):
		if sleep_available():
			_sleep()
		else:
			_try_build()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("demolish"):
		_try_demolish()
		get_viewport().set_input_as_handled()

## Entry points for the mobile buttons, so touch and keyboard run through the
## same code rather than drifting apart.
func touch_primary() -> void:
	match state:
		State.TITLE:
			state = State.PLAY
			audio.call("play", "confirm")
		State.RESULT:
			_begin_next_day()
		State.PAUSED:
			state = State.PLAY
		State.PLAY:
			if sleep_available():
				_sleep()
			else:
				_try_build()

func touch_secondary() -> void:
	match state:
		State.PLAY:
			_try_demolish()
		State.PAUSED:
			state = State.PLAY

func _try_build() -> void:
	if player.locked:
		return
	var cell: Vector2i = player.facing_cell()
	var type: int = selected_type()
	if sim.build(type, cell, build_dir):
		var at: Vector2 = Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
		fx.ring(at, Defs.machine_color(type), 22.0)
		fx.burst(at, Defs.machine_color(type), 6)
		shake = maxf(shake, 1.6)
		audio.call("play", "build")

func _try_demolish() -> void:
	if player.locked:
		return
	var cell: Vector2i = player.facing_cell()
	if sim.demolish(cell):
		var at: Vector2 = Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
		fx.burst(at, Defs.COL_TEXT_DIM, 5)
		audio.call("play", "remove")
	else:
		_notify("회수할 설비가 없습니다", Defs.COL_TEXT_DIM)

func _on_heat_gained(amount: int, cell: Vector2i, item_type: int) -> void:
	var at: Vector2 = Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
	fx.popup(at, "+%d" % amount, Defs.ITEM_COLORS[item_type])
	fx.ring(at, Defs.COL_CORE, 18.0)
	shake = maxf(shake, 0.9 if item_type != Defs.ITEM_ALLOY else 3.0)
	audio.call("play", "alloy" if item_type == Defs.ITEM_ALLOY else "deliver")

func _on_build_rejected(reason: String, cell: Vector2i) -> void:
	# One channel only. Showing the same reason both here and in the centre
	# banner produced two overlapping copies of the same string.
	fx.popup(Vector2(cell) * float(Defs.TILE) + Vector2(Defs.TILE * 0.5, -8.0), reason,
		Color8(255, 154, 143), true)
	fx.ring(Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5, Defs.COL_DANGER, 14.0)
	audio.call("play", "deny")

func _on_warmth_changed(radius: float) -> void:
	if state != State.PLAY:
		return
	# The panel already carries this number. Printing it in the world drew it
	# straight across the core at 1.22:1, defacing the one hero object.
	fx.ring(Vector2(sim.core_cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5,
		Defs.COL_CORE, radius * float(Defs.TILE) * 0.12)

func _notify(text: String, color: Color) -> void:
	message = text
	message_life = 2.0
	hud.set("message_color", color)

func day_heat() -> int:
	return sim.total_heat - day_start_heat

## Falling asleep outside: the cats bring you in, and the night ends anyway, but
## the day is scored as it stood.
func _carried_home() -> void:
	rescued_tonight = true
	_sleep()

func sleep_available() -> bool:
	return state == State.PLAY and is_night() and shelter_nearby()

func _sleep() -> void:
	if state != State.PLAY:
		return
	player.locked = true
	player.velocity = Vector2.ZERO
	player.position = shelter_position()
	audio.call("play", "confirm")
	fx.ring(shelter_position(), Defs.COL_CORE, 52.0)
	_finish_run()

## Dusk, not game over. The factory keeps everything it built.
func _finish_run() -> void:
	state = State.RESULT
	best_heat = maxi(best_heat, sim.total_heat)
	best_day_heat = maxi(best_day_heat, day_heat())
	player.locked = true
	shake = 4.0
	audio.call("play", "finish")

func _begin_next_day() -> void:
	day_number += 1
	day_start_heat = sim.total_heat
	time_left = Defs.DAY_SECONDS
	night_warned = false
	rescued_tonight = false
	player.locked = false
	player.warmth = 100.0
	# Morning starts at the shelter beside the core, as it does in Motorio.
	player.position = Vector2(sim.core_cell) * float(Defs.TILE) + Vector2(Defs.TILE * 0.5, Defs.TILE * 2.5)
	state = State.PLAY
	_notify("%d일차 아침" % day_number, Defs.COL_CORE)
	fx.ring(player.position, Defs.COL_CORE, 46.0)
	audio.call("play", "confirm")
