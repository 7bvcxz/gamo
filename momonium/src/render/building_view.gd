class_name BuildingView
extends Node2D

## One building on the island: its sprite standing on its footprint, a soft
## highlight on the ground when selected, and a ring above it while it works
## (filling) or cools down (emptying). Reads its building record every frame;
## owns no game state.

const RING_RADIUS := 13.0
const RING_WIDTH := 4.0
## The world's night tint (set by DayNight): lights divide by it to stay warm.
static var ambient := Color.WHITE

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
var _sparkle := 0.0
var _base_scale := Vector2.ONE
var _sprite_name := ""
## Read once: art settings the per-frame drawing needs.
var _lights_cfg: Dictionary = {}
var _evolution: Dictionary = {}
## The pennant tier, kept until mastery or the building changes.
var _pennant := -1
## Its lit windows (Step 52), when the drawing has any.
var lit: Sprite2D


func setup(p_id: int, p_buildings: BuildingSystem, p_projection: IsoProjection, lib: SpriteLibrary) -> void:
	id = p_id
	buildings = p_buildings
	projection = p_projection
	name = "Building_%d" % id
	var b := buildings.get_building(id)
	var sprite_name: String = buildings.type_def(b).get("sprite", "")
	_sprite_name = sprite_name
	sprite = lib.make_sprite(sprite_name) if lib.has(sprite_name) else Sprite2D.new()
	add_child(sprite)
	_base_scale = sprite.scale
	_lib = lib
	overlay = Sprite2D.new()
	overlay.visible = false
	sprite.add_child(overlay)
	# Step 52: its window panes, painted warm, laid over it after dusk.
	if lib.has(sprite_name + "_lit"):
		lit = Sprite2D.new()
		lit.name = "Lit"
		lib.place(lit, sprite_name + "_lit")
		lit.scale = Vector2.ONE * (lib.world_scale(sprite_name + "_lit") / maxf(_base_scale.x, 0.0001))
		lit.visible = false
		sprite.add_child(lit)
	if lib.has(sprite_name):
		_top = (lib.pivot(sprite_name, "top") - lib.pivot(sprite_name, "origin")) * lib.world_scale(sprite_name)
	_lights_cfg = buildings.sim.data.get_value("art", "night_lights", {})
	_evolution = buildings.sim.data.get_value("art", "evolution", {})
	refresh_pennant()
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


## Where pops and stars go: the top of the drawing, in the layer's space.
func top_point() -> Vector2:
	return position + _top


func pulse() -> void:
	if FxPrefs.moving():
		_bounce = 1.0


func refuse() -> void:
	_shake = 1.0


func celebrate() -> void:
	if not FxPrefs.enabled:
		return
	_celebrate = 1.0
	if FxPrefs.moving():
		_bounce = 1.0


## A few small stars above it: a Momo finished a job here, or learned something.
func sparkle() -> void:
	if FxPrefs.enabled:
		_sparkle = 1.0


## Step 68: a Momo's job here is done (a real `task_completed`, BuildingViews,
## never while time away is caught up) -- the THUNK: the progress ring the eye
## was following bursts -- a thick bright ring snaps out from it with six
## rays and fades -- the building gives a squash, the stars rise. Over the
## building, not at its foot, where the Momo stands in front of it. Once per
## completion. Reduced motion: the ring flashes in place, no squash. Effects
## off: nothing.
var _impact := 0.0
## How many it showed (tests).
var impacts := 0


func impact() -> void:
	if not FxPrefs.enabled:
		return
	impacts += 1
	_impact = 1.0
	_sparkle = 1.0
	if FxPrefs.moving():
		_bounce = maxf(_bounce, 0.7)


## Zoomed far out (set by BuildingViews): small motions at a lower rate.
var far := false
## Ring redraws so far (tests and the performance view).
var ring_draws := 0
var _since_draw := INF
var _drawn_state := ""
var _moves_type := ""
var _moves := false
## A building with nothing in motion redraws its ring this often (the night
## lights' flicker, the pennant's wave); one at work, building, cooling down,
## celebrating or turning (a generator, a landmark) every frame -- or this
## often when zoomed far out.
const AMBIENT_REDRAW_SECONDS := 0.1
const FAR_REDRAW_SECONDS := 0.1


