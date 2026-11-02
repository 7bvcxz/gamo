extends LabExperiment

## Experiment F -- Endless Growth. One magical tree on a small island, a Momo
## at its foot. The tree makes coins while the page is seen; the one button,
## Grow Tree, turns it into its next shape (TreeLevels: sprout, sapling,
## branches, a wide canopy, blossom, fruit, glow, twin trunks, a spiral
## pagoda, crystal leaves, a treehouse, a sky tree, a rainbow, then endless
## wonders). The next shape stands behind the tree as a pale silhouette, so
## curiosity has something to look at. The foot never moves; the view draws
## back only when the tree would not fit, and the Momo and the island beside
## it keep the scale readable.

const POP_SECONDS := 1.3
const MAX_ZOOM := 1.5
const MIN_ZOOM := 0.42
const GROW_SECONDS := 1.1
const ZOOM_SECONDS := 0.5
## The big reveals: a fanfare and a milestone in the record.
const BIG_STAGES: Array[int] = [5, 8, 10, 13]

var coins := 0.0
var earned := 0.0
var stage := 0

var world: Node2D
var island: LabIsland
var ocean: LabOcean
var tree: TreeView
var old_tree: TreeView
var preview: TreeView
var momo: LabMomo
var chip: PanelContainer
var chip_label: Label
var _pop := 0.0
var _pops := 0
var _zoom_tween: Tween
var _time := 0.0
var _foot := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean = LabOcean.new()
	add_child(ocean)
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
	_foot = island.iso.cell_center(Vector2i(1, 1))
	preview = TreeView.new()
	preview.silhouette = true
	preview.position = _foot
	island.add_child(preview)
	old_tree = TreeView.new()
	old_tree.position = _foot
	old_tree.visible = false
	old_tree.reduced_motion = reduced_motion
	island.add_child(old_tree)
	tree = TreeView.new()
	tree.position = _foot
	tree.reduced_motion = reduced_motion
	island.add_child(tree)
	momo = LabMomo.new()
	momo.reduced_motion = reduced_motion
	momo.position = island.iso.cell_center(Vector2i(1, 2)) + Vector2(-46, 6)
	island.add_child(momo)
	_build_chip()
	_show(0, false)
	resized.connect(func() -> void: _frame(false))
	_frame(false)
	if audio != null:
		audio.start_ambience(true)


# --- the economy ----------------------------------------------------------------------

func tick(dt: float) -> void:
	var r := TreeLevels.rate(stage)
	coins += r * dt
	earned += r * dt
	_pop += dt
	_time += dt
	if _pop >= POP_SECONDS:
		_pop -= POP_SECONDS
		_show_income(r * POP_SECONDS)
	var ready := coins >= next_cost()
	preview.sil_color = Color(1, 1, 1, (0.34 + 0.1 * sin(_time * TAU * 0.7)) if ready and not reduced_motion else (0.4 if ready else 0.22))
	session.metric("stage", stage)
	session.metric("stage_name", String(TreeLevels.stage(stage)["name"]))
	session.metric("coins", int(coins))
	session.metric("earned", int(earned))
	session.metric("rate", TreeLevels.rate(stage))


func hud() -> Dictionary:
	return {"value": coins, "rate": TreeLevels.rate(stage), "icon": "icon_coin"}


func next_cost() -> int:
	return TreeLevels.cost(stage + 1)


func action_info() -> Dictionary:
	return {"label": "Grow Tree", "cost": next_cost(), "affordable": coins >= next_cost(), "icon": "prop_tree"}


func do_action() -> void:
	var c := next_cost()
	if coins < c:
		return
	coins -= c
	stage += 1
	var shape_name := String(TreeLevels.stage(stage)["name"])
	var big := stage in BIG_STAGES
	session.upgrade(stage, c, {"shape": shape_name})
	if big:
		session.milestone(shape_name, {"stage": stage})
	_show(stage, true)
	momo.cheer(1.3)
	if audio != null:
		audio.play("promote" if big else "built", 1.0, -2.0)
	if fx != null:
		var top := tree.get_global_transform() * Vector2(0, -tree.extent().y * 0.6)
		fx.float_text(to_fx(top) + Vector2(0, -40), shape_name + "!", Color.WHITE, 48)
		fx.ring(to_fx(top), Color(0.85, 1, 0.75), 220.0)
		fx.coins(to_fx(top), 8, "icon_star")
	action_changed.emit()


# --- the tree --------------------------------------------------------------------------------

