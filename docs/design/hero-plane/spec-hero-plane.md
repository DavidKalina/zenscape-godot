# Spec: the hero plane (loop `hero-plane`)

The player's plane in endless flight stops being the code-built plump biplane
of `scripts/plane_figure.gd` and becomes an authored, textured model with the
same care as the pirate ship (`art/blender/ship/ship_build.py`). Its engine
idle on the title screen is redone. The user's words: it looks too simplistic,
too basic, like a toy; it should fit the world's aesthetic, with more detail
and more quality; the title's vibration animation needs to be something
polished. Skins for anything else are out of scope.

## Done looks like

- On the title, close up on the meadow, and in the chase camera, the plane
  holds up beside the ship and the land. It has real proportions and real
  surface: doped fabric over ribs, panel lines and fasteners on the metal,
  wear where hands, oil and exhaust would put it.
- The title's idle reads as an engine catching and running, and nothing
  shimmers or jitters.
- Flight, landing, the camera, the wind and everything sized off the plane
  behave exactly as before.

## Holds (do not change)

- It stays a biplane, and the same size: `SPAN` 1.4 toy units, lower span,
  wing heights, prop position, wheel contact and tail skid
  (`scripts/plane_strip.gd`, `PIVOT`), so `scripts/world_scale.gd`, ground
  scale, landing and the camera need no change. Nothing in the flight model
  moves. Toy units stay the model's units.
- `PlaneFigure`'s public face stays (`update`, `reset`, `park`, `shift`,
  `hum`, `rev`, `sway`, `set_wear`, `paints`, the mark and the vapour, the
  vapour's wingtip anchors). Callers don't change.
- Traffic planes keep the old code-built figure. Only the wanderer's own plane
  (no livery passed) gets the new model. Don't delete the old builder.
- The shop's paint liveries (`scripts/endless/shop_stock.gd`: body, dark, trim,
  wing) must keep working on the new model: mask the painted textures so those
  four colours tint it. No new skins. Worn (`set_wear`) keeps working.
- Colours stay the plane's: terracotta body, cloud-cream wings, sea-teal trim,
  brass, from the land. Deepen them with paint variation and wear; don't
  replace them.
- Stylised, not photoreal: the user rejected photo-textured rock as too
  realistic. Painted textures, generated in numpy as the ship's are, no
  photographs. No outlines or toon ramp; nothing in the world has them.
- Lit by the world's convention: no ambient, the sky's hemisphere as emission
  (`shaders/folk_surface.gdshaderinc`, `shaders/plane_surface.gdshader`, and
  `assets/models/pirate_ship/ship_surface.gdshader` for the textured form).
  The land's zs_palette globals and moods must reach it. Judge it at PC
  fidelity: keep the detail and depth, don't calm it down.
- No pilot is shown. The cockpit stays closed over, by a framed, glazed canopy.
- The in-flight prop blur stays a disc of air; it may be improved.

## The model

- Build script `art/blender/hero_plane/hero_plane_build.py` (self-contained,
  as the ship's is; run with `tools/blender.py`), exporting a glb and textures
  under `assets/models/hero_plane/`. The existing `art/blender/plane/` is old
  concept work: look at its renders for ideas, don't build on it.
- Moving parts are separate named nodes with hinges at the right places:
  propeller, ailerons, elevator, rudder (static today; it may follow yaw/roll),
  wheels. Also the parts the idle needs (cowl and engine vibration, see below).
- Detail to reach for, scaled to the toy units: a slimmer fuselage with a
  stringer-and-fabric rear and a metal forward section, a proper engine cowl
  with exhaust stubs, thinner wings with visible ribs and rib tape, real wing
  tip shapes, interplane struts with flying and landing wires, cabane struts,
  control horns and cables, a spoked or disc wheel with a tyre, a sprung
  undercarriage, a fuel filler, stencils, a roundel. Pick what reads; add no
  part only for the count.
- Wires and fine parts must not shimmer or crawl at chase distance. Test it in
  motion, and fade or thicken them with distance if they do.
- Budget: about 40k triangles or under and about 15 draws or under, for the one
  plane. Measure both. Check the cost rendered: a flight on the old and the new
  plane, with the frame rate compared at the same spot.
- Assess `docs/art/model-budget.md` and list what applies in the handoff
  (AGENTS.md, Models).

## The idle (title screen)

The cause to confirm first: `_idle` in `scripts/plane_figure.gd` shakes the
whole plane as one rigid body with sines at 17 to 29 Hz, which at 60 fps alias
into a digital shimmer. Measure what it really does per frame. The spec's aim
stays even if the cause proves different.

- No whole-body high-frequency shake. Below the frame rate's limit, use noise
  rather than stacked sines, and let the motion be time-based so it holds at any
  frame rate.
- An engine has a sequence. Keyed by hand, by eye: the prop swung by the
  starter, a few uneven compression kicks with the plane rocking back against
  them, a cough of exhaust smoke, the catch, a settle down to a steady idle.
  The runs from `ENGINE_AT`/`ENGINE_UP` in `scripts/endless/menu_stage.gd`
  may lengthen if the sequence needs it. Match it to the engine sound where
  the sound is driven (find it; say in the handoff if it's a mismatch you
  can't resolve).
- The energy moves through the plane: the nose and cowl tremble most, the
  undercarriage's springs and tyres take the rock, the wing tips, wires and
  control surfaces follow late with their own settle. Secondary parts on simple
  springs rather than more sines.
- A running idle that lives: small exhaust wisps and heat haze at the stubs,
  grass laid back behind the prop if it's cheap, a prop whose blades still read
  at idle instead of strobing.
- The run-up on the brakes (LEAVING) and the takeoff roll strain and build from
  it, nose down and tail light, as a change in the same system.
- Hum is 0 in flight today and stays so. If a little in-flight life on the
  parts comes free (wing flex, wires), keep it subtle, and leave the flight's
  feel alone.

## Stages (the trunk; there are no lanes, every stage touches the same plane)

1. The model in Blender with its painted textures. Stills in the game's look.
   **The loop pauses after this stage for the user's call on the look.** Put
   your concept stills side by side with the current plane.
2. In the game: the wanderer's plane uses it, parts wired, shop paints and wear
   work, the plane in the title, chase and on the wheels.
3. Fine-pass of look in the game: read at chase distance, wires, frame cost.
4. The idle: start-up sequence, running idle, run-up and roll.
5. Polish and the handoff.

## Checks

- Smoke: `studies/endless_flight.tscn`, `studies/flight_study.tscn`,
  `studies/ruin_kit_gallery.tscn` (`tools/smoke.py`), with a game that uses
  `PlaneFigure` still working.
- Stills with `tools/shot.py`, or `tools/view_plane.gd --shots=DIR`, which
  shows the plane close and needs updating for the new model. Passing
  `-- --no-title` keeps the title out; for the title's own captures, leave it
  out on purpose.
- Motion can't be judged from one still. For the idle, write short rendered
  frame sequences and a contact sheet, plus per-frame numbers of the parts'
  motion, and step through them.
- A real play loop check (`tools/drive.py`) that flight and landing behave as
  before with the new figure.
- Report what headless can't prove, and don't claim rendered checks you didn't
  run. Save files and layouts the user made are work: build and drive on a
  throwaway save (`--pilot-file=/tmp/...`). No `git stash` in this worktree;
  the stash list is shared with the user's work.

Prototyping rules hold: no new committed tests and no full suite. The handoff
lists any existing test this breaks.

## Loop

Slug `hero-plane`, branch `iter/hero-plane`, worktree
`/Users/davidkalina/Documents/Projects/zenscape-hero-plane`. Cap and budget:
the skill's default. Model: Opus. Don't merge to main; the user judges it
by playing.
