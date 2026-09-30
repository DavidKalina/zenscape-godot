# The sky's cloud

Branch `feature/sky-cloud` (2026-09-29). Before this, you got water by pressing empty sky and dragging onto the land. The user found that it felt good but was not legible: "maybe there should be a cloud where you're pulling, or sourcing water from." They chose an always-there cloud (over summoning one on press) and a cloud that runs dry and refills (over an endless one).

## Summoned

Branch `feature/summoned-cloud` (2026-09-29). The user scrapped two experiments that replaced this cloud (a moisture veil round the plate, and pulling tufts out of the volumetric cloud deck). They like this faceted cloud and its stretch and tear, but not anything that is always in the sky ("adds distractions"), and not many steps. So the cloud is never there by default: "You summon an orb, you summon a cloud." Everything below "Try it" still describes the cloud once it is there. The always-there cloud is kept behind `--always-cloud`.

### Try it

- **Nothing in the sky.** At rest there is no cloud.
- **The first world.** About 4 s into the session's first world, the cloud forms by itself where the always-there cloud floated, hangs about 6 s, then drifts off on the wind and thins away. It shows once a session. Hovering empty sky after that, the hint reads "Hold in the sky to call a cloud", until you have called it twice.
- **Click empty sky** still snaps day and night, and **a quick drag** is still the wind. Neither calls anything.
- **Press and hold empty sky.** After about a third of a second the loaded snap unloads into an open, cupped hand, and the cloud condenses in it: droplets and wisps swirl in to the hand, then the puffs swell out from the hand outward, overshoot and settle. It forms round the pinch, so the hand is already holding its near face.
- **Keep holding and pull.** The same press stretches it like taffy and tears the tuft off, as below. The hand closes to the pinch once the cloud has formed or you start to pull. A quick pull works too: the cloud can be torn once its middle has formed (0.35 s in); pulled further before that, it holds at the end of its stretch and tears the moment it can.
- **Carry the tuft over the land.** It becomes the water ball. Let go and it drops. All of it is one press: hold, form, pull, tear, carry, release.
- **Let go without pulling.** The cloud finishes forming and stays. Nothing snaps.
- **It lingers.** Press it again and it is pinched at once. Pull and tear for more water.
- **It leaves.** Left alone about 10 s, or 3 s once wrung dry, it drifts off with the sky's wind, rising a little, and thins away over 4 s, outer puffs first. Pressed while it is still more than half there, it swells back.
- **Hold elsewhere** while it is in the sky and it flies over and re-forms in your hand, keeping its water.

### How it works

