extends "res://variants/perfect/perfect_view.gd"

## The Popcorn Stand's picture (Step 10, design/SLICE.md). Everything B shows,
## plus the batch's other moments and the machines that take them over:
##   load + oil   -- after each pop a scoop tips kernels into the glass and a
##                   drop of oil follows (an animation, no input)
##   shake        -- from unlock.shake a crank on the machine's side; sliding the
##                   finger side to side while heating turns it and rattles the
##                   machine, three swings light the crank gold (an even pop)
##   season       -- from unlock.recipes three shakers on the left; tap one
##   pack + serve -- each batch drops into a striped bag that slides along the
##                   counter at the top to a customer (more customers as the
##                   stand grows)
##   automation   -- a motor on the crank, then a helper kettle on the right
##                   with its own small ring, popping by itself
## No words: numbers (x1.5, +N) and pictures only.

const RECIPE_ORDER := ["butter", "caramel", "cheese"]
const RECIPE_COLORS := {"butter": Color(1.0, 0.86, 0.35), "caramel": Color(0.78, 0.45, 0.16), "cheese": Color(1.0, 0.6, 0.12)}
const SHAKE_PX := 22.0

var _shake_dir := 0
var _shake_anchor := 0.0
var _wobble := 0.0
var _crank := 0.0
var _even_glow := 0.0
var _shaken_ever := false
var _bags: Array[Dictionary] = []
var _served := 0
var _react: Array[float] = [0, 0, 0, 0, 0, 0, 0]
var _loads: Array[float] = []
var _helper_kick := 0.0
var _recipe_flash := 0.0
var _auto_flash := 0.0
var helper_node := PopMachineNode.new()


func _init() -> void:
	super()
	helper_node.name = "Helper"
	add_child(helper_node)
	move_child(helper_node, 1)   # behind the main machine's front layer


func setup(p_rules: PopRules) -> void:
	super(p_rules)
	_bags.clear()
	_loads.clear()
	_shaken_ever = false


# -- layout ----------------------------------------------------------------

## A little smaller than B's machine: the shakers stand on its left and the
## helper on its right.
func machine_size() -> float:
	return minf(size.y * 0.5, size.x * 0.52)


func shaker_rect(i: int) -> Rect2:
	var h := minf(132.0, size.y * 0.115)
	return Rect2(Vector2(8, size.y * 0.36 + float(i) * (h + 16.0)), Vector2(108, h))


## Top right, under the counter: the one corner the machine and its ring never reach.
func helper_base() -> Vector2:
	return Vector2(size.x - 78, size.y * 0.36)


func helper_size() -> float:
	return machine_size() * 0.3


func counter_y() -> float:
	return size.y * 0.15


func _s() -> Dictionary:
	return rules.state()


## Window-local rects a test can tap (main.gd adds them to state().rects).
func extra_rects() -> Dictionary:
	var out := {}
	if rules == null:
		return out
	var st := _s()
	if bool(st["unlocked"]["recipes"]):
		for i in RECIPE_ORDER.size():
			out["recipe_" + String(RECIPE_ORDER[i])] = shaker_rect(i)
	if int(st["helper_level"]) > 0:
		var hs := helper_size()
		out["helper"] = Rect2(helper_base() - Vector2(hs * 0.45, hs), Vector2(hs * 0.9, hs))
	return out


# -- input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm != null:
		if _held:
			_track_shake(mm.position.x)
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and rules != null and bool(_s()["unlocked"]["recipes"]):
		for i in RECIPE_ORDER.size():
			if shaker_rect(i).has_point(mb.position):
				accept_event()
				command.emit("recipe", {"type": "recipe", "id": String(RECIPE_ORDER[i])})
				return
	if mb != null and mb.pressed:
		_shake_dir = 0
		_shake_anchor = mb.position.x
	super(event)


## Side to side while heating: each swing past SHAKE_PX is one shake.
func _track_shake(x: float) -> void:
	if rules == null:
		return
	var st := _s()
	if not bool(st["unlocked"]["shake"]) or not bool(st["heating"]):
		return
	if _shake_dir == 0:
		if absf(x - _shake_anchor) >= SHAKE_PX:
			_shake_dir = 1 if x > _shake_anchor else -1
			_shake_anchor = x
			command.emit("shake", {"type": "shake"})
		return
	if (x - _shake_anchor) * float(_shake_dir) > 0.0:
		_shake_anchor = x   # still going the same way: follow it
	elif absf(x - _shake_anchor) >= SHAKE_PX:
		_shake_dir = -_shake_dir
		_shake_anchor = x
		command.emit("shake", {"type": "shake"})


