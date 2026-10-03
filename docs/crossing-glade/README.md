# A quiet spot across the stream

## Objective

Implement and verify a cozy sandbox playable slice in which Bigfoot notices an
appealing resting spot across a small stream, the player creates a usable
crossing by placing a log or sculpting stepping stones, Bigfoot safely traverses
the crossing with expressive movement, and a successful visit lets him adopt
the destination as a persistent favorite resting place that he later revisits
autonomously. Integrate this into the existing playable world and editing flow,
respect terrain edits and invalidated routes, and validate the complete
player-to-Bigfoot interaction in the native game.

## Play

World → New crossing glade creates a separate saved diorama after saving the
current world. Bigfoot notices a scenic spot on the other bank. In Build, move
the provided long log into the stream with its long axis across the banks; its
ordinary editable pose supplies the height. Center it over the channel near the
middle of the clearing. Enjoy lets him cross and rest.

Alternatively, use Raise with a small brush in the middle of the stream until
its top reaches bank height, then Flatten from that top to make a landing.
Leave short water gaps on either side: he can hop up
to 1.45 meters between safe landings, with at most 0.3 meters of height change.
The provided channel fits one central stepping stone and two hops. The whole
airborne arc is checked for scenery and terrain obstacles.

The cozy flow also keeps a `Before-crossing-….json` copy of the previous place
in its save folder; use Open to return to it. The glade remains ordinary editable
terrain and objects. There are no currencies, quest panels or locked tools.

## Behavior and persistence

The same wish behavior runs in existing inhabited worlds with narrow streams
and nearby scenery. It does not require the glade. A completed rest records a
separate outing memory, leaving his home intact. He periodically attempts a
return, and unavailable routes have a cooldown. Removing a route does not erase
a still-valid destination; changing the resting surface invalidates it.

Navigation uses the actual placed log's triangles and both terrain-supported
ends, with a narrower checked foot support for balancing. Floating logs, unsafe
footing, water, and other obstacles remain excluded. Picking up a physical log
disables its stored crossing until the next committed placement. Save version
three adds outing position and visit count; versions one and two remain valid.

Continuous sculpted dry routes use ordinary navigation. Disconnected stones use
a local, cancellable route search with the existing frame budget. Bigfoot spreads
his arms on supported logs and uses an airborne/landing sequence for small hops.
Pausing freezes progress. Editing away a hop landing cancels the outing and
recovers safe footing; an interrupted outing never counts as a visit.

## Verification

- `tests/test_log_walkways.gd`: real log mesh support, normal swept routes,
  obstacle rejection, deletion, floating-log rejection and isolated worker data.
- `tests/test_stepping_route.gd`: disconnected banks and a center stone, checked
  water-gap hops, actual actor lift and landing, deleted stones, cancellation,
  and walking along the bank to a stone away from the direct destination line.
- `tests/test_bigfoot_crossing.gd` (removed): native product scene notices autonomously,
  accepts an edited log crossing, walks with balance, completes rest, saves,
  reopens and revisits. It also sculpts a real center stone, completes two hops,
  pauses mid-hop, and removes a landing while airborne. The complete interaction
  passed with the native renderer.
- `tests/test_creature_navigation.gd`: existing ground navigation regression passes.
- `tools/render_crossing_glade.gd`: native Metal captures notice, crossing and
  favorite-place completion in the main cozy game through the World entry and
  selection editing APIs. Both the log and sculpted-stone versions completed
  with ordinary autonomous behavior enabled. Both preserved an exact terrain/
  object backup of the previous world and restored the favorite after creating
  a fresh cozy-game scene from its saved file.
  Screenshots go to `/private/tmp/crossing-render`; use `-- --stones` for the
  sculpted alternative in `/private/tmp/crossing-render-stones`.

Local native captures: [log crossing](log-crossing.png), [stone hop](stone-hop.png),
and [favorite-place completion](favorite.png). Generated images remain on the
recording machine per the repository's ignore rules; the capture script and
measurements are versioned.

Discovery and walking-route checks initially took about 100 ms together in a
populated world. They now share cancellable queries with the stepping search;
native captures measured peak discovery/reachability slices of 1.52–1.60 ms
in the final stone run and 1.55–1.57 ms in the log run. Animation and world updates
continue between slices. This measures query work, not total rendered frame time.

Review corrected planner ownership during its first frame and made the movement
arc and clearance checks share one definition. The broad sweep caught one
introduced regression: promoting small carryable logs unnecessarily invalidated
navigation and prevented the physical-log interaction from starting. Invalidation
now applies only when that log actually supplied walkable footing. Its existing
interaction test and the bridge-promotion check cover both cases.

The main-game stone capture also exposed a too-narrow route-search corridor.
The local search now allows a short detour along either bank, while retaining
its node and per-frame work limits.

The full native sweep completed all 237 scripts: **177 clean passes, 25 passes
with classified renderer diagnostics, 30 failures and 5 timeouts**. Its original
results remain in [validation.json](validation.json); this is not a green-suite
claim. The corrected targeted run passed all six checks: crossing integration,
log support, stepping routes, home behavior, physical world play and the AI
decision budget. Four retain the known native light-unpair teardown diagnostic.

Several broader failures match the repository's existing
baseline audit (removed), including
premature UI access, outdated catalog expectations and simulation tests that
advance hundreds of ticks between asynchronous query frames. Exact-starting-
revision comparisons are retained in the same validation file. Cave-store,
habits, rage, routine-day and Fidelity-life tests all reproduce their exact
current error/assertion signatures on `f19b2f5`. The other unsuccessful sweep
results remain reported; they have not all been individually reproduced here.

## Completion audit

| Goal requirement | Evidence |
| --- | --- |
| Notice an appealing unreachable bank | Native scene test and both main-game notice captures |
| Place a log using existing editing | Main-game selection edit; actual mesh support and bank checks |
| Sculpt stepping stones | Native terrain brush, two checked hops, along-bank detour |
| Expressive safe traversal | Balance pose, airborne arc and landing; swept routes and interruption checks |
| Earn the favorite through a completed rest | Success-only visit count; interrupted hops earn no visit |
| Persist and revisit | Save/open plus autonomous second visit; fresh main-game restart for both routes |
| Respect edits | Bridge deletion/promotion, removed hop landing, reshaped resting surface |
| Integrate with the playable world | World menu in the main cozy scene; previous-world backup verified |
