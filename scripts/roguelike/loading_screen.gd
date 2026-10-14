extends CanvasLayer
## The loading screen (docs/design/roguelike/loading-screen-round1.md), the
## first thing the player sees: a calm painterly sky (shaders/
## loading_sky.gdshader: a gradient and two slow banks of cloud), a few
## floating-isle silhouettes bobbing in it, the game's title face (the isle
## card's gilt Newsreader), a hairline that fills as the layer is really
## built, and one small line saying what is being made.
##
## The look is all here and in loading_screen.tscn: the palette is the
## exports below (set on the sky shader and the silhouettes), the type is
## the isle card's (scripts/isle_splash.gd), the layout constants are in
## design px of a 1080-high screen. To restyle it, edit this scene and the
## exports; nothing else knows how it looks.
##
## The controller (scripts/roguelike/layer_loading.gd) calls `set_progress`,
## `set_line` and `reveal` / `conceal`. It draws only; it takes no input.
const Splash = preload("res://scripts/isle_splash.gd")

## Sky: top, middle and horizon of the gradient, the clouds' lit and shaded
## sides, and how much cloud (0..1).
@export var sky_top := Color(0.27, 0.38, 0.50)
@export var sky_middle := Color(0.58, 0.69, 0.75)
@export var sky_horizon := Color(0.94, 0.85, 0.72)
@export var cloud_light := Color(1.0, 0.96, 0.89)
@export var cloud_shade := Color(0.62, 0.68, 0.76)
@export_range(0.0, 1.0) var cloud_cover := 0.5
## The silhouettes: nearest isle's colour, and how much lighter each farther
## one is (towards the horizon, as hills fade).
@export var isle_colour := Color(0.17, 0.22, 0.30)
@export_range(0.0, 1.0) var haze := 0.45
## The type and the line.
@export var ink := Color(0.99, 0.95, 0.86)
@export var title := "ZENSCAPE"
@export var tagline := "gathering the isles"
@export var line_colour := Color(0.99, 0.95, 0.86)
## Design px: the title's size and tracking, its height on the screen (a
## share of it), the progress line's width, the small line's size.
@export var title_size := 56
@export var title_track := 16.0
@export_range(0.0, 1.0) var title_at := 0.2
@export var line_width := 280.0
@export var small_size := 15

@onready var frame: Control = $Frame
@onready var sky: ColorRect = $Frame/Sky
@onready var isles: Control = $Frame/Isles
@onready var marks: Control = $Frame/Marks
@onready var title_label: Label = $Frame/Title
@onready var tagline_label: Label = $Frame/Tagline
@onready var small_label: Label = $Frame/Small

## Seconds since it came up (the silhouettes' bob, the line's breath).
var age := 0.0
var _share := 0.0
var _shown := 0.0
var _px := 1.0
var _alpha := 1.0
var _goal := 1.0
var _rate := 1.0
var _title_font: FontVariation
var _small_font: FontVariation
## Fired once a `conceal` has finished (the screen is gone, not freed).
signal concealed

func _ready() -> void:
	layer = 110
	_title_font = Splash.inscription_font()
	_small_font = Splash.inscription_font()
	title_label.add_theme_font_override("font", _title_font)
	title_label.material = Splash.gilt_material()
	title_label.text = title
	tagline_label.add_theme_font_override("font", Splash.READING)
	tagline_label.text = tagline
	small_label.add_theme_font_override("font", _small_font)
	var material := sky.material as ShaderMaterial
	material.set_shader_parameter("top", sky_top)
	material.set_shader_parameter("middle", sky_middle)
	material.set_shader_parameter("horizon", sky_horizon)
	material.set_shader_parameter("cloud_light", cloud_light)
	material.set_shader_parameter("cloud_shade", cloud_shade)
	material.set_shader_parameter("cover", cloud_cover)
	isles.draw.connect(_draw_isles)
	marks.draw.connect(_draw_marks)
	_layout()

