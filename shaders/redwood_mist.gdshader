shader_type fog;
#include "res://shaders/reference_cloud_field.gdshaderinc"
uniform float mist_time = 0.0;
uniform float amount = 1.0;
uniform float floor_pockets = 1.0;
void fog() {
 vec3 p = WORLD_POSITION;
 float ground = 0.24*sin(p.x*0.31)*cos(p.z*0.25)+0.10*sin(p.z*0.65);
 float h = p.y-ground;
 // Upward advection changes the shape continuously instead of lifting a sheet.
 vec3 q = p*vec3(0.42,0.72,0.42)-vec3(mist_time*0.025,mist_time*0.11,0.0);
 float cloud = smoothstep(0.32,0.70,wxFbm(q));
 float pool = exp(-max(h,0.0)*0.82);
 float dissolve = 1.0-smoothstep(1.2,4.5,h);
 float edge = 1.0-smoothstep(19.0,24.0,abs(p.x));
 float path = abs(p.x-sin(p.z*0.14));
 float clearing = mix(0.22,1.0,smoothstep(0.6,2.2,path));
 float pockets = smoothstep(0.27,0.60,wxFbm(vec3(p.x*0.28,2.7,p.z*0.28)));
 float low = exp(-max(h,0.0)*1.3)*(1.0-smoothstep(1.1,2.0,h));
 vec3 rising_q = p*vec3(0.65,1.1,0.65)-vec3(mist_time*0.04,mist_time*0.24,0.0);
 float wisps = smoothstep(0.38,0.66,wxFbm(rising_q));
 float rise = smoothstep(0.1,0.6,h)*(1.0-smoothstep(1.0,2.7,h));
 float floor_density = clearing*pockets*(0.72*low+0.28*wisps*rise);
 float local_density = mix(0.21*cloud*pool*dissolve,floor_density,floor_pockets);
 DENSITY = h < -0.1 ? 0.0 : amount*edge*(0.008+local_density);
 ALBEDO = vec3(0.76,0.84,0.78);
 EMISSION = vec3(0.0);
}
