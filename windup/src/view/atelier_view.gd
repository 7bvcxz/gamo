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
## A working doll arrived at the doll being filled and started turning its key.
signal helping(helper: int, target: int)

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
## Helpers queue behind the sleeper's back (its key is there), a body apart.
const HELPER_GAPS := [44.0, 94.0, 144.0]
const WALK_SPEED := 110.0
## Warm light by stage: [design position, radius, first stage it shows in].
const LIGHTS := [[Vector2(512, 452), 250.0, 1], [Vector2(640, 380), 200.0, 2], [Vector2(430, 420), 180.0, 2],
	[Vector2(1000, 380), 220.0, 3], [Vector2(640, 20), 400.0, 4], [Vector2(1155, 200), 170.0, 5]]
## The room's tint by stage: cold moonlight to warm lamplight.
const TINT_BY_STAGE := [Color(0.74, 0.78, 0.95), Color(0.84, 0.84, 0.94), Color(0.9, 0.89, 0.92),
	Color(0.97, 0.94, 0.9), Color(1, 0.98, 0.94), Color(1, 1, 0.97)]
const C_LAMP := Color(1.0, 0.72, 0.38)
## Asleep dolls are drawn cold and dim, the one being wound a little brighter,
## awake dolls in full warm colour: 0, 1 or 3 awake dolls read at a glance.
const TINT_ASLEEP := Color(0.56, 0.6, 0.8)
const TINT_WINDING := Color(0.74, 0.76, 0.92)
## Personality through behaviour only (no stats): doll i is TEMPERAMENTS[i % 3].
const TEMPERAMENTS := ["curious", "timid", "proud"]

const BACKDROP := "res://assets/art/backdrop.svg"
const KEY := "res://assets/art/key.svg"
const GEAR_BIG := "res://assets/art/gear_big.svg"
const GEAR_SMALL := "res://assets/art/gear_small.svg"
## The gear train around the key: one small gear per awake doll. Slot k is at
## angle GEAR_ANGLES[k % 6] (degrees), on the first ring (meshing with the big
## gear) for k < 6 and on the second ring (meshing with the first) after.
const GEAR_ANGLES := [-80.0, -35.0, -125.0, 10.0, -170.0, 145.0]
const BIG_PITCH := 88.0
const SMALL_PITCH := 26.0
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
## True while it shows a slow clicker that the key can be held (Step 08).
var hold_hint: bool = false
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
var _gear_big: Texture2D
var _gear_small: Texture2D
var gear_angle: float = 0.0
var _gear_target: float = 0.0
var _gear_pop: PackedFloat32Array = PackedFloat32Array()
var _key_vel: float = 0.0
var _pawl: float = 0.0
var _sparks: Array = []         # [pos, vel, t]
var _shake: float = 0.0
## True: no shake (the HUD's motion icon, ?motion=reduce, the system setting).
var reduced_motion: bool = false
## Step 06 variant ("base", "a", "b", "c"): what extra the picture shows.
var variant: String = "base"
var _release_t: float = -1.0     # A: seconds since the spring was let go
var _release_fill: float = 0.0   # A: how full it was
var _full_t: float = 0.0         # A: the key strains when the spring is full
var _sheet_t: Dictionary = {}    # B: doll index -> seconds since its sheet flew off
var _zoom: float = 0.0           # B: the camera leaning in on a reveal
var _zoom_at: Vector2 = Vector2.ZERO
var _kicks: Array = []           # C: [from doll, to doll, t]
var _chain: int = 0              # C: awakenings in a row (each within 5 s of the last)
var _last_wake: float = -99.0
var _chain_of: Dictionary = {}   # C: doll index -> its place in the chain
var _motes: Array = []           # [from, t]: a working doll's energy drifting to the key
var _mote_clock: PackedFloat32Array = PackedFloat32Array()
var _ready_at: Dictionary = {}   # doll index -> _anim when it started working
var _helping: Dictionary = {}    # doll index -> the target it is turning
var _quirk_clock: PackedFloat32Array = PackedFloat32Array()
var _clock_hand: float = 0.0     # the grandfather clock's hour hand (advances per awakening)
var _dust: float = 1.0           # dust in the corners: 1 asleep -> 0 bustling


func _ready() -> void:
	use_art = use_art and ResourceLoader.exists(BACKDROP) and ResourceLoader.exists(KEY) and DollRig.art_present()
	if use_art:
		_backdrop = load(BACKDROP)
		_key = load(KEY)
		if ResourceLoader.exists(GEAR_BIG) and ResourceLoader.exists(GEAR_SMALL):
			_gear_big = load(GEAR_BIG)
			_gear_small = load(GEAR_SMALL)
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


## Applies a Step 06 variant to the dolls: B gives each a hat and a gesture
## and hides the sleepers under dust sheets.
func set_variant(id: String) -> void:
	variant = id
	for i in dolls.size():
		dolls[i].set_hat(DollRig.HATS[i % DollRig.HATS.size()] if id == "b" else "")
		dolls[i].gesture = i if id == "b" else -1


## B: is doll i still under its sheet?
func sheeted(i: int) -> bool:
	return variant == "b" and atelier != null and i >= atelier.awake and i != atelier.waking


## A: the spring was let go -- a rush of light down the thread, the train spins.
func on_release(e: float) -> void:
	_release_t = 0.0
	_release_fill = 1.0
	_gear_target += 0.25 + minf(e, 400.0) * 0.004
	for i in mini(12, 2 + int(e / 15.0)):
		if _flows.size() < 32:
			_flows.append([-0.04 * i])


## A: a turn refused because the spring is full: the key strains.
func on_spring_full() -> void:
	_full_t = 0.35


## C: doll i, just awake, turned the next sleeper's key.
func on_kick(i: int, _energy: float) -> void:
	if atelier != null and atelier.target() < dolls.size():
		_kicks.append([i, atelier.target(), 0.0])


## Diagnosis only (the bridge's dev_layers): turns layers of the picture off.
func set_layers(flags: Dictionary) -> void:
	_glow.visible = bool(flags.get("glow", true))
	_modulate.visible = bool(flags.get("tint", true))
	_fx.visible = bool(flags.get("fx", true))
	for d in dolls:
		d.visible = bool(flags.get("dolls", true))
	_hide_backdrop = not bool(flags.get("backdrop", true))
	_hide_props = not bool(flags.get("props", true))
	_hide_gears = not bool(flags.get("gears", true))
	queue_redraw()


var _hide_backdrop := false
var _hide_props := false
var _hide_gears := false


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
	_sparks.clear()
	_motes.clear()
	_ready_at.clear()
	_helping.clear()
	_mote_clock.resize(dolls.size())
	_quirk_clock.resize(dolls.size())
	for i in dolls.size():
		_mote_clock[i] = 0.37 * i
		_quirk_clock[i] = 2.0 + 1.3 * i
		dolls[i].modulate = _doll_tint(i)
	_clock_hand = _hand_for(atelier.awake) if atelier != null else _hand_for(0)
	_dust = _dust_for(atelier.awake) if atelier != null else 1.0
	_gear_pop.resize(12)
	for g in 12:
		_gear_pop[g] = 1.0 if atelier != null and g < atelier.awake else 0.0
	_sheet_t.clear()
	_kicks.clear()
	_chain = 0
	_chain_of.clear()
	_zoom = 0.0
	_release_t = -1.0
	for i in dolls.size():
		dolls[i].visible = not sheeted(i)
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
	_key_vel = 0.0
	gear_angle = 0.0
	_gear_target = 0.0
	_shake = 0.0
	hint = false
	sync()


## The centre of gear-train slot `k`, relative to the key's centre.
static func gear_slot(k: int) -> Vector2:
	var a := deg_to_rad(float(GEAR_ANGLES[k % GEAR_ANGLES.size()]))
	var r := BIG_PITCH + SMALL_PITCH + (2.0 * SMALL_PITCH if k >= GEAR_ANGLES.size() else 0.0)
	return Vector2.from_angle(a) * r


## How many gears of the train are showing (popping in counts as showing).
func gears_shown() -> int:
	var n := 0
	for v in _gear_pop:
		if v > 0.0:
			n += 1
	return n


## The rules started waking doll `i`: its wake-up and a burst of light.
func on_awakening(i: int) -> void:
	if i < dolls.size():
		dolls[i].start_wake()
		dolls[i].rotation = 0.0
		dolls[i].flutter = 0.0
		_bursts.append([_homes[i] + Vector2(0, -50), 0.0])
		var from := _layout_offset() + _homes[i] + Vector2(-8.0 * dolls[i].facing, -40)
		for k in 9:
			var a := -PI / 2.0 + (float(k) - 4.0) * 0.32
			_sparks.append([from, Vector2.from_angle(a) * (140.0 + 25.0 * (k % 3)), 0.0])
	if i < _gear_pop.size():
		_gear_pop[i] = 0.01
	if variant == "b" and i < dolls.size():
		dolls[i].visible = true
		_sheet_t[i] = 0.0
		_zoom_at = _layout_offset() + _homes[i] + Vector2(0, -50)
	if variant == "c":
		_chain = _chain + 1 if _anim - _last_wake < 5.0 else 1
		_last_wake = _anim
		_chain_of[i] = _chain
		if not _bursts.is_empty():
			_bursts[_bursts.size() - 1].append(_chain)