# -- events ----------------------------------------------------------------

func on_events(events: Array[Dictionary]) -> void:
	var rest: Array[Dictionary] = []
	for e: Dictionary in events:
		var d: Dictionary = e["data"]
		match String(e["type"]):
			"earn":
				# The +N shows where the batch popped; the coin flies to the money from
				# the customer who takes the bag (Step 11: 'the customers seemed to be
				# decoration' -- now they visibly pay).
				if String(d.get("from", "")) == "helper":
					_gain_at(int(d.get("amount", 0)), _helper_top() + Vector2(-110, -20))
					_sound("coin", 1.15, -14.0)
				else:
					_gain(int(d.get("amount", 0)))
					_sound("coin", 1.0, -8.0)
			"helper_pop":
				_helper_kick = 1.0
				var n := int(d.get("count", 1))
				fx.burst(_helper_top(), mini(n, 8) if not reduced_motion else 1, helper_size() / 900.0, rng, PopPalette.CREAM, 0.8, 0.9)
				_bag_from(_helper_top(), "helper")
				_sound("pop_1", 1.25, -10.0)
			"shook":
				_wobble = 1.0
				_crank += PI * 0.5
				_shaken_ever = true
				_sound("clink", 0.8 + 0.1 * float(int(d.get("shakes", 1)) % 3), -6.0)
				if bool(d.get("even", false)) and int(d.get("shakes", 0)) == int((rules.economy.table("stand")["shake"] as Dictionary)["turns"]):
					_even_glow = 1.0
					_sound("ding", 1.2, -10.0)
			"even":
				if not reduced_motion:
					fx.sparkle(machine_top(), machine_size() / 900.0, rng, 3, 110.0)
			"recipe":
				_recipe_flash = 1.0
				_sound("clink", 1.3)
			"auto":
				_auto_flash = 1.0
				_upgraded()
			"pop":
				rest.append(e)
				_loads.append(0.0)
				_bag_from(machine_top(), "main")
				var tint: Color = RECIPE_COLORS.get(String(_s()["recipe"]), PopPalette.CREAM)
				if String(_s()["recipe"]) != "butter" and not reduced_motion:
					fx.burst(machine_top(), 6, machine_size() / 900.0, rng, tint, 0.8, 1.0)
			_:
				rest.append(e)
	super(rest)


func _gain_at(amount: int, at: Vector2) -> void:
	# The +N floats from the helper, not from the main machine.
	_gain(amount)
	if not _gains.is_empty():
		_gains[-1]["at"] = at


## Each bag goes to a customer in turn (Step 10: two blind players saw bags
## stop on the counter and the customers never react). On arrival the customer
## hops and a coin shows over their head.
func _bag_from(from: Vector2, kind: String) -> void:
	var n := _customers()
	_bags.append({"age": 0.0, "from": from, "kind": kind, "to": _served % n, "arrived": false})
	_served += 1
	if _bags.size() > 12:
		_bags.pop_front()


func _customers() -> int:
	return mini(1 + rules.level / 3 + int(_s()["helper_level"]) / 2, 7)


func _customer_pos(i: int) -> Vector2:
	return Vector2(size.x - 60.0 - float(i) * 62.0, counter_y())


func _helper_top() -> Vector2:
	return helper_base() - Vector2(0, PopMachineArt.height_at(_helper_stage(), helper_size()) * 0.8)


func _helper_stage() -> int:
	return clampi(int(_s()["helper_level"]) * 2, 0, 14)


# -- frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	_wobble = maxf(0.0, _wobble - delta * 3.0)
	_even_glow = maxf(0.0, _even_glow - delta * 0.8)
	_helper_kick = maxf(0.0, _helper_kick - delta * 3.0)
	_recipe_flash = maxf(0.0, _recipe_flash - delta * 2.0)
	_auto_flash = maxf(0.0, _auto_flash - delta * 1.5)
	for b: Dictionary in _bags:
		b["age"] = float(b["age"]) + delta
		if not bool(b["arrived"]) and float(b["age"]) >= 1.0:
			b["arrived"] = true
			_react[int(b["to"])] = 1.0
			fx.coin(_customer_pos(int(b["to"])) + Vector2(0, -90), machine_size() / 900.0)
	for i in _react.size():
		_react[i] = maxf(0.0, _react[i] - delta * 1.6)
	while not _bags.is_empty() and float(_bags[0]["age"]) > 1.05:
		_bags.pop_front()
	for i in _loads.size():
		_loads[i] += delta
	while not _loads.is_empty() and _loads[0] > 0.7:
		_loads.pop_front()
	if rules != null:
		var st := _s()
		if bool(st["motor"]) and bool(st["heating"]):
			_crank += delta * 9.0
		var hl := int(st["helper_level"])
		helper_node.visible = hl > 0
		if hl > 0:
			helper_node.set_look(_helper_stage(), helper_size(), 0.5)
			var k := sin(_helper_kick * PI) * 0.08 if not reduced_motion else 0.0
			helper_node.position = helper_base()
			helper_node.scale = Vector2(1.0 + k, 1.0 - k)
	super(delta)


