extends RefCounted
class_name WorldView

# Every machine used to rebuild its _draw() commands each frame no matter where
# it stood, so a large factory paid for blocks nobody could see. Main publishes
# the camera rectangle once per frame and machines consult it before redrawing.

static var visible_rect := Rect2()

static func update_from_camera(camera_center: Vector2, view_size: Vector2) -> void:
	visible_rect = Rect2(camera_center - view_size * 0.5, view_size)

static func is_on_screen(point: Vector2, margin: float = 96.0) -> bool:
	if visible_rect.size == Vector2.ZERO:
		return true
	return visible_rect.grow(margin).has_point(point)
