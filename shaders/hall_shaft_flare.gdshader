shader_type canvas_item;
render_mode blend_add;
// The warm flare over the view as the plane passes through a light shaft
// (scripts/hall_shafts_director.gd): a faint warm wash over the whole view
// and a glow round where the sun is on the screen, both scaled by `amount`.
uniform float amount = 0.0;
uniform vec2 sun_uv = vec2(0.5, 0.0);
uniform float facing = 1.0;
uniform vec3 tint = vec3(1.0, 0.85, 0.6);

void fragment() {
	vec2 d = (UV - sun_uv) * vec2(1.78, 1.0);
	float glow = exp(-dot(d, d) * 1.6) * facing;
	float wash = 1.0 - 0.5 * length(UV - 0.5);
	float v = amount * (0.16 * wash + 0.85 * glow);
	COLOR = vec4(tint * v, 1.0);
}
