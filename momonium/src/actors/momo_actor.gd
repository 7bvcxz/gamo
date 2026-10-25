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
var mail: MailSystem
## A letter held up over the head while one this Momo wrote is unread -- the
## mailbox's red dot, but on the island, at the Momo who is waiting.
var envelope: Sprite2D
var _marked := true
## The one mood over its head when it is not at work (Step 48).
var mood_bubble: MoodBubble
var _mood_reason := ""


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
	mail = sim.system(&"mail")
	envelope = Sprite2D.new()
	envelope.name = "Envelope"
	lib.place(envelope, "ui_mail")
	envelope.centered = true
	envelope.offset = Vector2.ZERO
	envelope.scale = Vector2.ONE * (26.0 / maxf(lib.region("ui_mail").size.x, 1.0))
	envelope.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The HUD icon is drawn white for navy buttons; ink it for the white bubble.
	envelope.modulate = Color(0.25, 0.45, 0.8)
	envelope.visible = false
	add_child(envelope)
	mood_bubble = MoodBubble.new()
	mood_bubble.setup(lib)
	add_child(mood_bubble)


## Whether the simulation has this Momo doing its building's current stage.
func is_working() -> bool:
	var b := int(momos.get_momo(id).get("assigned", 0))
	if b == 0:
		return false
	var rec := (momos.sim.system(&"buildings") as BuildingSystem).get_building(b)
	return not rec.is_empty() and rec["state"] == BuildingSystem.WORKING and int(rec.get("worker", 0)) == id


## World-space box a tap or a drag can grab.
func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-26, -76), Vector2(52, 80))


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
		rig.position = Vector2(0, -LIFT)
	else:
		rig.walk_speed = 1.0
		rig.position = Vector2(sin(_shake * 40.0) * 4.0 * _shake, -sin(_pop * PI) * 18.0)
		if momos.is_moving(id):
			rig.set_state("walk")
			var h := momos.heading(id)
			rig.face(projection.to_screen(h) - projection.to_screen(Vector2.ZERO))
		elif is_working():
			rig.set_state("work")
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
	envelope.visible = mail != null and mail.has_unread_from(id) and not dragged
	if envelope.visible:
		envelope.position = rig.position + Vector2(-26, -96 + sin(t * 3.0) * 3.0)
		envelope.rotation = sin(t * 2.2) * 0.12
	if mood_bubble.due(delta):
		_mood_reason = MomoMood.reason(momos.sim, id)
	mood_bubble.step(delta, _mood_reason, envelope.visible or dragged, rig.position)
	# Its own drawing is the letter's bubble and the selection ring: redrawn
	# while either shows, and once more to clear it.
	var marks := envelope.visible or selected or dragged
	if marks or _marked:
		queue_redraw()
	_marked = marks


func _draw() -> void:
	if envelope != null and envelope.visible:
		# A white speech bubble under the letter, so it reads on any ground.
		var c := envelope.position
		draw_circle(c, 19.0, Color(1, 1, 1, 0.92))
		draw_colored_polygon(PackedVector2Array([c + Vector2(8, 14), c + Vector2(20, 26), c + Vector2(14, 10)]), Color(1, 1, 1, 0.92))
		draw_arc(c, 19.0, 0, TAU, 32, Color(0.35, 0.55, 0.85, 0.6), 1.5, true)
	if selected or dragged:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(1, 0.92, 0.45, 0.95), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
