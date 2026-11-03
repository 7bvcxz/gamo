class_name DollRig
extends Node2D

## One clockwork doll as a cut-out rig: SVG parts on pivots, posed by a
## handful of angles. The parts are one atlas (assets/art/doll/atlas.svg, built
## from art/svg/doll/ by tools/art/build_doll_atlas.mjs) so a doll's sprites
## batch into a few draw calls. The wake-up is a timeline through four
## key poses -- asleep, stirring, awake, stretch -- interpolated here, frame by
## frame, from `advance(dt)`; nothing runs on its own clock, so a test or a
## capture steps it exactly.
##
## Origin: between the feet, on the floor. Faces right. Parts are imported at
## twice their SVG size (crisp when the window is larger than 1280x720) and
## drawn at half scale.

const ATLAS := "res://assets/art/doll/atlas.svg"
const ATLAS_JSON := "res://assets/art/doll/atlas.json"
const TEX_SCALE := 2.0
## Eye places in head.svg pixels: [centre, scale] (near eye, far eye).
const EYES := [[Vector2(40, 31), 1.0], [Vector2(51, 30), 0.75]]
const EYE_PIVOT := Vector2(8, 6)

static var _atlas: Texture2D
static var _rects: Dictionary = {}

## Pivots in SVG (1x) pixels -- the numbers written in each SVG's comment.
const PIVOT := {
	"head": Vector2(30, 60), "torso_hip": Vector2(26, 60), "torso_neck": Vector2(26, 4),
	"torso_shoulder": Vector2(24, 12), "torso_key": Vector2(8, 30),
	"arm": Vector2(10, 6), "leg": Vector2(11, 4), "back_key": Vector2(24, 14),
}
const LEG_LENGTH := 52.0
const SIT_HIP := 12.0

## Key poses. Angles in degrees (Godot: positive = clockwise; for this rig
## positive leans forward/down). `eyes`: 0 closed, 0.5 half, 1 open.
const POSES := {
	"asleep": {"hip": SIT_HIP, "legs": -84.0, "torso": 24.0, "head": 34.0, "arm_near": 14.0, "arm_far": 8.0, "eyes": 0.0},
	"stirring": {"hip": SIT_HIP, "legs": -84.0, "torso": 10.0, "head": -6.0, "arm_near": 4.0, "arm_far": 2.0, "eyes": 0.45},
	"awake": {"hip": SIT_HIP, "legs": -84.0, "torso": -2.0, "head": -10.0, "arm_near": -24.0, "arm_far": -12.0, "eyes": 1.0},
	"stretch": {"hip": LEG_LENGTH, "legs": 0.0, "torso": -10.0, "head": -20.0, "arm_near": -128.0, "arm_far": -150.0, "eyes": 1.0},
	"stand": {"hip": LEG_LENGTH, "legs": 0.0, "torso": 0.0, "head": -4.0, "arm_near": -6.0, "arm_far": 4.0, "eyes": 1.0},
}
## The wake-up: [time, pose]. Holds and moves, ~1.6 s in all (H7: 1.5 s).
const WAKE := [[0.0, "asleep"], [0.35, "stirring"], [0.7, "awake"], [1.1, "stretch"], [1.6, "stand"]]
## Variant B's reveal (3.2 s): wakes, looks out at the player, then its own gesture.
const GESTURE_POSES := {
	"look": {"hip": SIT_HIP, "legs": -84.0, "torso": -6.0, "head": -22.0, "arm_near": -20.0, "arm_far": -10.0, "eyes": 1.0},
	"wave_up": {"hip": LEG_LENGTH, "legs": 0.0, "torso": -4.0, "head": -12.0, "arm_near": -165.0, "arm_far": 6.0, "eyes": 1.0},
	"wave_down": {"hip": LEG_LENGTH, "legs": 0.0, "torso": -4.0, "head": -12.0, "arm_near": -125.0, "arm_far": 6.0, "eyes": 1.0},
	"bow": {"hip": LEG_LENGTH, "legs": 0.0, "torso": 38.0, "head": 18.0, "arm_near": 30.0, "arm_far": 20.0, "eyes": 0.45},
	"cheer": {"hip": LEG_LENGTH, "legs": 0.0, "torso": -10.0, "head": -22.0, "arm_near": -150.0, "arm_far": -150.0, "eyes": 1.0},
	"hop": {"hip": LEG_LENGTH + 16.0, "legs": 12.0, "torso": -6.0, "head": -14.0, "arm_near": -60.0, "arm_far": -60.0, "eyes": 1.0},
	"salute": {"hip": LEG_LENGTH, "legs": 0.0, "torso": -3.0, "head": -8.0, "arm_near": -158.0, "arm_far": 4.0, "eyes": 1.0},
}
const GESTURES := [["wave_up", "wave_down"], ["bow", "stand"], ["cheer", "stand"], ["hop", "stand"], ["salute", "stand"]]
## Variant B's hats, one per doll (cycled): drawn on the head in head.svg pixels.
const HATS := ["top_hat", "beret", "flower", "bow", "crown", "cap"]

