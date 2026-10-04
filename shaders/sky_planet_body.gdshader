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
  vec3 room = zs_room_from_world(view);
  float presence = zs_planet_presence(view, room) * clouds;
  ALBEDO = scene_linear_for_display(clamp(face.rgb, 0.0, 1.0));
  // Opal's limb is antialiased over about a pixel.
  float edge = zs_night_style == 1 ? zs_opal_planet_edge(radial, view) : 1.0;
  ALPHA = presence * mix(face.a, 1.0, zs_night) * edge;
}
