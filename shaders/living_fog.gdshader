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
// Over open water the bank thins by this share and lifts its floor by
// water_lift metres, so ponds read clear and reflective under a misty plain.
uniform float water_clear = 0.85;
uniform float water_lift = 1.4;

float open_water_at(vec2 xz) {
	vec2 uv = (xz+16.0)/32.0;
	return zs_open_water(texture(ground_map,uv),texture(stream_map,uv));
}

void fog() {
	vec3 p = WORLD_POSITION;
	vec2 uv = (p.xz+16.0)/32.0;
	float ground = zs_surface_height(texture(ground_map,uv),texture(stream_map,uv));
	// Five taps soften the nearest-filtered map's edge into a fade at the shore.
	float water = (open_water_at(p.xz)*2.0+open_water_at(p.xz+vec2(1.2,0.0))+open_water_at(p.xz-vec2(1.2,0.0))
		+open_water_at(p.xz+vec2(0.0,1.2))+open_water_at(p.xz-vec2(0.0,1.2)))/6.0;
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
	float top = 0.8+bank_height+(noise-0.45)*bank_height*0.9-(1.0-parcel)*bank_height*0.65;
	float lift = water*water_lift;
	float body = (1.0-smoothstep(top-1.4,top+1.3,p.y))*smoothstep(ground-0.1+lift,ground+0.4+lift*1.4,p.y)*(1.0-water_clear*water);
	// Only where the land is behind it (reference_cloud_field.gdshaderinc).
	float edge = zs_plate_keep(p,ground);
	float boundary = 1.0-smoothstep(-0.8,0.0,SDF);
	DENSITY = ground < -100.0 ? 0.0 : bank_density*keep*body*edge*boundary*zs_reveal_keep(p.xz);
	ALBEDO = bank_color;
	EMISSION = bank_color*0.20;
}
