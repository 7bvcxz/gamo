extends PopPlayView

## Step 34's sheet (#flavors, not on the chooser): the five flavors side by side at a size
## where they can be judged -- each one's popped kernels, its sealed bag and cup, and its
## coating moving as it does on the packing floor (butter's sheen in the kettle, the sprayer's
## cheese and spicy dust, the coater's caramel ribbon and cocoa swirl), with its recipe's
## numbers (price of a small bag, coating time of a batch of four, the share of customers who
## ask for it, what opens it). A design sheet: nothing plays; the numbers are data/economy.json's.

const IDS := ["plain", "cheese", "spicy", "caramel", "cocoa"]
var _rec: Dictionary = {}
var _font := ThemeDB.fallback_font


func setup(p_rules: PopRules) -> void:
	super(p_rules)
	machine_node.visible = false
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
	if typeof(doc) == TYPE_DICTIONARY:
		_rec = ((doc as Dictionary)["factory"]["flavors"]["recipes"] as Dictionary)


func _process(delta: float) -> void:
	super(delta)
	machine_node.visible = false


func _gui_input(_event: InputEvent) -> void:
	pass


func _draw_under(ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), PopTokens.FLOOR_MID[0])
	var wide := size.x > size.y * 1.15
	var top := 64.0
	if wide:   # below the frame's card in the right column (it is the stub's; nothing to buy here)
		top = maxf(top, 190.0)
	for i in IDS.size():
		var cell: Rect2
		if wide:
			var w := (size.x - 32.0) / IDS.size()
			cell = Rect2(Vector2(16 + i * w, top), Vector2(w - 10, size.y - top - 16))
		else:
			var h := (size.y - top - 16.0) / IDS.size()
			cell = Rect2(Vector2(16, top + i * h), Vector2(size.x - 32, h - 10))
		_draw_flavor(ci, cell, String(IDS[i]), wide)


