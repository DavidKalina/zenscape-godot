shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque, specular_schlick_ggx;
// The water still running in a ruined aqueduct's channel (studies/
// aqueduct_isle_art.gd): a shallow film over the stone bed, clear enough to
// see the slabs under it, running along `flow`. Its ripples are noise
// carried down the channel, stretched along it; thin bright streaks ride the
// current; it whitens where it pulls along the channel's edges; glassy, the
// sky's pale blue at a glance and a sharp sun glint.
global uniform float zs_flow_time;
uniform vec3 shallow_color : source_color = vec3(0.11, 0.22, 0.25);
uniform vec3 sky_color : source_color = vec3(0.55, 0.68, 0.8);
uniform vec3 foam_color : source_color = vec3(0.86, 0.9, 0.9);
// The way the water runs (world), its pace (m/s), the channel's middle
// line (a point on it) and half width (m).
uniform vec3 flow = vec3(0.0, 0.0, -1.0);
uniform float speed = 1.1;
uniform vec3 middle = vec3(100.0, 36.0, 0.0);
uniform float half_width = 0.7;
uniform float ripple = 0.06;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float waves(vec2 f) {
	return noise(f * vec2(1.3, 3.2)) + 0.55 * noise(f * vec2(2.9, 6.4) + 3.1) + 0.3 * noise(f * vec2(6.1, 11.0) + 7.7);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 along = normalize(flow.xz);
	vec2 across = vec2(-along.y, along.x);
	vec2 rel = world_position.xz - middle.xz;
	vec2 q = vec2(dot(rel, along), dot(rel, across));
	float t = zs_flow_time * speed;
	vec2 f = vec2(q.x - t, q.y);
	float e = 0.04;
	float h0 = waves(f);
	float ha = waves(f + vec2(e, 0.0));
	float hc = waves(f + vec2(0.0, e));
	vec2 g = vec2(ha - h0, hc - h0) / e * ripple;
	vec3 n = normalize(vec3(-(along.x * g.x + across.x * g.y), 1.0, -(along.y * g.x + across.y * g.y)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	// Streaks riding the current, and the pull along the edges.
	float streak = smoothstep(0.66, 0.86, noise(vec2(f.x * 0.55, q.y * 9.0))) * 0.55;
	float edge = clamp(abs(q.y) / half_width, 0.0, 1.0);
	float foam = smoothstep(0.72, 1.0, edge) * (0.45 + 0.55 * noise(vec2(f.x * 2.2, q.y * 14.0)));
	vec3 water = mix(shallow_color, sky_color, fresnel);
	ALBEDO = mix(water + streak * 0.14, foam_color, foam * 0.55);
	ALPHA = clamp(0.5 + fresnel * 0.4 + foam * 0.3 + streak * 0.1, 0.0, 1.0);
	ROUGHNESS = mix(0.04, 0.3, foam);
	SPECULAR = 0.65;
	METALLIC = 0.0;
}
