class_name WindupWeb
extends RefCounted

## What the game asks of the browser: the address's options, and whether the
## page is hidden or the window has lost focus. Every call is a no-op off the
## web.
##
## Listeners are kept here: a JavaScript callback must outlive the call that
## made it, or the page calls into freed memory.

var _callbacks: Array[JavaScriptObject] = []
var _document: JavaScriptObject


static func available() -> bool:
	return OS.has_feature("web")


## The query string the page was opened with. The shared runner
## (deploy-web.sh) reads the address into RUNNER_PARAMS and then rewrites the
## address to the bare game folder, so location.search is empty by the time
## the game runs; a hashed game-*.html opened directly has no runner and keeps
## its own address.
static func query_string() -> String:
	if not available():
		return ""
	var v: Variant = JavaScriptBridge.eval(
		"((typeof RUNNER_PARAMS !== 'undefined') ? RUNNER_PARAMS : new URLSearchParams(location.search)).toString()", true)
	return String(v) if v != null else ""


## The system asks for less motion (prefers-reduced-motion).
static func prefers_reduced_motion() -> bool:
	if not available():
		return false
	var v: Variant = JavaScriptBridge.eval("!!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)", true)
	return v != null and bool(v)


## Calls on_hidden(bool) when the page is hidden or shown, and on_focus(bool)
## when the window loses or gains focus.
func attach(on_hidden: Callable, on_focus: Callable) -> void:
	if not available():
		return
	_document = JavaScriptBridge.get_interface("document")
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var vis := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_hidden.call(hidden())))
	var blur := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_focus.call(false)))
	var focus := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_focus.call(true)))
	_document.addEventListener("visibilitychange", vis)
	window.addEventListener("pagehide", vis)
	window.addEventListener("pageshow", vis)
	window.addEventListener("blur", blur)
	window.addEventListener("focus", focus)
	if hidden():
		on_hidden.call(true)


func hidden() -> bool:
	return _document != null and String(_document.visibilityState) == "hidden"


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb
