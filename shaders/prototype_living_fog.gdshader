shader_type fog;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform float bank_density = 0.7;
uniform float bank_height = 5.0;
uniform float activity = 0.0;
uniform float bank_clock = 0.0;
uniform vec3 bank_color = vec3(0.76,0.83,0.9);
void fog() {
	vec3 p = WORLD_POSITION;
	vec2 uv = (p.xz+16.0)/32.0;
	float ground = zs_surface_height(texture(ground_map,uv),texture(stream_map,uv));
	// Transport the entire bank envelope, not just detail inside a fixed cloud.
	vec2 air = p.xz-zs_wind_offset;
	vec3 q = vec3(air.x*0.20,p.y*0.32,air.y*0.20);
	q.y += bank_clock*0.025;
	float noise = wxFbm(q)*0.72+wxFbm2(q*2.1+vec3(6.2,3.1,9.3))*0.28;
	float along = dot(air,zs_wind_direction);
	float across = dot(air,vec2(-zs_wind_direction.y,zs_wind_direction.x));
	float front = sin(along*0.43+1.9*wxNoise(vec3(across*0.22,p.y*0.12,along*0.075)));
	float parcel = smoothstep(-0.30,0.65,front);
	float puff;
	float gust = zs_gust_parts_at(p.xz,zs_gust_distance,puff);
	float keep = smoothstep(0.29,0.57,noise)*parcel;
	keep *= 1.0-activity*0.65*smoothstep(0.5,0.95,gust);
	keep *= 1.0-smoothstep(0.10,0.6,puff)*0.82;
	float expansion = activity*2.2;
	float top = 0.8+bank_height+(noise-0.45)*bank_height*0.9-(1.0-parcel)*bank_height*0.65;
	float body = (1.0-smoothstep(top-1.4,top+1.3,p.y))*smoothstep(ground-0.1,ground+0.4,p.y);
	float edge = (1.0-smoothstep(12.0,16.0+expansion,abs(p.x)))*(1.0-smoothstep(12.0,16.0+expansion,abs(p.z)));
	float boundary = 1.0-smoothstep(-0.8,0.0,SDF);
	DENSITY = ground < -100.0 ? 0.0 : bank_density*keep*body*edge*boundary;
	ALBEDO = bank_color;
	EMISSION = bank_color*0.20;
}
