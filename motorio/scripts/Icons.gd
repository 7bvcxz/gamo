extends RefCounted
class_name Icons

## Icons for the UI, drawn rather than imported.
##
## Three places need a picture of a thing: the build menu, the objective line and
## the save-slot list. Sprite sheets for those would be three more assets to keep
## in step with the world art every time a machine changes shape, and the pack is
## already the thing that decides how long a phone waits before the title screen.
## These are a few draw calls each and cost nothing to ship.
##
## They obey the same four rules as everything in the world (Defs, "object drawing
## language"): light from the top-left, one near-black outline, one squashed
## shadow under anything that stands up, flat things inset and shadowless. An icon
## that lit itself differently from the machine it depicts would be a worse
## picture of it, however pretty on its own.
##
## Every icon fills the rect it is handed. Callers pass a square; nothing here
## assumes a size, so the same code draws a 20px hotbar chip and a 48px menu tile.

## Things the objective line can point at that are not machines or items.
const THING_CAT_FROZEN := "cat_frozen"
const THING_KIT := "kit"
const THING_TORCH := "torch"
const THING_CAT := "cat"
const THING_SHELTER := "shelter"
const THING_CORE := "core"
const THING_SEAM := "seam"
const THING_FOOD := "food"

static func _outline_width(rect: Rect2) -> float:
	return maxf(1.0, rect.size.x / 22.0)

## The shared shadow, scaled to the icon rather than to the world.
static func _shadow(canvas: CanvasItem, rect: Rect2) -> void:
	var at := Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.86)
	canvas.draw_set_transform(at, 0.0, Vector2(1.0, Defs.SHADOW_SQUASH))
	canvas.draw_circle(Vector2.ZERO, rect.size.x * 0.30, Defs.SHADOW)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A raised body with the light on its top-left, which is what makes every
## machine in this game read as the same class of object.
static func _body(canvas: CanvasItem, box: Rect2, base: Color, edge: Color, width: float) -> void:
	canvas.draw_rect(box, base)
	canvas.draw_rect(Rect2(box.position, Vector2(box.size.x * 0.42, box.size.y)),
		base.lightened(Defs.FACE_LIGHT))
	canvas.draw_rect(Rect2(box.position + Vector2(0.0, box.size.y * 0.72),
		Vector2(box.size.x, box.size.y * 0.28)), base.darkened(Defs.FACE_DARK))
	canvas.draw_rect(box, edge, false, width)
	canvas.draw_rect(box, Defs.OUTLINE, false, width * 0.6)

## An arrow along the machine's output face, so a glance at the icon says which
## way the thing points. The build menu is where a player learns that machines
## have a facing at all.
static func _arrow(canvas: CanvasItem, rect: Rect2, tint: Color) -> void:
	var right: float = rect.position.x + rect.size.x * 0.90
	var mid: float = rect.get_center().y
	var span: float = rect.size.x * 0.10
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(right, mid), Vector2(right - span, mid - span), Vector2(right - span, mid + span)]),
		tint)

## The pickaxe, for the tool slot. Drawn rather than imported for the same reason
## every machine here is: the whole game is a few hundred draw calls and three
## PNGs, and a 24-pixel icon does not need to be the fourth.
static func draw_pickaxe(canvas: CanvasItem, rect: Rect2) -> void:
	var centre: Vector2 = rect.get_center()
	var unit: float = rect.size.x
	_shadow(canvas, rect)
	# Haft, corner to corner, so the head has somewhere to sit.
	canvas.draw_line(centre + Vector2(-unit * 0.22, unit * 0.30),
		centre + Vector2(unit * 0.16, -unit * 0.24), Color8(122, 82, 52), unit * 0.11)
	# Head: two swept points off a short neck, which is what makes it a pickaxe
	# and not a hammer at this size.
	var neck: Vector2 = centre + Vector2(unit * 0.14, -unit * 0.22)
	canvas.draw_colored_polygon(PackedVector2Array([
		neck + Vector2(-unit * 0.30, -unit * 0.02),
		neck + Vector2(-unit * 0.06, -unit * 0.14),
		neck + Vector2(unit * 0.02, unit * 0.02),
		neck + Vector2(-unit * 0.08, unit * 0.02)]), Defs.COL_CLOCK)
	canvas.draw_colored_polygon(PackedVector2Array([
		neck + Vector2(unit * 0.30, -unit * 0.02),
		neck + Vector2(unit * 0.06, -unit * 0.14),
		neck + Vector2(-unit * 0.02, unit * 0.02),
		neck + Vector2(unit * 0.08, unit * 0.02)]), Defs.COL_CLOCK.darkened(0.18))

