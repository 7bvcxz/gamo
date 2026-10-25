class_name WebBridge
extends RefCounted

## The browser's view of the game: `window.momonium`.
##
## Every web build publishes `{version, ready}` so a deploy check can tell
## which build it is talking to. When the page sets `window.MOMONIUM_E2E = true`
## before the engine starts (Playwright's addInitScript), the bridge also opens
## a test interface:
##
##   momonium.state()            -> sim.snapshot() as an object
##   momonium.command({type,..}) -> sim.execute(...) result
##   momonium.setTimeScale(x)    -> simulated seconds per real second
##   momonium.call(name, arg)    -> a view-level query registered by the game
##                                  (e.g. where a tile is on screen)
##
## Nothing here is needed to play, and none of it exists unless asked for.

var _sim: Simulation
var _callbacks: Array = []
var _queries: Dictionary = {}
var e2e := false


static func is_web() -> bool:
	return OS.has_feature("web")


func attach(sim: Simulation, version: String) -> void:
	_sim = sim
	if not is_web():
		return
	e2e = bool(JavaScriptBridge.eval("!!window.MOMONIUM_E2E", true))
	JavaScriptBridge.eval("window.momonium = Object.assign(window.momonium || {}, {version: %s, ready: true, e2e: %s});"
		% [JSON.stringify(version), "true" if e2e else "false"], true)
	if not e2e:
		return
	var m: Variant = JavaScriptBridge.get_interface("window").momonium
	m._command = _keep(JavaScriptBridge.create_callback(_on_command))
	m._state = _keep(JavaScriptBridge.create_callback(_on_state))
	m._scale = _keep(JavaScriptBridge.create_callback(_on_scale))
	m._call = _keep(JavaScriptBridge.create_callback(_on_call))
	JavaScriptBridge.eval("""
		window.momonium.command = (c) => { window.momonium._command(JSON.stringify(c)); return JSON.parse(window.momonium._out); };
		window.momonium.state = () => { window.momonium._state(); return JSON.parse(window.momonium._out); };
		window.momonium.setTimeScale = (x) => { window.momonium._scale(x); };
		window.momonium.call = (name, arg) => { window.momonium._call(name, JSON.stringify(arg === undefined ? null : arg)); return JSON.parse(window.momonium._out); };
	""", true)


## Callbacks must outlive this call or the JS side calls into freed memory.
func _keep(callback: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(callback)
	return callback


## Registers a view-level query for E2E (`momonium.call(name, arg)`).
func register_query(name: String, fn: Callable) -> void:
	_queries[name] = fn


## Hands a result back to the JS wrapper that is waiting synchronously for it.
## Through eval: Object.set() on a JavaScriptObject is forwarded to JS as a
## method call named "set" and fails.
func _out(value: Variant) -> void:
	JavaScriptBridge.eval("window.momonium._out = %s;" % JSON.stringify(JSON.stringify(value)), true)


func _on_command(args: Array) -> void:
	var parsed: Variant = JSON.parse_string(String(args[0]))
	_out(_sim.execute(parsed) if typeof(parsed) == TYPE_DICTIONARY else SimResult.fail("err.bad_command"))


func _on_state(_args: Array) -> void:
	_out(_sim.snapshot())


func _on_scale(args: Array) -> void:
	_sim.time_scale = clampf(float(args[0]), 0.0, 1000.0)


func _on_call(args: Array) -> void:
	var fn: Callable = _queries.get(String(args[0]), Callable())
	if not fn.is_valid():
		_out({"error": "unknown query %s" % args[0]})
		return
	_out(fn.call(JSON.parse_string(String(args[1]))))
