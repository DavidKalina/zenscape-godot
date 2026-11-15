shader_type particles;
// The whale's tell: a blow of mist (scripts/endless/whale_home.gd), drawn by
// shaders/water_spray.gdshader (kind 1). A short burst thrown up at once,
// slow sprites small and low, fast ones big and high, so it is a narrow jet
// at the foot opening into a plume. The wind shears it off with height. The
// low sprites fade first and each fades in thin, so it thins from the
// bottom up. CUSTOM: x spin, y age (0 to 1), z the sprite's rank (0 low, 1
// high), w size (m).

uniform float rate = 1.0;
uniform vec3 ahead = vec3(0.0, 0.0, -1.0);
uniform vec3 right = vec3(1.0, 0.0, 0.0);
uniform vec2 up_speed = vec2(12.0, 50.0);
uniform float side_speed = 3.0;
uniform vec2 size_range = vec2(3.0, 9.0);
uniform float growth = 3.0;
uniform float drag = 0.4;
uniform float gravity = 0.4;
// Down the wind: pushed this hard (m/s²) at `shear_over` m up, less below.
uniform float shear = 1.5;
uniform float shear_over = 90.0;
uniform float water_y = -40.0;

float hash(uint n) {
	n = (n << 13u) ^ n;
	n = n * (n * n * 15731u + 789221u) + 1376312589u;
	return float(n & 0x7fffffffu) / float(0x7fffffff);
}

void start() {
	uint s = NUMBER * 7919u + RANDOM_SEED * 104729u + INDEX * 31u;
	if (hash(s) > rate) {
		ACTIVE = false;
	} else {
		float rank = hash(s + 6u);
		vec3 at = EMISSION_TRANSFORM[3].xyz;
		float a = hash(s + 5u) * 6.2832;
		float across = hash(s + 7u);
		vec3 v = vec3(0.0, 1.0, 0.0) * mix(up_speed.x, up_speed.y, rank);
		v += (right * cos(a) + ahead * sin(a)) * side_speed * rank * across;
		VELOCITY = v;
		float size = mix(size_range.x, size_range.y, rank) * mix(0.6, 1.3, hash(s + 10u));
		CUSTOM = vec4(hash(s + 11u) * 6.2832, 0.0, rank, size);
		COLOR = vec4(1.0);
		TRANSFORM = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(at, 1.0));
	}
}

void process() {
	uint s = NUMBER * 7919u + RANDOM_SEED * 104729u + INDEX * 31u;
	float rank = CUSTOM.z;
	CUSTOM.y += DELTA / max(LIFETIME, 0.001);
	float up = clamp((TRANSFORM[3].y - water_y) / shear_over, 0.0, 1.0);
	VELOCITY += ahead * shear * up * up * DELTA;
	VELOCITY.y -= gravity * DELTA;
	VELOCITY *= exp(-drag * DELTA);
	// The low ones go first.
	float end = mix(0.5, 1.0, rank);
	float u = CUSTOM.y / end;
	if (u >= 1.0) ACTIVE = false;
	float size = CUSTOM.w * (1.0 + growth * min(CUSTOM.y, 1.0));
	TRANSFORM[0] = vec4(size, 0.0, 0.0, 0.0);
	TRANSFORM[1] = vec4(0.0, size, 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, size, 0.0);
	float vary = mix(0.25, 1.0, hash(s + 12u));
	COLOR.a = vary * smoothstep(0.0, 0.07, u) * (1.0 - smoothstep(0.3, 1.0, u));
}