static func draw_machine(canvas: CanvasItem, rect: Rect2, type: int) -> void:
	var tint: Color = Defs.machine_color(type)
	var width: float = _outline_width(rect)
	match type:
		Defs.M_CORE:
			var centre: Vector2 = rect.get_center()
			var radius: float = rect.size.x * 0.34
			_shadow(canvas, rect)
			canvas.draw_circle(centre, radius * 1.35, Color(1.0, 0.67, 0.31, 0.16))
			canvas.draw_circle(centre, radius, Defs.COL_MACHINE.darkened(0.4))
			canvas.draw_circle(centre, radius * 0.82, Defs.COL_CORE_DEEP)
			canvas.draw_circle(centre, radius * 0.54, Defs.COL_CORE)
			canvas.draw_circle(centre, radius * 0.28, Color("fff0c9"))
		Defs.M_MINER:
			_shadow(canvas, rect)
			_body(canvas, rect.grow(-rect.size.x * 0.16), Defs.COL_MACHINE, tint, width)
			# The drill, pointing down into the seam it stands on.
			var centre: Vector2 = rect.get_center()
			var drill: float = rect.size.x * 0.13
			canvas.draw_colored_polygon(PackedVector2Array([
				centre + Vector2(-drill, -drill), centre + Vector2(drill, -drill),
				centre + Vector2(0.0, drill * 1.8)]), Defs.COL_BRASS)
			_arrow(canvas, rect, tint)
		Defs.M_BELT:
			# Flat on the ground: inset, no shadow, chevrons showing travel.
			var lane := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.24),
				Vector2(rect.size.x, rect.size.y * 0.52))
			canvas.draw_rect(lane, Defs.COL_BELT_BODY)
			canvas.draw_rect(lane, Defs.OUTLINE, false, width * 0.6)
			for index in 3:
				var x: float = lane.position.x + lane.size.x * (0.22 + 0.26 * float(index))
				var wing: float = lane.size.y * 0.24
				canvas.draw_line(Vector2(x - wing, lane.get_center().y - wing),
					Vector2(x, lane.get_center().y), Defs.COL_BELT_CHEVRON, width)
				canvas.draw_line(Vector2(x - wing, lane.get_center().y + wing),
					Vector2(x, lane.get_center().y), Defs.COL_BELT_CHEVRON, width)
		Defs.M_SPLITTER:
			var lane := Rect2(rect.position + Vector2(0.0, rect.size.y * 0.30),
				Vector2(rect.size.x * 0.62, rect.size.y * 0.40))
			canvas.draw_rect(lane, Defs.COL_BELT_BODY)
			canvas.draw_rect(lane, Defs.OUTLINE, false, width * 0.6)
			# One line in, two out: the whole point of the machine in one shape.
			var fork: Vector2 = lane.position + Vector2(lane.size.x, lane.size.y * 0.5)
			canvas.draw_line(fork, fork + rect.size * Vector2(0.26, -0.26), tint, width * 1.6)
			canvas.draw_line(fork, fork + rect.size * Vector2(0.26, 0.26), tint, width * 1.6)
		Defs.M_GENERATOR:
			_shadow(canvas, rect)
			_body(canvas, rect.grow(-rect.size.x * 0.16), Defs.COL_MACHINE, tint, width)
			var centre: Vector2 = rect.get_center()
			canvas.draw_circle(centre, rect.size.x * 0.17, Color(1.0, 0.78, 0.36, 0.85))
			# A bolt, because "this is the electricity one" has to survive being
			# 20 pixels wide on a hotbar chip.
			var unit: float = rect.size.x * 0.09
			canvas.draw_colored_polygon(PackedVector2Array([
				centre + Vector2(unit * 0.4, -unit * 1.6), centre + Vector2(-unit * 0.8, unit * 0.2),
				centre + Vector2(unit * 0.1, unit * 0.2), centre + Vector2(-unit * 0.4, unit * 1.6),
				centre + Vector2(unit * 0.9, -unit * 0.2), centre + Vector2(0.0, -unit * 0.2)]),
				Defs.OUTLINE)
		_:
			_body(canvas, rect, Defs.COL_MACHINE, tint, width)

