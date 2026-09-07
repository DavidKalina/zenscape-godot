shader_type canvas_item;
render_mode unshaded;
#include "res://shaders/reference_wind.gdshaderinc"
uniform sampler2D surface_depth : repeat_disable, filter_nearest;
uniform vec3 origins[64];
uniform vec4 motion[64];
uniform int particle_count = 0;
uniform float rise_height = 1.0;
uniform vec3 camera_origin;
uniform mat3 world_to_view;
uniform vec2 camera_planes;
uniform vec2 projection_scale;
uniform vec2 viewport_size;
void fragment() {
	vec2 depth_sample = texture(surface_depth,SCREEN_UV).rg;
	float scene_depth = depth_sample.r > 0.0 ? camera_planes.x*camera_planes.y/(camera_planes.x+depth_sample.r*(camera_planes.y-camera_planes.x)) : camera_planes.y;
	float alpha = 0.0;
	for (int i=0;i<64;i++) {
		if (i>=particle_count) break;
		vec4 data = motion[i];
		float p = fract(zs_motion_time*0.16+data.z);
		float air = zs_wind_at(origins[i].xz);
		vec3 position = origins[i];
		position.xz += data.xy*p+zs_wind_direction*(air*p*0.9);
		position.y += (1.0-(1.0-p)*(1.0-p))*rise_height*(1.0+0.35*air);
		vec3 view = world_to_view*(position-camera_origin);
		float distance = -view.z;
		if (distance < camera_planes.x || distance > camera_planes.y) continue;
		vec2 center = vec2(0.5)+vec2(view.x,-view.y)/(distance*projection_scale)*0.5;
		float diameter = (14.0+p*46.0)*data.w*30.0/distance;
		vec2 point = (SCREEN_UV-center)*viewport_size/diameter;
		float feather = smoothstep(0.5,0.08,length(point));
		float opacity = feather*smoothstep(0.0,0.15,p)*(1.0-smoothstep(0.45,1.0,p))
			*smoothstep(0.5,1.0,zs_water_growth)*(1.0-zs_ice*0.9)*mix(0.18,1.0,zs_daylight)*0.3;
		if (distance > scene_depth) opacity *= 1.0-depth_sample.g;
		alpha = opacity+alpha*(1.0-opacity);
	}
	COLOR = vec4(0.88,0.95,0.97,alpha);
}
