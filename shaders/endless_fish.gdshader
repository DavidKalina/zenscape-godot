shader_type spatial;
// A leaping pond fish (scripts/endless/endless_fish.gd): life_models.gd's
// vertex-coloured fish, nose along +Z, bent per instance as it leaps.
// leap.x: the body's arch (a C curve, sideways, rad over the length),
// leap.y: the tail beat's swing (m at the tail tip), leap.z: its phase,
// leap.w: wet sheen (1 just out of the water).
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled;

instance uniform vec4 leap = vec4(0.0);
// The mesh's length nose to tail tip (m) and its nose's z.
uniform float fish_length = 0.48;
uniform float nose_z = 0.2;

void vertex() {
	// 0 at the nose, 1 at the tail's tip.
	float back = clamp((nose_z - VERTEX.z) / fish_length, 0.0, 1.0);
	// The arch: the body bent round its middle, both ends to one side.
	float from_mid = back - 0.42;
	float arch = leap.x * from_mid * from_mid * fish_length;
	// The beat: a wave running back down the body, growing to the tail.
	float whip = smoothstep(0.25, 1.0, back);
	float beat = sin(leap.z - back * 4.2) * leap.y * whip;
	VERTEX.x += arch * 0.75 + beat;
	// Part of the arch over the back: nose and tail down, a bow at the top.
	VERTEX.y -= abs(leap.x) * from_mid * from_mid * fish_length * 0.7;
	// The normal turned with the bend's slope (sideways along z).
	float slope = leap.x * 2.0 * from_mid + cos(leap.z - back * 4.2) * leap.y * whip * 4.2 / fish_length;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.0, 1.0) * NORMAL.x * slope * 0.5);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	// Wet scales: a tight glint fresh out of the water, drying a little.
	ROUGHNESS = mix(0.55, 0.22, leap.w);
	SPECULAR = mix(0.45, 0.8, leap.w);
	BACKLIGHT = COLOR.rgb * 0.25;
}
