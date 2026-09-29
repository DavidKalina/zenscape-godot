shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;
// The outline round a hovered tree (scripts/tree_outline.gd): the tree's parts
// drawn back-faced and pushed `width` pixels out along their smoothed normals
// on screen, so only a rim shows past the tree itself.
uniform vec3 colour : source_color = vec3(1.0, 0.76, 0.24);
uniform float width = 2.5;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 out_dir = (PROJECTION_MATRIX * vec4(normal, 0.0)).xy;
	float l = length(out_dir);
	if (l > 1e-5) out_dir /= l;
	clip.xy += out_dir * width * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = colour;
}
