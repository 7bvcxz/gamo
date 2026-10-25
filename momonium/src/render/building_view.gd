class_name BuildingView
extends Node2D

## One building on the island: its sprite standing on its footprint, a soft
## highlight on the ground when selected, and a ring above it while it works
## (filling) or cools down (emptying). Reads its building record every frame;
## owns no game state.

const RING_RADIUS := 13.0
const RING_WIDTH := 4.0

var id := 0
var buildings: BuildingSystem
var projection: IsoProjection
var selected := false:
	set(value):
		selected = value
		queue_redraw()
## While a Momo is carried over this building: 1 can work here, -1 cannot.
var drop_hint := 0:
	set(value):
		drop_hint = value
		queue_redraw()
var sprite: Sprite2D
## Crops and other stage looks, drawn over the base sprite.
var overlay: Sprite2D
var ring: Node2D
var _lib: SpriteLibrary
var _look := ""
var _top := Vector2(0, -60)
var _bounce := 0.0
var _shake := 0.0
var _celebrate := 0.0
var _base_scale := Vector2.ONE


func setup(p_id: int, p_buildings: BuildingSystem, p_projection: IsoProjection, lib: SpriteLibrary) -> void:
	id = p_id
	buildings = p_buildings
	projection = p_projection
	name = "Building_%d" % id
	var b := buildings.get_building(id)
	var sprite_name: String = buildings.type_def(b).get("sprite", "")
	sprite = lib.make_sprite(sprite_name) if lib.has(sprite_name) else Sprite2D.new()
	add_child(sprite)
	_base_scale = sprite.scale
	_lib = lib
	overlay = Sprite2D.new()
	overlay.visible = false
	sprite.add_child(overlay)
	if lib.has(sprite_name):
		_top = (lib.pivot(sprite_name, "top") - lib.pivot(sprite_name, "origin")) * lib.world_scale(sprite_name)
	ring = Node2D.new()
	ring.z_index = 5
	ring.draw.connect(_draw_ring)
	add_child(ring)


## World-space rectangle a tap can land on.
func hit_rect() -> Rect2:
	if sprite.texture == null:
		return Rect2(position - Vector2(30, 30), Vector2(60, 60))
	var r := sprite.region_rect
	var s := sprite.scale
	return Rect2(position + sprite.offset * s, r.size * s)


func pulse() -> void:
	_bounce = 1.0


func refuse() -> void:
	_shake = 1.0


func celebrate() -> void:
	_celebrate = 1.0
	_bounce = 1.0


func _process(delta: float) -> void:
	_bounce = maxf(0.0, _bounce - delta * 4.0)
	_shake = maxf(0.0, _shake - delta * 3.5)
	_celebrate = maxf(0.0, _celebrate - delta * 1.2)
	var k := sin(_bounce * PI) * 0.08
	sprite.position = Vector2(sin(_shake * 40.0) * 3.0 * _shake, -k * 20.0)
	var b := buildings.get_building(id)
	if not b.is_empty() and b["state"] == BuildingSystem.CONSTRUCTING:
		# Under construction the building grows up out of its plot, half seen.
		var p := buildings.progress(b)
		var rise := 0.3 + 0.7 * (1.0 - pow(1.0 - p, 2.0))
		sprite.scale = Vector2(_base_scale.x, _base_scale.y * rise)
		sprite.modulate = Color(1, 1, 1, 0.35 + 0.5 * p)
	else:
		sprite.scale = _base_scale
		sprite.modulate = Color.WHITE
	if not b.is_empty():
		_update_look(buildings.look(b))
	ring.queue_redraw()


func _update_look(look_name: String) -> void:
	if look_name == _look:
		return
	_look = look_name
	if look_name == "" or not _lib.has(look_name):
		overlay.visible = false
		return
	_lib.place(overlay, look_name)
	# The overlay is a child of the base sprite, which already carries the
	# world scale and the base offset; express it in the base's own frame.
	overlay.scale = Vector2.ONE * (_lib.world_scale(look_name) / maxf(_base_scale.x, 0.0001))
	overlay.position = Vector2.ZERO
	overlay.offset = -_lib.pivot(look_name)
	overlay.visible = true


