# Crows on the aqueduct isle (round 1)

The aqueduct isle's songbirds are now crows. Only the look changed: the
flocks, perches, hops, foraging, flush, wheel, settle-away, home, roam and
dusk/dawn logic in `scripts/kit_isle/kit_birds.gd` run as before. The
crow's poses read the bird's state and write nothing back. It has its own
RNG, so `kit_birds`' random sequence is unchanged too.

- `scripts/crow_body.gd`: the crow, built in code like the guácharo.
  - A faceted lofted hull (flat planes, ridged back, keeled breast). After
    the user's note on lumpiness, it is angular and sleek, not round blobs.
  - A head whose forehead runs straight into a heavy beak, with a hinged
    lower mandible (the caw).
  - Throat hackles, scaly legs that keep the feet on the stone, and a
    12-feather tail that fans.
  - A folded wing for sitting. For flight, an arm-and-hand wing whose 10
    primaries are notched into fingers.
  - Drawn at 0.8 of a carrion crow: about 36 cm long, 72 cm across.
- `animate(bird, delta, yaw)` plays:
  - heavy flaps (a strong down-stroke; on the up-stroke the hand flexes back
    and the fan half closes), with glides between bouts while cruising and
    banking into turns;
  - the launch: wings flung up, nose high, faster beats, legs tucking;
  - the flare: nose up, short quick beats, tail fanned and down, feet
    reaching;
  - the touchdown: a squash that springs back while the wings lift and fold,
    then a tail flick;
  - the hop: a crouch, then a leap with one flap and the feet reaching;
  - while sitting: head snaps that overshoot a little, occasional head
    cocks, breathing;
  - a caw now and then: the head goes up, then thrusts forward with the beak
    open, the tail lifting, two or three times;
  - pecks on the turf.
- `shaders/crow.gdshader` draws the plumage:
  - feathers: charcoal-black quads with ragged, split edges (alpha scissor),
    old feathers worn brown at the tips, barbs, dust specks in the grain;
  - the body: faint feather rows and grain;
  - the beak: grained dark horn with a worn tip;
  - the sheen: a faint oily violet-to-green, drawn as a soft tinted lobe in
    `light()` and not as metallic, so it never glares white.

  Fine detail fades by pixel footprint.
- `kit_birds.gd`: a flock of species `crow` gets `CrowBody`. Other species
  keep the songbird body, so the other kit isles are unchanged.
  `studies/aqueduct_isle_birds.gd`: all four flocks are now crows, with the
  same counts and homes.
- `studies/crow_poses.tscn`: a key-poses grid. `--live` plays one crow
  through the states, `--close=<pose> [--from=below|above|front]` gives a
  close-up, and `--capture=dir` saves frames.

## Proof

- A headless import, then a smoke of `studies/aqueduct_isle.tscn` and
  `studies/crow_poses.tscn` (with and without `--live`) for 600 frames: 0 errors.
- `tests/test_aqueduct_isle_life.gd`: all 11 bird checks pass with crows
  (perch, flit/hop/forage, flush at the pilot, settle away, home, gust
  flush, night, morning).
- Rendered close-ups were judged by eye: the study grid, close-ups, a frame
  strip of the live run, and the real isle (perched on the gate, backlit
  and sun-side, and the flush).

## Existing tests

- `test_aqueduct_isle_life.gd` fails 3 **token** checks (the wall-run
  token, all 8 taken, the readout). They fail the same with the songbird
  flocks restored, so they are pre-existing and not from this round.
- No test breaks from this change. The check labels still say "Songbirds".

## Model budget (docs/art/model-budget.md)

The crow is about 1.1k triangles sitting and 1.3k flying. Feathers are
6-triangle quads with the detail drawn in the shader. With 14 crows that is
about 15–18k triangles and 11–13 draw calls each (about 170). All
materials are shared, and the per-crow fan is an instance uniform.

| Trick | Applies? | Estimate |
|---|---|---|
| Sculpt high, bake low | No. It is already low (about 1.2k triangles) and its detail is procedural in the shader. | none |
| Import LODs / visibility ranges | Yes, the best one. Below about 25 m, swap to a single merged mesh (no hackles, legs, eyes or jaw, and the tail and folded wings merged into the body). The isle already hides the birds past 150 m. | about 60% fewer triangles and about 9 fewer draw calls per far crow; about 0.05–0.1 ms CPU for 14 crows |
| Silhouette geometry | Already used: the faceted hull, the notched fingers and the ragged edges cut by alpha. | — |
| Rigid parts on bones | Already used. It is all rigid parts on nodes, with no skinning. | — |
| Parallax depth | No. The surfaces are too small to show it. | none |
| Vertex-colour grime | Partly. Dust and wear come from the shader. Darkness baked into the crevices of the hull at the neck and under the wings would cost no time. | 0 triangles, about 0 ms |

## Follow-ups

- `scripts/kit_isle/kit_audio_life.gd` still places songbird song excerpts
  at the birds' perches, so the crows "sing". Crow calls (caws timed to the
  caw pose) would match.
- The other kit isles still have songbirds. Giving them crows is one line
  each: species `crow` in their `*_isle_birds.gd`.
- The animation is procedural key poses in code and not Blender clips. It
  was judged in stills and frame strips, not yet in play.
