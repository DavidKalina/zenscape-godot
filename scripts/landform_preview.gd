extends RefCounted
## A look at the lower world's landforms before the lower world stands
## them: --landform=<name> (or several, comma separated) stands a small
## group of that landform's islands near the home island, in the open sky
## like a cluster (on the clusters' ring, scripts/sky_clusters.gd
## `near_spots`), on a flat stand-in sea (SEA_RADIUS m round, at the
## islands' sea level), each a fixed islet (scripts/sky_islets.gd `stand`)
## so the glide reads it as solid and the pilot can land on it. A landform
## is a script registered in LANDFORMS (NAME, ACROSS, `recipe`); the group
## is one island of each width in WIDTHS (m, held to its ACROSS range),
## laid along a line GAP m apart at the islands' widest,
## seeded by --landform-seed=N (SEED otherwise). Their keys are
## "landform:<name>:<k>" (tools/capture_landform.gd visits them).
## Hooked once, after the sky's clusters are laid (SkyIslands `reset`:
## `attach`).
##   godot --path . -- --no-title --landform=cliffs --no-clusters

const SkyIslets = preload("res://scripts/sky_islets.gd")

## The landforms by name.
const LANDFORMS := {
	"cliffs": preload("res://scripts/landform_cliffs.gd"),
}
## The islands' widths (m), and the gap between them (m).
const WIDTHS := [30.0,60.0,90.0]
const GAP := 26.0
const SEED := 7
## The stand-in sea's radius (m) and colour (linear); the islands' sea
## level stands this high in the home frame.
const SEA_RADIUS := 300.0
const SEA_COLOR := Color(0.07,0.2,0.24)
const SEA_Y := 2.0
## No random cluster within this far of a group.
const CLEAR := 420.0

## The landforms asked for (--landform=a,b), known ones only.
static func wanted() -> Array:
	var out: Array = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--landform="): continue
		for n: String in a.trim_prefix("--landform=").split(",",false):
			if LANDFORMS.has(n): out.append(n)
			else: push_warning("--landform: no landform %s (%s)" % [n,", ".join(LANDFORMS.keys())])
	return out

static func seed_value() -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--landform-seed="): return int(a.trim_prefix("--landform-seed="))
	return SEED

## Stands the asked-for groups for `islands` (SkyIslands, after its
## clusters' `reset`, their palette made): each on a clear spot near the
## home, the random clusters moved off it.
static func attach(islands: Node3D) -> void:
	var names := wanted()
	if names.is_empty(): return
	var clusters: Node3D = islands.clusters
	var islets: Node3D = clusters.islets
	var keys: Array = names.map(func(n: String) -> String: return "landform:"+n)
	var spots: Array = clusters.near_spots(keys,seed_value(),clusters.spots)
	for s: Dictionary in spots:
		clusters.spots = (clusters.spots as Array).filter(func(o: Dictionary) -> bool: return str(o.key).begins_with("near:") or Vector2(o.at.x-s.at.x,o.at.z-s.at.z).length() > CLEAR)
		islets.keep_clear.append(Vector3(s.at.x,s.at.z,CLEAR*0.6))
		var name_: String = str(s.motif).trim_prefix("landform:")
		_group(islets,clusters._palette,name_,Vector3(s.at.x,SEA_Y,s.at.z))

## One island of each width in WIDTHS along a line through `at`, and the
## sea under them.
static func _group(islets: Node3D, palette: Dictionary, name_: String, at: Vector3) -> void:
	var landform: Script = LANDFORMS[name_]
	var across: Vector2 = landform.ACROSS
	var widths: Array = WIDTHS.map(func(w: float) -> float: return clampf(w,across.x,across.y))
	var total := 0.0
	for w: float in widths: total += w*1.3+GAP
	var x := -total*0.5
	for k in range(widths.size()):
		var w: float = widths[k]
		x += w*0.65
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value(),name_,k])
		var spec: Dictionary = landform.recipe(rng,w)
		var home := at+Vector3(x,0.0,0.0)
		var out := SkyIslets.make(int(rng.seed % 16777216),spec,palette,home.y)
		var b: Dictionary = islets.stand("Landform_%s_%d" % [name_,k],home,out)
		b.fixed = true
		# Standing in the sea, it does not bob.
		b.phase = 0.0
		b.period = 1.0e9
		b.age = 0.0
		islets.built["landform:%s:%d" % [name_,k]] = b
		x += w*0.65+GAP
	var old := islets.get_node_or_null("LandformSea_%s" % name_)
	if old != null: old.free()
	var sea := MeshInstance3D.new()
	sea.name = "LandformSea_%s" % name_
	var disc := CylinderMesh.new()
	disc.top_radius = SEA_RADIUS
	disc.bottom_radius = SEA_RADIUS
	disc.height = 0.2
	disc.radial_segments = 64
	disc.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = SEA_COLOR
	material.roughness = 0.35
	material.metallic_specular = 0.4
	material.disable_receive_shadows = true
	disc.material = material
	sea.mesh = disc
	sea.position = at+Vector3.DOWN*0.1
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.set_meta("skip_reflection",true)
	islets.add_child(sea)
