shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// One add-blended billboard tongue. `blend_add` survives the Balanced display
// fog composite, and every bit of brightness is albedo, because glow is off.
#include "res://shaders/fire_noise.gdshaderinc"

// INSTANCE_CUSTOM = (phase, scale, lean_x, lean_z); COLOR.a is the life fade.
uniform float time = 0.0;
uniform float intensity = 1.0;

varying float v_h;
varying float v_u;
varying float v_seed;
varying float v_life;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float scale = max(INSTANCE_CUSTOM.y,0.001);
	vec3 lean = vec3(INSTANCE_CUSTOM.z,0.0,INSTANCE_CUSTOM.w);
	v_seed = phase;
	v_life = COLOR.a;
	v_h = 1.0-UV.y;
	v_u = (UV.x-0.5)*2.0;
	// Y-locked billboard: a flame leans with the wind, never with the camera.
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 front = INV_VIEW_MATRIX[3].xyz-center;
	front.y = 0.0;
	front = length(front) > 0.0001 ? normalize(front) : vec3(0.0,0.0,1.0);
	vec3 up = vec3(0.0,1.0,0.0);
	vec3 right = normalize(cross(up,front));
	float h = v_h;
	float t = time+phase*31.0;
	// Two sines: a slow body sway and a faster tip lick.
	float sway = sin(t*2.6+h*3.4)*0.10+sin(t*5.9+h*7.1+phase*9.0)*0.055;
	float stretch = 1.0+0.20*sin(t*4.3+phase*17.0);
	float taper = mix(1.0,0.30,h*h);
	// Every tongue is its own width, or a cell grid reads as a picket fence.
	float wide = 0.60+0.85*fract(phase*7.13);
	vec2 bend = vec2(dot(lean,right),dot(lean,front));
	VERTEX = vec3(
		(VERTEX.x*taper*wide+sway*h*h)*scale+bend.x*h*h*scale,
		h*scale*stretch,
		bend.y*h*h*scale);
	MODELVIEW_MATRIX = VIEW_MATRIX*mat4(vec4(right,0.0),vec4(up,0.0),vec4(front,0.0),vec4(center,1.0));
}

void fragment() {
	float h = clamp(v_h,0.0,1.0);
	// Teardrop: a broad foot, the widest point a third of the way up, a point.
	float body = pow(max(0.0,1.0-h),0.55)*(0.45+1.05*h);
	// A soft radial falloff, not a hard silhouette: the noise cuts the shape.
	float mask = (1.0-smoothstep(0.12,1.0,abs(v_u)/max(body,0.05)))*smoothstep(0.0,0.12,h);
	// Two scrolling noise fields, the fine one faster, so the tongue boils.
	float coarse = zs_fire_fbm(vec2(v_u*1.1+v_seed*13.0,h*2.1-time*1.6+v_seed*7.0));
	float fine = zs_fire_fbm(vec2(v_u*3.2-v_seed*5.0,h*5.4-time*3.2+v_seed*3.0));
	float turb = coarse*0.65+fine*0.35;
	// Erosion, not tinting: where the noise is thin the tongue is simply gone,
	// which is what separates licking flames from an orange blob.
	float flame = clamp(mask*(0.10+1.55*turb)-h*0.22,0.0,1.0);
	// black -> red -> orange -> pale yellow core.
	vec3 color = vec3(0.34,0.015,0.0);
	color = mix(color,vec3(0.92,0.10,0.005),smoothstep(0.04,0.32,flame));
	color = mix(color,vec3(1.0,0.34,0.02),smoothstep(0.30,0.64,flame));
	color = mix(color,vec3(1.0,0.84,0.46),smoothstep(0.80,1.0,flame));
	ALBEDO = color*intensity;
	// Add-blending stacks: one quad must stay dim or a dense front goes white.
	ALPHA = clamp(smoothstep(0.02,0.20,flame)*0.29*v_life,0.0,1.0);
}
