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
  float kind = INSTANCE_CUSTOM.w;
  hero = kind > 0.5 && kind < 1.5 ? 1.0 : 0.0;
  // Thinned toward the void under the slab, never cut at the horizon: the
  // camera looks down on the floating plate, so most of the sky it sees is
  // below the horizon line.
  float k = zs_night * zs_celestial_clear * smoothstep(-0.55, -0.2, dir.y);
  if (k > 0.001) k *= zs_ridge_open(dir, room) * zs_moon_open(dir, 0.004) * zs_sea_open(dir);
  if (k > 0.001) k *= zs_cloud_transmit(CAMERA_POSITION_WORLD, dir);
  if (k * bright < 0.002) {
    POSITION = vec4(2.0, 2.0, 2.0, 1.0);
  } else {
    float t = zs_motion_time;
    vec3 tint = star_tint(INSTANCE_CUSTOM.x);
    // A breath of scintillation, only on stars bright enough to show it
    // and a little more down by the horizon line; the faint dust holds
    // steady, so the sky is still rather than busy.
    float scint = mix(0.03, 0.09, 1.0 - smoothstep(0.0, 0.5, abs(dir.y))) * smoothstep(0.25, 0.8, bright);
    vec3 tw = vec3(1.0 + scint * sin(t * (0.5 + seed * 0.9) + seed * 40.0) * sin(t * (0.31 + seed * 0.4) + seed * 9.0));
    if (kind > 1.5) {
      // A breather: its colour swells and settles over half a minute.
      float breath = 0.5 + 0.5 * sin(t * (0.18 + seed * 0.08) + seed * 30.0);
      tint = mix(vec3(0.85, 0.95, 1.0), mix(vec3(0.45, 1.0, 0.9), vec3(0.75, 0.6, 1.0), INSTANCE_CUSTOM.x), 0.35 + 0.65 * breath);
      tw = vec3(0.65 + 0.35 * breath);
    }
    // Screen pixels: a star is a crisp point a pixel or two across, as a
    // real one is. Only a 4K-class window scales them up. The fade inside
    // the quad is round, so even the glow round a bright one never squares.
    float px = max(VIEWPORT_SIZE.y / 1800.0, 1.0);
    if (hero > 0.5) {
      // True HDR light that the glow picks up.
      light = tint * tw * bright * k / zs_exposure;
      sigma = 1.0 * px;
      halo = 1.0;
    } else {
      // Display light up to white, the overflow as HDR for the glow.
      vec3 peak = tint * tw * bright * k;
      light = scene_linear_for_display(min(peak, vec3(1.0))) + max(peak - 1.0, vec3(0.0)) * 0.5 / zs_exposure;
      sigma = mix(0.55, 0.85, smoothstep(0.1, 1.3, bright)) * px;
      halo = kind > 1.5 ? 1.0 : smoothstep(0.7, 1.3, bright);
    }
    reach = sigma * (hero > 0.5 ? 9.0 : mix(4.0, 8.0, halo));
    offset = VERTEX.xy * reach;
    vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dir * sky_distance, 1.0));
    clip.xy += offset * 2.0 / VIEWPORT_SIZE * clip.w;
    POSITION = clip;
  }
}

void fragment() {
  float r2 = dot(offset, offset);
  float r = sqrt(r2);
  // A round core and, on the brightest, a soft glow round it. No spikes:
  // they read as a lens, not as the sky.
  float profile = exp(-r2 / (2.0 * sigma * sigma));
  profile += exp(-r / (sigma * 2.2)) * (hero > 0.5 ? 0.1 : 0.06) * halo;
  // Ease to nothing inside the quad's circle, so its square never shows.
  profile *= 1.0 - smoothstep(0.6, 1.0, r / reach);
  ALBEDO = light * profile;
}
