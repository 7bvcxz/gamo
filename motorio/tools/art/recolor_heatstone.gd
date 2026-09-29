extends SceneTree

## Heat stone reads as a hot stone, not as copper (Factory Interaction Pass 01).
##
##     godot --headless --path motorio --script res://tools/art/recolor_heatstone.gd
##
## Measured: the heat stone and copper sheets averaged to the same colour on
## their ore pixels (hue 17 against 21 degrees, value 0.83 against 0.74), and
## their item colours were (255,122,48) and (252,104,46) -- one orange. The
## Visual North Star paints copper as red crystal clusters, which is what our
## heat stone looked like, so a player walked up to a red cluster expecting
## copper and got heat stone.
##
## This keeps every glowing pixel (the bright yellow-orange cores and cracks:
## what makes it heat stone) and turns the body of each lump from red-orange to
## a warm charcoal, the North Star's coal. The seam sheet stays the painted one;
## only its body colour moves. Idempotent: charcoal stays charcoal.

const SHEET := "res://assets/tiles/heatstone_6.png"

func _initialize() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	image.convert(Image.FORMAT_RGB8)
	var glow := 0
	var body := 0
	for y in image.get_height():
		for x in image.get_width():
			var c: Color = image.get_pixel(x, y)
			if c.s < 0.18:
				continue
			# The fire in it: bright and yellow enough.
			if c.v > 0.80 and c.g > 0.50:
				glow += 1
				continue
			var lum: float = c.r * 0.30 + c.g * 0.59 + c.b * 0.11
			var coal := Color(lum * 0.62 + 0.03, lum * 0.52 + 0.03, lum * 0.50 + 0.04)
			# A little of the ember left in the shadows of the lump.
			image.set_pixel(x, y, coal.lerp(c, 0.18))
			body += 1
	var error: int = image.save_png(ProjectSettings.globalize_path(SHEET))
	print("HEATSTONE: glow %d kept, body %d to charcoal (%d)" % [glow, body, error])
	quit(error)
