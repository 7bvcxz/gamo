extends PopPlayView

## Step 41's sheet (#cast, not on the chooser): the shop's people, its goods and the icon set at
## the size the factory draws them (the head of a 720x1280 shop), so they can be judged and
## measured where they are really seen. Nothing here plays.
##   1. the cast: the five members, three looks each (art/cast_art.gd)
##   2. the faces: waiting, impatient, happy, thanks, sad, delight
##   3. the motion: five actors (the factory's own, variants/factory/actor.gd) walking a strip,
##      stopping to breathe, hopping as if handed a bag; the rare delight every few seconds
##   4. the icons (art/icons.gd) on their plates and bare, at two sizes
##   5. the goods: each flavor's lot, its bag and its cup at the floors' sizes
## `cast_layout()` gives the tests and the audit tool where each part is.

const Actor := preload("res://variants/factory/actor.gd")
const WHO := ["classic", "student", "rush", "kid", "elder"]
const MOODS := ["wait", "impatient", "happy", "thanks", "sad", "delight"]
const FLAVORS := ["plain", "cheese", "spicy", "caramel", "cocoa"]
const HEAD := 21.8          ## the shop's head on a 720x1280 screen (factory_view._head_px)
const BAG := 34.0           ## a bag on the packing floor there (factory_view._bag_px)
var _walkers: Array = []
var _clock := 0.0


func setup(p_rules: PopRules) -> void:
	super(p_rules)
	machine_node.visible = false


func _process(delta: float) -> void:
	super(delta)
	machine_node.visible = false
	_clock += delta
	var lay := cast_layout()
	var strip: Rect2 = lay["walk"]
	if _walkers.is_empty() and strip.size.x > 0.0:
		for i in WHO.size():
			var a: Node2D = Actor.new()
			a.kind = Actor.CUSTOMER
			a.model_id = 700 + i
			a.who = String(WHO[i])
			a.look = PopCastArt.look_for(a.model_id, a.who)
			a.body = a.look["body"]
			a.skin = a.look["skin"]
			a.size_px = HEAD
			a.calm = reduced_motion
			a.position = Vector2(strip.position.x + strip.size.x * (0.1 + 0.18 * i), strip.end.y - 6)
			add_child(a)
			_walkers.append(a)
	for i in _walkers.size():
		var a: Node2D = _walkers[i]
		# a walk of 4 s across part of the strip, 2 s standing, a hop, back again
		var ph := fmod(_clock + i * 1.3, 8.0)
		var x0 := strip.position.x + strip.size.x * (0.08 + 0.18 * i)
		if not a.easing_to and ph < 0.05:
			a.walk_to(Vector2(x0 + strip.size.x * 0.12 * (1.0 if int((_clock + i * 1.3) / 8.0) % 2 == 0 else 0.0), a.position.y))
		if absf(ph - 5.0) < delta:
			a.react("receive")
		if i == 2 and absf(ph - 6.5) < delta:
			a.mood = "delight" if a.mood != "delight" else "wait"
			a.react("delight")
			a.queue_redraw()
		a.step(delta)


func _gui_input(_event: InputEvent) -> void:
	pass


## Where each part of the sheet is (window pixels).
func cast_layout() -> Dictionary:
	var top := 70.0
	var w := size.x - 32.0
	var h := size.y - top - 16.0
	var rows := [0.24, 0.14, 0.15, 0.22, 0.25]
	var out := {}
	var y := top
	var names := ["cast", "faces", "walk", "icons", "goods"]
	for i in names.size():
		out[names[i]] = Rect2(Vector2(16, y), Vector2(w, h * float(rows[i]) - 8.0))
		y += h * float(rows[i])
	return out


## For the tests: the icon cells (name -> centre and size) and the people's feet.
func cast_debug() -> Dictionary:
	var lay := cast_layout()
	var r: Rect2 = lay["icons"]
	var cells := {}
	var n := PopIcons.NAMES.size()
	var cw := r.size.x / float(n)
	for i in n:
		cells[PopIcons.NAMES[i]] = {"plate": [r.position.x + cw * (i + 0.5), r.position.y + r.size.y * 0.3], "bare": [r.position.x + cw * (i + 0.5), r.position.y + r.size.y * 0.75],
			"s": minf(cw * 0.7, r.size.y * 0.34), "small": minf(cw * 0.5, r.size.y * 0.22)}
	var walkers := []
	for a: Node2D in _walkers:
		walkers.append({"x": a.position.x, "y": a.position.y, "rot": a.skew, "sy": a.scale.y, "motion": a.motion, "who": a.who})
	var out := {}
	for k: String in lay:
		var q: Rect2 = lay[k]
		out[k] = [q.position.x, q.position.y, q.size.x, q.size.y]
	return {"layout": out, "icons": cells, "walkers": walkers, "head": HEAD}


