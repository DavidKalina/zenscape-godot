shader_type spatial;
// The beacon over a found plane part (scripts/plane_parts.gd): a soft
// column of warm light rising from it and fading out overhead, so a part
// reads from across the isle. Light only, added over what's behind; soft at
// its edges (brightest where it faces you), faint bands drifting up it, and
// gone as you come up to it (`near`), so it never hazes the part close to.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.82, 0.52);
uniform float strength = 0.3;
// The column's height (m), so `rise` runs 0 at its foot to 1 at its top.
uniform float height = 5.0;
// From x m to y m away it comes in.
uniform vec2 near = vec2(2.5, 7.0);

varying float rise;

void vertex() {
	rise = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float soft = pow(abs(dot(NORMAL, VIEW)), 2.0);
	float fade = pow(1.0 - rise, 1.6) * smoothstep(0.0, 0.15, rise) * smoothstep(near.x, near.y, length(VERTEX));
	float bands = 0.75 + 0.25 * sin(rise * 16.0 - TIME * 1.8);
	ALBEDO = tint * soft * fade * bands * strength;
}
