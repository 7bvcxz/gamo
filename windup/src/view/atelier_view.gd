class_name AtelierView
extends Node2D

## The atelier on screen: the backdrop, the big brass key in the middle (the
## one control), the dolls, the spirit, and the light that grows as the dolls
## wake. Art comes from assets/art/ (Step 03, design/ART_GUIDE.md); when it is
## missing the view draws the Step 02 shapes instead, so the game always opens
## -- `use_art` says which.
##
## The view shows the rules (an Atelier) and never changes them: `bind` gives
## it the atelier, `advance(dt)` moves the pictures by game time. Pressing the
## key says so through `key_pressed` / `key_released`; nothing on screen
## explains it in words.

signal key_pressed(source: String)
signal key_released

const DESIGN := Vector2(1280, 720)
const KEY_CENTER := Vector2(640, 380)
const KEY_HIT_RADIUS := 120.0
const KEY_DRAW := 224.0
const QUARTER := PI / 2.0
const DOLL_SCALE := 0.8
## Vest tints, one per doll in order: the dolls are a family, not clones.
const TINTS := [Color(1, 1, 1), Color(0.75, 0.85, 1.1), Color(1.1, 0.95, 0.7), Color(0.85, 1.0, 0.85),
	Color(1.1, 0.8, 0.95), Color(0.8, 0.8, 0.8), Color(1.0, 0.9, 0.8), Color(0.9, 0.9, 1.15),
	Color(1.15, 1.0, 0.85), Color(0.85, 0.95, 1.0), Color(1.0, 0.85, 0.85), Color(0.95, 1.05, 0.9)]
const HELPERS := 3
const HELPER_OFFSETS := [-40.0, 40.0, -72.0]
const WALK_SPEED := 110.0
## Warm light by stage: [design position, radius, first stage it shows in].
const LIGHTS := [[Vector2(512, 452), 250.0, 1], [Vector2(640, 380), 200.0, 2], [Vector2(430, 420), 180.0, 2],
	[Vector2(1000, 380), 220.0, 3], [Vector2(640, 20), 400.0, 4], [Vector2(1155, 200), 170.0, 5]]
## The room's tint by stage: cold moonlight to warm lamplight.
const TINT_BY_STAGE := [Color(0.74, 0.78, 0.95), Color(0.84, 0.84, 0.94), Color(0.9, 0.89, 0.92),
	Color(0.97, 0.94, 0.9), Color(1, 0.98, 0.94), Color(1, 1, 0.97)]
const C_LAMP := Color(1.0, 0.72, 0.38)

const BACKDROP := "res://assets/art/backdrop.svg"
const KEY := "res://assets/art/key.svg"
## Where the design rectangle's centre is in the backdrop picture.
const BACKDROP_CENTER := Vector2(720, 480)

const C_WALL := Color(0.105, 0.098, 0.135)
const C_WALL_LOW := Color(0.075, 0.07, 0.095)
const C_FLOOR := Color(0.13, 0.095, 0.08)
const C_MOON := Color(0.78, 0.84, 0.95)
const C_BRASS := Color(0.85, 0.64, 0.25)
const C_BRASS_DARK := Color(0.55, 0.38, 0.14)
const C_SPIRIT := Color(1.0, 0.92, 0.66)
const C_DOLL := Color(0.24, 0.2, 0.22)

var key_angle: float = 0.0
var version_text: String = ""
## True when the art is in the project; false draws the shape fallback.
var use_art: bool = true
## The first doll (kept for Step 03's tools and tests); `dolls` has all of them.
var doll: DollRig
var dolls: Array[DollRig] = []
## True while the game shows its wordless hint (the spirit pushes the key).
var hint: bool = false
var atelier: Atelier

