shader_type spatial;
// Written by art/blender/train/train_build.py: the headlamp's lens, lit.
render_mode unshaded, shadows_disabled;
void fragment() {
	ALBEDO = COLOR.rgb * 1.6;
}
