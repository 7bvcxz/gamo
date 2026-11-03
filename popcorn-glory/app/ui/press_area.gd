class_name PopPressArea
extends Control

## A drawn button: fires `pressed` when a press that began on it is released
## on it (slide off to cancel), like Godot's Button in its default mode. Only
## mouse events count -- a phone's touch arrives as a touch *and* its mouse
## copy, so listening to both would count one finger twice.

signal pressed
## A press released on it while it is disabled (Step 10: a blind player tapped
## an unaffordable card and thought the tap had not registered). Nothing is
## bought; whoever listens shows a 'no' -- see deny().
signal denied

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
		if Rect2(Vector2.ZERO, size).has_point(mb.position):
			if enabled:
				pressed.emit()
			else:
				denied.emit()
	queue_redraw()


var _deny := 0.0


## A short sideways shake: 'not yet'.
func deny() -> void:
	_deny = 1.0
	set_process(true)
	queue_redraw()


func deny_offset() -> float:
	return sin(_deny * 30.0) * 10.0 * _deny


func _step_deny(delta: float) -> void:
	if _deny > 0.0:
		_deny = maxf(0.0, _deny - delta * 2.5)
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
