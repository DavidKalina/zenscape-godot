#ifndef ZS_LAND_HORIZON
#define ZS_LAND_HORIZON
// The land's shadows past the sun's shadow map and its sky shade
// (scripts/endless/land_horizon.gd, --terrain-shadows=1): per spot of a
// square round the eye, the key light past the land toward it (red), the
// sky seen past the land round it (green) and the light again past only the
// occluders further than the horizon's NEAR (blue), which near the eye leaves
// the near hills to the sun's own map. Off (zs_horizon_at.w 0) nothing is read.
global uniform sampler2D zs_horizon : filter_linear, repeat_disable;
// Corner xz, side (m), on.
global uniform vec4 zs_horizon_at;

// From the eye (m): the far-only light out to here, the whole past it.
const vec2 ZS_HORIZON_NEAR = vec2(600.0, 860.0);

// (How much of the key light reaches `p`, how much sky it sees), `dist`
// m from the eye; (1, 1) off or outside the square.
vec2 zs_horizon_light(vec3 p, float dist) {
	if (zs_horizon_at.w <= 0.0) return vec2(1.0);
	vec2 uv = (p.xz - zs_horizon_at.xy) / max(zs_horizon_at.z, 1.0);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec2(1.0);
	vec3 s = texture(zs_horizon, uv).rgb;
	float sun = mix(s.b, s.r, smoothstep(ZS_HORIZON_NEAR.x, ZS_HORIZON_NEAR.y, dist));
	// Faded out toward the square's rim, so no edge shows.
	vec2 rim = min(uv, 1.0 - uv);
	float keep = smoothstep(0.0, 0.04, min(rim.x, rim.y)) * zs_horizon_at.w;
	return mix(vec2(1.0), vec2(sun, s.g), keep);
}
#endif
