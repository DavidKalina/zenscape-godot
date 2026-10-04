shader_type spatial;
// The planet's atmosphere as soft light round its disc: a camera-facing card
// that glows just past the limb, brightest on the side the sun reaches.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/sky_planet.gdshaderinc"

// How far the card reaches, in planet radii.
const float REACH = 1.6;
varying vec3 world;

void vertex() {
  vec3 centre = zs_planet_centre(CAMERA_POSITION_WORLD);
  world = centre + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * zs_planet_world_radius() * REACH;
  POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
  vec3 view = normalize(world - CAMERA_POSITION_WORLD);
  vec3 centre_dir = zs_world_from_room(normalize(planet_direction));
  // Angular distance from the centre, in planet radii.
  float x = sqrt(max(2.0 * (1.0 - dot(view, centre_dir)), 0.0)) / planet_radius;
  // The sun's side, seen across the sky from the centre.
  vec3 across = view - centre_dir * dot(view, centre_dir);
  vec3 sun_across = zs_sun_direction - centre_dir * dot(zs_sun_direction, centre_dir);
  float side = smoothstep(-0.5, 0.8, dot(normalize(across + 1e-6), normalize(sun_across + 1e-6)));
  float presence = zs_planet_presence(view, zs_room_from_world(view)) * mix(0.25, 1.0, zs_night);
  // Its colour and reach are the night style's (zs_night_planet_glow).
  vec3 glow = x < REACH ? zs_night_planet_glow(x, side) : vec3(0.0);
  ALBEDO = scene_linear_for_display(clamp(glow * presence, 0.0, 1.0));
}
