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
## Which frame the walk or run is on, and whether she is running, so the game can
## put a footfall on the frames where a boot lands. -1 when she is not moving,
## for the same reason mine_frame is -1 when she is not swinging: the sound has
## to fire on a change of frame, and a stale number fires on the first step of
## the next walk instead of the right one.
var step_frame: int = -1
var step_running := false
## Which frames of the eight a foot is down on. Two, because a walk cycle is two
## steps -- one sound per cycle sounds like a limp.
const STEP_FRAMES: Array[int] = [1, 5]

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
## Set by Main while a frozen cat is being carried. Halves her speed and takes
## the run away: it is a body, not a kitten, and the walk home is the price of
## having walked out. Separate from `carrying_cat` because the two are drawn
## from different sheets and only one of them slows her down.
var carrying_frozen := false
## The block of ice in her arms, and where its top edge sits in her local space.
##
## Not the arrangement a carried cat uses, and the first version was. A cat rides
## a third of a tile ahead in the direction she faces, drawn at its full world
## size -- which for a cat is smaller than she is, so she stays visible behind
## it. The ice block is not: at full size it covered her from the hat down and
## what the screen showed was Grim disappearing, not Grim carrying something.
## Worse, riding ahead of her meant walking north pushed it *up*, over her head.
##
## So it is held, not carried ahead: fixed to her chest whichever way she turns,
## drawn at seven tenths, with its top edge below her chin. Her head and
## shoulders stay clear, and the block reaches below her feet the way a heavy
## thing held in front of you does.
## Both numbers were set by measuring the result rather than by reasoning about
## it. The first attempt kept her head clear by nine pixels of the thirty-two she
## is drawn at, which is a hat sitting on a block of ice -- correct by the
## arithmetic and wrong on the screen. At these she is visible from the waist up.
## The ice reaches below her feet, which is what "held out in front" looks like
## from above.
const FROZEN_CARRY_DRAW := MachineLayer.CAT_DRAW * 0.62
const FROZEN_CARRY_TOP := -12.0
## Which emergency kit is in her arms, if any. Drawn in the same place the ice
## block is and for the same reason: it is a thing held in front of her with
## both hands, and it must not cover her head.
var carrying_kit: int = Defs.KIT_NONE
const KIT_CARRY_SIZE := 26.0
## 0..1 while working a seam by hand, for the swing animation and the ring.
var mining: float = 0.0
var carried_cat_pos := Vector2.ZERO
var carried_cat_heading := Vector2.DOWN
## Which grade is in her arms, because the SSR is drawn rather than played.
var carried_cat_rarity: int = Defs.RARITY_O
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

## A window is up, so the world is not listening.
##
## Separate from `locked`, which is the simulation holding the character still --
## asleep, frozen, being carried home. The two have to stay separate or closing a
## window would clear a freeze.
##
## It exists at all because movement is polled rather than delivered as events:
## the build list already consumed its key presses and marked them handled, and
## Grim walked anyway, because `Input.get_action_strength` does not care what any
## handler decided. Marking an event handled cannot stop something that never
## looked at the event.
var modal: bool = false

## The one question both of the above answer. Asked in one place so a third kind
## of "not now" cannot be added to one of the two things that need it.
func takes_input() -> bool:
	return not locked and not modal

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if takes_input():
		input = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		if input.length() > 1.0:
			input = input.normalized()
		if not touch_direction.is_zero_approx():
			input = touch_direction
	# Not while she is carrying one: the run is refused here rather than only
	# ignored in the speed, so the sheet, the footstep sound and the touch pad's
	# sprint button all agree that she is walking.
	var sprinting: bool = (Input.is_action_pressed("sprint") or touch_sprint) \
		and takes_input() and not carrying_frozen
	# Cold slows the whole way down to a crawl rather than only at the end.
	var chill_speed: float = lerpf(Defs.COLD_SPEED_FLOOR, 1.0, clampf(warmth / 100.0, 0.0, 1.0))
	var load_speed: float = Defs.FROZEN_CARRY_SPEED if carrying_frozen else 1.0
	var target: Vector2 = input * SPEED * (SPRINT if sprinting else 1.0) * chill_speed * load_speed
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
	step_frame = -1
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
	# Read by Main, which plays the footfall. Kept here because this is the one
	# place that knows which frame is showing, and a sound timed against anything
	# else drifts away from the legs it is supposed to belong to.
	step_frame = step
	step_running = sprinting
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

