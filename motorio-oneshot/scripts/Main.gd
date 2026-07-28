extends Node2D

## Orchestrator: owns game state, input routing, camera and the run timer.
## Simulation lives in Sim, drawing lives in the layers, so this file stays thin.

enum State { TITLE, PLAY, PAUSED, RESULT }

const SHAKE_DECAY := 7.0
const RESCUE_SECONDS := 1.6

@onready var sim: Sim = $Sim
@onready var world_layer: WorldLayer = $World
@onready var machine_layer: MachineLayer = $Machines
@onready var fx: FxLayer = $Fx
@onready var player: PlayerActor = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $UI/HUD
@onready var audio: Node = $Audio

var state: int = State.TITLE
var time_left: float = Defs.DAY_SECONDS
var selected_index: int = 0
var build_dir := Vector2i.RIGHT
var shake: float = 0.0
var rescue_timer: float = -1.0
var run_seed: int = 0
var best_heat: int = 0
var message: String = ""
var message_life: float = 0.0

func _ready() -> void:
	randomize()
	sim.heat_gained.connect(_on_heat_gained)
	sim.build_rejected.connect(_on_build_rejected)
	sim.warmth_changed.connect(_on_warmth_changed)
	world_layer.sim = sim
	machine_layer.sim = sim
	hud.set("main", self)
	_start_run()
	state = State.TITLE

func _start_run() -> void:
	run_seed = randi()
	sim.setup(run_seed)
	time_left = Defs.DAY_SECONDS
	player.position = Vector2(sim.core_cell) * float(Defs.TILE) + Vector2(0, Defs.TILE * 3)
	player.warmth = 100.0
	player.locked = false
	player.velocity = Vector2.ZERO
	rescue_timer = -1.0
	selected_index = 0
	shake = 0.0
	message = ""
	message_life = 0.0

func selected_type() -> int:
	return Defs.BUILDABLE[selected_index]

func day_fraction() -> float:
	return clampf(1.0 - time_left / Defs.DAY_SECONDS, 0.0, 1.0)

func _process(delta: float) -> void:
	var view := _view_rect()
	world_layer.set_view(view)
	world_layer.night = day_fraction()
	machine_layer.view_rect = view

	message_life = maxf(0.0, message_life - delta)
	if shake > 0.0:
		shake = maxf(0.0, shake - SHAKE_DECAY * delta)
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		camera.offset = Vector2.ZERO

	match state:
		State.PLAY: _process_play(delta)
		State.TITLE: _update_preview()
		State.PAUSED, State.RESULT: pass

func _process_play(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	sim.tick(delta)
	_update_warmth(delta)
	_update_preview()
	if time_left <= 0.0:
		_finish_run()

func _update_warmth(delta: float) -> void:
	if rescue_timer >= 0.0:
		rescue_timer -= delta
		if rescue_timer <= 0.0:
			_complete_rescue()
		return
	if sim.is_warm(player.cell()):
		player.warmth = minf(100.0, player.warmth + Defs.COLD_RECOVER * delta)
	else:
		player.warmth = maxf(0.0, player.warmth - Defs.COLD_DRAIN * delta)
		if player.warmth <= 0.0:
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
	machine_layer.preview_valid = sim.can_build(selected_type(), cell) == ""

func _view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / maxf(camera.zoom.x, 0.01)
	return Rect2(player.global_position - size * 0.5, size)

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
	if Input.is_action_just_pressed("rotate"):
		build_dir = Vector2i(-build_dir.y, build_dir.x)
		audio.call("play", "select")
		get_viewport().set_input_as_handled()
		return
	if Input.is_action_just_pressed("build"):
		_try_build()
		get_viewport().set_input_as_handled()
		return
	if Input.is_action_just_pressed("demolish"):
		_try_demolish()
		get_viewport().set_input_as_handled()

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
	_notify(reason, Defs.COL_DANGER)
	fx.ring(Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5, Defs.COL_DANGER, 14.0)
	audio.call("play", "deny")

func _on_warmth_changed(radius: float) -> void:
	if state != State.PLAY:
		return
	_notify("온기 반경 %.1f칸" % radius, Defs.COL_CORE)

func _notify(text: String, color: Color) -> void:
	message = text
	message_life = 2.0
	hud.set("message_color", color)

func _finish_run() -> void:
	state = State.RESULT
	best_heat = maxi(best_heat, sim.total_heat)
	player.locked = true
	shake = 4.0
	audio.call("play", "finish")
