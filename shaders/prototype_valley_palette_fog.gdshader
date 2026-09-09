shader_type fog;
#include "res://shaders/reference_cloud_field.gdshaderinc"
uniform vec3 cloud_tint = vec3(0.85,0.9,0.96);
uniform float cloud_glow = 0.28;
uniform float cloud_time = 0.0;
uniform float cloud_density = 0.30;
void fog() {
	vec3 p = WORLD_POSITION;
	vec3 local = p - OBJECT_POSITION;
	vec3 q = p * vec3(0.19,0.30,0.19) - vec3(cloud_time*0.055,0.0,cloud_time*0.022);
	float large = wxFbm(q);
	float detail = wxFbm2(q*2.1+vec3(6.2,3.1,9.3));
	float billow = large*0.7+detail*0.3;
	float band_center = (wxNoise(q*0.62+12.0)-0.5)*2.2;
	float vertical = 1.0-smoothstep(0.35,2.6,abs(local.y-band_center));
	float edge = 1.0-smoothstep(11.0,17.0,length(local.xz*vec2(0.85,1.05)));
	float broken = smoothstep(0.43,0.65,billow);
	DENSITY = cloud_density*broken*vertical*edge*(1.0-smoothstep(-0.7,0.0,SDF));
	ALBEDO = cloud_tint;
	EMISSION = cloud_tint*cloud_glow;
}
