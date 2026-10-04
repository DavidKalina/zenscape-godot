# Footbridges

Started 2026-10-03 on `feature/bridges`.

A footbridge from the case: take it, drag across a stream, a narrow water or a gap in the land, and let go. A gap can be a ravine, a crater or the drop between two peaks. The terrain decides. The drag only says roughly where to cross. Over water, the bridge snaps from bank to bank. Over a gap, each end finds level footing at the rim. Both ends rest on the ground. Up to 6 m it is a timber arch; from 6 to 20 m it is a rope bridge. Where the land will not carry one, nothing is laid.

Mountain-to-mountain bridges were added 2026-10-03, at the user's request: "Bridges should be placeable on mountains and stretch from mountain to mountain if you so choose. Only if there's enough flat ground." They chose rope bridges for long spans and 12 m as the longest, then raised it to 20 m the same day.

## The rule

- **Water decides where.** The planner (`scripts/footbridge.gd` `plan`) walks the drag's line in 0.1 m steps, and up to 1.5 m past each end. Water is live water at least 3 cm deep (`scripts/water_flow.gd`), a pond's surface, or a stream bed's course (the same three sources `scripts/life_survey.gd` reads). From the wet sample nearest the drag's middle it walks out both ways to the water's edges, then 0.45 m further onto each bank. Those are the ends. A rill narrower than that still gets a 1 m bridge.
- **Or a gap decides.** A drag counts as crossing a gap when the ground under it falls at least 1 m (`GAP`) below the line between its ends (`depth_under`). Each end then looks along the line, within 1.5 m of where the drag began or ended, for **footing** (`footing`, `_seat`): a 0.8 m by 0.8 m pad, dry, level across the line within 0.2 m, with nothing in it more than 0.2 m above the end. Toward the gap the ground may fall away. Behind the end it may fall by at most 0.4 m over half the pad (`SEAT_FALL`), as a crater's rim falls away outside its crest. It takes the highest such seat, and of those within 0.1 m of it (`SEAT_TIE`) the one furthest toward the gap. So over a crater each end climbs to the rim's crest and the bridge hangs over the bowl, rather than settling on its floor or walls (the user, 2026-10-03: bridges "tend to connect within a crater, and not over a crater"). On a plateau the bridge starts at the rim and not back from it. Between the footings the deck must clear the land. Over its first metre it may rest on the ground, sunk at most 3 cm, as an end rests on its sill. A drag read as a gap keeps the gap's refusals: a drag from peak to peak never drops to a little bridge over the stream far below. The exception is a stream in a shallow valley: if the water's bank-to-bank bridge spans at least half the drag, that bridge is laid instead.
- **Refusals.** Nothing is laid when there is no water and no gap near the drag (`dry`), when the span would be over 20 m (`too_long`), when an end of a gap has no level footing (`no_footing`), when the land rises into the deck (`blocked`), when the banks differ in height by more than 0.35 of the span (`too_steep`), when an end is off the land or in water (`edge`, `no_bank`), or when the water stands as high as the deck's underside (`flooded`). The hint line names the reason in a few words.
- **Feedback stays quiet.** While dragging, a ghost of the bridge shows: warm and faint where it would go, dull red along the drag where it would not. There is no snapping cursor, no outline and no popup. On a refusal the clump sheds, the case's refusal tick sounds, and the hint line says why.

## The look

**Up to 6 m (`TIMBER_SPAN`): a timber arch.** Faceted low-poly timber, matching the props: a gentle arch (rise 0.08 x span + 0.1 m, at most 0.6 m) of planks laid across two stringers, a sill log half-sunk under each end, and posts. A span shorter than 2.5 m has only short corner posts. A longer one has posts and a hand rail each side: posts at the ends and middle, plus quarter posts from 4.5 m. Each plank is cut a little differently (seeded by the record id), and every face is flat-shaded in its own tone of weathered brown (deck `8a6a4a`, stringers `5a4330`, sills `4c3a2a`, rails `6f5238`). 

