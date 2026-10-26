class_name SkyRenderer
extends ColorRect

## The sky band: the top two fifths of the screen (see sky.gdshader).

const SHADER := preload("res://assets/shaders/sky.gdshader")
const FRACTION := 0.4
## The painted cloud band (tools/art/build_textures.gd), when it exists.
const CLOUDS := "res://assets/textures/clouds.png"

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	if ResourceLoader.exists(CLOUDS):
		_mat.set_shader_parameter("clouds_tex", load(CLOUDS))
		_mat.set_shader_parameter("painted_clouds", 1.0)
	material = _mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_param(name: StringName, value: Variant) -> void:
	_mat.set_shader_parameter(name, value)


func _process(_delta: float) -> void:
	var size := get_viewport_rect().size
	position = Vector2.ZERO
	self.size = Vector2(size.x, size.y * FRACTION)
	_mat.set_shader_parameter("aspect", self.size.x / maxf(self.size.y, 1.0) * 1.0)
