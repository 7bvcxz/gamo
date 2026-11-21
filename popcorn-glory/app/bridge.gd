class_name PopBridge
extends RefCounted

## Step 46: the factory actor's script for its bake counters -- loaded only inside the dev calls.
## A preload here pinned it for the app's life, and with it its static bake cache (a node and
## SubViewports): every headless run then ended with "ObjectDB instances leaked at exit".
func _actor() -> GDScript:
	return load("res://variants/factory/actor.gd")

## The page's view of the game: `window.popcorn`.
##   popcorn.version, popcorn.ready
##   popcorn.state()          -> the app's state (screen, run, rects in window pixels)
##   popcorn.call(name, arg)  -> a named query below
## Read-only queries always answer. The dev_* hooks that change a run answer
## only with `?dev=1`, or when the page set `window.POPCORN_E2E = true` first.

var _app: Node
var _callbacks: Array[JavaScriptObject] = []
var e2e := false
var _p: Variant = null   ## window.popcorn, kept: its _put takes each answer (Step 46)


func attach(app: Node) -> void:
	_app = app
	if not OS.has_feature("web"):
		return
	e2e = bool(JavaScriptBridge.eval("!!window.POPCORN_E2E", true))
	JavaScriptBridge.eval("window.popcorn = Object.assign(window.popcorn || {}, {version: %s, ready: true});" % JSON.stringify(String(app.call("version"))), true)
	var p: Variant = JavaScriptBridge.get_interface("window").popcorn
	p._state = _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: _out(_app.call("state"))))
	p._call = _keep(JavaScriptBridge.create_callback(func(a: Array) -> void: _out(query(String(a[0]), JSON.parse_string(String(a[1]))))))
	_p = p
	JavaScriptBridge.eval("""
		window.popcorn._put = (s) => { window.popcorn._out = s; };
		window.popcorn.state = () => { window.popcorn._state(); return JSON.parse(window.popcorn._out); };
		window.popcorn.call = (name, arg) => { window.popcorn._call(name, JSON.stringify(arg === undefined ? null : arg)); return JSON.parse(window.popcorn._out); };
	""", true)


func dev_allowed() -> bool:
	return e2e or bool((_app.get("route") as Dictionary).get("dev", false)) or not OS.has_feature("web")


## Answers a named query. Off the web the tests call this directly.
func query(name: String, arg: Variant) -> Variant:
	match name:
		"state":
			return _app.call("state")
		"summary":
			return _app.call("summary")
		"log":
			return _app.call("log_lines")
		"log_document":
			return _app.call("log_document")
	if name.begins_with("dev_") and not dev_allowed():
		return {"ok": false, "error": "dev hooks need ?dev=1"}
	match name:
		"dev_open":
			_app.call("open", String(arg))
			return {"ok": true}
		"dev_back":
			_app.call("back")
			return {"ok": true}
		"dev_restart":
			_app.call("restart")
			return {"ok": true}
		"dev_advance":
			# Answers with the state after the step: one call where a test would make two.
			_app.call("dev_advance", int(arg))
			return {"ok": true, "state": _app.call("state")}
		"dev_save":
			# Writes the stand's save now and answers whether the store said it worked.
			return {"ok": bool(_app.call("save_now"))}
		"dev_money":
			# Setup for a test of a later moment (the stand's machines): money, not play.
			_app.call("dev_money", int(arg))
			return {"ok": true}
		"dev_news":
			# Step 37: a named event now (the schedule's draw is tested headless).
			return _app.call("dev_news", String(arg))
		"dev_contest":
			# Step 38: a named contest posted now (the board's rotation is tested headless).
			return _app.call("dev_contest", String(arg))
		"dev_build":
			# Step 42: a later factory for the motion tests: {plan: [[type, floor]...], sign, packer}.
			var a: Dictionary = arg if typeof(arg) == TYPE_DICTIONARY else {}
			return _app.call("dev_build", a.get("plan", []), int(a.get("sign", 6)), int(a.get("packer", 3)))
		"dev_fill_bin":
			# Step 44: the raw bin made full (counted as made), so the hand's next lot waits.
			return _app.call("dev_fill_bin")
		"dev_level":
			# A picture of a later machine for render checks -- not a play
			# (the play tests never call it).
			_app.call("dev_level", int(arg))
			return {"ok": true}
		"dev_sound":
			# Step 43: one sound of the grammar, at a place across the screen (x 0..1; none: centred).
			var sa: Dictionary = arg if typeof(arg) == TYPE_DICTIONARY else {}
			var au: PopAudio = _app.get("audio")
			if sa.has("x"):
				au.play_at(String(sa.get("name", "")), float(sa["x"]), float(sa.get("pitch", 1.0)), float(sa.get("db", 0.0)))
			else:
				au.play(String(sa.get("name", "")), float(sa.get("pitch", 1.0)), float(sa.get("db", 0.0)))
			return {"ok": true}
		"dev_bake":   # Step 46: the customers' baked textures on or off (the measurement)
			var actor := _actor()
			actor.bake_enabled = bool((arg as Dictionary).get("actors", true)) if typeof(arg) == TYPE_DICTIONARY else true
			if typeof(arg) == TYPE_DICTIONARY and bool((arg as Dictionary).get("free", false)):
				for k: String in (actor._baked as Dictionary).keys():
					((actor._baked as Dictionary)[k]["vp"] as Node).queue_free()
				(actor._baked as Dictionary).clear()
			return {"ok": true, "actors": actor.bake_enabled}
		"dev_hide":   # Step 46: hide one of the play view's layers (what it costs to draw and render)
			var play: Node = _app.get("frame").play if _app.get("frame") != null else null
			var a: Dictionary = arg if typeof(arg) == TYPE_DICTIONARY else {}
			var nm := String(a.get("name", ""))
			if play == null or not nm in play or not (play.get(nm) is CanvasItem):
				return {"ok": false, "error": "no layer " + nm}
			(play.get(nm) as CanvasItem).visible = not bool(a.get("hidden", true))
			return {"ok": true}
		"dev_render_info":
			return {"ok": true,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"static_mem": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
				"fps": Engine.get_frames_per_second(),
				# Step 46: where the frame goes -- Godot's process step, the model, the flush, the view.
				"process_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
				"actor_bakes_made": int(_actor().bakes_made), "actor_bakes_live": (_actor()._baked as Dictionary).size(),
				"viewports": _app.get_tree().root.find_children("*", "SubViewport", true, false).size(),
				"app_prof": (_app.get("prof") as Dictionary).duplicate(),
				"view_prof": (_app.get("frame").play.get("prof") as Dictionary).duplicate() if _app.get("frame") != null and _app.get("frame").play != null and "prof" in _app.get("frame").play else {}}
	return null


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb


## Through a JS function: setting a property on a JavaScriptObject from GDScript is
## sent to JS as a method call named "set" and fails. Step 46: the answer goes as the
## function's argument -- pasted into eval source (until 0.46) each answer was a new script
## the page compiled and kept, and a test asking the state every few seconds grew the heap.
func _out(value: Variant) -> void:
	_p._put(JSON.stringify(value))
