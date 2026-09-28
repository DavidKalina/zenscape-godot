shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled, fog_disabled;
// The God Hand's first pass (scripts/god_hand.gd): no colour, only the
// nearest shell's depth, for shaders/god_hand.gdshader to draw on. Drawn in
// the transparent pass (it writes ALPHA), after the ground's depth has been
// copied for the ground marks, so a mark under the hand still reads the
// ground; the display fog's depth (studies/surface_depth.gd, copied after
// the transparent pass) sees the hand where it is instead of the ground
// behind it, which is what keeps the composite from repainting it as ground.
// Where the wrist has faded (or the whole hand is fading out) it writes
// nothing, so an invisible arm leaves no hole in the fog.

// Keep in step with the colour pass's hand_opacity.
uniform float hand_opacity : hint_range(0.0, 1.0) = 1.0;
// Below this share of wrist fade times opacity the shell lays no depth.
uniform float hand_depth_cut : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	if (COLOR.a * hand_opacity < hand_depth_cut) discard;
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