func _draw_flavor(ci: CanvasItem, r: Rect2, id: String, wide: bool) -> void:
	var e: Dictionary = _rec.get(id, {})
	var k := PopFactoryArt.flavor_look(id)
	PopMachineArt._round_rect(ci, r, 14, Color(1, 1, 1, 0.92))
	PopMachineArt._round_rect(ci, Rect2(r.position, Vector2(r.size.x, 8)), 4, k["stripe"])
	var fs := int(clampf(minf(r.size.x, r.size.y) * 0.075, 13.0, 22.0))
	ci.draw_string(_font, r.position + Vector2(12, 10 + fs * 1.2), String(e.get("name", id)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
	# The picture: kernels, the coating moving over them, the bag and the cup.
	var pic: Rect2
	var nums: Rect2
	if wide:
		pic = Rect2(r.position + Vector2(8, fs * 2.0), Vector2(r.size.x - 16, r.size.y * 0.62))
		nums = Rect2(Vector2(r.position.x + 12, pic.end.y + 6), Vector2(r.size.x - 24, r.end.y - pic.end.y - 12))
	else:
		pic = Rect2(r.position + Vector2(r.size.x * 0.36, 12), Vector2(r.size.x * 0.62, r.size.y - 20))
		nums = Rect2(r.position + Vector2(12, fs * 2.0), Vector2(r.size.x * 0.34, r.size.y - fs * 2.2))
	var s := minf(pic.size.x / 7.0, pic.size.y / 4.6)
	var pile := Vector2(pic.position.x + pic.size.x * (0.26 if not wide else 0.5), pic.position.y + pic.size.y * (0.66 if not wide else 0.42))
	_draw_motion(ci, pile, s, id)
	for o: Vector2 in [Vector2(-1.1, 0.35), Vector2(1.1, 0.35), Vector2(0, -0.25), Vector2(-0.5, 0.9), Vector2(0.6, 0.95)]:
		PopFactoryArt.flavor_popcorn(ci, pile + o * s, s * 0.8, id)
	_draw_coat_over(ci, pile, s, id)
	var bag_at := Vector2(pic.position.x + pic.size.x * (0.62 if not wide else 0.3), pic.end.y - 4)
	var cup_at := Vector2(pic.position.x + pic.size.x * (0.86 if not wide else 0.74), pic.end.y - 4)
	PopFactoryArt.sku_bag(ci, bag_at, s * 1.4, id)
	PopFactoryArt.cup(ci, cup_at, s * 1.0)
	PopFactoryArt.flavor_popcorn(ci, cup_at - Vector2(0, s * 1.15), s * 0.42, id)
	# The recipe's numbers.
	var y := nums.position.y + fs
	PopMachineArt.draw_coin(ci, Vector2(nums.position.x + fs * 0.5, y - fs * 0.35), fs * 0.42)
	ci.draw_string(_font, Vector2(nums.position.x + fs * 1.3, y), "%d" % int(e.get("price", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
	y += fs * 1.35
	var coat := float(e.get("coat_ms_per_portion", 0)) * 4.0 / 1000.0
	ci.draw_string(_font, Vector2(nums.position.x, y), ("kettle" if id == "plain" else "%.1f s / 4" % coat), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, Color(PopPalette.INK, 0.75))
	y += fs * 1.35
	var share := float(e.get("order_share", 0.0))
	ci.draw_string(_font, Vector2(nums.position.x, y), ("base" if id == "plain" else "%d%% ask" % int(round(share * 100.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, Color(PopPalette.INK, 0.75))
	y += fs * 1.35
	var u: Dictionary = e.get("unlock", {})
	var lock := "open" if u.is_empty() else ("pack %d" % int(u.get("packer", 0)) + (" sign %d" % int(u["sign"]) if u.has("sign") else ""))
	ci.draw_string(_font, Vector2(nums.position.x, y), lock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, Color(PopPalette.INK, 0.55))


## Behind the kernels: the machine part that coats them (a nozzle, a drum).
func _draw_motion(ci: CanvasItem, c: Vector2, s: float, id: String) -> void:
	var k := PopFactoryArt.flavor_look(id)
	match id:
		"cheese", "spicy":
			var noz := c + Vector2(0, -s * 1.75)
			ci.draw_rect(Rect2(noz - Vector2(s * 0.5, s * 0.9), Vector2(s, s * 0.7)), PopTokens.STEEL_DEEP)
			ci.draw_colored_polygon(PackedVector2Array([noz + Vector2(-s * 0.25, -s * 0.2), noz + Vector2(s * 0.25, -s * 0.2), noz + Vector2(s * 0.12, s * 0.15), noz + Vector2(-s * 0.12, s * 0.15)]), PopTokens.STEEL)
		"caramel", "cocoa":
			ci.draw_circle(c + Vector2(0, -s * 0.1), s * 1.9, Color(k["stripe"], 0.12))
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 1.9, 0, TAU, 32, Color(PopTokens.STEEL_DEEP, 0.6), 3.0)


## Over the kernels: the coating, moving with the clock.
func _draw_coat_over(ci: CanvasItem, c: Vector2, s: float, id: String) -> void:
	var k := PopFactoryArt.flavor_look(id)
	var t := _t if not reduced_motion else 0.0
	match id:
		"plain":   # butter's sheen sweeps across the pile
			var x := -1.6 + fmod(t * 0.8, 1.0) * 3.2
			ci.draw_line(c + Vector2(x - 0.3, -0.8) * s, c + Vector2(x + 0.3, 1.2) * s, Color(1, 1, 0.85, 0.7), s * 0.28)
		"cheese", "spicy":   # dust falls from the nozzle
			for q in 9:
				var ph := fmod(t * 1.2 + q * 0.11, 1.0)
				var x := (float(q % 3) - 1.0) * s * (0.25 + ph * 0.9)
				ci.draw_circle(c + Vector2(x, -s * 1.6 + ph * s * 2.0), s * 0.09, k["mark"] if q % 2 == 0 else k["fill"])
			if id == "spicy":
				var sp := c + Vector2(cos(t * 3.0), sin(t * 2.0)) * s * 1.2
				ci.draw_line(sp - Vector2(s * 0.2, 0), sp + Vector2(s * 0.2, 0), Color(1.0, 0.9, 0.35), 2.0)
				ci.draw_line(sp - Vector2(0, s * 0.2), sp + Vector2(0, s * 0.2), Color(1.0, 0.9, 0.35), 2.0)
		"caramel":   # a ribbon pours and runs round the drum
			var a := t * 1.4
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 1.5, a, a + PI * 0.9, 18, k["band"], s * 0.28)
			ci.draw_line(c + Vector2(s * 0.2, -s * 1.9), c + Vector2(s * 0.2, -s * 0.6), k["band"], s * 0.22)
		"cocoa":   # a swirl turns
			var a := -t * 1.6
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 1.45, a, a + PI * 1.3, 18, k["stripe"], s * 0.22)
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.9, a + PI, a + PI * 2.2, 14, k["mark"], s * 0.14)