var pose: Dictionary = POSES["asleep"].duplicate()
var pose_name: String = "asleep"
var waking: bool = false
var wake_time: float = 0.0
var key_spin: float = 0.0
## What an awake doll is doing: "idle", "walk", "wind" (turning another doll's
## key), "work" (at its own place). Layered on the "stand" pose.
var activity: String = "idle"
## 1 faces right, -1 faces left (the whole rig is mirrored).
var facing: int = 1:
	set(v):
		facing = 1 if v >= 0 else -1
		scale.x = absf(scale.x) * facing
var vest_tint: Color = Color.WHITE
## B: a hat on the head ("" none) and the reveal gesture (index into GESTURES, -1 plain wake).
var hat: String = ""
var gesture: int = -1
var _timeline: Array = WAKE
var _quirk_name: String = ""
var _quirk_t: float = 0.0
var _quirk_len: float = 1.0
## 0..1 while asleep: how close it is to waking -- its eyes flutter open.
var flutter: float = 0.0
var _phase: float = 0.0

var _parts: Dictionary = {}
var _hip: Node2D
var _torso: Node2D
var _head: Node2D
var _eyes: Node2D
var _arm_near: Node2D
var _arm_far: Node2D
var _leg_near: Node2D
var _leg_far: Node2D
var _back_key: Node2D


static func art_present() -> bool:
	return ResourceLoader.exists(ATLAS) and FileAccess.file_exists(ATLAS_JSON)


static func _load_atlas() -> void:
	if _atlas != null:
		return
	_atlas = load(ATLAS)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_JSON))
	var parts: Dictionary = data["parts"]
	for name: String in parts:
		var r: Array = parts[name]
		_rects[name] = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _ready() -> void:
	_load_atlas()
	_hip = Node2D.new()
	add_child(_hip)
	_leg_far = _joint(_hip, "leg", Vector2(-3, 0), Color(0.72, 0.72, 0.78))
	_torso = _joint(_hip, "torso", Vector2.ZERO, Color.WHITE, PIVOT["torso_hip"])
	_back_key = _joint(_torso, "back_key", _local(PIVOT["torso_key"] - PIVOT["torso_hip"]), Color.WHITE)
	_arm_far = _joint(_torso, "arm", _local(PIVOT["torso_shoulder"] - PIVOT["torso_hip"]) + Vector2(-3, 0), Color(0.72, 0.72, 0.78))
	# The far arm and the back key are behind the torso's picture.
	_torso.move_child(_arm_far, 0)
	_torso.move_child(_back_key, 0)
	_head = _joint(_torso, "head", _local(PIVOT["torso_neck"] - PIVOT["torso_hip"]), Color.WHITE)
	_attach_hat()
	_eyes = Node2D.new()
	_head.add_child(_eyes)
	_eyes.position = _local(-PIVOT["head"])
	for e: Array in EYES:
		var holder := Node2D.new()
		holder.position = e[0]
		holder.scale = Vector2.ONE * float(e[1])
		_eyes.add_child(holder)
		for frame: String in ["eye_closed", "eye_half", "eye_open"]:
			holder.add_child(_sprite(frame, EYE_PIVOT, Color.WHITE))
	_leg_near = _joint(_hip, "leg", Vector2(3, 0), Color.WHITE)
	_arm_near = _joint(_torso, "arm", _local(PIVOT["torso_shoulder"] - PIVOT["torso_hip"]) + Vector2(2, 0), Color.WHITE)
	for c in _torso.get_children():
		if c is Sprite2D:
			(c as Sprite2D).modulate = vest_tint
	_apply()


## A part: a Node2D at `at` (its joint) holding the texture with its pivot on
## the node's origin.
func _joint(parent: Node, part: String, at: Vector2, tint: Color, pivot: Vector2 = Vector2.INF) -> Node2D:
	var joint := Node2D.new()
	joint.position = at
	parent.add_child(joint)
	var sprite := _sprite(part, pivot if pivot != Vector2.INF else PIVOT[part], tint)
	joint.add_child(sprite)
	_parts[part + str(_parts.size())] = sprite
	return joint


