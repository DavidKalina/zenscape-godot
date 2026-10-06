extends SceneTree
## The main thread's share of the sky streaming in mid-flight (scripts/
## sky_commits.gd). A scripted flight (tools/profile_sky_streaming.gd) from
## the plate past the fixed islands, out till a fresh island turns up, and
## over a chunk, which is claimed as it is flown into: no frame stands a
## part up once the sky's share of it is spent; an island's ground and
## earth sides are made on its worker, so standing it up is only its nodes,
## and the sides are the very ones the plate's own fitting gives; the claim
## never holds a frame for long (it re-formed the plate and read its whole
## habitat in single frames, ~300 ms) and its habitat is read again a slice
## a frame, finishing; and a plain formed from its baked outline is the
## plain its seed gives.
##
## Headless measures the scripts only, never the GPU's uploads or pipeline
## builds. The frame bounds are loose (several times the frames seen), so a
## slower machine still passes and the old stalls still fail.
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Profile = preload("res://tools/profile_sky_streaming.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const PlateFixture = preload("res://tests/fixtures/plate.gd")
## Each kind's commit, at most (ms): an island's nodes alone; the claim's
## steps; the worst whole frame of the flight (uncapped, headless).
const ISLAND_MS := 3.0
const CLAIM_STEP_MS := 60.0
const FRAME_MS := 120.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: push_error("sky streaming budget test timed out"); quit(2))
	_same_plain()
	await _flight()
	print("PASS: sky streaming budget" if failures == 0 else "FAIL: sky streaming budget")
	quit(1 if failures else 0)

## A plain formed with its seed's outline given (a sky chunk's, baked) is
## the plain formed without: outline, shore, heights and cover alike.
func _same_plain() -> void:
	var seed_value := 424242
	var a := NativeTerrainData.new()
	a.setup(PlateFixture.mesh())
	Genesis.shape(a,seed_value)
	var b := NativeTerrainData.new()
	b.setup(PlateFixture.mesh())
	Genesis.shape(b,seed_value,Vector2.ZERO,true,-1.0,a.outline)
	check(not a.outline.is_empty(),"The plain has an outline")
	check(a.outline == b.outline and a.shore_distance == b.shore_distance and a.shore_edges == b.shore_edges and a.keel == b.keel,"Given its baked outline, the plain's outline and shore are its seed's")
	check(a.heights == b.heights and a.blades == b.blades and a.meadow == b.meadow and a.objects.size() == b.objects.size(),"Given its baked outline, the plain's ground and cover are its seed's")

func _flight() -> void:
	var flown: Dictionary = await Profile.fly(root,self,22.0)
	print(flown.report)
	var commits: Array = flown.commits
	var frames: Array[float] = flown.frames
	check(int(flown.claimed) == 1,"The flight claims the chunk it flies into")
	check(int(flown.fresh) >= 1,"A fresh island turns up out in the open sky")
	var kinds := {}
	for c: Array in commits: kinds[c[1]] = true
	for kind in ["island","islet","range"]: check(kinds.has(kind),"Parts stood up on the way: %s" % kind)
	# The share: a frame starts a part only while it has room (the claim's
	# steps are its own, not streaming).
	var spent := {}
	var late := 0
	for c: Array in commits:
		if (c[1] as String).begins_with("claim:"): continue
		if int(spent.get(c[0],0)) >= SkyCommits.BUDGET_USEC: late += 1
		spent[c[0]] = int(spent.get(c[0],0))+maxi(int(c[2]),1)
	check(late == 0,"No frame stands a part up once its share is spent (%d did)" % late)
	var island_ms := 0.0
	var claim_ms := 0.0
	for c: Array in commits:
		if c[1] == "island": island_ms = maxf(island_ms,c[2]/1000.0)
		if (c[1] as String).begins_with("claim:"): claim_ms = maxf(claim_ms,c[2]/1000.0)
	check(island_ms <= ISLAND_MS,"An island's ground and sides are made on its worker: standing it up takes %.2f ms (at most %.1f)" % [island_ms,ISLAND_MS])
	check(claim_ms <= CLAIM_STEP_MS,"Each step of the claim on the main thread takes %.1f ms (at most %.0f)" % [claim_ms,CLAIM_STEP_MS])
	var worst := 0.0
	for f in frames: worst = maxf(worst,f)
	check(worst <= FRAME_MS,"The flight's worst frame, claim and all, is %.1f ms (at most %.0f)" % [worst,FRAME_MS])
	var habitat: Dictionary = flown.get("habitat",{})
	check(bool(habitat.get("settled",false)),"The claimed plate's habitat is read again, a slice a frame, and finishes")
	check(bool(flown.get("sides_match",false)),"An island's earth sides, made on its worker, are the ones the plate's own fitting gives")
