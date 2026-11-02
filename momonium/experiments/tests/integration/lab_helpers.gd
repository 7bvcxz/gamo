extends RefCounted

## Shared steps for the Lab's integration tests: a real touch (the engine
## turns it into a mouse event, as on a phone) at a point of the canvas.


## Presses and releases a finger at `canvas_point`, the way a phone does.
static func touch(tree: SceneTree, canvas_point: Vector2) -> void:
	var at: Vector2 = tree.root.get_final_transform() * canvas_point
	for pressed: bool in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = at
		t.pressed = pressed
		Input.parse_input_event(t)
		await tree.process_frame
	await tree.process_frame


## A mouse click at `canvas_point` (desktop).
static func click(tree: SceneTree, canvas_point: Vector2) -> void:
	var at: Vector2 = tree.root.get_final_transform() * canvas_point
	for pressed: bool in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.position = at
		m.global_position = at
		m.pressed = pressed
		Input.parse_input_event(m)
		await tree.process_frame
	await tree.process_frame


static func centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()
