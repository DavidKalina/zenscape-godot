extends CanvasLayer
## Frost on the canopy: crystals grown in from the screen's edges that melt
## back off (shaders/canopy_frost.gdshader). The cloud punch lays it
## (scripts/endless/moments/cloud_punch.gd); the wet layer
## (scripts/endless/screen_wet.gd) is its pattern. Hidden, and so free, while
## `cover` is 0. Whoever lays it drives it with `set_frost` each frame.

var _rect: ColorRect
var _mat: ShaderMaterial
## How far in it reaches (0 none, 1 full) and how far it has melted (0 ice,
## 1 a clear wet film).
var cover := 0.0
var melt := 0.0

func _init() -> void:
	name = "CanopyFrost"
	layer = 1

func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/canopy_frost.gdshader")
	_mat.set_shader_parameter("grain",randf()*40.0)
	_rect.material = _mat
	add_child(_rect)
	visible = false

## The frost now: `c` its reach, `m` its melt (both 0 to 1).
func set_frost(c: float, m: float) -> void:
	cover = clampf(c,0.0,1.0)
	melt = clampf(m,0.0,1.0)
	visible = cover > 0.002
	if _mat == null or not visible: return
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect",size.x/maxf(size.y,1.0))
	_mat.set_shader_parameter("cover",cover)
	_mat.set_shader_parameter("melt",melt)