## A flow of light from the key to the doll being filled, one per turn.
func on_wind() -> void:
	_press_kick = 1.0
	_pawl = 1.0
	_gear_target += 0.22
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
	# The key is a spring: it snaps past the quarter and settles (the click you feel).
	# Explicit steps are only stable when short: a long frame (a hitch, a tab
	# coming back) is cut into steps of at most 1/240 s, or the key flies off.
	var sub := maxi(1, ceili(dt * 240.0))
	for i in sub:
		var h := dt / sub
		_key_vel += ((_target_angle - key_angle) * 520.0 - _key_vel * 24.0) * h
		key_angle += _key_vel * h
	_press_kick = maxf(0.0, _press_kick - dt * 5.0)
	_pawl = maxf(0.0, _pawl - dt * 9.0)
	# The gear train: winding kicks it, the awake dolls keep it turning.
	if atelier != null:
		_gear_target += atelier.auto_rate() * 0.03 * dt
	gear_angle = lerpf(gear_angle, _gear_target, 1.0 - exp(-dt * 6.0))
	for g in _gear_pop.size():
		if _gear_pop[g] > 0.0 and _gear_pop[g] < 1.0:
			_gear_pop[g] = minf(1.0, _gear_pop[g] + dt * 1.6)
	for sp: Array in _sparks:
		sp[2] = float(sp[2]) + dt
		sp[1] = (sp[1] as Vector2) + Vector2(0, 260.0) * dt
		sp[0] = (sp[0] as Vector2) + (sp[1] as Vector2) * dt
	_sparks = _sparks.filter(func(sp: Array) -> bool: return float(sp[2]) < 0.9)
	_advance_variant(dt)
	_advance_life(dt)
	# No camera shake (Step 05 V2). Variant B's gentle lean is the only camera motion.
	var shake := Vector2.ZERO
	# B: the camera leans in on a reveal (not with reduced motion).
	var z := 1.0 + 0.09 * _zoom if not reduced_motion else 1.0
	scale = Vector2(z, z)
	position = _zoom_at * (1.0 - z) + shake
	_anticipate()
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


func _advance_variant(dt: float) -> void:
	if _release_t >= 0.0:
		_release_t += dt
		_release_fill = maxf(0.0, 1.0 - _release_t / 0.35)
		if _release_t > 0.6:
			_release_t = -1.0
	_full_t = maxf(0.0, _full_t - dt)
	for i: int in _sheet_t.keys():
		_sheet_t[i] = float(_sheet_t[i]) + dt
		if float(_sheet_t[i]) > 1.0:
			_sheet_t.erase(i)
	var revealing := variant == "b" and atelier != null and atelier.waking >= 0
	_zoom = move_toward(_zoom, 1.0 if revealing else 0.0, dt * (2.5 if revealing else 1.2))
	for kk: Array in _kicks:
		kk[2] = float(kk[2]) + dt
	_kicks = _kicks.filter(func(kk: Array) -> bool: return float(kk[2]) < 0.7)


func _doll_tint(i: int) -> Color:
	if atelier == null:
		return Color.WHITE
	match atelier.doll_state(i):
		"DORMANT":
			return TINT_ASLEEP
		"WINDING":
			return TINT_WINDING
	return Color.WHITE


static func _hand_for(awake_count: int) -> float:
	return -PI / 2.0 + awake_count * TAU / 12.0 + 0.6


static func _dust_for(awake_count: int) -> float:
	return clampf(1.0 - awake_count / 6.0, 0.0, 1.0)


