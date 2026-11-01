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
	_document.addEventListener("visibilitychange", visibility)
	window.addEventListener("pagehide", leaving)
	window.addEventListener("pageshow", back)
	# Opened in a background tab: it starts hidden.
	if hidden():
		on_hidden.call()


## Whether the page is hidden now (never on other platforms).
func hidden() -> bool:
	return _document != null and String(_document.visibilityState) == "hidden"