## A loose material, drawn the way it looks lying on the ground.
static func draw_item(canvas: CanvasItem, rect: Rect2, item_type: int) -> void:
	var centre: Vector2 = rect.get_center()
	var radius: float = rect.size.x * 0.30
	var colour: Color = Defs.ITEM_COLORS[item_type]
	_shadow(canvas, rect)
	canvas.draw_circle(centre, radius * 1.5, Color(colour.r, colour.g, colour.b, 0.26))
	canvas.draw_circle(centre, radius, colour)
	canvas.draw_circle(centre, radius, Defs.OUTLINE, false, _outline_width(rect))
	canvas.draw_circle(centre - Vector2(radius * 0.34, radius * 0.34), radius * 0.26,
		Color(1, 1, 1, 0.55))

## Things the objective can ask for that are neither machine nor material.
static func draw_thing(canvas: CanvasItem, rect: Rect2, key: String) -> void:
	var width: float = _outline_width(rect)
	match key:
		THING_TORCH:
			# A shaft with a burning head. The flame is the part that has to read
			# at hotbar size, so it is most of the drawing.
			_shadow(canvas, rect)
			var centre: Vector2 = rect.get_center()
			var shaft := Rect2(centre.x - rect.size.x * 0.06, centre.y - rect.size.y * 0.02,
				rect.size.x * 0.12, rect.size.y * 0.42)
			canvas.draw_rect(shaft.grow(width), Defs.OUTLINE)
			canvas.draw_rect(shaft, Color8(122, 84, 52))
			var head: Vector2 = Vector2(centre.x, centre.y - rect.size.y * 0.12)
			canvas.draw_circle(head, rect.size.x * 0.20, Defs.COL_CORE_DEEP)
			canvas.draw_circle(head + Vector2(0.0, -rect.size.y * 0.04),
				rect.size.x * 0.13, Defs.COL_CORE)
			canvas.draw_circle(head + Vector2(0.0, -rect.size.y * 0.07),
				rect.size.x * 0.06, Color(1, 1, 1, 0.85))
		THING_KIT:
			# The case, with its band and its handle. The same drawing the world
			# layer makes, at whatever size the objective card asks for.
			_shadow(canvas, rect)
			var case := rect.grow(-rect.size.x * 0.16)
			_body(canvas, case, Color8(96, 104, 116), Color8(150, 160, 176), width)
			canvas.draw_rect(Rect2(case.position.x,
				case.get_center().y - case.size.y * 0.08,
				case.size.x, case.size.y * 0.16), Color8(58, 64, 74))
			canvas.draw_rect(Rect2(case.get_center().x - case.size.x * 0.06,
				case.get_center().y - case.size.y * 0.14,
				case.size.x * 0.12, case.size.y * 0.28), Color8(214, 176, 96))
			canvas.draw_arc(Vector2(case.get_center().x, case.position.y),
				case.size.x * 0.18, PI, TAU, 10, Color8(58, 64, 74), width)
		THING_CAT_FROZEN:
			# A block of ice with ears in it. The ears are what make it a cat
			# rather than a crystal -- the objective line points at this from
			# across the screen at hotbar size, where the animal inside is three
			# pixels of face.
			_shadow(canvas, rect)
			var ice := rect.grow(-rect.size.x * 0.16)
			_body(canvas, ice, Defs.COL_ICE, Color(1, 1, 1, 0.8), width)
			var ear: float = rect.size.x * 0.11
			for side: float in [-1.0, 1.0]:
				var tip: Vector2 = Vector2(ice.get_center().x + side * ice.size.x * 0.26,
					ice.position.y + ice.size.y * 0.30)
				canvas.draw_colored_polygon(PackedVector2Array([
					tip + Vector2(-ear, ear * 1.2), tip + Vector2(ear, ear * 1.2),
					tip + Vector2(side * ear * 0.4, -ear * 0.5)]), Defs.COL_CAT_FUR)
			canvas.draw_circle(ice.get_center() + Vector2(0.0, ice.size.y * 0.10),
				rect.size.x * 0.10, Defs.COL_CAT_FACE)
			# The glare that says it is ice and not stone.
			canvas.draw_line(ice.position + ice.size * Vector2(0.22, 0.62),
				ice.position + ice.size * Vector2(0.40, 0.24), Color(1, 1, 1, 0.55), width)
		THING_FOOD:
			_shadow(canvas, rect)
			var box := rect.grow(-rect.size.x * 0.18)
			var crate := Color8(96, 108, 128)
			_body(canvas, box, crate, crate.lightened(0.25), width)
			canvas.draw_rect(Rect2(box.position + Vector2(0.0, box.size.y * 0.30),
				Vector2(box.size.x, box.size.y * 0.16)), crate.darkened(0.3))
		THING_CAT:
			_shadow(canvas, rect)
			var centre: Vector2 = rect.get_center()
			var body: float = rect.size.x * 0.26
			canvas.draw_circle(centre + Vector2(0.0, body * 0.4), body, Defs.COL_CAT_FUR)
			canvas.draw_circle(centre + Vector2(0.0, -body * 0.5), body * 0.72, Defs.COL_CAT_FUR)
			for side: float in [-1.0, 1.0]:
				var tip: Vector2 = centre + Vector2(side * body * 0.5, -body * 1.05)
				canvas.draw_colored_polygon(PackedVector2Array([
					tip + Vector2(-body * 0.26, body * 0.3), tip + Vector2(body * 0.26, body * 0.3),
					tip + Vector2(side * body * 0.1, -body * 0.42)]), Defs.COL_CAT_FUR)
			canvas.draw_circle(centre + Vector2(0.0, -body * 0.45), body * 0.34, Defs.COL_CAT_FACE)
		THING_SHELTER:
			_shadow(canvas, rect)
			var walls := Rect2(rect.position + rect.size * Vector2(0.16, 0.44),
				rect.size * Vector2(0.68, 0.40))
			var ridge: Vector2 = Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.16)
			canvas.draw_colored_polygon(PackedVector2Array([
				Vector2(walls.position.x - rect.size.x * 0.06, walls.position.y), ridge,
				Vector2(walls.end.x + rect.size.x * 0.06, walls.position.y)]), Color8(66, 44, 36))
			_body(canvas, walls, Color8(84, 52, 40), Color8(104, 66, 50), width)
			var window := Rect2(walls.get_center() - walls.size * Vector2(0.18, 0.10),
				walls.size * Vector2(0.36, 0.44))
			canvas.draw_rect(window, Color(1.0, 0.74, 0.36, 0.95))
		THING_CORE:
			draw_machine(canvas, rect, Defs.M_CORE)
		THING_SEAM:
			# A seam is ore in the ground: two shards, inset, no shadow.
			var colour: Color = Defs.ITEM_COLORS[Defs.ITEM_CRYSTAL]
			for offset: Vector2 in [Vector2(-0.14, 0.06), Vector2(0.16, -0.02)]:
				var at: Vector2 = rect.get_center() + rect.size * offset
				var size: float = rect.size.x * (0.20 if offset.x < 0.0 else 0.26)
				canvas.draw_colored_polygon(PackedVector2Array([
					at + Vector2(0.0, -size), at + Vector2(size * 0.8, size * 0.5),
					at + Vector2(-size * 0.8, size * 0.5)]), colour)
				canvas.draw_polyline(PackedVector2Array([
					at + Vector2(0.0, -size), at + Vector2(size * 0.8, size * 0.5),
					at + Vector2(-size * 0.8, size * 0.5), at + Vector2(0.0, -size)]),
					Defs.ORE_OUTLINE, width)

