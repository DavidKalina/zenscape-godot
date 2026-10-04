shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// The campfire's flame (scripts/campfire_fire.gd). Art direction: one clear,
// confident flame shape in three warm bands (a cream heart, gold, a deep
// orange skin with a thin ember-red rim), not a boil of noise. The soft part
// is round it: the halo, the light and the coal bed. Alpha-clipped, so it
// draws in the opaque pass and writes depth for the display fog composite
// (docs/garden/VALIDATION.md:113).
#include "res://shaders/fire_noise.gdshaderinc"

// INSTANCE_CUSTOM = (phase, height m, lean_x, lean_z), lean as a share of
// the height. COLOR.r is the kind (0 a body flame, 1 a lick torn off the
// tip), COLOR.a the life (rain thins it).
uniform float time = 0.0;
uniform float intensity = 1.0;
uniform vec3 rim_color = vec3(0.62,0.07,0.012);
uniform vec3 skin_color = vec3(0.95,0.22,0.025);
uniform vec3 gold_color = vec3(1.0,0.5,0.08);
uniform vec3 heart_color = vec3(1.0,0.86,0.56);

varying float v_h;
varying float v_u;
varying float v_seed;
varying float v_life;
varying float v_kind;
varying float v_cycle;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float scale = max(INSTANCE_CUSTOM.y,0.001);
	vec3 lean = vec3(INSTANCE_CUSTOM.z,0.0,INSTANCE_CUSTOM.w);
	v_kind = COLOR.r;
	v_seed = phase;
	v_life = COLOR.a;
	v_h = 1.0-UV.y;
	v_u = (UV.x-0.5)*2.0;
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 to_eye = INV_VIEW_MATRIX[3].xyz-center;
	vec3 front = vec3(to_eye.x,0.0,to_eye.z);
	front = length(front) > 0.0001 ? normalize(front) : vec3(0.0,0.0,1.0);
	vec3 right = normalize(cross(vec3(0.0,1.0,0.0),front));
	// Seen from above a flat flame thins to a line: the card tips back from
	// the eye a little, so the shape holds from the orbit.
	float tilt = 0.55*asin(clamp(normalize(to_eye).y,0.0,1.0));
	vec3 up = vec3(0.0,1.0,0.0)*cos(tilt)-front*sin(tilt);
	float t = time+phase*31.0;
	float size = scale;
	float lift = 0.0;
	float wide = 0.62;
	v_cycle = 0.0;
	if (v_kind > 0.5) {
		// A lick: a scrap of flame torn off the tip, rising and dwindling.
		float cycle = fract(time*(0.75+0.5*fract(phase*5.31))+phase);
		v_cycle = cycle;
		lift = scale*mix(0.42,1.0,cycle);
		size = scale*0.3*(1.0-cycle*0.85);
		wide = 0.7;
	}
	// The whole flame breathes: two slow sines on its height.
	float stretch = 1.0+0.09*sin(t*3.1)+0.05*sin(t*7.3+1.7);
	float h = v_h;
	vec3 offset = right*(v_u*0.5*wide*size)+up*(h*size*stretch+lift)+lean*(h*h*size+lift);
	VERTEX = offset;
	MODELVIEW_MATRIX = VIEW_MATRIX*mat4(vec4(1.0,0.0,0.0,0.0),vec4(0.0,1.0,0.0,0.0),vec4(0.0,0.0,1.0,0.0),vec4(center,1.0));
}

void fragment() {
	float h = clamp(v_h,0.0,1.0);
	float lick = step(0.5,v_kind);
	float t = time*mix(1.0,1.4,lick)+v_seed*23.0;
	// Rising noise bends the column, more at the tip than at the foot: the
	// foot is held by the sticks, the tip is free.
	float n1 = zs_fire_fbm(vec2(v_u*1.2+v_seed*7.0,h*1.5-t*1.7));
	float n2 = zs_fire_fbm(vec2(v_u*2.6-v_seed*3.0,h*3.0-t*2.9));
	float sway = (sin(t*2.2+h*2.4)*0.1+(n1-0.5)*0.5)*pow(h,1.4)*(1.0-0.6*lick);
	float u = v_u-sway;
	// The teardrop: round at the foot, widest low, drawn up to a point.
	float foot = mix(0.2,0.4,lick);
	float w = 0.92*sqrt(clamp(h/foot,0.0,1.0))*pow(clamp(1.0-h,0.0,1.0),0.8);
	float heat = 1.0-abs(u)/max(w,0.001);
	// The upper half splits into tongues; the very tip gives out.
	heat -= (n2-0.42)*0.85*smoothstep(0.3,0.9,h)*(1.0-0.5*lick);
	heat -= smoothstep(0.7,1.0,h)*0.25;
	// Rain (and the end of a lick's climb) eats it from the edge in.
	heat -= (1.0-v_life)*0.45+lick*smoothstep(0.55,1.0,v_cycle)*0.6;
	float aa = fwidth(heat)*1.2+0.015;
	// Bands, each a little wider low where the fire is hottest.
	float skin = smoothstep(0.07,0.07+aa,heat);
	float gold = smoothstep(0.34,0.34+aa,heat+0.16*(1.0-h));
	float heart = smoothstep(0.62,0.62+aa,heat+0.34*(1.0-h)-0.2*h)*(1.0-lick);
	vec3 color = mix(rim_color,skin_color,skin);
	color = mix(color,gold_color,gold);
	color = mix(color,heart_color,heart);
	ALBEDO = color*intensity;
	ALPHA = smoothstep(0.0,aa,heat);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
