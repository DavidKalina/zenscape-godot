shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The lift's tell (scripts/endless/peak_lift_wisps.gd): each wisp is a long soft
// quad facing the eye round its own axis, running up the lift's path and fading
// in and out over its run, and gone past `far` of the eye. INSTANCE_CUSTOM: the
// path's way (xyz), a phase (w).

uniform float run = 40.0;
uniform float far = 200.0;
uniform float pace = 26.0;
uniform vec3 tint = vec3(0.86,0.9,0.96);
uniform float strength = 0.2;

varying float v_fade;
varying float v_along;
varying float v_across;

void vertex() {
	float phase = INSTANCE_CUSTOM.w;
	float t = fract(TIME*pace/run+phase*7.0);
	vec3 way = normalize(INSTANCE_CUSTOM.xyz+vec3(0.0,0.9,0.0));
	float long = length(MODEL_MATRIX[1].xyz);
	vec3 base = MODEL_MATRIX[3].xyz+way*(t-0.5)*run;
	base += vec3(sin(TIME*0.7+phase*40.0),0.0,cos(TIME*0.5+phase*23.0))*3.0;
	vec3 to_eye = normalize(CAMERA_POSITION_WORLD-base);
	vec3 across = normalize(cross(way,to_eye));
	vec3 world = base+way*VERTEX.y*long+across*VERTEX.x*length(MODEL_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
	float seen = distance(CAMERA_POSITION_WORLD,base);
	// None seen steeply overhead: from under the gorge's top that is open sky.
	float over_eye = (base.y-CAMERA_POSITION_WORLD.y)/max(seen,1.0);
	v_fade = sin(3.14159*t)*(1.0-smoothstep(far*0.4,far,seen))*smoothstep(10.0,40.0,seen)*(1.0-smoothstep(0.15,0.35,over_eye));
	v_along = UV.y;
	v_across = UV.x*2.0-1.0;
}

void fragment() {
	ALBEDO = tint;
	float body = sin(3.14159*v_along);
	float edge = 1.0-v_across*v_across;
	ALPHA = strength*v_fade*body*body*edge*edge;
}
