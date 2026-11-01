class_name HandWorks
extends Node2D

## Step 83 (design/HANDS83.md): the player's own hands at work. A building the
## player is working (BuildingSystem.manual_jobs -- a stage the player started,
## in WORKING) shows a small glove with that job's tool over it: a watering
## can pouring, a pouch dropping seeds, a basket filling, a pickaxe or an axe
## striking, a trowel setting a sapling, a flask swirling, a hammer, logs fed
## to the fire, a pencil on a notebook. No Momo is drawn for the player's work,
## and nothing is drawn for a Momo's or an automatic stage.
##
## Presentation only. The hands come from the simulation's state and events
## (task_started with the player's worker, then the stage's end, a stop or a
## demolition); they are timed by the island's clock from the stage's start,
## so they run the stage's whole real duration, pause with it in the
## background, stop when it ends and come back as they were after a load --
## with no sound or effect replayed. Nothing they do touches the simulation.
## One node draws them all (three at most, by the rule), in the world under
## every panel (UiLayers.Z_HANDS), only where the camera looks.
##
## The tools are the painted tools of Step 66 (assets/hands/, built by
## tools/art/gen/build_hand_tools.gd); each turns about its grip, where the
## glove holds it. A pose is a loop of keys -- anticipation, the work, the
## recovery -- eased between, with its bits (drops, seeds, chips, sparks)
## drawn from the same clock. Reduced motion keeps the hand and tool still;
## effects off also drops the bits.

## A sound is asked for at each `contact` while on screen: {building, sound}.
signal struck(id: int, sound: String)

const ATLAS := "res://assets/hands/hand_tools"
## How tall a tool is in the world (a Momo is about 58).
const TOOL_PX := 44.0
## The glove: its size in world pixels per unit, and its colours.
const GLOVE_SCALE := 1.45
const INK := Color("#4b3324")
const CREAM := Color("#fff7e8")
const SHADE := Color("#efdcc2")
const CUFF := Color("#8fd6c9")
const CUFF_SHADE := Color("#6fbfb1")

## pose -> its tool, loop length (s), keys [phase, turn deg, dx, dy], the
## phase the tool lands (a sound, a burst), its bits, where the grip is from
## the building's work point, which way the glove's cuff points (degrees, in
## the tool's drawing) and the tap sound.
const POSES := {
	"water": {"tool": "watering_can", "period": 2.0, "contact": 0.45, "bits": "drops", "at": Vector2(-30, -40), "cuff": 180.0, "sound": "tap_water",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.22, -8.0, 0.0, -3.0], [0.45, 38.0, 2.0, 1.0], [0.78, 40.0, 2.0, 1.0], [1.0, 0.0, 0.0, 0.0]]},
	"sow": {"tool": "seed_pouch", "period": 1.6, "contact": 0.5, "bits": "seeds", "at": Vector2(0, -42), "cuff": -90.0, "sound": "tap_soft",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.3, -12.0, -1.0, -4.0], [0.5, 22.0, 1.0, 0.0], [0.62, 8.0, 0.0, -1.0], [0.74, 22.0, 1.0, 0.0], [1.0, 0.0, 0.0, 0.0]]},
	"harvest": {"tool": "basket", "period": 1.8, "contact": 0.5, "bits": "crops", "at": Vector2(0, -46), "cuff": -90.0, "sound": "tap_soft",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.28, -6.0, 0.0, -6.0], [0.5, 5.0, 0.0, 2.0], [0.7, 0.0, 0.0, -2.0], [1.0, 0.0, 0.0, 0.0]]},
	"dig": {"tool": "pickaxe", "period": 1.2, "contact": 0.5, "bits": "chips", "at": Vector2(-24, -12), "cuff": 24.0, "sound": "tap_pick",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.36, -40.0, -2.0, -3.0], [0.5, 36.0, 2.0, 2.0], [0.62, 28.0, 1.0, 1.0], [1.0, 0.0, 0.0, 0.0]]},
	"chop": {"tool": "axe", "period": 1.2, "contact": 0.5, "bits": "woodchips", "at": Vector2(-24, -12), "cuff": 27.0, "sound": "tap_wood",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.36, -42.0, -2.0, -3.0], [0.5, 34.0, 2.0, 2.0], [0.62, 26.0, 1.0, 1.0], [1.0, 0.0, 0.0, 0.0]]},
	"replant": {"tool": "trowel", "period": 2.0, "contact": 0.5, "bits": "crumbs", "at": Vector2(-18, -26), "cuff": 222.0, "sound": "tap_wood",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.3, -10.0, 0.0, -4.0], [0.5, 14.0, 1.0, 3.0], [0.76, 14.0, 1.0, 3.0], [1.0, 0.0, 0.0, 0.0]]},
	"study": {"tool": "flask", "period": 2.2, "contact": 0.25, "bits": "bubbles", "at": Vector2(0, -40), "cuff": -30.0, "sound": "tap_soft",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.25, -16.0, -1.0, -1.0], [0.5, 15.0, 1.0, 0.0], [0.75, -10.0, 0.0, -1.0], [1.0, 0.0, 0.0, 0.0]]},
	"hammer": {"tool": "hammer", "period": 0.9, "contact": 0.5, "bits": "sparks", "at": Vector2(-22, -12), "cuff": 30.0, "sound": "tap_metal",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.36, -36.0, -1.0, -3.0], [0.5, 30.0, 1.0, 2.0], [0.6, 24.0, 1.0, 1.0], [1.0, 0.0, 0.0, 0.0]]},
	"stoke": {"tool": "logs", "period": 1.8, "contact": 0.55, "bits": "embers", "at": Vector2(0, -40), "cuff": -90.0, "sound": "tap_wood",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.35, -12.0, -3.0, -6.0], [0.55, 10.0, 3.0, 2.0], [0.7, 6.0, 1.0, 0.0], [1.0, 0.0, 0.0, 0.0]]},
	"write": {"tool": "notebook", "period": 1.4, "contact": 0.3, "bits": "ink", "at": Vector2(12, -30), "cuff": -53.0, "sound": "",
		"keys": [[0.0, 0.0, 0.0, 0.0], [0.25, -3.0, -2.0, 1.0], [0.5, 2.0, 2.0, -1.0], [0.75, -2.0, -1.0, 1.0], [1.0, 0.0, 0.0, 0.0]]},
}

