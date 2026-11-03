class_name PopMachineNode
extends Node2D

## The machine on its own canvas item, drawn with its base at the origin.
## set_look() redraws only when the look actually changes; everything that
## moves every frame (breathing, a pop's squash, C's rattle) is this node's
## position and scale, which cost nothing to redraw.

var level := -1
var size_px := 0.0
var fill := 0.0
var redraws := 0


func set_look(p_level: int, p_size: float, p_fill: float) -> void:
	if p_level == level and is_equal_approx(p_size, size_px) and is_equal_approx(p_fill, fill):
		return
	level = p_level
	size_px = p_size
	fill = p_fill
	queue_redraw()


func _draw() -> void:
	if level < 0:
		return
	redraws += 1
	PopMachineArt.draw(self, Vector2.ZERO, size_px, level, 0.0, fill)
