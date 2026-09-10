shader_type spatial;
#include "res://shaders/cave_cutaway.gdshaderinc"
render_mode cull_disabled, diffuse_lambert;
uniform bool floor_surface = false;
uniform vec2 bed_center;
uniform vec2 pool_center;
uniform float moisture = 0.75;
uniform vec4 rock_tint : source_color = vec4(0.4,0.5,0.45,1.0);
// Walls only: outward normal of this side and how far its middle has dissolved.
uniform vec3 cutaway_normal = vec3(0.0);
uniform float cutaway_half_width = 14.2;
uniform float cutaway_ceiling = 8.3;
uniform float cutaway_reveal = 0.0;
varying vec3 stone;
float grain(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float patch(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0),vec2(1.0),fract(p));
	return mix(mix(grain(cell),grain(cell+vec2(1,0)),f.x),
		mix(grain(cell+vec2(0,1)),grain(cell+vec2(1,1)),f.x),f.y);
}
void vertex() { stone = VERTEX; }
void fragment() {
	if (cutaway_reveal > 0.0 && cave_cutaway(stone, cutaway_normal, cutaway_half_width, cutaway_ceiling, cutaway_reveal, FRAGCOORD.xy)) discard;
	float damp;
	if (floor_surface) {
		float dry_bed = smoothstep(1.8,3.0,distance(stone.xz,bed_center));
		float pool_edge = 1.0-smoothstep(1.3,4.2,distance(stone.xz,pool_center));
		damp = max(pool_edge, smoothstep(0.38,0.7,patch(stone.xz*0.32)))*dry_bed;
	} else {
		float streak = patch(stone.xz*vec2(1.8,1.5));
		damp = smoothstep(0.42,0.75,streak)*(0.45+0.55*smoothstep(0.0,7.5,stone.y));
	}
	damp *= moisture;
	ALBEDO = COLOR.rgb*mix(vec3(1.0),rock_tint.rgb*2.3,0.25)*mix(vec3(0.86,0.88,0.88),vec3(0.43,0.52,0.48),damp);
	ROUGHNESS = mix(0.94,0.4,damp);
	SPECULAR = mix(0.16,0.3,damp);
}