func _shake() -> Vector2:
	var s := super()
	if reduced_motion:
		return s
	return s + Vector2(sin(_t * 45.0) * 9.0 * _wobble, 0)


# -- drawing ---------------------------------------------------------------

func _draw_under(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	_draw_counter(ci)
	super(ci, base, size_px)


func _draw_over(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	super(ci, base, size_px)
	var st := _s()
	if bool(st["unlocked"]["shake"]):
		_draw_crank(ci, base, size_px, st)
	if bool(st["unlocked"]["recipes"]):
		_draw_shakers(ci, st)
	if int(st["helper_level"]) > 0:
		_draw_helper_ring(ci, st)
	_draw_loads(ci, base, size_px)
	_draw_bags(ci)


## The counter along the top and the customers at its right end. The queue
## grows with the stand: one more customer every three levels.
func _draw_counter(ci: CanvasItem) -> void:
	var y := counter_y()
	ci.draw_rect(Rect2(Vector2(24, y), Vector2(size.x - 48, 16)), PopPalette.RED.darkened(0.25))
	ci.draw_rect(Rect2(Vector2(24, y - 4), Vector2(size.x - 48, 6)), PopPalette.CREAM)
	for i in _customers():
		var x := _customer_pos(i).x
		var bob := sin(_t * 3.0 + float(i)) * 3.0 if not reduced_motion else 0.0
		var hop := sin(_react[i] * PI) * 16.0 if not reduced_motion else 0.0
		bob -= hop
		var col := Color.from_hsv(fmod(0.08 + float(i) * 0.17, 1.0), 0.35, 0.85)
		ci.draw_circle(Vector2(x, y - 74 + bob), 20, col.lightened(0.3))                       # head
		ci.draw_colored_polygon(PopMachineArt.ellipse(Vector2(x, y - 26 + bob), Vector2(26, 30), 16), col)  # body
		ci.draw_arc(Vector2(x, y - 74 + bob), 20, 0, TAU, 16, PopPalette.INK, 3.0)
		if _react[i] > 0.0:
			# Paid: the bag in their hands, and a coin rising beside the head.
			var bag := Rect2(Vector2(x - 13, y - 44 + bob), Vector2(26, 32))
			ci.draw_rect(bag, PopPalette.CREAM)
			ci.draw_rect(Rect2(bag.position + Vector2(9, 0), Vector2(8, bag.size.y)), PopPalette.RED)
			ci.draw_rect(bag, PopPalette.INK, false, 2.0)
			PopMachineArt.draw_coin(ci, Vector2(x + 30, y - 80 + bob - (1.0 - _react[i]) * 24.0), 13)


## A striped bag rises from the machine, sails to the counter and slides to
## the customer -- the pack-and-serve moment of every batch.
func _draw_bags(ci: CanvasItem) -> void:
	for b: Dictionary in _bags:
		var a := clampf(float(b["age"]), 0.0, 1.0)
		var from: Vector2 = b["from"]
		var to := _customer_pos(int(b["to"])) + Vector2(0, -40)
		var p := from.lerp(to, a) + Vector2(0, -sin(a * PI) * 140.0)
		var s := 0.7 if String(b["kind"]) == "helper" else 1.0
		var r := Rect2(p - Vector2(16, 22) * s, Vector2(32, 44) * s)
		ci.draw_rect(r, PopPalette.CREAM)
		for i in 3:
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * (0.1 + 0.3 * float(i)), 0), Vector2(r.size.x * 0.14, r.size.y)), PopPalette.RED)
		ci.draw_circle(r.position + Vector2(r.size.x * 0.5, 2), 9.0 * s, PopPalette.CREAM)
		ci.draw_rect(r, PopPalette.INK, false, 2.0)


