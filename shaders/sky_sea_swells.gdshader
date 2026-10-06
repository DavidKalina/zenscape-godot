shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The near cloud sea's swells, baked (scripts/sky_sea.gd `_bake_swells`):
// how far the heaps rise under the islands and close round the ranges'
// feet (shaders/sky_sea.gdshader `sea_rise`), drawn once over a square of
// the world round the eye so the march reads them from a texture instead of
// going through every island and range a step. Red the islands' lift, green
// the ranges' foot, each 0 to 1.

// The square's corner and side (world m).
uniform vec2 origin;
uniform float side = 6000.0;
// As shaders/sky_sea.gdshader `islands`, `ranges` and SWELL_REACH.
uniform vec4 islands[8];
uniform vec4 ranges[4];
uniform vec2 swell_reach = vec2(0.6, 1.5);

void fragment() {
	vec2 xz = origin + UV * side;
	float lift = 0.0;
	for (int i = 0; i < 8; i++) {
		if (islands[i].z <= 0.0) break;
		float d = length(xz - islands[i].xy);
		lift = max(lift, 1.0 - smoothstep(islands[i].z * swell_reach.x, islands[i].z * swell_reach.y, d));
	}
	float foot = 0.0;
	for (int i = 0; i < 4; i++) {
		if (ranges[i].z <= 0.0) break;
		float d = length(xz - ranges[i].xy);
		foot = max(foot, 1.0 - smoothstep(ranges[i].z * 0.6, ranges[i].z, d));
	}
	COLOR = vec4(lift, foot, 0.0, 1.0);
}
