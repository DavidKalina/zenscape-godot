#ifndef ZS_LAND_HORIZON
#define ZS_LAND_HORIZON
// The land's shadows past the sun's shadow map and its sky shade
// (scripts/endless/land_horizon.gd, --terrain-shadows=1): per spot of a
// square round the eye, the tangent of the land's horizon toward the key
// light's bearing (red), the sky seen past the land round it (green) and the
// horizon again past only the occluders further than the horizon's NEAR
// (blue), which near the eye leaves the near hills to the sun's own map. The
// light's height is read live here, so the shadows move smoothly as the sun
// sinks. A new march fades in over the last (zs_horizon_was). Off
// (zs_horizon_at.w 0) nothing is read.
global uniform sampler2D zs_horizon : filter_linear, repeat_disable;
// Corner xz, side (m), on.
global uniform vec4 zs_horizon_at;
// The march before, fading out: corner xz, side (m), its weight (1 to 0).
global uniform sampler2D zs_horizon_was : filter_linear, repeat_disable;
global uniform vec4 zs_horizon_was_at;
// The key light (toward it: the sun, the moon by night).
global uniform vec3 zs_horizon_key;

// From the eye (m): the far-only horizon out to here, the whole past it.
const vec2 ZS_HORIZON_NEAR = vec2(600.0, 860.0);
// The light's soft edge, in the horizon's tangent.
const float ZS_HORIZON_PEN = 0.025;

// (Light, sky) from one march's texel `s` at `uv` of its square.
vec2 zs_horizon_read(vec3 s, vec2 uv, float near_w, float sun_tan) {
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec2(1.0);
	float top = mix(s.b, s.r, near_w);
	float lit = smoothstep(-ZS_HORIZON_PEN, ZS_HORIZON_PEN, sun_tan - top);
	// Faded out toward the square's rim, so no edge shows.
	vec2 rim = min(uv, 1.0 - uv);
	return mix(vec2(1.0), vec2(lit, s.g), smoothstep(0.0, 0.04, min(rim.x, rim.y)));
}

// (How much of the key light reaches `p`, how much sky it sees), `dist`
// m from the eye; (1, 1) off or outside the square.
vec2 zs_horizon_light(vec3 p, float dist) {
	if (zs_horizon_at.w <= 0.0) return vec2(1.0);
	float sun_tan = zs_horizon_key.y / max(length(zs_horizon_key.xz), 1e-4);
	float near_w = smoothstep(ZS_HORIZON_NEAR.x, ZS_HORIZON_NEAR.y, dist);
	vec2 uv = (p.xz - zs_horizon_at.xy) / max(zs_horizon_at.z, 1.0);
	vec2 got = zs_horizon_read(texture(zs_horizon, uv).rgb, uv, near_w, sun_tan);
	if (zs_horizon_was_at.w > 0.0) {
		vec2 was_uv = (p.xz - zs_horizon_was_at.xy) / max(zs_horizon_was_at.z, 1.0);
		got = mix(got, zs_horizon_read(texture(zs_horizon_was, was_uv).rgb, was_uv, near_w, sun_tan), zs_horizon_was_at.w);
	}
	return mix(vec2(1.0), got, zs_horizon_at.w);
}
#endif
