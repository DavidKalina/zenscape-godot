# Handoff: the rune knight (loop `rune-knight`)

Spec: `spec-rune-knight.md` (the mind) and `spec-rune-knight-body.md` (the
body lane, merged at 36a079f7). Trail: `git log --grep='^ITER(rune-knight)'`.
Branch `iter/rune-knight`, not merged to main.

## Play it

```
godot --path . res://studies/aqueduct_isle.tscn -- --no-title --rune-knight
```

Add `--ledger=/tmp/rk.json` to keep his rune and tokens out of the real
save (`--fresh-ledger` writes over it on the first take).
`--rune-body=standin` plays the block greybox body; `--rune-attack=lob`
the old lobbed ball.

## What's built

- **Him:** a stone knight 1.6 wanderer heights tall (`WorldScale.wanderer_tall`),
  the "bastion" build in the Olmec's stone (`art/blender/rune_knight/`,
  `assets/models/rune_knight.glb`, 43 loose pieces on 23 bones, 22 clips),
  behind a body API so the mind (`scripts/enemies/rune_knight.gd`) never
  touches the model (`rune_knight_body.gd`, stand-in
  `rune_knight_body_standin.gd`, procedural layer `rune_knight_rig.gd`:
  feet on the ground, head and chest on you, eye lit while he fights).
- **Patrol and sense:** walks the aqueduct's deck end to end; sees you to
  28 m; notices, tracks, gives up after 4 s out of sight.
- **Attack:** wind drawn into his right gauntlet as a blade, then a level
  (jump it) or high (sidestep it) slash throwing a crescent of air; a hit
  is the gust knock.
- **Tennis:** your X gust shot (or the Z stand-in, no charge) from in
  front he catches and slashes back faster; past his limit he misses.
- **Parry:** RB / Q 0.1 s before his wind reaches you absorbs it into a
  gauge segment, with hit-stop, camera punch and sound; no cue; a whiff
  holds you in guard 0.5 s and the hit lands harder
  (`scripts/wind_parry.gd`).
- **Riposte:** a parry makes him reel 1.25 s; X then can't be caught,
  cracks a rune and pops out that tablet's real glyph token.
- **Wear and deaths:** three runes (hands, chest), each cracked by a rally
  miss or a riposte; heavy skids; the brace (side hits teeter him at the
  lip, a second hit puts him over); a riposte never kills. All three dark:
  he kneels, the next hit crumbles him and his last wind bursts out
  (parry it for a full gauge). Off the deck: he falls and shatters. Off
  the island's rim: gone.
- **The leap:** down to the meadow when you're below, back up when you
  climb the deck, home when you're gone; the landing's ring knocks and
  can be parried.
- **Footwork:** walks in past 11 m, backs off inside 5 m, strafes round
  you between moves; along the deck only; off the strip, wall and rim.
- **At the plane:** led crescents at a flying plane within 90 m, a blade
  flare at the gather; a hit buffets it like the dragon's blast.
- **Ledger:** his core rune rises where he died; taking it marks
  `aqueduct_isle/rune_knight` (card row "Guardians") and he stays gone.
  His three glyph tokens are `aqueduct_isle/rune_knight_hand_l`,
  `_hand_r`, `_chest`; a taken one never spills again.

## Shared files touched (all additive, off without `--rune-knight`)

`scripts/updraft.gd` (asks the parry first), `scripts/pilot_figure.gd`
(guard pose), `scripts/lock_on/gust_shot.gd` (its balls readable as wind
shots, steering over a blocking lip), `studies/character_study.gd` and
`studies/kit_isle.gd` (the whiff hold), `scripts/kit_isle/kit_tokens.gd`
(tokens laid later), `shaders/olmec_stone.gdshader` (`split` knob, off by
default), `scripts/world_scale.gd` (`WANDERER_TALL`, `wanderer_tall`),
`data/ledger/ledger.json` and `ruins.json`, `studies/aqueduct_isle.gd` and
`aqueduct_isle_tokens.gd`.

## Breaks

- `tests/test_ledger.gd`: three places (lines near 99, 161, 166): the
  four new objectives, and the aqueduct isle counting 11 tokens with the
  flag. Not run (prototype rules); a lock-in round fixes it.
- The full suite was not run.

## Open (the user's calls)

- The card shows "Guardians 0/1" on the default isle, earnable only with
  the flag: hide it until he's on by default?
- A riposte from the front at the deck's far end skids him 0 to 1 m (the
  end is a wall). Proposed: make the end an edge he teeters on.
- His strafe is slow (0.29 m/s, the clip's pace); faster means re-timing
  the clip.
- His crescent at the plane is pale on clouds from the chase camera
  (`sky_far_width`, `sky_size`).
- His real slash leaves the blade 0.22 m right of the stand-in's; if his
  crescents shove you off the deck's side unfairly, move its spawn.
- Hands don't reach for a caught shot (the torso turns instead).
- 28.8k triangles; LODs carry him at range. Budget notes in the body spec.

## Not proven

- A token spilled on the meadow (no driver ripostes him there).
- The hips sinking for a foot over lower ground.
- The fight film's leap-up and slash-hit shots look past the island into
  cloud, and the parked plane hides the leap-down; retake with
  `python3 tools/drive.py scratch/rk19_film.gd --rendered --timeout 900`
  after aiming those cameras inland.

## Proof left uncommitted

The play-loop drivers `scratch/rk_*.gd` (list and commands in bd228a3a,
plus `rk_rig`, `rk_tokens`, `rk_steps`, `rk_foot`, `rk_sky`,
`rk19_film`), stills in `captures/shots/rk*`, the film
`captures/rk19/rk19_fight.mp4`. The `.uid` files for `scripts/lock_on/*`,
`wind_gauge.gd` came from main untracked and are left for main.

## Next

The body lane is done; the next round is the user's: play, then a lock-in
round (committed tests, the ledger test, the `--rune-knight` default and
the card row), or the next enemy through skill `enemy-build`.
