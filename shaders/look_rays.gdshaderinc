// Look pass light shafts (scripts/look_pass.gd), shared by the display-fog
// blend (shaders/reference_air_blend.gdshader) and the standalone grade
// (shaders/look_grade.gdshader) that draws when native mist hides the blend,
// which is most of play. The including shader declares `scene_color` (the
// frame) and `surface_depth` (studies/surface_depth.gd's copy of the scene's
// depth, r = 0 where nothing solid stands) before including this.
// Zero strength leaves the frame untouched.
uniform float rays_strength = 0.0;
// xy: the sun's position in screen UV; z: shaft strength from sun height and cloud.
uniform vec3 rays_sun = vec3(0.5, 0.5, 0.0);
uniform vec3 rays_color = vec3(1.0);

// How many samples each shaft pixel gathers toward the sun (a future graphics
// setting: fewer is cheaper and grainier).
const int RAYS_TAPS = 32;
// How far toward the sun the gather reaches (share of the way), and how fast
// a sample's light fades the further it lies from the sun's disc on screen.
const float RAYS_REACH = 0.92;
const float RAYS_SOURCE_FALLOFF = 6.5;
// The sky's brightness (display luma) at which it starts and is fully a
// source: only the glow round the sun and sunlit cloud, not plain blue sky.
const vec2 RAYS_BRIGHT = vec2(0.5, 1.2);

float zs_rays_open(vec2 uv) {
	return texture(surface_depth, uv).r <= 0.0 ? 1.0 : 0.0;
}

// The light a sample sends along a shaft: open sky (nothing solid in front),
// as bright as it stands, most near the sun. The clouds have no depth, so a
// sunlit crown or the glow round the disc gives light, and a tower's shaded
// flank, a ridge or an island's keel stands dark in it and casts the gap.
float zs_rays_source(vec2 uv, vec2 sun, vec2 aspect) {
	float open = zs_rays_open(uv);
	if (open <= 0.0) return 0.0;
	float luma = dot(texture(scene_color, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
	float bright = smoothstep(RAYS_BRIGHT.x, RAYS_BRIGHT.y, luma);
	return bright * exp(-length((uv - sun) * aspect) * RAYS_SOURCE_FALLOFF);
}

// The shafts' light at this pixel, `veil` (0 to 1) of it held back by air
// already in front.
vec3 zs_look_rays(vec2 uv, vec2 pixel_size, vec2 fragcoord, float veil) {
	if (rays_strength <= 0.0 || rays_sun.z <= 0.0) return vec3(0.0);
	vec2 aspect = vec2(pixel_size.y / pixel_size.x, 1.0);
	float reach = length((rays_sun.xy - uv) * aspect);
	float falloff = 1.0 - smoothstep(0.05, 1.1, reach);
	if (falloff <= 0.0) return vec3(0.0);
	float jitter = fract(sin(dot(fragcoord, vec2(12.9898, 78.233))) * 43758.5453);
	float light = 0.0;
	for (int i = 0; i < RAYS_TAPS; i++) {
		float t = (float(i) + jitter) / float(RAYS_TAPS);
		light += zs_rays_source(mix(uv, rays_sun.xy, t * RAYS_REACH), rays_sun.xy, aspect) * (1.0 - t * 0.5);
	}
	light /= float(RAYS_TAPS) * 0.75;
	return rays_color * light * falloff * rays_strength * rays_sun.z * (1.0 - veil * 0.6);
}
