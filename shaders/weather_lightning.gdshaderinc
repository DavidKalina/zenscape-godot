// A storm's lightning lighting the cloud from inside (scripts/endless/
// weather_lightning.gd writes zs_lightning: the flash's x, z, seconds since it
// began, and its light now, the pulses and the flash's strength already in
// it). Include after shaders/weather.gdshaderinc (the global) and
// shaders/reference_globals.gdshaderinc (zs_daylight). Lifted from the storm
// front's storm_cloud_light.gdshaderinc, without its deck.
//
// The flash glows round its spot in the cloud, most low down and in the
// cloud's thick heart (its own lit form: where the march found it bright it
// takes more, its dark pouches less), so it lights with shape, never a flat
// grey lift. At night it reaches less far and is eased harder, so a flash
// lifts the cloud round it and never whites the sky out.

// Its colour and gain.
const vec3 ZS_LIGHTNING_COL = vec3(0.8, 0.86, 1.0);
const float ZS_LIGHTNING_GAIN = 1.4;
// Its reach (m, by day): a near glow and a faint wide one (its share).
const vec2 ZS_LIGHTNING_REACH = vec2(700.0, 2400.0);
const float ZS_LIGHTNING_WIDE = 0.06;
// At night the near glow reaches this far (m), and the flash on the cloud is
// this share of the day's.
const float ZS_LIGHTNING_NIGHT_REACH = 480.0;
const float ZS_LIGHTNING_NIGHT = 0.6;
// The cloud's own light for its form: lum / (lum + REF) x 2, REF by day and
// by night (the night's cloud is far darker).
const vec2 ZS_LIGHTNING_FORM_REF = vec2(0.02, 0.003);
// The flash lights a cloud most low down: over LOW.x m above the sea it falls
// off over LOW.y m to HIGH of it.
const vec2 ZS_LIGHTNING_LOW = vec2(600.0, 700.0);
const float ZS_LIGHTNING_HIGH = 0.3;
// The most a flash adds (linear luminance), eased in: CAP x tanh(lum / CAP).
const float ZS_LIGHTNING_CAP = 0.07;

float zs_lightning_lum(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// The flash's light on the cloud at world `p` (`crown` how high in its cloud,
// 0 at the base; `lum` the cloud's own light there; `sea` the sea's y).
vec3 zs_lightning_cloud(vec3 p, float crown, float lum, float sea) {
	if (zs_lightning.w <= 0.0) return vec3(0.0);
	float dist = length(p.xz - zs_lightning.xy);
	float reach = exp(-dist / mix(ZS_LIGHTNING_NIGHT_REACH, ZS_LIGHTNING_REACH.x, zs_daylight))
		+ ZS_LIGHTNING_WIDE * exp(-dist / ZS_LIGHTNING_REACH.y);
	float ref = mix(ZS_LIGHTNING_FORM_REF.y, ZS_LIGHTNING_FORM_REF.x, zs_daylight);
	float form = clamp(2.0 * lum / (lum + ref), 0.2, 1.6);
	form *= mix(ZS_LIGHTNING_HIGH, 1.0, exp(-max(p.y - sea - ZS_LIGHTNING_LOW.x, 0.0) / ZS_LIGHTNING_LOW.y));
	form *= mix(ZS_LIGHTNING_NIGHT, 1.0, zs_daylight) * mix(1.0, 0.55, clamp(crown, 0.0, 1.0));
	vec3 add = ZS_LIGHTNING_COL * (zs_lightning.w * reach * ZS_LIGHTNING_GAIN * form);
	float a = zs_lightning_lum(add);
	return a > 1e-5 ? add * (ZS_LIGHTNING_CAP * tanh(a / ZS_LIGHTNING_CAP) / a) : add;
}
