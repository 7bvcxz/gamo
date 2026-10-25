class_name MomoActor
extends Node2D

## One Momo on the island: the rig standing where the simulation says, walking
## when the simulation has it walking (facing the way it goes), sitting now and
## then, asleep at night. While dragged it hangs from the finger above its
## shadow. Owns no game state.

const LIFT := 26.0

var id := 0
var rig: MomoRig
var momos: MomoSystem
var cycle: DayCycle
var clock: SimClock
var projection: IsoProjection
var selected := false:
	set(value):
		selected = value
		queue_redraw()
## While dragged: the world point under the finger.
var dragged := false
var drag_world := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _sit_until := 0.0
var _next_sit := 0.0
var _shake := 0.0
var _pop := 0.0


func setup(p_id: int, sim: Simulation, lib: SpriteLibrary, p_projection: IsoProjection = null) -> void:
	id = p_id
	name = "Momo_%d" % id
	momos = sim.system(&"momo")
	cycle = DayCycle.new(sim.data)
	clock = sim.clock
	projection = p_projection
	_rng.seed = id * 7919
	_next_sit = _rng.randf_range(8.0, 16.0)
	rig = MomoRig.new()
	rig.setup(lib, id)
	add_child(rig)


## World-space box a tap or a drag can grab.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-26, -76), Vector2(52, 80))


func refuse() -> void:
	_shake = 1.0


func appear() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 3.0)
	_pop = maxf(0.0, _pop - delta * 1.5)
	var t := rig.time
	if dragged:
		rig.set_state("walk")
		rig.walk_speed = 2.0
		rig.position = Vector2(0, -LIFT)
	else:
		rig.walk_speed = 1.0
		rig.position = Vector2(sin(_shake * 40.0) * 4.0 * _shake, -sin(_pop * PI) * 18.0)
		if momos.is_moving(id):
			rig.set_state("walk")
			var h := momos.heading(id)
			rig.face(projection.to_screen(h) - projection.to_screen(Vector2.ZERO))
		elif cycle.is_night(clock):
			rig.set_state("sleep")
		elif int(momos.get_momo(id).get("assigned", 0)) != 0:
			rig.set_state("idle")
			rig.face(Vector2(-1, -0.4))
		elif t < _sit_until:
			rig.set_state("sit")
		else:
			rig.set_state("idle")
			if t >= _next_sit:
				_sit_until = t + _rng.randf_range(3.0, 6.0)
				_next_sit = _sit_until + _rng.randf_range(10.0, 20.0)
	queue_redraw()


func _draw() -> void:
	if selected or dragged:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(1, 0.92, 0.45, 0.95), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
