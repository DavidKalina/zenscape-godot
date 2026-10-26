shader_type particles;
// Water thrown off the surface by the plane (scripts/endless/water_contact.gd):
// one shader for the rooster tail's drops, its mist and the bursts where a
// wingtip or the belly nearly touches. Spawned at the emitter (on the water
// under the plane), spread back along this frame's travel so a fast emitter
// leaves no gaps, thrown up and out in the plane's frame, then falling under
// gravity and air drag; gone under the water it came from. TRANSFORM carries
// the drawn size and, for streaks, the velocity's way (scaled by `stretch`),
// for shaders/water_spray.gdshader. CUSTOM: x spin, y age (0 to 1), z seed,
// w size (m).

// The share of slots that spawn (0 none: the emission's own rate times this).
uniform float rate = 0.0;
// The emitter's move this frame (m, world): spawns spread back along it.
uniform vec3 travel = vec3(0.0);
// The plane's flat forward and right (world, unit).
uniform vec3 ahead = vec3(0.0, 0.0, -1.0);
uniform vec3 right = vec3(1.0, 0.0, 0.0);
// The plane's speed (m/s); a share of it rides with the water (`carry`).
uniform float plane_speed = 0.0;
uniform vec2 carry = vec2(0.1, 0.3);
// Thrown up (m/s, min and max) and out to the sides (m/s; both sides), and
// back toward the plane's tail (m/s): times `strength`.
uniform vec2 up_speed = vec2(2.0, 8.0);
uniform vec2 side_speed = vec2(0.5, 4.0);
uniform vec2 back_speed = vec2(0.0, 2.0);
uniform float strength = 1.0;
// Spawned in a box this big (half extents, m: across, up, along).
uniform vec3 box = vec3(0.6, 0.05, 0.6);
// Size at birth (m, min and max), grown by `growth` times over its life.
uniform vec2 size_range = vec2(0.05, 0.14);
uniform float growth = 0.0;
// Air drag (per second), gravity (m/s²) and a rise for mist (m/s² up).
uniform float drag = 0.6;
uniform float gravity = 9.8;
uniform float buoyancy = 0.0;
// Streaks: drawn this many seconds of travel long (0: round).
uniform float stretch = 0.0;
// The water's level here (m): drops falling under it are gone.
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
		vec3 up = vec3(0.0, 1.0, 0.0);
		vec3 at = EMISSION_TRANSFORM[3].xyz;
		at += right * box.x * (hash(s + 1u) * 2.0 - 1.0);
		at += up * box.y * hash(s + 2u);
		at += ahead * box.z * (hash(s + 3u) * 2.0 - 1.0);
		at -= travel * hash(s + 4u);
		float side = hash(s + 5u) < 0.5 ? -1.0 : 1.0;
		vec3 v = up * mix(up_speed.x, up_speed.y, pow(hash(s + 6u), 1.5));
		v += right * side * mix(side_speed.x, side_speed.y, hash(s + 7u));
		v -= ahead * mix(back_speed.x, back_speed.y, hash(s + 8u));
		v *= strength;
		v += ahead * plane_speed * mix(carry.x, carry.y, hash(s + 9u));
		VELOCITY = v;
		float size = mix(size_range.x, size_range.y, hash(s + 10u));
		CUSTOM = vec4(hash(s + 11u) * 6.2832, 0.0, hash(s + 12u), size);
		COLOR = vec4(1.0);
		TRANSFORM = mat4(vec4(size, 0.0, 0.0, 0.0), vec4(0.0, size, 0.0, 0.0), vec4(0.0, 0.0, size, 0.0), vec4(at, 1.0));
	}
}

void process() {
	CUSTOM.y += DELTA / max(LIFETIME, 0.001);
	VELOCITY.y += (buoyancy - gravity) * DELTA;
	VELOCITY *= exp(-drag * DELTA);
	if (CUSTOM.y >= 1.0 || (TRANSFORM[3].y < water_y - 0.2 && VELOCITY.y < 0.0)) {
		ACTIVE = false;
	}
	float age = clamp(CUSTOM.y, 0.0, 1.0);
	float size = CUSTOM.w * (1.0 + growth * age);
	float speed = length(VELOCITY);
	vec3 way = speed > 0.01 ? VELOCITY / speed : vec3(0.0, 1.0, 0.0);
	TRANSFORM[0] = vec4(size, 0.0, 0.0, 0.0);
	TRANSFORM[1] = vec4(stretch > 0.0 ? way * (size + speed * stretch) : vec3(0.0, size, 0.0), 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, size, 0.0);
	// In fast, out slow.
	COLOR.a = smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.45, 1.0, age));
}