## How much is made, 0 to 1 (the line eases toward it).
func set_progress(share: float) -> void:
	_share = clampf(share, 0.0, 1.0)

## The small line under the hairline: what is being made now.
func set_line(text: String) -> void:
	small_label.text = text.to_upper()

## Fades in over `seconds` (0: at once), or out (`conceal`, then `concealed`).
func reveal(seconds := 0.0) -> void:
	_goal = 1.0
	_rate = 1.0 / maxf(seconds, 0.001)
	visible = true
	if seconds <= 0.0:
		_alpha = 1.0
		frame.modulate.a = 1.0

func conceal(seconds := 0.9) -> void:
	_goal = 0.0
	_rate = 1.0 / maxf(seconds, 0.001)

func is_gone() -> bool:
	return _alpha <= 0.0 and _goal <= 0.0

## Starts fully hidden, to be revealed.
func hide_now() -> void:
	_alpha = 0.0
	_goal = 0.0
	if frame != null: frame.modulate.a = 0.0

func _process(delta: float) -> void:
	age += delta
	if _alpha != _goal:
		var was := _alpha
		_alpha = move_toward(_alpha, _goal, delta * _rate)
		frame.modulate.a = smoothstep(0.0, 1.0, _alpha)
		if _alpha <= 0.0 and was > 0.0:
			visible = false
			concealed.emit()
	_shown = lerpf(_shown, _share, clampf(delta * 4.0, 0.0, 1.0))
	_layout()
	isles.queue_redraw()
	marks.queue_redraw()

func _layout() -> void:
	var size := frame.size
	_px = maxf(size.y, 1.0) / 1080.0
	Splash.style(title_label, _title_font, title_size, title_track, _px, ink)
	Splash.gild(title_label, title_size, _px)
	_centre(title_label, size.y * title_at)
	Splash.style(tagline_label, null, 22, 0.0, _px, Color(ink, 0.85))
	_centre(tagline_label, size.y * title_at + 92.0 * _px)
	Splash.style(small_label, _small_font, small_size, 4.0, _px, Color(ink, 0.7))
	_centre(small_label, size.y * 0.91 + 22.0 * _px)

## `label` centred across, its top at `top`.
func _centre(label: Label, top: float) -> void:
	var font: Font = label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	label.position = Vector2((frame.size.x - width) * 0.5, top)

# --- The silhouettes ----------------------------------------------------------------

## [x share of the width, y share of the height, size (design px across),
## depth 0 (near) to 1 (far), bob phase]: the far ones smaller, hazier and
## slower.
const ISLES := [
	[0.80, 0.50, 150.0, 0.85, 0.4],
	[0.15, 0.58, 190.0, 0.70, 2.1],
	[0.50, 0.56, 400.0, 0.0, 0.0],
	[0.92, 0.70, 120.0, 0.55, 4.0],
]

func _draw_isles() -> void:
	var size := isles.size
	for spec: Array in ISLES:
		var depth: float = spec[3]
		var wide: float = float(spec[2]) * _px
		# Farther isles bob slower and less; the near one turns a degree or
		# two, as if on its slow drift.
		var bob := sin(age * (0.55 - 0.3 * depth) + float(spec[4])) * (9.0 - 5.0 * depth) * _px
		var sway := sin(age * 0.23 + float(spec[4])) * deg_to_rad(1.6) * (1.0 - depth * 0.6)
		var at := Vector2(size.x * float(spec[0]), size.y * float(spec[1]) + bob)
		var colour := isle_colour.lerp(sky_middle, haze * depth)
		var shape := _isle(wide, int(float(spec[4]) * 10.0))
		var xf := Transform2D(sway, at)
		var moved := PackedVector2Array()
		for p in shape: moved.append(xf * p)
		if Geometry2D.triangulate_polygon(moved).is_empty(): continue
		isles.draw_colored_polygon(moved, colour)

