# Handoff: heist tidy (branch `iter/heist-tidy`)

A prototype round of three fixes the user asked for after playing the heist
level (`studies/heist_level.tscn`, `run-heist.command`). They said: "Switching
between rope and bag sucked." "Loot is tiny and looks ugly." "Where I grabbed
the dragon egg isn't a good spot to spawn olmec."

## 1. No switching: the bag and the rope at once

He wears the bag and carries the rope together. What he is standing by, and
what he is aiming at, decides which one a key works. In the heist, H / D-pad
up does nothing now. The binding stays in `scripts/pad.gd`, and
`crag_reach --greed-run` still switches with it (`context_hands` is off there;
it's one line to turn it on).

| Key | What it does |
|---|---|
| E / B | Loot in reach: bag it. Otherwise it works the rope: tug a caught hook, tie the rope at a post you're by, hop off the wall on a rappel. |
| F / D-pad down | The bag lying by you: shoulder it, or drag it if it's too heavy. At the plane's rope hook: hitch it (press again to bank it). Otherwise, if the rope is out anywhere: reel it in. Otherwise: set the bag down, or let go of a drag. |
| hold LMB / T / RT | Goes to the rope if a swing point, a post above you, or a face too tall to climb is ahead (along his facing; for swing points and posts, the camera's view too). Otherwise it throws the bag. With the rope still on a swing point and another swing point ahead, it yanks the rope back and aims again. |
| While aiming | The aim moves between the two as the reticle moves. Onto a swing point's line (within 1 m), a post, or a tall face, it's the hook. Off those, it's a bag throw, if the bag is on your back and light enough to throw. A 0.12 s hold stops it flickering. |

A face counts as "too tall" by the face itself (from its lip down to the floor
at its foot, more than `RuinKit.CHAIN_TOP + 0.3`), not by the lip's height above
his feet. So the vault's three ledges are still bag throws, while `wall_01` and
`vault_n` are hooks.

The prompt line in the top left now shows what each key does where you stand,
for example "E bag the coins · F set the bag down · hold LMB/T aim the hook at
the swing". The foot hint says the same.

Code:
- `studies/crag_reach_greed.gd`: `key_for`, `rope_ahead`, `rope_wants`,
  `face_tall`, `aim_handover`, `context_text`.
- `studies/crag_reach.gd`: `context_hands`, `key_for()`, `_hands_text()`, and a
  call from `_want`.
- `scripts/carry/loot_bag.gd`: each key asks `study.key_for` (falling back to
  `bag_keys`). New: `aim_toward` and `aim_drop`.
- `scripts/rope/climb_rope.gd`: one hunk in `_read_input`, where each key asks
  `study.key_for` (falling back to `rope_keys`). Nothing else in the rope
  changed, so it should merge cleanly with the rope rework.

## 2. Loot that reads

There are new models in `scripts/carry/heist_loot_models.gd`, used only by the
heist: `greed_loot_model` in `studies/heist_level.gd`, through a host hook in
`Greed.build`. Other studies still use `bag_study`/`treasure_models`, unchanged.
The piece ids and kind ids are the same.

Each model is built in code from lathed outlines and primitives, merged into
one ArrayMesh with 2-4 materials and crevice grime baked into the vertex
colours. That is the repo's usual way for props.

| kind | kg | model | height m | tris |
|---|---|---|---|---|
| gem | 0.5 | sapphire cluster on a rock in a gold stand | 0.42 | 248 |
| chalice | 1.5 | gold cup with a knotted stem and ruby band | 0.46 | 864 |
| coins | 2 | open iron-banded chest heaped with gold, coins spilt in front | 0.50 | 2190 |
| idol | 3 | seated jade figure on a stepped gold plinth | 0.64 | 1734 |
| bar | 4 | six tapered ingots stacked 3/2/1 | 0.33 | 144 |
| urn | 6 | terracotta amphora, black band with a gold zigzag | 0.72 | 1336 |
| egg | 8 | teal scaled dragon egg with ember cracks, in a gold claw cup, plus a small warm light ("Ember") | 0.82 | 2882 |

Model budget (`docs/art/model-budget.md`):
- **Applied: vertex-colour grime.** Crevice darkness at no texture or draw cost.
- **Applied: silhouette geometry.** Scales, claws, handles and coins are real
  geometry; flat faces carry no detail.
- **Cost:** about 9.6k triangles for everything placed. One mesh per piece, 2-4
  draws each. Frame time is negligible.
- **Not worth it:** sculpt-and-bake (it would add triangles, not save them);
  bones (nothing is skinned); parallax (no textures).
- **Later, if wanted:** visibility ranges or LODs on the coin chest and the egg
  would save about 2k triangles each past 25 m, under 0.05 ms.

Seen: in deep shade the gold reads dull rather than shiny. The bar stack reads
as one gold block from the high camera.

Stills: `scratch/look/loot_row_final.png`, `loot_row_far_final.png` (about
14 m), `loot_close_*_final.png`, and `loot_play_*_final.png` (in the level,
game camera). Driver: `scratch/loot_look.gd`.

## 3. The Olmec's new start: `heist/olmec_start`, leaping to `heist/olmec_leap`

He no longer comes up by the chest. What happens now (`_hold_far` in
`studies/heist_level.gd`):
1. When the egg wakes the isle, you only hear him: "Far off, stone grinds on
   stone...".
2. `HEIST_COME_AFTER` (6 s) after you're up the ledges onto vault_s's crown,
   he climbs the far east face of vault_e, the tower mass behind the court
   (`heist/olmec_start`, about 38 m from the chest). If you're still in the
   court, he comes anyway `HEIST_HOLD_MOST` (90 s) after the wake.
3. He hauls over high across the court, then leaps down onto vault_s's crown
   by its east lip (`heist/olmec_leap`, about 20 m from the corner swing's
   rim). If that spot's arc is blocked, he tries spots around it.
4. From there he comes for you while you rig the corner swing.

`swing_02` joins the rig holds (no pounce or suck for up to 8 s while you rig).
At swing_02, only a pounce is cancelled, not his leap across.

If he falls before his leap, he comes back up `olmec_start` rather than the
crag's pick, which had picked the old court lip.

From the pillar on, nothing changed: the staged drop still moves him to the
perch.

The old `heist/olmec_up` token is gone; no saved layout used it. The
`olmec_wall` block still stands on the court's west face.

Tried and dropped:
- vault_sw round the corner: waiting there, he walks off the corner and falls,
  and the rock spire blocks his leap across.
- The spur and the gate: their faces aren't clean, he falls, and the crag's
  pick brings him back up the old court lip.

Known: the play camera looks ahead (west), so you hear him come up and see him
when he lands, not while he climbs (`scratch/look/olmec_start_*.png`). The
start face logs "isn't clean" as a warning, but he hauls over fine in every
run.

## Proved (throwaway drivers in `scratch/`, ledgers in `/tmp`, uncommitted)

- **Smoke (headless):** `heist_level --no-title` and
  `crag_reach --no-title --greed-run`: 0 errors.
- **Full run from the real start, real input** (`scratch/heist_full.gd`, a
  copy of last round's driver; it never presses H, since its `hands()` only
  waits the old switch's beat to keep the route timing):
  - Banked 175 (coins, dragon egg) in 4:07, 69/69 checks.
  - That covers rope and bag with no switch: rappels, hook climbs, swings,
    bag throws up the ledges, F reels, F hitches.
  - The Olmec came up `olmec_start` 61 m away and leapt across.
  - His closest approach on the vault/crown leg was 20.7 m (at the old spot:
    18.6). Pillar 7.7 m, gap 4.9 m.
- **Stalls (headless):**
  - 10 s on vault_s's crown: caught (thrown off).
  - 8 s, no brood: caught.
  - 15 s at the gap: lost.
  - Standing in the court with no brood: not caught within 130 s. He comes at
    90 s and is slow to come down the steps; with the brood there, the court
    has its own pressure.
- **Hand-over through real input** (`scratch/ctx_handover.gd`):
  1. At gap_near the throw starts as the hook (swing_03 overhead).
  2. The stick takes the reticle onto gap_far and the aim becomes the bag's.
  3. Released, the bag lands across (10 kg).
- **Prompts** (`scratch/ctx_hint.gd`): printed at a post, loot, swing_01, a
  step and the gap; see above. The rendered window still didn't show the
  top-left HUD layer, so the label's look is unverified.

## Existing tests

None of the tests reference the changed code (`grep tests/`). The full suite
was not run (prototype round).

## Open

- Whether the far start's timing feels right in play (`HEIST_COME_AFTER`,
  `HEIST_HOLD_MOST`), and whether to show him (a camera beat) as he leaps.
- Swing_01's landing is still timing-sensitive (a few frames' difference
  landed him short in one run; out of scope, rope feel).