var _target_angle: float = 0.0
var _anim: float = 0.0
var _backdrop: Texture2D
var _key: Texture2D
var _homes: Array[Vector2] = []
var _flows: Array = []          # [start, t]
var _bursts: Array = []         # [design position, t]
var _light: PackedFloat32Array = PackedFloat32Array()
var _tint: Color = TINT_BY_STAGE[0]
var _press_kick: float = 0.0
var _glow: Node2D
var _fx: Node2D
var _modulate: CanvasModulate
var _glow_tex: GradientTexture2D


func _ready() -> void:
	use_art = use_art and ResourceLoader.exists(BACKDROP) and ResourceLoader.exists(KEY) and DollRig.art_present()
	if use_art:
		_backdrop = load(BACKDROP)
		_key = load(KEY)
	_modulate = CanvasModulate.new()
	_modulate.color = _tint
	add_child(_modulate)
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	_glow_tex = GradientTexture2D.new()
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.width = 128
	_glow_tex.height = 128
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow_tex.gradient = g
	_light.resize(LIGHTS.size())
	if atelier == null:
		# Step 03's single doll, for views made without rules (tools, tests).
		_make_dolls([Vector2(430, 648)])
	add_child(_glow)
	add_child(_fx)
	_layout()
	get_viewport().size_changed.connect(_layout)


## Diagnosis only (the bridge's dev_layers): turns layers of the picture off.
func set_layers(flags: Dictionary) -> void:
	_glow.visible = bool(flags.get("glow", true))
	_modulate.visible = bool(flags.get("tint", true))
	_fx.visible = bool(flags.get("fx", true))
	for d in dolls:
		d.visible = bool(flags.get("dolls", true))
	_hide_backdrop = not bool(flags.get("backdrop", true))
	queue_redraw()


var _hide_backdrop := false


## Gives the view the rules it shows; makes one doll per doll in the data.
func bind(a: Atelier) -> void:
	atelier = a
	_make_dolls(a.b.positions)
	if _glow != null:
		move_child(_glow, -1)
		move_child(_fx, -1)
	sync()


func _make_dolls(positions: Array[Vector2]) -> void:
	for d in dolls:
		d.queue_free()
	dolls.clear()
	_homes = positions.duplicate()
	doll = null
	if not use_art:
		return
	for i in positions.size():
		var d := DollRig.new()
		d.vest_tint = TINTS[i % TINTS.size()]
		d.scale = Vector2.ONE * DOLL_SCALE
		add_child(d)
		d.facing = 1 if positions[i].x < DESIGN.x * 0.5 else -1
		dolls.append(d)
	if not dolls.is_empty():
		doll = dolls[0]
	_layout()


## Puts every doll in the pose the rules say (a new game, a loaded save).
func sync() -> void:
	for i in dolls.size():
		var d := dolls[i]
		if atelier != null and (i < atelier.awake or i == atelier.waking):
			d.set_pose("stand")
			d.activity = "idle"
		else:
			d.set_pose("asleep")
		d.position = _layout_offset() + _homes[i]
		d.facing = 1 if _homes[i].x < DESIGN.x * 0.5 else -1
	_flows.clear()
	_bursts.clear()
	if atelier != null:
		var st := atelier.stage
		for k in LIGHTS.size():
			_light[k] = 1.0 if st >= int(LIGHTS[k][2]) else 0.0
		_tint = TINT_BY_STAGE[mini(st, TINT_BY_STAGE.size() - 1)]
		if _modulate != null:
			_modulate.color = _tint
	queue_redraw()


func reset() -> void:
	key_angle = 0.0
	_target_angle = 0.0
	hint = false
	sync()


## The rules started waking doll `i`: its wake-up and a burst of light.
func on_awakening(i: int) -> void:
	if i < dolls.size():
		dolls[i].start_wake()
		_bursts.append([_homes[i] + Vector2(0, -50), 0.0])


## A flow of light from the key to the doll being filled, one per turn.
func on_wind() -> void:
	_press_kick = 1.0
	if _flows.size() < 32:
		_flows.append([0.0])


## One quarter turn of the key (the visual half of a wind; the caller counts it).
func turn() -> void:
	_target_angle += QUARTER