var sim: Simulation
var buildings: BuildingSystem
var views: BuildingViews
var cameras: CameraController
var texture: Texture2D
var tools: Dictionary = {}
var tool_height := 128.0
## building id -> {pose, start, end, cycle}: the hands drawn now.
var hands: Dictionary = {}
## Draws seen, for tests (a hand off screen is not drawn).
var drawn := 0


func setup(p_sim: Simulation, p_views: BuildingViews, p_cameras: CameraController) -> void:
	sim = p_sim
	buildings = sim.system(&"buildings")
	views = p_views
	cameras = p_cameras
	name = "HandWorks"
	z_index = UiLayers.Z_HANDS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture = load(ATLAS + ".png")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ATLAS + ".json"))
	tools = meta.get("tools", {})
	tool_height = float(meta.get("height", 128))
	sim.bus.emitted.connect(_on_event)
	resync()


## The hands as the simulation says they are now (a load, a new island): every
## building the player is working, each from its own stage's start -- no
## sound for a stroke that was already past.
func resync() -> void:
	hands.clear()
	for id: int in buildings.manual_jobs():
		_add(id)


## The pose a building's current stage plays with the player's hands ("" none).
func pose_of(id: int) -> String:
	var b := buildings.get_building(id)
	if b.is_empty():
		return ""
	var action := String(buildings.current_stage(b).get("action", ""))
	var pose := MomoSheet.shared().work_animation(action)
	return pose if POSES.has(pose) else ""


func _add(id: int) -> void:
	var pose := pose_of(id)
	if pose == "":
		return
	var b := buildings.get_building(id)
	var p: Dictionary = POSES[pose]
	var t := (sim.now_ms() - int(b["task_start"])) / 1000.0
	# A stroke already past its landing (a load mid-stage) makes no sound.
	hands[id] = {"pose": pose, "start": int(b["task_start"]), "end": int(b["task_end"]),
		"cycle": floori(t / float(p["period"])), "struck": fposmod(t / float(p["period"]), 1.0) >= float(p["contact"])}
	set_process(true)


func _on_event(type: StringName, p: Dictionary) -> void:
	match type:
		&"task_started":
			if int(p.get("worker", -1)) == BuildingSystem.PLAYER:
				_add(int(p["id"]))
		&"task_completed", &"task_stopped", &"building_removed":
			hands.erase(int(p.get("id", 0)))
			queue_redraw()
		&"game_loaded":
			resync()


