shader_type spatial;
// A fish flung out of the water by the plane (scripts/endless/wake_fish.gd):
// life_models.gd's vertex-coloured fish, nose along +Z. The whole leap is here,
// worked out from the moment it breaks the water, so nothing runs on the CPU
// once it has begun: the arc, the body turned along it, the bend, the tail.
// The instance's transform: the spot on the water, turned along the leap,
// scaled to its length.
// INSTANCE_CUSTOM: x the moment it breaks (`clock`'s s), y its time in the air
// (s), z its run along the water (m/s), w a seed 0..1 signed by the side it
// bends to; over FLOP it goes in on its side.
render_mode cull_disabled;

uniform float clock = 0.0;
// The mesh's length nose to tail tip (m) and its nose's z.
uniform float fish_length = 0.48;
uniform float nose_z = 0.2;
uniform float gravity = 9.8;
// The centre starts this share of the length under the water.
uniform float sink_share = 0.3;
uniform float flop = 0.65;
// The scales' silver: how much of the paint gives way to it.
uniform vec3 silver : source_color = vec3(0.86, 0.9, 0.95);
uniform float silver_share = 0.75;
// The flash: a broad sheen off the flank and a tight glint in it.
uniform float sheen = 1.2;
uniform float glint = 9.0;
uniform float rim = 0.3;

varying float wet;
// 1 on the flanks and belly, 0 along the back: the silver stops at the dark back.
varying float flank;

void vertex() {
	float t = clock - INSTANCE_CUSTOM.x;
	float air = INSTANCE_CUSTOM.y;
	float u = t / air;
	wet = 1.0;
	flank = 1.0 - smoothstep(0.3, 0.85, NORMAL.y);
	if (u < 0.0 || u > 1.3) {
		// Not in the air: folded to a point.
		VERTEX = vec3(0.0);
	} else {
		float scale = length(MODEL_MATRIX[0].xyz);
		float seed = abs(INSTANCE_CUSTOM.w);
		float side = INSTANCE_CUSTOM.w < 0.0 ? -1.0 : 1.0;
		float along = clamp(u, 0.0, 1.0);
		float top = sin(along * PI);
		// The body, in the mesh's own metres. 0 at the nose, 1 at the tail's tip.
		float back = clamp((nose_z - VERTEX.z) / fish_length, 0.0, 1.0);
		float from_mid = back - 0.42;
		// The arch: a C held over the top of the leap.
		float bend = side * 1.3 * pow(top, 1.5);
		float arch = bend * from_mid * from_mid * fish_length;
		// The beat: hard as it breaks out, still at the top, a last flick going in.
		float beat = fish_length * (0.26 * (1.0 - smoothstep(0.0, 0.38, u)) + 0.2 * smoothstep(0.68, 0.9, u) * (1.0 - smoothstep(0.98, 1.2, u)));
		float wave = TAU * mix(9.0, 6.0, along) * t + seed * 40.0 - back * 4.2;
		float whip = smoothstep(0.25, 1.0, back);
		float swing = sin(wave) * beat * whip;
		vec3 v = VERTEX;
		v.x += arch * 0.75 + swing;
		v.y -= abs(bend) * from_mid * from_mid * fish_length * 0.7;
		// Stretched bursting out, squashed a touch going in.
		float long = 1.0 + 0.18 * (1.0 - smoothstep(0.0, 0.3, u)) - 0.08 * smoothstep(0.85, 1.0, u);
		float thin = 1.0 / sqrt(long);
		v *= vec3(thin, thin, long);
		// The normal turned with the bend's slope (sideways along z).
		float slope = bend * 2.0 * from_mid + cos(wave) * beat * whip * 4.2 / fish_length;
		vec3 n = normalize(NORMAL + vec3(0.0, 0.0, 1.0) * NORMAL.x * slope * 0.5);
		// The roll: it twists through the air, which turns the flank to the
		// sun and away; a flop lies over on its side.
		float roll = 0.55 * sin(along * 7.0 + seed * 6.2832) * top;
		if (seed > flop) roll += side * 1.45 * smoothstep(0.35, 0.95, u);
		float cr = cos(roll);
		float sr = sin(roll);
		v = vec3(cr * v.x - sr * v.y, sr * v.x + cr * v.y, v.z);
		n = vec3(cr * n.x - sr * n.y, sr * n.x + cr * n.y, n.z);
		// Nose along the arc.
		float rise = gravity * air * 0.5 - gravity * t;
		float run = INSTANCE_CUSTOM.z;
		float slant = length(vec2(rise, run));
		float cp = run / slant;
		float sp = rise / slant;
		v = vec3(v.x, cp * v.y + sp * v.z, -sp * v.y + cp * v.z);
		n = vec3(n.x, cp * n.y + sp * n.z, -sp * n.y + cp * n.z);
		// The arc, from just under the water, back to as far under. The
		// spot's own scale is undone: the arc is in metres.
		float sink = fish_length * scale * sink_share;
		float height = -sink + gravity * air * 0.5 * t - 0.5 * gravity * t * t;
		VERTEX = v + vec3(0.0, height, run * t) / scale;
		NORMAL = n;
		wet = 1.0 - 0.4 * along;
	}
}

void fragment() {
	ALBEDO = mix(COLOR.rgb, silver, silver_share * flank) * mix(0.5, 0.7, flank);
	ROUGHNESS = mix(0.5, 0.25, wet);
	METALLIC = 0.2;
	SPECULAR = 0.8;
}

void light() {
	// Wrapped all the way round: a fish on the far side of the sun is never a black shape.
	float wrap = (dot(NORMAL, LIGHT) + 1.0) * 0.5;
	DIFFUSE_LIGHT += wrap * wrap * wrap * 0.5 * ATTENUATION * LIGHT_COLOR / PI;
	vec3 half_way = normalize(VIEW + LIGHT);
	float over = max(dot(NORMAL, half_way), 0.0);
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// The flash stays silver in a low sun: most of the light's colour taken out.
	vec3 white = mix(LIGHT_COLOR, vec3(dot(LIGHT_COLOR, vec3(0.33))), 0.7);
	SPECULAR_LIGHT += ATTENUATION * white / PI * (pow(over, 7.0) * sheen + pow(over, 70.0) * glint + edge * rim);
}