## For the browser tests: the same, with the icon cells and the walkers' feet in window pixels.
func debug_state() -> Dictionary:
	var d := cast_debug()
	var xf := get_viewport().get_final_transform() * get_global_transform()
	var k := xf.get_scale().x
	var icons := {}
	for name: String in d["icons"]:
		var cell: Dictionary = d["icons"][name]
		var p: Vector2 = xf * Vector2(cell["plate"][0], cell["plate"][1])
		var b: Vector2 = xf * Vector2(cell["bare"][0], cell["bare"][1])
		icons[name] = {"plate": [p.x, p.y], "bare": [b.x, b.y], "s": float(cell["s"]) * k, "small": float(cell["small"]) * k}
	d["icons"] = icons
	for w: Dictionary in d["walkers"]:
		var f: Vector2 = xf * Vector2(w["x"], w["y"])
		w["wx"] = f.x
		w["wy"] = f.y
	d["scale"] = k
	return d


func _draw_under(ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), PopTokens.FLOOR_TOP[0])
	var lay := cast_layout()
	for k: String in lay:
		PopMachineArt._round_rect(ci, lay[k], 14, Color(1, 1, 1, 0.6))
	# 1. the cast: five members, three looks each
	var cr: Rect2 = lay["cast"]
	for i in WHO.size():
		for j in 3:
			var n := i * 3 + j
			var foot := Vector2(cr.position.x + cr.size.x * (float(n % 8) + 0.5 + (0.5 if n >= 8 else 0.0)) / 8.0, cr.position.y + cr.size.y * (0.47 if n < 8 else 0.95))
			var id := 40 + i * 7 + j * 31
			PopCastArt.person(ci, foot, HEAD, PopCastArt.look_for(id, String(WHO[i])), "wait", String(WHO[i]))
	# 2. the faces
	var fr: Rect2 = lay["faces"]
	var mw := fr.size.x / float(MOODS.size())
	for i in MOODS.size():
		PopCastArt.person(ci, Vector2(fr.position.x + mw * (i + 0.5), fr.end.y - 6), HEAD, PopCastArt.look_for(11, "classic"), String(MOODS[i]), "classic")
	# 3. the walk strip's floor line (its actors are child nodes)
	var wr: Rect2 = lay["walk"]
	ci.draw_line(Vector2(wr.position.x + 8, wr.end.y - 5), Vector2(wr.end.x - 8, wr.end.y - 5), Color(PopPalette.INK, 0.2), 2.0)
	# 4. the icons: on their plates (top row) and bare (smaller, bottom row)
	var d := cast_debug()
	for name: String in PopIcons.NAMES:
		var cell: Dictionary = d["icons"][name]
		PopIcons.draw(ci, name, Vector2(cell["plate"][0], cell["plate"][1]), float(cell["s"]), true)
		PopIcons.draw(ci, name, Vector2(cell["bare"][0], cell["bare"][1]), float(cell["small"]))
	# 5. the goods: lot, bag and cup of every flavor at the floors' sizes
	var gr: Rect2 = lay["goods"]
	var gw := gr.size.x / float(FLAVORS.size())
	for i in FLAVORS.size():
		var id := String(FLAVORS[i])
		var cx := gr.position.x + gw * (i + 0.5)
		var lot := Vector2(cx, gr.position.y + gr.size.y * 0.25)
		var s := BAG * 0.55
		for o: Vector2 in [Vector2(-0.55, 0.15), Vector2(0.5, 0.2), Vector2(0, -0.4)]:
			PopFactoryArt.flavor_popcorn(ci, lot + o * s, s * 0.62, id)
		PopFactoryArt.sku_bag(ci, Vector2(cx - gw * 0.18, gr.end.y - 8), BAG, id)
		PopFactoryArt.cup(ci, Vector2(cx + gw * 0.2, gr.end.y - 8), BAG * 0.7)
		PopFactoryArt.flavor_popcorn(ci, Vector2(cx + gw * 0.2, gr.end.y - 8 - BAG * 0.85), BAG * 0.28, id)
