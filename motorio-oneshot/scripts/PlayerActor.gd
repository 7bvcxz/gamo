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

## The character is Grim, and her sheets come out of tools/sprite already
## normalised: uniform 128-pixel cells, one shared scale across a sequence, and
## the foot placed on the same anchor in every frame.
##
## That replaced twelve hand-measured rectangles and twelve hand-measured foot
## positions. The old sheet was a set of drawings that happened to share a file:
## each sat at a different offset inside its cell, one crossed the cell boundary
## entirely, and slicing it by hframes/vframes teleported the character between
## frames. All of that arithmetic existed to compensate for a sheet that was
## never in register. This one is, so there is nothing left to compensate for.
const CELL := 128.0
## Where the feet are inside a cell, from tools/sprite/spec.json. The pipeline
## guarantees it, and the validator fails a sequence that does not honour it.
const FOOT_ANCHOR := Vector2(64.0, 104.0)

## Half, so a 128-pixel cell draws as a 64-pixel figure whose body spans about
## 32 logical pixels -- one tile, and the size the previous character was drawn
## at. The cell does not decide how big she is in the world; this does.
##
## Half is also the number that makes a 1920x1080 window land one texel on one
## screen pixel, since the viewport is 960x540. That is the whole reason the
## sheets are 128 rather than 64.
const SPRITE_SCALE := 0.5

## Where her feet sit relative to the actor's origin. The actor's position is the
## point the simulation moves; this is how far below it the drawing stands.
const TARGET_FOOT := Vector2(0.0, 12.0)

const IDLE_SHEET: Texture2D = preload("res://assets/characters/grim_idle_s.png")
const WALK_SHEET: Texture2D = preload("res://assets/characters/grim_walk_s.png")
## Walking sideways is a different drawing, not the front view turned: the legs
## cross and the satchel swings, which a mirror of the front view cannot show.
## West is this flipped, because the foot anchor is on the cell's centre line and
## the reflection is therefore exact.
const WALK_E_SHEET: Texture2D = preload("res://assets/characters/grim_walk_e.png")
const RUN_SHEET: Texture2D = preload("res://assets/characters/grim_run_s.png")
## The side run, where the forward lean is finally visible. Front-on it is not:
## a body pitched toward the camera foreshortens into nothing, which is why the
## front run reads as a run through the knees and the bounce instead. Measured on
## the footage, the side run leans 2.7 degrees forward against the side walk's
## 0.9 back -- a 3.6 degree difference between walking and running.
const RUN_E_SHEET: Texture2D = preload("res://assets/characters/grim_run_e.png")
## Walking away. Drawn rather than derived, because a back view shares nothing
## with a front one: no face, the satchel strap crosses the other shoulder, and
## the coat hangs differently. Up used to play the front sheet, so she walked
## north while looking south.
const WALK_N_SHEET: Texture2D = preload("res://assets/characters/grim_walk_n.png")
const RUN_N_SHEET: Texture2D = preload("res://assets/characters/grim_run_n.png")
## Swinging a pickaxe. `mining` is already driven by the simulation -- it is the
## fraction of the way through working a seam by hand -- and until now only fed
## a progress ring. The character stood there doing nothing while she mined.
const MINE_SHEET: Texture2D = preload("res://assets/characters/grim_mine_s.png")
## West rather than east, because the clip that reads as a side view faces left.
## East is this mirrored, which is exact -- the anchor sits on the cell's centre
## line -- and is the same trade the walk and run make for their west frames.
const MINE_W_SHEET: Texture2D = preload("res://assets/characters/grim_mine_w.png")
const MINE_N_SHEET: Texture2D = preload("res://assets/characters/grim_mine_n.png")
## Eight frames at ten a second, for every motion. The spec settles on one shape
## rather than a count per motion: what differs between a walk and an idle is
## what happens inside the cycle, not how many slots it is cut into.
const FRAMES := 8
const FPS := 10.0
## The run plays faster than everything else, and the number is not a taste
## decision. Its source cycle is seven frames of twelve-per-second footage, so a
## stride takes 0.58s; eight frames at ten a second would stretch that to 0.80s
## and the run would arrive slower than it was generated. Fourteen puts it back
## at 0.57s. The walk needs no such correction -- its cycle is 0.83s and eight
## frames at ten is 0.80s, which is the same stride.
##
const RUN_FPS := 14.0
## A swing is slower than a stride, and the sheets say by how much. The mining
## clips repeat every 17, 20 and 20 source frames at twelve a second -- about a
## second and two thirds -- while a walk repeats every ten, which is 0.83s. Eight
## frames at ten a second is 0.8s, so walking played at its own speed and mining
## played at twice its own. It read as frantic, which is what a person watching
## it said.
const MINE_FPS := 5.0
## Which frame of the swing the pickaxe is at the ground. Used for the impact
## sound, so the sound lands with the hit rather than on a timer of its own.
const MINE_IMPACT_FRAME := 4

