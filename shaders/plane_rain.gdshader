shader_type spatial;
// A raindrop's streak as the plane flies through it (scripts/plane_weather.gd
// `rain`): a soft line, thin and faint at its edges, its tail fading behind
// its head, fading in from the lens (near_fade m) and out into the rain's
// distance (far_fade m). The particle's colour varies each drop's strength.
// The streak is laid in the world along `along` (its way past and length,
// m, the same for every drop), turned about it to face the eye: a drop
// coming at the camera draws as a line racing out from the middle of the
// view, not as a billboard's line slanted the camera's way.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform vec4 tint : source_color = vec4(0.78, 0.82, 0.9, 0.2);
uniform float near_fade = 4.0;
uniform float far_fade = 30.0;
uniform vec3 along = vec3(0.0, -1.0, 0.0);
// No streak drawn thinner than this (radians across, about 1.5 px): a
// thinner one breaks into dark dots under MSAA; widened, it fades to match.
uniform float thinnest = 0.0018;
// Each drop's own way off `along` (of its length) and its length's spread:
// gusting, not one clean radial rush.
uniform float jitter = 0.22;
uniform vec2 lengths = vec2(0.45, 1.15);

varying float seen_at;
varying float thin;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 way = length(along) > 0.0001 ? along : vec3(0.0, -0.01, 0.0);
	float id = float(INSTANCE_ID);
	vec3 h = fract(sin(vec3(id * 12.9898, id * 78.233, id * 37.719)) * 43758.5453);
	float reach = length(way);
	way = (way + (h - 0.5) * 2.0 * jitter * reach);
	way = normalize(way) * reach * mix(lengths.x, lengths.y, fract(h.x * 7.13 + h.y));
	vec3 side = cross(normalize(way), centre - eye);
	side = length(side) > 0.0001 ? normalize(side) : INV_VIEW_MATRIX[0].xyz;
	float wide = max(size * abs(VERTEX.x) * 2.0, 0.0001);
	float grow = max(1.0, length(centre - eye) * thinnest / wide);
	thin = 1.0 / grow;
	vec3 world = centre + way * size * VERTEX.y + side * size * VERTEX.x * grow;
	vec4 seen = VIEW_MATRIX * vec4(world, 1.0);
	seen_at = length(seen.xyz);
	VERTEX = seen.xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float body = 1.0 - across * across;
	// UV.y 0 at the head (leading, down the velocity), 1 at the tail.
	float tail = smoothstep(1.0, 0.25, UV.y) * smoothstep(0.0, 0.08, UV.y);
	float near = smoothstep(near_fade * 0.35, near_fade, seen_at);
	float far = 1.0 - smoothstep(far_fade * 0.4, far_fade, seen_at);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a * body * tail * near * far * thin;
}
