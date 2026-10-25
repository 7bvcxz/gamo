class_name LandBuyer
extends RefCounted

## Buying the sea next to the island, where it is.
##
## With a mouse, hovering a sea tile that touches the island (side by side,
## never only by a corner) shows the block it would become and its price; a
## click buys it on the spot. With a finger there is no hover, so the first tap
## shows the same preview with "tap again", and only a second tap on the same
## tile buys -- a stray tap on the sea never spends money. Tiles that cannot
## be bought now are shown red with the reason (not enough money, not yet
## open). Drags and brush strokes never reach here: the input router only
## sends taps that did not move, and editing a Momo's tiles takes taps first.

var sim: Simulation
var land: LandSystem
var world: WorldSystem
var preview: LandPreview
var projection: IsoProjection
## The tile a finger has previewed and a second tap would buy.
var pending := LandPreview.NONE
var hover := LandPreview.NONE
var last_result: Dictionary = {}


func setup(p_sim: Simulation, p_preview: LandPreview, p_projection: IsoProjection) -> void:
	sim = p_sim
	land = sim.system(&"land")
	world = sim.system(&"world")
	preview = p_preview
	projection = p_projection


## A sea tile that touches the island.
func buyable(cell: Vector2i) -> bool:
	return world.is_purchasable(cell)


func on_hover(world_pos: Vector2) -> void:
	var cell := projection.cell_at(world_pos)
	if buyable(cell):
		hover = cell
		_show(cell, "")
	elif pending == LandPreview.NONE:
		hover = LandPreview.NONE
		preview.clear()


## A tap or click on the world. Returns whether it was about land to buy.
func on_tap(world_pos: Vector2, mouse: bool) -> bool:
	var cell := projection.cell_at(world_pos)
	if not buyable(cell):
		clear()
		return false
	if mouse or pending == cell:
		buy(cell)
	else:
		pending = cell
		last_result = {}
		_show(cell, tr_hint("land.tap_again"))
	return true


func buy(cell: Vector2i) -> void:
	last_result = sim.execute({"type": "land.buy", "cell": [cell.x, cell.y]})
	if last_result["ok"]:
		pending = LandPreview.NONE
		hover = LandPreview.NONE
		preview.clear()
		# The new land rises out of the sea (the island already owns it).
		var fx := LandRiseEffect.new()
		fx.name = "LandRise"
		fx.projection = projection
		fx.cell = cell
		preview.get_parent().add_child(fx)
	else:
		_show(cell, "")


func clear() -> void:
	pending = LandPreview.NONE
	hover = LandPreview.NONE
	preview.clear()


## The block, gold or red, and why it cannot be bought now if it cannot.
func _show(cell: Vector2i, hint: String) -> void:
	var why := _why_not()
	preview.show_cell(cell, why == "", why if why != "" else hint)


func _why_not() -> String:
	if not (sim.system(&"progression") as ProgressionSystem).is_unlocked("land"):
		return TranslationServer.translate("build.unlock_at") % sim.data.get_int("balance", "unlocks.land.level", 1)
	if not (sim.system(&"economy") as EconomySystem).can_afford(land.next_cost()):
		return TranslationServer.translate("land.short")
	return ""


static func tr_hint(key: String) -> String:
	return TranslationServer.translate(key)
