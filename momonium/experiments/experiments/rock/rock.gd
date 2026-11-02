extends LabExperiment

## Experiment C -- Break & Upgrade. A giant rock stands on a tiny island the
## moment the experiment opens. Tap it: the glove swings the pickaxe, chips
## fly, a damage number pops, the bar drops and cracks open. At zero it bursts
## into pieces and a shower of coins; spend them on the one button, Pickaxe
## Power, and the next rock -- harder, bigger, richer -- rises in its place.
## The Giant Crystal on the far islet is the distant goal. The action is the
## tap (unlike A's passive growth): one tap is exactly one hit, a tap that
## misses the rock or lands while the next one rises does nothing.
##
## Every number is RockLevels; nothing is random but the look of the chips.

const RISE_SECONDS := 0.5
const SWING_SECONDS := 0.26

var coins := 0
var earned := 0
var pick := 0
var rock_index := 0
var hp := 0
var max_hp := 0
var taps := 0
var hits := 0
var misses := 0
var damage_total := 0
var breaks := 0
var first_break_ms := -1
var rise_left := 0.0

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var rock_view: RockView
var goal_view: RockView
var goal_world: Node2D
var momo: LabMomo
var swing: _Swing
var bits: _Bits
var bar: _HpBar
var chip: PanelContainer
var chip_label: Label
var _pick_tex: AtlasTexture
var _scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ocean = LabOcean.new()
	add_child(ocean)
	goal_world = Node2D.new()
	goal_world.name = "Goal"
	add_child(goal_world)
	var far := LabIsland.new()
	far.set_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	goal_world.add_child(far)
	goal_view = RockView.new()
	goal_view.setup(RockLevels.rock(RockLevels.GOAL), 9)
	goal_view.position = far.iso.cell_center(Vector2i(1, 1)) + Vector2(0, -49)
	far.add_child(goal_view)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	island = LabIsland.new()
	var cells: Array[Vector2i] = []
	for x in 3:
		for y in 3:
			cells.append(Vector2i(x, y))
	island.set_cells(cells)
	world.add_child(island)
	ocean.follow(island)
	momo = LabMomo.new()
	momo.reduced_motion = reduced_motion
	momo.position = island.iso.cell_center(Vector2i(0, 2)) + Vector2(-10, 0)
	island.add_child(momo)
	rock_view = RockView.new()
	rock_view.position = island.iso.cell_center(Vector2i(1, 1)) + Vector2(0, 10)
	island.add_child(rock_view)
	bits = _Bits.new()
	world.add_child(bits)
	swing = _Swing.new()
	swing.reduced_motion = reduced_motion
	world.add_child(swing)
	bar = _HpBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_build_chip()
	_pick_tex = LabGlove.tool_texture("pickaxe")
	_set_rock(0)
	resized.connect(_layout)
	_layout()
	if audio != null:
		audio.start_ambience(false)


# --- the hit ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	# The mouse copy of a touch, or a click: one press, one hit. (The Lab stops
	# the touch itself before the UI, so a finger is never counted twice.)
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	tap_at(mb.position)


## A tap at `local` (this Control's coordinates): a hit if it is on the rock.
func tap_at(local: Vector2) -> void:
	taps += 1
	var on_rock := rock_view.hit_test(rock_view.get_global_transform().affine_inverse() * (get_global_transform() * local))
	if not on_rock:
		misses += 1
		session.action("tap_miss")
		return
	if rise_left > 0.0 or hp <= 0:
		session.action("tap_wait")
		return
	hit(local)