func _process(delta: float) -> void:
	_bounce = maxf(0.0, _bounce - delta * 4.0)
	_shake = maxf(0.0, _shake - delta * 3.5)
	_celebrate = maxf(0.0, _celebrate - delta * 1.2)
	_sparkle = maxf(0.0, _sparkle - delta * 1.6)
	_impact = maxf(0.0, _impact - delta * 3.0)
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
	_since_draw += delta
	var state := String(b.get("state", ""))
	var every := 0.0 if _in_motion(b) else AMBIENT_REDRAW_SECONDS
	if far:
		every = maxf(every, FAR_REDRAW_SECONDS)
	if state != _drawn_state or _since_draw >= every:
		_drawn_state = state
		_since_draw = 0.0
		ring_draws += 1
		ring.queue_redraw()


## Whether its ring moves frame to frame: a progress arc, a celebration or
## sparkle, turning blades, a landmark's glint.
func _in_motion(b: Dictionary) -> bool:
	if _celebrate > 0.0 or _sparkle > 0.0 or _impact > 0.0:
		return true
	if b.is_empty():
		return false
	if String(b["state"]) in [BuildingSystem.WORKING, BuildingSystem.CONSTRUCTING, BuildingSystem.COOLDOWN]:
		return true
	var type := String(b["type"])
	if type != _moves_type:
		_moves_type = type
		var power: PowerSystem = buildings.sim.system(&"power")
		_moves = buildings.is_special(type) or (power != null and String(power.generator_def(type).get("kind", "")) != "")
	return _moves


func _update_look(look_name: String) -> void:
	if look_name == _look:
		return
	# A crop changing (sprout to leaves to ripe) gives a small hop.
	if _look != "" or look_name != "":
		_bounce = maxf(_bounce, 0.6)
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
		_draw_smoke(b)
	_draw_power(b)
	_draw_lights(b)
	_draw_pennant(b)
	_draw_special(b)
	if _impact > 0.0:
		_draw_impact()
	if _sparkle > 0.0:
		for i in 5:
			var a := TAU * i / 5.0 + _sparkle
			var r := 10.0 + (1.0 - _sparkle) * 18.0
			var p := _top * 0.6 + Vector2(cos(a) * r, sin(a) * r * 0.6 - (1.0 - _sparkle) * 10.0)
			ring.draw_circle(p, 2.5 * _sparkle, Color(1, 0.97, 0.7, _sparkle))
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
			# A little dust at its feet while it goes up.
			var t := buildings.sim.now_ms() / 1000.0
			for i in 4:
				var k := fposmod(t * 0.7 + i / 4.0, 1.0)
				var side := -1.0 if i % 2 == 0 else 1.0
				ring.draw_circle(Vector2(side * (14.0 + k * 16.0), 6.0 - k * 10.0), 3.0 + k * 4.0, Color(0.86, 0.78, 0.62, 0.45 * (1.0 - k)))
		BuildingSystem.WORKING:
			var p := buildings.progress(b)
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.55))
			ring.draw_arc(centre, RING_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.25), RING_WIDTH, true)
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * p, 32, Color("#9be15d"), RING_WIDTH, true)
			# Step 68: the arc's leading end, a small bead that brightens and
			# grows in the last part of the stage -- where the work is, how
			# near the THUNK. From the stage's own progress; it never pulses.
			var tip := centre + Vector2.from_angle(-PI / 2 + TAU * p) * RING_RADIUS
			var near := clampf((p - 0.8) / 0.2, 0.0, 1.0)
			ring.draw_circle(tip, 2.6 + near * 1.6, Color(0.09, 0.25, 0.47, 0.9))
			ring.draw_circle(tip, 1.7 + near * 1.4, Color("#eaffcf").lerp(Color.WHITE, near))
		BuildingSystem.IDLE:
			_draw_blocked(b, centre)
		BuildingSystem.COOLDOWN:
			var total := maxf(float(int(b["ready_at"]) - int(b["task_end"])), 1.0)
			var left := float(buildings.remaining_ms(b)) / total
			ring.draw_circle(centre, RING_RADIUS + 3, Color(0.09, 0.25, 0.47, 0.45))
			ring.draw_arc(centre, RING_RADIUS, -PI / 2, -PI / 2 + TAU * left, 32, Color(0.75, 0.85, 1.0, 0.8), RING_WIDTH, true)


