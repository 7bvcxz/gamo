extends Node2D
class_name PlayerActor

## The engineer. The artwork and the animation approach are carried over from
## Motorio: one registered pose per state, animated with squash, bounce and a
## foot anchor, because the generated sheet's frames do not share a continuous
## silhouette and cross-fading them made the character jitter sideways.

## Halved: the world is small and the cold is the pressure, so covering ground
## should be a decision rather than something you do incidentally.
const SPEED := 84.0
const SPRINT := 1.7
const ACCEL := 1500.0
const FRICTION := 1900.0

const SPRITE_SCALE := 0.105
const TARGET_FOOT := Vector2(0.0, 12.0)

## The sheet is NOT a clean 4x3 grid. Measured from the image: each row's four
## drawings sit at different offsets inside their cells (drifting ~50px left per
## column) and the fourth drawing crosses the cell boundary entirely. Slicing by
## hframes/vframes therefore shifted the character between frames -- the visible
## "teleport" -- and clipped the last pose. These are the real pixel bounds of
## each drawing, and the foot anchor measured inside each one.
const FRAME_REGIONS: Array[Rect2] = [
	Rect2(155, 42, 187, 297), Rect2(462, 42, 187, 297), Rect2(760, 35, 214, 304), Rect2(1062, 40, 207, 299),
	Rect2(154, 381, 190, 302), Rect2(462, 381, 191, 302), Rect2(766, 382, 193, 300), Rect2(1078, 382, 191, 301),
	Rect2(147, 728, 206, 297), Rect2(457, 729, 211, 284), Rect2(767, 727, 211, 301), Rect2(1084, 732, 211, 298),
]
const FRAME_FOOT: Array[Vector2] = [
	Vector2(81.9, 296), Vector2(80.9, 296), Vector2(90.7, 303), Vector2(95.8, 298),
	Vector2(117.8, 301), Vector2(121.3, 301), Vector2(129.9, 299), Vector2(126.9, 300),
	Vector2(115.2, 296), Vector2(152.4, 283), Vector2(142.6, 300), Vector2(139.4, 297),
]

var velocity := Vector2.ZERO
var facing := Vector2i.RIGHT
## Eight-way facing for the artwork and the shadow lean. Build targeting stays
## on the four cardinals because belts and machine outputs are cardinal.
var facing8: int = Defs.DIR_S
var warmth := 100.0
var locked := false
var animation_time := 0.0
var _lean := 0.0
## 0 upright, 1 fully collapsed. Driven by Main once warmth runs out.
var collapse := 0.0
var touch_direction := Vector2.ZERO
var touch_sprint := false
## Set by Main while a cat is being carried, so it rides along in her arms.
var carrying_cat := false
## Set by Main. Structures block movement, so the actor needs to ask the world
## whether a tile is passable before it commits to a step.
var blocked: Callable = func(_cell: Vector2i) -> bool: return false

@onready var character: Sprite2D = $Character

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not locked:
		input = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		if input.length() > 1.0:
			input = input.normalized()
		if not touch_direction.is_zero_approx():
			input = touch_direction
	var sprinting: bool = (Input.is_action_pressed("sprint") or touch_sprint) and not locked
	# Cold slows the whole way down to a crawl rather than only at the end.
	var chill_speed: float = lerpf(Defs.COLD_SPEED_FLOOR, 1.0, clampf(warmth / 100.0, 0.0, 1.0))
	var target: Vector2 = input * SPEED * (SPRINT if sprinting else 1.0) * chill_speed
	if input == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(target, ACCEL * delta)
		facing8 = Defs.facing_index(input)
		if absf(input.x) > 0.25:
			facing = Vector2i(signi(int(signf(input.x))), 0)
		elif absf(input.y) > 0.25:
			facing = Vector2i(0, signi(int(signf(input.y))))
	_move(velocity * delta)

	_animate(delta, input, sprinting)
	queue_redraw()

## Axis-separated movement: try each axis on its own so sliding along a wall
## works instead of sticking the moment one direction is blocked.
func _move(step: Vector2) -> void:
	# Already inside a structure? Suspend collision until the body is clear. A
	# save written before a tile gained the attribute can leave the player here,
	# and blocking every way out would seal them in permanently.
	if not _free_at(position):
		position += step
		return
	if not _free_at(Vector2(position.x + step.x, position.y)):
		step.x = 0.0
		velocity.x = 0.0
	position.x += step.x
	if not _free_at(Vector2(position.x, position.y + step.y)):
		step.y = 0.0
		velocity.y = 0.0
	position.y += step.y

## The body is a small box, so a corner cannot clip into a structure.
func _free_at(at: Vector2) -> bool:
	var r: float = Defs.PLAYER_RADIUS
	for corner: Vector2 in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		var cell := Vector2i(((at + corner) / float(Defs.TILE)).floor())
		if blocked.call(cell):
			return false
	return true

