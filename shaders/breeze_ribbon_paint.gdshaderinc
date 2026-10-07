// The breeze ribbon's brush (shaders/breeze_ribbon.gdshader), shared with
// the sky's jet-stream ribbons (shaders/sky_jet_ribbon.gdshader) so the air
// is painted one way on the plate and between the islands.
// `rb_u` is 0 at the tail and 1 at the head; `rb_along` the brush's run
// back from the head in its own units (metres on the plate; a jet's
// strokes, ten times as long, pass a tenth of theirs, so the swell and the
// grain run at the same pace along a stroke); `rb_seed` the stroke's seed.
#ifndef ZS_BREEZE_RIBBON_PAINT
#define ZS_BREEZE_RIBBON_PAINT

// A brush's pressure: a fine needle at the head, full just behind, a long
// run down to nothing at the tail, swelling and easing along it.
float rb_taper_at(float rb_u) {
	return smoothstep(0.0, 0.35, rb_u) * (1.0 - smoothstep(0.9, 1.0, rb_u));
}

float rb_pressure_at(float rb_along, float rb_seed) {
	return 0.7 + 0.3 * sin(rb_along * 0.9 + rb_seed) * sin(rb_along * 0.37 + rb_seed * 1.7);
}

float rb_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rb_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rb_hash(i), rb_hash(i + vec2(1.0, 0.0)), f.x), mix(rb_hash(i + vec2(0.0, 1.0)), rb_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How much paint lies at a point of the stroke: `rb_v` -1..1 across,
// `rb_facing` how side-on the stroke runs to the eye (0 end-on), `rb_cover`
// its true width over its drawn width. Times the stroke's opacity.
float rb_paint_alpha(float rb_u, float rb_along, float rb_v, float rb_seed, float rb_facing, float rb_cover, float rb_scatter) {
	// A loaded brush: a soft wash the full width and a brighter core a
	// little to one side, as paint gathers on the brush's heel.
	float rb_wash = (1.0 - smoothstep(0.4, 1.0, abs(rb_v))) * 0.55;
	float rb_core_v = (rb_v + 0.15) * 2.4;
	float rb_soft = max(rb_wash, exp(-rb_core_v * rb_core_v));
	// The brush dries toward the tail: a soft grain along the stroke. It
	// thins the paint but never breaks it, so a tail never reads as dashes.
	float rb_dry = 1.0 - rb_u;
	float rb_bristle = rb_noise(vec2(rb_along * 0.55 + rb_seed, rb_v * 4.5 + rb_seed * 0.3));
	float rb_paint = mix(1.0, 0.55 + 0.45 * rb_bristle, smoothstep(0.5, 1.0, rb_dry));
	// Brightest just behind the head, fading down the tail.
	float rb_body = mix(0.3, 1.0, sqrt(rb_u));
	float rb_side_on = smoothstep(0.12, 0.5, rb_facing);
	return rb_body * rb_paint * rb_soft * rb_side_on * mix(0.75, 1.0, rb_cover) * (0.85 + 0.5 * rb_scatter);
}

// The stroke's light: the sky's, the sun's (brighter looking toward it,
// `rb_scatter`), a breath of its own at night.
vec3 rb_paint_light(float rb_scatter) {
	vec3 sun = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight;
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	return sky * 1.15 + sun * (0.4 + 0.9 * rb_scatter) + vec3(0.02 + 0.03 * zs_night);
}

#endif
