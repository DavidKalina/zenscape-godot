shader_type spatial;
// A push-up orb's ball (scripts/burrower/push_ups.gd): lit, and glowing the same
// all over while it hangs (`moving` 0). Going up or down hard (`moving` to 1) its
// edge falls off to amber, so it reads as a ball on the move and not a flat disc.

instance uniform float moving = 0.0;
uniform vec3 albedo : source_color;
uniform vec3 glow : source_color;
uniform float energy = 3.2;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float limb = mix(1.0, mix(0.25, 1.0, facing * facing), moving);
	ALBEDO = albedo * limb;
	ROUGHNESS = 0.35;
	EMISSION = glow * energy * limb;
}
