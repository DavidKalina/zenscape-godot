#ifndef ZS_CLOUD_VOLUME_SHADOW
#define ZS_CLOUD_VOLUME_SHADOW
// The unified cloud volume's shade on the land (scripts/cloud_volume.gd,
// on by default): its shadow pass (shaders/cloud_volume_march.glsl
// SHADOW) looks up from the sea's feet toward the sun through the heaps and
// the towers and keeps, per spot of a square round the eye, how much light
// the cloud on high lets through, how much the heaps do, and how high the
// shade on high stands. A point on an island or a range takes the spot its
// sun line comes up through; the shade on high only if that cloud stands
// over it, the heaps' only below their crowns. Off (zs_cloud_shadow_at.w 0)
// nothing is read.
global uniform sampler2D zs_cloud_shadow : filter_linear, repeat_disable;
// Corner xz, side (m), on.
global uniform vec4 zs_cloud_shadow_at;
// The light (sun, moon at night) xyz, the sea's feet y it looks up from.
global uniform vec4 zs_cloud_shadow_light;

// The heaps' crowns stand under this (m: the march's split, scripts/
// cloud_volume.gd SHADE_SPLIT).
const float ZS_CLOUD_SHADE_SPLIT = -55.0;

// How much of the light the cloud keeps off `p` (0 none, 1 all).
float zs_cloud_volume_shade(vec3 p) {
	if (zs_cloud_shadow_at.w <= 0.0) return 0.0;
	vec3 light = zs_cloud_shadow_light.xyz;
	if (light.y < 0.03) return 0.0;
	vec2 q = p.xz + light.xz / max(light.y, 0.12) * (zs_cloud_shadow_light.w - p.y);
	vec2 uv = (q - zs_cloud_shadow_at.xy) / max(zs_cloud_shadow_at.z, 1.0);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	vec3 s = texture(zs_cloud_shadow, uv).rgb;
	float over = smoothstep(s.b + 30.0, s.b - 15.0, p.y);
	float keep = mix(1.0, s.r, over) * mix(s.g, 1.0, smoothstep(ZS_CLOUD_SHADE_SPLIT - 30.0, ZS_CLOUD_SHADE_SPLIT, p.y));
	// Faded out toward the square's rim, so no edge shows.
	vec2 rim = min(uv, 1.0 - uv);
	return (1.0 - keep) * smoothstep(0.0, 0.06, min(rim.x, rim.y)) * zs_cloud_shadow_at.w;
}
#endif
