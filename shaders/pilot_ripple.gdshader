shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, shadows_disabled, cull_disabled;
// The pilot's ripples (scripts/pilot_ripples.gd): flat faceted rings on the
// water, laid out here from their instance data (x the reach, y the width,
// z the age 0 to 1, w 1 while it lives), pale and softly lit by the sky as
// the folk are, a touch brighter while young. Never see-through: a ring
// thins away instead of fading.
global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;

uniform vec3 tint : source_color = vec3(0.86, 0.93, 0.96);
uniform float fill = 1.4;

varying float age;

void vertex() {
	vec4 data = INSTANCE_CUSTOM;
	float reach = data.x + UV.x * data.y;
	VERTEX = vec3(VERTEX.x * reach, 0.0, VERTEX.z * reach) * data.w;
	age = data.z;
}

void fragment() {
	ALBEDO = tint * mix(1.08, 0.94, age);
	ROUGHNESS = 1.0;
	EMISSION = ALBEDO * zs_hemi_sky * zs_hemi_energy * fill / PI;
}