## The atelier's life that follows the rules' state: doll colours, the motes a
## working doll sends to the key, temperaments, the clock and the dust.
func _advance_life(dt: float) -> void:
	if atelier == null:
		return
	for i in dolls.size():
		var d := dolls[i]
		d.modulate = d.modulate.lerp(_doll_tint(i), 1.0 - exp(-dt * 3.0))
		var st := atelier.doll_state(i)
		if st == "WORKING" and not _ready_at.has(i):
			_ready_at[i] = _anim
		if st == "WORKING" and d.awake_now() and not _helping.has(i) and d.activity == "work":
			_mote_clock[i] += dt
			var every := maxf(0.6, 2.4 - atelier.b.rates[i] * 0.2)
			if _mote_clock[i] >= every and _motes.size() < 40:
				_mote_clock[i] = 0.0
				_motes.append([d.position + Vector2(0, -46), 0.0])
		if st == "WORKING" and d.awake_now() and d.activity != "walk":
			_quirk_clock[i] -= dt
			if _quirk_clock[i] <= 0.0:
				_quirk(i)
	for m: Array in _motes:
		m[1] = float(m[1]) + dt / 1.1
	_motes = _motes.filter(func(m: Array) -> bool: return float(m[1]) < 1.0)
	_clock_hand = lerp_angle(_clock_hand, _hand_for(atelier.awake), 1.0 - exp(-dt * 2.0))
	_dust = move_toward(_dust, _dust_for(atelier.awake), dt * 0.3)


## A temperament shows itself now and then: the curious one looks over at the
## key, the timid one pauses and looks down, the proud one strikes a pose.
func _quirk(i: int) -> void:
	var d := dolls[i]
	match TEMPERAMENTS[i % TEMPERAMENTS.size()]:
		"curious":
			d.play_quirk("look", 1.0)
			_quirk_clock[i] = 5.0 + fmod(i * 1.7, 2.0)
		"timid":
			d.play_quirk("bow", 0.9)
			_quirk_clock[i] = 6.5 + fmod(i * 1.3, 2.0)
		"proud":
			d.play_quirk("cheer", 0.8)
			_quirk_clock[i] = 7.0 + fmod(i * 1.1, 2.0)


## The doll being filled shivers as it nears its cost, and its eyes flutter.
func _anticipate() -> void:
	if atelier == null:
		return
	var tgt := atelier.target()
	for i in dolls.size():
		var d := dolls[i]
		if sheeted(i):
			d.visible = false
			continue
		if i == tgt and atelier.waking < 0 and d.pose_name == "asleep":
			var f := atelier.target_fill()
			var k := clampf((f - 0.55) / 0.45, 0.0, 1.0)
			d.rotation = sin(_anim * 38.0) * 0.035 * k
			d.flutter = clampf((f - 0.8) / 0.2, 0.0, 1.0)
		elif d.pose_name == "asleep":
			d.rotation = 0.0
			d.flutter = 0.0


