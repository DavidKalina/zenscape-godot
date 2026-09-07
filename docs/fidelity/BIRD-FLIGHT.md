# Terrain-driven bird flight

The imported gull flock now uses source birds.js flight dynamics rather than
rotating captured transforms around the origin. Its five source thermals and
22 initial simulation slots are exported after matching the imported bird mesh.
Eleven reserve slots stay hidden until called, as in the source growth model.

`studies/bird_flight.gd` implements soar/cross/stoop/pullup transitions, thermal
spring/tangent steering, wind drift, look-ahead climb, terrain backstop, turn-rate
cap, bank, pitch, and effort-driven flap amplitude/phase. The vertex shader uses
the original wing rotation with a squared shoulder-to-tip lever and persistent
per-instance phase. Pause freezes both flight and wings. Hidden birds do not
simulate. The native UI can startle the flock into a sustained climb-out and
call the reserve into the sky through the source forty-second easing constant.
Departure-call events are emitted but are not yet connected to audio.

## Verification

`tools/export_bird_flight.mjs` records source states and ten-second trajectories
with a reproducible random stream, plus the original terrain queries.
`test_bird_flight.gd` replays those queries to isolate the flight equations:
maximum position error at step 300 is 0.00000190735 world units, phase error
0.000000245712 radians, and no mode differences. Query positions/counts also
agree. The production terrain adapter is now checked separately against independent source heights and trajectories.

Additional native checks cover pause, growth hiding, startle, and forty seconds
of strong-wind flight with center clearance against the actual imported terrain.
`test_fidelity.gd` passes after scene integration. `bird-thermal-flight.mp4`
shows 15 seconds of the integrated flock, camera `22,.95,1.9,0,9,0`; frames 150
and 350 inspected. Birds trace different paths above the peaks and bank as they
turn. This is native motion footage, not matched source/control footage.

## Remaining fidelity work

The production flock now uses `reference_source_ground.gd`, which ports the
imported scene's continuous noise, twin-summit profile, terrace quantization,
stream channel cuts, pool scoop, and arch ground profile. Exported genome,
landmark placement and stream plan come from `export_source_terrain.mjs`.
This is a sampler for the captured seed-7/gen-21 scene, not a general world
generator. Other terrain archetypes and border-conforming worlds remain unported.
Bigfoot feet and precipitation retain their visible-mesh contact samplers.

`test_source_terrain.gd` compares 10,000 independent source queries across a
48-unit square, including the island margins: maximum height error 3.4e-12.
The actual continuous sampler then drives the ten-second source flight fixture:
maximum position error 2.25e-6 world units, phase error 1.26e-6 radians, no mode
differences. These checks use free queries, not a replay of recorded heights.
The integrated scene test passes. `bird-source-terrain.mp4` is a three-second
native capture after integration; frame 60 inspected. Matched source motion
footage is still pending.

A dense bilinear height-field experiment was rejected before integration:
although it reduced flight error from .61 to .032 units, averaging across the
source's .678-unit terrace steps caused height errors up to .384 units. The
analytical sampler preserves those discontinuities; the experimental grid and
runtime sampler were removed.

The fixture is gull-only. Crane/goose model swapping, mixed population limits,
bird-call audio and complete conductor growth pacing remain. Native flight uses
a seeded random stream for repeatability; the source uses Math.random during
mode changes. Source comments describing future perching/V-formation/storm
sheltering are proposals, not behavior implemented by current birds.js.

## Paused sandbox growth

Growth controls update flock visibility even while motion is paused. Scrubbing
terrain backward below its ready threshold hides the flock; restoring terrain
and foliage restores its current pose without advancing simulation or wing
phase. `test_paused_reveal.gd` reproduced the previously stuck visible flock,
then passed after separating paused visibility publication from flight updates.
Birds also wait for ready terrain during ordinary replay.
