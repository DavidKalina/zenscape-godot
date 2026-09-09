shader_type fog;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform float bank_density = 0.7;
uniform float bank_height = 5.0;
uniform float coverage = 1.0;
uniform float activity = 0.0;
uniform float bank_clock = 0.0;
uniform vec3 bank_color = vec3(0.76,0.83,0.9);
void fog() {
	vec3 p = WORLD_POSITION;
	vec2 uv = (p.xz+16.0)/32.0;
	float ground = zs_surface_height(texture(ground_map,uv),texture(stream_map,uv));
	// Integrated wind travel keeps the cloud continuous when typing pace changes.
	vec3 q = p*vec3(0.17,0.26,0.17)-vec3(zs_wind_offset.x,0.0,zs_wind_offset.y)*0.095;
	q.y += bank_clock*0.016;
	float noise = wxFbm(q)*0.72+wxFbm2(q*2.1+vec3(6.2,3.1,9.3))*0.28;
	float puff;
	float gust = zs_gust_parts_at(p.xz,zs_gust_distance,puff);
	float along = dot(p.xz,zs_wind_direction)/14.0;
	float tear = 4.0*coverage*(1.0-coverage);
	float local_cover = clamp(coverage+tear*(0.13*along-0.45*(gust-0.5)),0.0,1.0);
	float keep = smoothstep(0.43-local_cover*0.27,0.60-local_cover*0.25,noise);
	keep *= 1.0-activity*0.65*smoothstep(0.5,0.95,gust);
	keep *= 1.0-smoothstep(0.10,0.6,puff)*0.82;
	float expansion = activity*2.2;
	float top = 0.8+bank_height+(noise-0.45)*bank_height*0.7;
	float body = (1.0-smoothstep(top-1.4,top+1.3,p.y))*smoothstep(ground-0.1,ground+0.4,p.y);
	float edge = 1.0-smoothstep(10.0,14.0+expansion,length(p.xz*vec2(0.9,1.0)));
	float boundary = 1.0-smoothstep(-0.8,0.0,SDF);
	DENSITY = ground < -100.0 ? 0.0 : bank_density*local_cover*keep*body*edge*boundary;
	ALBEDO = bank_color;
	EMISSION = bank_color*0.20;
}
