# Serpent route (handoff)

Branch `feature/serpent-route`, from `main` 3ecaabec. Not merged and not
pushed.

This round tests whether you can hop between isles without the plane. The rune
serpent now flies a fixed loop through region one: the aqueduct isle and three
of its motif isles. At each isle it passes low and close beside a ruin-kit
ledge, and you can ride it on foot in the real game.

## Launch

    godot --path . -- --no-title --serpent-board=home     # on the aqueduct isle's ledge, it coming
    godot --path . -- --no-title --serpent-board=tarn     # also nave, gorge (or aqueduct, cloister_tarn, drowned_nave, sundered_gorge)
    godot --path . -- --no-title --serpent-old-route      # the old long way, no ledges, no riding
    godot --path . -- --no-title --serpent-at=gorge       # the serpent's own flag: start it at a mark

`--serpent-board=` skips the title like `--place=` does. It stands you on the
ledge's terrace facing its way, with its head 45 m short of the ledge. The head
goes by in about 5 s and the middle in about 10 s. Run off the end and jump as
the middle passes.

## The route

`scripts/kit_isle/serpent_route.gd` `ROUTE` is a closed cubic B-spline through
42 control points. It is **1658 m round. A lap takes 156 s (2.6 min) at
10.6 m/s on average**: cruise is 12 m/s, and it slows to about 10 m/s past each
ledge (pace share 0.75 plus its surge).

It runs east-about from the aqueduct isle:

| Mark | m | What |
|---|---|---|
| `home` | 94 | East along the aqueduct isle's south rim, past the ledge at its south tip. |
| `dip` | ~370 | Out south-east and down in a long dip toward the cloud sea (the head's lowest is -12 m, about 25°), then up again. The start mark. |
| `tarn` | 538 | South past the cloister tarn's east rim and its ledge. |
| `nave` | 921 | West under the tarn, across to the drowned nave, and past its south tip and ledge. |
| `gorge` | 1262 | North up the nave's west side to the Sundered gorge's south mouth, past the ledge on its west lip. |
| `thread` | ~1330 | Up over the rope bridge and down the gorge's length between the rims (the old way's thread, a little lower), out of the north mouth and east home. |

It runs straight and level past each ledge for about 40 m:

- four or more control points in a line;
- weave share 0.1;
- `look_share` 0.1 within 100 m of the ledge, so its head stays on its way.

Its tube is clear of every isle's rock and ground (girth, weave, veer and
heave all at their most). It keeps clear of the airships' loops by 21 m past
its reach, against a ship's 15. Everything is in the south and west, far from
the lodestone's shard and the hall chain.

I picked these isles because the loop is compact and has variety. It has a
dip, an over-water leg, and the gorge thread, which is the one real threading
moment. The bell spires, hollow keel and others stay plane-only for now.

## Boarding ledges

Each ledge has two parts:

- **A terrace:** a heavy worn slab, 6 m along its way and 3.6 m out, on two set-in courses of masonry. It juts past the rim.
- **A stair:** a flight of the kit's steps (`RuinKit._flight`, 2.4 m wide) climbs to it from the turf, toward the serpent.

There is no HUD marker. You read the spot from the stair and the jutting
slab.

Each ledge is laid off the serpent's own way at its mark:

