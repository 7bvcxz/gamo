extends ColorRect
class_name Atmosphere

## The full-screen grade, on its own CanvasLayer between the world and the HUD.
##
## Above the world so it colours the scene, below the HUD so it never tints the
## text -- a vignette creeping over the corner of a panel is the difference
## between "atmospheric" and "my screen is dirty".
##
## The shader reads nothing and samples nothing (see atmosphere.gdshader), so the
## cost here is one full-screen pass of arithmetic. The uniforms are pushed only
## when they actually change: setting a shader parameter every frame for a value
## that moves once a second is a pointless buffer update on a platform where
## those are not free.

var main: Node2D

var _night: float = -1.0
var _vignette: float = -1.0

func _ready() -> void:
	# Never eats input; the HUD and the world both live around it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color(1, 1, 1, 1)

func _process(_delta: float) -> void:
	if main == null or material == null:
		return
	var night: float = main.night_level()
	# Cold closes the frame in as well as night does: the vignette is the game's
	# quietest way of saying the situation is getting worse, and it should answer
	# to the thing that is actually getting worse.
	var chill: float = clampf(1.0 - main.player.warmth / 100.0, 0.0, 1.0)
	var vignette: float = 0.30 + night * 0.26 + chill * 0.30
	if absf(night - _night) > 0.01:
		_night = night
		material.set_shader_parameter("night", night)
	if absf(vignette - _vignette) > 0.01:
		_vignette = vignette
		material.set_shader_parameter("vignette_strength", vignette)
