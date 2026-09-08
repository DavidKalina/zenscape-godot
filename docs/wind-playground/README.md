# Wind playground

Launch `run-wind-playground.command`, or open `studies/wind_playground.tscn` in
Godot 4.7.2 Forward+. The scene constructs its garden from native editor data;
it does not replace an existing garden save.

## Try it

- Drag across the ground to aim a gust. Release to blow in the arrow direction.
  The origin is the start of the drag; the effect fades over an eight-metre radius.
- Choose Breeze, Gust or Blast. **Try a gust** aims a repeatable gust at Bigfoot.
- Switch **Gust tool** off to grab Bigfoot by the head or click for his attention.
  The existing **Pick up** tray button also works with the gust tool selected.
- Right drag orbits, the wheel zooms, R resets Bigfoot, P pauses/resumes.
- **Build this garden** opens the existing native palette. Sculpt, place, rotate,
  paint, save or open a garden normally. **Play with the wind** (or native Inspect)
  refreshes physical terrain/scenery and resumes play. Esc also exits Build.
  Returning to play requires a dry, sufficiently level clearing.

## What is shared

`LocalWindField` owns eight bounded local gust slots. Each has world origin,
normalized direction, speed in metres/second, radius and duration. A smooth
attack/decay and spherical falloff produce the same local vector on CPU and GPU.
Overlaps add; a ninth gust replaces the oldest. The physics clock advances the
field and publishes shader uniforms. Pausing freezes both the field and Bigfoot.

The existing atmosphere still supplies the landscape's ambient flutter. Its
smoothed strength and breathing envelope calibrate mean physical wind to
strength × envelope × 3 m/s. Noise-advection speed is not used as physical speed.

- Bigfoot uses an opt-in 32 kg rigid capsule with quadratic relative-air drag and
  off-centre force. The solver determines displacement and tipping. Small wind
  produces a supporting brace; settled bodies blend into an upright recovery.
- Foliage adds bounded local crown bending in world direction while preserving
  mesh rotation/scale and the existing ambient animation.
- Ponds and source lakes add directional surface chop and fine ripple normals.
  Shore factors and ice suppress the response.
- Waterfall spray drifts laterally; main strands deflect subtly, anchored at
  their source and impact, with downward flow preserved.
- Native terrain uses its actual triangle mesh for collision. Solid props use
  transformed collision proxies; placement checks account for those proxies.

## Evidence

`gust-control.mp4` shows the same camera, garden and frame clock: gust on the
left, untouched control on the right. The trigger is frame 60. At frame 45 the
rendered images match exactly. Frame 100 shows Bigfoot toppled with changed
foliage and spray; he subsequently recovers roughly two metres from his start.
`gust-control-detail.png` enlarges that comparison. `render-differences.json`
records selected region differences, not a quality score.

Reproduce footage with `tools/film_wind_playground.gd` and Godot `--write-movie`
at `--fixed-fps 60`; append `-- --control` for the untouched reel. Profile using
`tools/profile_wind_playground.gd`. Test results and performance measurements are
stored beside this document.

Forward+ GPU regression: **90/90 tests passed**, with no script/shader errors or
timeouts. The integration test also exercises camera-projected aiming,
Build/Inspect synchronization and pause/resume. Computer use successfully
inspected the live window, but click/drag commands failed with the tool's
`noWindowsAvailable` error; automated native pointer manipulation was therefore
not verified. The scene is left open for a human feel check.

Performance on the Apple M5 Pro at a 1440×960 viewport: three alternating control
and gust phases, 360 measured frames each after settling. Control medians were
8.31–8.34 ms; gust medians were 8.16–8.36 ms. Control p95 was 8.45–9.02 ms and
gust p95 was 8.73–9.41 ms. This is approximately a 120 FPS presentation limit,
not a measurement of spare GPU capacity. Metal returned zero for GPU duration,
so that counter is unavailable rather than evidence of zero GPU cost. The
measurements show no clear median frame-time increase in this small garden;
large dense gardens and other hardware still need profiling.

## Current limits

This is a first physics interaction, not an articulated ragdoll. Animated limbs
can intersect the ground while the capsule tumbles; getting up blends back to
the existing Land/Alert performance. Props remain static, and Bigfoot does not
yet float, splash or collide limb by limb. His play state is transient; native
garden saves preserve landscape edits, not creature placement or gust history.

Spray retains the existing analytical particle renderer: instantaneous gust
velocity offsets its age-based path, rather than integrating a persistent
trajectory. It returns smoothly as a gust decays. Water is shader motion, not a
fluid volume: pond displacement is bounded to 0.12 m and waterfall deflection to
0.24 m. This system does not change water routing or terrain.

The existing fidelity scene reports six ObjectDB instances at shutdown in some
capture runs. The new interaction tests check their own body/collider cleanup;
the pre-existing scene shutdown leak is outside this feature.
