class_name PopBridge
extends RefCounted

## The page's view of the game: `window.popcorn`.
##   popcorn.version, popcorn.ready
##   popcorn.state()          -> the app's state (screen, run, rects in window pixels)
##   popcorn.call(name, arg)  -> a named query below
## Read-only queries always answer. The dev_* hooks that change a run answer
## only with `?dev=1`, or when the page set `window.POPCORN_E2E = true` first.

var _app: Node
var _callbacks: Array[JavaScriptObject] = []
var e2e := false


func attach(app: Node) -> void:
	_app = app
	if not OS.has_feature("web"):
		return
	e2e = bool(JavaScriptBridge.eval("!!window.POPCORN_E2E", true))
	JavaScriptBridge.eval("window.popcorn = Object.assign(window.popcorn || {}, {version: %s, ready: true});" % JSON.stringify(String(app.call("version"))), true)
	var p: Variant = JavaScriptBridge.get_interface("window").popcorn
	p._state = _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: _out(_app.call("state"))))
	p._call = _keep(JavaScriptBridge.create_callback(func(a: Array) -> void: _out(query(String(a[0]), JSON.parse_string(String(a[1]))))))
	JavaScriptBridge.eval("""
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
		"dev_level":
			# A picture of a later machine for render checks -- not a play
			# (the play tests never call it).
			_app.call("dev_level", int(arg))
			return {"ok": true}
		"dev_render_info":
			return {"ok": true,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
				"static_mem": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
				"fps": Engine.get_frames_per_second()}
	return null


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb


## Through eval: setting a property on a JavaScriptObject from GDScript is sent
## to JS as a method call named "set" and fails.
func _out(value: Variant) -> void:
	JavaScriptBridge.eval("window.popcorn._out = %s;" % JSON.stringify(JSON.stringify(value)), true)
