extends Node2D
class_name CatView

## One cat, as a node with children, so its parts cannot come apart.
##
## Everything a cat shows used to be computed separately from its position --
## five paths from one number -- and three bugs in two days came from a value
## leaking into one of those paths and not the others. The worst of them: the
## breathing scale was folded into the body's height, the gauge was positioned
## from that height, and the shadow was not, so a walking cat's gauge slid
## against its own shadow.
##
## Here the only thing that moves is this node. Children sit at constant local
## offsets, and the one rule that makes the old bug impossible is that
## `_overhead` is placed from a constant, never from the body's current scale.
##
## Built in code rather than as a .tscn. The structure is the point and it is
## eight lines of it; a scene file would put those eight lines somewhere a reader
## of this script cannot see them.

## The sheets and the numbers stay in MachineLayer, which still draws the cat in
## the player's arms -- one carried sprite with no shadow and nothing hanging
## over it, so it has nothing to come apart from.
const CELL := MachineLayer.CAT_CELL
const FRAMES := MachineLayer.CAT_FRAMES
const DRAW := MachineLayer.CAT_DRAW

## Where the feet sit below this node's origin. The body's own origin is moved to
## its foot anchor, so breathing scales the sprite about the feet and cannot lift
## or drop them by even the third of a pixel that scaling about the centre would.
const GROUND := MachineLayer.CAT_GROUND
## The top of the head, as a constant. This is the line everything overhead hangs
## from, and it does not move when the cat breathes -- which is the whole fix.
const HEAD := GROUND - (MachineLayer.CAT_FOOT_FRACTION - MachineLayer.CAT_HEAD_FRACTION) \
	* DRAW

var cat: Sim.Cat = null
var pulse: float = 0.0

var _shadow: Node2D
var _body: Sprite2D
var _pig: Node2D
var _tool: Sprite2D
var _overhead: Node2D

func _ready() -> void:
	# Shadows below every cat's body rather than below its own: drawn per cat,
	# the next cat's shadow lands on the previous cat's feet. A negative z does
	# across the whole pool what two passes over the array used to do.
	_shadow = Node2D.new()
	_shadow.z_index = -1
	_shadow.draw.connect(_draw_shadow)
	add_child(_shadow)

	_body = Sprite2D.new()
	_body.texture = MachineLayer.CAT_IDLE_SHEET
	_body.region_enabled = true
	_body.position = Vector2(0.0, GROUND)
	# The origin is the foot anchor, in texture pixels, so scale happens there.
	_body.offset = Vector2(0.0, -(MachineLayer.CAT_FOOT_FRACTION - 0.5) * CELL)
	add_child(_body)

	# No sheet exists for the pig, so it is drawn. It goes in the animal's own
	# band inside the cell, which is what keeps it on the shadow and the gauge.
	_pig = Node2D.new()
	_pig.draw.connect(_draw_pig)
	_pig.visible = false
	add_child(_pig)

	_tool = Sprite2D.new()
	_tool.texture = MachineLayer.CAT_TOOL_ART
	_tool.scale = Vector2.ONE * (MachineLayer.CAT_TOOL_DRAW / float(_tool.texture.get_width()))
	_tool.visible = false
	add_child(_tool)

	_overhead = Node2D.new()
	_overhead.position = Vector2(0.0, HEAD)
	_overhead.draw.connect(_draw_overhead)
	add_child(_overhead)

