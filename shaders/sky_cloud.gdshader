shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, cull_back;
// The sky's cloud (scripts/sky_cloud.gd): faceted puffs, painted like the
// land. Each facet takes its own flat normal, so the puffs read as cut from
// the same faceted world. The top is the cloud's own white; the belly takes
// the instance colour, grey-blue while the cloud is full of water and pale
// as it is wrung dry, so how much it holds shows on its underside.

// The sunlit top, and a little of the colour kept at night so it still reads.
uniform vec3 cloud_top : source_color = vec3(0.98, 0.98, 0.96);
uniform float cloud_glow : hint_range(0.0, 1.0) = 0.1;
// Night (studies/celestial.gd): rgb the moonlight by phase and height, a how
// far into the night look. By night the cloud drops its own glow and goes to
// a dark silhouette, and the facets turned to the moon catch a moonlit rim
// that is bright under a full moon and gone under a new one.
global uniform vec4 zs_moon_light;
global uniform vec3 zs_moon_direction;
// How dark the cloud's body goes at night, and how bright its moonlit rim.
uniform float night_body : hint_range(0.0, 1.0) = 0.5;
uniform float night_rim : hint_range(0.0, 2.0) = 0.7;

void fragment() {
	// The facet's normal, turned to face the eye whichever way the
	// derivatives run.
	vec3 facet = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(facet, -VERTEX) < 0.0) facet = -facet;
	NORMAL = facet;
	vec3 up = (INV_VIEW_MATRIX * vec4(facet, 0.0)).xyz;
	vec3 color = mix(COLOR.rgb, cloud_top, smoothstep(-0.65, 0.55, up.y));
	float dark = clamp(zs_moon_light.a, 0.0, 1.0);
	ALBEDO = color * mix(1.0, night_body, dark);
	ROUGHNESS = 1.0;
	float edge = 1.0 - clamp(dot(facet, normalize(-VERTEX)), 0.0, 1.0);
	float moonward = smoothstep(-0.15, 0.7, dot(up, zs_moon_direction));
	EMISSION = color * cloud_glow * (1.0 - 0.85 * dark)
		+ zs_moon_light.rgb * night_rim * edge * edge * moonward;
}
