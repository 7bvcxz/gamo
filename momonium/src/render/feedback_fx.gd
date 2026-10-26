class_name FeedbackFx
extends Node2D

## Small world-space responses to real events (Step 47): "+3" with the item's
## icon over a building that produced, "+$3" over one whose work just sold
## (Step 50: finished work is money at once), "x2" over the Clock Tower when its
## burst begins, the whole island twinkling once when the settlement is
## promoted. Every pop comes from a simulation event, never from a counter of
## its own.
##
## Restrained by construction:
##   - one pop per building and item within MERGE_SECONDS: a batch of jobs
##     finishing together is one "+N", never a stack (Step 54: the first shows
##     at once and the rest add to it -- it used to wait the whole window, so
##     the number came after the eye had moved on);
##   - nothing while time away is caught up (`sim.replaying`), after a load,
##     or with effects off; fades only with reduced motion;
##   - at most MAX_ACTIVE at once, from a pool, only where the camera looks,
##     and no per-frame work when nothing is showing;
##   - drawn in the world under the HUD, kept the same size on screen at any
##     zoom so big numbers stay readable and never cover a button.

const MERGE_SECONDS := 0.45
const MAX_ACTIVE := 10
## Step 54: larger, held longer (opaque for the first two thirds), with a
## heavy dark rim -- readable over the bright sea and the grass.
const LIFE := 1.9
const RISE := 36.0
const FONT_SIZE := 34
const ICON_PX := 34.0
const OUTLINE := Color(0.03, 0.1, 0.24, 0.95)

var sim: Simulation
var views: BuildingViews
var lib: SpriteLibrary
var cameras: CameraController
var font: Font
## Every pop shown, newest last: {kind, key, text, amount} (tests, E2E).
var shown: Array[Dictionary] = []

var _active: Array[Dictionary] = []
var _pool: Array[Node2D] = []
var _burst_was := false


func setup(p_sim: Simulation, p_views: BuildingViews, p_lib: SpriteLibrary, p_cameras: CameraController, p_font: Font) -> void:
	sim = p_sim
	views = p_views
	lib = p_lib
	cameras = p_cameras
	font = p_font
	z_index = 40
	sim.bus.emitted.connect(_on_event)
	var sp: SpecialSystem = sim.system(&"specials")
	_burst_was = sp != null and bool(sp.burst()["active"])
	# The burst is polled a few times a second, apart from the pops' animation,
	# which runs only while something is showing.
	var watch := Timer.new()
	watch.name = "BurstWatch"
	watch.wait_time = 0.25
	watch.autostart = true
	watch.timeout.connect(_watch_burst)
	add_child(watch)
	set_process(false)


func _on_event(type: StringName, payload: Dictionary) -> void:
	if type == &"game_loaded":
		clear()
		return
	if sim.replaying or not FxPrefs.enabled:
		return
	match type:
		&"produced":
			var id := int(payload["id"])
			var economy: EconomySystem = sim.system(&"economy")
			for item: String in (payload.get("items", {}) as Dictionary):
				var n := float(payload["items"][item])
				# A crop sold as it is picked shows as its money, not as a crop.
				if n > 0.0 and not economy.sells_at_once(item):
					_queue("prod:%d:%s" % [id, item], "produced", id, n, String(sim.data.item(item).get("icon", "")), Color("#fff6d8"))
		&"sold":
			# The money of a finished job, over the building that earned it.
			var id := int(payload.get("id", 0))
			if id != 0 and int(payload.get("money", 0)) > 0:
				_queue("money:%d" % id, "money", id, float(payload["money"]), "icon_coin", Color("#ffe27a"))
		&"tier_promoted":
			for v: BuildingView in views.views.values():
				v.sparkle()
			shown.append({"kind": "promoted", "key": "tier", "text": String(payload.get("name", "")), "amount": 0.0})


## One pop per building and item: shown at once; what follows within
## MERGE_SECONDS adds to the pop on screen instead of making another.
func _queue(key: String, kind: String, building: int, amount: float, icon: String, color: Color, text: String = "") -> void:
	for a: Dictionary in _active:
		if String(a.get("key", "")) == key and float(a["age"]) < MERGE_SECONDS:
			a["amount"] = float(a["amount"]) + amount
			_relabel(a)
			return
	_show(key, {"kind": kind, "building": building, "amount": amount, "icon": icon, "color": color, "text": text})



## A pop that grew: its number, laid out again, a small bump, and the record.
func _relabel(a: Dictionary) -> void:
	var node: Node2D = a["node"]
	var text := ("+$" if String(a["kind"]) == "money" else "+") + FxPrefs.compact(float(a["amount"]))
	_layout(node, text)
	a["bump"] = 0.0
	for i in range(shown.size() - 1, -1, -1):
		if String(shown[i]["key"]) == String(a["key"]):
			shown[i]["amount"] = float(a["amount"])
			shown[i]["text"] = text
			break


