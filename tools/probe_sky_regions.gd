extends SceneTree
## The sky world's regions as laid out (scripts/sky_world.gd), seed by seed:
## how many tries the ridges took, how long the layout took, each region's
## room for islands (km^2) and its islands as the plan finds them, its
## cumulus. Headless, nothing drawn:
##   Godot --headless --path . -s res://tools/probe_sky_regions.gd -- --seeds=7,1,99
const SkyWorld = preload("res://scripts/sky_world.gd")

func _initialize() -> void:
	var seeds := [7,1,99,12345,31337,424242,5,2024]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = Array(a.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s))
	var worst := 0.0
	for s: int in seeds:
		SkyWorld.seed = s
		var began := Time.get_ticks_usec()
		var l := SkyWorld.layout()
		var ms := (Time.get_ticks_usec()-began)/1000.0
		worst = maxf(worst,ms)
		var areas: Array = l.regions.map(func(g: Dictionary) -> String: return ("home " if g.home else "")+str(g.area))
		var ridges: int = l.ranges.filter(func(r: Dictionary) -> bool: return r.kind == "ridge").size()
		print(("seed %d: try %d, kept %s, balance %.2f, %.0f ms; %d ridge pieces; room %s km^2; islands %s; cumulus %d" % [s,int(l.get("tries",0)),str(l.kept_rules),float(l.get("balance",0.0)),ms,ridges,str(areas),str(l.get("islands",[])),l.towers.size()]))
		var band_far := 0.0
		for r: Dictionary in l.ranges:
			if not SkyWorld.in_band(r.kind) or r.kind == "far": continue
			for p: Vector2 in SkyWorld.box_outline(r):
				if maxf(absf(p.x),absf(p.y)) > band_far: print("     far %s %s scale %s angle %.0f order %s/%s" % [r.kind,r.index,r.scale,rad_to_deg(r.angle),r.get("order"),r.get("of")])
				band_far = maxf(band_far,maxf(absf(p.x),absf(p.y)))
		print("   the band within %.0f m" % band_far)
		if "--map" in OS.get_cmdline_user_args(): _map(l)
		if "--real" in OS.get_cmdline_user_args(): _real(l)
	print("worst layout %.0f ms" % worst)
	quit(0)

## The plan's regions as letters every 150 m (--map): A the plate's, B, C..
## the others, # rock at glide height, . open but no region's, P the plate.
func _map(l: Dictionary) -> void:
	var band: Array = l.ranges.filter(func(r: Dictionary) -> bool: return SkyWorld.in_band(r.kind))
	var ridges: Array = l.ranges.filter(func(r: Dictionary) -> bool: return not SkyWorld.in_band(r.kind))
	var n := SkyWorld.grid_size()
	var b := SkyWorld.basins(SkyWorld.plan_open(ridges,SkyWorld._band_open(band)),n,SkyWorld.GRID,SkyWorld.CORE,SkyWorld.PASS_HALF)
	var home: int = b.labels[SkyWorld._grid_index(Vector2.ZERO,n)]
	for z in range(-3300,3301,150):
		var row := ""
		for x in range(-3300,3301,75):
			var p := Vector2(x,z)
			var c: int = SkyWorld._grid_index(p,n)
			var k: int = b.labels[c]
			var ch := "#" if b.dist[c] == 0.0 else ("." if k < 0 else ("A" if k == home else "BCDEFG"[k if k < home else k-1]))
			if p.length() < 80.0: ch = "P"
			elif p.length() > SkyWorld.SCATTER and ch != "#": ch = ch.to_lower()
			row += ch
		print(row)

## The same read off the real rock (--real: every range made, as tests/
## test_sky_world.gd reads it, every 25 m; slow).
func _real(l: Dictionary) -> void:
	var SkyPeak: GDScript = load("res://scripts/sky_peak.gd")
	var SkyPeaks: GDScript = load("res://scripts/sky_peaks.gd")
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var made := []
	for r: Dictionary in l.ranges: made.append({"shape":SkyPeak.make(int(r.seed),float(r.stature),bool(r.gorge)),"at":r.at,"turn":float(r.turn),"scale":r.scale})
	made.append({"shape":SkyPeak.make(SkyPeaks.seed_of(Vector2i.ZERO),1.0),"at":SkyPeaks.HOME,"turn":SkyPeaks.HOME_TURN,"scale":Vector3.ONE})
	var half := 3650.0
	var grid := 25.0
	var n := int(half*2.0/grid)+1
	var open := PackedByteArray()
	open.resize(n*n)
	for c in range(n*n):
		var p := Vector2(-half+(c%n)*grid,-half+(c/n)*grid)
		if p.length() >= SkyWorld.crest(atan2(p.y,p.x)):
			open[c] = 0
			continue
		var top := -INF
		for m: Dictionary in made:
			var at: Vector3 = m.at
			var s: Vector3 = m.scale
			var d := Vector2(p.x-at.x,p.y-at.z)
			if d.length() > SkyPeak.HALF.length()*maxf(s.x,s.z): continue
			var local := Vector3(d.x,0.0,d.y).rotated(Vector3.UP,-float(m.turn))
			var h: Variant = m.shape.height_at(Vector2(local.x/s.x,local.z/s.z))
			if h != null: top = maxf(top,SkyPeak.SEA+(float(h)-SkyPeak.SEA)*s.y)
		open[c] = 1 if top <= SkyWorld.PASS_TOP else 0
	var b := SkyWorld.basins(open,n,grid,SkyWorld.CORE,SkyWorld.PASS_HALF)
	print("real rock: %d regions" % b.count)
	for z in range(-3300,3301,150):
		var row := ""
		for x in range(-3300,3301,75):
			var c := clampi(roundi((z+half)/grid),0,n-1)*n+clampi(roundi((x+half)/grid),0,n-1)
			var k: int = b.labels[c]
			var ch := "#" if b.dist[c] == 0.0 else ("." if k < 0 else "ABCDEFG"[k])
			if Vector2(x,z).length() < 80.0: ch = "P"
			row += ch
		print(row)
