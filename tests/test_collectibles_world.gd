extends SceneTree
## The sky's collectible tokens (scripts/sky_collectibles.gd, laid by
## scripts/collectible_lines.gd): the same seed lays the same lines; every
## category turns up near the home in review mode; a bridge's tokens stand
## on its deck, an under line hangs under the rock, the air lines leave
## the plane room, and the foot ones are out of the plane's reach (and an
## open spot is not); the walker and the plane each pick up (the plane
## from further, along its way); what is collected is kept and never
## stands again; the readout shows.
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCollectibles = preload("res://scripts/sky_collectibles.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## A sky near the home, its near hosts stood and their lines laid.
func _sky() -> Dictionary:
	var cells := SkyCells.new(SkyWorld.SLOTS)
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var field: Node3D = SkyClusters.new()
	field.islets = islets
	field.with_random = false
	field.with_near = SkyCollectibles.NEAR_MOTIFS.duplicate()
	root.add_child(field)
	field.reset(cells)
	for s: Dictionary in field.spots: field.plan_now(s.key)
	# The islets round the home.
	var eye := Vector3(0.0,20.0,0.0)
	for i in range(8):
		islets.advance(SkyIslets.CHECK,eye)
	for x in range(-2,3):
		for z in range(-2,3):
			var cell := Vector2i(x,z)
			var at: Variant = islets.spot(cell)
			if at != null and not islets.built.has(islets._key(cell)): islets._build(cell,at)
	islets.flush()
	var tokens: Node3D = SkyCollectibles.new()
	tokens.near_home = true
	tokens.islets = islets
	tokens.clusters = field
	root.add_child(tokens)
	tokens.reset(cells)
	var began := Time.get_ticks_msec()
	tokens.flush(eye)
	print("  laid in %d ms" % (Time.get_ticks_msec()-began))
	return {"cells":cells,"islets":islets,"field":field,"tokens":tokens,"eye":eye}

func _run() -> void:
	var sky := _sky()
	var tokens: Node3D = sky.tokens
	var islets: Node3D = sky.islets
	var field: Node3D = sky.field
	var census: Dictionary = tokens.census()
	print("  census: %s" % str(census))
	for category: String in ["bridge","under","air","foot"]:
		check(int(census[category]) > 0,"%s tokens are laid near the home (%d)" % [category,int(census[category])])
	var kinds := {}
	for entry: Array in tokens.all_lines(): kinds[entry[1].kind] = true
	print("  kinds: %s" % str(kinds.keys()))
	check(kinds.has("trail") and (kinds.has("gap") or kinds.has("under_bridge")),"Air lines both between islands and through a cluster")

	# Determinism: a second laying over the same hosts gives the same lines.
	var again: Node3D = SkyCollectibles.new()
	again.near_home = true
	again.islets = islets
	again.clusters = field
	root.add_child(again)
	again.reset(sky.cells)
	again.flush(sky.eye)
	check(_signature(again) == _signature(tokens),"The same seed lays the same lines (%d lines)" % tokens.all_lines().size())
	again.queue_free()
	# And another seed lays others.
	var lines_a: Array = Lines.bridge_lines(_plan_of(field),_offsets(field),Vector3.ZERO,"k",1,true)
	var lines_b: Array = Lines.bridge_lines(_plan_of(field),_offsets(field),Vector3.ZERO,"k",1,true)
	check(str(lines_a) == str(lines_b) and not lines_a.is_empty(),"A bridge's line is the same each time")

	# The rules, token by token.
	var bridge_ok := true
	var under_ok := true
	var air_ok := true
	var foot_ok := true
	var open_reached := true
	for entry: Array in tokens.all_lines():
		var key: String = entry[0]
		var l: Dictionary = entry[1]
		var solids := _solids(key,islets,field)
		for p: Vector3 in l.points:
			match str(l.category):
				"bridge":
					if not _on_deck(solids,p): bridge_ok = false
				"under":
					var s: Dictionary = solids[0]
					var q := p-(s.off as Vector3)
					var under := Lines.islet_under(s.shape,Vector2(q.x,q.z))
					if under == INF or q.y > under-Lines.UNDER_GAP+0.01:
						under_ok = false
						print("  under token at %s: rock %s" % [p,under])
				"air":
					if key != "trails" and not Lines.plane_fits(solids,p): air_ok = false
				"foot":
					if Lines.plane_reaches(solids,p,Lines.PLANE_REACH+float(l.size)*0.5): foot_ok = false
					# Standing room for the walker under it.
					var s: Dictionary = _holding(solids,p)
					var q := p-(s.off as Vector3)
					if s.is_empty() or not s.shape.on_land(Vector2(q.x,q.z)) or s.shape.blocked(Vector2(q.x,q.z)): foot_ok = false
	check(bridge_ok,"Bridge tokens stand over a deck, a walker's height over its planks")
	check(under_ok,"Under tokens hang under the rock, a plane's room below it")
	check(air_ok,"Air tokens leave the plane's wings room")
	check(foot_ok,"Foot tokens are out of the plane's reach and on ground the walker stands on")
	# The check bites: an open spot in the middle of a meadow islet is the
	# plane's.
	for key: String in islets.built:
		var b: Dictionary = islets.built[key]
		if b.has("cluster"): continue
		var solids := [Lines.solid(b.shape,Vector3.ZERO)]
		var open_spot := Vector3.INF
		for x in range(-4,5):
			var p := Vector2(x,0.0)
			if b.shape.on_land(p) and Lines._cover(solids[0],p,float(b.shape.ground_at(p))+Lines.FOOT_Y) == 0.0:
				open_spot = Vector3(p.x,float(b.shape.ground_at(p))+Lines.FOOT_Y,p.y)
				break
		if open_spot != Vector3.INF:
			open_reached = Lines.plane_reaches(solids,open_spot,Lines.PLANE_REACH+0.25)
			break
	check(open_reached,"A spot in the open on an islet is the plane's to reach")
	# The trails keep off everything they must.
	var trails_ok := true
	for l: Dictionary in tokens.sources.get("trails",{}).get("lines",[]):
		for p: Vector3 in l.points:
			for c: Dictionary in field.spots:
				if Vector2(p.x-c.at.x,p.z-c.at.z).length() < Lines.TRAIL_CLUSTER: trails_ok = false
	check(trails_ok and not (tokens.sources.get("trails",{}).get("lines",[]) as Array).is_empty(),"Swoops between islands keep clear of the clusters")

	# Pickup. Tokens standing near the eye: the walker's and the plane's.
	var walk_token := _live(tokens,"foot")
	var air_token := _live(tokens,"air") if not _live(tokens,"air").is_empty() else _live(tokens,"under")
	check(not walk_token.is_empty() and not air_token.is_empty(),"Foot and air tokens stand near the eye")
	if not walk_token.is_empty():
		var holder: Node3D = walk_token.holder
		var at := holder.global_position
		tokens.touch_walker(at+Vector3(1.0,0.0,0.0))
		check(not holder.taking,"The walker a metre off doesn't take a small token")
		tokens._last.clear()
		tokens.touch_walker(at+Vector3(0.3,0.0,0.0))
		check(holder.taking and tokens.collected.has(walk_token.id),"The walker walking through a token takes it")
	if not air_token.is_empty():
		var holder: Node3D = air_token.holder
		var at := holder.global_position
		# A fast plane: one frame before, the next past it.
		tokens._last.clear()
		tokens.touch_plane(at+Vector3(-3.0,1.2,0.0))
		check(not holder.taking,"The plane 3 m short hasn't it yet")
		tokens.touch_plane(at+Vector3(3.0,1.2,0.0))
		check(holder.taking and tokens.collected.has(air_token.id),"The plane takes it passing by within its reach, along its way")
	for i in range(40): await process_frame
	check(tokens.hud.showing() and tokens.hud._count.text == "1","The readout shows the glyph and its count")

	# A whole line: every token of a line taken.
	var whole := {}
	for entry: Array in tokens.all_lines():
		var l: Dictionary = entry[1]
		if l.category == "under" and not whole.has("l"): whole = {"key":entry[0],"l":l}
	if not whole.is_empty():
		var s: Dictionary = tokens.sources[whole.key]
		var got := []
		tokens.picked.connect(func(_g: String, _t: int, done: int, count: int) -> void: got.append([done,count]))
		var points: PackedVector3Array = whole.l.points
		for k in range(points.size()):
			var id := "%s:%d" % [whole.l.id,k]
			if not tokens.collected.has(id) and s.live.has(id): tokens.collect(s,id)
		check(not got.is_empty() and got[-1][0] == got[-1][1],"Taking a line's last token completes it (%s)" % str(got.back() if not got.is_empty() else []))

	# Kept: saved through JSON, loaded into a fresh sky, nothing collected
	# stands again; and the same sky streamed again doesn't respawn them.
	var taken: Array = tokens.collected.keys()
	tokens._stream(sky.eye)
	tokens.flush(sky.eye)
	var respawned := false
	for key in tokens.sources:
		for id: String in taken:
			if tokens.sources[key].live.has(id) and is_instance_valid(tokens.sources[key].live[id]) and not tokens.sources[key].live[id].taking: respawned = true
	check(not respawned,"Collected tokens never stand again")
	var saved: Variant = JSON.parse_string(JSON.stringify(tokens.save_state()))
	var fresh: Node3D = SkyCollectibles.new()
	fresh.near_home = true
	fresh.islets = islets
	fresh.clusters = field
	root.add_child(fresh)
	fresh.reset(sky.cells)
	fresh.load_state(saved)
	fresh.flush(sky.eye)
	var standing := 0
	for key in fresh.sources:
		for id: String in taken:
			if fresh.sources[key].live.has(id): standing += 1
	check(fresh.collected.size() == taken.size() and standing == 0,"Kept with the world: %d collected, none stand after a load" % fresh.collected.size())
	fresh.load_state({"seed":SkyWorld.seed+1,"collected":saved.collected})
	check(fresh.collected.is_empty(),"A save for another seed's sky is left out")

	# Streaming: far off, nothing stands.
	tokens._stream(Vector3(5000.0,0.0,5000.0))
	var live := 0
	for key in tokens.sources:
		for h: Variant in tokens.sources[key].live.values():
			if is_instance_valid(h) and not h.is_queued_for_deletion(): live += 1
	check(live == 0,"Far from every token none stand as nodes (%d)" % live)
	tokens._stream(sky.eye)
	var began := Time.get_ticks_usec()
	tokens._survey(sky.eye-sky.cells.origin)
	tokens._stream(sky.eye)
	print("  near the home: %d points looked over, a survey and stream in %d us" % [int(tokens.spent.looked),Time.get_ticks_usec()-began])

	print("PASS: collectibles world" if failures == 0 else "FAIL: collectibles world (%d)" % failures)
	quit(1 if failures else 0)

## Every line's id and points, sorted, as one string.
func _signature(tokens: Node3D) -> String:
	var parts: Array = []
	for entry: Array in tokens.all_lines():
		parts.append("%s %s %s %s" % [entry[1].id,entry[1].category,entry[1].glyph,str(entry[1].points)])
	parts.sort()
	return "\n".join(parts)

## A standing token of `category`: {id, holder}, or {}.
func _live(tokens: Node3D, category: String) -> Dictionary:
	for key in tokens.sources:
		var s: Dictionary = tokens.sources[key]
		for l: Dictionary in s.lines:
			if l.category != category: continue
			for k in range((l.points as PackedVector3Array).size()):
				var id := "%s:%d" % [l.id,k]
				if s.live.has(id) and is_instance_valid(s.live[id]) and not tokens.collected.has(id): return {"id":id,"holder":s.live[id]}
	return {}

func _plan_of(field: Node3D) -> Dictionary:
	for key in field.clusters:
		var plan: Dictionary = field.clusters[key].get("plan",{})
		if not (plan.get("bridges",[]) as Array).is_empty(): return plan
	return {}

func _offsets(field: Node3D) -> Dictionary:
	var out := {}
	for m: Dictionary in _plan_of(field).members: out[m.name] = m.offset
	return out

## The solids a source's lines were laid against, in its host's frame.
func _solids(key: String, islets: Node3D, field: Node3D) -> Array:
	if key.begins_with("islet:"):
		return [Lines.solid(islets.built[key.trim_prefix("islet:")].shape,Vector3.ZERO)]
	if key.begins_with("cluster:"):
		var plan: Dictionary = field.clusters[key.trim_prefix("cluster:")].plan
		var host_off := Vector3.ZERO
		var out: Array = []
		for m: Dictionary in plan.members: out.append(Lines.solid(m.shape,(m.offset as Vector3)-host_off,m.features))
		return out
	return []

## The solid whose land holds host-frame point `p`, or {}.
func _holding(solids: Array, p: Vector3) -> Dictionary:
	for s: Dictionary in solids:
		var q := p-(s.off as Vector3)
		if s.shape.on_land(Vector2(q.x,q.z)): return s
	return {}

## True when `p` stands over some solid's deck, FOOT_Y over its planks.
func _on_deck(solids: Array, p: Vector3) -> bool:
	for s: Dictionary in solids:
		var q := p-(s.off as Vector3)
		var y := Lines.deck_y(s,Vector2(q.x,q.z))
		if y > -INF and absf(q.y-y-Lines.FOOT_Y) < 0.05: return true
	return false
