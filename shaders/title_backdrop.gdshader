shader_type canvas_item;
render_mode unshaded;
// The live world behind the title cards, dimmed and softened as the design's
// backdrop filter: the main menu blur(2px) brightness(.72), world select
// brightness(.82) (scripts/title_cards.gd).
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float brightness = 0.72;
uniform float blur = 2.0;

void fragment() {
	vec3 c;
	if (blur > 0.05) {
		float lod = log2(max(blur,1.0));
		vec2 step = SCREEN_PIXEL_SIZE*blur*0.75;
		c = textureLod(screen_texture,SCREEN_UV,lod).rgb*0.4;
		c += textureLod(screen_texture,SCREEN_UV+vec2(step.x,step.y),lod).rgb*0.15;
		c += textureLod(screen_texture,SCREEN_UV+vec2(-step.x,step.y),lod).rgb*0.15;
		c += textureLod(screen_texture,SCREEN_UV+vec2(step.x,-step.y),lod).rgb*0.15;
		c += textureLod(screen_texture,SCREEN_UV-step,lod).rgb*0.15;
	} else {
		c = textureLod(screen_texture,SCREEN_UV,0.0).rgb;
	}
	COLOR = vec4(c*brightness,1.0);
}