var velocity := Vector2.ZERO
## Which frame the swing is on, so the game can put a sound on the impact. -1
## when she is not mining.
var mine_frame: int = -1
var facing := Vector2i.RIGHT
## Eight-way facing for the artwork and the shadow lean. Build targeting stays
## on the four cardinals because belts and machine outputs are cardinal.
var facing8: int = Defs.DIR_S
var warmth := 100.0
var locked := false
var animation_time := 0.0
## The movement the current frame is being chosen for, so the drawing routines
## can ask which way she is going without it being threaded through each call.
var _walk_input := Vector2.ZERO
## Which way she is drawn horizontally. Remembered rather than derived from the
## current input, so standing still keeps the direction she was last walking.
var _face_left := false
## 0 upright, 1 fully collapsed. Driven by Main once warmth runs out.
var collapse := 0.0
var touch_direction := Vector2.ZERO
var touch_sprint := false
## Set by Main while a cat is being carried, so it rides along in her arms.
## The position and heading come from the cat itself rather than being recomputed
## here, so the drawing cannot drift from where the simulation put it.
var carrying_cat := false
## 0..1 while working a seam by hand, for the swing animation and the ring.
var mining: float = 0.0
var carried_cat_pos := Vector2.ZERO
var carried_cat_heading := Vector2.DOWN
## Set by Main. Structures block movement, so the actor needs to ask the world
## whether a tile is passable before it commits to a step.
var blocked: Callable = func(_cell: Vector2i) -> bool: return false

@onready var character: Sprite2D = $Character

## The carried cat is drawn on its own canvas item stacked above the character
## sprite. Drawing it in this node's _draw would put it *behind* Character,
## because a Node2D paints before its children.
var carry_layer: Node2D

func _ready() -> void:
	carry_layer = Node2D.new()
	carry_layer.z_index = 1
	add_child(carry_layer)
	carry_layer.draw.connect(_draw_carried_cat)

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
	if carry_layer != null:
		carry_layer.queue_redraw()

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
	# Her sheet is a single right-facing drawing, so west is a mirror. The flip in
	# Defs.facing_view belongs to the cat sheet, which really does have a left
	# frame, and following it snapped her back to facing right the moment she
	# stopped after walking west. The last horizontal heading is kept instead;
	# walking straight up or down leaves it alone.
	if absf(input.x) > 0.15:
		_face_left = input.x < 0.0
	character.flip_h = _face_left
	# Cold drains the colour out of her the same way it does the world.
	var chill: float = clampf(1.0 - warmth / 100.0, 0.0, 1.0)
	character.modulate = Color.WHITE.lerp(Color(0.70, 0.80, 1.0), chill * 0.65)
	_walk_input = input
	if collapse > 0.0:
		_collapsed()
	elif mining > 0.0 and input.is_zero_approx():
		# Only while standing: walking away from a seam stops the work anyway, and
		# a swing played over a stride would be two animations at once.
		_mining()
	elif input.is_zero_approx():
		_idle()
	else:
		_moving(sprinting)

func _collapsed() -> void:
	# Sinks to the ground and tips over rather than freezing mid-pose.
	var fall: float = clampf(collapse, 0.0, 1.0)
	character.rotation = fall * (PI * 0.42) * (-1.0 if character.flip_h else 1.0)
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * lerpf(1.0, 0.86, fall))
	_set_frame(IDLE_SHEET, 0, TARGET_FOOT + Vector2(0.0, fall * 7.0))

## The swing, facing whichever way she is working. Which direction that is comes
## from `facing`, not from movement input -- she is standing still, so there is no
## input to read.
func _mining() -> void:
	character.rotation = 0.0
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	var step: int = int(animation_time * MINE_FPS) % FRAMES
	mine_frame = step
	var sheet: Texture2D
	if facing.x != 0:
		sheet = MINE_W_SHEET
		# Mining reads its direction from `facing`, so the flip has to come from
		# there too. flip_h is otherwise set from the last walking input, which is
		# whatever she happened to be doing before she stopped to work.
		character.flip_h = facing.x > 0
	elif facing.y < 0:
		sheet = MINE_N_SHEET
	else:
		sheet = MINE_SHEET
	_set_frame(sheet, step)

