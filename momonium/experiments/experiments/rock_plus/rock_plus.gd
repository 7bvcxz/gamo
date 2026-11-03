extends LabExperiment

## C+ -- the improved track of Break & Upgrade (Step 94): one rock at a time,
## one currency, one pickaxe, one tap, like C. Step 96 gave it thirty minutes
## (RockPlusLevels: eighteen kinds of rock with their shapes, a big one every
## sixth, a level about every three rocks with no wall, chunks that pay as
## they break off, the next big rock on the far islet as the next goal); in
## Step 95 it still ran on C's numbers. Step 95 made the hit tactile
## (RockPlusFeel):
##   - the pickaxe waits raised beside the rock and lands on the frame of the
##     tap (C swung in for 0.06 s after the chips had already flown), holds
##     the contact for an instant, recoils and comes back;
##   - the rock flashes, squashes and jolts by itself -- never the world or
##     the camera -- keeps a dent and a crack where each hit landed, and
##     loses a chunk at a third and at two thirds of its damage;
##   - the last hit holds the moment, then the rock flies apart into pieces
##     that fall and bounce on the island, coins shower out and Momo cheers;
##   - heavier rocks squash less, sound lower and break into more pieces; the
##     pickaxe looks and sounds new at its milestones (Copper, Steel, Golden,
##     Crystal), not only a bigger number.
## One press is one hit; a press off the rock, or while the next one rises,
## does nothing and pays nothing. Two experiment-only alternatives (dev, the
## run records which): `?alt=hold` (Step 95) -- a press held on the rock
## repeats a hit every HOLD_PERIOD; `?alt=light` (Step 96) -- every rock has
## LIGHT_HP of its hit points, the same coins: fewer taps for each break.
## The baseline C (experiments/rock/) is never changed for any of this.

## `?alt=light`: the share of a rock's hit points.
const LIGHT_HP := 0.6

const RISE_SECONDS := 0.5

var coins := 0
var earned := 0
var pick := 0
var rock_index := 0
var hp := 0
var max_hp := 0
var taps := 0
var hits := 0
var hold_hits := 0
var misses := 0
var damage_total := 0
var breaks := 0
var big_breaks := 0
var chunks := 0
var chunk_coins := 0
var first_break_ms := -1
var rise_left := 0.0
var last_impact := 0.0
var hit_sounds := 0

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var rock_view: RockPlusView
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
## The breaking moment: the broken rock still shows (flashing) while this
## runs down, then flies apart; its reward is already paid.
var _hold_left := 0.0
var _burst_reward := 0
var _burst_rock: Dictionary = {}
var _jolt := 0.0
var _jolt_t := 0.0
var _sound_ms := -1000.0
var _touch := false
var _holding := false
var _hold_t := 0.0
var _hold_at := Vector2.ZERO
## Coins already paid for the rock in play (its chunks); the break pays the rest.
var _rock_paid := 0
var _goal_shown := -1


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
	goal_view = RockPlusView.new()
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
	rock_view = RockPlusView.new()
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
	_set_rock_state(0)
	_show_rock(0)
	swing.set_pick(pick)
	resized.connect(_layout)
	_layout()
	if audio != null:
		audio.start_ambience(true)


# --- the hit ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	# The mouse copy of a touch, or a click: one press, one hit. (The Lab stops
	# the touch itself before the UI, so a finger is never counted twice.) A
	# touch's copy comes from the emulation device (-1): the damage number
	# then rises higher, clear of the finger.
	var motion := event as InputEventMouseMotion
	if motion != null and _holding:
		_hold_at = motion.position
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mb.pressed:
		_holding = false
		return
	accept_event()
	var before := hits
	tap_at(mb.position, mb.device == -1)
	if variant == "hold" and hits > before:
		_holding = true
		_hold_t = 0.0
		_hold_at = mb.position


## A tap at `local` (this Control's coordinates): a hit if it is on the rock.
func tap_at(local: Vector2, touch: bool = false) -> void:
	taps += 1
	_touch = touch
	if not _on_rock(local):
		misses += 1
		session.action("tap_miss")
		return
	if rise_left > 0.0 or hp <= 0:
		session.action("tap_wait")
		return
	hit(local)


func _on_rock(local: Vector2) -> bool:
	return rock_view.hit_test(rock_view.get_global_transform().affine_inverse() * (get_global_transform() * local))


## One hit of the pickaxe at `local`; `kind` is the action it records ("hit",
## or "hold_hit" for a repeat of the press-and-hold experiment).
func hit(local: Vector2, kind: String = "hit") -> void:
	var dmg := RockPlusLevels.damage(pick)
	hits += 1
	if kind == "hold_hit":
		hold_hits += 1
	damage_total += dmg
	# The share of the rock gone, from whole numbers (1 - hp / max would put
	# 17 of 50 a hair under the 0.34 stage).
	var before := float(max_hp - hp) / float(max_hp)
	hp = maxi(0, hp - dmg)
	var frac := float(max_hp - hp) / float(max_hp)
	session.action(kind, {"damage": dmg, "rock": rock_index})
	var r := RockPlusLevels.rock(rock_index)
	var imp := RockPlusFeel.impact(dmg, max_hp)
	var w := RockPlusFeel.weight(r)
	last_impact = imp
	rock_view.damage_frac = frac
	bar.set_hp(hp, max_hp, not reduced_motion)
	var global := get_global_transform() * local
	var at_world := world.get_global_transform().affine_inverse() * global
	rock_view.add_mark(rock_view.get_global_transform().affine_inverse() * global, imp)
	rock_view.flash = 0.45 + 0.4 * imp
	swing.strike(at_world, imp)
	if not reduced_motion:
		var tier := RockPlusFeel.tier(pick)
		bits.impact(at_world, rock_view.body, String(r["sound"]) != "stone", imp, int(tier["sparks"]), _floor_y())
		rock_view.squash = clampf(imp / w * 1.3, 0.25, 1.0)
		var tw := rock_view.create_tween()
		tw.tween_property(rock_view, "squash", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_jolt = 7.0 * imp / w
		_jolt_t = 0.12
		bar.kick = 1.0
	if fx != null:
		# Above the hit, clear of a finger (higher, and to the side away from
		# the rock's middle), but never over the bar's numbers: it starts far
		# enough below the bar to rise (70 px) without reaching it.
		var lift := RockPlusFeel.NUMBER_LIFT_TOUCH if _touch else RockPlusFeel.NUMBER_LIFT_MOUSE
		var side := 0.0
		if _touch:
			side = 70.0 if global.x >= (rock_view.get_global_transform() * rock_view.centre).x else -70.0
		var at := to_fx(global) + Vector2(side, -lift)
		at.y = maxf(at.y, to_fx(Vector2(0, bar.get_global_rect().end.y)).y + 80.0)
		var col := Color.WHITE.lerp(Color("#ffd84d"), clampf((imp - 0.5) * 2.0, 0.0, 1.0))
		fx.float_text(at, "-%d" % dmg, col, RockPlusFeel.number_size(imp))
	_hit_sound(r, imp)
	if hp <= 0:
		_break()
		return
	for k in RockPlusFeel.STAGES.size():
		var at := RockPlusFeel.STAGES[k]
		if before < at and frac >= at:
			_chunk(k, w, r)


func _hit_sound(r: Dictionary, imp: float) -> void:
	if audio == null:
		return
	# Two hits in one moment are one sound, never a doubled one.
	var now := Time.get_ticks_msec()
	if now - _sound_ms < RockPlusFeel.SOUND_GAP * 1000.0:
		return
	_sound_ms = now
	hit_sounds += 1
	var s := RockPlusFeel.hit_sound(r, pick, imp)
	audio.play(String(s["name"]), float(s["pitch"]), float(s["db"]), 0.04)
	if String(s["layer"]) != "":
		audio.play(String(s["layer"]), float(s["layer_pitch"]), float(s["layer_db"]), 0.02)


## A chunk breaks off the rim (stage `k` + 1 of the rock) and pays its share.
func _chunk(k: int, w: float, r: Dictionary) -> void:
	chunks += 1
	rock_view.stage = k + 1
	var pay := RockPlusLevels.chunk_pay(r)
	coins += pay
	earned += pay
	chunk_coins += pay
	_rock_paid += pay
	session.milestone("chunk", {"rock": rock_index, "stage": k + 1, "coins": pay})
	if fx != null and k < rock_view.notches.size():
		var mid := Vector2.ZERO
		for p: Vector2 in rock_view.notches[k]:
			mid += p
		mid /= maxf(1.0, rock_view.notches[k].size())
		var at := to_fx(rock_view.get_global_transform() * mid)
		fx.float_text(at + Vector2(0, -30), "+%d" % pay, Color("#ffe27a"), 34)
		fx.coins(at, 3)
	action_changed.emit()
	if not reduced_motion and k < rock_view.notches.size():
		bits.chunk(rock_view, world, rock_view.notches[k], _floor_y())
	if audio != null:
		audio.play("thunk", 1.0 / sqrt(w), -6.0, 0.02)


func _break() -> void:
	var r := RockPlusLevels.rock(rock_index)
	# What the chunks have not paid yet: a rock pays its reward, once.
	var reward := int(r["reward"]) - _rock_paid
	coins += reward
	earned += reward
	breaks += 1
	if bool(r["big"]):
		big_breaks += 1
	if first_break_ms < 0:
		first_break_ms = int(session.active_ms)
	session.milestone("break", {"rock": rock_index, "name": r["name"], "reward": int(r["reward"]), "pick": pick, "big": bool(r["big"])})
	# Paid now; shown after the breaking moment. The next rock's numbers are
	# in place already, and a tap before it has risen does nothing.
	_burst_reward = int(r["reward"])
	_burst_rock = r
	_hold_left = 0.0 if reduced_motion else RockPlusFeel.break_hold(r)
	rock_view.flash = 1.0
	rock_view.stage = 2
	# The bar and the chip still show the broken rock until it flies apart.
	_set_rock_state(rock_index + 1, false)
	rise_left = _hold_left + (RISE_SECONDS if not reduced_motion else 0.0)
	if _hold_left <= 0.0:
		_burst()
	action_changed.emit()


## The broken rock flies apart (its reward was paid at the hit) and the next
## one starts to rise in its place.
func _burst() -> void:
	_hold_left = 0.0
	var centre := rock_view.get_global_transform() * rock_view.centre
	if fx != null:
		fx.float_text(to_fx(centre) + Vector2(0, -70), "+%d" % _burst_reward, Color("#ffe27a"), 64)
		fx.coins(to_fx(centre), clampi(_burst_reward / 5, 8, 18))
		fx.ring(to_fx(centre), Color(1, 0.95, 0.7), rock_view.radius * 1.7 * _scale)
	if not reduced_motion:
		bits.shatter(rock_view, world, RockPlusFeel.shatter_pieces(_burst_rock), _floor_y())
	momo.cheer(1.4)
	bar.set_hp(hp, max_hp, false)
	_update_chip()
	if audio != null:
		var w := RockPlusFeel.weight(_burst_rock)
		audio.play("break", 1.05 / sqrt(w), 0.0, 0.02)
		audio.play("coin", 1.0, -5.0)
	_show_rock(rock_index)
	_place_rock()


## The numbers of rock `n`: what the next hits take away (`shown`: the bar
## and the chip say so at once).
func _set_rock_state(n: int, shown: bool = true) -> void:
	rock_index = n
	var r := RockPlusLevels.rock(n)
	max_hp = maxi(1, int(round(float(r["hp"]) * (LIGHT_HP if variant == "light" else 1.0))))
	hp = max_hp
	_rock_paid = 0
	if shown:
		if bar != null:
			bar.set_hp(hp, max_hp, false)
		_update_chip()


## The look of rock `n`, and on the far islet the next big rock (the next
## goal: this kind's, or the next kind's once this one is broken).
func _show_rock(n: int) -> void:
	rock_view.setup(RockPlusLevels.rock(n), 100 + n)
	rock_view.damage_frac = 0.0
	var next_big := (n / RockPlusLevels.KIND_SIZE + 1) * RockPlusLevels.KIND_SIZE - 1
	if next_big != _goal_shown:
		_goal_shown = next_big
		goal_view.setup(RockPlusLevels.rock(next_big), 9)


## The island's ground under the rock, in the world's coordinates: where
## chips and pieces land.
func _floor_y() -> float:
	return (world.get_global_transform().affine_inverse() * (island.get_global_transform() * island.iso.cell_center(Vector2i(1, 1)))).y + 30.0


# --- the play clock ----------------------------------------------------------------------

func tick(dt: float) -> void:
	if _hold_left > 0.0:
		_hold_left -= dt
		if _hold_left <= 0.0:
			_burst()
	if rise_left > 0.0:
		rise_left = maxf(0.0, rise_left - dt)
		_place_rock()
	if _holding:
		_hold_t += dt
		while _hold_t >= RockPlusFeel.HOLD_PERIOD:
			_hold_t -= RockPlusFeel.HOLD_PERIOD
			if rise_left <= 0.0 and hp > 0 and _on_rock(_hold_at):
				hit(_hold_at, "hold_hit")
	session.metric("rock", rock_index)
	session.metric("kind", String(RockPlusLevels.rock(rock_index)["kind"]))
	session.metric("rocks_broken", breaks)
	session.metric("big_rocks_broken", big_breaks)
	session.metric("chunks", chunks)
	session.metric("chunk_coins", chunk_coins)
	session.metric("pickaxe", pick)
	session.metric("damage_per_hit", RockPlusLevels.damage(pick))
	session.metric("taps", taps)
	session.metric("hits", hits)
	session.metric("hold_hits", hold_hits)
	session.metric("misses", misses)
	session.metric("damage_total", damage_total)
	session.metric("coins", coins)
	session.metric("earned", earned)
	session.metric("first_break_s", snappedf(first_break_ms / 1000.0, 0.1) if first_break_ms >= 0 else null)


func _process(delta: float) -> void:
	# The rock's own flash and jolt fade in real time (the frame pauses the
	# experiment, so they stop with it).
	if rock_view.flash > 0.0:
		rock_view.flash = maxf(0.0, rock_view.flash - delta * (2.5 if _hold_left > 0.0 else 6.0))
	if _jolt_t > 0.0:
		_jolt_t = maxf(0.0, _jolt_t - delta)
		rock_view.jolt = Vector2(sin(_jolt_t * 95.0) * _jolt * (_jolt_t / 0.12), 0.0)
	elif rock_view.jolt != Vector2.ZERO:
		rock_view.jolt = Vector2.ZERO


func hud() -> Dictionary:
	return {"value": coins, "rate": 0.0, "icon": "icon_coin"}


## The pickaxe's colour at `level`: its tier's.
static func tint(level: int) -> Color:
	return RockPlusFeel.tier(level)["tint"]


func action_info() -> Dictionary:
	var c := RockPlusLevels.cost(pick + 1)
	return {"label": "Pickaxe Power", "cost": c, "affordable": coins >= c, "texture": _pick_tex, "tint": tint(pick + 1)}


func do_action() -> void:
	var c := RockPlusLevels.cost(pick + 1)
	if coins < c:
		return
	coins -= c
	pick += 1
	var milestone := RockPlusFeel.is_milestone(pick)
	var tier := RockPlusFeel.tier(pick)
	session.upgrade(pick, c, {"damage": RockPlusLevels.damage(pick), "tier": String(tier["name"]), "milestone": milestone})
	swing.set_pick(pick)
	swing.show_off(milestone)
	if fx != null:
		var at := to_fx(get_global_transform() * Vector2(size.x * 0.5, size.y - LabHost.BOTTOM_UI - 60))
		if milestone:
			fx.float_text(at + Vector2(0, -50), String(tier["name"]) + "!", Color.WHITE, 50)
			fx.ring(to_fx(swing.get_global_transform() * swing.ready_tip), tint(pick).lightened(0.3), 220.0 * _scale)
		fx.float_text(at, "%s per hit" % LabHost._short(RockPlusLevels.damage(pick)), Color("#ffe27a"), 44)
	if audio != null:
		audio.play("promote" if milestone else "built", 1.0, -3.0 if milestone else -6.0)
	momo.look("happy", 1.0)
	if milestone:
		momo.cheer(1.0)
	_update_chip()
	action_changed.emit()


# --- layout -----------------------------------------------------------------------------------

func _layout() -> void:
	if size.x <= 0.0:
		return
	var area := Rect2(0, LabHost.TOP_UI + 60.0, size.x, size.y - LabHost.TOP_UI - 60.0 - LabHost.BOTTOM_UI)
	_scale = clampf(minf(area.size.x / 560.0, area.size.y / 760.0), 0.6, 1.3)
	world.scale = Vector2(_scale, _scale)
	var foot := island.iso.cell_center(Vector2i(1, 1))
	world.position = Vector2(area.get_center().x, area.position.y + area.size.y * 0.66) - foot * _scale
	goal_world.scale = Vector2(_scale, _scale) * 0.34
	goal_world.position = Vector2(area.position.x + area.size.x * 0.8, area.position.y + 40.0 * _scale)
	_place_rock()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _place_rock() -> void:
	# Holding the breaking moment: the broken rock stays where it was.
	var rising := 0.0 if _hold_left > 0.0 else minf(rise_left, RISE_SECONDS)
	var k := 1.0 - rising / RISE_SECONDS
	var e := 1.0 - pow(1.0 - k, 3.0)
	rock_view.position = island.iso.cell_center(Vector2i(1, 1)) + Vector2(0, 10 + (1.0 - e) * 160.0)
	rock_view.modulate.a = clampf(k * 1.5, 0.0, 1.0)
	var top := rock_view.get_global_transform() * Vector2(0, rock_view.top())
	var at := get_global_transform().affine_inverse() * top
	bar.size = Vector2(320, 34)
	bar.home = Vector2(at.x - 160.0, maxf(LabHost.TOP_UI + 62.0, at.y - 64.0))
	bar.position = bar.home
	# The pickaxe waits raised at the rock's upper right, its tip just off the stone.
	var to_world := world.get_global_transform().affine_inverse() * rock_view.get_global_transform()
	swing.ready_tip = to_world * (rock_view.centre + Vector2(rock_view.radius * 0.95, -rock_view.radius * 0.62))
	swing.k = _scale


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
	var r := RockPlusLevels.rock(rock_index)
	var alt := " · hold test" if variant == "hold" else (" · light test" if variant == "light" else "")
	chip_label.text = "%s · %d/%d · hit %s%s" % [r["name"], int(r["step"]) + 1, RockPlusLevels.KIND_SIZE, LabHost._short(RockPlusLevels.damage(pick)), alt]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


# --- the pieces --------------------------------------------------------------------------------

## The glove and pickaxe. It waits raised beside the rock (bobbing a little)
## so the first thing on screen says "strike it"; a hit puts its tip on the
## tap at once -- with a smear from where it waited -- holds the contact for
## CONTACT seconds, recoils past its waiting angle and settles back. Its
## head, trail, sparks, glow and shards come from RockPlusFeel's tier.
class _Swing extends Node2D:
	const CONTACT := 0.06
	const RECOIL := 0.16
	const SETTLE := 0.42
	const HIT_ANGLE := 28.0
	const READY_ANGLE := -40.0
	const RECOIL_ANGLE := -72.0
	var reduced_motion := false
	var ready_tip := Vector2.ZERO
	var at := Vector2.ZERO
	var t := 99.0
	var k := 1.0
	var impact := 0.5
	var tint := Color.WHITE
	var tier: Dictionary = RockPlusFeel.TIERS[0]
	var _tool: Dictionary = {}
	var _show := -1.0
	var _show_big := false
	var _time := 0.0

	func _ready() -> void:
		_tool = LabGlove.tool("pickaxe")
		z_index = 10
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func set_pick(level: int) -> void:
		tier = RockPlusFeel.tier(level)
		tint = tier["tint"]
		queue_redraw()

	func strike(p: Vector2, p_impact: float) -> void:
		at = p
		impact = p_impact
		t = 0.0
		queue_redraw()

	## The new pickaxe shown off over its waiting place: big at a milestone.
	func show_off(big: bool) -> void:
		if reduced_motion:
			return
		_show = 0.0
		_show_big = big

	## Whether the tip is on the rock this frame (tests).
	func in_contact() -> bool:
		return t < CONTACT

	func _process(delta: float) -> void:
		t += delta
		_time += delta
		if _show >= 0.0:
			_show += delta
			if _show > (1.3 if _show_big else 0.7):
				_show = -1.0
		queue_redraw()

	func _grip_for(tip: Vector2, deg: float, scale_k: float) -> Vector2:
		var grip_px: Vector2 = _tool["grip"]
		var tip_px: Vector2 = _tool["tip"]
		return tip - (tip_px - grip_px).rotated(deg_to_rad(deg)) * scale_k

	func _draw() -> void:
		if _tool.is_empty():
			return
		var s := 0.95 * k * float(tier["head"])
		var contact_grip := _grip_for(at, HIT_ANGLE, s)
		var bob := 0.0 if reduced_motion else sin(_time * 3.2) * 4.0
		var ready_grip := _grip_for(ready_tip + Vector2(0, bob), READY_ANGLE, s)
		var grip := ready_grip
		var deg := READY_ANGLE
		if reduced_motion:
			if t < 0.15:
				grip = contact_grip
				deg = HIT_ANGLE
		elif t < CONTACT:
			grip = contact_grip
			deg = HIT_ANGLE
			_draw_smear(s)
		elif t < RECOIL:
			var u := (t - CONTACT) / (RECOIL - CONTACT)
			var e := 1.0 - pow(1.0 - u, 3.0)
			deg = lerpf(HIT_ANGLE, RECOIL_ANGLE, e)
			grip = contact_grip + Vector2(0, -18.0 * k) * e
		elif t < SETTLE:
			var u := (t - RECOIL) / (SETTLE - RECOIL)
			var e := u * u * (3.0 - 2.0 * u)
			deg = lerpf(RECOIL_ANGLE, READY_ANGLE, e)
			grip = (contact_grip + Vector2(0, -18.0 * k)).lerp(ready_grip, e)
		var big := 1.0
		if _show >= 0.0:
			var span := 1.3 if _show_big else 0.7
			var up := sin(minf(_show / span, 1.0) * PI)
			big = 1.0 + (0.9 if _show_big else 0.35) * up
			deg += 10.0 * sin(_show * 9.0) * up
		var tip_px: Vector2 = _tool["tip"]
		var grip_px: Vector2 = _tool["grip"]
		var along := (tip_px - grip_px).rotated(deg_to_rad(deg)) * s * big
		if bool(tier["glow"]):
			var head := grip + along * 0.8
			draw_circle(head, 34.0 * k * big, Color(tint, 0.22))
		_draw_tool(grip, deg_to_rad(deg), s * big)
		if bool(tier["ring"]):
			# Starmetal on: a ring around the head, two sparks riding it.
			var head := grip + along * 0.8
			draw_set_transform(head, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, 46.0 * k * big, 0.0, TAU, 28, Color(tint.lightened(0.3), 0.8), 3.0)
			for i in 2:
				var a := (0.0 if reduced_motion else _time * 3.0) + PI * i
				draw_circle(Vector2(cos(a), sin(a)) * 46.0 * k * big, 5.0, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(tier["shards"]) and not reduced_motion:
			var c := grip + along * 0.7
			for i in 3:
				var a := _time * 2.4 + TAU * i / 3.0
				var p := c + Vector2(cos(a), sin(a) * 0.6) * 40.0 * k
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(4, 0), p + Vector2(0, 7), p + Vector2(-4, 0)]), Color("#c9f7ff"))

	## The swing's path in the instant of contact: a band from where the tip
	## waited to where it landed (tinted, and stronger, from Copper on).
	func _draw_smear(s: float) -> void:
		var a := ready_tip
		var b := at
		var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * (a.distance_to(b) * 0.25)
		var pts := PackedVector2Array()
		var back := PackedVector2Array()
		for i in 7:
			var u := float(i) / 6.0
			var p := a.lerp(mid, u).lerp(mid.lerp(b, u), u)
			var nrm := (mid.lerp(b, u) - a.lerp(mid, u)).orthogonal().normalized()
			var w := (4.0 + 14.0 * u * (0.5 + impact)) * s
			pts.append(p + nrm * w)
			back.append(p - nrm * w)
		back.reverse()
		pts.append_array(back)
		var col := Color(tint, 0.45) if bool(tier["trail"]) else Color(1, 1, 1, 0.35)
		draw_colored_polygon(pts, col)

	func _draw_tool(grip: Vector2, turn: float, scale_k: float) -> void:
		var reg: Rect2 = _tool["region"]
		var grip_px: Vector2 = _tool["grip"]
		draw_set_transform(grip, turn, Vector2.ONE * scale_k)
		draw_texture_rect_region(LabGlove.TOOLS, Rect2(-grip_px, reg.size), reg, tint)
		draw_set_transform(grip, turn + deg_to_rad(24.0), Vector2.ONE * 1.45 * scale_k * 2.2)
		LabGlove.draw(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Everything that flies, from one list: at a hit a flash, chips and (from
## Copper, more on ore) sparks; a chunk breaking off; the pieces of a broken
## rock. Chips and pieces fall onto the island's ground (`floor`), bounce
## once and fade; dust puffs where pieces land. At most MAX_BITS at once.
class _Bits extends Node2D:
	var items: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()

	func _ready() -> void:
		rng.seed = 95
		z_index = 8

	func _add(it: Dictionary) -> void:
		items.append(it)
		while items.size() > RockPlusFeel.MAX_BITS:
			items.pop_front()

	func impact(at: Vector2, color: Color, ringing: bool, p_impact: float, sparks: int, floor_y: float) -> void:
		_add({"kind": "flash", "p": at, "life": 0.0, "max": 0.14, "r": 18.0 + 30.0 * p_impact})
		for i in 3 + int(round(p_impact * 4.0)):
			var v := Vector2(rng.randf_range(-240, 240), rng.randf_range(-380, -140)) * (0.7 + 0.5 * p_impact)
			_add({"kind": "chip", "p": at, "v": v, "r": rng.randf_range(4, 8) * (0.8 + 0.5 * p_impact), "c": color.lightened(0.1),
				"life": 0.0, "max": 0.7, "floor": floor_y + rng.randf_range(-12, 12), "bounced": false})
		var n := sparks + (2 if ringing else 0)
		for i in n:
			var a := rng.randf_range(-PI * 0.95, -PI * 0.05)
			var v := Vector2(cos(a), sin(a)) * rng.randf_range(260, 520)
			_add({"kind": "spark", "p": at, "v": v, "life": 0.0, "max": 0.22, "c": Color("#fff2b3")})

	func chunk(rock: RockPlusView, space: Node2D, notch: PackedVector2Array, floor_y: float) -> void:
		var to_here := space.get_global_transform().affine_inverse() * rock.get_global_transform()
		var mid := Vector2.ZERO
		for p: Vector2 in notch:
			mid += to_here * p
		mid /= maxf(1.0, notch.size())
		var moved := PackedVector2Array()
		for p: Vector2 in notch:
			moved.append(to_here * p - mid)
		var out := (mid - to_here * rock.centre).normalized()
		_add({"kind": "piece", "p": mid, "v": out * 240.0 + Vector2(0, -320), "c": rock.body, "life": 0.0, "max": 1.1, "poly": moved,
			"tris": _triangles(moved), "spin": rng.randf_range(-6, 6), "turn": 0.0, "floor": floor_y, "bounced": false})
		for i in 6:
			_add({"kind": "chip", "p": mid, "v": out * rng.randf_range(80, 260) + Vector2(rng.randf_range(-80, 80), rng.randf_range(-360, -160)),
				"r": rng.randf_range(4, 8), "c": rock.body.lightened(0.1), "life": 0.0, "max": 0.8, "floor": floor_y + rng.randf_range(-12, 12), "bounced": false})

	func shatter(rock: RockPlusView, space: Node2D, n: int, floor_y: float) -> void:
		var to_here := space.get_global_transform().affine_inverse() * rock.get_global_transform()
		var c := to_here * rock.centre
		for poly: PackedVector2Array in rock.pieces(n):
			var moved := PackedVector2Array()
			var mid := Vector2.ZERO
			for p: Vector2 in poly:
				mid += to_here * p
			mid /= poly.size()
			for p: Vector2 in poly:
				moved.append(to_here * p - mid)
			var out := (mid - c).normalized()
			_add({"kind": "piece", "p": mid, "v": out * rng.randf_range(240, 420) + Vector2(0, -300), "c": rock.body, "life": 0.0, "max": 1.0,
				"poly": moved, "tris": _triangles(moved), "spin": rng.randf_range(-6, 6), "turn": 0.0, "floor": floor_y + rng.randf_range(-20, 20), "bounced": false})
		_add({"kind": "flash", "p": c, "life": 0.0, "max": 0.2, "r": rock.radius * 1.2})
		for i in 5:
			_add({"kind": "dust", "p": c + Vector2(rng.randf_range(-rock.radius, rock.radius), rng.randf_range(10, 40)), "life": 0.0, "max": 0.7,
				"r": rng.randf_range(20, 36)})

	## A piece's triangles, worked out once (RockPlusView hands out pieces
	## that triangulate; one that does not is not drawn).
	static func _triangles(poly: PackedVector2Array) -> PackedInt32Array:
		return Geometry2D.triangulate_polygon(poly)

	func _process(delta: float) -> void:
		if items.is_empty():
			return
		var landed: Array[Vector2] = []
		for it: Dictionary in items:
			it["life"] = float(it["life"]) + delta
			if it.has("v"):
				it["v"] = (it["v"] as Vector2) + Vector2(0, 1250 if String(it["kind"]) != "spark" else 600) * delta
				it["p"] = (it["p"] as Vector2) + (it["v"] as Vector2) * delta
			if it.has("turn"):
				it["turn"] = float(it["turn"]) + float(it["spin"]) * delta
			# One bounce on the island, then they lie still and fade.
			if it.has("floor") and (it["p"] as Vector2).y > float(it["floor"]) and (it["v"] as Vector2).y > 0.0:
				var v: Vector2 = it["v"]
				if bool(it["bounced"]):
					it["v"] = Vector2.ZERO
					it["spin"] = 0.0
				else:
					it["v"] = Vector2(v.x * 0.5, -v.y * 0.32)
					it["bounced"] = true
					if String(it["kind"]) == "piece":
						landed.append(it["p"])
				it["p"] = Vector2((it["p"] as Vector2).x, float(it["floor"]))
		for p: Vector2 in landed:
			_add({"kind": "dust", "p": p, "life": 0.0, "max": 0.5, "r": 14.0})
		items = items.filter(func(it: Dictionary) -> bool: return float(it["life"]) < float(it["max"]))
		queue_redraw()

	## All of them in one draw command: every shape as triangles in one array.
	## A circle or a piece per draw call costs a render object each, and C+ at
	## its busiest (a break on every hit) drew 2,200-2,950 objects to C's 500
	## -- the size of the frame drop Step 93 found in D.
	func _draw() -> void:
		if items.is_empty():
			return
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for it: Dictionary in items:
			var life := float(it["life"]) / float(it["max"])
			var a := clampf((1.0 - life) / 0.35, 0.0, 1.0)
			match String(it["kind"]):
				"flash":
					_disc(pts, cols, idx, it["p"], float(it["r"]) * (0.4 + 0.8 * life), Color(1, 1, 0.92, 0.55 * (1.0 - life)), 14)
				"dust":
					_disc(pts, cols, idx, it["p"], float(it["r"]) * (0.6 + 0.8 * life), Color(0.93, 0.9, 0.84, 0.45 * (1.0 - life)), 10)
				"spark":
					var p: Vector2 = it["p"]
					var v: Vector2 = it["v"]
					_stroke(pts, cols, idx, p, p - v * 0.035, 3.0, Color(it["c"], 1.0 - life))
				"chip":
					_disc(pts, cols, idx, it["p"], float(it["r"]) * maxf(a, 0.3), Color(it["c"], a), 7)
				"piece":
					var xf := Transform2D(float(it["turn"]), Vector2.ONE * 0.85, 0.0, it["p"])
					# The ink rim first, a little bigger, then the stone on it.
					_shape(pts, cols, idx, xf, it["poly"], it["tris"], 1.12, Color(RockView.INK, a))
					_shape(pts, cols, idx, xf, it["poly"], it["tris"], 1.0, Color((it["c"] as Color).darkened(0.08), a))
		if not idx.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)

	static func _disc(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, c: Vector2, r: float, col: Color, n: int) -> void:
		var base := pts.size()
		pts.append(c)
		cols.append(col)
		for k in n:
			var a := TAU * k / n
			pts.append(c + Vector2(cos(a), sin(a)) * r)
			cols.append(col)
		for k in n:
			idx.append_array([base, base + 1 + k, base + 1 + (k + 1) % n])

	static func _stroke(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, a: Vector2, b: Vector2, w: float, col: Color) -> void:
		var n := (b - a).orthogonal().normalized() * w * 0.5
		var base := pts.size()
		pts.append_array([a + n, b + n, b - n, a - n])
		cols.append_array([col, col, col, col])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	static func _shape(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, xf: Transform2D, poly: PackedVector2Array, tris: PackedInt32Array, k: float, col: Color) -> void:
		var base := pts.size()
		for p: Vector2 in poly:
			pts.append(xf * (p * k))
			cols.append(col)
		for t: int in tris:
			idx.append(base + t)


## The rock's health: a white lag that follows the drop, the number on it; it
## kicks up a little at each hit (back to `home`).
class _HpBar extends Control:
	var hp := 1
	var max_hp := 1
	var lag := 1.0
	var kick := 0.0
	var home := Vector2.ZERO

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
		if kick > 0.0:
			kick = maxf(0.0, kick - delta * 9.0)
			position = home + Vector2(0, -6.0 * kick)

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
	var r := RockPlusLevels.rock(rock_index)
	return {"coins": coins, "earned": earned, "pick": pick, "damage": RockPlusLevels.damage(pick), "rock": rock_index,
		"rock_name": r["name"], "kind": r["kind"], "kind_step": r["step"], "big": r["big"], "big_breaks": big_breaks,
		"next_big": RockPlusLevels.rock(_goal_shown)["name"], "chunk_coins": chunk_coins, "hp": hp, "max_hp": max_hp, "taps": taps, "hits": hits, "hold_hits": hold_hits,
		"misses": misses, "damage_total": damage_total, "breaks": breaks, "chunks": chunks, "first_break_ms": first_break_ms,
		"rising": rise_left > 0.0, "breaking": _hold_left > 0.0, "next_cost": RockPlusLevels.cost(pick + 1), "cracks": rock_view.damage_frac,
		"stage": rock_view.stage, "marks": rock_view.marks.size(), "bits": bits.items.size(), "impact": snappedf(last_impact, 0.01),
		"tier": String(RockPlusFeel.tier(pick)["name"]), "contact": swing.in_contact(), "hit_sounds": hit_sounds, "holding": _holding, "touch": _touch,
		"variant": variant, "rock_rect": [rr.position.x, rr.position.y, rr.size.x, rr.size.y], "goal_visible": goal_world.visible}


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += int(arg)
			action_changed.emit()
			return {"ok": true, "coins": coins}
		"rock":
			# Jumps to rock `arg` (pictures, tests).
			_set_rock_state(int(arg))
			_show_rock(int(arg))
			_place_rock()
			return {"ok": true, "rock": rock_index}
		"pick":
			pick = maxi(0, int(arg))
			swing.set_pick(pick)
			_update_chip()
			action_changed.emit()
			return {"ok": true, "pick": pick}
		"hits":
			# `arg` hits on the rock's middle, as taps would land (waiting out a rise).
			for i in int(arg):
				if rise_left > 0.0:
					if _hold_left > 0.0:
						_burst()
					rise_left = 0.0
					_place_rock()
				tap_at(get_global_transform().affine_inverse() * (rock_view.get_global_transform() * rock_view.centre))
			return {"ok": true, "rock": rock_index, "hp": hp}
	return null