func clear() -> void:
	for a: Dictionary in _active:
		_recycle(a["node"])
	_active.clear()


func active_count() -> int:
	return _active.size()


func _process(delta: float) -> void:
	if _active.is_empty():
		set_process(false)
		return
	var zoom := cameras.camera.zoom.x if cameras != null and cameras.camera != null else 1.0
	for i in range(_active.size() - 1, -1, -1):
		var a: Dictionary = _active[i]
		a["age"] = float(a["age"]) + delta
		var k := float(a["age"]) / LIFE
		var node: Node2D = a["node"]
		# A pop that just grew swells a little and settles (not with reduced motion).
		var swell := 1.0
		if a.has("bump") and FxPrefs.moving():
			a["bump"] = float(a["bump"]) + delta
			swell = 1.0 + 0.18 * maxf(0.0, 1.0 - float(a["bump"]) / 0.2)
		node.scale = Vector2.ONE * swell / maxf(zoom, 0.05)
		if FxPrefs.moving():
			node.position = Vector2(a["from"]) + Vector2(0, -RISE * (1.0 - pow(1.0 - minf(k, 1.0), 2.0))) / maxf(zoom, 0.05)
		node.modulate.a = clampf((1.0 - k) * 3.0, 0.0, 1.0)
		if k >= 1.0:
			_recycle(node)
			_active.remove_at(i)


## The Clock Tower's burst is a time rule, not an event: watch it begin.
func _watch_burst() -> void:
	var sp: SpecialSystem = sim.system(&"specials")
	if sp == null:
		return
	var on := bool(sp.burst()["active"])
	if on and not _burst_was and not sim.replaying and FxPrefs.enabled:
		var tower := (sim.system(&"buildings") as BuildingSystem).special_built("clock_tower")
		if tower != 0:
			_show("burst", {"kind": "burst", "building": tower, "amount": 0.0, "icon": "", "color": Color("#ffd45a"), "text": "×2"})
	_burst_was = on


func _show(key: String, p: Dictionary) -> void:
	var v: BuildingView = views.view(int(p["building"])) if views != null else null
	if v == null:
		return
	var at := v.top_point()
	if cameras != null and cameras.camera != null and cameras.camera.is_inside_tree() and not cameras.sight_rect(0.0).has_point(at):
		return
	# Two things at once over one building (a felled tree's wood and its
	# money): one above the other, never on top of each other (Step 50).
	var zoom := cameras.camera.zoom.x if cameras != null and cameras.camera != null else 1.0
	for a: Dictionary in _active:
		if int(a.get("building", 0)) == int(p["building"]) and float(a["age"]) < 0.5:
			at.y -= 30.0 / maxf(zoom, 0.05)
	if _active.size() >= MAX_ACTIVE:
		_recycle(_active[0]["node"])
		_active.remove_at(0)
	var text := String(p["text"]) if String(p["text"]) != "" else ("+$" if String(p["kind"]) == "money" else "+") + FxPrefs.compact(float(p["amount"]))
	var node := _take()
	var label: Label = node.get_node("Text")
	label.add_theme_color_override("font_color", p["color"])
	var icon: Sprite2D = node.get_node("Icon")
	var icon_name := String(p["icon"])
	icon.visible = icon_name != "" and lib.has(icon_name)
	if icon.visible:
		lib.place(icon, icon_name, "center" if lib.pivot(icon_name, "center") != Vector2.ZERO else "origin")
		var r := lib.region(icon_name)
		icon.scale = Vector2.ONE * ICON_PX / maxf(r.size.x, r.size.y)
	_layout(node, text)
	node.position = at
	node.modulate.a = 1.0
	node.visible = true
	_active.append({"node": node, "age": 0.0, "from": at, "building": int(p["building"]), "key": key, "kind": String(p["kind"]), "amount": float(p["amount"])})
	shown.append({"kind": p["kind"], "key": key, "text": text, "amount": float(p["amount"])})
	if shown.size() > 60:
		shown.pop_front()
	set_process(true)


## Text and icon of a pop, centred on its point.
func _layout(node: Node2D, text: String) -> void:
	var label: Label = node.get_node("Text")
	var icon: Sprite2D = node.get_node("Icon")
	label.text = text
	label.reset_size()
	var width := label.size.x + (ICON_PX + 4.0 if icon.visible else 0.0)
	label.position = Vector2(-width * 0.5 + (ICON_PX + 4.0 if icon.visible else 0.0), -label.size.y * 0.5)
	icon.position = Vector2(-width * 0.5 + ICON_PX * 0.5, 0)


func _take() -> Node2D:
	if not _pool.is_empty():
		return _pool.pop_back()
	var node := Node2D.new()
	node.name = "Pop"
	var icon := Sprite2D.new()
	icon.name = "Icon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.add_child(icon)
	var label := Label.new()
	label.name = "Text"
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(label)
	add_child(node)
	return node


func _recycle(node: Node2D) -> void:
	node.visible = false
	_pool.append(node)
