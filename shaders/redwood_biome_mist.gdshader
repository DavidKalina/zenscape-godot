shader_type fog;
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform sampler2D tree_cover : filter_linear, repeat_disable;
uniform float mist_time = 0.0;
uniform float amount = 1.0;
void fog() {
 vec3 p = WORLD_POSITION;
 vec2 uv = (p.xz+16.0)/32.0;
 float ground = zs_surface_height(texture(ground_map,uv),texture(stream_map,uv));
 float h = p.y-ground;
 float cover = texture(tree_cover,uv).r;
 float edge = 1.0-smoothstep(12.0,15.0,max(abs(p.x),abs(p.z)));
 float density = 0.0;
 if (cover>0.01 && h>=-0.1 && ground>-100.0) {
  density = 0.008*cover;
  if (h<2.7) {
   float pockets = smoothstep(0.27,0.60,wxFbm(vec3(p.x*0.28,2.7,p.z*0.28)));
   float low = exp(-max(h,0.0)*1.3)*(1.0-smoothstep(1.1,2.0,h));
   vec3 q = p*vec3(0.65,1.1,0.65)-vec3(mist_time*0.04,mist_time*0.24,0.0);
   float wisps = smoothstep(0.38,0.66,wxFbm(q));
   float rise = smoothstep(0.1,0.6,h)*(1.0-smoothstep(1.0,2.7,h));
   density += cover*pockets*(0.72*low+0.28*wisps*rise);
  }
 }
 DENSITY = density*amount*edge;
 ALBEDO = vec3(0.76,0.84,0.78);
 EMISSION = vec3(0.0);
}
