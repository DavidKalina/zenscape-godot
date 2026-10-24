shader_type spatial;
// The endless flight's songbirds (scripts/endless/endless_birds.gd): the
// isles' songbirds (scripts/songbird_body.gd's meshes, vertex-coloured,
// smooth) drawn as MultiMeshes. Like shaders/songbird.gdshader without the
// perch ride, with a wrapped light and a little light through the feathers,
// so a bird's shaded side keeps its colour against the land's lit crowns.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform float bird_roughness = 0.92;
// Light let through from behind (thin feathers), and the shaded side's lift.
uniform float backlight = 0.45;
uniform float fill = 0.18;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = bird_roughness;
	BACKLIGHT = COLOR.rgb * backlight;
	EMISSION = COLOR.rgb * fill * 0.25;
}