var _last_offset := Vector2.INF


func _layout() -> void:
	var o := _layout_offset()
	if _last_offset != Vector2.INF:
		for d in dolls:
			d.position += o - _last_offset
	else:
		for i in dolls.size():
			dolls[i].position = o + _homes[i]
	_last_offset = o
	queue_redraw()


## Moves the pictures by `dt` of game time (the game calls it; nothing here
## runs on the real clock, so a paused game is a still picture).
func advance(dt: float) -> void:
	_anim += dt
	key_angle = lerpf(key_angle, _target_angle, 1.0 - exp(-dt * 18.0))
	_press_kick = maxf(0.0, _press_kick - dt * 5.0)
	_move_dolls(dt)
	for d in dolls:
		d.advance(dt)
	for f: Array in _flows:
		f[0] = float(f[0]) + dt / 0.55
	_flows = _flows.filter(func(f: Array) -> bool: return float(f[0]) < 1.0)
	for b: Array in _bursts:
		b[1] = float(b[1]) + dt
	_bursts = _bursts.filter(func(b: Array) -> bool: return float(b[1]) < 1.6)
	if atelier != null:
		for k in LIGHTS.size():
			var want := 1.0 if atelier.stage >= int(LIGHTS[k][2]) else 0.0
			_light[k] = move_toward(_light[k], want, dt * 0.6)
		var to: Color = TINT_BY_STAGE[mini(atelier.stage, TINT_BY_STAGE.size() - 1)]
		_tint = _tint.lerp(to, 1.0 - exp(-dt * 1.2))
		_modulate.color = _tint
	queue_redraw()
	_glow.queue_redraw()
	_fx.queue_redraw()


## Awake dolls walk: up to HELPERS of them, the nearest, go to the doll being
## filled and turn its key; the rest work at their own places.
func _move_dolls(dt: float) -> void:
	if atelier == null:
		return
	var tgt := atelier.target()
	var helpers: Array[int] = []
	if tgt < dolls.size() and atelier.waking < 0:
		var awake_ids: Array[int] = []
		for i in atelier.awake:
			awake_ids.append(i)
		awake_ids.sort_custom(func(a: int, b: int) -> bool:
			return dolls[a].position.distance_to(dolls[tgt].position) < dolls[b].position.distance_to(dolls[tgt].position))
		helpers = awake_ids.slice(0, HELPERS)
	var o := _layout_offset()
	for i in mini(atelier.awake, dolls.size()):
		var d := dolls[i]
		if not d.awake_now():
			continue
		var k := helpers.find(i)
		var goal: Vector2 = o + _homes[i]
		var face_to := 0.0
		if k >= 0:
			var side := float(HELPER_OFFSETS[k])
			goal = o + _homes[tgt] + Vector2(side, 2.0 + k * 3.0)
			face_to = (o + _homes[tgt]).x
		var delta := goal - d.position
		if delta.length() > 3.0:
			d.position += delta.limit_length(WALK_SPEED * dt)
			d.activity = "walk"
			d.facing = 1 if delta.x >= 0.0 else -1
		else:
			d.activity = "wind" if k >= 0 else "work"
			if k >= 0:
				d.facing = 1 if face_to >= d.position.x else -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed and key_hit(to_local(mb.position)):
			key_pressed.emit("click")
			get_viewport().set_input_as_handled()
		elif not mb.pressed:
			key_released.emit()


## Whether a point (in this node's space) is on the key.
func key_hit(point: Vector2) -> bool:
	return point.distance_to(key_center()) <= KEY_HIT_RADIUS


## The key's centre in this node's space.
func key_center() -> Vector2:
	return _layout_offset() + KEY_CENTER


## The design rectangle is centred in whatever the window shows (stretch
## aspect "expand" can make the visible area wider or taller than 1280x720).
func _layout_offset() -> Vector2:
	var size := get_viewport_rect().size
	return ((size - DESIGN) * 0.5).floor()