**From 6 to 20 m: a rope bridge.** The deck sags 0.05 × span (0.3 to 1 m) on a sine-squared curve (`lift`), so each anchor leaves its rim level before the deck hangs out over the drop. Planks are laid with gaps between them on two foot ropes. Two hand ropes ride 0.8 m above the deck and sag about half as much, with cords down to the deck's edge about every half metre. A tall post stands each side at each end, sunk in the footing, and a sill log lies under each end. Rope is `9a8360`, posts `5a4330`, and the planks share the timber deck's tones.

The tray icon is a timber arch with its posts and rail over a ripple. In hand, the cursor is a little stack of planks.

## How it fits

- **A record.** `NativeTerrainData.add_bridge` stores `{"asset": "bridge", x/z, end_x/end_z}`, marked hand-made, as waterfalls store their two ends. Undo, redo, saving and loading (the document validates both ends) work as they do for any record. `place`, `update_object` and `replace_object_asset` refuse bridges; they have their own two-ended tool.
- **Drawn apart from the instance batches.** `GardenView` draws no "bridge" part. `scripts/footbridge.gd` is a node under the terrain, in plate metres. It redraws when the records change (`objects_revision`) and on every editor refresh. Each end sits on the ground wherever that is now: shaping a bank moves its end with it, and a bridge whose ends have not moved keeps its mesh.
- **Water passes under.** A bridge changes no height and adds nothing to the water grid, so the live water runs under it untouched.
- **Walked on.** On foot (the wanderer, V, and photo mode's ground eye, G), you stand on the deck, not on the stream bed under it. `Footbridge.decks` and `deck_at` give the planks' height at any point, from the same ends and arch the mesh is built on, read at most once a frame. A bridge with hand rails keeps the walker on it (`keep_on`); from a short one without rails they can step off the side where the water is shallow enough to wade. The water under a deck does not count as wading.
- **Trash can.** The can takes a bridge when any part of its span is in reach, not only its first end (`Trash.reach_of`), and the mesh flies into the can. Shift spares it, as it spares trees, rocks and everything built. Explosions, fire, the selection tool and the creation brushes leave it alone.
- **Editor entry point.** `NativeChunkEditor.place_bridge(from, to)` plans, lays the bridge as one undo step and returns the plan. The command palette lists it under Elements.

## Probe

`tools/probe_bridges.gd` (headless) digs a trench in the cozy world, fills it with live water and drags the footbridge across it through real input. It checks the valid ghost, a bank-to-bank snap with dry ends, one undo step, unchanged ground, and that water still stands under the bridge. It then checks:

- the refusals over dry land, a basin 22 m across and banks 2 m apart in height;
- Cmd+Z;
- a trash-can stroke over the middle of the span, and its undo;
- over a gap between two flat peaks 8 m apart: a rope bridge from rim to rim that sags at mid-span, and the wanderer walking it peak to peak; no bridge when one peak has no level top (`no_footing`); a timber arch over a 3 m dry ravine;
- the wanderer walking across from bank to bank, feet on the planks all the way, standing on the arch at mid-span, dry underfoot, held in by the rails, and photo mode's ground eye standing on the deck;
- a JSON save and load round trip, plus rejection of a bridge saved without its far end.

`tools/probe_crater_bridge.gd` (headless) shapes craters with the Crater's Pull profile (3 to 6 m in radius, 2 to 4 m deep) and plans drags crest to crest, from just inside and just outside the rims, and off the middle line. Each one must hang rim to rim. It then fills one with a lake and checks the bridge still hangs from the rims over the water, not bank to bank down in the bowl.

```sh
perl -e 'alarm 600; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
  --script res://tools/probe_bridges.gd -- --modeless --no-title --no-rain-runoff
```

## Not yet

- The look is not verified on screen. Headless renders nothing, so the arch, the rope bridge's sag and ropes, the plank tones, the ghost's colours and how it sits among the props have not been seen.
- The tray icon and the cursor clump are still the timber arch, also for a rope bridge.
- Reshaping the land under a gap bridge moves its ends with the ground but does not check it again. A bridge whose rim is dug away, or whose gap is filled in, stays.
- Creatures (`scripts/creature_navigation.gd`) do not walk over bridges yet.
- A bridge over a live stream that later dries stays where it is. The land moves its ends, but water drying up does not take a bridge away.