func _draw_impact() -> void:
	var k := _impact
	var at := _top + Vector2(0, -18)
	var r := (RING_RADIUS + (1.0 - k) * 26.0) if FxPrefs.moving() else RING_RADIUS + 8.0
	var a := clampf(k * 1.5, 0.0, 1.0)
	var dark := Color(0.06, 0.14, 0.3, 0.9 * a)
	var light := Color(1.0, 0.95, 0.62, a)
	ring.draw_arc(at, r, 0, TAU, 40, dark, 8.0, true)
	ring.draw_arc(at, r, 0, TAU, 40, light, 4.5, true)
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 + 0.3)
		var from := at + d * (r + 5.0)
		var to := at + d * (r + 5.0 + 12.0 * k)
		ring.draw_line(from, to, dark, 6.0, true)
		ring.draw_line(from, to, light, 3.0, true)


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


## Furnaces and workshops at work breathe a little smoke from the roof.
func _draw_smoke(b: Dictionary) -> void:
	if not String(b["type"]) in ["smelter", "car_factory", "game_studio", "steam_engine"]:
		return
	var t := buildings.sim.now_ms() / 1000.0
	var stack := _top + Vector2(-6, 8)
	for i in 3:
		var k := fposmod(t * 0.5 + i / 3.0, 1.0)
		ring.draw_circle(stack + Vector2(sin(k * 4.0 + i) * 4.0, -k * 26.0), 2.5 + k * 5.0, Color(0.88, 0.88, 0.9, 0.55 * (1.0 - k)))


## Warm windows after dusk: brighter the darker it is. The colour is divided
## by the night tint the whole world gets, so it stays warm on the screen.
## Step 52: the panes themselves light up -- the `_lit` sprite traced from the
## painting -- instead of two dots near the roof that matched no window. They
## are fully lit by mid-evening: half-lit, warm over blue glass reads as beige.
func _draw_lights(b: Dictionary) -> void:
	if lit == null:
		return
	var night := night_strength(ambient, float(_lights_cfg.get("start", 0.25)))
	lit.visible = night > 0.01 and b["state"] != BuildingSystem.CONSTRUCTING
	if not lit.visible:
		return
	var warm := Color(String(_lights_cfg.get("color", "#ffd98a")))
	var t := buildings.sim.now_ms() / 1000.0
	var flicker := 0.92 + 0.08 * sin(t * 3.1 + id * 1.7)
	lit.modulate = Color(minf(warm.r / maxf(ambient.r, 0.2), 4.0), minf(warm.g / maxf(ambient.g, 0.2), 4.0), minf(warm.b / maxf(ambient.b, 0.2), 4.0), minf(1.0, night * 2.2) * flicker)


## A pennant on the four families as their mastery grows: bronze, silver, gold.
func _draw_pennant(b: Dictionary) -> void:
	if b["state"] == BuildingSystem.CONSTRUCTING or buildings.is_special(String(b["type"])):
		return
	var tier := _pennant
	# Step 72: after a Golden Age every building flies a gold pennant, and after
	# a Civilization each carries a star -- the milestone seen on the island.
	var age := golden_age()
	if tier < 0 and age == 0:
		return
	var col := Color(String((_evolution.get("colors", ["#ffd45a"]) as Array)[tier])) if age == 0 else GOLDEN
	var t := buildings.sim.now_ms() / 1000.0
	var pole := _top + Vector2(20, 14)
	ring.draw_line(pole, pole + Vector2(0, -18), Color(0.4, 0.28, 0.16), 2.0, true)
	var wave := sin(t * 2.0 + id) * 1.5
	ring.draw_colored_polygon(PackedVector2Array([pole + Vector2(0, -18), pole + Vector2(11, -14 + wave), pole + Vector2(0, -10)]), col)
	if age >= 2:
		var c := pole + Vector2(0, -22)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2 + k * PI / 5
			pts.append(c + Vector2(cos(a), sin(a)) * (3.6 if k % 2 == 0 else 1.6))
		ring.draw_colored_polygon(pts, Color(1, 1, 0.92))