## Where helper k stands for target doll `tgt` (design coordinates): behind
## its back, a body apart; on the other side if that would leave the room.
func helper_spot(tgt: int, k: int) -> Vector2:
	var home: Vector2 = _homes[tgt]
	var back := -1.0 if home.x < DESIGN.x * 0.5 else 1.0   # sleepers face the room's middle
	var x: float = home.x + back * float(HELPER_GAPS[k])
	if x < 40.0 or x > DESIGN.x - 40.0:
		x = home.x - back * float(HELPER_GAPS[k])
	return Vector2(x, home.y + 2.0 + k * 3.0)


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
			goal = o + helper_spot(tgt, k)
			face_to = (o + _homes[tgt]).x
		var delta := goal - d.position
		var settle := 1.5 if TEMPERAMENTS[i % TEMPERAMENTS.size()] == "timid" else 0.3
		if _ready_at.has(i) and _anim - float(_ready_at[i]) < settle:
			d.activity = "idle"
			continue
		if delta.length() > 3.0:
			d.position += delta.limit_length(WALK_SPEED * dt)
			d.activity = "walk"
			d.facing = 1 if delta.x >= 0.0 else -1
		else:
			d.activity = "wind" if k >= 0 else "work"
			if k >= 0:
				d.facing = 1 if face_to >= d.position.x else -1
				if int(_helping.get(i, -1)) != tgt:
					_helping[i] = tgt
					helping.emit(i, tgt)
			else:
				_helping.erase(i)


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
	var stage := atelier.stage if atelier != null else 0
	if not _hide_props:
		_draw_props(_layout_offset(), stage)
		_draw_clock(_layout_offset(), stage)
		_draw_dust()
	if stage >= 1:
		_draw_lamp(_layout_offset() + Vector2(500, 492))
	var k := key_center()
	if not _hide_gears:
		_draw_gears(k)
	var wobble := sin(_anim * 2.4) * (0.12 if hint else 0.04) + sin(_anim * 60.0) * 0.05 * (_full_t / 0.35)
	var grow := 1.0 + _press_kick * 0.04
	draw_set_transform(k, key_angle + wobble, Vector2(grow, grow))
	draw_texture_rect(_key, Rect2(Vector2(-KEY_DRAW, -KEY_DRAW) * 0.5, Vector2(KEY_DRAW, KEY_DRAW)), false)
	draw_set_transform(Vector2.ZERO, 0.0)
	# The ratchet pawl at the top right of the housing: it flicks on every turn.
	var pv := k + Vector2(78, -86)
	draw_set_transform(pv, -0.5 * _pawl)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(-14, 26), Vector2(-20, 22)]), Color(0.72, 0.52, 0.2))
	draw_circle(Vector2.ZERO, 6.0, Color(0.45, 0.31, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_gears(k: Vector2) -> void:
	if _gear_big == null:
		return
	var ratio := BIG_PITCH / SMALL_PITCH
	for g in _gear_pop.size():
		var pop := _gear_pop[g]
		if pop <= 0.0:
			continue
		var s := _pop_scale(pop)
		var spin := -gear_angle * ratio if g < GEAR_ANGLES.size() else gear_angle * ratio
		draw_set_transform(k + gear_slot(g), spin + g * 0.4, Vector2(s, s))
		draw_texture_rect(_gear_small, Rect2(Vector2(-38, -38), Vector2(76, 76)), false)
	draw_set_transform(k, gear_angle)
	draw_texture_rect(_gear_big, Rect2(Vector2(-104, -104), Vector2(208, 208)), false)
	draw_set_transform(Vector2.ZERO, 0.0)


## 0..1 -> a scale that grows past 1 and settles (a gear clicking into place).
static func _pop_scale(t: float) -> float:
	if t >= 1.0:
		return 1.0
	return t * (1.0 + 0.35 * sin(t * PI))


## Room props that answer the stage (no new rules, only pictures): the sewing
## machine's cover comes off at stage 2, the jacket on the dress form gets
## finished at stage 3, the grandfather clock starts at stage 5. Coordinates
## are the backdrop's minus its design offset (80, 120).
func _draw_props(o: Vector2, stage: int) -> void:
	if not use_art:
		return
	var turn := gear_angle * 2.0
	if stage < 2:
		# The dust cover over the machine.
		var pts := PackedVector2Array()
		for i in 21:
			var u := float(i) / 20.0
			pts.append(_bez(Vector2(350, 428), Vector2(352, 380), Vector2(390, 350), Vector2(440, 348), u))
		for i in 21:
			var u := float(i) / 20.0
			pts.append(_bez(Vector2(440, 348), Vector2(486, 348), Vector2(510, 380), Vector2(504, 428), u))
		draw_colored_polygon(pts, Color(0.29, 0.25, 0.32))
		draw_polyline(pts, Color(0.11, 0.09, 0.12), 2.0)
	else:
		# The machine itself (burgundy enamel, brass trim), its wheel turning
		# with the gear train; the cover folded beside it.
		var body := Color(0.5, 0.18, 0.22)
		var edge := Color(0.78, 0.42, 0.38)
		var gold := Color(0.95, 0.75, 0.38)
		var shapes := [Rect2(340, 404, 132, 22), Rect2(436, 350, 30, 58), Rect2(352, 348, 114, 26), Rect2(356, 372, 14, 26)]
		for r: Rect2 in shapes:
			var rr := Rect2(o + r.position, r.size)
			draw_rect(rr, body)
			draw_rect(rr, edge, false, 2.0)
		draw_line(o + Vector2(363, 398), o + Vector2(363, 410), Color(0.9, 0.9, 0.95), 2.0)
		draw_line(o + Vector2(364, 360), o + Vector2(432, 360), gold, 3.0)
		draw_rect(Rect2(o + Vector2(392, 330), Vector2(16, 18)), Color(0.94, 0.9, 0.8))
		draw_line(o + Vector2(400, 330), o + Vector2(400, 348), gold, 2.0)
		var wc := o + Vector2(474, 378)
		draw_circle(wc, 17.0, Color(0.78, 0.58, 0.28))
		draw_circle(wc, 12.0, Color(0.35, 0.22, 0.12))
		for n in 3:
			var a := turn + TAU * n / 3.0
			draw_line(wc, wc + Vector2.from_angle(a) * 12.0, gold, 3.0)
		draw_colored_polygon(PackedVector2Array([o + Vector2(476, 428), o + Vector2(484, 410), o + Vector2(500, 414), o + Vector2(498, 428)]), Color(0.29, 0.25, 0.32))
	if stage >= 3:
		# The jacket on the dress form: sleeves, collar and buttons.
		var jc := Color(0.24, 0.29, 0.37)
		draw_colored_polygon(PackedVector2Array([o + Vector2(918, 286), o + Vector2(904, 300), o + Vector2(898, 380), o + Vector2(912, 382), o + Vector2(920, 306)]), jc)
		draw_colored_polygon(PackedVector2Array([o + Vector2(1002, 286), o + Vector2(1016, 300), o + Vector2(1022, 380), o + Vector2(1008, 382), o + Vector2(1000, 306)]), jc)
		draw_colored_polygon(PackedVector2Array([o + Vector2(944, 262), o + Vector2(960, 300), o + Vector2(976, 262)]), Color(0.85, 0.8, 0.7))
		for i in 4:
			draw_circle(o + Vector2(960, 310 + i * 22), 3.0, Color(0.9, 0.72, 0.35))
	pass


## The grandfather clock follows the dolls: its hour hand moves one hour per
## awakening (state, not time), and from stage 5 the pendulum swings.
func _draw_clock(o: Vector2, stage: int) -> void:
	if not use_art:
		return
	var face := o + Vector2(1155, 198)
	draw_circle(face, 36.0, Color(0.79, 0.75, 0.64))
	for n in 12:
		var a := TAU * n / 12.0
		draw_line(face + Vector2.from_angle(a) * 30.0, face + Vector2.from_angle(a) * 34.0, Color(0.3, 0.22, 0.15), 2.0)
	var ink := Color(0.16, 0.11, 0.08)
	draw_line(face, face + Vector2.from_angle(_clock_hand) * 20.0, ink, 4.0)
	var minute := _clock_hand * 12.0 if stage < 5 else _anim * 0.6
	draw_line(face, face + Vector2.from_angle(minute) * 29.0, ink, 2.5)
	draw_circle(face, 3.0, ink)
	if stage >= 5:
		draw_rect(Rect2(o + Vector2(1128, 266), Vector2(54, 186)), Color(0.12, 0.08, 0.09))
		var top := o + Vector2(1155, 270)
		var swing := sin(_anim * PI) * 0.32
		var bob := top + Vector2.from_angle(PI / 2.0 + swing) * 136.0
		draw_line(top, bob, Color(0.43, 0.29, 0.13), 3.0)
		draw_circle(bob, 15.0, Color(0.6, 0.42, 0.16))


## Dust in the corners while the atelier sleeps; it clears as dolls wake.
func _draw_dust() -> void:
	if _dust <= 0.01:
		return
	var size := get_viewport_rect().size
	var c := Color(0.42, 0.4, 0.5, 0.42 * _dust)
	for corner: Vector2 in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
		draw_texture_rect(_glow_tex, Rect2(corner - Vector2(260, 260), Vector2(520, 520)), false, c)


static func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


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
	if atelier != null:
		for i in mini(atelier.awake, dolls.size()):
			var f := _glow.to_local(dolls[i].global_position) + Vector2(0, -20)
			_glow.draw_texture_rect(_glow_tex, Rect2(f - Vector2(44, 30), Vector2(88, 60)), false, Color(C_LAMP, 0.35))


## Light flowing to the doll being filled, its fill ring, awakening bursts,
## and the spirit.
func _draw_fx() -> void:
	var o := _layout_offset()
	var k := key_center()
	var tgt := atelier.target() if atelier != null else dolls.size()
	if use_art:
		_draw_foreground()
	if variant == "b":
		_draw_sheets(tgt)
	if tgt < dolls.size():
		var to := _fx.to_local(dolls[tgt].back_key_global())
		# A faint brass thread from the big key to the doll it is filling: the
		# picture says which key feeds which doll.
		var mid0 := (k + to) * 0.5 + Vector2(0, -120)
		var pts := PackedVector2Array()
		for i in 25:
			var u := float(i) / 24.0
			pts.append(k.lerp(mid0, u).lerp(mid0.lerp(to, u), u))
		_fx.draw_polyline(pts, Color(1.0, 0.8, 0.45, 0.16), 2.0)
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
	for m: Array in _motes:
		var t := float(m[1])
		var from := _fx.to_local(m[0] as Vector2)
		var mid := (from + k) * 0.5 + Vector2(0, -70)
		var q := from.lerp(mid, t).lerp(mid.lerp(k, t), t)
		_fx.draw_circle(q, 5.0, Color(1.0, 0.8, 0.45, 0.25 * (1.0 - t * 0.5)))
		_fx.draw_circle(q, 2.2, Color(1.0, 0.92, 0.7, 0.85))
	if variant == "c":
		_draw_chains(tgt)
	if variant == "a":
		_draw_spring(k)
	for sp: Array in _sparks:
		var life := 1.0 - float(sp[2]) / 0.9
		var c0: Vector2 = sp[0]
		var r0 := 4.0 * life
		if r0 < 0.5:
			continue   # a vanishing spark: its polygon would be degenerate (an engine error per frame)
		_fx.draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -r0 * 2), c0 + Vector2(r0 * 0.5, 0),
			c0 + Vector2(0, r0 * 2), c0 + Vector2(-r0 * 0.5, 0)]), Color(1.0, 0.9, 0.55, life))
		_fx.draw_colored_polygon(PackedVector2Array([c0 + Vector2(-r0 * 2, 0), c0 + Vector2(0, r0 * 0.5),
			c0 + Vector2(r0 * 2, 0), c0 + Vector2(0, -r0 * 0.5)]), Color(1.0, 0.9, 0.55, life))
	for b: Array in _bursts:
		var t := float(b[1]) / 1.6
		var c: Vector2 = o + b[0]
		var grow := 1.0 + 0.6 * (float(b[2]) - 1.0) if b.size() > 2 else 1.0
		_fx.draw_arc(c, (20.0 + t * 90.0) * grow, 0.0, TAU, 40, Color(1.0, 0.86, 0.5, 0.7 * (1.0 - t)), 3.0 if grow <= 1.0 else 5.0, true)
		_fx.draw_circle(c, 30.0 * (1.0 - t), Color(1.0, 0.9, 0.6, 0.25 * (1.0 - t)))
	var s := k + Vector2(-150, -96 + sin(_anim * 1.7) * 9.0)
	if hold_hint:
		# Without words: the spirit sits on the key and keeps pressing; a ring
		# fills around the key for as long as it holds, then it lets go.
		var cycle := fmod(_anim, 2.4)
		var held := clampf(cycle / 1.8, 0.0, 1.0)
		s = k + Vector2(0, -52 + (3.0 if cycle < 1.8 else -6.0))
		_fx.draw_arc(k, 128.0, -PI / 2.0, -PI / 2.0 + TAU * held, 48, Color(1.0, 0.85, 0.5, 0.7 * (1.0 - maxf(0.0, cycle - 1.8) / 0.6)), 5.0)
	elif hint:
		# Without words: the spirit goes to the key and pushes it.
		var push := (sin(_anim * 6.0) * 0.5 + 0.5)
		s = k + Vector2(-104 + push * 14.0, -40)
	s.y -= _press_kick * 8.0
	_draw_spirit(s)


