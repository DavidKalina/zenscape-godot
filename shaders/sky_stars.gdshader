shader_type spatial;
// The stars as real points (scripts/sky_objects.gd): one camera-facing quad
// each, sized in screen pixels so a star stays a sharp point at any field of
// view and window size, out at the sky's distance round whichever camera
// draws them, so the water's mirror sees them too.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
#include "res://shaders/sky_objects.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

// Peak light, already in scene-linear and with every veil applied.
varying vec3 light;
// The quad's corner, in pixels from the star's centre.
varying vec2 offset;
varying float sigma;
varying float hero;
varying float halo;
varying float reach;

// Star colour by temperature, t in 0..1: hot blue-white through white
// and yellow to orange and a rare ember red. Weighted toward white.
vec3 star_tint(float t) {
  vec3 c = vec3(0.66, 0.77, 1.0);
  c = mix(c, vec3(0.94, 0.96, 1.0), smoothstep(0.14, 0.3, t));
  c = mix(c, vec3(1.0, 0.91, 0.76), smoothstep(0.55, 0.7, t));
  c = mix(c, vec3(1.0, 0.72, 0.46), smoothstep(0.84, 0.92, t));
  c = mix(c, vec3(1.0, 0.55, 0.34), smoothstep(0.97, 0.995, t));
  return c;
}

void vertex() {
  // Instance origin: the star's room direction. Custom: temperature,
  // brightness (display units; a hero star's is its HDR power), seed, hero.
  vec3 room = normalize(MODEL_MATRIX[3].xyz);
  vec3 dir = zs_world_from_room(room);
  float bright = INSTANCE_CUSTOM.y;
  float seed = INSTANCE_CUSTOM.z;
  hero = INSTANCE_CUSTOM.w;
  // Thinned toward the void under the slab, never cut at the horizon: the
  // camera looks down on the floating plate, so most of the sky it sees is
  // below the horizon line.
  float k = zs_night * zs_celestial_clear * smoothstep(-0.55, -0.2, dir.y);
  if (k > 0.001) k *= zs_ridge_open(dir, room) * zs_moon_open(dir, 0.004);
  if (k > 0.001) k *= zs_cloud_transmit(CAMERA_POSITION_WORLD, dir);
  if (k * bright < 0.002) {
    POSITION = vec4(2.0, 2.0, 2.0, 1.0);
  } else {
    // Scintillation: slow and small overhead, stronger where the air is
    // thick near the horizon line. A hero star's colour shifts as it does.
    float t = zs_motion_time;
    float scint = mix(0.1, 0.4, 1.0 - smoothstep(0.0, 0.6, abs(dir.y)));
    vec3 tw = vec3(1.0 + scint * sin(t * (0.7 + seed * 2.3) + seed * 40.0) * sin(t * (0.45 + seed) + seed * 9.0));
    if (hero > 0.5)
      tw = 1.0 + 0.3 * sin(t * (1.3 + seed) + seed * 17.0 + vec3(0.0, 0.8, 1.6)) * sin(t * (0.37 + seed * 0.2) + seed * 5.0);
    vec3 tint = star_tint(INSTANCE_CUSTOM.x);
    // Pixels at the reference 1080-line window.
    float px = VIEWPORT_SIZE.y / 1080.0;
    if (hero > 0.5) {
      // True HDR light that the glow picks up.
      light = tint * tw * bright * k / zs_exposure;
      sigma = 1.1 * px;
      halo = 1.0;
    } else {
      // Display light up to white, the overflow as HDR for the glow.
      vec3 peak = tint * tw * bright * k;
      light = scene_linear_for_display(min(peak, vec3(1.0))) + max(peak - 1.0, vec3(0.0)) * 0.5 / zs_exposure;
      sigma = mix(0.6, 1.0, smoothstep(0.2, 2.0, bright)) * px;
      halo = smoothstep(1.2, 2.4, bright);
    }
    reach = hero > 0.5 ? 18.0 * px : sigma * mix(3.5, 9.0, halo);
    offset = VERTEX.xy * reach;
    vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dir * sky_distance, 1.0));
    clip.xy += offset * 2.0 / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
  }
}

void fragment() {
  float r2 = dot(offset, offset);
  float profile = exp(-r2 / (2.0 * sigma * sigma));
  if (hero > 0.5) {
    // A soft halo and faint four-point glints.
    float r = sqrt(r2);
    float thin = sigma * 0.6;
    float spike = sigma * 10.0;
    profile += exp(-r / (sigma * 5.0)) * 0.12
      + (exp(-abs(offset.y) / thin) * exp(-abs(offset.x) / spike)
       + exp(-abs(offset.x) / thin) * exp(-abs(offset.y) / spike)) * 0.07;
  } else {
    profile += exp(-sqrt(r2) / (sigma * 3.0)) * 0.22 * halo;
  }
  // Ease to nothing at the quad's edge, so no square shows round a star.
  profile *= 1.0 - smoothstep(0.7, 1.0, max(abs(offset.x), abs(offset.y)) / reach);
  ALBEDO = light * profile;
}
