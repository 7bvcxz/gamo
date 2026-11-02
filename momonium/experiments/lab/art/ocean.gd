class_name LabOcean
extends ColorRect

## The game's sea (shared/shaders/ocean.gdshader, a copy of the game's) behind
## everything: procedural water anchored to the island, shallows and foam from
## a small "how close is land" texture (momonium src/render/shore_field.gd's
## plain build: one texel per tile, a cubic upscale).

const SHADER := preload("res://shared/shaders/ocean.gdshader")
const TEXELS_PER_TILE := 8
const MARGIN_TILES := 3

var island: LabIsland
var _mat: ShaderMaterial
var _time := 0.0
var _shore_tex: ImageTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	_mat.set_shader_parameter("deep_color", Color("#129ee0"))
	_mat.set_shader_parameter("mid_color", Color("#2eb5f7"))
	_mat.set_shader_parameter("shallow_color", Color("#2bd6db"))
	_mat.set_shader_parameter("far_color", Color("#69b8fc"))


## Anchors the water to `p_island` and rebuilds the coast when it grows.
func follow(p_island: LabIsland) -> void:
	island = p_island
	island.changed.connect(_rebuild_shore)
	_mat.set_shader_parameter("half_tile", Vector2(island.iso.tile_width, island.iso.tile_height) * 0.5)
	_rebuild_shore()


func _process(delta: float) -> void:
	_time += delta
	_mat.set_shader_parameter("time_s", _time)
	_mat.set_shader_parameter("screen_size", size)
	_mat.set_shader_parameter("sun_screen", size * Vector2(0.62, 0.22))
	if island == null or not is_instance_valid(island):
		return
	# Canvas pixel -> the island's local pixels (it may be moved and scaled).
	var to_local := (island.get_global_transform() as Transform2D).affine_inverse() * get_global_transform()
	_mat.set_shader_parameter("inv_x", to_local.x)
	_mat.set_shader_parameter("inv_y", to_local.y)
	_mat.set_shader_parameter("inv_o", to_local.origin)
	_mat.set_shader_parameter("water_drop", island.iso.drop())


func _rebuild_shore() -> void:
	var b := island.bounds()
	var origin := b.position - Vector2i(MARGIN_TILES, MARGIN_TILES)
	var tiles := b.size + Vector2i(MARGIN_TILES * 2, MARGIN_TILES * 2)
	var coverage := Image.create(tiles.x, tiles.y, false, Image.FORMAT_L8)
	for cell: Vector2i in island.cells:
		coverage.set_pixel(cell.x - origin.x, cell.y - origin.y, Color.WHITE)
	coverage.resize(tiles.x * TEXELS_PER_TILE, tiles.y * TEXELS_PER_TILE, Image.INTERPOLATE_CUBIC)
	if _shore_tex == null or _shore_tex.get_size() != Vector2(coverage.get_size()):
		_shore_tex = ImageTexture.create_from_image(coverage)
	else:
		_shore_tex.update(coverage)
	_mat.set_shader_parameter("shore_field", _shore_tex)
	_mat.set_shader_parameter("field_rect", Vector4(origin.x, origin.y, tiles.x, tiles.y))
