class_name PopPressArea
extends Control

## A drawn button: fires `pressed` when a press that began on it is released
## on it (slide off to cancel), like Godot's Button in its default mode. Only
## mouse events count -- a phone's touch arrives as a touch *and* its mouse
## copy, so listening to both would count one finger twice.

signal pressed

var enabled := true
var held := false
## The mouse is over it (desktop): drawn a little lifted.
var hovered := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		held = true
	elif held:
		held = false
		if enabled and Rect2(Vector2.ZERO, size).has_point(mb.position):
			pressed.emit()
	queue_redraw()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			hovered = true
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT:
			hovered = false
			held = false
			queue_redraw()
