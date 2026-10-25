class_name WebBridge
extends RefCounted

## The browser's view of the game: `window.momonium`.
##
## Always present on web builds with the version and a ready flag, so a deploy
## check can tell which build it is talking to. Nothing here is needed to play.


static func is_web() -> bool:
	return OS.has_feature("web")


static func publish_ready(version: String) -> void:
	if not is_web():
		return
	JavaScriptBridge.eval("window.momonium = Object.assign(window.momonium || {}, {version: %s, ready: true});" % JSON.stringify(version), true)
