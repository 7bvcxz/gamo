class_name LandMode
extends Control

## Land management. Opened by the HUD's Land button. While open, taps on the
## world choose a buyable cell instead of selecting things; a bottom bar shows
## the next price, a Buy button (with the price, disabled when it cannot be
## afforded) and a close button. Buying keeps the mode open so a player can
## shape the island cell by cell; closing (the button or Land again) returns
## taps to the world.

signal closed

var sim: Simulation
var land: LandSystem
var preview: LandPreview
var projection: IsoProjection
var lib: SpriteLibrary
var active := false
var chosen := Vector2i(-99999, -99999)
var last_result: Dictionary = {}

var bar: PanelContainer
var price_label: Label
var buy_button: Button
var close_button: Button


func setup(p_sim: Simulation, p_preview: LandPreview, p_projection: IsoProjection, p_lib: SpriteLibrary) -> void:
	sim = p_sim
	land = sim.system(&"land")
	preview = p_preview
	projection = p_projection
	lib = p_lib
	name = "LandMode"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar = PanelContainer.new()
	bar.name = "LandBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = lib.atlas_texture("ui_land")
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	price_label = Label.new()
	price_label.add_theme_font_size_override("font_size", 22)
	row.add_child(price_label)
	buy_button = Button.new()
	buy_button.name = "Buy"
	buy_button.custom_minimum_size = Vector2(150, 64)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.icon = lib.atlas_texture("icon_coin")
	buy_button.expand_icon = false
	buy_button.add_theme_constant_override("icon_max_width", 28)
	buy_button.add_theme_font_size_override("font_size", 22)
	buy_button.pressed.connect(confirm)
	row.add_child(buy_button)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "✕"
	close_button.custom_minimum_size = Vector2(64, 64)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(close)
	row.add_child(close_button)
	bar.add_child(row)
	bar.visible = false
	add_child(bar)
	resized.connect(_layout)
	sim.bus.emitted.connect(func(type: StringName, _p: Dictionary) -> void:
		if active and type in [&"money_changed", &"land_bought"]:
			_refresh())


func open() -> void:
	active = true
	chosen = Vector2i(-99999, -99999)
	preview.font = get_theme_default_font()
	preview.active = true
	preview.refresh()
	bar.visible = true
	_refresh()
	_layout()


func close() -> void:
	if not active:
		return
	active = false
	preview.active = false
	preview.queue_redraw()
	bar.visible = false
	closed.emit()


func toggle() -> void:
	if active:
		close()
	else:
		open()


## A tap on the world while the mode is open: choose a buyable cell, or clear.
func on_world_tap(world_pos: Vector2) -> void:
	var cell := projection.cell_at(world_pos)
	if preview.is_candidate(cell):
		chosen = cell
	else:
		chosen = Vector2i(-99999, -99999)
	_refresh()


func confirm() -> void:
	if not preview.is_candidate(chosen):
		return
	var cell := chosen
	last_result = sim.execute({"type": "land.buy", "cell": [cell.x, cell.y]})
	if last_result["ok"]:
		chosen = Vector2i(-99999, -99999)
		var fx := LandRiseEffect.new()
		fx.projection = projection
		fx.cell = cell
		preview.get_parent().add_child(fx)
	_refresh()


func _refresh() -> void:
	var cost := land.next_cost()
	var economy: EconomySystem = sim.system(&"economy")
	var can_pay := economy.can_afford(cost)
	price_label.text = "%s  $%d" % [tr("land.next"), cost]
	var has_choice := preview.is_candidate(chosen)
	buy_button.text = tr("land.buy") if can_pay else tr("err.not_enough_money")
	buy_button.disabled = not has_choice or not can_pay
	preview.chosen = chosen
	preview.affordable = can_pay
	preview.queue_redraw()
	_layout()


func _layout() -> void:
	if bar == null:
		return
	bar.reset_size()
	bar.position = Vector2((size.x - bar.size.x) * 0.5, size.y - bar.size.y - 104)