func _idle() -> void:
	mine_frame = -1
	# The clip's own breathing was about six pixels at 640, which is under one
	# pixel once the sheet is 128 and drawn at half scale -- it rounds away, and
	# the four idle frames differ only in shading. So the rise and fall is done
	# here, where it can be given an amplitude that survives. Small on purpose:
	# she is standing still, and anything larger reads as bobbing.
	var breath: float = 1.0 + sin(animation_time * 2.4) * 0.028
	# Upright. The lean was a tilt for the diagonal facings, which mattered when
	# one drawing had to stand in for eight directions; standing still now means
	# standing still.
	character.rotation = 0.0
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE * breath)
	_set_frame(IDLE_SHEET, int(animation_time * FPS) % FRAMES)

func _moving(sprinting: bool) -> void:
	mine_frame = -1
	# Nothing procedural. No rocking, no squash, no hop -- the sheet is played and
	# that is all.
	#
	# All three were added when the walk was four drawings that did not move on
	# their own, so the engine had to supply the motion. Every one of them has
	# since been caught fighting the artwork: the rocking put a second swing on
	# top of the drawn lean, and the vertical hop bounced a character whose feet
	# the drawing already lifts. Compensation that outlives what it compensated
	# for is just noise on top of the thing it was hiding.
	character.rotation = 0.0
	character.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	var fps: float = RUN_FPS if sprinting else FPS
	var step: int = int(animation_time * fps) % FRAMES
	# Ties go sideways, and the tie is not a rare case: a keyboard diagonal is
	# exactly 0.707 on both axes, so `>` sent every diagonal to the front view
	# while the comment here claimed otherwise.
	var sideways: bool = absf(_walk_input.x) >= absf(_walk_input.y)
	# Three views: sideways, away, and toward. Up is its own drawing now rather
	# than the front one played while moving north.
	var sheet: Texture2D
	if sideways:
		sheet = RUN_E_SHEET if sprinting else WALK_E_SHEET
	elif _walk_input.y < 0.0:
		sheet = RUN_N_SHEET if sprinting else WALK_N_SHEET
	else:
		sheet = RUN_SHEET if sprinting else WALK_SHEET
	_set_frame(sheet, step)

## Playback is a plain loop for every motion, and the ping-pong that used to be
## here is gone. It existed because the idle's frames were a one-way slice of a
## breath rather than a cycle, so looping them snapped from the end back to the
## start. The pipeline now samples every motion across one full period, so the
## last frame leads into the first on its own and there is nothing left to hide.
## Places the cell so its anchor lands on `target_foot`. Every frame uses the
## same rectangle size and the same anchor, so this is one subtraction rather
## than a per-frame lookup.
func _set_frame(sheet: Texture2D, frame_index: int, target_foot: Vector2 = TARGET_FOOT) -> void:
	character.texture = sheet
	character.region_enabled = true
	character.region_rect = Rect2(frame_index * CELL, 0.0, CELL, CELL)
	character.position = target_foot - foot_offset(character.scale, character.rotation)

## Offset from the sprite's centre to the foot anchor, in parent space.
##
## Horizontally there is nothing to correct: the anchor sits on the cell's
## vertical centre line, which is also what makes mirroring west from east exact.
## Vertically it is the distance from the middle of the cell down to the anchor.
## No frame index, because every frame answers the same.
static func foot_offset(scale: Vector2, rotation: float) -> Vector2:
	var delta := Vector2(0.0, FOOT_ANCHOR.y - CELL * 0.5)
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

## Drawn in world space relative to the player, from the cat's own position, so
## what is on screen and what the simulation believes are the same thing.
func _draw_carried_cat() -> void:
	if not carrying_cat:
		return
	var offset: Vector2 = carried_cat_pos - global_position
	var view: Dictionary = Defs.facing_view(Defs.facing_index(carried_cat_heading))
	# Same arithmetic as a cat standing on the ground, only measured from her
	# position instead of the world's. Doing it separately here is what let the
	# two drift apart when the cat's drawn size changed.
	var target: Rect2 = MachineLayer.cat_rect(offset, 1.0, bool(view["flip"]), 0.0)
	# The idle sheet: a cat in her arms is not walking, and the old directional
	# sheet it used to index into no longer exists.
	var step: int = int(animation_time * MachineLayer.CAT_FPS) % MachineLayer.CAT_FRAMES
	var region := Rect2(float(step) * MachineLayer.CAT_CELL, 0.0,
		MachineLayer.CAT_CELL, MachineLayer.CAT_CELL)
	carry_layer.draw_texture_rect_region(MachineLayer.CAT_IDLE_SHEET, target, region, Color.WHITE)