func _draw() -> void:
	if not selected and drop_hint == 0:
		return
	var b := buildings.get_building(id)
	var fill := Color(1, 0.95, 0.6, 0.18)
	var line := Color(1, 0.93, 0.45, 0.95)
	if drop_hint == 1:
		fill = Color(0.45, 0.95, 0.5, 0.3)
		line = Color(0.6, 1.0, 0.6, 1.0)
	elif drop_hint == -1:
		fill = Color(1.0, 0.35, 0.3, 0.3)
		line = Color(1.0, 0.45, 0.4, 1.0)
	for cell: Vector2i in buildings.cells_of(b):
		var c := projection.cell_corners(cell)
		var local := PackedVector2Array()
		for p: Vector2 in c:
			local.append(p - position)
		var loop := local.duplicate()
		loop.append(local[0])
		draw_colored_polygon(local, fill)
		draw_polyline(loop, line, 3.0, true)


func _draw_ring() -> void:
	var b := buildings.get_building(id)
	if b.is_empty():
		return
	var centre := _top + Vector2(0, -18)
	if _celebrate > 0.0:
		for i in 8:
			var a := TAU * i / 8.0 + (1.0 - _celebrate) * 2.0
			var r := 20.0 + (1.0 - _celebrate) * 34.0
			ring.draw_circle(_top * 0.5 + Vector2(cos(a) * r, sin(a) * r * 0.6), 3.5 * _celebrate, Color(1, 0.93, 0.5, _celebrate))
	if b["state"] == BuildingSystem.WORKING:
		_draw_work_effect(String(buildings.current_stage(b).get("action", "")), buildings.progress(b))
	_draw_power(b)
	match String(b["state"]):
		BuildingSystem.CONSTRUCTING:
			var p := buildings.progress(b)
			# Scaffold posts at the footprint corners, fading as the work completes.
			for cell: Vector2i in buildings.cells_of(b):
				for corner: Vector2 in projection.cell_corners(cell):
					var foot := corner - position
					ring.draw_line(foot, foot + Vector2(0, -46), Color(0.55, 0.38, 0.2, 0.9 * (1.0 - p * 0.6)), 3.0, true)
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.55))
			ring.draw_arc(centre, RING_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.25), RING_WIDTH, true)
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * p, 32, Color("#ffc94d"), RING_WIDTH, true)
		BuildingSystem.WORKING:
			var p := buildings.progress(b)
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.55))
			ring.draw_arc(centre, RING_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.25), RING_WIDTH, true)
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * p, 32, Color("#9be15d"), RING_WIDTH, true)
		BuildingSystem.IDLE:
			_draw_blocked(b, centre)
		BuildingSystem.COOLDOWN:
			var total := maxf(float(int(b["ready_at"]) - int(b["task_end"])), 1.0)
			var left := float(buildings.remaining_ms(b)) / total
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.45))
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * left, 32, Color(0.75, 0.85, 1.0, 0.8), RING_WIDTH, true)


