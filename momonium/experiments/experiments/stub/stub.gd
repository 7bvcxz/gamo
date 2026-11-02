extends LabExperiment

## The stub every experiment opens until it is built: the Lab's frame working
## end to end -- one resource (coins, one a second), one growing object (a
## plant beside Momo, a new picture at each step) and one button (Grow) -- and
## a COMING SOON card naming the real experiment. It proves a scene launches
## with Back, Restart, the play clock and the run report; it is not a game.

const STAGES: Array[String] = ["crop_seeds", "crop_sprout", "crop_leafy", "crop_ripe", "prop_bush", "prop_bush_flowers", "prop_tree"]
const BASE_COST := 5
const COST_GROWTH := 1.6

var coins := 0.0
var level := 0
var world: Node2D
var island: LabIsland
var ocean: LabOcean
var momo: LabMomo
var plant: Sprite2D
var card: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ocean = LabOcean.new()
	add_child(ocean)
	world = Node2D.new()
	add_child(world)
	island = LabIsland.new()
	island.reduced_motion = reduced_motion
	var cells: Array[Vector2i] = []
	for x in 3:
		for y in 3:
			cells.append(Vector2i(x, y))
	island.set_cells(cells)
	world.add_child(island)
	ocean.follow(island)
	momo = LabMomo.new()
	momo.reduced_motion = reduced_motion
	momo.position = island.iso.cell_center(Vector2i(1, 1)) + Vector2(-40, 10)
	island.add_child(momo)
	plant = Sprite2D.new()
	plant.centered = false
	plant.position = island.iso.cell_center(Vector2i(1, 1)) + Vector2(50, -10)
	island.add_child(plant)
	_show_plant()
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", LabStyle.box(Color(1, 1, 1, 0.92), 28))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := LabStyle.label("FRAME DEMO" if String(get_meta("lab_id", "")) == "stub" else "COMING SOON", 34, LabStyle.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := LabStyle.label(LabRegistry.label(String(get_meta("lab_id", ""))), 28, Color("#5b6b7a"))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(s)
	card.add_child(col)
	add_child(card)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var host_rect := Rect2(0, LabHost.TOP_UI, size.x, size.y - LabHost.TOP_UI - LabHost.BOTTOM_UI)
	world.position = Vector2(size.x * 0.5, host_rect.position.y + host_rect.size.y * 0.42 - 147.0)
	card.reset_size()
	card.position = Vector2((size.x - card.size.x) * 0.5, host_rect.end.y - card.size.y - 20.0)


func tick(dt: float) -> void:
	coins += rate() * dt
	session.metric("coins", int(coins))
	session.metric("level", level)


func rate() -> float:
	return 1.0 + level * 0.5


func cost() -> int:
	return int(round(BASE_COST * pow(COST_GROWTH, level)))


func hud() -> Dictionary:
	return {"value": coins, "rate": rate(), "icon": "icon_coin"}


func action_info() -> Dictionary:
	var done := level >= STAGES.size() - 1
	return {"label": "Grow", "cost": -1 if done else cost(), "affordable": not done and coins >= cost(),
		"icon": STAGES[mini(level + 1, STAGES.size() - 1)]}


func do_action() -> void:
	if level >= STAGES.size() - 1 or coins < cost():
		return
	var c := cost()
	coins -= c
	level += 1
	session.upgrade(level, c)
	_show_plant()
	momo.cheer()
	if audio != null:
		audio.play("built")
	if fx != null:
		fx.ring(to_fx(plant.get_global_transform() * Vector2(0, 0)))


func _show_plant() -> void:
	var pic := STAGES[level]
	plant.texture = LabAtlas.texture(pic)
	var k := LabAtlas.world_scale(pic) * 1.1
	plant.scale = Vector2(k, k)
	plant.offset = -LabAtlas.pivot(pic)


func state() -> Dictionary:
	return {"coins": coins, "level": level, "cost": cost(), "plant": STAGES[level]}


func dev(name: String, arg: Variant) -> Variant:
	if name == "coins":
		coins += float(arg)
		return {"ok": true, "coins": coins}
	return null
