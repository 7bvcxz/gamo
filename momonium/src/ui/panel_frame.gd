class_name PanelFrame
extends Control

## The one way the game shows more than the HUD: a card over a faint scrim,
## with a title (or, with several bodies, a row of tabs in its place), a close
## button and a body. Tapping the scrim or ✕ closes it; while closed it takes
## no input at all, so the island view stays clean and touchable. The frame
## sits under the HUD, so the corner buttons keep working while it is open.
##
## Bodies are small views with `refresh()` that read the simulation when they
## draw -- nothing is copied into the panel. The frame refreshes the visible
## one on every simulation event and a few times a second for running timers.

signal opened
signal closed

const MAX_WIDTH := 560.0

var scrim: ColorRect
var card: PanelContainer
var scroll: ScrollContainer
var title_label: Label
var close_button: Button
var tab_bar: HBoxContainer
var body: VBoxContainer
var tabs: Array[Dictionary] = []
var current := -1
## Pixels on the right the card must leave free (the HUD's side buttons).
var right_reserved := 100.0
var _refresh_left := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	scrim = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.02, 0.08, 0.18, 0.18)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and not e.pressed) or (e is InputEventScreenTouch and not e.pressed):
			close())
	add_child(scrim)
	card = PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	tab_bar = HBoxContainer.new()
	tab_bar.name = "Tabs"
	tab_bar.add_theme_constant_override("separation", 6)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.visible = false
	head.add_child(tab_bar)
	close_button = PanelViews.close_button(52.0)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	col.add_child(head)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	resized.connect(_layout)


## Refresh on every simulation event while open, so values follow the
## simulation the moment it changes (not only on the 4 Hz timer tick).
func watch(sim: Simulation) -> void:
	sim.bus.emitted.connect(_on_sim_event)


func _on_sim_event(_type: StringName, _payload: Dictionary) -> void:
	if visible:
		refresh()


func set_title(text: String) -> void:
	title_label.text = text


## Adds a tab: `view` is a Control with refresh(); `label_key` its button.
func add_tab(label_key: String, view: Control) -> void:
	var button := Button.new()
	button.name = "Tab_" + label_key
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	var index := tabs.size()
	button.pressed.connect(func() -> void: show_tab(index))
	tab_bar.add_child(button)
	view.visible = false
	body.add_child(view)
	tabs.append({"key": label_key, "view": view, "button": button})
	tab_bar.visible = tabs.size() > 1
	title_label.visible = not tab_bar.visible
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relabel()


func show_tab(index: int) -> void:
	current = clampi(index, 0, tabs.size() - 1)
	for i in tabs.size():
		(tabs[i]["view"] as Control).visible = i == current
		(tabs[i]["button"] as Button).modulate = Color(1.25, 1.2, 0.85) if i == current else Color(1, 1, 1, 0.7)
	refresh()
	_layout.call_deferred()


func open(tab: int = 0) -> void:
	var was := visible
	visible = true
	show_tab(tab)
	_layout()
	if not was:
		opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle(tab: int = 0) -> void:
	if visible:
		close()
	else:
		open(tab)


func refresh() -> void:
	if current >= 0 and current < tabs.size():
		var v: Control = tabs[current]["view"]
		if v.has_method("refresh"):
			v.call("refresh")
		_layout.call_deferred()


func current_view() -> Control:
	return tabs[current]["view"] if current >= 0 and current < tabs.size() else null


## Escape (or a phone's back gesture mapped to it) closes the open panel.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		refresh()


func _relabel() -> void:
	for t: Dictionary in tabs:
		(t["button"] as Button).text = tr(t["key"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and tab_bar != null:
		_relabel()


## Centred in the space left of the side buttons; as tall as its body up to
## about two thirds of the screen, then the body scrolls.
func _layout() -> void:
	if card == null:
		return
	var w := size.x
	var avail := maxf(w - 16.0 - right_reserved, 320.0)
	card.custom_minimum_size.x = minf(MAX_WIDTH, avail)
	var content := body.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(content, maxf(size.y * 0.66, 200.0))
	card.reset_size()
	var y := minf(size.y * 0.12, maxf(size.y - card.size.y - 120.0, 8.0))
	card.position = Vector2(16.0 + maxf((avail - card.size.x) * 0.5, 0.0), y)


func card_rect() -> Rect2:
	return card.get_global_rect()
