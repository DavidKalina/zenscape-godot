// The storm's cloud in the endless clouds' composite (shaders/
// endless_cloud_composite.gdshader; include after shaders/
// storm_front.gdshaderinc): the field's clouds where the storm pushes them
// (shaders/storm_cloud.glslinc) cooled toward a slightly green grey, kept
// darker at the base than up the towers (the march's own light does most
// of it), the haze in front of it thinner and greyer (a storm stands
// out dark against the sky from kilometres off), and the lightning
// (zs_lightning) lighting the cloud from inside round each strike. With the
// storm off every function here leaves the cloud as it was.

// The storm's push on the field's clouds (shaders/storm_cloud.glslinc
// storm_push, its numbers): built from SP_AHEAD.x m ahead of the edge to
// whole at .y, let go over the clearing, faded at the line's ends; times
// the storm's intensity (set by scripts/endless/endless_clouds.gd).
const vec2 ZS_STORM_PUSH_AHEAD = vec2(3800.0, 250.0);
const float ZS_STORM_PUSH_BEHIND_FROM = -200.0;
const float ZS_STORM_PUSH_BEHIND = 1400.0;
const vec2 ZS_STORM_PUSH_ENDS = vec2(1500.0, 900.0);
uniform float storm_intensity = 1.0;
// The deck's hue (the luminance kept, the colour taken from this).
const vec3 ZS_STORM_CLOUD_HUE = vec3(0.84, 0.97, 1.0);
// How much of its own light the deck keeps: at its base, up its towers.
const float ZS_STORM_CLOUD_BASE = 0.7;
const float ZS_STORM_CLOUD_TOP = 1.0;
// How far its colour is greyed toward the hue.
const float ZS_STORM_CLOUD_GREY = 0.8;
// The haze over the deck: this share of the land's, its colour greyed and
// darkened toward the deck's.
const float ZS_STORM_HAZE_KEEP = 0.35;
const float ZS_STORM_HAZE_GREY = 0.55;
const float ZS_STORM_HAZE_DARK = 0.72;
// The lightning in the cloud: its colour, gain, and reach (m; a near glow
// and a faint wide one).
const vec3 ZS_STORM_FLASH_COL = vec3(0.82, 0.88, 1.0);
const float ZS_STORM_FLASH_GAIN = 2.2;
const vec2 ZS_STORM_FLASH_REACH = vec2(500.0, 2600.0);
const float ZS_STORM_FLASH_WIDE = 0.04;
const float ZS_STORM_FLASH_DECAY = 10.0;
// The flash on the deck follows the deck's own light (its pouches dark,
// its gaps and breaks pale): times lum / (lum + REF) x 2 under the push,
// so a deck lit as REF takes the flash whole. Laid flat, the core's
// frequent flickers washed the deck to a flat pale grey looking up.
const float ZS_STORM_FLASH_FORM_REF = 0.02;

float zs_storm_cloud_lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// How hard the storm pushes the cloud at world `xz` (0..1).
float zs_storm_cloud_weight(vec2 xz) {
	if (!zs_storm_on()) return 0.0;
	float d = zs_storm_d(xz);
	float core = zs_storm_shape.y;
	float half_len = zs_storm_shape.x * 0.5;
	return zs_storm_ramp(ZS_STORM_PUSH_AHEAD.x, ZS_STORM_PUSH_AHEAD.y, d)
		* zs_storm_ramp(-core + ZS_STORM_PUSH_BEHIND_FROM - ZS_STORM_PUSH_BEHIND, -core + ZS_STORM_PUSH_BEHIND_FROM, d)
		* zs_storm_ramp(half_len + ZS_STORM_PUSH_ENDS.x, half_len - ZS_STORM_PUSH_ENDS.y, abs(zs_storm_along(xz)))
		* clamp(storm_intensity, 0.0, 1.0);
}

// The cloud's colour `col` pushed (`w` the push, `crown` how high
// in its cloud, 0 at the base).
vec3 zs_storm_cloud_colour(vec3 col, float w, float crown) {
	if (w <= 0.0) return col;
	float lum = zs_storm_cloud_lum(col);
	float keep = mix(ZS_STORM_CLOUD_BASE, ZS_STORM_CLOUD_TOP, smoothstep(0.05, 0.9, crown));
	// Its own light kept (the sun's warmth on the lit heaps, the sky's blue
	// in their shade), only cooled toward the storm's grey: the dark comes
	// from its shadows, never a flat tint.
	vec3 grey = lum * ZS_STORM_CLOUD_HUE / zs_storm_cloud_lum(ZS_STORM_CLOUD_HUE);
	vec3 storm = mix(col, grey, ZS_STORM_CLOUD_GREY * mix(1.0, 0.6, smoothstep(0.1, 0.8, crown))) * keep;
	return mix(col, storm, w);
}

// The share of the haze laid over the deck.
float zs_storm_haze_share(float w) {
	return mix(1.0, ZS_STORM_HAZE_KEEP, w);
}

// The haze's colour over the deck.
vec3 zs_storm_haze_colour(vec3 sky, float w) {
	if (w <= 0.0) return sky;
	vec3 grey = zs_storm_cloud_lum(sky) * ZS_STORM_HAZE_DARK * ZS_STORM_CLOUD_HUE / zs_storm_cloud_lum(ZS_STORM_CLOUD_HUE);
	return mix(sky, grey, w * ZS_STORM_HAZE_GREY);
}

// The lightning's light on the cloud at world `p` (`crown` how high in its
// cloud; lit from inside and below, the base and heart glow most).
vec3 zs_storm_cloud_flash(vec3 p, float crown, float w, float lum) {
	if (!zs_storm_on() || zs_lightning.w <= 0.0) return vec3(0.0);
	float since = zs_lightning.z;
	if (since < 0.0 || since > 1.5) return vec3(0.0);
	// The stroke and a return stroke a beat after it.
	// (Brief and near: the core flickers every second or two, and a long
	// tail or wide reach left the whole deck lit a flat pale grey.)
	float f = exp(-since * ZS_STORM_FLASH_DECAY) + 0.55 * exp(-max(since - 0.13, 0.0) * 14.0) * step(0.13, since);
	float dist = length(p.xz - zs_lightning.xy);
	float reach = exp(-dist / ZS_STORM_FLASH_REACH.x) + ZS_STORM_FLASH_WIDE * exp(-dist / ZS_STORM_FLASH_REACH.y);
	float form = mix(1.0, 2.0 * lum / (lum + ZS_STORM_FLASH_FORM_REF), w);
	return ZS_STORM_FLASH_COL * (f * reach * zs_lightning.w * ZS_STORM_FLASH_GAIN * mix(1.0, 0.55, crown) * mix(0.5, 1.0, w) * form);
}
