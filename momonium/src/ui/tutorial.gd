class_name Tutorial
extends Control

## The first-run tutorial: a pulsing ring on the next thing to touch and one
## short line beside it -- an empty tile, the farm among the four choices that
## open beside it, then the first sowing and watering -- and at the end where
## the other buildings are (any empty tile) and how one comes down (trash, then
## the check, half back).
##
## It never takes over: the overlay ignores input (only its Skip / Got it
## buttons are buttons), nothing is opened or done for the player, and the
## step shown is worked out each frame from the world and the screen -- close
## the choices and it points at a tile again; build the farm another way and
## it moves on. Replaying it from Settings starts again on the island
## as it is: it waits for a new farm.

signal finished(skipped: bool)

const STEPS: PackedStringArray = ["pick_tile", "pick_farm", "wait_build", "sow", "working", "water", "more"]

var sim: Simulation
var hud: Hud
var strip: BuildStrip
var cameras: CameraController
var projection: IsoProjection
var building_views: BuildingViews
var context: ContextPanel
var running := false
var step := ""
## The farm this run of the tutorial is about (0 until one is placed).
var farm := 0
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
	_farms_at_start.clear()
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		if String(bs.get_building(id)["type"]) == "farm":
			_farms_at_start.append(id)
	visible = true
	_update()


func stop(skipped: bool) -> void:
	if not running:
		return
	running = false
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
	if done < 2 and b["state"] == BuildingSystem.WORKING:
		return "working"
	if done == 0:
		return "sow"
	if done == 1:
		return "water"
	return "more"


func _update() -> void:
	step = current_step()
	target = Rect2()
	target2 = Rect2()
	ok_button.visible = step == "more"
	ok_button.text = tr("tutorial.ok")
	skip_button.text = tr("tutorial.skip")
	skip_button.visible = step != "more"
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