func _draw() -> void:
	if use_art:
		_draw_art()
	else:
		_draw_shapes()
	if version_text != "":
		var size := get_viewport_rect().size
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 70, size.y - 14), version_text,
			HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(1, 1, 1, 0.35))


func _draw_art() -> void:
	var size := get_viewport_rect().size
	var tex := Vector2(_backdrop.get_size())
	# Cover the visible area; the backdrop's centre stays on the design centre.
	var s := maxf(1.0, maxf(size.x / tex.x, size.y / tex.y))
	var centre := _layout_offset() + DESIGN * 0.5
	if not _hide_backdrop:
		draw_texture_rect(_backdrop, Rect2(centre - BACKDROP_CENTER * s, tex * s), false)
	if atelier != null and atelier.stage >= 1:
		_draw_lamp(_layout_offset() + Vector2(500, 492))
	var wobble := sin(_anim * 2.4) * (0.12 if hint else 0.04)
	var k := key_center()
	var grow := 1.0 + _press_kick * 0.04
	draw_set_transform(k, key_angle + wobble, Vector2(grow, grow))
	draw_texture_rect(_key, Rect2(Vector2(-KEY_DRAW, -KEY_DRAW) * 0.5, Vector2(KEY_DRAW, KEY_DRAW)), false)
	draw_set_transform(Vector2.ZERO, 0.0)


## The desk lamp that lights at the first awakening.
func _draw_lamp(base: Vector2) -> void:
	draw_rect(Rect2(base + Vector2(-16, -6), Vector2(32, 6)), Color(0.45, 0.31, 0.14))
	draw_line(base + Vector2(0, -6), base + Vector2(8, -44), Color(0.6, 0.43, 0.18), 4.0, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -40), base + Vector2(30, -52),
		base + Vector2(34, -30), base + Vector2(10, -24)]), Color(0.42, 0.18, 0.2))
	draw_circle(base + Vector2(20, -30), 5.0, Color(1.0, 0.86, 0.55))


## Additive warm light, one soft disc per lit source.
func _draw_glow() -> void:
	var o := _layout_offset()
	for k in LIGHTS.size():
		var a: float = _light[k] if k < _light.size() else 0.0
		if a <= 0.001:
			continue
		var r: float = LIGHTS[k][1]
		var c: Vector2 = o + LIGHTS[k][0]
		_glow.draw_texture_rect(_glow_tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(C_LAMP, 0.4 * a))


## Light flowing to the doll being filled, its fill ring, awakening bursts,
## and the spirit.
func _draw_fx() -> void:
	var o := _layout_offset()
	var k := key_center()
	var tgt := atelier.target() if atelier != null else dolls.size()
	if tgt < dolls.size():
		var to := _fx.to_local(dolls[tgt].back_key_global())
		for f: Array in _flows:
			var t := float(f[0])
			var mid := (k + to) * 0.5 + Vector2(0, -120)
			var p := k.lerp(mid, t).lerp(mid.lerp(to, t), t)
			_fx.draw_circle(p, 9.0, Color(1.0, 0.8, 0.4, 0.25))
			_fx.draw_circle(p, 4.0, Color(1.0, 0.93, 0.7, 0.9))
		var fill := atelier.target_fill()
		_fx.draw_arc(to, 16.0, 0.0, TAU, 32, Color(1, 0.85, 0.5, 0.18), 4.0, true)
		if fill > 0.0:
			_fx.draw_arc(to, 16.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, Color(1.0, 0.82, 0.42, 0.95), 4.0, true)
	for b: Array in _bursts:
		var t := float(b[1]) / 1.6
		var c: Vector2 = o + b[0]
		_fx.draw_arc(c, 20.0 + t * 90.0, 0.0, TAU, 40, Color(1.0, 0.86, 0.5, 0.7 * (1.0 - t)), 3.0, true)
		_fx.draw_circle(c, 30.0 * (1.0 - t), Color(1.0, 0.9, 0.6, 0.25 * (1.0 - t)))
	var s := k + Vector2(-150, -96 + sin(_anim * 1.7) * 9.0)
	if hint:
		# Without words: the spirit goes to the key and pushes it.
		var push := (sin(_anim * 6.0) * 0.5 + 0.5)
		s = k + Vector2(-104 + push * 14.0, -40)
	s.y -= _press_kick * 8.0
	_draw_spirit(s)


