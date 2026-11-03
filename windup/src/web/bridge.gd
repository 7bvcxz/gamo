class_name WindupBridge
extends RefCounted

## The page's view of the game: `window.windup`.
##   windup.version, windup.ready
##   windup.state()          -> WindupMain.state()
##   windup.events()         -> the run's events as JSON lines
##   windup.call(name, arg)  -> a named query below
## Read-only queries always answer. The dev_* hooks that change a run answer
## only in dev mode (`?dev=1`) or when the page set `window.WINDUP_E2E = true`
## before the game started. Off the web the tests call `query` directly.

var _main: Node
var _callbacks: Array[JavaScriptObject] = []
var e2e: bool = false


func attach(main: Node) -> void:
	_main = main
	if not OS.has_feature("web"):
		return
	e2e = bool(JavaScriptBridge.eval("!!window.WINDUP_E2E", true))
	JavaScriptBridge.eval("window.windup = Object.assign(window.windup || {}, {version: %s, ready: true});"
		% JSON.stringify(String(main.call("version"))), true)
	var w: Variant = JavaScriptBridge.get_interface("window").windup
	w._state = _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: _out(_main.call("state"))))
	w._events = _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: _out(query("events", null))))
	w._call = _keep(JavaScriptBridge.create_callback(func(a: Array) -> void:
		_out(query(String(a[0]), JSON.parse_string(String(a[1]))))))
	JavaScriptBridge.eval("""
		window.windup.state = () => { window.windup._state(); return JSON.parse(window.windup._out); };
		window.windup.events = () => { window.windup._events(); return JSON.parse(window.windup._out); };
		window.windup.call = (name, arg) => { window.windup._call(name, JSON.stringify(arg === undefined ? null : arg)); return JSON.parse(window.windup._out); };
	""", true)


func dev_allowed() -> bool:
	if not OS.has_feature("web"):
		return true
	var config: RunConfig = _main.get("config")
	return e2e or (config != null and config.dev)


## Answers a named query.
func query(name: String, arg: Variant) -> Variant:
	var telemetry: Telemetry = _main.get("telemetry")
	match name:
		"state":
			return _main.call("state")
		"events":
			return telemetry.to_jsonl()
		"end":
			return _main.call("end_session")
		"icon_point":
			var hh: Hud = _main.get("hud")
			var vp3 := (_main as Node).get_viewport()
			var at: Vector2 = hh.volume_center() if String(arg) == "volume" else hh.motion_center()
			var q3: Vector2 = vp3.get_final_transform() * at
			var sz3 := Vector2(vp3.get_window().size)
			return {"x": q3.x / sz3.x, "y": q3.y / sz3.y}
		"restart_point":
			var h: Hud = _main.get("hud")
			var vp2 := (_main as Node).get_viewport()
			var q: Vector2 = vp2.get_final_transform() * h.restart_center()
			var sz := Vector2(vp2.get_window().size)
			return {"x": q.x / sz.x, "y": q.y / sz.y}
		"key_point":
			# Where the key is, as a fraction of the window: a browser test
			# clicks it without knowing the canvas scale or the device ratio.
			var view: AtelierView = _main.get("view")
			var vp := view.get_viewport()
			var p: Vector2 = vp.get_final_transform() * (view.get_global_transform_with_canvas() * view.key_center())
			var size := Vector2(vp.get_window().size) if vp.get_window() != null else vp.get_visible_rect().size
			return {"x": p.x / size.x, "y": p.y / size.y}
	if name.begins_with("dev_") and not dev_allowed():
		return {"ok": false, "error": "dev hooks need ?dev=1"}
	match name:
		"dev_new_game":
			_main.call("new_game", int(arg) if arg != null else RunConfig.DEFAULT_SEED)
			return {"ok": true, "state": _main.call("state")}
		"dev_wind":
			# n turns, each 1/cap apart in game time: the rules' cap holds here too.
			var balance: Balance = _main.get("balance")
			for i in maxi(1, int(arg) if arg != null else 1):
				_main.call("wind", "dev")
				_main.call("advance", 1.0 / balance.max_turns_per_second + 0.001)
			return {"ok": true, "state": _main.call("state")}
		"dev_restart":
			var hud: Hud = _main.get("hud")
			hud.press_restart()
			hud.press_restart()
			return {"ok": true, "state": _main.call("state")}
		"dev_advance":
			_main.call("advance", float(arg))
			return {"ok": true, "state": _main.call("state")}
		"dev_wake":
			var view: AtelierView = _main.get("view")
			if view.doll == null:
				return {"ok": false, "error": "no doll (art missing)"}
			view.doll.start_wake()
			return {"ok": true, "state": _main.call("state")}
		"dev_render_info":
			# What the renderer did last frame -- to tell 'more pixels' from
			# 'more draw calls' when the frame rate drops (the Fun Lab's hook).
			return {"ok": true,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
		"dev_layers":
			# Hide parts of the picture to find what costs frames: {glow, tint, fx, dolls, backdrop}.
			var v: AtelierView = _main.get("view")
			v.set_layers(arg if arg is Dictionary else {})
			return {"ok": true}
		"dev_pause":
			var a: Array = arg
			_main.call("set_pause", String(a[0]), bool(a[1]))
			return {"ok": true, "state": _main.call("state")}
	return {"ok": false, "error": "unknown query " + name}


func _out(value: Variant) -> void:
	JavaScriptBridge.get_interface("window").windup._out = JSON.stringify(value)


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb
