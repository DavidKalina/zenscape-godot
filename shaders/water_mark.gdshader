shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap;
// Marks on the water the plane leaves (scripts/endless/water_contact.gd), one
// flat quad per instance of a MultiMesh: kind 0 a patch of churned foam that
// spreads and thins into lace as it ages, kind 1 a ripple ring running out.
// INSTANCE_CUSTOM: x age (0 to 1), y kind, z seed, w strength.

global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;

uniform vec4 foam : source_color = vec4(0.86, 0.96, 1.0, 1.0);
uniform vec4 churn : source_color = vec4(0.45, 0.82, 0.88, 1.0);

varying vec4 mark;

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.55);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.55);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.55);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.55);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	mark = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float age = mark.x;
	float k = mark.w;
	vec3 colour;
	float alpha;
	if (mark.y < 0.5) {
		vec2 q = p * 6.0 + vec2(mark.z * 41.0, mark.z * 17.0);
		float n = vnoise(q) * 0.5 + vnoise(q * 2.3 + 5.0) * 0.3 + vnoise(q * 5.1 + 9.0) * 0.2;
		// Solid when fresh, thinning into veins as it ages.
		float vein = 1.0 - abs(n * 2.0 - 1.0);
		float body = mix(n, vein, smoothstep(0.1, 0.6, age));
		float cut = mix(0.25, 0.7, age);
		float lace = smoothstep(cut, cut + 0.18, body);
		float disc = smoothstep(1.0, mix(0.35, 0.7, age), r);
		alpha = disc * (lace * 0.7 + 0.1 * (1.0 - age)) * k * (1.0 - smoothstep(0.5, 1.0, age));
		colour = mix(churn.rgb, foam.rgb, lace);
	} else {
		// A thin bright ring with a dark trough inside it.
		float edge = 0.92;
		float crest = smoothstep(0.08, 0.0, abs(r - edge));
		float trough = smoothstep(0.16, 0.0, abs(r - edge + 0.12));
		alpha = (crest * 0.8 + trough * 0.25) * k * (1.0 - age) * (1.0 - age);
		colour = mix(churn.rgb * 0.7, foam.rgb, crest);
	}
	ALBEDO = colour;
	EMISSION = colour * zs_hemi_sky * zs_hemi_energy / PI * 0.4;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
