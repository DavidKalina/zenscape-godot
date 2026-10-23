shader_type spatial;
// The endless flight's birds (scripts/endless/endless_birds.gd): one
// MultiMesh of a unit bird (span 1, faces -z), each instance's wings posed
// from its custom data: x the inner wing's angle up (rad), y the outer
// wing's bend on it, z how spread (0 tucked, 1 open), w a warm tint.
render_mode cull_disabled, specular_disabled;

const float SHOULDER = 0.055;
const float ELBOW = 0.27;

varying float tint;

void vertex() {
	tint = INSTANCE_CUSTOM.w;
	float ax = abs(VERTEX.x);
	if (ax > SHOULDER) {
		float side = sign(VERTEX.x);
		float a1 = INSTANCE_CUSTOM.x;
		float a2 = a1+INSTANCE_CUSTOM.y;
		float spread = INSTANCE_CUSTOM.z;
		float d = ax-SHOULDER;
		float d1 = min(d,ELBOW-SHOULDER);
		float d2 = max(d-(ELBOW-SHOULDER),0.0);
		vec2 open = vec2(cos(a1),sin(a1))*d1+vec2(cos(a2),sin(a2))*d2;
		// Tucked: laid back along the flank, a little over the back.
		vec3 tucked = vec3(SHOULDER+d*0.1,VERTEX.y+0.02+d*0.04,VERTEX.z+d*0.62);
		vec3 spread_at = vec3(SHOULDER+open.x,VERTEX.y+open.y,VERTEX.z);
		vec3 p = mix(tucked,spread_at,spread);
		VERTEX = vec3(side*p.x,p.y,p.z);
		float a = d2 > 0.0 ? a2 : a1;
		vec3 n_open = vec3(-side*sin(a),cos(a),0.0);
		NORMAL = normalize(mix(vec3(side,0.25,0.0),n_open,spread));
	}
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c,c*vec3(1.45,1.2,0.85)+vec3(0.025,0.015,0.0),tint);
	ROUGHNESS = 0.85;
	// Thin feathers let a little light through from behind.
	BACKLIGHT = vec3(0.12,0.1,0.08);
}
