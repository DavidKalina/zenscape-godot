shader_type spatial;
// A kit cache's glow (scripts/kit_isle/kit_caches.gd): laid over a breakable
// piece's own meshes (material_overlay) when something is hidden inside.
// A soft edge glow (fresnel) breathing slowly, a faint band of shimmer
// climbing the stone, and a few specks that twinkle on its faces. One
// shared material; each piece's flare and phase are instance uniforms.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// The edge glow at rest (its least and most over a breath) and how tight
// to the silhouette it sits (higher: thinner).
uniform vec2 edge = vec2(0.1, 0.27);
uniform float edge_power = 3.2;
// Over the whole face, faintly, at the breath's top.
uniform float body = 0.02;
// Seconds a breath.
uniform float breath_time = 3.4;
// The shimmer band: its strength, how many bands a metre, how fast it climbs.
uniform float band = 0.08;
uniform float band_density = 0.35;
uniform float band_speed = 0.45;
// The specks: cells a metre, the share of cells that hold one, and how bright.
uniform float speck_cells = 2.0;
uniform float speck_share = 0.3;
uniform float speck = 2.6;
// A speck's radius (share of a cell).
uniform float speck_size = 0.28;
// A weak hit's flare (1 at the hit, fading): how much brighter it makes all.
uniform float flare_gain = 3.0;
// ... and how much it fills the faces besides (a pulse through the whole piece).
uniform float flare_fill = 0.35;

// The find's own colour (scripts/kit_isle/kit_caches.gd: its HUD tint).
instance uniform vec4 tint : source_color = vec4(0.56, 0.83, 0.9, 1.0);
instance uniform float flare = 0.0;
instance uniform float phase = 0.0;

varying vec3 world;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fres = pow(1.0 - facing, edge_power);
	float breath = 0.5 - 0.5 * cos(TAU * (TIME / breath_time + phase));
	float glow = fres * mix(edge.x, edge.y, breath) + body * breath;
	float b = sin((world.y * band_density - TIME * band_speed + phase) * TAU + sin(world.x * 1.3 + world.z * 1.1));
	glow += band * smoothstep(0.94, 1.0, b);
	// Specks: one in some cells, a dot that twinkles on its own clock.
	vec3 cell = floor(world * speck_cells);
	float h = hash3(cell);
	if (h < speck_share) {
		vec3 c = (cell + 0.5 + (vec3(hash3(cell + 7.1), hash3(cell + 3.7), hash3(cell + 1.3)) - 0.5) * 0.5) / speck_cells;
		float d = length(world - c) * speck_cells;
		float tw = pow(max(sin(TIME * (1.2 + h * 9.0) + h * 61.0), 0.0), 6.0);
		glow += speck * tw * smoothstep(speck_size, 0.0, d);
	}
	glow = glow * (1.0 + flare * flare_gain) + flare * flare_fill;
	ALBEDO = tint.rgb * glow;
}
