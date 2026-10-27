class_name Tutorial
extends Control

## The first-run tutorial: a pulsing ring on the next thing to touch and one
## short line beside it -- on a new island the ripe crop waiting on its farm
## (the first tap is a harvest and its money, Step 50), then sowing and
## watering it again; on an island without one, an empty tile and the farm
## among the four choices first -- then a Momo and its tiles (Step 53: a new
## island has none, so first the farm by hand until the first hire is
## affordable -- the money counted beside the farm -- then the Hire button and
## its card; the hired Momo is selected, and its tiles follow), and at the end
## where the other buildings are (any empty tile) and how one comes down
## (trash, then the check, half back). Between the Momo and that end, the
## sea, once the island is nearly full: the tile it would grow into is ringed
## with its price until it is affordable, then "tap the glowing sea" -- buying
## land was the one core thing blind players found late or never (Step 50).
##
## It never takes over: the overlay ignores input (only its Skip / Got it
## buttons are buttons), nothing is opened or done for the player, and the
## step shown is worked out each frame from the world and the screen -- close
## the choices and it points at a tile again; build the farm another way and
## it moves on. Replaying it from Settings starts again on the island
## as it is: it waits for a new farm.

signal finished(skipped: bool)

const STEPS: PackedStringArray = ["harvest", "pick_tile", "pick_farm", "wait_build", "sow", "working", "water", "save_hire", "hire", "momo_select", "momo_pencil", "momo_edit", "land", "more"]

var sim: Simulation
var hud: Hud
var strip: BuildStrip
## For the Momo steps: what is selected, the pencil, where Momo stand.
var selection: SelectionController
var editor: WatchEditor
var momo_views: MomoViews
## The sea for sale: the tile it rings and whether it glows now.
var land_preview: LandPreview
## The menu the first Momo is hired from (Step 53).
var hire_menu: HireMenu
var _momo_done := false
var _land_done := false
var _edited := false
var cameras: CameraController
var projection: IsoProjection
var building_views: BuildingViews
var context: ContextPanel
var running := false
var step := ""
## The farm this run of the tutorial is about (0 until one is placed).
var farm := 0
## It began as the new island's ripe farm: harvest first, then sow and water.
var ripe_start := false
var _farms_at_start: Array[int] = []
var _time := 0.0
var bubble: PanelContainer
var text: Label
var skip_button: Button
var ok_button: Button
var target := Rect2()
var target2 := Rect2()


func setup(p_sim: Simulation, p_hud: Hud, p_strip: BuildStrip, p_cameras: CameraController, p_projection: IsoProjection, p_views: BuildingViews, p_context: ContextPanel = null) -> void:
	context = p_context
	sim = p_sim
	hud = p_hud
	strip = p_strip
	cameras = p_cameras
	projection = p_projection
	building_views = p_views
	name = "Tutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = PanelViews.label("", 19)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(290, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	ok_button = Button.new()
	ok_button.name = "Ok"
	ok_button.custom_minimum_size = Vector2(96, 48)
	ok_button.focus_mode = Control.FOCUS_NONE
	ok_button.pressed.connect(func() -> void: stop(false))
	row.add_child(ok_button)
	skip_button = Button.new()
	skip_button.name = "Skip"
	skip_button.custom_minimum_size = Vector2(96, 48)
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.flat = true
	skip_button.pressed.connect(func() -> void: stop(true))
	row.add_child(skip_button)
	bubble.add_child(row)
	add_child(bubble)
	visible = false


func start() -> void:
	running = true
	farm = 0
	ripe_start = false
	_momo_done = false
	_land_done = false
	_edited = false
	_farms_at_start.clear()
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		var b := bs.get_building(id)
		if String(b["type"]) != "farm":
			continue
		# A farm nobody has worked yet, its crop ripe: the new island's. The
		# tutorial starts on it. Any other farm is the island's past.
		if farm == 0 and int(b["completed"]) == 0 and b["state"] == BuildingSystem.IDLE and String(bs.current_stage(b).get("action", "")) == "harvest":
			farm = id
			ripe_start = true
		else:
			_farms_at_start.append(id)
	visible = true
	_update()


func stop(skipped: bool) -> void:
	if not running:
		return
	running = false
	if selection != null:
		selection.momo_slack = 0.0
	visible = false
	step = ""
	finished.emit(skipped)


func _process(delta: float) -> void:
	if not running:
		return
	_time += delta
	_update()
	queue_redraw()


## Which step the player is on, from the world and the screen.
func current_step() -> String:
	var bs: BuildingSystem = sim.system(&"buildings")
	if farm == 0:
		for id: int in bs.ids():
			if String(bs.get_building(id)["type"]) == "farm" and not _farms_at_start.has(id):
				farm = id
	if farm == 0 or bs.get_building(farm).is_empty():
		farm = 0
		return "pick_farm" if strip.open else "pick_tile"
	var b := bs.get_building(farm)
	if b["state"] == BuildingSystem.CONSTRUCTING:
		return "wait_build"
	var done := int(b["completed"])
	var hands := 3 if ripe_start else 2
	if done < hands and b["state"] == BuildingSystem.WORKING:
		return "working"
	if ripe_start:
		done -= 1
		if done < 0:
			return "harvest"
	if done == 0:
		return "sow"
	if done == 1:
		return "water"
	# Then the Momo: hire the first (Step 53: the island starts with none) --
	# by hand until it is affordable -- then tap one, its pencil, a tile or a
	# stroke -- unless one is already looking after something.
	var momo_system: MomoSystem = sim.system(&"momo")
	if not _momo_done and momo_system.ids().is_empty():
		var economy: EconomySystem = sim.system(&"economy")
		return "hire" if economy.can_afford(momo_system.hire_cost()) else "save_hire"
	if not _momo_done:
		var momos: MomoSystem = sim.system(&"momo")
		for m: int in momos.ids():
			if not momos.watched(m).is_empty() and not (editor != null and editor.active):
				_momo_done = true
	if not _momo_done and editor != null and selection != null:
		if editor.active and _edited:
			_momo_done = true
		elif editor.active:
			return "momo_edit"
		elif selection.kind == "momo":
			return "momo_pencil"
		else:
			return "momo_select"
	if not _land_done and land_preview != null:
		var land: LandSystem = sim.system(&"land")
		if not land.purchases.is_empty() or land_preview.grow_spot() == LandPreview.NONE:
			_land_done = true
		elif land_preview.due():
			return "land"
		else:
			# Quiet until the island is nearly full (LandPreview.due): the
			# player plays meanwhile, nothing on screen.
			return "later"
	return "more"


func _update() -> void:
	step = current_step()
	if selection != null:
		selection.momo_slack = 36.0 if step == "momo_select" else 0.0
	target = Rect2()
	target2 = Rect2()
	ok_button.visible = step == "more"
	ok_button.text = tr("tutorial.ok")
	skip_button.text = tr("tutorial.skip")
	skip_button.visible = step != "more"
	bubble.visible = step != "later"
	match step:
		"pick_tile":
			target = _cell_rect(suggested_tile())
			text.text = tr("tutorial.pick_tile")
		"pick_farm":
			target = _rect(strip.buttons.get("farm"))
			var cost := int(sim.data.building_type("farm").get("cost", {}).get("money", 0))
			text.text = tr("tutorial.pick_farm") % cost
		"wait_build":
			target = _building_rect(farm)
			text.text = tr("tutorial.wait_build")
		"harvest":
			target = _building_rect(farm)
			text.text = tr("tutorial.harvest")
		"sow":
			target = _building_rect(farm)
			target2 = _stage_card()
			text.text = tr("tutorial.sow")
		"working":
			target = _building_rect(farm)
			text.text = tr("tutorial.working")
		"water":
			target = _building_rect(farm)
			target2 = _stage_card()
			text.text = tr("tutorial.water")
		"save_hire":
			# Keep farming by hand: the farm, and how far the first Momo is.
			target = _building_rect(farm)
			var economy: EconomySystem = sim.system(&"economy")
			text.text = tr("tutorial.save_hire") % [economy.money, (sim.system(&"momo") as MomoSystem).hire_cost()]
		"hire":
			var card: Control = hire_menu.cards.get("momo") if hire_menu != null and hire_menu.visible else null
			target = _rect(card) if card != null else _rect(hud.buttons.get(&"hire"))
			text.text = tr("tutorial.hire") % (sim.system(&"momo") as MomoSystem).hire_cost()
		"momo_select":
			target = _momo_rect()
			text.text = tr("tutorial.momo_select")
		"momo_pencil":
			target = _rect(editor.pencil)
			text.text = tr("tutorial.momo_pencil")
		"momo_edit":
			target = _rect(editor.count_pill)
			text.text = tr("tutorial.momo_edit") % [(sim.system(&"momo") as MomoSystem).watched(editor.momo).size(), (sim.system(&"momo") as MomoSystem).watch_capacity(editor.momo)]
		"land":
			var land: LandSystem = sim.system(&"land")
			var glowing := land_preview.invitation()
			target = _cell_rect(glowing if glowing != LandPreview.NONE else land_preview.grow_spot())
			text.text = tr("tutorial.land_buy") if glowing != LandPreview.NONE else tr("tutorial.land_save") % land.next_cost()
		"more":
			text.text = tr("tutorial.wait_water") + "\n" + tr("tutorial.more")
			if strip.open:
				target = _rect(strip.buttons.get("lumberyard"))
				target2 = _rect(strip.buttons.get("mine"))
			elif context != null and context.trash_button.visible:
				target = _rect(context.trash_button)
				target2 = _rect(context.confirm_button)
			else:
				target = _cell_rect(suggested_tile())
	_place_bubble()


## The free tile of the island nearest its middle (ties: the first in cell
## order), to ring when the tutorial asks for a tap on empty ground.
func suggested_tile() -> Vector2i:
	var world: WorldSystem = sim.system(&"world")
	var cells := world.owned_cells()
	if cells.is_empty():
		return Vector2i.ZERO
	var middle := Vector2.ZERO
	for c: Vector2i in cells:
		middle += Vector2(c)
	middle /= float(cells.size())
	# Not where a Momo stands: a tap there picks the Momo, not the ground.
	var under: Array[Vector2i] = []
	var momos: MomoSystem = sim.system(&"momo")
	for id: int in momos.ids():
		var p := momos.position_of(id)
		under.append(Vector2i(floori(p.x), floori(p.y)))
	var best := Vector2i(-1, -1)
	var best_d := INF
	cells.sort()
	for c: Vector2i in cells:
		if not world.is_buildable(c) or under.has(c):
			continue
		var d := Vector2(c).distance_squared_to(middle)
		if d < best_d - 0.001:
			best_d = d
			best = c
	return best if best.x >= 0 else cells[0]


## The Momo nearest the middle of the screen, on screen.
func _momo_rect() -> Rect2:
	if momo_views == null:
		return Rect2()
	var best := Rect2()
	var best_d := INF
	for id: int in (sim.system(&"momo") as MomoSystem).ids():
		var a := momo_views.actor(id)
		if a == null:
			continue
		var r := a.hit_rect()
		var sr := Rect2(cameras.world_to_screen(r.position), cameras.world_to_screen(r.end) - cameras.world_to_screen(r.position))
		var d := sr.get_center().distance_to(size * 0.5)
		if d < best_d:
			best = sr
			best_d = d
	return best


## The lit stage card of the tutorial's farm, when its panel is showing:
## tapping it does what tapping the farm does, and no Momo stands in front.
func _stage_card() -> Rect2:
	if context == null or context.building_id != farm:
		return Rect2()
	return _rect(context.current_card())


func _rect(c: Control) -> Rect2:
	return c.get_global_rect() if c != null and c.is_visible_in_tree() else Rect2()


func _cell_rect(cell: Vector2i) -> Rect2:
	var c := cameras.world_to_screen(projection.cell_center(cell))
	var w := projection.tile_width * cameras.camera.zoom.x * 0.5
	return Rect2(c - Vector2(w, w * 0.6), Vector2(w * 2.0, w * 1.2))


func _building_rect(id: int) -> Rect2:
	var view: BuildingView = building_views.view(id) if building_views != null else null
	if view == null:
		return Rect2()
	var r := view.hit_rect()
	var a := cameras.world_to_screen(r.position)
	var b := cameras.world_to_screen(r.end)
	return Rect2(a, b - a)


## Beside the target: below it when there is room, otherwise above, kept on
## screen -- and clear of the open build strip.
func _place_bubble() -> void:
	bubble.reset_size()
	var s := bubble.size
	var t := target if target.size != Vector2.ZERO else Rect2(size * 0.5, Vector2.ZERO)
	if target.size != Vector2.ZERO and target2.size != Vector2.ZERO:
		t = target.merge(target2)
	# The trash's check appears right above it: keep that spot clear too.
	if step == "more" and context != null and context.trash_button.visible:
		t = t.merge(context.confirm_button.get_global_rect())
	if strip.open:
		t = strip.strip_rect()
		var below := t.end.y + 14.0
		var y0 := below if below + s.y < size.y - 12.0 else t.position.y - s.y - 14.0
		bubble.position = Vector2(clampf(t.get_center().x - s.x * 0.5, 12.0, maxf(size.x - s.x - 12.0, 12.0)), clampf(y0, 80.0, maxf(size.y - s.y - 12.0, 80.0)))
		return
	var x := clampf(t.get_center().x - s.x * 0.5, 12.0, maxf(size.x - s.x - 12.0, 12.0))
	var y := t.end.y + 18.0
	if y + s.y > size.y - 110.0:
		y = t.position.y - s.y - 18.0
	bubble.position = Vector2(x, clampf(y, 80.0, maxf(size.y - s.y - 12.0, 80.0)))


func _draw() -> void:
	if not running:
		return
	for r: Rect2 in [target, target2]:
		if r.size == Vector2.ZERO:
			continue
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		var grown := r.grow(6.0 + 6.0 * pulse)
		draw_rect(grown, Color(1.0, 0.89, 0.48, 0.25 + 0.35 * (1.0 - pulse)), false, 4.0)
		draw_rect(r.grow(3.0), Color(1.0, 0.89, 0.48, 0.95), false, 3.0)