- Its end is 0.9 m off the widest flank (the head's jowls) at full weave. That is about 1.2 m off the back's flank where riders stand.
- Its top is 0.4 m under the back's crest there.
- Rays fit the flight's foot to the turf. A motif isle's ledge is built once that isle is up.

| Ledge | End (world) | Steps | Spine from end | Crest vs ledge |
|---|---|---|---|---|
| home (aqueduct, south tip) | (63.0, 31.3, 28.9) | 5 | 4.22 m | 0.27 m under |
| tarn (cloister tarn, east rim) | (99.1, 32.2, 374.0) | 3 | 4.18 m | 0.29 m over |
| nave (drowned nave, south tip) | (-231.0, 31.4, 401.3) | 2 | 4.32 m | 0.41 m under |
| gorge (Sundered gorge, west lip at the south mouth) | (-310.3, 39.8, 117.4) | 9 | 4.53 m | 0.66 m under |

**Why the ledge sits level with the back, not above it as the greybox tower
did.** The motor's jump is only 0.8 m high. The tower stood 1.2 m over the
back, which is fine for jumping down onto it, but you can't jump back up to it.
Level means:

- **Getting on:** a hop across about 1.2 m onto its shoulder.
- **Getting off:** a jump from the flat top's edge, with a twirl (X) as it tops out, or the sail.

The terrace's 6 m span gives about 0.6 s of back going by.

## Riding in the game

`scripts/kit_isle/serpent_rider.gd` is the greybox's riding, brought in
whole: `studies/serpent_back.gd` hulls, `PilotMotor.carry`, the carried
camera with `CAM_TURN` sway, the air frame, the eased roll while ridden, and
the glances back.

### What changed from the greybox

- **Hulls are live only within 40 m of you, or while you're on it.** Otherwise they're out of the world, and its own capsules stand in for the plane. When the hulls are live the capsules are off (`RuneSerpent.set_solid`). Cost is about 0.7 ms a frame while live, measured headless, and 0 otherwise. The hull build is the same as the greybox's; I didn't simplify it.
- **Ordering uses process priorities rather than a scene `tick` override.** The serpent runs at -101, the rider at -100 (it reads what you landed on, lays the hulls and carries you), then the scene at 0. `kit_isle.gd`'s body is untouched.
- **No fade back onto it.** When you fall off, the game's own fall takes over (`kit_isle.gd` `_check_step_off`): Space opens the pocket sail, you walk on if you land on something, and otherwise you're stranded for 3 s and set back beside the parked plane.
- **The air frame fades.** You keep the velocity you left it with while you're within 6 m under where you left, so a jump comes back down on it. Past that, or once the sail is open, it fades over 1.5 s (the greybox kept it forever).
- **`lost` is set aside.** While you ride it, and while you're falling from it, the scene's respawn floor (y 5) is ignored, because the dip runs under it. Stranding is the net.
- **Girth is 1.5× in the game too.** It's 6 m through, so the serpent now looks fatter in the game sky.
- **New `rune_serpent.gd` hooks:** `look_share` and `set_solid(on)`. Both default to unchanged behaviour.
- **No motor changes.** `carry` already existed.

### Other changes

- `aqueduct_isle_sky.gd`: the route node is used when the motif isles exist, unless `--serpent-old-route`. That flag gives the old serpent exactly as before.
- `front_door.gd`: `--serpent-board=` skips the title.
- `tests/test_rune_serpent.gd`: now runs with `--serpent-old-route`, since it checks the old way's marks, gorge and pacing. The new route is checked by its own test.

## Tests

`tests/test_serpent_route.gd` runs headless and passes. It checks:

- the route is the default, links four isles, and its tube is clear;
- the airships' loops are clear;
- a lap takes 156 s;
- every ledge stands, is passed within a jump, and is never touched by the body;
- standing still on each ledge through a pass, you are left alone;
- from the home ledge, a running jump as its middle passes lands you on its back at 28 m from the snout;
- you stay on its back for all 40 s through the dip (down to -10 m) to the tarn, with `lost` set aside;
- alongside the tarn, a jump plus a twirl lands you on the tarn's terrace;
- walking off over open sky gives the game's fall: off the edge, stranded, then back beside the plane after 5 s;
- `--serpent-old-route` gives the old way.

I also ran the import, the headless load of `res://studies/zenscape.tscn
--quit-after 300` (clean, plus with `--serpent-board=gorge`) and
`test_rune_serpent` (passes). I did not run the full suite.

`tools/serpent_route_survey.gd` holds the survey tools I used to lay the route:

- isle height maps (`-- [ids]`);
- the gorge in section (`-- gap`);
- the route report: ledges, tube and lap (`-- route`).

**Rendered captures.** In the home sequence the serpent passes the ledge
cleanly. Before the 100 m look hold, its snout, turned to look at the rider,
swept him off the ledge; that is now fixed and covered by the test. The gorge
wide shot shows the stair and terrace reading well against the gorge.

## What's weak

- **Nothing was played by hand.** The jump timing, the camera's sway, and whether getting off at 10 m/s is fun or fiddly are all unverified.
- **Getting off onto a ledge is a skill move.** You need a jump plus a twirl, or the sail, and you have to lead it by about 10 m because you carry its 10 m/s. Landing on the rim turf is longer still (about 7 m off the spine): use the sail.
- **The terrace slab draws as a plain flat box.** It's the kit's lean stone with no ivy and no chips on top. It needs an art pass. The stair reads fine.
- **The ledges are clean new pieces on old isles.** They aren't woven into each motif's own ruins.
- **Breath and banking.** The bank after a turn, and the 3% breath, make the pass vary by a few tenths of a metre. That is in the test's tolerance but not exact.
- **At the tarn the ledge is only 3 steps.** The tarn's turf is about level with its back.
- **No HUD hint while riding.** The foot hint stays the walker's.
- **The serpent is 1.5× fatter everywhere,** including when seen from the plane.

## Open questions

1. **The plane and the route.** Falling off sends you back to the plane, wherever it's parked. Should the plane be recallable to where you are? Or should the fall instead set you on the last ledge you left from? Right now losing the plane means walking home the slow way, which matches the brief.
2. **Riding with the plane.** Can the plane land on or fly alongside a ridden serpent? Its capsules are off while you're near it on foot, so the plane would pass through. That can't happen yet, because you can't be on foot and flying at once.
3. **More routes, or a second serpent?** One serpent means a 2.6 min wait at worst for it to come round. A second, half a lap apart, would halve that.
4. **Should it slow more by the ledges,** or wait (hover) a beat?
5. **Make getting off friendlier?** The frame you leave in could fade faster near a ledge, or the ledge could be longer.
