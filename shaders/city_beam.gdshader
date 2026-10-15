shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A rod of light through dusty air (scripts/city_kit_light2.gd): the
// sun-mirror's beam and the light shaft falling from the dark above. A
// cheap visual, no light of its own: an open cylinder (CylinderMesh, its
// length along local y, UV.y 0 at the top, 1 at the foot), additive, its
// core bright where the view crosses it face on and fading to nothing at
// its silhouette (so it reads as a soft rod, not a tube), dust motes
// drifting through it, its ends faded. Haze and torch alike: it dims with
// distance by itself (the fog would only brighten an additive pass).

uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.78);
uniform float strength = 0.32;
// Metres of rod (the mesh is scaled to it) and the dust's scale and drift.
uniform float length_m = 10.0;
uniform float dust_scale = 1.6;
uniform float drift = 0.35;
uniform float dust = 0.7;
// The share of the length faded in at its start (UV.y 0) and out at its end.
uniform float fade_in = 0.02;
uniform float fade_out = 0.06;
// How sharply its silhouette softens (higher, a thinner bright core).
uniform float core = 2.6;
// Gone by this far from the camera (m), faded from half of it.
uniform float far_fade = 160.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x),
			mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x),
			mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rod = pow(face, core);
	vec3 p = world / dust_scale + vec3(0.0, -TIME * drift, TIME * drift * 0.4);
	float motes = vnoise(p) * 0.6 + vnoise(p * 2.7 + 3.1) * 0.4;
	motes = mix(1.0 - dust, 1.0 + dust, smoothstep(0.35, 0.85, motes));
	float ends = smoothstep(0.0, fade_in, UV.y) * (1.0 - smoothstep(1.0 - fade_out, 1.0, UV.y));
	float dist = length(world - CAMERA_POSITION_WORLD);
	float far = 1.0 - smoothstep(far_fade * 0.5, far_fade, dist);
	// Close up, inside the rod: no burn-out when the camera passes through.
	float near = smoothstep(0.4, 2.5, dist);
	ALBEDO = tint * strength * rod * motes * ends * far * near;
}