## What each grade looks like, as artwork rather than as a letter and a colour.
##
## Still images, which is not a compromise in the place they are used: the gacha
## result is a card, and a card is exactly where a drawing of an animal standing
## still is the right picture. The world is a different question and is not
## answered here -- there a cat has to walk in three directions, eat and work,
## which is six generated clips per grade. Until those exist every grade plays
## cat_org's sheets in the world and is told apart by the ring on the ground.
##
## SSR has no entry because the SSR is a pig, and the pig is drawn.
const GRADE_PORTRAITS: Array[Texture2D] = [
	preload("res://assets/portraits/o.png"),
	preload("res://assets/portraits/n.png"),
	preload("res://assets/portraits/r.png"),
	preload("res://assets/portraits/sr.png"),
]

## The one place that knows what a grade looks like. Everything that shows a
## pulled cat goes through here, so the pig can never end up being the only
## thing that remembers it is not a cat.
static func draw_grade(canvas: CanvasItem, rect: Rect2, grade: int) -> void:
	if grade < 0 or grade >= GRADE_PORTRAITS.size():
		draw_pig(canvas, rect)
		return
	var art: Texture2D = GRADE_PORTRAITS[grade]
	var source: Vector2 = Vector2(art.get_size())
	if source.x <= 0.0 or source.y <= 0.0:
		return
	# Fitted rather than stretched, and stood on the floor of the rect: these are
	# animals on their feet, and centring them vertically leaves them hovering.
	var fit: float = minf(rect.size.x / source.x, rect.size.y / source.y)
	var drawn: Vector2 = source * fit
	canvas.draw_texture_rect(art, Rect2(
		rect.position + Vector2((rect.size.x - drawn.x) * 0.5, rect.size.y - drawn.y),
		drawn), false)

