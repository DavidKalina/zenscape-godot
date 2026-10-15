# The Bearers' Underway — "They carry the dead over the top. The living go by the shelf beneath."
Lenses: verb STAY HIDDEN · mood OPPRESSIVE/SACRED · shape A HANGING UNDERSIDE · purpose PROCESSIONAL WAY · decay still working (the road is in use) · scale colossal

Pitch: You come out of the city onto a landing and see the Way: a causeway of battered piers, 160 m of it, running level into the haze as a comb of identical shadows, its deck lit by a row of cressets and slowly crossed by the black silhouettes of headless bodies walking in file. Nobody is meant to cross it from below, and you do: down a pier stair to a shelf of stone under the road's lip, where the firelight never reaches and every footfall above you is the sound of the next ten metres.

Place:
- **Landform.** Two shores 158 m apart (six spans, `CityKit.SPAN` 26.4 m each) over a haze with no floor. The near shore is a landing slab; the far shore is a blunt tomb-mound, a stepped hill with one small door and a dim cresset crown (the Way's end; the dead are carried in). The gulf is unlit and open: no wall either side, just the piers going down 48 m (`CityKit.PIER_DROP`) into brown nothing.
- **Arrival view.** From the near landing's lip, at deck height, looking along the axis: the deck is a bright bar (cressets every second parapet, tinted warm, `maker_cresset`), and under it a repeating dark: six pier shadows, each a battered wedge with a corbelled opening (3 courses, each stepped 1.0 m in and 1.6 m tall, `CityKit.CORBELS`/`CORBEL_STEP`) black as a mouth. Bodies walk the bar, one every span or so, small as ants at 140 m, their shadows swinging down the haze. The tomb-mound at the end holds the eye. Nothing about the top invites you; the underside is the only part with a way in.
- **How it sits.** It is not ruined. It still works, which is the horror: the road is swept, the lamps are tended, and the only break is a tooth missing from the shelf below (the shelf nobody walks). Overgrowth is minimal (cold, dry lichen on the girder soffit, hanging mats of root where the haze condenses). Stone is the city's weathered basalt, not painterly sky-kit stone; the talud under tablero piers carry a rune frieze at pilot eye height: the carvings of a procession, small figures bearing a bier, repeated at every pier so you always know where you are.
- **The shelf.** The deck's girder (`DECK_THICK` 3.2 m) is stepped in at its foot: its lowest course sits 1.0 m inside the deck's edge, leaving a **shelf** 1.0 m wide on each flank, 1.6 m (one `SET_OFF`) of headroom under the overhang. From the deck you see only the lip; from a body's eye line (neck 6.7 m, so ~8 m up on the centre lane, 5 m in from the edge) the shelf is under the girder's own shoulder, blocked by stone.

Top (ASCII, 1 char = 4 m; the whole Way compressed, near shore left):
```
   near landing                     the Way (6 spans, 158 m)                 tomb
 ┌─────────┐   p        p        p        p        p        p        p   ┌────────┐
 │ 1  [..] │===o=======o=========o=========o=========o=========o=========|  2  A   │
 │   @  ^^ │   :        :   (bay) :        :  (bay)  :        :         │   ##@   │
 └─────────┘   :        :   ~~~~~ :        :  ~~~~~  :        :         └────────┘
   '.' shelf (both flanks, under the deck)   '=' deck, cressets and bodies  'o' bodies
   p = pier with landing slab on its flank   (bay) = breakable bay over a landing
   ~ = gulf    @ landmark    ^ rim    A arena (the tomb door's apron)
```
Side (the cross-section at a pier, then a span):
```
 deck + parapets      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      bodies walk here, y 0
 girder shoulder      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓      y -3.2 (DECK_THICK)
 shelf (1.0 m)   ▒▒▒▒                             ▒▒▒▒      y -4.8  headroom 1.6
 cornice course   ═══                             ═══       y -6.4  (a lip to hang from)
 landing slab    [6x6]  at a pier flank, shelf level        y -4.8
 pier             ║ ║  battered, down 48 m into haze
```

Play:
- **Route A, the shelf (hidden, slow).** Descend the near pier's service stair (`city_stair`-style flights, or a drop onto the first landing: a fall stun-free if it lands the course below, `COURSE` 4.8 m), step onto the shelf. Crouch-creep it: sneak footfall is 1 to 1.5 m of hearing, a walk is 4, a run 14 (noise-stealth-round1.md). A bay of 26.4 m at the sneak pace (1.9 m/s) takes ~14 s; the six spans, ~85 s with the stops. The shelf is under the girder's shoulder, so the body's sight can't reach you through the stone, and the dark (`sight_dark_range` 0.4) cuts what it sees past that. What hunts you is sound: a body overhead within 4 m hears a walk, within 14 m a run, a grab at 6 m, a wall kick at 8 m.
- **Route A's gaps.** Every second span the shelf is torn away for 4.4 to 6.6 m (one to 1.5 `BAY`). Three ways over: (1) **shimmy** the cornice course 1.6 m below the shelf's level: drop-hang from the shelf's edge (`HANG_DROP` 0.825 under the lip), then 0.7 m/s hand over hand, ~9 s for a 6.4 m tear; silent (a grab is 6 m, the shimmy itself nothing), but nothing to do if a bay drops while you hang; (2) **long jump** the tear from a run-up on the shelf (a long jump needs a run (`LONG_PACE` 3.0 m/s, 7.6 m/s at its best) and the shelf gives only the span's 19 m of run-up, so a 4.4 m tear is a plain long jump and a 6.6 m one needs the chain or the twirl): loud (takeoff 4 m, landing 5 + 6/m fallen = ~14 m at the shelf); (3) **climb out** by a pier's corbel courses (1.0 m steps, 1.6 m tall: one jump catches each, `GRAB_TOP` 1.875) to the pier's landing slab on the flank and cross the tear on the slab's far end. Quiet and slow, or loud and quick, or exposed on the slab.
- **Route B, the deck (loud, fast).** Climb the corbels up the pier flank at the near shore (or the stair) onto the deck and run the lane: 158 m at run 4.8 m/s is 33 s. A body is seen as soon as it turns; this is the fight-or-flight crossing, with long jumps over the bays (a bay's middle third is 8.8 m, the very gap the body leaps and the wanderer long-jumps with a chain of two). You will be chased; the answer is the parapet (a set-off tall, a grab) and the edge: hang the flank (`HANG_DROP`) to get below the eye line and drop onto the shelf below, which the body can't follow (shelf is walker-only).
- **Route C, the switch.** A mid-Way pier has a landing on its flank with a cresset and a niche (a `city_niches` hide): a place to wait out a body that has stopped to look. This is the only place on the shelf route where your cover is stone and a lamp, not just dark.
- **The choice.** Quiet-and-slow (shelf, shimmy) or loud-and-quick (deck, jump). Both are readable from the landing. What the player learns across a run is the bodies' circuit.

Threat: **the bearers.** Headless bodies that walk the Way in a slow file, set up as a patrol along the deck (`HeadlessBody` roaming along its lane: `LANE` 8.8 m, deck 11 m). They never leave the deck unless they hear you; then one goes to look: it walks to the nearest point above the noise and, if it has a landing slab below within `drop_max` (about 22 m), it **drops** onto the pier's landing slab, shockwave rolling out along the landing and breaking the loose shelf-edge cornice. A body stopped over a bay for its `weight` stands on the bay; the bay's tell is a crack and a trickle of dust (`FloorBreak`), then the bay goes and the body drops with it onto the slab. The shockwave works on the grounded in its band (`shock_band` ~1.9 m vertical, `shock_air`), and the shelf is walker-only, so **you are not thrown while on the shelf, but you are on the landing slabs** and the slab is where the pilot is exposed. That is the whole tension: the shelf is a refuge, the landing is the cost, and the landings are where the bodies come down.
Tool: a body that dropped is on a 6 x 6 m slab 22 m down from where it stood; you can climb the corbels past it up to the deck and run while its patrol is short a member. A bay that breaks lets you through to the top without a climb. Shockwaves from a landing on the next slab down the Way arrive as a throw if you are on the slab: the shock shoves you outward (`shock_out` ~10 m/s) over the gulf, where a cornice lip catches you hanging (a free grab) or the haze does not.

Could combo:
- A body drops onto a landing as you cross it: the shock shoves you off the slab edge; the cornice course below is the catch (airborne -> grab, `GRAB_TOP`). Or you ride the shove across a tear in the shelf. Neither is a line; both happen because the shelf and slabs are within one shock radius (`shock_r` 4 Hh, about 18 m) of each other.
- Two bodies come to look at one noise from opposite ends of a span; the bay between them takes both their weight and goes; a body falling onto a body is whatever Jolt says.
- A beacon (`Beacon`, scripts/enemies/beacon.gd) lit on the far end of the shelf draws a body to the far pier and clears the near one: a cresset you tip (it tips if barged, `maker_cresset`) for a diversion.
- Ports in: a body thrown or knocked in from the neighbour isle lands on the deck and becomes a bearer. Ports out: a pilot knocked off the shelf lands on the cornice, then the pier landing below; below that, the haze.

Mystery: Whose dead? The frieze at every pier is the same procession with one more figure each pier (a headless one, then a headed one, then the head floating over a bier). The tomb-mound at the end has a door scaled for the walker, not for them. The bearers walk to it and walk back and have never gone in. Something in the mound is still being fed.

Kit used (all verified in code):
- `city_causeway` (scripts/city_kit.gd; opts `spans`, `bay`, `drop`, `end_piers`) for the deck, corbelled piers, the breakable bay (`FloorBreak`).
- `city_pyramid` (scripts/city_kit_landmarks.gd) as the tomb-mound, reskinned as a stepped mound, summit door.
- `city_niches` (scripts/city_kit_refuges.gd) for the landing-slab hide.
- `maker_cresset`, `maker_runnel` (scripts/city_kit_fires.gd) for the deck's lamps and the oil line of the procession.
- `city_lip`, `city_terrace` (scripts/city_kit_climb.gd) for the pier-flank hauls and the landing slabs.
- `scripts/walker_only.gd` for the shelf; `FloorBreak` (scripts/city_breaks/floor_break.gd) for the bay.
- Greybox `city_landing` (scripts/kit_isle/greybox/registry.gd) as the near shore.

Kit asks:
- `city_causeway` option `shelf` (family city): the girder stepped in at its foot into a walker-only 1.0 m shelf each flank, a cornice course 1.6 m under it, torn stretches with their gap length as a knob. Core ask, medium: procedural.
- `city_landing_slab` (family city): a 6 x 6 m slab hung off a pier flank at shelf height with a corbel step up from the shelf and a drop stair down; body-sized, walker-passable, breakable seams. Low to med.
- `maker_frieze` (dressing): the procession relief, one panel per pier, repeating. Low (texture/relief on the pier face).
- To check, not build: `headless_body.gd _shock_meets` only throws a pilot whose feet are within `shock_band` of the wave; confirm a hanging pilot reads as out of band.

Family knobs:
- `spans` 4 to 6 (106 to 158 m).
- `torn` 1 to 3 of the shelf's gaps (4.4 to 6.6 m); the long ones need the twirl.
- `bearers` 2 to 4 on the deck, and their circuit (end to end, or a loop with a gap).
- `lit` 0.3 to 1 (how many cressets are lit on the deck; the dark under the deck is constant).

Sockets:
- rim: the near landing (facing the Way, +Z of the piece) and the tomb apron (facing back).
- arena: the tomb apron (the 20 m square before the door; a body waits on it).
- cover: the pier landings (`city_niches`), the corbels (stone on three sides), the parapet.
- perch: the cresset plinth on the deck's mid-point (a body's lookout, and a tool: tip it, draw them).

Generator fit: **a crossing between two places (an edge)**. A level causeway, 106 to 158 m long (4 to 6 spans), height drop ~0 to 4.8 m (one `COURSE`, at the landing stair); it needs piers that go down into haze, so only on a layer with a floorless gulf (the city's "under" world; scripts/roguelike/city_crossings.gd's causeway beam is the short version this replaces for the far edges). The isles must be 110 to 170 m apart; it is a long-edge motif, not a short hop.

Distinct from: the aqueduct crossing (crossing_viaduct.gd) and `city_causeway` as `city_crossings.gd` places it (a deck you run along and a bay that breaks). That one is run on top. This one hands the top to the Olmec and sends you beneath it. Nearest greybox: `felled_colonnade` (also a long colonnade-like thing); not this: the road here is intact and the threat is above it.