func _animate(delta: float, input: Vector2, sprinting: bool) -> void:
	animation_time += delta
	# The generated sheet is a single front-facing view, so heading is expressed
	# by mirroring and by a lean rather than by a different drawing.
	var view: Dictionary = Defs.facing_view(facing8)
	var lean: float = float(view["lean"])
	character.flip_h = bool(view["flip"]) or (absf(input.x) > 0.15 and input.x < 0.0)
	_lean = lerpf(_lean, lean, minf(1.0, delta * 9.0))
	# Cold drains the colour out of her the same way it does the world.
	var chill: float = clampf(1.0 - warmth / 100.0, 0.0, 1.0)
	character.modulate = Color.WHITE.lerp(Color(0.70, 0.80, 1.0), chill * 0.65)
	if collapse > 0.0:
		_collapsed()
	elif input.is_zero_approx():
		_idle()
	else:
		_moving(sprinting)

func _collapsed() -> void:
	# Sinks to the ground and tips over rather than freezing mid-pose.
	var fall: float = clampf(collapse, 0.0, 1.0)
	character.rotation = fall * (PI * 0.42) * (-1.0 if character.flip_h else 1.0)
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * lerpf(1.0, 0.86, fall))
	_set_frame(0, TARGET_FOOT + Vector2(0.0, fall * 7.0))

func _idle() -> void:
	var breath: float = 1.0 + sin(animation_time * 3.2) * 0.012
	character.rotation = _lean * 0.05
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * breath)
	# The idle row's four frames share a silhouette, so they can actually cycle;
	# only the action rows had the discontinuity that forced a single pose.
	_set_frame(int(animation_time * 2.2) % 4)

func _moving(sprinting: bool) -> void:
	var rate: float = 13.0 if sprinting else 8.5
	var phase: float = animation_time * rate
	var stretch: float = sin(phase) * (0.045 if sprinting else 0.035)
	var squash: float = -stretch * 0.45
	var bounce: float = absf(sin(phase)) * (3.0 if sprinting else 2.0)
	character.rotation = sin(phase) * (0.075 if sprinting else 0.055) + _lean * 0.06
	character.scale = Vector2(SPRITE_SCALE * (1.0 + squash), SPRITE_SCALE * (1.0 + stretch))
	# Walk and run now cycle their four drawn frames instead of holding one. The
	# foot anchor per frame is what keeps the character from sliding sideways.
	var row: int = 8 if sprinting else 4
	var step: int = int(animation_time * (9.0 if sprinting else 6.5)) % 4
	_set_frame(row + step, TARGET_FOOT - Vector2(0.0, bounce))

## Places the drawing so its measured foot lands exactly on `target_foot`,
## whatever the frame's own size and offset are. This is what removes the jitter.
func _set_frame(frame_index: int, target_foot: Vector2 = TARGET_FOOT) -> void:
	var region: Rect2 = FRAME_REGIONS[frame_index]
	character.region_enabled = true
	character.region_rect = region
	character.position = target_foot - foot_offset(frame_index, character.scale, character.rotation, character.flip_h)

## Offset from the sprite's own origin to its anchor, in parent space.
## Horizontally the anchor is the drawing's centre, not its feet: in a run cycle
## the feet legitimately swing about 3.6px, and anchoring to them makes the torso
## wobble instead. Vertically the anchor is the measured foot, which is what
## keeps every pose standing on the same ground line.
static func foot_offset(frame_index: int, scale: Vector2, rotation: float, _flipped: bool) -> Vector2:
	var region: Rect2 = FRAME_REGIONS[frame_index]
	var delta := Vector2(0.0, FRAME_FOOT[frame_index].y - region.size.y * 0.5)
	return (delta * scale).rotated(rotation)

func facing_cell() -> Vector2i:
	return Vector2i((position / float(Defs.TILE)).floor()) + facing

func cell() -> Vector2i:
	return Vector2i((position / float(Defs.TILE)).floor())

func _draw() -> void:
	# Flattened ground shadow, drawn under the sprite so she is anchored to the
	# grid rather than floating over it.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 26), 9.0, Color(0.02, 0.04, 0.08, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Two markers: the cardinal pip is the build-targeting contract, the smaller
	# eight-way arc shows which way she is actually heading.
	var heading: Vector2 = Defs.DIR_VECTORS[facing8]
	draw_circle(heading * 20.0, 1.8, Color(Defs.COL_BELT_RIM.r, Defs.COL_BELT_RIM.g, Defs.COL_BELT_RIM.b, 0.6))
	draw_circle(Vector2(facing.x, facing.y) * 15.0, 2.4, Defs.COL_CORE)