- `scripts/sky_cloud.gd` (`summoned`, `presence`: "gone", "forming", "here", "leaving"; always "here" under `--always-cloud`). `hand_reach.gd` calls it.
- **The summon.** `hand_reach._process` counts the void press's hold. At `SUMMON_HOLD` (0.35 s) with the pointer still within `CLICK_PIXELS` (6 px), `_summon` cancels the wind's press, takes the hand's void point (on the pointer's ray, `VOID_DEPTH` 0.8 of the camera's distance out) and calls `SkyCloud.summon`. From there the press is the cloud's: `holding` is "cloud" and the drag and release run the cloud's code, unchanged.
- **Placing it.** The cloud faces the camera (level). It stands `GRIP` (0, 0.1, −1.6) of its own metres behind the pinch, so the pinch is on its near face, under the pointer. Its `size` is its depth over `REFERENCE_DEPTH` (60 m, about the always-there cloud's), within `SIZE_RANGE` (0.25 to 1.2), so it reads about the same size on screen. Everything in metres scales with it: puffs, stretch (`STRETCH`), grab reach, tremble, recoil, tuft and drops. It stays where it was called, bobbing; the bob stops while it is held, so a let-go does not jump.
- **Forming** (`FORM_SECONDS`, 0.79 s).
  - Anticipation: `GATHER_BEADS` (28) of the drop beads spiral in to the pinch from `GATHER_SPREAD` (2.4) times the cloud's size over `GATHER_SECONDS` (0.34 s), turning `SWIRL` (2.4 rad), slow then quick, stretched along their way. The three wisp puffs curl in with them.
  - The puffs: from `PUFF_START` (0.12 s), each puff starts up to `PUFF_STAGGER` (0.22 s) later by its distance from the pinch, so it swells from the hand outward. Each gathers in from `PUFF_SPREAD` (1.7) times its place on a critically damped ease (`GATHER_RATE` 14/s) and swells over `PUFF_SECONDS` (0.45 s) on an underdamped spring, 1 − e^(−11t)·cos(17t) (`SWELL_DAMP`, `SWELL_FREQ`): about 13% over at 0.18 s, then a small dip and settle. The probe reads 1.195 of full size at the peak (with the breath).
  - It can be torn from `TEAR_FORM` (0.35 s). A pull that reaches the tear earlier waits at the end of its stretch.
  - Called while it is still in the sky, it re-forms from where its puffs are drawn, with their sizes, instead of from nothing.
- **The hand.** While forming it takes "summon": the Reach clips (the sun's cup), floating, square to the camera. A loaded snap unloads into ReachIn over `UNLOAD_BLEND` (0.25 s). It closes to "cloud" (the Pinch clips) once formed, or once the pull's tension passes `PINCH_TENSION` (0.08), and stays closed.
- **Lingering and leaving.**
  - Seconds left alone count only while it is idle and not feeding a ball.
  - It leaves after `LINGER` (10 s), `DEMO_LINGER` (6 s) for the demo, or `DRY_LINGER` (3 s) once wrung dry (`wrung`: its water fell under a tear's since it came). It still refills at `REFILL` while it lingers.
  - Leaving, it drifts along the atmosphere's live wind (`_air_angle`, `_air_strength`) at `DRIFT` (1.2 to 4 m/s by strength, times its size), easing in over the first third, and rises `RISE` (0.35 m/s). With no wind it drifts across the view. As it sets off its puffs are kicked back, the trailing side most.
  - It thins over `LEAVE_SECONDS` (4 s): each puff shrinks to nothing in its own half of that, outer puffs first, while the puffs spread apart and the belly pales. Under `LEAVE_GRAB` (0.6) of the way gone a press takes it, and it swells back.
  - Gone, it is full again for the next call.
- **The demo.** `DEMO_DELAY` (4 s) of a calm world (a world open, nothing held) in a session that has not seen it (`demo_shown`, a static). It forms where the always-there cloud floats (`FAR` 9 m beyond the plate's middle, 15 m up, 2 m to the side), at size 1, then lingers `DEMO_LINGER`. Taken by the hand, it becomes an ordinary summoned cloud. `--no-cloud-demo` skips it (for probes and films that press the sky).
- **The hints.** Over empty sky, once the demo has shown or the snap's hint is done, the hint is `SUMMON_HINT` ("Hold in the sky to call a cloud") until the summon has been used `SUMMON_HINT_UNTIL` (2) times or the hint read `SUMMON_READS` (5) times. No marks or outlines.
- **No shower.** The design allowed a light shower on its way out, if the rain and runoff made it cheap. There is no rain source for the flow sim to take (only balls and springs), so it does not rain.

### Probe

`tools/probe_summoned_cloud.gd` (`--headless --fixed-fps 60 ... -- --no-title`) passes, 33 checks: no cloud at rest; the demo forms by itself, hangs on screen above the land, drifts 2.2 m and thins to 0.35 of its bulk halfway out, is gone, and does not come back; the sky's hint then names the summon; a quick click snaps and a quick drag blows wind, neither calling it; a hold 0.1 s short is still the snap's, and at 0.35 s it calls the cloud into a cupped hand, the pinch on the pointer; 28 droplets gather; the puffs overshoot to 1.195; in the same press the pull pinches, tears at 0.4 s formed (before it finishes), and over the land the tuft is the held ball, filled only from the cloud, without a snap; the ball lands and the cloud lingers; pressed again it pinches at once and gives a second ball; left alone it leaves at 9.4 s and is gone, drifted, and the sky under the pointer is empty again; a hold let go calls it and snaps nothing; wrung dry it leaves after 2 s. `tools/probe_sky_cloud.gd` now runs with `--always-cloud` and checks the old cloud, plus that a long still hold there calls nothing and still snaps (45 checks). `tools/probe_sky_wind.gd` still passes.

## Try it (the cloud once it is there)

- **Look up** (`--always-cloud`). A small faceted cloud floats over the far side of the diorama, in the sky behind it. It follows the camera round slowly, so it stays behind the plate, and it sways and bobs. Its belly is grey-blue when it is full of water.
- **Hover it.** The hand opens over it and the hint reads "Pull the cloud to tear off some water".
- **Press and pull.** The hand pinches a tuft, and the cloud stretches after it like taffy. The puffs near the press follow and the whole cloud leans. A neck of small puffs stretches between the cloud and the tuft, thinning as it goes. The further you pull, the more the hand lags the pointer, and near the end the cloud trembles.
- **Let go short.** It springs back and jiggles. Nothing is taken.
- **Pull far enough** (0.16 of the view's height). The tuft tears off into the hand: the cloud recoils and the neck breaks into wisps.
- **Carry the tuft over the land.** It condenses into the water ball, which fills while you hold it, as before, but only with what the cloud has. Drops run from the cloud's belly along an arc into the ball, and the cloud shrinks and pales as it gives. Let go and the ball drops, as before.
- **Let a tuft go over the sky.** It drifts home and gives its water back.
- **A dry cloud** stretches but will not tear. The hint says it is wrung dry and fills again in time.
- **Click empty sky** still snaps day and night. Dragging from empty sky no longer makes water. The cloud is the only way to get it.

## How it works (the cloud once it is there)

- `scripts/sky_cloud.gd`, made by `hand_reach.gd` in its setup under the modeless hand.
  - It lives in the room (world space), not under the terrain, so it does not turn with the world or ride the flip.
  - It is drawn as 22 puffs in one MultiMesh: 11 for the body, 4 for the neck, 4 for the tuft and 3 wisps. The puffs are low-poly spheres with flat facet normals (`shaders/sky_cloud.gdshader`).
  - The top is white. The belly takes the instance colour, from `BELLY_FULL` to `BELLY_DRY` with the water.
  - The drops reuse the water ball's beads (`shaders/water_bead.gdshader`).
- **Placement.** It floats `FAR` 9 m from the plate's middle toward the far rim, `HEIGHT` 15 m up. It sways `SWAY` 4 m across over 70 s and bobs 0.35 m. Its bearing eases after the camera at `BEARING_RATE` 0.6/s. From the default view (1440×900) it sits at about (702, 91) px, well above the land.
- **Hit.** The pointer's ray is tested against the body puffs at `HIT_SLACK` (1.25) of their radius, and only while the cloud is at rest. `hand_reach` checks the cloud before the rim, the land and the void, so a press on it is the cloud's.
- **The pull.**
  - Tension is the pointer's travel from the press over `TEAR_REACH` (0.16) of the view's height.
  - The pulled puffs follow the pointer's own travel on the plane through the grab, facing the camera. The follow eases toward `STRETCH` (4.5 m): `STRETCH·(1 − e^(−d/STRETCH))`. So the hand, which holds the tuft, lags the pointer more as the pull grows (70 px at the tear in the probe).
  - Puffs are weighted by `exp(−(d/GRAB_REACH)²)` from the press (`GRAB_REACH` 2.6 m), and the whole cloud leans `SAG` (0.15) of the way.
  - Each puff springs toward its goal (90/s², 7/s, under critical), so it jiggles.
  - It trembles up to `TREMBLE` (0.12 m) by tension³.
- **The tear.**
  - The tear takes `TEAR_TAKES` (0.6 m³, the ball's first water) from the cloud.
  - The pulled puffs are kicked back at `RECOIL` (9 m/s) by their weight.
  - The neck becomes wisps that drift and shrink over 0.6 s.
  - The tuft follows the pointer on a spring (70/s², 13/s).
- **Into the ball.**
  - Over the land, `hand_reach._cloud_drag` sets `NativeChunkEditor.ball_supply` to the cloud's `supply` and calls `ball_from_sky`.
  - The tuft flies into the ball and shrinks over 0.35 s, the ball's own condense.
  - `_ball_step` fills the ball only with what `ball_supply` grants. The release clears it, so the classic water brush still fills freely.
  - Drops fall along a quadratic arc from the belly to the ball's top. At most 40 are in the air, at up to 34 a second by the feed rate. Each takes 0.7 s.
- **Water.**
  - A full cloud holds `CAPACITY` 30 m³, a little more than one largest ball (24 m³).
  - It refills at `REFILL` 0.5 m³/s (empty to full in a minute), only while it is at rest and not feeding.
  - Its size (down to `SHRUNK` 0.6) and belly colour follow the water, eased at 3/s.
- **The hand.** Over the cloud the hand takes the "void" pose at the pointer's point on the cloud. Pressing takes "cloud": the Pinch clips, floating free (not lifted, not tilted to the ground, leaning into the pull). Once the ball is made, the editor's "cup" takes over, as before.

## Seeds: the wild tree's flick

First built the same day as a seed pod in the sky (a dandelion clock pulled like the cloud) plus trees bent all the way over to shake spores into the hand. The user found the pod "not super legible" next to the cloud and liked "having to flick the pollen from the trees". So the pod is gone, and a tree throws its spores itself when you let it go.

### Try it

- **The wild tree.** Every fresh plain under the hand has one mature tree, 3–6.5 m from the middle: a broadleaf, conifer or birch, as the seed turns. It is the forest's first source. The other is water: a splash grows trees where it lands.
- **Flick it.** Press a tree and the hand takes it by the crown. Drag and it bends after you. Let go and it whips back, and the spores burst from its crown the way it whips (against your pull). A little tug throws nothing. From about a third of the way over, they land 2.5 m out, and a full bend throws them 9 m and thicker. They fly into a veil that sinks at once. The wind carries it and the land decides what takes, as for the old swept veil. They lean to the tree's own kind, but the land bends it: where the kind suits the ground it holds, elsewhere the land picks (an oak's seeds come up willow on a shore), and now and then one comes up something new.
- **Rest.** A tree that has thrown its spores only bends for 45 s.

### How it works

- **The wild tree.** `genesis_canvas.gd` `_wild_tree`, called from `shape` when `modeless_input.enabled()`, places one of `WILD_KINDS` at `WILD_SIZE` 1.35. It is part of the plain, so undo, the flip's underside and atlas chunks all have it (each atlas chunk gets its own).
- **The flick.**
  - `hand_reach._tree_let_go` calls `_flick` if the tree's tension is at least `FLICK_MIN` (0.3) and it is rested.
  - The direction is minus the tree's last pull, in plate space. The reach is `FLICK_REACH` (2.5 to 9 m) by tension.
  - The strength is `TREE_STRENGTH` (1.8) times 0.4 to 1 of the forest brush's.
  - `NativeChunkEditor.fling_from_tree(base, crown, direction, reach, kind, strength)` lays a line of ground points from `FLING_FROM` (1 m) past the foot, every `FLING_STEP` (0.5 m), stopping where the land does. It then calls `pollen_cloud.fling`.
- **The veil.** `pollen_cloud.fling` gathers a veil along that line and starts every mote at the crown with a throw velocity (`FLING_SPEED` 1.4 × reach a second, lofted `FLING_LOFT` 2 m/s, scattered as the God Hand's toss is). It releases the veil at once, so the motes spring out of the crown on to their places while the veil takes its breath and sinks.
- **The kind.** `pollen_cloud.seed_kind` is stamped on the veil and handed on in `settled` as "kind". `_write_cloud` passes it through emergence onto each planned plant: the land bends it (`emergence._heir_kind`, below). Only kinds emergence can grow are passed (`hand_reach.SPORE_KINDS`).
- **The land bends the kind** (chosen 2026-09-29: "one tree produces more of the same tree", so variety comes from the land, and it may change a seed's kind completely).
  - A seed keeps its parent's kind at the kind's fit where it lands (`tree_stands.gd` `fit`: its species weight there over the best kind's, 0 where the habitat does not grow it), eased by `FIT_EASE` (0.5, a square root).
  - The forest spreading from the seeds keeps it at `SOWN_KIND_SHARE` (0.75) of that.
  - Otherwise the stand picks as it always does, so an oak's seeds come up willow on a shore and pine or juniper up high and dry.
  - `SPORT` (0.07) of them come up some other kind the ground grows (`tree_stands.gd` `sport`, by weight), whatever the fit, so a flat plain drifts too and the new kinds can be flicked in turn.
- **Sowing out of hand.** `_write_cloud` lends the editor to the forest brush while it sows. Without that, a veil made outside the brush wrote no forest wish.
- **Trees in hand.**
  - World play is paused whenever the editor is active, which it always is under the hand scheme, so the hand bends trees itself: `_tree_press`, `_tree_pull`, `_tree_let_go`, and `_step_trees` while world play is paused.
  - `_tree_press` checks the promoted trees' own `pick` first. World play's `pick_object` skips promoted trees, so a tree once taken could not be taken again until the world refreshed.
  - World play frees promoted trees whenever the world's objects change. So the hand keeps each tree's spring state and carries it onto the tree when it is promoted again (`_tree_node`, `_keep_spring`).

## Probe

`tools/probe_sky_cloud.gd` (`--headless --fixed-fps 60 ... -- --no-title --always-cloud`) passed 43 checks in two runs in a row before the summon; with `--always-cloud` it now has 45. It checks:
- the cloud is on screen above the land, and hover takes the cloud's zone and opens the hand;
- a click on empty sky still snaps;
- a press pinches;
- a short pull stretches it (2.1 m at 0.42 tension), then springs back within 0.1 m and keeps its water;
- a long pull toward the land lags the hand by 70 px and tears, and the tuft becomes the held ball, cupped;
- after 1.5 s the ball holds 4.24 m³, exactly what the cloud gave, 19 drops are in the air and the cloud shows 0.9 full; the ball lands and the drops stop;
- a tuft torn upward and let go over the sky drifts home and gives its water back;
- a cloud at 0.3 m³ stretches but does not tear, and refills;
- there is no seed pod, and the plain has its one wild tree;
- a little tug on it throws nothing;
- bent past 0.9 and let go, it flicks: the veil carries the tree's kind, its motes are in the air, and the tree is out of the hand. The seeds land against the pull, and that kind leads on them and in the forest round them;
- pressed again once it settles, it is in hand. Bent again at once, it stays in hand through the forest's refreshes, throws nothing when let go, and springs back to rest.

## Limits and open points

- **Summoned, unseen.** Nothing of the summon has been rendered or felt: the gather and swell's timing and overshoot, whether the droplets read at that size, the Reach cup's read as a beckon and its hand-off to the pinch, whether 0.35 s is the right hold (a slow click now calls a cloud instead of snapping), the drift and thinning, and the demo's place and timing. The cloud forms at the hand's depth (about 34 m out in the default view) at 0.57 the size, so it may sit in front of far mountains, or low beside the plate when called below the horizon.
- **Re-called elsewhere.** A cloud still in the sky flies straight to the new pinch as it re-forms. It is a fast move for a large thing.

- **Unseen.** Nothing has been rendered: the cloud's look beside the Fidelity sky and fog, the Pinch clips' read on a cloud, the neck, the tear, the drops' arc, and whether the hand at the cloud's depth (about 65 m out) reads too small.
- **Placement.** It is fixed to the far side. Close up, or in a low view, it may be off screen or behind a mountain. How it should follow a close camera is open.
- **The tuft stays at the cloud's depth** while carried. On screen it is under the pointer, but in the world it is far behind the land until it flies into the ball.
- **Weather.** Rain and a snow-globe shake do not refill it yet, and it does not rain.
- **Seeds, unseen.** The flick's burst from the crown, the throw's reach and loft, whether a third of a bend is the right least, and the wild tree's place on the plain.
- **Ready shows on hover.** The tree under the pointer gets an outline (scripts/tree_outline.gd): gold when its spores are ready, pale straw while it rests. Nothing shows it without hovering. The outline is an inverted hull that does not follow the wind sway, so in a strong wind it sits a pixel or two off at the crown.
- **Seeded worlds in probes.** On a `--seed` world the places screen holds the world (`places.holding`), and the hand is unavailable, so the probe uses the plain and its wild tree.
- **No sound** for the stretch or the tear.
- **Stale tools.** These still get their water with the old sky drag, which now makes none: `tools/probe_water_flow_modeless.gd` and the films `film_everything.gd`, `film_edge_fall.gd`, `film_hand_world.gd` and `film_water_flow.gd`. They want to pull from the cloud instead (`probe_sky_cloud.gd` shows how). Anything that expects the cloud to be in the sky at rest now needs `--always-cloud`, or a summon first (`probe_summoned_cloud.gd` shows how); anything that presses empty sky after about 4 s may meet the demo cloud unless it passes `--no-cloud-demo`. Suite tests were not run (deferred during the scenic pivot).