func _process(_delta: float) -> void:
	# The state is the authority: a hand whose building is no longer worked by
	# the player goes, whatever event was missed.
	for id: int in hands.keys():
		var b := buildings.get_building(id)
		if b.is_empty() or b["state"] != BuildingSystem.WORKING or int(b.get("worker", -1)) != BuildingSystem.PLAYER:
			hands.erase(id)
	if hands.is_empty():
		queue_redraw()
		set_process(false)
		return
	var sight := cameras.sight_rect(40.0) if cameras != null and cameras.camera != null else Rect2(-1e9, -1e9, 2e9, 2e9)
	for id: int in hands:
		var h: Dictionary = hands[id]
		var p: Dictionary = POSES[h["pose"]]
		var t := (sim.now_ms() - int(h["start"])) / 1000.0
		var cycle := floori(t / float(p["period"]))
		var phase := fposmod(t / float(p["period"]), 1.0)
		if cycle != int(h["cycle"]):
			h["cycle"] = cycle
			h["struck"] = false
		# One tap per stroke, as the tool lands, and only where it is seen.
		if not bool(h["struck"]) and phase >= float(p["contact"]):
			h["struck"] = true
			var v := views.view(id) if views != null else null
			if v != null and sight.has_point(v.position) and String(p["sound"]) != "" and FxPrefs.moving():
				struck.emit(id, String(p["sound"]))
	queue_redraw()


## Where a building is worked: low on its drawing, in front.
func work_point(id: int) -> Vector2:
	var v := views.view(id) if views != null else null
	return v.work_point() if v != null else Vector2.ZERO


## {id: {pose, tool, grip, tip, rect}} -- where each hand is drawn now, in the
## world (tests, E2E).
func shown() -> Dictionary:
	var out := {}
	for id: int in hands:
		var g := _geometry(id)
		if not g.is_empty():
			out[id] = {"pose": hands[id]["pose"], "tool": POSES[hands[id]["pose"]]["tool"], "grip": g["grip"], "tip": g["tip"], "rect": g["rect"], "work": work_point(id)}
	return out


## The pose's keys at `phase`, eased: [turn deg, dx, dy].
static func sample(keys: Array, phase: float) -> Vector3:
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if phase <= float(b[0]):
			var span := maxf(float(b[0]) - float(a[0]), 0.0001)
			var k := smoothstep(0.0, 1.0, (phase - float(a[0])) / span)
			return Vector3(lerpf(float(a[1]), float(b[1]), k), lerpf(float(a[2]), float(b[2]), k), lerpf(float(a[3]), float(b[3]), k))
	var last: Array = keys[keys.size() - 1]
	return Vector3(float(last[1]), float(last[2]), float(last[3]))


func _phase_of(id: int) -> Dictionary:
	var h: Dictionary = hands[id]
	var p: Dictionary = POSES[h["pose"]]
	var t := (sim.now_ms() - int(h["start"])) / 1000.0
	return {"t": t, "phase": fposmod(t / float(p["period"]), 1.0) if FxPrefs.moving() else 0.0}


func _geometry(id: int) -> Dictionary:
	var h: Dictionary = hands[id]
	var p: Dictionary = POSES[h["pose"]]
	var tool: Dictionary = tools.get(String(p["tool"]), {})
	if tool.is_empty():
		return {}
	var k := sample(p["keys"], float(_phase_of(id)["phase"]))
	var scale_k := TOOL_PX / tool_height
	var grip_px := Vector2(float(tool["grip"][0]), float(tool["grip"][1]))
	var tip_px := Vector2(float(tool["tip"][0]), float(tool["tip"][1]))
	var region := Rect2(float(tool["region"][0]), float(tool["region"][1]), float(tool["region"][2]), float(tool["region"][3]))
	var turn := deg_to_rad(k.x)
	var grip: Vector2 = work_point(id) + (p["at"] as Vector2) + Vector2(k.y, k.z)
	var tip := grip + (tip_px - grip_px).rotated(turn) * scale_k
	# The drawn rectangle's bounds in the world (the tool turned about its grip).
	var corners: Array[Vector2] = []
	for c: Vector2 in [Vector2.ZERO, Vector2(region.size.x, 0), region.size, Vector2(0, region.size.y)]:
		corners.append(grip + (c - grip_px).rotated(turn) * scale_k)
	var r := Rect2(corners[0], Vector2.ZERO)
	for c: Vector2 in corners:
		r = r.expand(c)
	return {"grip": grip, "tip": tip, "turn": turn, "scale": scale_k, "grip_px": grip_px, "region": region, "rect": r}