## Load and oil: kernels drop from a scoop into the glass, then one drop of oil.
func _draw_loads(ci: CanvasItem, base: Vector2, size_px: float) -> void:
	if _loads.is_empty():
		return
	var h := PopMachineArt.height_at(rules.level, size_px)
	var top := base - Vector2(0, h * 0.98)
	var into := base - Vector2(0, h * 0.5)
	for a: float in _loads:
		var k := clampf(a / 0.5, 0.0, 1.0)
		var scoop := top + Vector2(-h * 0.2, -40)
		ci.draw_colored_polygon(PackedVector2Array([scoop + Vector2(-28, -6), scoop + Vector2(28, -6), scoop + Vector2(18, 14), scoop + Vector2(-18, 14)]), PopPalette.CHROME)
		for i in 4:
			var q := scoop.lerp(into, clampf(k * 1.3 - float(i) * 0.12, 0.0, 1.0)) + Vector2(float(i) * 8.0 - 12.0, 0)
			if PopAtlas.has("kernel"):
				PopAtlas.draw(ci, "kernel", q, 18.0)
			else:
				ci.draw_circle(q, 6, Color(0.85, 0.6, 0.25))
		if a > 0.35:
			var o := clampf((a - 0.35) / 0.3, 0.0, 1.0)
			var drop := scoop.lerp(into, o) + Vector2(16, 0)
			ci.draw_circle(drop, 7, Color(1.0, 0.83, 0.25, 1.0 - o * 0.5))


## The crank on the machine's right side: it turns a quarter for each shake
## and keeps turning with the motor; gold once the shakes make an even pop.
func _draw_crank(ci: CanvasItem, base: Vector2, size_px: float, st: Dictionary) -> void:
	var h := PopMachineArt.height_at(rules.level, size_px)
	var w := h * (0.78 + 0.03 * mini(rules.level, 6))
	var c := base + Vector2(w * 0.5 + 18, -h * 0.33)
	var r := 26.0
	var even := bool(st["even"]) and bool(st["heating"])
	var col := PopPalette.GOLD if even or _even_glow > 0.0 else PopPalette.CHROME
	ci.draw_circle(c, r + 4, PopPalette.INK)
	ci.draw_circle(c, r, col)
	var a := _crank
	var arm := c + Vector2(cos(a), sin(a)) * (r + 16)
	ci.draw_line(c, arm, PopPalette.INK, 9.0)
	ci.draw_line(c, arm, col.lightened(0.2), 5.0)
	ci.draw_circle(arm, 10, PopPalette.RED)
	if bool(st["motor"]):
		# The motor: a box under the crank with a belt to it.
		var m := Rect2(c + Vector2(-26, r + 22), Vector2(52, 40))
		PopMachineArt._round_rect(ci, m, 8, Color(0.35, 0.4, 0.5))
		ci.draw_line(c + Vector2(-r * 0.6, r * 0.8), m.position + Vector2(10, 4), PopPalette.INK, 4.0)
		ci.draw_line(c + Vector2(r * 0.6, r * 0.8), m.position + Vector2(42, 4), PopPalette.INK, 4.0)
		ci.draw_circle(m.get_center(), 9, Color(0.9, 0.9, 0.95) if int(_t * 8.0) % 2 == 0 or not bool(st["heating"]) else PopPalette.GOLD)
	if not _shaken_ever and bool(st["heating"]):
		# The first time: arrows either side of the crank, swinging -- "shake me".
		var sw := sin(_t * 10.0) * 10.0 if not reduced_motion else 0.0
		for sgn: float in [-1.0, 1.0]:
			var tip := c + Vector2(sgn * (r + 44) + sw, -r - 30)
			ci.draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(sgn * 16, 11), tip - Vector2(sgn * 16, -11)]), Color(PopPalette.INK, 0.6))
			ci.draw_line(tip - Vector2(sgn * 14, 0), tip - Vector2(sgn * 34, 0), Color(PopPalette.INK, 0.6), 5.0)


