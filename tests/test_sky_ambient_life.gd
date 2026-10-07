extends SceneTree
## suite: serial
## The other islands' life from the air (scripts/sky_ambient_life.gd) and
## the claim it hands over at (scripts/sky_islands.gd `claim`), flown as
## tools/profile_claim.gd flies: from open sky into a fresh chunk, back into
## the built island first left (its document loaded back) and into the
## fresh chunk again.
##
## The claim: no frame of the approach, the claim or the landing does more
## than CLAIM_FRAME_MS of the claim's own work (its steps, the plate drawn
## again, the habitat read again: each frame's sum), and no frame round it
## runs more than SPIKE_MS past the open sky's slowest. Before, forming the
## plain (24 ms), reading a built island's document (26 ms), the save (9 ms)
## and the fire field's re-seed (11 ms) each landed in a single frame.
##
## The life: only islands within RADIUS of the glide have it, at most CAP;
## an island past RELEASE never; the nearest island in reach gets it; its
## gulls, flock and chaff are drawn; the glide passing over a grove flushes
## its flock; at a claim the island left takes on the plate's gulls where
## they flew, and the claimed island's stand-ins carry on over the plate
## through the swap without a jump, and go as the plate's own come in. Its
## cost a frame, with one to CAP islands in reach and with twice CAP, stays
## within AMBIENT_MS.
##
## Headless measures the scripts only, never the GPU, and checks positions
## the layer worked out, never pixels: how it looks is for a rendered glide.
const Profile = preload("res://tools/profile_claim.gd")
const Ambient = preload("res://scripts/sky_ambient_life.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
## The claim's own work in any one frame (ms), and how far past the open
## sky's slowest frame any frame round the claim may run (ms).
const CLAIM_FRAME_MS := 8.0
const SPIKE_MS := 8.0
## The life's main-thread cost a frame (ms): mean and worst, CAP islands.
const AMBIENT_MS := Vector2(0.6,2.0)
## A gull carried across the swap moves at most this (m) between frames.
const CARRIED := 0.6
var failures := 0

# What the flight saw, frame by frame (`_watch`).
var far_hosts := 0
var over_cap := 0
var near_without := 0
var near_frames := 0
var drawn_near := 0
var flushed := false
var flock_drawn := 0
var chaff_drawn := 0
var hosts_most := 0
var _nearest_key := ""
var _nearest_for := 0
var _was_claiming := false
var _claim_keys: Array = []
var _last_origin := Vector3.ZERO
var _last_gulls := {}
var carried_worst := 0.0
var carried_checked := 0
var left_hosts := 0
var left_from_real := 0
var left_worst := 0.0
var _real_before: Array = []
var handover_seen := 0
var handover_left_over := 0
var real_came := false

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(900).timeout.connect(func() -> void: push_error("sky ambient life test timed out"); quit(2))
	# The headless root is 100 px wide, narrower than the shell lays out for.
	root.size = Vector2i(1440,900)
	var flown: Dictionary = await Profile.fly(root,self,22.0,false,Callable(),3,_watch)
	print(flown.report)
	_claim_frames(flown)
	_life_checks()
	_flight_cost(flown)
	await _taken(flown.scene)
	await _cap_and_cost(flown.scene)
	(flown.scene as Node).queue_free()
	await process_frame
	print("PASS: sky ambient life" if failures == 0 else "FAIL: sky ambient life")
	quit(1 if failures else 0)

## Every frame of the flight: who has life, what it draws, and the claim's
## handover.
func _watch(scene: Node3D, _id: int, claiming: bool, _leg: int) -> void:
	var islands: Node3D = scene.wanderer.islands
	var ambient: Node3D = islands.ambient
	if ambient == null: return
	var eye: Vector3 = scene.wanderer.glide.position
	var live := 0
	for key: String in ambient.hosts:
		var host: Node3D = ambient.hosts[key]
		if is_instance_valid(host) and host.handing < 0.0: live += 1
	hosts_most = maxi(hosts_most,live)
	if live > ambient.cap: over_cap += 1
	# Past RELEASE, never; the nearest island well in reach, soon.
	var nearest := ""
	var nearest_d := INF
	for i in range(islands.copy_count()):
		if islands.lands[i] == null or islands._rise[i] != Vector3.ZERO or (islands.offsets[i] as Vector3).length() < 1.0: continue
		var key: String = islands._key(islands.homes[i])
		var d: float = ambient._middle_of(i).distance_to(eye)
		if d > ambient.release and ambient.hosts.has(key): far_hosts += 1
		if d < nearest_d:
			nearest_d = d
			nearest = key
	if nearest_d < ambient.radius*0.8 and not claiming:
		_nearest_for = _nearest_for+1 if nearest == _nearest_key else 0
		_nearest_key = nearest
		if _nearest_for > 90:
			near_frames += 1
			var host: Node3D = ambient.hosts.get(nearest)
			if host == null: near_without += 1
			else:
				for g: Vector4 in host.shown.gulls: if g.w > 0.01: drawn_near += 1
	for key: String in ambient.hosts:
		var host: Node3D = ambient.hosts[key]
		if not is_instance_valid(host): continue
		if host.flushed >= 0.0: flushed = true
		for b: Vector4 in host.shown.flock: if b.w > 0.01: flock_drawn += 1
		for c: Vector4 in host.shown.chaff: if c.w > 0.01: chaff_drawn += 1
	_handover(islands,ambient,claiming)
	_was_claiming = claiming
	_last_origin = islands.origin

## The claim's handover: the island left takes the plate's gulls, the
## claimed one's carry on over the plate without a jump.
func _handover(islands: Node3D, ambient: Node3D, claiming: bool) -> void:
	var life: Node = islands.scene.get("land_life")
	# The plate's own gulls, world space, while it shows.
	var real: Array = []
	if life != null and life.get("_birds") != null:
		var node: Node3D = life._bird_node
		for bird: Dictionary in life._birds.birds:
			if float(bird.out) > 0.5: real.append(node.global_transform*Vector3(bird.x,bird.y,bird.z))
	if claiming and not _was_claiming:
		_claim_keys = ambient.hosts.keys()
	# The island left, once the plate hides: life at once, from the real gulls.
	if claiming:
		for i in range(islands.copy_count()):
			if (islands.offsets[i] as Vector3).length() >= 1.0: continue
			var host: Node3D = ambient.hosts.get(islands._key(islands.homes[i]))
			if host == null or host.has_meta("checked"): continue
			host.set_meta("checked",true)
			left_hosts += 1
			for g: Dictionary in host.gulls:
				if (g.from as Vector3) == Vector3.INF: continue
				left_from_real += 1
				var best := INF
				for p: Vector3 in _real_before: best = minf(best,p.distance_to(g.from))
				left_worst = maxf(left_worst,best)
	if not real.is_empty(): _real_before = real
	# The claimed island's gulls, world space, each frame of the claim.
	if claiming:
		_last_gulls.clear()
		for key: String in _claim_keys:
			var host: Node3D = ambient.hosts.get(key)
			if host == null or not is_instance_valid(host): continue
			var world: Array = []
			for g: Vector4 in host.shown.gulls: world.append(host.global_transform*Vector3(g.x,g.y,g.z))
			_last_gulls[key] = world
	elif _was_claiming:
		var shift: Vector3 = islands.origin-_last_origin
		for key: String in _last_gulls:
			var host: Node3D = ambient.hosts.get("handover:"+key)
			if host == null: continue
			handover_seen += 1
			var before: Array = _last_gulls[key]
			for k in range(mini(before.size(),host.shown.gulls.size())):
				var g: Vector4 = host.shown.gulls[k]
				var now: Vector3 = host.global_transform*Vector3(g.x,g.y,g.z)
				carried_worst = maxf(carried_worst,now.distance_to((before[k] as Vector3)+shift))
				carried_checked += 1
	for key: String in ambient.hosts:
		if key.begins_with("handover:") and claiming and not _was_claiming: handover_left_over += 1
	if life != null and Ambient._real_gulls(life) > 0 and not claiming: real_came = true

func _claim_frames(flown: Dictionary) -> void:
	var quiet: Array[float] = flown.quiet
	var calm := 0.0
	for q in quiet: calm = maxf(calm,q)
	for leg: Dictionary in flown.legs:
		var claim: Array = leg.claim
		check(claim[0] >= 0 and claim[1] >= claim[0],"Leg %s: the chunk is claimed (%d frames)" % [leg.name,claim[1]-claim[0]+1])
		var worst_claim := 0.0
		var worst_at := -1
		var worst_wall := 0.0
		for f: Dictionary in leg.frames:
			var mine := Profile.claim_ms(f)
			if mine > worst_claim:
				worst_claim = mine
				worst_at = f.id
			if f.id >= claim[0]-3 and f.id <= claim[1]+100: worst_wall = maxf(worst_wall,f.wall)
		check(worst_claim <= CLAIM_FRAME_MS,"Leg %s (%s): the claim's own work is %.1f ms in its worst frame (@%d, at most %.0f)" % [leg.name,leg.path,worst_claim,worst_at,CLAIM_FRAME_MS])
		check(worst_wall <= calm+SPIKE_MS,"Leg %s: round the claim no frame runs past %.1f ms (%.1f; open sky's slowest %.1f, +%.0f)" % [leg.name,calm+SPIKE_MS,worst_wall,calm,SPIKE_MS])

func _life_checks() -> void:
	print("     life: most islands at once %d, nearest-in-reach frames %d (gull draws %d), flock draws %d, chaff draws %d" % [hosts_most,near_frames,drawn_near,flock_drawn,chaff_drawn])
	check(over_cap == 0,"No more than CAP islands have life at once (%d frames over)" % over_cap)
	check(far_hosts == 0,"No island past RELEASE has life (%d frames did)" % far_hosts)
	check(near_frames > 0 and near_without == 0,"The nearest island in reach has life (%d of %d frames without)" % [near_without,near_frames])
	check(drawn_near > 0,"Its gulls are drawn (%d)" % drawn_near)
	check(chaff_drawn > 0,"Chaff drifts over the islands in reach (%d)" % chaff_drawn)
	check(flushed and flock_drawn > 0,"Gliding over a grove flushes its flock (%d drawn)" % flock_drawn)
	print("     handover: islands left %d (gulls taken from the plate's %d, worst %.2f m off), carried across the swap %d (worst %.2f m), plate's own gulls came: %s" % [left_hosts,left_from_real,left_worst,carried_checked,carried_worst,real_came])
	check(left_hosts >= 3,"Each island left takes life the frame the plate hides (%d of 3)" % left_hosts)
	check(left_from_real == 0 or left_worst <= CARRIED,"The island left's gulls start where the plate's own were flying (worst %.2f m)" % left_worst)
	check(handover_seen >= 3 and carried_checked > 0,"The claimed island's life carries on over the plate through each swap (%d swaps, %d gulls)" % [handover_seen,carried_checked])
	check(carried_worst <= CARRIED,"Its gulls move on without a jump across the swap (worst %.2f m, at most %.1f)" % [carried_worst,CARRIED])
	check(handover_left_over == 0,"Each handover is over by the next claim (%d left over)" % handover_left_over)

## The life's cost in each frame of the flight, flocks flushing and all, and
## each island's standing up (within the sky's frame share).
func _flight_cost(flown: Dictionary) -> void:
	var costs: Array[float] = []
	var stand := 0.0
	for leg: Dictionary in flown.legs:
		for f: Dictionary in leg.frames:
			for s: Array in f.steps:
				if s[0] == "ambient": costs.append(s[1])
				elif s[0] == "ambient:stand": stand = maxf(stand,s[1])
	costs.sort()
	var mean := 0.0
	for c in costs: mean += c
	mean /= maxf(costs.size(),1.0)
	print("     life's cost in flight: mean %.3f ms, p95 %.3f, worst %.3f over %d frames; an island stood up in %.2f ms at most" % [mean,costs[int(costs.size()*0.95)] if not costs.is_empty() else 0.0,costs[-1] if not costs.is_empty() else 0.0,costs.size(),stand])
	check(not costs.is_empty() and mean <= AMBIENT_MS.x and costs[-1] <= AMBIENT_MS.y,"In flight the life costs %.3f ms a frame on the mean, %.3f at worst (at most %.1f, %.1f)" % [mean,costs[-1] if not costs.is_empty() else -1.0,AMBIENT_MS.x,AMBIENT_MS.y])
	check(stand <= 3.0,"Standing an island's life up takes %.2f ms (at most 3)" % stand)

## The island left at a claim takes the plate's own gulls as they fly
## (`leave`), here with three of LandLife's gulls set flying by hand: its
## first gulls are drawn where they were, and ease into its own circles.
func _taken(scene: Node3D) -> void:
	var islands: Node3D = scene.wanderer.islands
	var ambient: Node3D = islands.ambient
	var life: Node = scene.get("land_life")
	var index := -1
	for i in range(islands.copy_count()):
		if islands.lands[i] != null and islands._rise[i] == Vector3.ZERO and (islands.offsets[i] as Vector3).length() >= 1.0: index = i
	if life == null or index < 0:
		check(false,"A world with LandLife's gulls and an island to leave them to")
		return
	# Wherever the island stands, it is in reach.
	ambient.radius = 1.0e6
	ambient.release = 1.0e6
	ambient.cap = 99
	var node: Node3D = life._bird_node
	var flying: Array[Vector3] = []
	for k in range(3):
		var bird: Dictionary = life._birds.birds[k]
		bird.out = 1.0
		bird.x = 2.0*k
		bird.y = 11.0+k
		bird.z = -3.0
		flying.append(node.global_transform*Vector3(bird.x,bird.y,bird.z))
	ambient.leave(index)
	var host: Node3D = ambient.host_at(islands.homes[index])
	ambient.advance(0.0,scene.wanderer.glide.position)
	var worst := 0.0
	var island: Node3D = islands._copies[index]
	for k in range(3):
		var g: Vector4 = host.shown.gulls[k]
		var drawn: Vector3 = island.global_transform*Vector3(g.x,g.y,g.z)
		worst = maxf(worst,drawn.distance_to(flying[k]))
	check(host != null and host.gulls.size() >= 3 and worst <= 0.01,"The island left draws the plate's flying gulls where they were (worst %.3f m)" % worst)
	for k in range(30): ambient.advance(1.0/10.0,scene.wanderer.glide.position)
	var eased := 0.0
	for k in range(3):
		var g: Vector4 = host.shown.gulls[k]
		eased = maxf(eased,(island.global_transform*Vector3(g.x,g.y,g.z)).distance_to(flying[k]))
	check(eased > 1.0,"...and eases them into its own circles (%.1f m on, after 3 s)" % eased)
	for k in range(3): life._birds.birds[k].out = 0.0
	ambient.clear()
	ambient.radius = Ambient.RADIUS
	ambient.release = Ambient.RELEASE
	ambient.cap = Ambient.CAP
	await process_frame

## With the reach widened, every island within it to CAP (and twice CAP)
## has life, and the frame's cost stays small.
func _cap_and_cost(scene: Node3D) -> void:
	var islands: Node3D = scene.wanderer.islands
	var ambient: Node3D = islands.ambient
	var eye: Vector3 = scene.wanderer.glide.position
	var eligible := 0
	for i in range(islands.copy_count()):
		if islands.lands[i] != null and islands._rise[i] == Vector3.ZERO and (islands.offsets[i] as Vector3).length() >= 1.0: eligible += 1
	ambient.radius = 1.0e6
	ambient.release = 1.0e6
	var lines: Array[String] = []
	for n in [1,2,Ambient.CAP,Ambient.CAP*2]:
		ambient.cap = n
		ambient.clear()
		var costs: Array[float] = []
		for k in range(150):
			# Every flock out, as the glide passing would flush them.
			if k == 25:
				for host: Node3D in ambient.hosts.values(): host.flushed = 0.0
			ambient.advance(1.0/60.0,eye)
			if k >= 30: costs.append(ambient.last_usec/1000.0)
			await process_frame
		var live := 0
		var drawn := 0
		for host: Node3D in ambient.hosts.values(): if host.handing < 0.0: live += 1
		drawn = ambient.drawn()
		costs.sort()
		var mean := 0.0
		for c in costs: mean += c
		mean /= maxf(costs.size(),1.0)
		var p95: float = costs[int(costs.size()*0.95)]
		lines.append("%d islands (%d creatures): mean %.3f ms, p95 %.3f, worst %.3f" % [live,drawn,mean,p95,costs[-1]])
		check(live == mini(n,eligible),"With the reach widened and a cap of %d, %d islands have life (%d in reach)" % [n,live,eligible])
		if n <= Ambient.CAP:
			check(mean <= AMBIENT_MS.x and costs[-1] <= AMBIENT_MS.y,"With %d islands, the life costs %.3f ms a frame on the mean, %.3f at worst (at most %.1f, %.1f)" % [live,mean,costs[-1],AMBIENT_MS.x,AMBIENT_MS.y])
	print("     life's cost a frame (headless):\n       "+"\n       ".join(lines))
	ambient.radius = Ambient.RADIUS
	ambient.release = Ambient.RELEASE
	ambient.cap = Ambient.CAP
