#ifndef ZS_SKY_OBJECTS
#define ZS_SKY_OBJECTS
// What the sky's real objects (scripts/sky_objects.gd) share: where a room
// direction lands, and how much of it the clouds, the horizon ridges and the
// moon leave showing. They draw after the dome, so anything the dome lays
// over its own stars has to be asked here instead.
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/sky_ridges.gdshaderinc"
// The cloud sea's veil (zs_sea_open), with its strength copied like the ridges'.
#include "res://shaders/sky_cloud_sea.gdshaderinc"

// The look pass's ridges, copied from the sky material.
uniform float horizon_ridges = 0.0;
uniform float horizon_seed = 0.0;
uniform float horizon_relief = 1.0;
// How far out the objects sit: inside the camera's far plane (500), well
// beyond anything on the plate, so they read as at infinity.
uniform float sky_distance = 420.0;

// A room direction in the world: turned by the room's yaw, the inverse of
// zsRoomDir (shaders/reference_sky_common.gdshaderinc).
vec3 zs_world_from_room(vec3 room) {
  float c = cos(zs_room_yaw);
  float s = sin(zs_room_yaw);
  return vec3(c * room.x + s * room.z, room.y, -s * room.x + c * room.z);
}

// A world direction as the room sees it: zsRoomDir, which sits in an
// include the spatial shaders can't take whole.
vec3 zs_room_from_world(vec3 dir) {
  float c = cos(zs_room_yaw);
  float s = sin(zs_room_yaw);
  return vec3(c * dir.x - s * dir.z, dir.y, s * dir.x + c * dir.z);
}

// The share of light the cloud deck lets through along `rd` from `ro`: the
// same slab, field and extinction as zs_cloud_march
// (shaders/reference_cloud_march.gdshaderinc), without the lighting.
float zs_cloud_transmit(vec3 ro, vec3 rd) {
  if (abs(rd.y) < 0.002 || zs_cloud.x < 0.001) return 1.0;
  float ta = (zs_cloud.z - ro.y) / rd.y;
  float tb = (zs_cloud.z + zs_cloud.w - ro.y) / rd.y;
  float enter = max(min(ta, tb), 0.0);
  float leave = min(max(ta, tb), 900.0);
  if (leave <= enter) return 1.0;
  const int STEPS = 10;
  float step_length = max((leave - enter) / float(STEPS), zs_cloud.w * 0.085);
  float t = enter + step_length * 0.5;
  float trans = 1.0;
  for (int i = 0; i < STEPS; i++) {
    if (trans < 0.02 || t > leave) break;
    trans *= exp(-cloudAt(ro + rd * t) * step_length * 0.09);
    t += step_length;
  }
  return 1.0 - (1.0 - trans) * smoothstep(0.0, 0.11, abs(rd.y));
}

// 1 where the ridges leave the world direction `dir` open, 0 behind them.
float zs_ridge_open(vec3 dir, vec3 room) {
  float y = dir.y;
  if (horizon_ridges <= 0.0 || y <= -0.14 || y >= 0.12) return 1.0;
  vec2 around = normalize(room.xz + 1e-5);
  float below = smoothstep(-0.14, -0.04, y);
  float open = 1.0;
  for (int k = 0; k < 3; k++) {
    float top = zs_ridge_top(around, float(k), horizon_seed, horizon_relief);
    open *= 1.0 - smoothstep(top + 0.0015, top - 0.0015, y) * below * horizon_ridges;
  }
  return open;
}

// 1 away from the moon's disc, 0 inside it, by `margin` radians.
float zs_moon_open(vec3 dir, float margin) {
  float vis = zs_celestial_clear * smoothstep(-0.04, 0.03, zs_moon_direction.y);
  float ang = sqrt(max(2.0 * (1.0 - dot(dir, zs_moon_direction)), 0.0));
  return 1.0 - vis * (1.0 - smoothstep(0.024, 0.024 + margin, ang));
}
#endif