func _draw_spirit(at: Vector2) -> void:
	for i in 4:
		_fx.draw_circle(at, 30.0 - i * 6.0, Color(C_SPIRIT, 0.06 + i * 0.05))
	_fx.draw_circle(at, 10.0, C_SPIRIT)
	_fx.draw_circle(at + Vector2(-3, -1), 1.6, Color(0.25, 0.18, 0.1))
	_fx.draw_circle(at + Vector2(3, -1), 1.6, Color(0.25, 0.18, 0.1))


## The Step 02 shapes: the fallback when the art is not there.
func _draw_shapes() -> void:
	var size := get_viewport_rect().size
	var o := _layout_offset()
	draw_rect(Rect2(Vector2.ZERO, size), C_WALL)
	var floor_y := o.y + 520.0
	draw_rect(Rect2(0, floor_y - 120.0, size.x, 120.0), C_WALL_LOW)
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), C_FLOOR)
	var win := Rect2(o + Vector2(140, 120), Vector2(170, 230))
	draw_rect(win, C_MOON.darkened(0.55))
	draw_circle(win.position + Vector2(118, 60), 26.0, C_MOON)
	draw_rect(Rect2(win.position.x + 82, win.position.y, 6, win.size.y), C_WALL)
	draw_rect(Rect2(win.position.x, win.position.y + 112, win.size.x, 6), C_WALL)
	var beam := PackedVector2Array([win.position + Vector2(0, win.size.y), win.end,
		Vector2(win.end.x + 260, floor_y + 150), Vector2(win.position.x + 120, floor_y + 150)])
	draw_colored_polygon(beam, Color(C_MOON, 0.07))
	draw_rect(Rect2(o + Vector2(470, 500), Vector2(340, 26)), C_FLOOR.lightened(0.15))
	draw_rect(Rect2(o + Vector2(490, 526), Vector2(18, 90)), C_FLOOR.lightened(0.08))
	draw_rect(Rect2(o + Vector2(772, 526), Vector2(18, 90)), C_FLOOR.lightened(0.08))
	var d := o + Vector2(980, 470)
	draw_rect(Rect2(d + Vector2(-34, 60), Vector2(68, 14)), C_FLOOR.lightened(0.12))
	draw_rect(Rect2(d + Vector2(-26, 74), Vector2(8, 60)), C_FLOOR.lightened(0.05))
	draw_rect(Rect2(d + Vector2(18, 74), Vector2(8, 60)), C_FLOOR.lightened(0.05))
	draw_rect(Rect2(d + Vector2(-20, 6), Vector2(40, 56)), C_DOLL)
	draw_circle(d + Vector2(14, 0), 18.0, C_DOLL.lightened(0.08))
	draw_circle(d + Vector2(-22, 26), 6.0, C_BRASS_DARK)
	var k := key_center()
	draw_rect(Rect2(k + Vector2(-16, 40), Vector2(32, 82)), C_BRASS_DARK)
	draw_set_transform(k, key_angle + sin(_anim * 2.4) * 0.05)
	draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 48, C_BRASS, 22.0, true)
	draw_circle(Vector2.ZERO, 16.0, C_BRASS_DARK)
	for i in 4:
		var a := i * QUARTER
		draw_line(Vector2.from_angle(a) * 24.0, Vector2.from_angle(a) * 58.0, C_BRASS, 10.0, true)
	draw_set_transform(Vector2.ZERO, 0.0)