## The foreground, for depth (Step 03 V2): a big thread spool close to the
## eye at the bottom right and the edge of a draped cloth at the top left,
## dark and soft, outside the band where dolls stand.
func _draw_foreground() -> void:
	var size := get_viewport_rect().size
	var sp := Vector2(size.x + 30.0, size.y + 40.0)
	_fx.draw_circle(sp, 120.0, Color(0.05, 0.035, 0.04, 0.92))
	_fx.draw_circle(sp, 96.0, Color(0.25, 0.09, 0.12, 0.9))
	for n in 7:
		_fx.draw_arc(sp, 100.0 + n * 3.0, PI, PI * 1.5, 24, Color(0.35, 0.13, 0.17, 0.6), 1.5)
	_fx.draw_circle(sp, 30.0, Color(0.05, 0.035, 0.04, 0.95))
	var cloth := PackedVector2Array([Vector2(0, 0), Vector2(150, 0), Vector2(128, 26), Vector2(96, 18), Vector2(70, 44),
		Vector2(38, 36), Vector2(16, 70), Vector2(0, 66)])
	_fx.draw_colored_polygon(cloth, Color(0.09, 0.05, 0.08, 0.9))
	_fx.draw_polyline(PackedVector2Array([Vector2(150, 0), Vector2(128, 26), Vector2(96, 18), Vector2(70, 44), Vector2(38, 36), Vector2(16, 70)]),
		Color(0.3, 0.16, 0.2, 0.7), 2.0)