func _show(n: int, animate: bool) -> void:
	if animate and not reduced_motion:
		old_tree.set_shape(tree.shape, 1000 + n - 1)
		old_tree.grow = 1.0
		old_tree.visible = true
		old_tree.modulate.a = 1.0
		var out := old_tree.create_tween().set_parallel(true)
		out.tween_property(old_tree, "modulate:a", 0.0, 0.35)
		out.chain().tween_callback(func() -> void: old_tree.visible = false)
		tree.set_shape(TreeLevels.stage(n), 1000 + n)
		tree.grow = 0.0
		var tw := tree.create_tween()
		tw.tween_property(tree, "grow", 1.0, GROW_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tree.set_shape(TreeLevels.stage(n), 1000 + n)
		tree.grow = 1.0
	preview.set_shape(TreeLevels.stage(n + 1), 1000 + n + 1)
	_update_chip()
	_frame(animate)


## Fits the tree and the island between the
## frame's top and its button: the same size while it fits (MAX_ZOOM), so
## the tree grows on screen, drawing back only past that (MIN_ZOOM at least).
func _frame(animate: bool) -> void:
	if size.x <= 0.0:
		return
	# The tree as it is now (the next shape's silhouette may reach past the
	# view: it is a hint, and framing for it would shrink the tree first).
	var e := tree.extent()
	var half_w := maxf(e.x, 200.0)
	var height := e.y
	var b := Rect2(_foot + Vector2(-half_w, -height), Vector2(half_w * 2.0, height))
	b = b.merge(island.screen_bounds()).grow(20.0)
	var area := Rect2(0, LabHost.TOP_UI + 64.0, size.x, size.y - LabHost.TOP_UI - 64.0 - LabHost.BOTTOM_UI)
	var k := clampf(minf(area.size.x / b.size.x, area.size.y / b.size.y), MIN_ZOOM, MAX_ZOOM)
	var pos := Vector2(area.get_center().x - b.get_center().x * k, area.end.y - b.end.y * k)
	if _zoom_tween != null:
		_zoom_tween.kill()
	if animate and not reduced_motion:
		_zoom_tween = create_tween().set_parallel(true)
		# Quicker than the tree grows in (GROW_SECONDS): the view is ready
		# before the new shape reaches its full size.
		_zoom_tween.tween_property(world, "scale", Vector2(k, k), ZOOM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_zoom_tween.tween_property(world, "position", pos, ZOOM_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		world.scale = Vector2(k, k)
		world.position = pos


func _show_income(amount: float) -> void:
	if fx == null or reduced_motion:
		return
	var tips: Array = tree.geo.get("tips", [])
	if tips.is_empty():
		return
	var t: Dictionary = tips[(_pops * 7) % tips.size()]
	_pops += 1
	var at := to_fx(tree.get_global_transform() * (t["p"] as Vector2))
	fx.float_text(at, "+%d" % int(round(amount)), Color("#ffe27a"), 30)
	fx.coins(at, 1)
	if audio != null and _pops % 3 == 0:
		audio.play("coin", 1.15, -14.0)


func _build_chip() -> void:
	chip = PanelContainer.new()
	chip.name = "StageChip"
	chip.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.85), 22, Color(0, 0, 0, 0), 0, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_label = LabStyle.label("", 26, LabStyle.INK)
	chip.add_child(chip_label)
	add_child(chip)


func _update_chip() -> void:
	chip_label.text = "Tree %d · %s" % [stage, TreeLevels.stage(stage)["name"]]
	chip.reset_size()
	chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and chip != null:
		chip.position = Vector2((size.x - chip.size.x) * 0.5, LabHost.TOP_UI)


# --- tests and the page --------------------------------------------------------------------------

## The tree's box on screen (canvas pixels): its foot to its top.
func tree_rect() -> Rect2:
	var e := tree.extent()
	var a := tree.get_global_transform() * Vector2(-e.x, -e.y)
	var b := tree.get_global_transform() * Vector2(e.x, 0)
	return Rect2(a, b - a)


func state() -> Dictionary:
	var r := tree_rect()
	var foot := tree.get_global_transform() * Vector2.ZERO
	return {"coins": coins, "earned": earned, "stage": stage, "name": TreeLevels.stage(stage)["name"],
		"next_name": TreeLevels.stage(stage + 1)["name"], "rate": TreeLevels.rate(stage), "next_cost": next_cost(),
		"tree_rect": [r.position.x, r.position.y, r.size.x, r.size.y], "foot": [foot.x, foot.y], "zoom": world.scale.x,
		"segments": (tree.geo["segs"] as Array).size(), "tips": (tree.geo["tips"] as Array).size(),
		"crown": String(tree.shape.get("crown", "")), "preview": preview.visible and not preview.geo.is_empty(),
		"settled": tree.grow >= 1.0 and (_zoom_tween == null or not _zoom_tween.is_running())}


func intent_question() -> String:
	return "See the next tree?"


func dev(name: String, arg: Variant) -> Variant:
	match name:
		"coins":
			coins += float(arg)
			return {"ok": true, "coins": coins}
		"stage":
			var to := int(arg)
			while stage < to:
				coins += next_cost()
				do_action()
			return {"ok": true, "stage": stage}
	return null
