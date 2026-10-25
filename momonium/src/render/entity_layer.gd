class_name EntityLayer
extends Node2D

## Everything that stands on the island -- buildings, Momo, props -- drawn in
## depth order. Children are positioned at the point where they touch the
## ground (their origin pivot) and Godot's y-sort draws lower-on-screen later,
## which for this projection is exactly nearer-first-hidden.
##
## Two things at the same depth (x + y) are side by side on screen; a tiny
## x-based nudge makes their order stable instead of depending on insertion.

const TIE_BREAK_PER_X := 0.01

var projection: IsoProjection


func _init(p_projection: IsoProjection = null) -> void:
	projection = p_projection
	y_sort_enabled = true


## Ground point for something standing at `logical` (tile units).
func ground_point(logical: Vector2) -> Vector2:
	return projection.to_screen(logical) + Vector2(0, logical.x * TIE_BREAK_PER_X)


## Adds `node` standing at `logical` (e.g. Vector2(cell) + Vector2(0.5, 0.5)).
func add_entity(node: Node2D, logical: Vector2) -> void:
	node.position = ground_point(logical)
	add_child(node)


func move_entity(node: Node2D, logical: Vector2) -> void:
	node.position = ground_point(logical)
