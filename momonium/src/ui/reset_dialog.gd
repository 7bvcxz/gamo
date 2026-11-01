class_name ResetDialog
extends CanvasLayer

## Step 80: the confirmation for Reset All Data (Settings > Advanced), on its
## own layer above everything -- the HUD, every panel, the tutorial, the tips,
## a selected Momo's Schedule button -- with a dim that takes every touch, so
## nothing under it can be pressed while it asks.
##
## Two steps after the Settings button: what will be lost and what stays, with
## Cancel or Continue; then "This cannot be undone" with Cancel or the red
## Erase everything -- placed where Continue was not, and answering only after
## ARM_SECONDS, so a double tap cannot go through both. Cancel, the dim,
## Escape or a phone's back gesture dismiss it at either step and change
## nothing. It erases nothing itself: `confirmed` goes to the composition root
## (Main.reset_all_data), which may come back with `show_failure`.

signal confirmed
signal cancelled

const LAYER := 90
## Seconds before the red button answers.
const ARM_SECONDS := 0.8

var stage := 0
var dim: ColorRect
var card: PanelContainer
var title: Label
var body: Label
var kept: Label
var failure: Label
var cancel_button: Button
var continue_button: Button
var confirm_button: Button
var _armed_at := 0.0
var _t := 0.0


func setup(card_theme: Theme) -> void:
	name = "ResetDialog"
	layer = LAYER
	visible = false
	var root := Control.new()
	root.name = "Root"
	root.theme = card_theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.07, 0.15, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			cancel())
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	card = PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(320, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := HudTheme.card_box(card_theme, 0.97)
	box.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", box)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	title = PanelViews.label("", 22)
	title.name = "Title"
	col.add_child(title)
	body = PanelViews.label("", 16)
	body.name = "Body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	kept = PanelViews.label("", 14, true)
	kept.name = "Kept"
	kept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(kept)
	failure = PanelViews.label("", 15)
	failure.name = "Failure"
	failure.theme_type_variation = &"BadLabel"
	failure.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	failure.visible = false
	col.add_child(failure)
	# Step 1: Cancel left, Continue right. Step 2: Erase everything on its own
	# row under Cancel -- never where Continue was.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	cancel_button = _button("Cancel", row)
	cancel_button.pressed.connect(cancel)
	continue_button = _button("Continue", row)
	continue_button.pressed.connect(func() -> void: _to_stage(2))
	confirm_button = _button("Confirm", col)
	confirm_button.theme_type_variation = &"DangerButton"
	confirm_button.pressed.connect(func() -> void:
		if stage == 2 and _t >= _armed_at:
			confirmed.emit())


func _button(node_name: String, parent: Control) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	parent.add_child(b)
	return b


## The first step: what will be lost.
func open() -> void:
	visible = true
	failure.visible = false
	_to_stage(1)


## Dismissed: nothing changed.
func cancel() -> void:
	if not visible:
		return
	visible = false
	stage = 0
	cancelled.emit()


## The reset could not erase everything (Main put back what it had erased).
func show_failure(names: Array) -> void:
	failure.text = tr("reset.failed").format({"list": ", ".join(names.map(func(n: Variant) -> String: return String(n).get_file() if String(n).begins_with("user://") else String(n)))})
	failure.visible = true


func _to_stage(n: int) -> void:
	stage = n
	refresh()
	if n == 2:
		_armed_at = _t + ARM_SECONDS
		confirm_button.disabled = true


func refresh() -> void:
	title.text = tr("reset.title") if stage == 1 else tr("reset.sure_title")
	body.text = tr("reset.lost") if stage == 1 else tr("reset.sure_body")
	kept.text = tr("reset.kept")
	kept.visible = stage == 1
	cancel_button.text = tr("reset.cancel")
	continue_button.text = tr("reset.continue")
	continue_button.visible = stage == 1
	confirm_button.text = tr("reset.confirm")
	confirm_button.visible = stage == 2


func _process(delta: float) -> void:
	_t += delta
	if visible and stage == 2 and confirm_button.disabled and _t >= _armed_at:
		confirm_button.disabled = false


## Escape or back: dismissed, whatever step (before any panel hears it).
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and title != null and visible:
		refresh()