const GOLDEN := Color("#ffc93c")


## Step 72: 0 before a Golden Age, 1 after it, 2 after a whole Civilization.
func golden_age() -> int:
	var goals: GoalSystem = buildings.sim.system(&"goals")
	if goals == null:
		return 0
	return 2 if goals.reached.has("civilization") else (1 if goals.reached.has("golden_age") else 0)


## The landmarks' own life: the Clock Tower's hands race and it glows gold
## during a burst; the Monument catches the light now and then.
func _draw_special(b: Dictionary) -> void:
	if b["state"] == BuildingSystem.CONSTRUCTING:
		return
	var type := String(b["type"])
	var t := buildings.sim.now_ms() / 1000.0
	var ws := _lib.world_scale(_sprite_name) if _lib.has(_sprite_name) else 0.5
	var origin := _lib.pivot(_sprite_name, "origin") if _lib.has(_sprite_name) else Vector2(70, 95)
	match type:
		"clock_tower":
			var sp: SpecialSystem = buildings.sim.system(&"specials")
			var on := sp != null and bool(sp.burst()["active"])
			var speed := 6.0 if on else 0.3
			# The painted faces' centres are pivots (pixels, like `origin`): a
			# frame-unit point minus a pixel pivot put the hands on the roof.
			for pv: String in ["face_l", "face_r"]:
				if not _lib.has(_sprite_name) or not (_lib.sprites[_sprite_name]["pivots"] as Dictionary).has(pv):
					continue
				var c := (_lib.pivot(_sprite_name, pv) - origin) * ws
				# Step 52: the redrawn dials are larger -- an hour and a minute hand.
				ring.draw_line(c, c + Vector2.from_angle(t * speed / 12.0 - PI * 0.5) * 2.4, Color(0.23, 0.19, 0.16), 1.3, true)
				ring.draw_line(c, c + Vector2.from_angle(t * speed - PI * 0.5) * 3.5, Color(0.23, 0.19, 0.16), 1.0, true)
			if on:
				var pulse := 0.5 + 0.5 * sin(t * 4.0)
				ring.draw_arc(_top * 0.5, 22.0 + pulse * 4.0, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.35 + 0.25 * pulse), 3.0, true)
		"momo_monument":
			var k := fposmod(t / 6.0 + id * 0.37, 1.0)
			if k < 0.12:
				var g := sin(k / 0.12 * PI)
				var at := _top + Vector2(4, 18)
				ring.draw_line(at + Vector2(-6 * g, 0), at + Vector2(6 * g, 0), Color(1, 1, 0.9, g), 2.0, true)
				ring.draw_line(at + Vector2(0, -6 * g), at + Vector2(0, 6 * g), Color(1, 1, 0.9, g), 2.0, true)


## How strongly windows glow under this night tint: 0 by day, up to 1.
static func night_strength(tint: Color, start: float = 0.25) -> float:
	var lum := tint.r * 0.3 + tint.g * 0.55 + tint.b * 0.15
	return clampf((1.0 - lum - start) * 2.0, 0.0, 1.0)


## Which pennant its family's mastery has earned: -1 none, 0 bronze, 1 silver, 2 gold.
func pennant_tier() -> int:
	var b := buildings.get_building(id)
	if b.is_empty() or buildings.is_special(String(b["type"])):
		return -1
	var fam := buildings.family_of(String(b["type"]))
	var levels: Array = (_evolution if not _evolution.is_empty() else buildings.sim.data.get_value("art", "evolution", {})).get("levels", [])
	var lv := int((buildings.sim.system(&"progression") as ProgressionSystem).mastery_of(fam)["level"])
	var tier := -1
	for i in levels.size():
		if lv >= int(levels[i]):
			tier = i
	return tier


func refresh_pennant() -> void:
	_pennant = pennant_tier()
