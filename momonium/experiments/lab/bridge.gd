class_name LabBridge
extends RefCounted

## The page's view of the Lab: `window.funlab`.
##   funlab.version, funlab.ready
##   funlab.state()           -> LabApp.state() (screen, tiles, the run...)
##   funlab.call(name, arg)   -> a named query below
## Read-only queries are always there (a tester can copy a summary from the
## console); the dev_* hooks that change a run answer only in dev mode
## (`?dev=1`) or when the page set `window.FUNLAB_E2E = true` first.

var _app: Node
var _callbacks: Array[JavaScriptObject] = []
var e2e := false


func attach(app: Node) -> void:
	_app = app
	if not OS.has_feature("web"):
		return
	e2e = bool(JavaScriptBridge.eval("!!window.FUNLAB_E2E", true))
	JavaScriptBridge.eval("window.funlab = Object.assign(window.funlab || {}, {version: %s, ready: true});" % JSON.stringify(String(app.call("version"))), true)
	var f: Variant = JavaScriptBridge.get_interface("window").funlab
	f._state = _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: _out(_app.call("state"))))
	f._call = _keep(JavaScriptBridge.create_callback(func(a: Array) -> void: _out(query(String(a[0]), JSON.parse_string(String(a[1]))))))
	JavaScriptBridge.eval("""
		window.funlab.state = () => { window.funlab._state(); return JSON.parse(window.funlab._out); };
		window.funlab.call = (name, arg) => { window.funlab._call(name, JSON.stringify(arg === undefined ? null : arg)); return JSON.parse(window.funlab._out); };
	""", true)


## Answers a named query. Off the web the tests call this directly.
func query(name: String, arg: Variant) -> Variant:
	var host: LabHost = _app.get("host")
	match name:
		"state":
			return _app.call("state")
		"summary":
			return host.session.summary() if host != null else null
		"csv":
			return host.session.to_csv() if host != null else ""
		"history":
			return _app.get("history")
	if name.begins_with("dev_") and not (e2e or bool((_app.get("route") as Dictionary).get("dev", false)) or not OS.has_feature("web")):
		return {"ok": false, "error": "dev hooks need ?dev=1"}
	match name:
		"dev_open":
			_app.call("open", String(arg))
			return {"ok": true}
		"dev_back":
			_app.call("back")
			return {"ok": true}
		"dev_restart":
			if host != null:
				host.restart()
			return {"ok": host != null}
		"dev_advance":
			# Answers with the state after the step (one call where a test
			# would make two).
			if host != null:
				host.step(float(arg))
				host.call("_refresh")
			return {"ok": host != null, "state": _app.call("state")}
		"dev_render_info":
			# What the renderer did in the last frame (draw calls and objects):
			# to tell 'more pixels' from 'more draw calls' when frames drop.
			return {"ok": true,
				"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				"objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
				"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
		"dev_time_scale":
			if host != null:
				host.time_scale = clampf(float(arg), 0.0, 10.0)
			return {"ok": host != null}
		"dev_pause":
			if host != null:
				var a: Array = arg
				host.set_pause(String(a[0]), bool(a[1]))
			return {"ok": host != null}
		"dev_action":
			if host != null:
				host.press_action()
			return {"ok": host != null}
	if host != null and name.begins_with("dev_"):
		return host.experiment.dev(name.trim_prefix("dev_"), arg)
	return null


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb


## Through eval: setting a property on a JavaScriptObject from GDScript is sent
## to JS as a method call named "set" and fails.
func _out(value: Variant) -> void:
	JavaScriptBridge.eval("window.funlab._out = %s;" % JSON.stringify(JSON.stringify(value)), true)
