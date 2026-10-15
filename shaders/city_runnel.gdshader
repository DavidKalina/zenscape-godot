shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The oil runnel (scripts/city_kit_fires.gd `Runnel`): a carved channel of
// glossy black resin on a wall or a floor, and the flame running it. A
// strip laid along the runnel's line: UV.x the length (m) from its head,
// UV.y 0..1 across. Unlit, it is a dark groove, glossy down the middle,
// its cut walls shadowed. Lit, everything up to `front` burns: a bright
// tongue at the front, then a churning orange that settles over
// `afterglow` s to a low ember glow (`ember`) the resin keeps, so the line
// it ran (and the holds beside it) stays readable. No geometry: a few
// hundred pixels.
#include "res://shaders/fire_noise.gdshaderinc"

// How far (m) the flame has run (under 0: never lit), its speed (m/s).
uniform float front = -1.0;
uniform float speed = 3.0;
uniform float afterglow = 4.0;
uniform float ember = 0.3;
uniform float time = 0.0;
uniform vec3 resin : source_color = vec3(0.045,0.036,0.03);
uniform vec3 cut : source_color = vec3(0.02,0.018,0.016);

void fragment() {
	float x = UV.x;
	float across = abs(UV.y-0.5)*2.0;
	// The groove: its cut walls dark and rough, the resin glossy between.
	float wall = smoothstep(0.55,0.95,across);
	float crust = zs_fire_fbm(vec2(x*3.1,UV.y*2.0));
	ALBEDO = mix(resin*(0.75+0.5*crust),cut,wall);
	ROUGHNESS = mix(0.22+0.25*crust,0.85,wall);
	SPECULAR = 0.6;
	if (front >= 0.0 && x <= front) {
		float behind = front-x;
		float age = behind/max(speed,0.01);
		float fresh = exp(-age*2.2/max(afterglow,0.01));
		float churn = zs_fire_fbm(vec2(x*2.2-time*1.9,UV.y*3.0+time*0.6));
		float lit = mix(ember*(0.7+0.6*churn),1.0,fresh)*(0.55+0.9*churn);
		float lip = 1.0-smoothstep(0.45,1.0,across);
		vec3 hot = mix(vec3(0.55,0.05,0.005),vec3(1.0,0.4,0.06),clamp(lit,0.0,1.0));
		// The running tongue: white-gold at the very front.
		float head = exp(-behind*1.6);
		hot += vec3(1.0,0.78,0.42)*head*1.8;
		EMISSION = hot*lit*lip*2.6;
		ALBEDO *= 1.0-0.6*lip*fresh;
	}
}