## One hit of the pickaxe at `local`.
func hit(local: Vector2) -> void:
	var dmg := RockLevels.damage(pick)
	hits += 1
	damage_total += dmg
	hp = maxi(0, hp - dmg)
	session.action("hit", {"damage": dmg, "rock": rock_index})
	rock_view.damage_frac = 1.0 - float(hp) / float(max_hp)
	bar.set_hp(hp, max_hp, not reduced_motion)
	var at_world := world.get_global_transform().affine_inverse() * (get_global_transform() * local)
	swing.strike(at_world, RockLevels.tint(pick), _scale)
	if not reduced_motion:
		bits.burst(at_world, rock_view.body, rock_index >= 4, 6)
		rock_view.squash = 1.0
		var tw := rock_view.create_tween()
		tw.tween_property(rock_view, "squash", 0.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if fx != null:
		fx.float_text(to_fx(get_global_transform() * local) + Vector2(0, -40), "-%d" % dmg, Color.WHITE, 34)
	if audio != null:
		audio.play("metal" if rock_index >= 4 else "pick", 1.0 + 0.04 * float(hits % 3), -2.0, 0.06)
	if hp <= 0:
		_break()


func _break() -> void:
	var r := RockLevels.rock(rock_index)
	var reward := int(r["reward"])
	coins += reward
	earned += reward
	breaks += 1
	if first_break_ms < 0:
		first_break_ms = int(session.active_ms)
	session.milestone("break", {"rock": rock_index, "name": r["name"], "reward": reward, "pick": pick})
	var centre := rock_view.get_global_transform() * rock_view.centre
	if fx != null:
		fx.float_text(to_fx(centre) + Vector2(0, -60), "+%d" % reward, Color("#ffe27a"), 60)
		fx.coins(to_fx(centre), clampi(reward / 6, 6, 18))
		fx.ring(to_fx(centre), Color(1, 0.95, 0.7), rock_view.radius * 1.6 * _scale)
	if not reduced_motion:
		bits.shatter(rock_view, world)
	momo.cheer(1.4)
	if audio != null:
		audio.play("break", 1.0, 0.0, 0.02)
		audio.play("coin", 1.0, -4.0)
	_set_rock(rock_index + 1)
	rise_left = RISE_SECONDS if not reduced_motion else 0.0
	_place_rock()
	action_changed.emit()


func _set_rock(n: int) -> void:
	rock_index = n
	var r := RockLevels.rock(n)
	max_hp = int(r["hp"])
	hp = max_hp
	rock_view.setup(r, 100 + n)
	rock_view.damage_frac = 0.0
	if bar != null:
		bar.set_hp(hp, max_hp, false)
	goal_world.visible = n < RockLevels.GOAL
	_update_chip()


# --- the play clock ----------------------------------------------------------------------

func tick(dt: float) -> void:
	if rise_left > 0.0:
		rise_left = maxf(0.0, rise_left - dt)
		_place_rock()
	session.metric("rock", rock_index)
	session.metric("rocks_broken", breaks)
	session.metric("pickaxe", pick)
	session.metric("damage_per_hit", RockLevels.damage(pick))
	session.metric("taps", taps)
	session.metric("hits", hits)
	session.metric("misses", misses)
	session.metric("damage_total", damage_total)
	session.metric("coins", coins)
	session.metric("earned", earned)
	session.metric("first_break_s", snappedf(first_break_ms / 1000.0, 0.1) if first_break_ms >= 0 else null)


func hud() -> Dictionary:
	return {"value": coins, "rate": 0.0, "icon": "icon_coin"}


func action_info() -> Dictionary:
	if pick >= RockLevels.max_pick():
		return {"label": "Pickaxe max", "cost": -1, "affordable": false, "texture": _pick_tex, "tint": RockLevels.tint(pick)}
	var c := RockLevels.cost(pick + 1)
	return {"label": "Pickaxe Power", "cost": c, "affordable": coins >= c, "texture": _pick_tex, "tint": RockLevels.tint(pick + 1), "icon": "pick%d" % (pick + 1)}


func do_action() -> void:
	if pick >= RockLevels.max_pick():
		return
	var c := RockLevels.cost(pick + 1)
	if coins < c:
		return
	coins -= c
	pick += 1
	session.upgrade(pick, c, {"damage": RockLevels.damage(pick)})
	swing.show_off(rock_view.position + island.position + Vector2(0, -rock_view.radius * 2.0), RockLevels.tint(pick), _scale)
	if fx != null:
		fx.float_text(to_fx(get_global_transform() * Vector2(size.x * 0.5, size.y - LabHost.BOTTOM_UI - 60)), "x%d per hit" % RockLevels.damage(pick), Color("#ffe27a"), 44)
	if audio != null:
		audio.play("promote", 1.0, -3.0)
	momo.look("happy", 1.0)
	_update_chip()
	action_changed.emit()


# --- layout -----------------------------------------------------------------------------------

func _layout() -> void:
	if size.x <= 0.0:
		return
	var area := Rect2(0, LabHost.TOP_UI + 60.0, size.x, size.y - LabHost.TOP_UI - 60.0 - LabHost.BOTTOM_UI)
	_scale = clampf(minf(area.size.x / 560.0, area.size.y / 760.0), 0.6, 1.3)
	world.scale = Vector2(_scale, _scale)
	# The island's middle cell under the rock, low in the play area.
	var foot := island.iso.cell_center(Vector2i(1, 1))
	world.position = Vector2(area.get_center().x, area.position.y + area.size.y * 0.66) - foot * _scale
	goal_world.scale = Vector2(_scale, _scale) * 0.34
	goal_world.position = Vector2(area.position.x + area.size.x * 0.8, area.position.y + 40.0 * _scale)
	_place_rock()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _place_rock() -> void:
	var k := 1.0 - rise_left / RISE_SECONDS if RISE_SECONDS > 0.0 else 1.0
	var e := 1.0 - pow(1.0 - k, 3.0)
	rock_view.position = island.iso.cell_center(Vector2i(1, 1)) + Vector2(0, 10 + (1.0 - e) * 160.0)
	rock_view.modulate.a = clampf(k * 1.5, 0.0, 1.0)
	var top := rock_view.get_global_transform() * Vector2(0, rock_view.top())
	var at := get_global_transform().affine_inverse() * top
	bar.size = Vector2(320, 34)
	bar.position = Vector2(at.x - 160.0, maxf(LabHost.TOP_UI + 62.0, at.y - 64.0))


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "RockChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	chip.add_child(chip_label)
	add_child(chip)


func _update_chip() -> void:
	if chip_label == null:
		return
	var r := RockLevels.rock(rock_index)
	chip_label.text = "Rock %d/%d · %s · hit %d" % [mini(rock_index + 1, RockLevels.rock_count()), RockLevels.rock_count(), r["name"], RockLevels.damage(pick)]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


# --- the pieces --------------------------------------------------------------------------------

## The glove and pickaxe: raised, a quick strike that lands on the tap, back.
class _Swing extends Node2D:
	var reduced_motion := false
	var at := Vector2.ZERO
	var t := 99.0
	var tint := Color.WHITE
	var k := 1.0
	var _tool: Dictionary = {}
	var _show := -1.0

	func _ready() -> void:
		_tool = LabGlove.tool("pickaxe")
		z_index = 10
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func strike(p: Vector2, p_tint: Color, scale_k: float) -> void:
		at = p
		tint = p_tint
		k = scale_k
		t = 0.0
		queue_redraw()

	## The new pickaxe held up for a moment over the rock.
	func show_off(p: Vector2, p_tint: Color, scale_k: float) -> void:
		if reduced_motion:
			return
		tint = p_tint
		_show = 0.0
		at = p
		k = scale_k

	func _process(delta: float) -> void:
		t += delta
		if _show >= 0.0:
			_show += delta
			if _show > 1.0:
				_show = -1.0
		queue_redraw()

	func _angle() -> float:
		# Degrees: raised -50, the strike lands at 0.06 s at +28, back to -25.
		if reduced_motion:
			return 10.0
		if t < 0.06:
			return lerpf(-50.0, 28.0, t / 0.06)
		if t < 0.26:
			return lerpf(28.0, -25.0, (t - 0.06) / 0.2)
		return -25.0

	func _draw() -> void:
		if _show >= 0.0:
			var s := 1.0 + 0.4 * sin(minf(_show, 0.5) / 0.5 * PI * 0.5)
			var a := 1.0 - maxf(0.0, _show - 0.7) / 0.3
			_draw_tool(at, deg_to_rad(-20.0 + 10.0 * sin(_show * 8.0)), 1.6 * s * k, a, true)
		if t > 0.9:
			return
		var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.3
		var turn := deg_to_rad(_angle())
		var scale_k := 0.95 * k
		# Where the grip goes so the tip lands on `at` at the strike's angle.
		# The tools' grip and tip are in their own region's pixels.
		var grip_px: Vector2 = _tool["grip"]
		var tip_px: Vector2 = _tool["tip"]
		var grip := at - (tip_px - grip_px).rotated(deg_to_rad(28.0)) * scale_k
		_draw_tool(grip, turn, scale_k, alpha, false)

	func _draw_tool(grip: Vector2, turn: float, scale_k: float, alpha: float, centred: bool) -> void:
		var reg: Rect2 = _tool["region"]
		var grip_px: Vector2 = _tool["grip"]
		var origin := -grip_px if not centred else -reg.size * 0.5
		draw_set_transform(grip, turn, Vector2.ONE * scale_k)
		draw_texture_rect_region(LabGlove.TOOLS, Rect2(origin, reg.size), reg, Color(tint, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not centred:
			draw_set_transform(grip, turn + deg_to_rad(24.0), Vector2.ONE * 1.45 * scale_k * 2.2)
			LabGlove.draw(self)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Chips at a hit and the pieces of a broken rock, drawn from one list.
class _Bits extends Node2D:
	var items: Array = []
	var rng := RandomNumberGenerator.new()

	func _ready() -> void:
		rng.seed = 88
		z_index = 8

	func burst(at: Vector2, color: Color, sparks: bool, n: int) -> void:
		for i in n:
			var v := Vector2(rng.randf_range(-260, 260), rng.randf_range(-420, -160))
			items.append({"p": at, "v": v, "r": rng.randf_range(4, 9), "c": Color("#fff2b3") if sparks and i % 2 == 0 else color.lightened(0.1),
				"life": 0.0, "max": 0.45, "poly": PackedVector2Array(), "spin": rng.randf_range(-8, 8), "turn": 0.0})

	func shatter(rock: RockView, space: Node2D) -> void:
		var to_here := space.get_global_transform().affine_inverse() * rock.get_global_transform()
		var c := to_here * rock.centre
		for poly: PackedVector2Array in rock.pieces(8):
			var moved := PackedVector2Array()
			var mid := Vector2.ZERO
			for p: Vector2 in poly:
				mid += to_here * p
			mid /= poly.size()
			for p: Vector2 in poly:
				moved.append(to_here * p - mid)
			var out := (mid - c).normalized()
			items.append({"p": mid, "v": out * rng.randf_range(260, 420) + Vector2(0, -260), "r": 0.0, "c": rock.body,
				"life": 0.0, "max": 0.8, "poly": moved, "spin": rng.randf_range(-5, 5), "turn": 0.0})

	func _process(delta: float) -> void:
		if items.is_empty():
			return
		for it: Dictionary in items:
			it["life"] = float(it["life"]) + delta
			it["v"] = (it["v"] as Vector2) + Vector2(0, 1100) * delta
			it["p"] = (it["p"] as Vector2) + (it["v"] as Vector2) * delta
			it["turn"] = float(it["turn"]) + float(it["spin"]) * delta
		items = items.filter(func(it: Dictionary) -> bool: return float(it["life"]) < float(it["max"]))
		queue_redraw()

	func _draw() -> void:
		for it: Dictionary in items:
			# Solid while they fly, fading only at the end.
			var a := clampf((1.0 - float(it["life"]) / float(it["max"])) / 0.35, 0.0, 1.0)
			var col: Color = it["c"]
			var poly: PackedVector2Array = it["poly"]
			if poly.is_empty():
				draw_circle(it["p"], float(it["r"]) * a + 1.0, Color(col, a))
			else:
				draw_set_transform(it["p"], float(it["turn"]), Vector2.ONE * 0.85)
				draw_colored_polygon(poly, Color(col.darkened(0.08), a))
				var ring := poly.duplicate()
				ring.append(poly[0])
				draw_polyline(ring, Color(RockView.INK, a), 3.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The rock's health: a white lag that follows the drop, the number on it.
class _HpBar extends Control:
	var hp := 1
	var max_hp := 1
	var lag := 1.0

	func set_hp(p_hp: int, p_max: int, animate: bool) -> void:
		hp = p_hp
		max_hp = p_max
		if not animate:
			lag = float(hp) / float(max_hp)
		queue_redraw()

	func _process(delta: float) -> void:
		var target := float(hp) / float(max_hp)
		if lag > target:
			lag = maxf(target, lag - delta * 1.6)
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(LabStyle.box(Color(0.1, 0.14, 0.2, 0.75), 17, Color(0, 0, 0, 0), 0, 0), r)
		var inner := r.grow(-5)
		var f := float(hp) / float(max_hp)
		if lag > f:
			draw_style_box(LabStyle.box(Color(1, 1, 1, 0.85), 12, Color(0, 0, 0, 0), 0, 0), Rect2(inner.position, Vector2(inner.size.x * lag, inner.size.y)))
		if f > 0.0:
			var col := Color("#7ed957").lerp(Color("#ffb347"), 1.0 - f) if f > 0.35 else Color("#ff6b5a")
			draw_style_box(LabStyle.box(col, 12, Color(0, 0, 0, 0), 0, 0), Rect2(inner.position, Vector2(maxf(inner.size.x * f, 14.0), inner.size.y)))
		var font := ThemeDB.fallback_font if get_theme_default_font() == null else get_theme_default_font()
		var text := "%d / %d" % [hp, max_hp]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string_outline(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0.1, 0.14, 0.2, 0.9))
		draw_string(font, Vector2((size.x - w) * 0.5, size.y * 0.5 + 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


# --- tests and the page ------------------------------------------------------------------------

## Where the rock is in canvas pixels (its middle, and a generous box).
func rock_rect() -> Rect2:
	var c := rock_view.get_global_transform() * rock_view.centre
	var r := rock_view.radius * _scale
	return Rect2(c - Vector2(r, r * 0.8), Vector2(r * 2.0, r * 1.6))


func state() -> Dictionary:
	var rr := rock_rect()
	return {"coins": coins, "earned": earned, "pick": pick, "damage": RockLevels.damage(pick), "rock": rock_index,
		"rock_name": RockLevels.rock(rock_index)["name"], "hp": hp, "max_hp": max_hp, "taps": taps, "hits": hits, "misses": misses,
		"damage_total": damage_total, "breaks": breaks, "first_break_ms": first_break_ms, "rising": rise_left > 0.0,
		"next_cost": RockLevels.cost(pick + 1), "cracks": rock_view.damage_frac,
		"rock_rect": [rr.position.x, rr.position.y, rr.size.x, rr.size.y], "goal_visible": goal_world.visible}


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += int(arg)
			action_changed.emit()
			return {"ok": true, "coins": coins}
		"rock":
			# Jumps to rock `arg` (pictures, tests).
			_set_rock(int(arg))
			return {"ok": true, "rock": rock_index}
		"pick":
			pick = clampi(int(arg), 0, RockLevels.max_pick())
			_update_chip()
			action_changed.emit()
			return {"ok": true, "pick": pick}
		"hits":
			# `arg` hits on the rock's middle, as taps would land (waiting out a rise).
			for i in int(arg):
				if rise_left > 0.0:
					rise_left = 0.0
					_place_rock()
				tap_at(get_global_transform().affine_inverse() * (rock_view.get_global_transform() * rock_view.centre))
			return {"ok": true, "rock": rock_index, "hp": hp}
	return null