## Her temperature, over her head, in the same words a cat's hunger is in.
##
## The corner readout is still the exact number; this is the one the eye finds
## without leaving her. In the opening the temperature *is* the clock, and the
## player is looking at Grim and the snow, not at a panel.
##
## Hidden while she is warm. A gauge that is always full is a gauge nobody reads
## on the day it is not.
func _draw_warmth_bar() -> void:
	var show: float = clampf((Defs.WARMTH_BAR_SHOW - warmth) / Defs.WARMTH_BAR_FADE,
		0.0, 1.0)
	if show <= 0.0:
		return
	var size: Vector2 = Defs.WARMTH_BAR_SIZE
	var bar := Rect2(-size.x * 0.5, -Defs.WARMTH_BAR_LIFT, size.x, size.y)
	var fill: float = clampf(warmth / 100.0, 0.0, 1.0)
	draw_rect(bar.grow(1.0), Color(0.02, 0.03, 0.06, 0.80 * show))
	draw_rect(bar, Color(0.10, 0.13, 0.20, 0.85 * show))
	# Amber while it is only cold, red once it is dangerous. The colour changes
	# before the number does anything, which is the point of having it here.
	var colour: Color = Defs.COL_BELT_RIM.lerp(Defs.COL_DANGER,
		clampf(1.0 - warmth / 45.0, 0.0, 1.0))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)),
		Color(colour.r, colour.g, colour.b, show))

func _draw() -> void:
	_draw_warmth_bar()
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
	# A kit first: it is neither a cat nor ice, and she can only hold one thing.
	if carrying_kit != Defs.KIT_NONE:
		var box := Rect2(-KIT_CARRY_SIZE * 0.5, FROZEN_CARRY_TOP,
			KIT_CARRY_SIZE, KIT_CARRY_SIZE * 0.78)
		carry_layer.draw_rect(box.grow(1.0), Defs.OUTLINE)
		carry_layer.draw_rect(box, Color8(96, 104, 116))
		carry_layer.draw_rect(Rect2(box.position.x, box.get_center().y - 2.0,
			box.size.x, 4.0), Color8(58, 64, 74))
		carry_layer.draw_rect(Rect2(box.get_center().x - 1.5,
			box.get_center().y - 3.5, 3.0, 7.0), Color8(214, 176, 96))
		return
	# The frozen one first: it is not a Cat and has no rarity, heading or frame.
	if carrying_frozen:
		var block := Rect2(Vector2(-FROZEN_CARRY_DRAW * 0.5, FROZEN_CARRY_TOP),
			Vector2.ONE * FROZEN_CARRY_DRAW)
		var cell := Rect2(0.0, 0.0, MachineLayer.CAT_CELL, MachineLayer.CAT_CELL)
		carry_layer.draw_texture_rect_region(MachineLayer.CAT_FREEZE_SHEET, block, cell,
			Color.WHITE)
		return
	if not carrying_cat:
		return
	var offset: Vector2 = carried_cat_pos - global_position
	var view: Dictionary = Defs.facing_view(Defs.facing_index(carried_cat_heading))
	# Same arithmetic as a cat standing on the ground, only measured from her
	# position instead of the world's. Doing it separately here is what let the
	# two drift apart when the cat's drawn size changed.
	var target: Rect2 = MachineLayer.cat_rect(offset, 1.0, bool(view["flip"]), 0.0)
	# The SSR is a pig and has no sheet to index into. Handled here as well as in
	# the machine layer because a cat is drawn in two places -- on the ground and
	# in her arms -- and the last time those two disagreed the carried one drifted
	# off its own anchor for a release.
	if carried_cat_rarity == Defs.RARITY_SSR:
		Icons.draw_pig(carry_layer, MachineLayer.cat_body_rect(target), 0.0)
		return
	# The idle sheet: a cat in her arms is not walking, and the old directional
	# sheet it used to index into no longer exists.
	var step: int = int(animation_time * MachineLayer.CAT_FPS) % MachineLayer.CAT_FRAMES
	var region := Rect2(float(step) * MachineLayer.CAT_CELL, 0.0,
		MachineLayer.CAT_CELL, MachineLayer.CAT_CELL)
	carry_layer.draw_texture_rect_region(MachineLayer.CAT_IDLE_SHEET, target, region, Color.WHITE)