## B: dust sheets over the sleepers; the next one's sheet trembles as it fills;
## a woken doll's sheet flies up and fades.
func _draw_sheets(tgt: int) -> void:
	for i in dolls.size():
		var p := _fx.to_local(dolls[i].global_position)
		if sheeted(i):
			var sway := 0.0
			var lift := 0.0
			if i == tgt and atelier != null:
				var f := atelier.target_fill()
				sway = sin(_anim * 20.0) * 3.0 * clampf((f - 0.5) * 2.0, 0.0, 1.0)
				lift = 6.0 * f
			_draw_sheet(p, sway, lift, 1.0, 0.0)
		elif _sheet_t.has(i):
			var t := float(_sheet_t[i])
			_draw_sheet(p + Vector2(10.0 * t, -170.0 * t), 0.0, 10.0, 1.0 - t, t * 1.4)


func _draw_sheet(p: Vector2, sway: float, lift: float, alpha: float, turn: float) -> void:
	if alpha <= 0.02:
		return
	var pts := PackedVector2Array()
	for n in 13:
		var u := float(n) / 12.0
		var x := lerpf(-34.0, 34.0, u)
		var y := -lift * (0.5 - absf(u - 0.5)) * 2.0
		pts.append(Vector2(x, y))
	for n in 13:
		var u := float(n) / 12.0
		var a := PI * u
		pts.append(Vector2(cos(a) * 34.0 + sway * sin(a), -lift - sin(a) * 52.0 - 4.0))
	var rot := Transform2D(turn, p)
	var poly := PackedVector2Array()
	for q in pts:
		poly.append(rot * q)
	_fx.draw_colored_polygon(poly, Color(0.66, 0.62, 0.58, 0.96 * alpha))
	_fx.draw_polyline(poly, Color(0.32, 0.28, 0.27, 0.8 * alpha), 2.0)
	_fx.draw_line(rot * Vector2(-12, -lift - 8), rot * Vector2(-6, -lift - 44), Color(0.5, 0.46, 0.43, 0.7 * alpha), 2.0)
	_fx.draw_line(rot * Vector2(10, -lift - 6), rot * Vector2(14, -lift - 40), Color(0.5, 0.46, 0.43, 0.7 * alpha), 2.0)


