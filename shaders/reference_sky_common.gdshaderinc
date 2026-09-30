// Ported from ZenScape sky.js and aurora.js; shared by sky and water.
#include "res://shaders/reference_globals.gdshaderinc"

  // A world direction as the room sees it (docs/scenic/hand-turn.md, "A fixed
  // room"): turned back about the vertical by the room's yaw, so what is
  // drawn in the room keeps its bearing to the camera as the diorama turns.
  vec3 zsRoomDir(vec3 dir) {
    float c = cos(zs_room_yaw);
    float s = sin(zs_room_yaw);
    return vec3(c * dir.x - s * dir.z, dir.y, s * dir.x + c * dir.z);
  }

  
   // strength, speed, palette, heading
  
  
  

  vec3 zsAurora(vec3 dir) {
    float visible = zs_aurora.x * smoothstep(0.35, 0.9, zs_night)
      * zs_celestial_clear * zs_celestial_clear * smoothstep(-0.65, -0.4, dir.y);
    if (visible < 0.0001) return vec3(0.0);

    float t = zs_motion_time * zs_aurora.y;
    float az = atan(dir.x, dir.z) - zs_aurora.w;
    // A world-fixed arc, never a camera-facing backdrop. Integer angular
    // harmonics make the join at +/-pi continuous from every orbit angle.
    float sector = 0.12 + 0.88 * smoothstep(-0.4, 0.7, cos(az));
    float breath = 0.72 + 0.28 * sin(t * 0.055 + 0.7) * sin(t * 0.033 + 1.2);
    vec3 light = vec3(0.0);
    for (int i = 0; i < 3; i++) {
      float layer = float(i);
      float a = az + layer * 0.24 + 0.025 * sin(t * 0.19 + layer);
      float fold = sin(a * 2.0 + t * 0.075 + layer)
        + 0.35 * sin(a * 5.0 - t * 0.11 + layer * 2.3)
        + 0.14 * sin(a * 9.0 + t * 0.045 + layer * 1.3);
      // As with the stars, the lower edge extends below the horizon: this
      // world's sky surrounds a floating diorama viewed from above.
      float foot = -0.28 + 0.115 * fold + layer * 0.085;
      float h = dir.y - foot;
      float height = 0.38 + 0.13 * sin(a * 3.0 + layer * 1.7 + t * 0.035);
      float u = max(0.0, h) / height;
      float curtain = smoothstep(-0.025, 0.035, h) * exp(-u * 2.2)
        * (1.0 - smoothstep(0.65, 1.2, u));
      // Fine, vertically coherent rays ride the large folds. Their phase
      // drifts slowly; no frame-random noise or scintillation.
      // Warp the spacing and bend the rays gently with height. All angular
      // frequencies remain integers so an orbit cannot expose a sky seam.
      float ribbon = a + 0.045 * fold + 0.025 * sin(a * 7.0 - t * 0.08 + layer)
        + h * 0.06 * sin(a * 3.0 + t * 0.05 + layer);
      float phaseA = ribbon * 79.0 + 2.4 * sin(a * 17.0 + layer) + t * 0.12;
      float phaseB = ribbon * 127.0 + 1.8 * sin(a * 29.0 - layer) - t * 0.09;
      // Fade unresolved rays in both the sky and the smaller water reflection.
      float rayA = mix(0.5, 0.5 + 0.5 * sin(phaseA),
        1.0 - smoothstep(0.5, 2.0, fwidth(phaseA)));
      float rayB = mix(0.5, 0.5 + 0.5 * sin(phaseB),
        1.0 - smoothstep(0.5, 2.0, fwidth(phaseB)));
      float rays = 0.22 + 0.50 * rayA + 0.28 * rayB;
      float gathering = 0.5 + 0.30 * sin(a * 4.0 + fold * 1.3 - t * 0.065 + layer * 2.1)
        + 0.20 * sin(a * 7.0 - fold + t * 0.04 + layer);
      float clusters = smoothstep(0.16, 0.78, gathering);
      vec3 green = mix(vec3(0.08, 0.82, 0.36), vec3(0.10, 0.55, 0.88), zs_aurora.z);
      vec3 violet = mix(vec3(0.38, 0.16, 0.65), vec3(0.66, 0.14, 0.47), zs_aurora.z);
      vec3 color = mix(green, violet * 1.2, smoothstep(0.06, 0.55, u));
      // A gathered fold catches light; the lower edge disappears between
      // gatherings instead of drawing one unbroken luminous rail.
      float hem = exp(-h * h / 0.0012) * 0.09 * clusters * clusters;
      light += (color * curtain * rays * (0.06 + 1.35 * clusters) + green * hem)
        * (0.36 - layer * 0.075);
    }
    return light * visible * sector * breath;
  }

  
  
  
  
  
  
  
  
   // angular radius scale, band thickness
  // THE RAINBOW (ADR 0043). Sunlight turned back by the drops still in the
  // air: a ring about the ANTISOLAR point, red outside at 42.3 degrees and
  // violet inside at 40.6, a fainter second ring turned inside out at 50-53,
  // the sky between the two a shade darker (Alexander's band) and the sky
  // inside the first a shade brighter, since every drop nearer the axis
  // than the bow throws light too. The angular distance is shared with the
  // dark band; a dry sky skips this whole term.
  vec3 zsSpectrum(float t, float pixelWidth) {   // 0 = violet .. 1 = red
    // Overlapping light lobes give each colour its own soft edge. Their
    // tails are the halo, instead of clipping a painted strip to a mask.
    // Widen subpixel lobes while conserving their energy in distant water.
    vec3 width = vec3(0.32, 0.30, 0.29);
    vec3 filtered = sqrt(width * width + vec3(pixelWidth * pixelWidth));
    vec3 x = (vec3(t) - vec3(0.91, 0.55, 0.20)) / filtered;
    vec3 c = exp(-x * x) * width / filtered * vec3(1.0, 0.94, 1.0);
    float violetWidth = sqrt(0.19 * 0.19 + pixelWidth * pixelWidth);
    float violet = (t - 0.08) / violetWidth;
    c.r += 0.30 * exp(-violet * violet) * 0.19 / violetWidth;
    return mix(c, vec3(max(c.r, max(c.g, c.b))), 0.14);
  }
  vec3 zsRainbow(float a, float pixelWidth, vec3 dir) {
    float a1 = 41.45 + (a - 41.45) / zs_bow_shape.y;
    float a2 = 51.8 + (a - 51.8) / zs_bow_shape.y;
    pixelWidth /= zs_bow_shape.y;
    float t1 = (a1 - 40.6) / 1.7;
    float t2 = (a2 - 50.2) / 3.2;
    // the light is the sun's: a low sun makes a red bow
    vec3 sun = mix(vec3(1.0, 0.55, 0.32), vec3(1.0), smoothstep(0.02, 0.3, zs_sun_direction.y));
    vec3 col = zsSpectrum(t1, pixelWidth / 1.7) * 0.38
      + zsSpectrum(1.0 - t2, pixelWidth / 3.2) * mix(0.085, 0.2, zs_bow_double);
    // The crest catches clear light; the feet dissolve into wetter air.
    // Broad, fixed variation reads as uneven drops, never a pulsing neon arc.
    float drops = 0.90 + 0.10 * sin(dot(dir, vec3(7.0, 3.0, -5.0)));
    col *= drops * mix(0.66, 1.0, smoothstep(-0.12, 0.38, dir.y));
    // A pearly inner shoulder and two barely-there interference fringes.
    // They use the same angle as the bow, fading out when too fine to resolve.
    float shoulder = (a1 - 39.9) / 1.25;
    col += vec3(0.026, 0.032, 0.045) * exp(-shoulder * shoulder);
    float fringe1 = (a1 - 39.65) / 0.16;
    float fringe2 = (a1 - 39.15) / 0.14;
    col += (vec3(0.010, 0.005, 0.012) * exp(-fringe1 * fringe1)
      + vec3(0.004, 0.008, 0.009) * exp(-fringe2 * fringe2))
      * (1.0 - smoothstep(0.08, 0.30, pixelWidth));
    col += vec3(0.022) * (1.0 - smoothstep(34.0, 40.6, a1));
    return col * sun;
  }
  vec3 zsSkyGradient(vec3 dir) {
    float y = dir.y;
    vec3 col = mix(zs_sky_down, zs_sky_up, smoothstep(-0.4, 0.7, y));
    // By day the glow band is the preset's, all the way round. At the
    // horizon crossings (zs_dusk_direction rises) it gathers toward the sun's side
    // of the sky — a sunset lives somewhere, not everywhere.
    float toSun = dot(normalize(dir.xz + 1e-4), normalize(zs_sun_direction.xz + 1e-4)) * 0.5 + 0.5;
    col += exp(-abs(y) * 3.5) * zs_sky_glow * mix(1.0, toSun * toSun * 1.6 + 0.08, zs_dusk_direction);
    // The Belt of Venus: on the side AWAY from the sun, the earth's
    // shadow stands on the horizon as a blue-grey band, and the air
    // above it still catches the sun and glows pink. The pink sits a
    // little higher and fades up into the dome; the shadow band sits
    // on the horizon line under it.
    if (zs_belt > 0.001) {
      float away = (1.0 - toSun);
      float pink = exp(-(y - 0.10) * (y - 0.10) / 0.012) * away * away;
      float shade = exp(-y * y / 0.004) * away;
      col += vec3(0.42, 0.13, 0.16) * pink * zs_belt;
      col = mix(col, col * vec3(0.55, 0.62, 0.80), shade * 0.5 * zs_belt);
    }
    if (zs_bow > 0.001) {
      // The bow runs on below the horizon a little, as the stars do: the
      // diorama floats, and the dome under it is most of the sky in shot.
      float ba = zs_bow * smoothstep(-0.55, -0.2, dir.y);
      // THE GROW: the bow is drawn the way the terrain is grown, not cut in.
      // It sweeps round the ring from the foot under the horizon on one
      // side, up over the top and down to the other foot, as zs_bow_grow runs
      // 0 to 1 — a frame about the antisolar axis, and the angle round it.
      if (zs_bow_grow < 0.999) {
        vec3 axis = -zs_sun_direction;
        vec3 reference = abs(axis.y) > 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
        vec3 up = normalize(reference - axis * dot(reference, axis));
        vec3 right = cross(axis, up);
        float phi = atan(dot(dir, right), dot(dir, up));    // 0 at the top
        float frac = (phi + 3.14159265) / 6.2831853;         // 0..1 from the bottom, round
        ba *= 1.0 - smoothstep(zs_bow_grow - 0.04, zs_bow_grow, frac);
      }
      float a = degrees(acos(clamp(-dot(dir, zs_sun_direction), -1.0, 1.0))) / zs_bow_shape.x;
      // Alexander's band: the sky between the bows is a shade darker
      float a1 = 41.45 + (a - 41.45) / zs_bow_shape.y;
      float a2 = 51.8 + (a - 51.8) / zs_bow_shape.y;
      col *= 1.0 - 0.08 * ba * smoothstep(42.3, 44.0, a1) * (1.0 - smoothstep(48.5, 50.2, a2));
      col += zsRainbow(a, fwidth(a), dir) * ba;
    }
    return col + zsAurora(dir);
  }