## A sprite of one atlas part with `pivot` (SVG pixels) on its origin.
func _sprite(part: String, pivot: Vector2, tint: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _atlas
	sprite.region_enabled = true
	var r: Rect2 = _rects[part]
	sprite.region_rect = Rect2(r.position * TEX_SCALE, r.size * TEX_SCALE)
	sprite.centered = false
	sprite.scale = Vector2.ONE / TEX_SCALE
	sprite.offset = -pivot * TEX_SCALE
	sprite.modulate = tint
	return sprite


## SVG pixels -> this rig's units (the same at 1x).
static func _local(v: Vector2) -> Vector2:
	return v


func set_pose(name: String) -> void:
	pose = POSES[name].duplicate()
	pose_name = name
	waking = false
	_apply()


func start_wake() -> void:
	set_pose("asleep")
	waking = true
	wake_time = 0.0
	_timeline = WAKE if gesture < 0 else reveal_timeline(gesture)


## B: asleep -> stirring -> awake -> looks at the player -> its gesture twice -> stands.
static func reveal_timeline(g: int) -> Array:
	var pair: Array = GESTURES[g % GESTURES.size()]
	return [[0.0, "asleep"], [0.6, "stirring"], [1.1, "awake"], [1.5, "look"], [1.95, pair[0]],
		[2.35, pair[1]], [2.75, pair[0]], [3.2, "stand"]]


func wake_length() -> float:
	return float(_timeline[_timeline.size() - 1][0])


func advance(dt: float) -> void:
	_phase += dt
	if waking:
		wake_time += dt
		pose = _timeline_pose(_timeline, wake_time)
		if wake_time >= wake_length():
			waking = false
			pose_name = "stand"
			pose = POSES["stand"].duplicate()
	elif pose_name == "stand":
		pose = _activity_pose(activity, _phase)
		if _quirk_t > 0.0:
			_quirk_t = maxf(0.0, _quirk_t - dt)
			var env := sin(PI * (1.0 - _quirk_t / _quirk_len))
			var q: Dictionary = _named(_quirk_name)
			# Upper body only: a standing doll stays on its feet.
			for key: String in ["torso", "head", "arm_near", "arm_far"]:
				pose[key] = lerpf(float(pose[key]), float(q[key]), env * 0.9)
	key_spin += dt * (6.0 if pose_name == "stand" or waking else 0.0)
	_apply()
	if pose_name == "asleep" and _hip != null:
		# Sleeping, it breathes: the slump rises and falls a little.
		_torso.rotation_degrees = float(pose["torso"]) + sin(_phase * 1.6) * 2.0


## A short temperament gesture over whatever the doll is doing (upper body).
func play_quirk(name: String, seconds: float) -> void:
	if not (POSES.has(name) or GESTURE_POSES.has(name)):
		return
	_quirk_name = name
	_quirk_len = maxf(0.1, seconds)
	_quirk_t = _quirk_len


func awake_now() -> bool:
	return pose_name == "stand" and not waking


## The stand pose with the activity's motion on top.
static func _activity_pose(what: String, t: float) -> Dictionary:
	var p: Dictionary = POSES["stand"].duplicate()
	match what:
		"walk":
			var sw := sin(t * 9.0)
			p["legs"] = sw * 22.0
			p["arm_near"] = -sw * 18.0
			p["arm_far"] = sw * 18.0
			p["torso"] = 4.0
		"wind":
			# Both hands forward on another doll's key, turning it.
			p["arm_near"] = -88.0 + sin(t * 7.0) * 26.0
			p["arm_far"] = -80.0 + sin(t * 7.0 + 1.2) * 20.0
			p["torso"] = 8.0
			p["head"] = 6.0
		"work":
			p["arm_near"] = -50.0 + sin(t * 5.0) * 30.0
			p["torso"] = 4.0 + sin(t * 2.5) * 3.0
			p["head"] = 8.0 + sin(t * 2.5) * 4.0
		_:
			p["torso"] = sin(t * 1.3) * 2.0
			p["head"] = -4.0 + sin(t * 0.9) * 5.0
	return p


var _hat_node: Node2D


## B: puts a hat on (or takes it off with ""), before or after the rig is built.
func set_hat(name: String) -> void:
	hat = name
	if _head != null:
		_attach_hat()


func _attach_hat() -> void:
	if _hat_node != null:
		_hat_node.queue_free()
		_hat_node = null
	if hat == "":
		return
	_hat_node = Node2D.new()
	_hat_node.position = _local(-PIVOT["head"])
	_hat_node.draw.connect(_draw_hat.bind(_hat_node))
	_head.add_child(_hat_node)


## B's hats, in head.svg pixels (the face looks right; the crown of the head is near (32, 10)).
func _draw_hat(c: Node2D) -> void:
	var tint := vest_tint
	match hat:
		"top_hat":
			c.draw_rect(Rect2(14, 6, 36, 5), Color(0.12, 0.1, 0.12))
			c.draw_rect(Rect2(20, -16, 24, 23), Color(0.15, 0.12, 0.15))
			c.draw_rect(Rect2(20, -2, 24, 4), Color(0.6, 0.2, 0.25))
		"beret":
			c.draw_colored_polygon(PackedVector2Array([Vector2(12, 12), Vector2(20, 2), Vector2(38, -1), Vector2(52, 6), Vector2(50, 12)]), Color(0.25, 0.3, 0.55) * tint)
			c.draw_circle(Vector2(34, -2), 2.5, Color(0.25, 0.3, 0.55))
		"flower":
			for k in 5:
				c.draw_circle(Vector2(46, 10) + Vector2.from_angle(TAU * k / 5.0) * 4.5, 3.4, Color(1.0, 0.75, 0.85))
			c.draw_circle(Vector2(46, 10), 2.6, Color(1.0, 0.85, 0.3))
		"bow":
			c.draw_colored_polygon(PackedVector2Array([Vector2(26, 6), Vector2(16, 0), Vector2(16, 12)]), Color(0.9, 0.3, 0.35))
			c.draw_colored_polygon(PackedVector2Array([Vector2(26, 6), Vector2(36, 0), Vector2(36, 12)]), Color(0.9, 0.3, 0.35))
			c.draw_circle(Vector2(26, 6), 3.0, Color(0.75, 0.2, 0.25))
		"crown":
			c.draw_colored_polygon(PackedVector2Array([Vector2(18, 10), Vector2(18, -2), Vector2(24, 4), Vector2(31, -6), Vector2(38, 4), Vector2(44, -2), Vector2(44, 10)]), Color(0.98, 0.78, 0.3))
			c.draw_circle(Vector2(31, 4), 2.2, Color(0.8, 0.2, 0.3))
		"cap":
			c.draw_colored_polygon(PackedVector2Array([Vector2(12, 12), Vector2(16, 0), Vector2(34, -3), Vector2(50, 4), Vector2(62, 10), Vector2(48, 12)]), Color(0.75, 0.55, 0.3) * tint)


## Where the doll's own wind-up key is (for the fill ring).
func back_key_global() -> Vector2:
	if _back_key == null:
		return global_position
	return _back_key.get_global_transform() * Vector2(-6, 0)


## The pose at time `t` of the wake-up timeline (smoothstep between keys).
static func _wake_pose(t: float) -> Dictionary:
	return _timeline_pose(WAKE, t)


static func _named(name: String) -> Dictionary:
	return POSES[name] if POSES.has(name) else GESTURE_POSES[name]


static func _timeline_pose(tl: Array, t: float) -> Dictionary:
	for i in tl.size() - 1:
		var a: Array = tl[i]
		var b: Array = tl[i + 1]
		if t <= float(b[0]):
			var k := smoothstep(float(a[0]), float(b[0]), t)
			return _blend(_named(a[1]), _named(b[1]), k)
	return _named(tl[tl.size() - 1][1]).duplicate()


static func _blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key: String in a:
		out[key] = lerpf(float(a[key]), float(b[key]), k)
	return out


func _apply() -> void:
	if _hip == null:
		return
	_hip.position = Vector2(0, -float(pose["hip"]))
	_leg_near.rotation_degrees = float(pose["legs"])
	_leg_far.rotation_degrees = float(pose["legs"])
	_torso.rotation_degrees = float(pose["torso"])
	_head.rotation_degrees = float(pose["head"])
	_arm_near.rotation_degrees = float(pose["arm_near"])
	_arm_far.rotation_degrees = float(pose["arm_far"])
	_back_key.rotation = key_spin
	var o := float(pose["eyes"])
	if pose_name == "asleep" and not waking and flutter > 0.0 and sin(_phase * 9.0) > 1.0 - flutter * 0.7:
		o = 0.45
	var frame := 0 if o < 0.2 else (1 if o < 0.75 else 2)
	for holder in _eyes.get_children():
		for i in holder.get_child_count():
			(holder.get_child(i) as Sprite2D).visible = i == frame


## Where the top of the head is now (for tests: asleep is lower than standing).
func head_top() -> Vector2:
	return _head.get_global_transform() * Vector2(0, -50)