## Called once a frame by the pool. Sets this node's position and the state its
## children need; nothing here computes a second position for anything.
func sync(source: Sim.Cat, time: float, visible_now: bool) -> void:
	cat = source
	pulse = time
	visible = visible_now
	if not visible_now:
		return
	position = cat.pos

	var breathe: float = MachineLayer.cat_breathe(cat, pulse)
	var frame: int = MachineLayer.cat_frame(cat, pulse)
	var heading: Vector2 = Vector2.DOWN if cat.state == Defs.CAT_EATING else cat.heading
	var chosen: Array = MachineLayer.cat_sheet(cat.state, heading, cat.is_walking())
	var sheet: Texture2D = chosen[0]
	var base: float = DRAW / CELL

	var is_pig: bool = cat.rarity == Defs.RARITY_SSR
	_body.visible = not is_pig
	_pig.visible = is_pig
	_body.texture = sheet
	_body.region_rect = Rect2(float(frame) * CELL, 0.0, CELL, CELL)
	_body.flip_h = bool(chosen[1])
	_body.scale = Vector2(base / breathe, base * breathe)

	_tool.visible = cat.state == Defs.CAT_WORKING
	if _tool.visible:
		# Twice a cycle, a quarter as far. A drill swinging the height of the cat
		# reads as the animal waving it about; a short fast tap reads as work.
		var swing: float = float(frame) / float(FRAMES) * MachineLayer.CAT_TOOL_BEATS
		_tool.position = Vector2(0.0, 9.0 + sin(swing * TAU) * MachineLayer.CAT_TOOL_BOB)

	_shadow.queue_redraw()
	_overhead.queue_redraw()
	if is_pig:
		_pig.queue_redraw()

func _draw_shadow() -> void:
	# Squashed the same way every shadow in the game is, and at a fixed offset
	# from the cat rather than from anything the cat is currently doing.
	var at := Vector2(0.0, GROUND)
	_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, Defs.SHADOW_SQUASH))
	_shadow.draw_circle(Vector2(at.x, at.y / Defs.SHADOW_SQUASH), DRAW * 0.18, Defs.SHADOW)
	if cat != null and cat.rarity >= Defs.RARITY_R:
		var tint: Color = Defs.RARITY_COLORS[cat.rarity]
		_shadow.draw_arc(Vector2(at.x, at.y / Defs.SHADOW_SQUASH), DRAW * 0.26, 0.0, TAU, 24,
			Color(tint.r, tint.g, tint.b, 0.85), 2.0)
	_shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Crumbs kicking up from the bowl, at the feet, where they belong.
	if cat != null and cat.state == Defs.CAT_EATING:
		for crumb in 3:
			var phase: float = fmod(pulse * 2.2 + float(crumb) * 0.33, 1.0)
			_shadow.draw_circle(Vector2(sin(float(crumb) * 2.1) * 9.0, 6.0 - phase * 9.0),
				1.6 * (1.0 - phase), Color(0.95, 0.82, 0.55, 1.0 - phase))

func _draw_pig() -> void:
	if cat == null:
		return
	var gait: float = 0.0
	if cat.is_walking():
		gait = pulse * 7.0
	var top: float = HEAD
	var bottom: float = GROUND
	var width: float = DRAW * 0.62
	Icons.draw_pig(_pig, Rect2(-width * 0.5, top, width, bottom - top), gait)

## The gauge and the load, hung from a constant. Never from the body's current
## height: that is the coupling the whole structure exists to remove.
func _draw_overhead() -> void:
	if cat == null:
		return
	if cat.carrying >= 0:
		var load_colour: Color = Defs.ITEM_COLORS[cat.carrying]
		var at := Vector2(0.0, -MachineLayer.CAT_LOAD_LIFT)
		_overhead.draw_circle(at, MachineLayer.CAT_LOAD_RADIUS,
			Color(load_colour.r, load_colour.g, load_colour.b, 0.30))
		_overhead.draw_circle(at, 3.2, load_colour)
	if cat.hunger < 0.5:
		var size: Vector2 = MachineLayer.CAT_BAR_SIZE
		var bar := Rect2(-size.x * 0.5, -MachineLayer.CAT_BAR_LIFT, size.x, size.y)
		_overhead.draw_rect(bar, Color(0.06, 0.08, 0.12, 0.85))
		_overhead.draw_rect(Rect2(bar.position, Vector2(bar.size.x * cat.hunger, bar.size.y)),
			Defs.COL_DANGER if cat.hunger <= 0.0 else Defs.COL_BELT_RIM)