## Generators move with what they give: blades turning with the wind, the
## wheel turning steadily, smoke from a fired boiler. A powered building at
## work wears a small bolt -- bright when it got all its power, dim when not.
func _draw_power(b: Dictionary) -> void:
	var power: PowerSystem = buildings.sim.system(&"power")
	if power == null or b["state"] == BuildingSystem.CONSTRUCTING:
		return
	var type := String(b["type"])
	var now := buildings.sim.now_ms()
	var t := now / 1000.0
	var sprite_name := String(buildings.type_def(b).get("sprite", ""))
	var origin := _lib.pivot(sprite_name, "origin") if _lib.has(sprite_name) else Vector2.ZERO
	var ws := _lib.world_scale(sprite_name) if _lib.has(sprite_name) else 0.5
	match String(power.generator_def(type).get("kind", "")):
		"wind":
			var hub := (_lib.pivot(sprite_name, "hub") - origin) * ws
			var a := t * 6.0 * power.wind(now)
			for i in 3:
				var dir := Vector2.from_angle(a + TAU * i / 3.0)
				ring.draw_line(hub, hub + dir * 30.0, Color(0.96, 0.97, 0.98), 4.0, true)
				ring.draw_line(hub, hub + dir * 30.0, Color(0.6, 0.65, 0.7, 0.6), 1.0, true)
			ring.draw_circle(hub, 3.0, Color(0.8, 0.83, 0.87))
		"hydro":
			var hub := (_lib.pivot(sprite_name, "hub") - origin) * ws
			ring.draw_arc(hub, 14.0, 0, TAU, 24, Color(0.55, 0.36, 0.2), 3.0, true)
			for i in 8:
				var dir := Vector2.from_angle(t * 1.6 + TAU * i / 8.0)
				ring.draw_line(hub, hub + dir * 14.0, Color(0.66, 0.45, 0.25), 2.0, true)
				ring.draw_rect(Rect2(hub + dir * 14.0 - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.55, 0.36, 0.2))
		"steam":
			if power.output_of(int(b["id"]), now) > 0.0:
				var stack := (_lib.pivot(sprite_name, "stack") - origin) * ws
				for i in 3:
					var k := fposmod(t * 0.6 + i / 3.0, 1.0)
					ring.draw_circle(stack + Vector2(sin(k * 5.0 + i) * 4.0, -k * 30.0), 3.0 + k * 5.0, Color(0.9, 0.9, 0.92, 0.7 * (1.0 - k)))
	if b["state"] == BuildingSystem.WORKING and not power.use_of(type).is_empty():
		var share := float(power.shares.get(int(b["id"]), 1.0))
		var c := _top + Vector2(26, -18)
		var col := Color("#ffd84d") if share >= 0.999 else Color(1.0, 0.6, 0.3, 0.9)
		ring.draw_circle(c, 9.0, Color(0.09, 0.25, 0.47, 0.8))
		ring.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -7), c + Vector2(-4, 1), c + Vector2(0, 1), c + Vector2(-2, 7), c + Vector2(4, -1), c + Vector2(0, -1)]), col)


## A building that cannot start shows why, without words: the item it lacks
## on a white disc, struck through in red -- or, when its output has nowhere
## to go, that item ringed in orange (the store is full).
func _draw_blocked(b: Dictionary, centre: Vector2) -> void:
	var block := buildings.blocked(b)
	if block.is_empty():
		return
	var missing := block.has("missing") or block.has("crew")
	var icon := "momo_front"
	if not block.has("crew"):
		var items: Dictionary = block.get("missing", block.get("full", {}))
		if items.is_empty():
			return
		icon = String(buildings.sim.data.item(String(items.keys()[0])).get("icon", ""))
	var red := Color("#ff5a4f") if missing else Color("#ffa53a")
	ring.draw_circle(centre, RING_RADIUS + 6, Color(1, 1, 1, 0.94))
	ring.draw_arc(centre, RING_RADIUS + 6, 0, TAU, 32, red, 3.0, true)
	if _lib.has(icon):
		ring.draw_texture_rect_region(_lib.texture, Rect2(centre - Vector2(13, 13), Vector2(26, 26)), _lib.region(icon))
	if missing:
		ring.draw_line(centre + Vector2(-13, 13), centre + Vector2(13, -13), red, 3.0, true)


## A little of what the work looks like: seeds dropping, water arcing down,
## ripe crops hopping up. Drawn from progress, so it is the same at any speed.
func _draw_work_effect(action: String, p: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	match action:
		"sow":
			for i in 6:
				var k := fposmod(t * 1.6 + i / 6.0, 1.0)
				var x := -26.0 + i * 10.0
				ring.draw_circle(Vector2(x, -30.0 + k * 28.0), 2.2, Color(0.93, 0.85, 0.6, 1.0 - k))
		"water":
			for i in 10:
				var k := fposmod(t * 2.2 + i / 10.0, 1.0)
				var x := lerpf(-30.0, 30.0, i / 9.0)
				ring.draw_circle(Vector2(x + sin(i) * 4.0, -34.0 + k * 34.0), 2.0, Color(0.55, 0.82, 1.0, 0.9 * (1.0 - k)))
			ring.draw_arc(Vector2(0, 2), 26.0 * (0.6 + 0.4 * fposmod(t * 2.0, 1.0)), 0, TAU, 24, Color(0.7, 0.9, 1.0, 0.35), 2.0, true)
		"harvest":
			for i in 5:
				var k := fposmod(t * 1.3 + i / 5.0, 1.0)
				var x := -24.0 + i * 12.0
				ring.draw_circle(Vector2(x, -10.0 - sin(k * PI) * 26.0), 4.0, Color(0.92, 0.27, 0.18, 1.0 - k * 0.5))
