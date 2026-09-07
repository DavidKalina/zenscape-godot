# Environment checkpoint

The fidelity scene is now the project's F5 entry point with Forward+. Esc opens
the existing sculpting prototype. This is an intermediate checkpoint toward the
full scope in [PARITY.md](PARITY.md), not a claim of complete source parity.

## Available controls

- Wind strength/direction, G gust, valley fog.
- Time slider, automatic day/night cycle, N advances to the next solar quarter.
- Aurora strength and rainbow visibility.
- Clear/rain/storm/snow selector with smooth lighting and precipitation transitions.
- B summons and frames a Bigfoot peek; T adds a ground tremor; P freezes motion.
- Drag orbit, middle drag pan, wheel zoom, R reset, Space drift, H controls, Tab source still.

## Source and native behavior

The celestial shader preserves the original sky gradient, stars, Milky Way,
meteor, sun, moon, rainbow and aurora functions. The original mountain lighting
curves reproduce the captured daytime sky vectors and sun energy within 1e-5.
This numeric check does not establish pixel-identical HDR rendering at every hour.

The shared advected wind field drives foliage, water, fog and spray. Valley fog
uses a bounded native volume; waterfall droplets have gravity and wind drag.
These native atmosphere/water effects are still approximations of the full
source systems. Fog on/off captures were inspected and the control range widened
because its original maximum barely changed the rendered valley.

The original rangy Bigfoot geometry is exported by tools/export_bigfoot.mjs.
The native rig ports idle, look, walk and peek, including bark-grip IK and two
independent foot-height solves. tests/test_bigfoot.gd compares 1,300 local joint
transforms against fixtures from bigfoot-model.js; maximum error was 0.000074.
The captured seed has no encounter tree, so the manual preview finds a dry,
level patch and adds the original procedural tree there. This is not yet the
original rare automatic encounter schedule or its entire lifecycle.

bigfoot-motion.mp4 compares moving native animation (left) with a frozen native
control (right), six seconds at 30 FPS. Frames near the start, middle and end
were inspected. This is motion evidence, not a performance measurement or a
Three.js/Godot pixel comparison. The earlier motion-comparison.mp4 predates this
checkpoint and covers the first water/motion pass.

Precipitation uses source-derived fall/wander/crown equations in native instanced
geometry. A 128-square height texture includes terrain and water. Nearest sampling
keeps the no-surface sentinel from contaminating edge heights. The iterative
wind-carried landing calculation is approximate on steep terrain; exact mesh
collision and full source weather behavior remain work. Transparent particles
use native HDR blending, rather than applying the sky's inverse output transform.

Tremor ports the original additive trauma, squared amplitude, deterministic
oscillation and decay. It is applied to a fresh orbit-camera transform each frame;
tests verify that it settles without drift. Growth/thunder event coupling remains.

## Validation

Native Forward+ tests/test_fidelity.gd passes water import, celestial matching,
wind/pause, fog controls, encounter pause/re-summon, tremor settling, weather
transitions and navigation checks. tests/test_bigfoot.gd passes source pose fixtures.
The source checkout and existing sculpting implementation are unchanged.

Remaining priorities include source cloud volumes and god rays, lightning and
wet/cold surface response, staged growth, lake detail/ice/algae/ripples, wildlife
behavior, sound, generation and editing parity. Frame-rate work remains paused.

## Cloud / pooled-air checkpoint

The original cloud density, erosion, orographic field, phase function and
three-tap self-shadow math are now in native sky shaders. The native integration
uses 64 steps in the final sky pass. Native fog also affects intermediate sky
passes; keeping the cloud integral in the final pass prevents fog being blended
twice and contaminating its display-space colors. A matched source capture exposed the
mountain preset's 20–32 cloud slab (not the module's 26–42 default) and the actual
wind direction (1, 0.35). Those inputs are corrected. The export now retains
cloud layer, baked summit and ground-range metadata in environment.json.

source-clouds.png/json records the original at seed 7, time .35, cloud .7, mist
.45, haze .15 and a horizon camera (32, 1.5, 1.8893, target 0,4,0). Native cloud
sun/sky colors and light direction match its captured uniforms within 1e-5.
Cloud drift freezes on pause and weather presets clear manual cover overrides.

Cloud shapes are closer after correcting those inputs. The source comparison
still shows brighter native foliage and different fog contrast. Tracing the complete source paint splice confirmed that cloud attenuation is
before tone mapping (inside opaque_fragment), correcting an earlier diagnosis.
The native hemisphere emission was missing the source Lambert 1/PI factor;
this has now been corrected. Surface cloud sampling also uses the source
shadow map's fixed 0.6 world-height convention. Night cloud illumination also has native daylight
scaling and needs a matched check. These are open fidelity differences.

The native fog now uses source pooled-air density and cloud-gap illumination,
with the imported terrain/water height map. Light-shaft intensity is adjustable;
the source summit-cap and lee-side spill fields are now present. Shroud and
inversion remain unported. Fog emission no longer applies density twice: Godot
already applies it during volume injection. Source fog lighting is converted
from display color into native HDR, and the local volume now affects sky gaps. Native volume integration and
HDR blending differ from the source volume compositor. No pixel-parity claim
is made for the atmospheric output yet.

cloud-comparison.mp4 is Godot left / original Three.js right, six seconds at
30 FPS, 1280×854 per side. Seed, camera, hour, cloud cover, mist/haze and starting
cloud drift are matched. Source final drift/state were captured to verify that
weather stayed pinned through the reel. Initial/middle/final frames were inspected;
the reel now includes the hemisphere and fog corrections. Atmospheric contrast
and pooling still differ; this is evidence of progress, not complete parity.

Fixed-state ray intensity 0/3 captures also show the cloud-lit contribution to
native fog. This proves the control changes the rendered illumination, not that
all source shaft shapes or contrast have been matched.

Latest review: the revised reel was checked at the start, midpoint and end.
Native pooled forest mist remains weaker than the source, the summit plume is
too faint, and flowers/grass retain stronger contrast. The cap/spill math is
ported but its rendered silhouette is not yet accepted as matching.
