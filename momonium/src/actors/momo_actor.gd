class_name MomoActor
extends Node2D

## One Momo on the island: the rig standing where the simulation says, walking
## when the simulation has it walking (facing the way it goes), sitting now and
## then, asleep at night. While dragged it hangs from the finger above its
## shadow. Owns no game state.

const LIFT := 26.0
## The body a tap finds and the HUD makes room for, from the feet, for a
## Momo of size 1 (MomoRig.HEIGHT): a little past its sides, its fur curl and
## its feet. Scaled by `size`.
const BODY := Rect2(-26, -76, 52, 80)
## Step 68: its tool landed (the rig's contact frame), while it was seen.
signal struck(momo: int, pose: String)
## The pose a shown mood puts an idle Momo in (Step 51; the bubble stays).
const MOOD_POSE := {"content": "happy", "thinking": "waiting", "confused": "confused", "worried": "confused"}

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
## How far below its feet this node sits for the depth sort (Step 55,
## MomoViews): everything it draws is lifted back by as much, so the Momo is
## seen -- and tapped -- exactly where it stands.
var depth_lift := 0.0
var _marked := true
## The one mood over its head when it is not at work (Step 48).
var mood_bubble: MoodBubble
var _mood_reason := ""
## Step 77: how big it is drawn (`art.momo_size.scale`, 0.8): read once here,
## handed to the rig (which scales about the feet) and the bubble, and used
## for all that follows the body -- the tap box, the ring, the hop.
var size := 1.0
## Island pixels a tap may land outside the body and still find it.
var hit_slack := 4.0


func setup(p_id: int, sim: Simulation, lib: SpriteLibrary, p_projection: IsoProjection = null) -> void:
	id = p_id
	name = "Momo_%d" % id
	momos = sim.system(&"momo")
	cycle = DayCycle.new(sim.data)
	clock = sim.clock
	projection = p_projection
	_rng.seed = id * 7919
	_next_sit = _rng.randf_range(8.0, 16.0)
	size = sim.data.get_float("art", "momo_size.scale", 1.0)
	hit_slack = sim.data.get_float("art", "momo_size.hit_slack", 4.0)
	rig = MomoRig.new()
	rig.setup(lib, id)
	rig.size = size
	add_child(rig)
	rig.struck.connect(func(pose: String) -> void: struck.emit(id, pose))
	mood_bubble = MoodBubble.new()
	mood_bubble.setup(lib)
	mood_bubble.size = size
	add_child(mood_bubble)


## Whether the simulation has this Momo doing its building's current stage.
func is_working() -> bool:
	var b := int(momos.get_momo(id).get("assigned", 0))
	if b == 0:
		return false
	var rec := (momos.sim.system(&"buildings") as BuildingSystem).get_building(b)
	return not rec.is_empty() and rec["state"] == BuildingSystem.WORKING and int(rec.get("worker", 0)) == id


## The work animation for the stage it is doing (Step 66): the stage's
## action -- sow, water, harvest, dig, chop, replant, study, smelt, stoke,
## assemble, design... -- looked up in the work atlas's `actions`, each a
## Momo holding that job's tool. "" works back turned.
func work_pose() -> String:
	var bs: BuildingSystem = momos.sim.system(&"buildings")
	var rec := bs.get_building(int(momos.get_momo(id).get("assigned", 0)))
	if rec.is_empty():
		return ""
	var stage := bs.current_stage(rec)
	return rig.sheet.work_animation(String(stage.get("action", stage.get("id", ""))))


## Its body as drawn, from its feet (island pixels): BODY at its size.
func body() -> Rect2:
	return Rect2(BODY.position * size, BODY.size * size)


## World-space box a tap or a drag can grab: the body, `hit_slack` wider at
## the sides and over the head. Not under the feet: there is only the shadow,
## and the tile it stands on (a tap there is for the building).
func hit_rect() -> Rect2:
	var b := body()
	return Rect2(ground() + b.position, b.size).grow_individual(hit_slack, hit_slack, hit_slack, 0.0)


## Where it stands (its feet, in the layer), the sort's lift taken off.
func ground() -> Vector2:
	return position - Vector2(0, depth_lift)


## Out of sight it stops animating -- its body and its letter -- until seen.
func set_awake(on: bool) -> void:
	if is_processing() == on:
		return
	set_process(on)
	rig.set_process(on)


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
		rig.position = Vector2(0, -LIFT - depth_lift)
	else:
		rig.walk_speed = 1.0
		rig.position = Vector2(sin(_shake * 40.0) * 4.0 * _shake * size, -sin(_pop * PI) * 18.0 * size - depth_lift)
		if momos.is_moving(id):
			rig.set_state("walk")
			var h := momos.heading(id)
			rig.face(projection.to_screen(h) - projection.to_screen(Vector2.ZERO))
		elif is_working():
			rig.set_state("work")
			rig.work_pose = work_pose()
			rig.face(Vector2(-1, -0.4))
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
	# Step 57: no letter over its head -- a new letter is the mailbox's news
	# alone; over a Momo there is only its mood.
	if mood_bubble.due(delta):
		_mood_reason = MomoMood.reason(momos.sim, id)
	mood_bubble.step(delta, _mood_reason, dragged, rig.position)
	rig.mood_pose = String(MOOD_POSE.get(mood_bubble.mood, ""))
	# Its own drawing is the selection ring: redrawn while it shows, and once
	# more to clear it.
	var marks := selected or dragged
	if marks or _marked:
		queue_redraw()
	_marked = marks


func _draw() -> void:
	if selected or dragged:
		draw_set_transform(Vector2(0, 2.0 * size - depth_lift), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 30.0 * size, 0, TAU, 32, Color(1, 0.92, 0.45, 0.95), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
