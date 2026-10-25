class_name OceanRenderer
extends ColorRect

## Screen-space sea below the horizon (see assets/shaders/ocean.gdshader).
## Lives in the background canvas layer; every frame it hands the shader the
## inverse camera transform so the pattern is anchored to the world, and it
## rebuilds the shore field when the coastline changes.

const SHADER := preload("res://assets/shaders/ocean.gdshader")
const HORIZON_FRACTION := 0.4

var camera: Camera2D
var projection: IsoProjection
var shore := ShoreField.new()
## Driven by the sky (Step 09); day defaults until then.
var sun_screen_fraction := Vector2(0.62, 0.18)
var sun_strength := 1.0
var quality := 1.0

var _world: WorldSystem
var _mat: ShaderMaterial


func setup(sim: Simulation, p_camera: Camera2D, p_projection: IsoProjection) -> void:
	camera = p_camera
	projection = p_projection
	_world = sim.system(&"world")
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var data := sim.data
	_mat.set_shader_parameter("deep_color", data.color("sea_day", 2))
	_mat.set_shader_parameter("mid_color", data.color("sea_day", 1))
	_mat.set_shader_parameter("shallow_color", data.color("sea_day", 3))
	_mat.set_shader_parameter("horizon_color", data.color("sea_day", 0))
	_mat.set_shader_parameter("foam_color", data.color("foam"))
	_mat.set_shader_parameter("half_tile", Vector2(projection.tile_width, projection.tile_height) * 0.5)
	_mat.set_shader_parameter("water_drop", projection.cliff_height * projection.height_scale)
	sim.bus.emitted.connect(_on_event)
	_rebuild_shore()


func set_palette(deep: Color, mid: Color, shallow: Color, horizon: Color, glint: Color) -> void:
	_mat.set_shader_parameter("deep_color", deep)
	_mat.set_shader_parameter("mid_color", mid)
	_mat.set_shader_parameter("shallow_color", shallow)
	_mat.set_shader_parameter("horizon_color", horizon)
	_mat.set_shader_parameter("glint_color", glint)


func _on_event(type: StringName, _payload: Dictionary) -> void:
	if type in [&"land_added", &"game_loaded"] and not _shore_dirty:
		_shore_dirty = true
		_rebuild_shore.call_deferred()


var _shore_dirty := false


func _rebuild_shore() -> void:
	_shore_dirty = false
	shore.build(_world)
	_mat.set_shader_parameter("shore_field", shore.texture)
	_mat.set_shader_parameter("field_rect", Vector4(shore.rect.position.x, shore.rect.position.y, shore.rect.size.x, shore.rect.size.y))


func _process(_delta: float) -> void:
	var size := get_viewport_rect().size
	position = Vector2.ZERO
	self.size = size
	var inv := camera.get_canvas_transform().affine_inverse()
	_mat.set_shader_parameter("inv_x", inv.x)
	_mat.set_shader_parameter("inv_y", inv.y)
	_mat.set_shader_parameter("inv_o", inv.origin)
	_mat.set_shader_parameter("screen_size", size)
	_mat.set_shader_parameter("horizon_y", size.y * HORIZON_FRACTION)
	_mat.set_shader_parameter("sun_screen", size * sun_screen_fraction)
	_mat.set_shader_parameter("sun_strength", sun_strength)
	_mat.set_shader_parameter("quality", quality)
	_mat.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
