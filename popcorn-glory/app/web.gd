class_name PopWeb
extends RefCounted

## What the game asks of the browser: its address, the page's visibility, a
## file to save. Every call is a no-op off the web. JavaScript callbacks are
## kept here: a callback must outlive the call that made it.

var _callbacks: Array[JavaScriptObject] = []
var _document: JavaScriptObject


static func available() -> bool:
	return OS.has_feature("web")


static func eval(js: String) -> Variant:
	if not available():
		return null
	return JavaScriptBridge.eval(js, true)


static func location_hash() -> String:
	var v: Variant = eval("location.hash")
	return String(v) if v != null else ""


static func location_search() -> String:
	var v: Variant = eval("location.search")
	return String(v) if v != null else ""


## `#id` in the address (a history entry, so the browser's back button
## returns to the chooser); "" goes back to the bare address.
static func set_route(id: String) -> void:
	if not available():
		return
	if id == "":
		eval("history.pushState(null, '', location.pathname + location.search); window.dispatchEvent(new HashChangeEvent('hashchange'));")
	else:
		eval("location.hash = %s;" % JSON.stringify(id))


static func download(text: String, file_name: String, mime: String) -> void:
	if available():
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, mime)


## Calls `on_hash()` when the address changes and `on_hidden(bool)` when the
## page is hidden or shown.
func attach(on_hash: Callable, on_hidden: Callable) -> void:
	if not available():
		return
	_document = JavaScriptBridge.get_interface("document")
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var hash_cb := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_hash.call()))
	var vis_cb := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_hidden.call(hidden())))
	window.addEventListener("hashchange", hash_cb)
	_document.addEventListener("visibilitychange", vis_cb)
	window.addEventListener("pagehide", vis_cb)
	window.addEventListener("pageshow", vis_cb)
	if hidden():
		on_hidden.call(true)


func hidden() -> bool:
	return _document != null and String(_document.visibilityState) == "hidden"


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb
