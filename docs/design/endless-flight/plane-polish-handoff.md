# Plane polish: no pilot, a new look, wingtip vapour, rumble

What changed
- `scripts/plane_figure.gd` is rebuilt:
  - The pilot and scarf are gone. The cockpit is closed over by a low tinted canopy behind the upper wing.
  - The same biplane is drawn plumper and plainer: a rounder body, a round cowl with no rivets, louvres or exhausts, thicker wings with smoother cloth, a pair of struts a side and no wires, a sturdier undercarriage and fat wheels.
  - The paint is from the land: a terracotta body, cloud-cream wings, sea-teal trim and struts, and a slate canopy.
  - It is smooth and glossy. The joined meshes get smoothed normals with a crease angle (`_smooth`, CREASE), and the paint gets a clear coat (`coat`, COAT_ROUGH) with less grime (GRIT 0.2).
  - The dead found-parts machinery went with the old model (`set_missing`, `set_found`, the damage, seat glow and ring; `scripts/plane_parts.gd` was already cut). `set_wear` is now immediate.
  - Traffic planes share the figure and its liveries, so they lose their pilots too. The livery's `scarf` key is dropped (`scripts/sky_traffic.gd`).
- Wingtip vapour: `studies/endless_flight.gd` `_pull_of` takes the flight path's turn rate (VAPOUR_TURN 0.7 to 1.5 rad/s), with more past cruise, and passes it to the figure's vapour. None shows on the wheels.
  - The trail is longer (40 points at 0.03 s, about 1.2 s), wider and softer, and grows with the plane's size. It eases in and out.
  - Driven: flying straight 0, a gentle turn about 0.06, a full turn about 0.66, a pull-up about 0.35 to 0.64, a boosted full turn about 0.92.
- Rumble: `scripts/endless/flight_rumble.gd` drives the pad only, through `Pad.pulse`. Nothing happens on the keyboard or with vibration off.
  - Knocks come from the landing's events: greaser, a touch that sticks, a thump by its k, bounce, slide and hit.
  - A hum runs under them: the wheels by ground speed and grit, Boost, a hard pull, and skimming within 4 m (× size) at cruise.
  - Nothing called `Pad.note` after the cut (the pause host did), so the game never knew a pad was in hand and the rumble stayed silent. `endless_flight` now connects it to the root's `window_input`.
- `show_pilot` is removed, along with its callers (endless_flight, endless_traffic, ruin_kit_gallery).

Proof
- Smoke: endless_flight, flight_study and ruin_kit_gallery PASS.
- Throwaway drive (`scratch/vapour_rumble.gd`, uncommitted): the pull values above, plus pad pulses in turns, boost and on knocks. Knocks fire at once, ring about 0.3 s and stop.
- Rendered captures (git-ignored):
  - `captures/plane_before/`, `plane_after1/` (faceted) and `plane_after2/` (smooth) hold the viewer's stills.
  - `captures/flight/` holds in-game turns with vapour, and `crops.png` the gloss close up.
- Not verified: a real pad's rumble felt in the hand.

Tests this breaks (for the lock-in round)
- `tests/test_glide_camera.gd:158` and `tests/test_sky_plane.gd:269` read `figure._scarf_points`, and the scarf is gone.
- `test_world_scale_guard.gd` and `test_ruin_kit.gd` still pass.

Model budget (docs/art/model-budget.md)
- The plane is now about 4.1k triangles in 13 draws. It was about 42k in 30 with the pilot's head, hat and scarf, so roughly 38k triangles and 17 draws are saved per plane, traffic included.
- Sculpt and bake, parallax, and vertex-colour grime don't apply: it is a smooth glossy procedural toy with no fine surface detail to bake.
- LODs: traffic already swaps to a posed far stand-in past 260 m, so a mesh LOD would save little.
- Rigid parts on bones: there is no skinning, so it doesn't apply.