func _draw() -> void:
	drawn = 0
	if hands.is_empty() or texture == null:
		return
	var sight := cameras.sight_rect(40.0) if cameras != null and cameras.camera != null else Rect2(-1e9, -1e9, 2e9, 2e9)
	for id: int in hands:
		var g := _geometry(id)
		if g.is_empty() or not sight.intersects(g["rect"]):
			continue
		drawn += 1
		var p: Dictionary = POSES[hands[id]["pose"]]
		var ph := _phase_of(id)
		draw_set_transform(g["grip"], g["turn"], Vector2.ONE * float(g["scale"]))
		var region: Rect2 = g["region"]
		draw_texture_rect_region(texture, Rect2(-(g["grip_px"] as Vector2), region.size), region)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The bits in front of the tool they leave (seeds from the pouch's
		# mouth fell behind its body), under the glove.
		if FxPrefs.enabled and FxPrefs.moving():
			_draw_bits(String(p["bits"]), g, float(ph["phase"]), float(p["contact"]), float(ph["t"]), work_point(id))
		draw_set_transform(g["grip"], g["turn"] + deg_to_rad(float(p["cuff"])), Vector2.ONE * GLOVE_SCALE)
		draw_glove(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The glove, a fist at the origin, its cuff toward +x and the handle it
## holds running along y, on `ci` (the building card's little hand too): a
## palm, four curled fingers wrapped round the handle on the far side, a thumb
## across them, a cuff with a band. Each part is laid as a dark rim first and
## its fill after, so the outline goes round the whole hand as one.
static func draw_glove(ci: CanvasItem, at: Vector2 = Vector2.ZERO, size: float = 1.0) -> void:
	var lw := 1.25 * size
	var palm := _rounded(Rect2(at + Vector2(-5.0, -6.0) * size, Vector2(10.5, 12.0) * size), 4.0 * size)
	var fingers: Array[Vector2] = []
	for y: float in [-4.4, -1.5, 1.5, 4.4]:
		fingers.append(at + Vector2(-5.6, y) * size)
	var thumb := at + Vector2(-1.6, -5.4) * size
	var cuff := _rounded(Rect2(at + Vector2(4.2, -6.2) * size, Vector2(6.4, 12.4) * size), 2.2 * size)
	var band := _rounded(Rect2(at + Vector2(8.0, -6.2) * size, Vector2(2.6, 12.4) * size), 1.2 * size)
	# The rim.
	ci.draw_colored_polygon(_grown(cuff, at + Vector2(7.4, 0) * size, lw), INK)
	ci.draw_colored_polygon(_grown(palm, at + Vector2(0.2, 0) * size, lw), INK)
	for f: Vector2 in fingers:
		ci.draw_circle(f, 2.15 * size + lw, INK)
	_ellipse(ci, thumb, Vector2(3.3, 2.0) * size + Vector2(lw, lw), -0.35, INK)
	# The fills.
	ci.draw_colored_polygon(cuff, CUFF)
	ci.draw_colored_polygon(band, CUFF_SHADE)
	ci.draw_colored_polygon(palm, CREAM)
	ci.draw_colored_polygon(_rounded(Rect2(at + Vector2(-1.0, -2.0) * size, Vector2(6.0, 7.6) * size), 3.0 * size), SHADE)
	for f: Vector2 in fingers:
		ci.draw_circle(f, 2.15 * size, CREAM)
	_ellipse(ci, thumb, Vector2(3.3, 2.0) * size, -0.35, CREAM)
	# The fingers' parting lines and a little shine.
	for y: float in [-2.95, 0.0, 2.95]:
		ci.draw_line(at + Vector2(-7.0, y) * size, at + Vector2(-4.4, y) * size, INK.lerp(SHADE, 0.35), 0.8 * size, true)
	ci.draw_circle(at + Vector2(-2.6, -2.2) * size, 1.0 * size, Color(1, 1, 1, 0.85))


static func _rounded(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rad := minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var corners := [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for c: Array in corners:
		for i in 5:
			var a := float(c[1]) + PI * 0.5 * i / 4.0
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


## A shape pushed out by `by` from `centre` (its rim).
static func _grown(pts: PackedVector2Array, centre: Vector2, by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p + (p - centre).normalized() * by)
	return out


static func _ellipse(ci: CanvasItem, c: Vector2, r: Vector2, turn: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(turn))
	ci.draw_colored_polygon(pts, col)


## The little bits of the work, from the clock alone (nothing kept between
## frames): `phase` 0..1 of the loop, `contact` where the tool lands.
func _draw_bits(kind: String, g: Dictionary, phase: float, contact: float, t: float, work: Vector2) -> void:
	var tip: Vector2 = g["tip"]
	var since := phase - contact
	match kind:
		"drops":
			if phase >= contact and phase <= 0.85:
				for i in 6:
					var k := fposmod(t * 2.6 + i / 6.0, 1.0)
					var p := tip + Vector2((i - 2.5) * 1.1 + sin(i * 2.1) * 1.2, 2.0 + k * 20.0)
					draw_circle(p, 1.6, Color(0.5, 0.78, 1.0, 0.9 * (1.0 - k)))
				var ring := fposmod(t * 1.8, 1.0)
				draw_arc(Vector2(tip.x, work.y + 4.0), 3.0 + ring * 9.0, 0, TAU, 16, Color(0.7, 0.9, 1.0, 0.5 * (1.0 - ring)), 1.2, true)
		"seeds":
			if since >= 0.0 and since < 0.45:
				for i in 5:
					var k := clampf((since - i * 0.03) / 0.35, 0.0, 1.0)
					if k <= 0.0 or k >= 1.0:
						continue
					var p := tip + Vector2((i - 2) * 2.4 * k, 22.0 * k * k)
					draw_set_transform(p, 0.6 + i, Vector2(1.0, 0.65))
					draw_circle(Vector2.ZERO, 1.7, Color("#b9824a"))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"crops":
			if phase > 0.3 and phase < 0.62:
				var k := (phase - 0.3) / 0.32
				for i in 2:
					var from := work + Vector2(-6.0 + i * 12.0, 4.0)
					var p := from.lerp(tip, k) + Vector2(0, -sin(k * PI) * 10.0)
					draw_circle(p, 2.6, INK)
					draw_circle(p, 2.0, Color("#e8452f"))
					draw_circle(p + Vector2(0, -1.8), 0.9, Color("#5fae3c"))
		"chips", "woodchips", "crumbs", "sparks":
			var life := 0.22 if kind == "sparks" else 0.3
			if since >= 0.0 and since < life:
				var k := since / life
				var col: Color = {"chips": Color("#9aa0a6"), "woodchips": Color("#d9a35b"), "crumbs": Color("#7a4f2c"), "sparks": Color("#ffcf4a")}[kind]
				for i in 6:
					var a := -PI * (0.15 + 0.7 * i / 5.0)
					var speed := 14.0 + (i % 3) * 5.0
					var p := tip + Vector2(cos(a), sin(a)) * speed * k + Vector2(0, 18.0 * k * k)
					draw_circle(p, (1.1 if kind == "sparks" else 1.6) * (1.0 - k * 0.5), Color(col, 1.0 - k))
		"bubbles":
			for i in 4:
				var k := fposmod(t * 0.9 + i / 4.0, 1.0)
				var p := tip + Vector2(sin(t * 3.0 + i * 1.7) * 2.0, -k * 14.0)
				draw_arc(p, 1.4 + k * 1.2, 0, TAU, 12, Color(0.75, 0.97, 0.92, 0.85 * (1.0 - k)), 0.9, true)
		"embers":
			if since >= 0.0 and since < 0.5:
				var k := since / 0.5
				for i in 5:
					var p := work + Vector2((i - 2) * 3.0 + sin(i + t * 4.0) * 1.5, -4.0 - k * (12.0 + i * 2.0))
					draw_circle(p, 1.3, Color(1.0, 0.6 + 0.08 * i, 0.2, 1.0 - k))
		"ink":
			var k := fposmod(t * 1.4, 1.0)
			for i in 3:
				var p := tip + Vector2(-4.0 + i * 3.0 + k * 3.0, 2.0 + sin(i * 2.0 + t * 6.0) * 1.0)
				draw_circle(p, 0.7, Color(0.25, 0.2, 0.45, 0.8 * (1.0 - absf(k - 0.5) * 2.0 * 0.6)))
