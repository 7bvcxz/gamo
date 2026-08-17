extends Node2D

## Keeps one CatView per cat in the simulation.
##
## The simulation still owns every cat: where it is, what it is doing, how hungry
## it is. This node owns only the fact that each of them has a view, and the view
## owns only the fact that its parts move together.
##
## One place writes a cat's screen position, and it is `view.sync`. That is the
## whole point of the change: the drawing used to compute a position five times
## per cat and the bugs were always one of the five disagreeing.

const VIEW := preload("res://scripts/CatView.gd")

var sim: Sim
## The camera's rectangle, set by Main like every other layer's. Views outside it
## are hidden rather than freed -- a cat walking off the edge and back is common,
## and rebuilding its node each time would be work for nothing.
var view_rect := Rect2()

var pulse: float = 0.0
var _views: Array[CatView] = []

func _process(delta: float) -> void:
	pulse += delta
	if sim == null:
		return
	# The crew changes when a crate is adopted or the slot machine pays out, so
	# the pool is sized here rather than wired to a signal: one comparison a
	# frame against a list that is almost always the same length.
	while _views.size() < sim.cats.size():
		var view: CatView = VIEW.new()
		add_child(view)
		_views.append(view)
	while _views.size() > sim.cats.size():
		var spare: CatView = _views.pop_back()
		spare.queue_free()

	for index in sim.cats.size():
		var cat: Sim.Cat = sim.cats[index]
		# A carried cat rides in the player's arms and is painted there; a
		# sleeping one is indoors. Both would otherwise be drawn twice.
		var shown: bool = cat != sim.carried_cat and cat.state != Defs.CAT_ASLEEP \
			and view_rect.grow(64.0).has_point(cat.pos)
		_views[index].sync(cat, pulse, shown, sim.cat_has_tool(cat))