## The SSR cat, which is a pig.
##
## Drawn, not generated. Every other cat plays an eight-frame sheet cut out of a
## video, and one more sheet is a generation run plus a pipeline pass. A pig is a
## shape this drawing language can state exactly -- round body, two soft ears, a
## snout with two nostrils, a curl of tail -- so it is stated, built on the cat
## icon's own proportions so the two stand in a line together without one of them
## looking like it wandered in from another game.
##
## Front-facing always. The pig has no side view and inventing one out of the
## same primitives would be a worse picture than the one that works, so a walking
## pig is a pig walking toward you. `step` drives the legs; pass 0 to stand still.
##
## Fills the rect it is handed, like every icon here, which is what lets the same
## function draw a 40px result tile and a 58px animal in the snow.
static func draw_pig(canvas: CanvasItem, rect: Rect2, step: float = 0.0) -> void:
	var box: Rect2 = rect.abs()
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return
	var centre_x: float = box.position.x + box.size.x * 0.5
	var line: float = maxf(1.0, box.size.x / 26.0)
	var body: float = minf(box.size.x * 0.40, box.size.y * 0.30)
	var body_at := Vector2(centre_x, box.position.y + box.size.y * 0.66)
	var head: float = body * 0.82
	var head_at := Vector2(centre_x, box.position.y + box.size.y * 0.29)

	# Legs first, so the body sits on top of them rather than beside them.
	for side: float in [-1.0, 1.0]:
		var phase: float = step
		if side > 0.0:
			phase = step + PI
		var swing: float = sin(phase) * box.size.y * 0.045
		var leg := Rect2(centre_x + side * body * 0.54 - box.size.x * 0.06,
			body_at.y + body * 0.46 + swing, box.size.x * 0.12, box.size.y * 0.15)
		canvas.draw_rect(leg, Defs.COL_PIG_SNOUT)
		canvas.draw_rect(leg, Defs.OUTLINE, false, line * 0.7)
	# The curl. One detail carries the whole reading: without it a pink circle is
	# a pink circle, and with it nobody has to be told what they pulled.
	canvas.draw_arc(Vector2(centre_x - body * 1.05, body_at.y - body * 0.26), body * 0.30,
		-PI * 0.45, PI * 1.45, 16, Defs.COL_PIG_SNOUT, line * 1.2)

	canvas.draw_circle(body_at, body, Defs.COL_PIG_BODY)
	canvas.draw_circle(body_at - Vector2(body * 0.30, body * 0.34), body * 0.42,
		Defs.COL_PIG_BODY.lightened(Defs.FACE_LIGHT))
	# Ears behind the head, the way the cat icon does it.
	for side: float in [-1.0, 1.0]:
		var tip: Vector2 = head_at + Vector2(side * head * 0.70, -head * 0.60)
		canvas.draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-head * 0.30, head * 0.34), tip + Vector2(head * 0.30, head * 0.34),
			tip + Vector2(side * head * 0.16, -head * 0.46)]), Defs.COL_PIG_SNOUT)
	canvas.draw_circle(head_at, head, Defs.COL_PIG_BODY)
	canvas.draw_circle(head_at - Vector2(head * 0.28, head * 0.30), head * 0.40,
		Defs.COL_PIG_BODY.lightened(Defs.FACE_LIGHT))
	for side: float in [-1.0, 1.0]:
		canvas.draw_circle(head_at + Vector2(side * head * 0.40, -head * 0.16),
			maxf(1.0, head * 0.12), Defs.OUTLINE)
	var snout := Rect2(head_at.x - head * 0.40, head_at.y + head * 0.16,
		head * 0.80, head * 0.52)
	canvas.draw_rect(snout, Defs.COL_PIG_SNOUT)
	canvas.draw_rect(snout, Defs.OUTLINE, false, line * 0.7)
	for side: float in [-1.0, 1.0]:
		canvas.draw_circle(snout.get_center() + Vector2(side * snout.size.x * 0.20, 0.0),
			maxf(0.8, snout.size.x * 0.11), Defs.OUTLINE)
