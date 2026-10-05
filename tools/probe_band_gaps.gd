extends SceneTree
## Where the sky world's band (scripts/sky_world.gd) dips under the glide's
## ceiling outside its notches, or stands in a notch's middle, on the real
## rock (as tests/test_sky_world.gd reads it), and which ranges stand
## there: for chasing the band's gaps seed by seed. Headless:
##   Godot --headless --path . -s res://tools/probe_band_gaps.gd -- --seeds=99,31337
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const CEILING := SkyGlide.CEILING+SkyGlide.CEILING_FADE

func _initialize() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	var seeds := [99,31337]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = Array(a.trim_prefix("--seeds=").split(",")).map(func(s: String) -> int: return int(s))
	for s: int in seeds:
		SkyWorld.seed = s
		var made := []
		for r: Dictionary in SkyWorld.layout().ranges:
			if not SkyWorld.in_band(r.kind): continue
			made.append({"r":r,"shape":SkyPeak.make(int(r.seed),float(r.stature),bool(r.gorge))})
		for n: Dictionary in SkyWorld.layout().notches:
			print("seed %d notch at %.1f deg, half %.1f deg" % [s,rad_to_deg(n.angle),rad_to_deg(float(n.arc)*0.5/SkyWorld.crest(n.angle))])
		for k in range(1800):
			var angle := TAU*k/1800.0
			var c := SkyWorld.crest(angle)
			var way := Vector2(cos(angle),sin(angle))
			var top := -INF
			var who := ""
			var r := SkyWorld.BAND_IN-200.0
			while r <= c+1700.0:
				for m: Dictionary in made:
					var h := _rock(m,way*r)
					if h > top:
						top = h
						who = "%s#%d(%s%s, order %s/%s)" % [m.r.kind,int(m.r.index),"gorge " if m.r.gorge else "",str(snappedf(rad_to_deg(float(m.r.angle)),0.1)),str(m.r.get("order","-")),str(m.r.get("of","-"))]
				r += 8.0
			var notch := SkyWorld.in_notch(angle)
			var middle := false
			for n: Dictionary in SkyWorld.layout().notches:
				if absf(angle_difference(angle,float(n.angle))) <= float(n.arc)*0.4/SkyWorld.crest(float(n.angle)): middle = true
			if (middle and top > SkyGlide.FLOOR) or (not notch and top <= CEILING):
				print("  %.1f deg: top %.0f m by %s%s" % [rad_to_deg(angle),top,who," (notch middle)" if middle else ""])
	quit(0)

static func _rock(m: Dictionary, p: Vector2) -> float:
	var r: Dictionary = m.r
	var at: Vector3 = r.at
	var s: Vector3 = r.scale
	var d := Vector2(p.x-at.x,p.y-at.z)
	if d.length() > SkyPeak.HALF.length()*maxf(s.x,s.z): return -INF
	var local := Vector3(d.x,0.0,d.y).rotated(Vector3.UP,-float(r.turn))
	var h: Variant = m.shape.height_at(Vector2(local.x/s.x,local.z/s.z))
	return -INF if h == null else SkyPeak.SEA+(float(h)-SkyPeak.SEA)*s.y
