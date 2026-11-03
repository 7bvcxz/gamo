class_name DollRig
extends Node2D

## One clockwork doll as a cut-out rig: SVG parts (assets/art/doll/) on
## pivots, posed by a handful of angles. The wake-up is a timeline through four
## key poses -- asleep, stirring, awake, stretch -- interpolated here, frame by
## frame, from `advance(dt)`; nothing runs on its own clock, so a test or a
## capture steps it exactly.
##
## Origin: between the feet, on the floor. Faces right. Parts are imported at
## twice their SVG size (crisp when the window is larger than 1280x720) and
## drawn at half scale.

const ART := "res://assets/art/doll/"
const TEX_SCALE := 2.0

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

var pose: Dictionary = POSES["asleep"].duplicate()
var pose_name: String = "asleep"
var waking: bool = false
var wake_time: float = 0.0
var key_spin: float = 0.0

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
	for p: String in ["head", "torso", "arm", "leg", "back_key"]:
		if not ResourceLoader.exists(ART + p + ".svg"):
			return false
	return true


func _ready() -> void:
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
	_eyes = DollEyes.new()
	_head.add_child(_eyes)
	_eyes.position = _local(-PIVOT["head"])
	_leg_near = _joint(_hip, "leg", Vector2(3, 0), Color.WHITE)
	_arm_near = _joint(_torso, "arm", _local(PIVOT["torso_shoulder"] - PIVOT["torso_hip"]) + Vector2(2, 0), Color.WHITE)
	_apply()


## A part: a Node2D at `at` (its joint) holding the texture with its pivot on
## the node's origin.
func _joint(parent: Node, part: String, at: Vector2, tint: Color, pivot: Vector2 = Vector2.INF) -> Node2D:
	var joint := Node2D.new()
	joint.position = at
	parent.add_child(joint)
	var sprite := Sprite2D.new()
	sprite.texture = load(ART + part + ".svg")
	sprite.centered = false
	sprite.scale = Vector2.ONE / TEX_SCALE
	sprite.offset = -(pivot if pivot != Vector2.INF else PIVOT[part]) * TEX_SCALE
	sprite.modulate = tint
	joint.add_child(sprite)
	_parts[part + str(_parts.size())] = sprite
	return joint


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


func advance(dt: float) -> void:
	if waking:
		wake_time += dt
		pose = _wake_pose(wake_time)
		if wake_time >= WAKE[WAKE.size() - 1][0]:
			waking = false
			pose_name = "stand"
	key_spin += dt * (6.0 if pose_name == "stand" or waking else 0.0)
	_apply()


## The pose at time `t` of the wake-up timeline (smoothstep between keys).
static func _wake_pose(t: float) -> Dictionary:
	for i in WAKE.size() - 1:
		var a: Array = WAKE[i]
		var b: Array = WAKE[i + 1]
		if t <= float(b[0]):
			var k := smoothstep(float(a[0]), float(b[0]), t)
			return _blend(POSES[a[1]], POSES[b[1]], k)
	return POSES[WAKE[WAKE.size() - 1][1]].duplicate()


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
	(_eyes as DollEyes).openness = float(pose["eyes"])
	_eyes.queue_redraw()


## Where the top of the head is now (for tests: asleep is lower than standing).
func head_top() -> Vector2:
	return _head.get_global_transform() * Vector2(0, -50)


class DollEyes extends Node2D:
	## Eyes in the head SVG's own pixels: closed is a lid line, open an oval
	## with a highlight. Two eyes in three-quarter view, the far one smaller.
	var openness: float = 0.0
	const EYES := [[Vector2(40, 31), 1.0], [Vector2(51, 30), 0.75]]
	const INK := Color(0.16, 0.1, 0.12)

	func _draw() -> void:
		for e: Array in EYES:
			var c: Vector2 = e[0]
			var s: float = e[1]
			if openness < 0.2:
				draw_arc(c + Vector2(0, -1.5) * s, 3.6 * s, deg_to_rad(20), deg_to_rad(160), 8, INK, 1.6, true)
			else:
				var h := lerpf(1.2, 4.4, clampf(openness, 0.0, 1.0)) * s
				var pts := PackedVector2Array()
				for i in 12:
					var a := TAU * i / 12.0
					pts.append(c + Vector2(cos(a) * 3.0 * s, sin(a) * h))
				draw_colored_polygon(pts, INK)
				if openness > 0.7:
					draw_circle(c + Vector2(0.9, -1.4) * s, 0.9 * s, Color(1, 1, 1, 0.9))
