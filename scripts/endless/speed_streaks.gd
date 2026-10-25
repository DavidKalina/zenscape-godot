extends ColorRect
## Speed streaks: faint wind lines near the screen's edges, running out
## from where the plane is going (`centre`, the travel's point on screen),
## for endless flight (studies/endless_flight.gd `_streaks`). One full-screen
## rect, one shader: thin soft lines in a few angle bands, dashed along the
## radius and flowing outward with the speed (`travel`), masked to the edges
## (EDGE, as a share of the screen's height from the centre) and, near the
## land (`ground`), stronger over the lower half. `strength` 0 draws nothing
## (the rect hides).
##
## Kept faint: at full strength a line is at most ALPHA opaque, warm white.

const ALPHA := 0.22
const EDGE := Vector2(0.4,1.0)
const CELLS := Vector2(230.0,150.0)

const CODE := """
shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform float strength = 0.0;
uniform float travel = 0.0;
uniform vec2 centre = vec2(0.5, 0.5);
uniform float aspect = 1.6;
uniform float px_uv = 0.001;
uniform float ground = 0.0;
uniform float alpha = 0.3;
uniform vec2 edge = vec2(0.3, 0.95);
uniform vec2 cells = vec2(230.0, 150.0);
uniform vec3 tint : source_color = vec3(0.97, 0.96, 0.92);

float hash(float n) { return fract(sin(n * 91.3458) * 47453.5453); }

// One band of streaks: `n` angle cells, a few of them carrying a line.
float band(vec2 p, float r, float n, float seed, float flow) {
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float ca = a * n;
	float id = floor(ca);
	float h = hash(id + seed);
	float h2 = hash(id * 1.37 + seed + 11.0);
	if (h2 < 0.72) return 0.0;
	// A pixel in angle cells here, so the line keeps about 2 px wide, soft.
	float px = n * px_uv / (6.2831853 * max(r, 0.001));
	float off = abs(fract(ca) - 0.5 - (h - 0.5) * 0.5);
	float line = 1.0 - smoothstep(px * 0.5, px * 2.2, off);
	// Dashes along the radius (in log radius, so they run faster outward).
	float u = fract(log(r + 0.02) * (1.1 + h * 1.4) - travel * flow * (0.7 + h * 0.6) + h * 13.0);
	float dash = smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.22, 0.48, u));
	return line * dash * (0.45 + 0.55 * h2);
}

void fragment() {
	vec2 p = UV - centre;
	p.x *= aspect;
	float r = length(p);
	float mask = smoothstep(edge.x, edge.y, r);
	float below = smoothstep(0.0, 0.45, UV.y - 0.5);
	mask *= 1.0 + ground * below * 1.3;
	float s = band(p, r, cells.x, 0.0, 1.0) + 0.7 * band(p, r, cells.y, 7.3, 0.8);
	COLOR = vec4(tint, clamp(s * mask * strength * alpha, 0.0, 0.6));
}
"""

var strength := 0.0
var travel := 0.0
var _mat: ShaderMaterial

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1,1,1,1)
	var shader := Shader.new()
	shader.code = CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("alpha",ALPHA)
	_mat.set_shader_parameter("edge",EDGE)
	_mat.set_shader_parameter("cells",CELLS)
	material = _mat
	visible = false

## One frame: `want` the strength (0 to 1, eased in over EASE_IN s and out
## over EASE_OUT), `flow` how fast the dashes run out (about the speed over
## 30 m/s), `centre` the travel's point on screen (UV), `ground` near the land.
const EASE_IN := 0.25
const EASE_OUT := 0.5
func show_state(delta: float, want: float, flow: float, centre: Vector2, ground: float) -> void:
	var rate := EASE_IN if want > strength else EASE_OUT
	strength = lerpf(strength,clampf(want,0.0,1.0),1.0-exp(-delta/rate)) if delta > 0.0 else want
	if strength < 0.003:
		strength = 0.0 if want <= 0.0 else strength
		visible = false
		return
	visible = true
	travel = fmod(travel+delta*flow,1000.0)
	var view := get_viewport_rect().size
	_mat.set_shader_parameter("strength",strength)
	_mat.set_shader_parameter("travel",travel)
	_mat.set_shader_parameter("centre",centre)
	_mat.set_shader_parameter("ground",clampf(ground,0.0,1.0))
	if view.y > 0.0:
		_mat.set_shader_parameter("aspect",view.x/view.y)
		_mat.set_shader_parameter("px_uv",1.0/view.y)
