shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// The campfire's bed of coals (scripts/campfire_fire.gd): a flat disc laid
// on the ash under the sticks, added over it, so the fire stands on heat and
// not on grey ash. Live coals breathe slowly in and out of a deep red, the
// hottest near the middle; no flicker faster than about 1 Hz.
#include "res://shaders/fire_noise.gdshaderinc"

// INSTANCE_CUSTOM.x is the fire's phase; COLOR.a its life (rain dims it).
uniform float time = 0.0;
uniform float strength = 1.0;

varying float v_seed;
varying float v_life;

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
	v_life = COLOR.a;
}

void fragment() {
	vec2 p = (UV-0.5)*2.0;
	float r = length(p);
	float t = time*0.35+v_seed*17.0;
	// Clumps of coal, each breathing on its own slow beat.
	float clumps = zs_fire_fbm(p*3.4+vec2(v_seed*9.0,v_seed*4.0));
	float breath = zs_fire_fbm(p*2.1+vec2(t,-t*0.7));
	float live = smoothstep(0.38,0.72,clumps*0.7+breath*0.5);
	float heat = live*(1.0-smoothstep(0.25,0.95,r));
	// Under it all, a soft warmth on the ash.
	float warmth = exp(-r*r*5.0)*0.35;
	vec3 color = vec3(0.5,0.035,0.004)*warmth;
	color += mix(vec3(0.7,0.06,0.005),vec3(1.0,0.4,0.05),smoothstep(0.4,0.95,heat))*heat;
	ALBEDO = color*strength*v_life;
	ALPHA = 1.0;
}
