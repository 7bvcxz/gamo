extends Node2D

## Step 51: the 5x5 sheet with its slot legend -- each cell on a checker (so
## its transparency shows), the pivot marked, and "row,col name" under it.
## Capture with
##   tools/capture.gd -- --scene res://tools/art/gen/momo_legend.tscn --size 1000x1100

const SCALE := 0.7


func _ready() -> void:
	var sheet := MomoSheet.shared()
	var font := ThemeDB.fallback_font
	var bg := ColorRect.new()
	bg.color = Color("#f4efe6")
	bg.size = Vector2(1000, 1100)
	add_child(bg)
	var step := Vector2(sheet.cell) * SCALE + Vector2(16, 34)
	for name: String in sheet.cells:
		var c: Dictionary = sheet.cells[name]
		var at := Vector2(20, 20) + Vector2(int(c["col"]), int(c["row"])) * step
		for y in 8:
			for x in 8:
				var sq := ColorRect.new()
				sq.color = Color("#e3dccf") if (x + y) % 2 == 0 else Color("#fbf8f2")
				sq.position = at + Vector2(x, y) * sheet.cell.x * SCALE / 8.0
				sq.size = Vector2.ONE * sheet.cell.x * SCALE / 8.0
				add_child(sq)
		var s := Sprite2D.new()
		s.texture = sheet.texture
		s.region_enabled = true
		s.region_rect = sheet.region(name)
		s.centered = false
		s.position = at
		s.scale = Vector2.ONE * SCALE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(s)
		var pivot := ColorRect.new()
		pivot.color = Color("#e0523a")
		pivot.size = Vector2(6, 6)
		pivot.position = at + sheet.pivot * SCALE - Vector2(3, 3)
		add_child(pivot)
		var label := Label.new()
		label.text = "%d,%d %s" % [int(c["row"]), int(c["col"]), name]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#23324a"))
		label.position = at + Vector2(2, sheet.cell.y * SCALE + 4)
		add_child(label)