## C: every awake doll sends light along a line to the next sleeper; a doll
## that has just woken throws an arc of sparks to it (its kick).
func _draw_chains(tgt: int) -> void:
	if atelier == null:
		return
	if tgt < dolls.size():
		var to := _fx.to_local(dolls[tgt].back_key_global())
		for i in mini(atelier.awake, dolls.size()):
			var from := _fx.to_local(dolls[i].global_position) + Vector2(0, -44)
			_fx.draw_line(from, to, Color(1.0, 0.75, 0.4, 0.18), 2.0)
			for n in 3:
				var u := fmod(_anim * 0.8 + n / 3.0 + i * 0.13, 1.0)
				_fx.draw_circle(from.lerp(to, u), 3.0, Color(1.0, 0.85, 0.5, 0.75))
	for kk: Array in _kicks:
		var t := float(kk[2]) / 0.7
		var a: int = kk[0]
		var b: int = kk[1]
		if a >= dolls.size() or b >= dolls.size():
			continue
		var from := _fx.to_local(dolls[a].global_position) + Vector2(0, -50)
		var to := _fx.to_local(dolls[b].back_key_global())
		var mid := (from + to) * 0.5 + Vector2(0, -90)
		var q := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		_fx.draw_circle(q, 10.0 * (1.0 - t) + 4.0, Color(1.0, 0.9, 0.55, 0.9))
		_fx.draw_circle(q, 20.0 * (1.0 - t) + 6.0, Color(1.0, 0.8, 0.4, 0.25))


## A: the mainspring coiled around the key -- more turns and hotter as it fills;
## it unwinds in a flash when let go.
func _draw_spring(k: Vector2) -> void:
	if atelier == null:
		return
	var f := atelier.spring_fill()
	if _release_t >= 0.0:
		f = maxf(f, _release_fill)
	if f <= 0.0:
		_fx.draw_arc(k, 136.0, 0.0, TAU, 48, Color(0.85, 0.65, 0.3, 0.18), 2.0)
		return
	var turns := 0.8 + 5.2 * f
	var pts := PackedVector2Array()
	var steps := int(24 * turns)
	for n in steps + 1:
		var u := float(n) / steps
		var a := -PI / 2.0 + u * TAU * turns - gear_angle
		pts.append(k + Vector2.from_angle(a) * lerpf(154.0, 118.0, u * f + (1.0 - f) * 0.0))
	var hot := Color(0.85, 0.62, 0.28).lerp(Color(1.0, 0.45, 0.25), f)
	_fx.draw_polyline(pts, Color(hot, 0.85), 3.0 + 2.0 * f)
	if f >= 0.999:
		_fx.draw_arc(k, 160.0, 0.0, TAU, 48, Color(1.0, 0.6, 0.3, 0.35 + 0.25 * sin(_anim * 12.0)), 4.0)


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