## One isle's outline, `wide` px across, centred on its top surface: a flat
## uneven top with a broken arch and a column, the keel hanging under it in
## steps. Deterministic from `seed_value`.
static func _isle(wide: float, seed_value: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7
	var half := wide * 0.5
	var up := PackedVector2Array()
	var steps := 9
	for i in range(steps + 1):
		var t := float(i) / steps
		up.append(Vector2(lerpf(-half, half, t), -sin(t * PI) * wide * 0.035 + rng.randf_range(-1.0, 1.0) * wide * 0.006))
	var out := PackedVector2Array()
	out.append(Vector2(-half, 0.0))
	# Ruin: a column and a broken arch standing on the top, left of middle.
	var a := wide * (-0.16 + rng.randf_range(-0.04, 0.04))
	var arch := wide * 0.2
	var tall := wide * 0.2
	for p in up:
		if p.x < a - 1.0: out.append(p)
	var top_y := -wide * 0.03
	out.append(Vector2(a, top_y))
	out.append(Vector2(a, top_y - tall))
	out.append(Vector2(a + arch * 0.14, top_y - tall))
	out.append(Vector2(a + arch * 0.14, top_y - tall * 0.78))
	# the arch's underside, in a few steps
	for k in range(1, 6):
		var u := float(k) / 6.0
		out.append(Vector2(a + arch * (0.14 + 0.72 * u), top_y - tall * (0.78 + 0.1 * sin(u * PI))))
	out.append(Vector2(a + arch * 0.86, top_y - tall * 0.7))
	out.append(Vector2(a + arch * 0.86, top_y))
	for p in up:
		if p.x > a + arch * 0.86 + 1.0 and p.x < half * 0.2: out.append(p)
	# a second, smaller broken wall
	var b := half * 0.34
	out.append(Vector2(b, top_y))
	out.append(Vector2(b, top_y - tall * 0.5))
	out.append(Vector2(b + wide * 0.03, top_y - tall * 0.42))
	out.append(Vector2(b + wide * 0.06, top_y - tall * 0.6))
	out.append(Vector2(b + wide * 0.06, top_y))
	for p in up:
		if p.x > b + wide * 0.06 + 1.0: out.append(p)
	out.append(Vector2(half, 0.0))
	# The keel, back along the underside, stepped to a point.
	var keel := [Vector2(0.9, 0.08), Vector2(0.72, 0.2), Vector2(0.6, 0.36), Vector2(0.38, 0.5), Vector2(0.2, 0.7), Vector2(0.0, 0.95), Vector2(-0.18, 0.62), Vector2(-0.34, 0.5), Vector2(-0.6, 0.3), Vector2(-0.78, 0.17), Vector2(-0.93, 0.07)]
	for k: Vector2 in keel: out.append(Vector2(k.x * half, k.y * wide * 0.5 + rng.randf_range(-1.0, 1.0) * wide * 0.01))
	return out

# --- The hairline -------------------------------------------------------------------

func _draw_marks() -> void:
	var size := marks.size
	var mid := size.x * 0.5
	var y := size.y * 0.91
	var half := line_width * 0.5 * _px
	var base := Color(line_colour, 0.22)
	marks.draw_line(Vector2(mid - half, y), Vector2(mid + half, y), base, maxf(1.0, _px))
	var reach := half * clampf(_shown, 0.0, 1.0)
	var breathe := 0.8 + 0.2 * sin(age * 1.8)
	if reach > 0.5:
		marks.draw_line(Vector2(mid - half, y), Vector2(mid - half + reach * 2.0, y), Color(line_colour, 0.14 * breathe), 5.0 * _px, true)
		marks.draw_line(Vector2(mid - half, y), Vector2(mid - half + reach * 2.0, y), Color(line_colour, 0.85), maxf(1.5, 1.5 * _px), true)
	# a small diamond rides the end of what is made
	var d := 3.5 * _px
	var head := Vector2(mid - half + reach * 2.0, y)
	marks.draw_colored_polygon(PackedVector2Array([head + Vector2(0, -d), head + Vector2(d, 0), head + Vector2(0, d), head + Vector2(-d, 0)]), Color(line_colour, 0.95))
