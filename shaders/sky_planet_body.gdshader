shader_type spatial;
// The planet's body: a smooth sphere lit by the real sun, so its terminator
// follows the day and it hangs as a lit crescent or a full disc. Its face is
// the night style's (zs_night_planet_body).
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
#include "res://shaders/sky_planet.gdshaderinc"

varying vec3 local;
varying vec3 world;
varying float clouds;

void vertex() {
  // A slow turn on its pole, so the band detail drifts.
  float spin = zs_motion_time * 0.004;
  local = mat3(vec3(cos(spin), 0.0, -sin(spin)), vec3(0.0, 1.0, 0.0), vec3(sin(spin), 0.0, cos(spin))) * VERTEX;
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  world = centre + zs_planet_axes() * VERTEX * zs_planet_world_radius();
  clouds = zs_cloud_transmit(CAMERA_POSITION_WORLD, normalize(world - CAMERA_POSITION_WORLD));
  POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
  vec3 view = normalize(world - CAMERA_POSITION_WORLD);
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  // Lit round, not per facet: faceted, it read as a mirror ball.
  vec3 radial = normalize(world - centre);
  // Its face is the night style's (shaders/night_sky.gdshaderinc).
  vec4 face = zs_night_planet_body(normalize(local), radial, view, zs_sun_direction);
  // The rings' shadow: where the way from here to the sun crosses the ring
  // plane, the style's own ring dust there dims the light.
  mat3 axes = zs_planet_axes();
  float sun_up = dot(zs_sun_direction, axes[1]);
  float up = dot(radial, axes[1]);
  if (abs(sun_up) > 0.001 && up * sun_up < 0.0) {
    vec3 cross_at = radial - zs_sun_direction * (up / sun_up);
    vec3 ring = vec3(dot(cross_at, axes[0]), 0.0, dot(cross_at, axes[2]));
    float r = length(ring.xz);
    float dust = zs_night_planet_rings(ring, fwidth(r), 1.0, 1.0).a;
    float facing = smoothstep(-0.05, 0.3, dot(radial, zs_sun_direction));
    face.rgb *= 1.0 - 0.7 * clamp(dust / 0.7, 0.0, 1.0) * facing;
  }
  // A clean, antialiased limb: fade over the last pixel or so of the disc,
  // where the sphere's edge would otherwise stair-step.
  float mu = dot(radial, -view);
  float edge = clamp(mu / max(fwidth(mu) * 1.5, 1e-5), 0.0, 1.0);
  vec3 room = zs_room_from_world(view);
  float presence = zs_planet_presence(view, room) * clouds;
  ALBEDO = scene_linear_for_display(clamp(face.rgb, 0.0, 1.0));
  ALPHA = presence * mix(face.a, 1.0, zs_night) * edge;
}
