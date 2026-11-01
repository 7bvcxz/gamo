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
##
## Step 81 (design/PANELS81.md): the card sits in the band the HUD leaves free
## (`avoid`: every HUD rectangle -- the top cards, the side buttons, the corner
## buttons -- never under one); with several bodies the tabs have a row of
## their own under the title and the close button, the full width of the card,
## and scroll sideways in it alone (a fade at an edge says there are more);
## the body scrolls in its own bounded view behind a slim bar with a gutter,
## so no text runs under the bar; a view that scrolls its own parts
## (`owns_scroll`, the research tree and its details) gets the room
## (`room`) and the body does not scroll as well. The card takes every touch
## and wheel on it: nothing reaches the island through a panel.

signal opened
signal closed

const MAX_WIDTH := 560.0
## Screen units kept between the card and the screen's edge or a HUD piece.
const MARGIN := 12.0
## A scroll bar's width, and the room kept between it and the text.
const BAR := 6.0
const GUTTER := 8.0
## The tab row's height and its edge fades' width.
const TAB_H := 50.0
const FADE := 28.0

var scrim: ColorRect
var card: PanelContainer
var scroll: ScrollContainer
var title_label: Label
var close_button: Button
var tab_bar: HBoxContainer
var tab_scroll: ScrollContainer
var tab_row: Control
var tab_fade: Control
var body: VBoxContainer
var body_margin: MarginContainer
## HUD rectangles the card must stay clear of, in this frame's space.
var avoid: Array[Rect2] = []
## Where they come from, asked on every layout (the HUD may have laid itself
## out again since): -> {avoid: Array[Rect2], right: float} (Main).
var hud_space: Callable
## The height the body may take (Step 81): views that scroll their own parts
## size them to it.
var room := 400.0
var title_key := ""
## How wide the card may grow (Research: wider, for the tree and its details
## side by side where the screen has the room).
var max_width := MAX_WIDTH
var tabs: Array[Dictionary] = []
var current := -1
## Pixels on the right the card must leave free (the HUD's side buttons).
var right_reserved := 100.0
const CARD_ALPHA := 0.86
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
	# Every touch and wheel on the card stops at it (a Container lets them
	# through by default, and then they reached the island under it). A wheel
	# passes even a STOP control unless told not to: over a body with nothing
	# to scroll it zoomed the island.
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_force_pass_scroll_events = false
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 8)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title_label)
	close_button = PanelViews.close_button(48.0)
	close_button.pressed.connect(close)
	head.add_child(close_button)
	col.add_child(head)
	# The tabs' own row, under the head: as wide as the card, scrolling
	# sideways in itself when they do not fit (Research has one per industry).
	tab_row = Control.new()
	tab_row.name = "TabRow"
	tab_row.custom_minimum_size = Vector2(0, TAB_H)
	tab_row.clip_contents = true
	tab_row.visible = false
	col.add_child(tab_row)
	tab_scroll = ScrollContainer.new()
	tab_scroll.name = "TabScroll"
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_row.add_child(tab_scroll)
	tab_bar = HBoxContainer.new()
	tab_bar.name = "Tabs"
	tab_bar.add_theme_constant_override("separation", 6)
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(tab_bar)
	tab_fade = Control.new()
	tab_fade.name = "TabFade"
	tab_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_fade.draw.connect(_draw_tab_fade)
	tab_row.add_child(tab_fade)
	tab_scroll.get_h_scroll_bar().value_changed.connect(func(_v: float) -> void: tab_fade.queue_redraw())
	tab_scroll.get_h_scroll_bar().changed.connect(tab_fade.queue_redraw)
	scroll = ScrollContainer.new()
	scroll.name = "BodyScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	PanelViews.slim_bars(scroll)
	col.add_child(scroll)
	# The gutter: the body ends BAR + GUTTER short of the scroll's edge, so a
	# bar that shows never lies over text (and showing it moves nothing).
	body_margin = MarginContainer.new()
	body_margin.name = "BodyMargin"
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_right", int(BAR + GUTTER))
	scroll.add_child(body_margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_child(body)
	resized.connect(_layout)


## Refresh on every simulation event while open, so values follow the
## simulation the moment it changes (not only on the 4 Hz timer tick).
func watch(sim: Simulation) -> void:
	sim.bus.emitted.connect(_on_sim_event)


func _on_sim_event(_type: StringName, _payload: Dictionary) -> void:
	if visible:
		refresh()


func set_title(text: String) -> void:
	title_key = ""
	title_label.text = text


## A title read from the translations, again when the language changes.
func set_title_key(key: String) -> void:
	title_key = key
	title_label.text = tr(key)


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
	# A red dot on the tab when its body has news (set_tab_dot).
	button.draw.connect(func() -> void:
		if index < tabs.size() and bool(tabs[index].get("dot", false)):
			button.draw_circle(Vector2(button.size.x - 10, 10), 6.0, Color("#ff5a4f"))
			button.draw_arc(Vector2(button.size.x - 10, 10), 6.0, 0, TAU, 16, Color.WHITE, 1.5, true))
	tab_bar.add_child(button)
	view.visible = false
	body.add_child(view)
	tabs.append({"key": label_key, "view": view, "button": button})
	tab_row.visible = tabs.size() > 1
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relabel()


func set_tab_dot(index: int, on: bool) -> void:
	if index < 0 or index >= tabs.size() or bool(tabs[index].get("dot", false)) == on:
		return
	tabs[index]["dot"] = on
	(tabs[index]["button"] as Button).queue_redraw()


func tab_dot(index: int) -> bool:
	return index >= 0 and index < tabs.size() and bool(tabs[index].get("dot", false))


## Step 71: hides or shows a tab's button (a research tab with nothing to show
## yet). A hidden tab is never the current one while another is shown.
func set_tab_shown(index: int, on: bool) -> void:
	if index < 0 or index >= tabs.size():
		return
	var b: Button = tabs[index]["button"]
	if b.visible == on:
		return
	b.visible = on
	if not on and visible and current == index:
		show_tab(index)


func show_tab(index: int) -> void:
	index = clampi(index, 0, tabs.size() - 1)
	if not tabs.is_empty() and not (tabs[index]["button"] as Button).visible:
		for i in tabs.size():
			if (tabs[i]["button"] as Button).visible:
				index = i
				break
	current = index
	for i in tabs.size():
		(tabs[i]["view"] as Control).visible = i == current
		(tabs[i]["button"] as Button).theme_type_variation = &"SelectedButton" if i == current else &""
	# A view that scrolls its own parts: the body does not scroll as well (two
	# bars for one drag).
	var owns: bool = not tabs.is_empty() and tabs[current]["view"].get("owns_scroll") == true
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if owns else ScrollContainer.SCROLL_MODE_AUTO
	if not tabs.is_empty():
		tab_scroll.ensure_control_visible.call_deferred(tabs[current]["button"])
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
	if title_key != "":
		title_label.text = tr(title_key)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and tab_bar != null:
		_relabel()
	elif what == NOTIFICATION_THEME_CHANGED and card != null:
		# A card of reading is denser than the HUD's glass (Step 46): small
		# text over a busy island must stay legible.
		var box := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
		if box != null:
			box.bg_color.a = CARD_ALPHA
			box.set_corner_radius_all(HudTheme.CARD_RADIUS)
			box.shadow_size = 14
			box.shadow_color = Color(0.05, 0.16, 0.34, 0.22)
			card.add_theme_stylebox_override("panel", box)


## Centred in the columns left of the side buttons, below the HUD pieces
## above it and above those below it (`avoid`); as tall as its body up to
## that band, then the body scrolls (or, for a view that scrolls its own
## parts, they do -- `room` is how tall they may be).
func _layout() -> void:
	if card == null:
		return
	if hud_space.is_valid():
		var got: Dictionary = hud_space.call(self)
		avoid = got["avoid"]
		right_reserved = float(got["right"])
	var w := size.x
	var h := size.y
	var right := w - maxf(right_reserved, MARGIN)
	var avail := maxf(right - MARGIN, 300.0)
	var cw := minf(max_width, avail)
	card.custom_minimum_size.x = cw
	var x := MARGIN + maxf((avail - cw) * 0.5, 0.0)
	var top := MARGIN
	var bottom := h - MARGIN
	for r: Rect2 in avoid:
		if r.end.x <= x or r.position.x >= x + cw or r.size.x <= 0.0:
			continue
		if r.get_center().y < h * 0.5:
			top = maxf(top, r.end.y + MARGIN)
		else:
			bottom = minf(bottom, r.position.y - MARGIN)
	var band := maxf(bottom - top, 220.0)
	# The card without its body: the head, the tab row, the paddings.
	scroll.custom_minimum_size.y = 0.0
	card.reset_size()
	var chrome := card.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	room = maxf(band - chrome, 120.0)
	# A view that scrolls its own parts sizes them to the room now, before
	# the body is measured (its height is theirs).
	var view := current_view()
	if view != null and view.has_method("fit_room"):
		var pad := (card.get_theme_stylebox("panel") as StyleBox).get_content_margin(SIDE_LEFT) + (card.get_theme_stylebox("panel") as StyleBox).get_content_margin(SIDE_RIGHT)
		view.call("fit_room", room, cw - pad - BAR - GUTTER)
	var content := body_margin.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(content, room)
	card.reset_size()
	card.position = Vector2(x, top).round()
	tab_fade.queue_redraw()
	# Whatever the views have built since: a swipe on it scrolls its view.
	for sc: Node in card.find_children("*", "ScrollContainer", true, false):
		PanelViews.let_swipes_through(sc as ScrollContainer)


## The tab row's fades: an edge the tabs go on past is washed into the card,
## so a cut tab reads as "more this way" and never as a broken one.
func _draw_tab_fade() -> void:
	var bar := tab_scroll.get_h_scroll_bar()
	var box := card.get_theme_stylebox("panel") as StyleBoxFlat
	var c := box.bg_color if box != null else Color(1, 1, 1, 0.86)
	var clear := Color(c, 0.0)
	var r := Rect2(Vector2.ZERO, tab_fade.size)
	if bar.value > 0.5:
		tab_fade.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(FADE, 0), r.position + Vector2(FADE, r.size.y), r.position + Vector2(0, r.size.y)]),
			PackedColorArray([c, clear, clear, c]))
	if bar.value < bar.max_value - bar.page - 0.5:
		var e := r.end.x
		tab_fade.draw_polygon(PackedVector2Array([Vector2(e - FADE, 0), Vector2(e, 0), Vector2(e, r.size.y), Vector2(e - FADE, r.size.y)]),
			PackedColorArray([clear, c, c, clear]))


func card_rect() -> Rect2:
	return card.get_global_rect()
