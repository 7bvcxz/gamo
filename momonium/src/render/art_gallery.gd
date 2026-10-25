extends Node2D

## Developer view of the art pipeline: every atlas sprite at its world scale,
## standing on a projected tile, with its pivots marked, plus the ground
## textures. Open scenes/dev/art_gallery.tscn or capture it with tools/capture.gd.

var _lib: SpriteLibrary
var _proj: IsoProjection


func _ready() -> void:
	var data := GameData.load_default()
	_lib = SpriteLibrary.load_atlas()
	_proj = IsoProjection.from_data(data)
	var x := 90.0
	var names: Array = _lib.sprites.keys()
	names.sort()
	for name: String in names:
		var holder := Node2D.new()
		holder.position = Vector2(x, 300)
		add_child(holder)
		holder.add_child(_lib.make_sprite(name, "origin" if _lib.pivot(name, "origin") != Vector2.ZERO or name.begins_with("momo") else "center"))
		x += 150.0
	for i in 3:
		var tex: Texture2D = load(["res://assets/textures/grass.png", "res://assets/textures/dirt.png", "res://assets/textures/stone.png"][i])
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(20 + i * 230, 420)
		s.scale = Vector2(0.8, 0.8)
		add_child(s)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#dfeaf4"))
	var x := 90.0
	for name: String in _sorted_names():
		var origin := Vector2(x, 300)
		var corners := _proj.cell_corners(Vector2i.ZERO)
		var shift := origin - _proj.cell_center(Vector2i.ZERO)
		var pts := PackedVector2Array()
		for c: Vector2 in corners:
			pts.append(c * 0.8 + shift * 1.0 + (_proj.cell_center(Vector2i.ZERO) * 0.2))
		draw_colored_polygon(pts, Color(0.55, 0.78, 0.35, 0.6))
		draw_circle(origin, 3, Color.RED)
		x += 150.0


func _sorted_names() -> Array:
	var names: Array = _lib.sprites.keys()
	names.sort()
	return names
