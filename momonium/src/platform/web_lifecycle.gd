class_name WebLifecycle
extends RefCounted

## Step 79: the page's own lifecycle on the web, told to the game as two
## callables -- `visibilitychange` (a tab hidden or shown, a phone's browser
## sent to the background and back) and `pagehide`/`pageshow` (leaving the page
## and coming back through the back-forward cache). On Android and desktop the
## engine's notifications say the same (main.gd `_notification`).

## Callbacks must outlive this call or the JS side calls into freed memory.
var _callbacks: Array[JavaScriptObject] = []
var _document: JavaScriptObject
## [target, event, callback] as added, for `detach`.
var _listeners: Array = []


func attach(on_hidden: Callable, on_visible: Callable) -> void:
	if not OS.has_feature("web"):
		return
	_document = JavaScriptBridge.get_interface("document")
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	var visibility := JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if hidden():
			on_hidden.call()
		else:
			on_visible.call())
	var leaving := JavaScriptBridge.create_callback(func(_args: Array) -> void: on_hidden.call())
	var back := JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if not hidden():
			on_visible.call())
	_callbacks.append_array([visibility, leaving, back])
	_listeners = [[_document, "visibilitychange", visibility], [window, "pagehide", leaving], [window, "pageshow", back]]
	for l: Array in _listeners:
		(l[0] as JavaScriptObject).addEventListener(String(l[1]), l[2])
	# Opened in a background tab: it starts hidden.
	if hidden():
		on_hidden.call()


## Takes the listeners off the page -- when the game scene is replaced (a
## sale, the demo, a reset), so the page never calls into the old one.
func detach() -> void:
	for l: Array in _listeners:
		(l[0] as JavaScriptObject).removeEventListener(String(l[1]), l[2])
	_listeners.clear()


## Whether the page is hidden now (never on other platforms).
func hidden() -> bool:
	return _document != null and String(_document.visibilityState) == "hidden"
