class_name LabWeb
extends RefCounted

## What the Lab asks of the browser: its address (which experiment, dev mode),
## the page's visibility and focus, a file to save, the reduced-motion
## preference. Every call is a no-op off the web.
##
## Listeners are kept here: a JavaScript callback must outlive the call that
## made it or the page calls into freed memory.

var _callbacks: Array[JavaScriptObject] = []
var _listeners: Array = []
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


## Puts `#id` in the address (a new history entry, so the browser's back
## button returns to the launcher); empty goes back to the bare address.
static func set_route(id: String) -> void:
	if not available():
		return
	if id == "":
		eval("history.pushState(null, '', location.pathname + location.search); window.dispatchEvent(new HashChangeEvent('hashchange'));")
	else:
		eval("location.hash = %s;" % JSON.stringify(id))


static func reduced_motion() -> bool:
	var v: Variant = eval("!!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)")
	return v != null and bool(v)


## Offers `text` to the player as a file download.
static func download(text: String, file_name: String, mime: String) -> void:
	if not available():
		return
	JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, mime)


## Listens for the address changing (the back button, an edited link),
## the page being hidden or shown, and the window losing or gaining focus.
func attach(on_hash: Callable, on_hidden: Callable, on_focus: Callable) -> void:
	if not available():
		return
	_document = JavaScriptBridge.get_interface("document")
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var hash := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_hash.call()))
	var vis := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_hidden.call(hidden())))
	var blur := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_focus.call(false)))
	var focus := _keep(JavaScriptBridge.create_callback(func(_a: Array) -> void: on_focus.call(true)))
	_listeners = [[window, "hashchange", hash], [_document, "visibilitychange", vis],
		[window, "pagehide", vis], [window, "pageshow", vis], [window, "blur", blur], [window, "focus", focus]]
	for l: Array in _listeners:
		(l[0] as JavaScriptObject).addEventListener(String(l[1]), l[2])
	if hidden():
		on_hidden.call(true)


func hidden() -> bool:
	return _document != null and String(_document.visibilityState) == "hidden"


func _keep(cb: JavaScriptObject) -> JavaScriptObject:
	_callbacks.append(cb)
	return cb
