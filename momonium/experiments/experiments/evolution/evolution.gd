extends LabExperiment

## Experiment B -- Momo Evolution. One Momo is the thing that grows. It works
## by itself at one spot beside it (a seed bed, a sprout, ripe crops, logs, a
## rock, an anvil, a desk), each finished pass of its work paying coins, and
## the one button, Upgrade Momo, makes this Momo better: a new tool and a new
## motion every second level (the game's own work loops: seed pouch, watering
## can, basket, axe, pickaxe, hammer, flask), and in between something to
## wear and a quicker hand (EvolutionLevels). The Momo keeps the game's size
## (0.8, the Step 76 root between its feet) and the camera never moves: only
## the Momo changes. What the next level brings is shown first: a thing to
## wear as a pale outline on the Momo, a new tool in a thought bubble.

## How big the world is drawn: the Momo about 200 px tall on a phone (the
## same size at every level; only the camera's fit to the window decides it).
const ZOOM := 3.6
const BURST_ITEMS := 1

var coins := 0
var earned := 0
var level := 0
var cycle_t := 0.0
var passes := 0

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var momo: LabMomo
var ghost: LabMomo
var spot: Sprite2D
var spot_draw: _Spot
var bubble: _Bubble
var chip: PanelContainer
var chip_label: Label
var _last_frame := -1
var _tool_tex := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean = LabOcean.new()
	add_child(ocean)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	island = LabIsland.new()
	island.set_cells([Vector2i(0, 0)])
	world.add_child(island)
	ocean.follow(island)
	var centre := island.iso.cell_center(Vector2i(0, 0))
	spot = Sprite2D.new()
	spot.centered = false
	spot.position = centre + Vector2(30, 6)
	island.add_child(spot)
	spot_draw = _Spot.new()
	spot_draw.position = spot.position
	spot_draw.scale = Vector2(1.5, 1.5)
	island.add_child(spot_draw)
	momo = LabMomo.new()
	momo.reduced_motion = reduced_motion
	momo.position = centre + Vector2(-14, 4)
	island.add_child(momo)
	ghost = LabMomo.new()
	ghost.position = momo.position
	ghost.only_wear = true
	ghost.modulate = Color(1.7, 1.7, 1.9, 0.0)
	ghost.set_meta("ghost", true)
	island.add_child(ghost)
	bubble = _Bubble.new()
	bubble.position = momo.position + Vector2(-34, -78)
	island.add_child(bubble)
	_build_chip()
	_apply(false)
	resized.connect(_layout)
	_layout()
	if audio != null:
		audio.start_ambience(true)


# --- the work and the pay ---------------------------------------------------------------

func tick(dt: float) -> void:
	cycle_t += dt
	var c := EvolutionLevels.cycle(level)
	while cycle_t >= c:
		cycle_t -= c
		_paid()
	# The picture follows the same clock: the frame that pays is the pass's end.
	var pose := String(EvolutionLevels.row(level)["pose"])
	var t := cycle_t / c * LabMomo.loop_seconds(pose)
	momo.work_t = t
	ghost.work_t = t
	var f: Array = LabMomo.frame_at(pose, t)
	var contact := int(float((LabMomo.work()["animations"] as Dictionary)[pose].get("contact", -1.0)))
	if int(f[1]) != _last_frame:
		if int(f[1]) == contact and audio != null:
			var tap := String((LabMomo.work()["animations"] as Dictionary)[pose].get("tap", "tap_soft")).trim_prefix("tap_")
			audio.play({"soft": "soft", "water": "water", "pick": "pick", "wood": "wood", "metal": "metal"}.get(tap, "soft"), 1.0, -9.0, 0.06)
		_last_frame = int(f[1])
	var ready := coins >= EvolutionLevels.cost(level + 1)
	var a := 0.0 if ghost.accessories.is_empty() else ((0.5 + 0.25 * sin(session.active_ms / 1000.0 * TAU * 0.7)) if ready and not reduced_motion else (0.6 if ready else 0.35))
	ghost.modulate.a = a
	bubble.affordable = ready
	session.metric("level", level)
	session.metric("stage", String(EvolutionLevels.row(level)["name"]))
	session.metric("coins", coins)
	session.metric("earned", earned)
	session.metric("passes", passes)
	session.metric("rate", snappedf(EvolutionLevels.rate(level), 0.01))


func _paid() -> void:
	var pay := int(EvolutionLevels.row(level)["pay"])
	coins += pay
	earned += pay
	passes += 1
	if fx != null and not reduced_motion:
		var at := to_fx(spot.get_global_transform() * Vector2(0, -24))
		fx.float_text(at + Vector2(0, -30), "+%d" % pay, Color("#ffe27a"), 34)
		fx.coins(at, BURST_ITEMS, String(EvolutionLevels.row(level)["item"]))
	if audio != null and passes % 2 == 0:
		audio.play("coin", 1.1, -14.0)


func hud() -> Dictionary:
	return {"value": coins, "rate": snappedf(EvolutionLevels.rate(level), 0.1), "icon": "icon_coin"}


func action_info() -> Dictionary:
	var c := EvolutionLevels.cost(level + 1)
	var nxt := level + 1
	var info := {"label": "Upgrade Momo", "cost": c, "affordable": coins >= c}
	if EvolutionLevels.new_tool(nxt):
		info["texture"] = _tool(String(EvolutionLevels.row(nxt)["tool"]))
	else:
		info["icon"] = "momo_front"
	return info


func do_action() -> void:
	var c := EvolutionLevels.cost(level + 1)
	if coins < c:
		return
	coins -= c
	var old_cycle := EvolutionLevels.cycle(level)
	level += 1
	# The pass under way keeps its share of the work done.
	cycle_t *= EvolutionLevels.cycle(level) / old_cycle
	var r := EvolutionLevels.row(level)
	var tool := EvolutionLevels.new_tool(level)
	session.upgrade(level, c, {"name": String(r["name"]), "pose": String(r["pose"]), "tool": tool})
	if tool:
		session.milestone(String(r["name"]), {"level": level, "pose": String(r["pose"])})
	_apply(true)
	momo.cheer(0.9)
	if audio != null:
		audio.play("promote" if tool else "built", 1.0, -2.0)
	if fx != null:
		var head := to_fx(momo.get_global_transform() * Vector2(0, -momo.height() - 10.0))
		fx.float_text(head + Vector2(0, -24), String(r["name"]) + "!", Color.WHITE, 44 if tool else 36)
		fx.ring(to_fx(momo.get_global_transform() * Vector2(0, -momo.height() * 0.5)), Color(1, 0.95, 0.65), 170.0 if tool else 120.0)
	action_changed.emit()


# --- the Momo and its spot --------------------------------------------------------------------

func _apply(animate: bool) -> void:
	var r := EvolutionLevels.row(level)
	momo.work_anim = String(r["pose"])
	momo.accessories = EvolutionLevels.wearing(level)
	momo.sparkle = int(r.get("sparkle", 0))
	ghost.work_anim = momo.work_anim
	# The next level as a teaser: the thing to wear, pale on the Momo, or the
	# next tool dreamt of in a bubble.
	var nxt := level + 1
	var now := EvolutionLevels.wearing(level)
	var then := EvolutionLevels.wearing(nxt)
	var extra: Array[String] = []
	for w: String in then:
		if not now.has(w):
			extra.append(w)
	ghost.accessories = extra
	bubble.tool = _tool(String(EvolutionLevels.row(nxt)["tool"])) if EvolutionLevels.new_tool(nxt) else null
	bubble.visible = bubble.tool != null
	var s := String(r["spot"])
	spot_draw.kind = s
	spot.visible = LabAtlas.has(s)
	if spot.visible:
		spot.texture = LabAtlas.texture(s)
		var k := LabAtlas.world_scale(s) * 0.95
		spot.scale = Vector2(k, k)
		spot.offset = -LabAtlas.pivot(s)
	spot_draw.queue_redraw()
	if animate and not reduced_motion:
		spot.scale *= 0.2
		var to := spot.scale * 5.0
		spot.create_tween().tween_property(spot, "scale", to, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_chip()


func _tool(name: String) -> AtlasTexture:
	if not _tool_tex.has(name):
		_tool_tex[name] = LabGlove.tool_texture(name)
	return _tool_tex[name]


## The camera is fixed: the Momo stands in the middle of the play area at the
## same size the whole time, so only the Momo changes.
func _layout() -> void:
	if size.x <= 0.0:
		return
	var area := Rect2(0, LabHost.TOP_UI + 60.0, size.x, size.y - LabHost.TOP_UI - 60.0 - LabHost.BOTTOM_UI)
	var k := minf(ZOOM, minf(area.size.x / 200.0, area.size.y / 230.0))
	world.scale = Vector2(k, k)
	var foot := momo.position
	world.position = Vector2(area.get_center().x, area.position.y + area.size.y * 0.72) - foot * k
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "LevelChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	chip.add_child(chip_label)
	add_child(chip)


func _update_chip() -> void:
	chip_label.text = "Lv %d · %s" % [level, EvolutionLevels.row(level)["name"]]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


## A spot with no picture in the atlas: the anvil and the desk.
class _Spot extends Node2D:
	var kind := ""

	func _draw() -> void:
		match kind:
			"anvil":
				draw_colored_polygon(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0), Vector2(10, -8), Vector2(-10, -8)]), Color("#4d5560"))
				draw_colored_polygon(PackedVector2Array([Vector2(-22, -8), Vector2(24, -8), Vector2(30, -16), Vector2(-14, -16), Vector2(-26, -12)]), Color("#6f7a86"))
				draw_line(Vector2(-14, -16), Vector2(30, -16), Color("#a9b4c0"), 2.0)
			"desk":
				draw_rect(Rect2(-20, -16, 40, 5), Color("#a8744a"))
				draw_rect(Rect2(-17, -11, 3, 11), Color("#7a4b2f"))
				draw_rect(Rect2(14, -11, 3, 11), Color("#7a4b2f"))
				draw_rect(Rect2(-12, -24, 14, 8), Color("#f2e3c3"))
				draw_circle(Vector2(8, -21), 4.0, Color("#9fe3c4"))


## The next tool, dreamt of: a thought bubble over the Momo.
class _Bubble extends Node2D:
	var tool: Texture2D
	var affordable := false:
		set(v):
			if v != affordable:
				affordable = v
				queue_redraw()

	func _draw() -> void:
		if tool == null:
			return
		var a := 0.95 if affordable else 0.7
		draw_circle(Vector2(18, 16), 3.0, Color(1, 1, 1, a))
		draw_circle(Vector2(10, 8), 4.5, Color(1, 1, 1, a))
		draw_circle(Vector2(0, -12), 17.0, Color(1, 1, 1, a))
		var r := Rect2(Vector2(-11, -24), Vector2(22, 24))
		draw_texture_rect(tool, r, false, Color(1, 1, 1, a))


# --- tests and the page -------------------------------------------------------------------------

func state() -> Dictionary:
	var f: Array = LabMomo.frame_at(momo.work_anim, momo.work_t)
	var foot := momo.get_global_transform() * Vector2.ZERO
	return {"coins": coins, "earned": earned, "level": level, "name": EvolutionLevels.row(level)["name"],
		"pose": momo.work_anim, "frame": f[0], "frame_index": f[1], "cycle_t": cycle_t, "cycle": EvolutionLevels.cycle(level),
		"passes": passes, "wearing": momo.accessories, "teaser_wear": ghost.accessories, "teaser_tool": bubble.visible,
		"next_cost": EvolutionLevels.cost(level + 1), "rate": EvolutionLevels.rate(level),
		"foot": [foot.x, foot.y], "momo_height": momo.height() * world.scale.x, "zoom": world.scale.x}


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += int(arg)
			action_changed.emit()
			return {"ok": true, "coins": coins}
		"level":
			var to := int(arg)
			while level < to:
				coins += EvolutionLevels.cost(level + 1)
				do_action()
			return {"ok": true, "level": level}
	return null