## The three recipes: a shaker each, its colour, and what it does in numbers --
## x the batch, the width of its gold, and a clock if it cools longer.
func _draw_shakers(ci: CanvasItem, st: Dictionary) -> void:
	var recipes: Dictionary = rules.economy.table("stand")["recipes"]
	var font := ThemeDB.fallback_font
	for i in RECIPE_ORDER.size():
		var id := String(RECIPE_ORDER[i])
		var rd: Dictionary = recipes[id]
		var r := shaker_rect(i)
		var chosen := String(st["recipe"]) == id
		var lift := (6.0 + 6.0 * _recipe_flash) if chosen else 0.0
		r.position.y -= lift
		PopMachineArt._round_rect(ci, Rect2(r.position + Vector2(0, 6), r.size), 16, PopPalette.SHADOW)
		PopMachineArt._round_rect(ci, r, 16, Color(1, 1, 1, 0.95) if chosen else Color(1, 1, 1, 0.6))
		if chosen:
			var pts := PopMachineArt.round_rect_points(r, 16)
			pts.append(pts[0])
			ci.draw_polyline(pts, PopPalette.GOLD, 5.0)
		# The shaker: a jar with a lid and holes.
		var jar := Rect2(r.position + Vector2(r.size.x * 0.3, r.size.y * 0.12), Vector2(r.size.x * 0.4, r.size.y * 0.42))
		PopMachineArt._round_rect(ci, jar, 8, RECIPE_COLORS[id])
		ci.draw_rect(Rect2(jar.position - Vector2(2, 10), Vector2(jar.size.x + 4, 12)), PopPalette.CHROME)
		for k in 3:
			ci.draw_circle(jar.position + Vector2(jar.size.x * (0.25 + 0.25 * float(k)), -4), 2.5, PopPalette.INK)
		# x mult
		var fs := int(r.size.y * 0.2)
		var label := "x%s" % str(snappedf(float(rd["mult"]), 0.01))
		ci.draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.74), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, PopPalette.INK)
		# The gold's width, a short arc; a clock if it cools longer.
		var ac := Vector2(r.position.x + r.size.x * (0.4 if int(rd.get("cooldown_add_ms", 0)) > 0 else 0.5), r.end.y - 12)
		var span := 0.9 * float(rd.get("window_scale", 1.0))
		ci.draw_arc(ac + Vector2(0, 14), 22, -PI / 2 - span / 2, -PI / 2 + span / 2, 10, PopPalette.GOLD, 6.0)
		if int(rd.get("cooldown_add_ms", 0)) > 0:
			var cc := Vector2(r.position.x + r.size.x * 0.76, r.end.y - 14)
			ci.draw_circle(cc, 9, Color(1, 1, 1))
			ci.draw_arc(cc, 9, 0, TAU, 12, PopPalette.INK, 2.0)
			ci.draw_line(cc, cc + Vector2(0, -6), PopPalette.INK, 2.0)
			ci.draw_line(cc, cc + Vector2(5, 0), PopPalette.INK, 2.0)


## The helper's own small ring: its batch filling round the clock, the same
## colours as the big ring, so it reads as "the same job, by itself".
func _draw_helper_ring(ci: CanvasItem, st: Dictionary) -> void:
	var cycle := maxf(1.0, float(st["helper_cycle_ms"]))
	var k := clampf(float(st["helper_ms"]) / cycle, 0.0, 1.0)
	var hs := helper_size()
	var c := helper_base() - Vector2(0, PopMachineArt.height_at(_helper_stage(), hs) * 0.5)
	var r := hs * 0.62
	var top := -PI / 2
	ci.draw_arc(c, r, 0, TAU, 32, Color(0.35, 0.6, 0.95, 0.35), 7.0)
	ci.draw_arc(c, r, top, top + TAU * k, 32, Color(0.3, 0.55, 0.95), 7.0)
	var a := top + TAU * k
	ci.draw_circle(c + Vector2(cos(a), sin(a)) * r, 8, Color.WHITE)
	if _auto_flash > 0.0:
		ci.draw_arc(c, r * (1.0 + 0.4 * (1.0 - _auto_flash)), 0, TAU, 32, Color(PopPalette.GOLD, _auto_flash), 10.0)


## The idle hint (Step 10): once shaking has unlocked and has never been done,
## the finger held on the machine also slides side to side, with an arrow each
## way -- the gesture itself, seen while waiting (the crank's arrows show only
## mid-hold).
func _draw_hint_gesture(ci: CanvasItem, size_px: float, finger: bool) -> void:
	var st := _s()
	if not bool(st["unlocked"]["shake"]) or _shaken_ever:
		super(ci, size_px, finger)
		return
	super(ci, size_px, false)
	var c := machine_centre()
	var sw := sin(_t * 9.0) * size_px * 0.08 if not reduced_motion else 0.0
	var p := c + Vector2(size_px * 0.04 + sw, size_px * 0.1)
	ci.draw_circle(p, 22, PopPalette.CREAM)
	ci.draw_rect(Rect2(p.x - 22, p.y, 44, 70), PopPalette.CREAM)
	ci.draw_circle(p + Vector2(0, -6), 10, Color(1, 0.85, 0.8))
	ci.draw_arc(p, 22, PI, TAU, 16, PopPalette.INK, 4.0)
	for sgn: float in [-1.0, 1.0]:
		var tip := c + Vector2(sgn * size_px * 0.26, size_px * 0.13)
		ci.draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(sgn * 22, 15), tip - Vector2(sgn * 22, -15)]), Color(PopPalette.INK, 0.55))
		ci.draw_line(tip - Vector2(sgn * 18, 0), tip - Vector2(sgn * 56, 0), Color(PopPalette.INK, 0.55), 7.0)
