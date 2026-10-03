#ifndef ZS_SKY_PLANET
#define ZS_SKY_PLANET
// The planet (scripts/sky_objects.gd): a faceted body, a soft atmosphere and
// thin rings, sharing where it hangs and how much of it shows.
#include "res://shaders/sky_objects.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

// The room direction of its centre, its angular radius in radians, and its
// axes in the room (y is the pole the rings circle).
uniform vec3 planet_direction = vec3(0.0, 0.0, 1.0);
uniform float planet_radius = 0.05;
uniform mat3 planet_frame = mat3(1.0);

vec3 zs_planet_centre(vec3 camera) {
  return camera + zs_world_from_room(normalize(planet_direction)) * sky_distance;
}
float zs_planet_world_radius() {
  return planet_radius * sky_distance;
}
mat3 zs_planet_axes() {
  return mat3(zs_world_from_room(planet_frame[0]), zs_world_from_room(planet_frame[1]), zs_world_from_room(planet_frame[2]));
}
// How strongly it shows along `dir` before lighting: whole at night, a pale
// ghost by day, thinned toward the void and behind weather and ridges.
float zs_planet_presence(vec3 dir, vec3 room) {
  return zs_celestial_clear * smoothstep(-0.75, -0.45, dir.y) * zs_ridge_open(dir, room);
}
// Where a sky direction strikes the planet's sphere from `camera`, as the
// distance along it, or -1.
float zs_planet_hit(vec3 camera, vec3 dir) {
  vec3 oc = camera - zs_planet_centre(camera);
  float b = dot(oc, dir);
  float r = zs_planet_world_radius();
  float disc = b * b - (dot(oc, oc) - r * r);
  if (disc < 0.0) return -1.0;
  return -b - sqrt(disc);
}
#endif
