extends Node3D
## The golden trees (endless flight, the wilderness finds; scripts/endless/
## finds_table.gd rows `gold-*`): one odd gold spruce standing in its wood,
## a real tree of the land's (scripts/endless/land_trees.gd) taken out of the
## bulk (LandTrees `knock`, so its solid and collider go) and stood again on its
## own node, gilt, glowing at dusk, glints drifting off its crown.
##
## A surge roll (scripts/endless/surge_smash.gd `hot`) into it knocks it down:
## the hit-stop and kick of a smash, a burst of gold leaves, and it goes over
## the plane's way with the weight of a rod tipping on its foot (TreeKnock's
## fall, scripts/endless/tree_knock.gd), thuds, bounces and lies there for
## good. At the thud its find's anchor `golden/<id>` is handed to the finds
## (`finds.anchor`), so the ring stands over the stump. Flown into without the
## roll it is any tree's hit (TreeKnock's costs: speed, a shove, the chain)
## but it shrugs it off and stands.
##
## Kept: the book's `opened` holds `golden/<id>` once one is down (`open_up`,
## saved at once), and a land loaded again lays it down where it stood and
## hands the anchor at once, so a find not yet flown is still there.
##
## Streamed: nothing is built or tested past REACH m of the eye (FREE to go);
## the hit test runs only within TEST m of the plane.

const WorldScale = preload("res://scripts/world_scale.gd")
const LandTrees = preload("res://scripts/endless/land_trees.gd")
const TreeKnock = preload("res://scripts/endless/tree_knock.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const LEAF_SHADER := preload("res://shaders/golden_leaf.gdshader")

## The trees, by find id: `at` the plan tree's spot (world XZ, the nearest
## tree to it within PICK m is the one), `wood` what kind it stands in.
const SITES := [
	# The valley wood north-east of the start meadow, ~470 m off.
	{"id":"gold-spruce","at":Vector2(358.2,-310.3),"wood":"dense"},
	# A grove's clump in the south meadows, by the gap.
	{"id":"gold-grove","at":Vector2(-1131.3,2852.5),"wood":"grove"},
	# The wood on the east hills, past the arch run.
	{"id":"gold-shore","at":Vector2(2791.8,932.2),"wood":"dense"},
]
const PICK := 6.0
const REACH := 1500.0
const FREE := 1800.0
const TEST := 80.0
## Grown this much over the tree it stands for, to read over its wood.
const GROW := 1.2
const WIDE := 1.2
## The look: gilt by day, a glow coming on as the light goes (daylight from
## DARK.x to DARK.y), its light's energy and range.
const GOLD := Color(1.0,0.66,0.12)
const BARK := Color(0.45,0.3,0.12)
const GLOW_DAY := 0.55
const GLOW_NIGHT := 1.6
const DARK := Vector2(0.6,0.05)
const LAMP := Vector2(2.2,22.0)
## The fall: the snap's spin (rad/s), the rod's pull (TreeKnock FALL_G), the
## bounce, the stump (m).
const SNAP := 1.6
const FALL_G := 1.5
const BOUNCE := 0.22
const BOUNCES := 2
const STUMP := 0.6
## A plain hit: shrugged off, the sway's kick (rad) and spring (Hz, damping).
const SWAY_KICK := 0.12
const SWAY_HZ := 1.4
const SWAY_DAMP := 0.18
const COOL := 0.8

signal felled(id: String)

var game: Node3D
## id -> {id, at, wood, state ("away", "up"), down (bool), tree {x, z, foot,
## height, bottom, reach, radius}, stood {variant, trunk}, node, pivot, lamp,
## glints, fall {...}, sway, sway_v, cool}
var sites := {}
## Counted, for the drivers.
var falls := 0
var shrugs := 0
var _gold: StandardMaterial3D
var _bark: StandardMaterial3D
var _leaf_mat: ShaderMaterial
var _glint_mat: StandardMaterial3D

func _init() -> void:
	name = "GoldenTrees"

func setup(g: Node3D) -> void:
	game = g
	for s: Dictionary in SITES:
		var id := str(s.id)
		var site := {"id":id,"at":s.at,"wood":s.wood,"state":"away","down":game.book.opened.has(key(id)),"cool":0.0,"sway":0.0,"sway_v":0.0}
		sites[id] = site
		if bool(site.down): _hand(site)
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = GOLD
	_gold.metallic = 0.75
	_gold.roughness = 0.45
	_gold.emission_enabled = true
	_gold.emission = GOLD
	_gold.emission_energy_multiplier = GLOW_DAY
	_bark = StandardMaterial3D.new()
	_bark.albedo_color = BARK
	_bark.metallic = 0.6
	_bark.roughness = 0.45
	_bark.emission_enabled = true
	_bark.emission = BARK
	_bark.emission_energy_multiplier = GLOW_DAY*0.5
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = LEAF_SHADER
	_leaf_mat.set_shader_parameter("leaf_tex",_leaf_texture())
	_warm()

## The fell's first use done at setup: a burst of gold leaves and of each
## debris kind, too small to see, drawn once before the eye. Their pipelines
## are built under the start's first frames, not at the first tree felled,
## where their 13 pipelines held a frame up to ~0.5 s rendered (`--gold-warm=0`
## leaves them to the fell). The ring's rise has no first-use cost of its own.
func _warm() -> void:
	if "--gold-warm=0" in preload("res://scripts/launch_args.gd").user_args(): return
	var cam: Camera3D = game.get("camera")
	if cam == null: return
	var p := _leaf_burst(Vector3.UP,2,0.2)
	p.lifetime = 0.5
	(p.draw_pass_1 as QuadMesh).size = Vector2.ONE*0.001
	p.position = Vector3(0.0,0.0,-6.0)
	cam.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var debris: Variant = game.get("debris")
	if debris != null: debris.warm(cam,Vector3(0.0,0.0,-6.0))

## The book's name for tree `id` down.
static func key(id: String) -> String:
	return "golden/"+id

func is_down(id: String) -> bool:
	return bool((sites.get(id,{}) as Dictionary).get("down",false))

## Where tree `id` stands (world, its foot), or Vector3.INF before it's found.
func foot_of(id: String) -> Vector3:
	var site: Dictionary = sites.get(id,{})
	if not site.has("tree"): return Vector3.INF
	var t: Dictionary = site.tree
	return Vector3(float(t.x),float(t.foot),float(t.z))

## One frame before the plane's step: the trees streamed round the eye, the
## plane's coming spot tried against the standing ones.
func before(delta: float) -> void:
	var eye: Vector3 = game.camera.global_position
	var dark := smoothstep(DARK.x,DARK.y,_daylight())
	_gold.emission_energy_multiplier = lerpf(GLOW_DAY,GLOW_NIGHT,dark)
	_bark.emission_energy_multiplier = lerpf(GLOW_DAY,GLOW_NIGHT,dark)*0.5
	for id: String in sites:
		var site: Dictionary = sites[id]
		var at: Vector2 = site.at
		var d := Vector2(eye.x,eye.z).distance_to(at)
		match str(site.state):
			"away":
				if d < REACH: _stand(site)
			"up":
				if d > FREE:
					_free(site)
					continue
				if site.lamp != null: (site.lamp as OmniLight3D).light_energy = LAMP.x*dark
				site.cool = maxf(float(site.cool)-delta,0.0)
				if site.has("fall"): _fall_step(site,delta)
				elif not bool(site.down):
					_sway_step(site,delta)
					_try_hit(site,delta)

## A frame while the flight is held (find_reveal.gd): a falling tree goes on
## falling, and nothing else.
func hold_step(delta: float) -> void:
	for id: String in sites:
		var site: Dictionary = sites[id]
		if str(site.state) == "up" and site.has("fall"): _fall_step(site,delta)

func _daylight() -> float:
	var look: Variant = game.get("look")
	if look == null or look.celestial == null: return 1.0
	return float(look.celestial.daylight)

# --- Standing ---------------------------------------------------------------------

## The tree taken from the land's (once its cell is there) and stood gilt.
func _stand(site: Dictionary) -> void:
	var trees: Node3D = game.get("trees")
	if trees == null or not bool(trees.enabled): return
	if not site.has("tree"):
		var t := _pick(trees,site.at)
		if t.is_empty(): return
		site.tree = t
		var stood: Dictionary = trees.knock(t)
		if stood.is_empty() or int(stood.variant) < 0: stood = {"variant":-1,"trunk":Transform3D(Basis(),Vector3(float(t.x),float(t.foot),float(t.z)))}
		site.stood = stood
	_build(site,trees)
	site.state = "up"

## The plan tree nearest `at` within PICK m, from its cell's solid (LandTrees
## `cell_trees`), or {} while that cell isn't planned.
func _pick(trees: Node3D, at: Vector2) -> Dictionary:
	var ck := LandTrees.Plan.cell_of(at.x,at.y)
	var solid: PackedFloat32Array = trees.cell_trees(ck)
	if solid.is_empty(): return {}
	var best := {}
	var near := PICK
	for i in solid.size()/8:
		var q := i*8
		var dd := Vector2(solid[q]-at.x,solid[q+1]-at.y).length()
		if dd >= near: continue
		near = dd
		best = {"x":solid[q],"z":solid[q+1],"foot":solid[q+2],"height":solid[q+3],"bottom":solid[q+4],"reach":solid[q+5],"radius":solid[q+6]}
	# Knocked already (this run): its numbers are zero; the plan's own stand in.
	if not best.is_empty() and float(best.height) <= 0.0: return {}
	return best

func _build(site: Dictionary, trees: Node3D) -> void:
	var t: Dictionary = site.tree
	var stood: Dictionary = site.stood
	# The mature spruce whatever it stood for (its full crown reads best),
	# at the tree's height times GROW, WIDE across.
	var parts: Array = trees.parts(0)
	var foot: Vector3 = (stood.trunk as Transform3D).origin
	var height := float(t.height)
	var top := maxf((parts[1] as Mesh).get_aabb().end.y,0.1)
	var k := height*GROW/top
	var xf := Transform3D(Basis(Vector3.UP,float(absi(hash(str(site.id)))%628)/100.0)*Basis.from_scale(Vector3(k*WIDE,k,k*WIDE)),foot)
	site.height = height*GROW
	var root := Node3D.new()
	root.name = "Gold_"+str(site.id)
	add_child(root)
	site.node = root
	var pivot := Node3D.new()
	pivot.name = "Tree"
	pivot.position = foot+Vector3.UP*STUMP
	root.add_child(pivot)
	site.pivot = pivot
	var local := Transform3D(xf.basis,Vector3.DOWN*STUMP)
	pivot.add_child(_mesh(parts[0],local,_bark))
	pivot.add_child(_mesh(parts[1],local,_gold))
	# The stump left when it goes: the trunk's foot, STUMP high.
	var trunk_top := maxf((parts[0] as Mesh).get_aabb().end.y*xf.basis.y.length(),0.1)
	var stump := _mesh(parts[0],Transform3D(xf.basis*Basis.from_scale(Vector3(1.0,STUMP*1.6/trunk_top,1.0)),foot),_bark)
	stump.name = "Stump"
	root.add_child(stump)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0,0.78,0.4)
	lamp.omni_range = LAMP.y
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0,float(site.height)*0.5,0.0)
	pivot.add_child(lamp)
	site.lamp = lamp
	var glints := _glints(float(site.height),float(t.radius)*GROW*WIDE)
	glints.position = Vector3(0.0,float(site.height)*0.45,0.0)
	pivot.add_child(glints)
	site.glints = glints
	if bool(site.down): _lay(site,site.get("way",_seeded_way(site)),true)

func _mesh(mesh: Mesh, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = mat
	mi.set_meta("skip_reflection",true)
	return mi

## A soft four-point star on a round glow, alpha only in its edge (white).
static func _star_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2((x+0.5)/n-0.5,(y+0.5)/n-0.5)*2.0
			var r := d.length()
			var core := exp(-r*r*14.0)
			var ray := exp(-absf(d.x)*26.0)*exp(-absf(d.y)*2.6)+exp(-absf(d.y)*26.0)*exp(-absf(d.x)*2.6)
			var a := clampf(core*0.9+ray*0.8,0.0,1.0)*clampf(1.0-r*r,0.0,1.0)
			img.set_pixel(x,y,Color(1.0,1.0,1.0,a))
	return ImageTexture.create_from_image(img)

## A leaf: a pointed oval with a darker midrib and veins, alpha-cut at its edge
## (the quad is 1 m wide by 1 m tall; the leaf lies along its length).
static func _leaf_texture() -> ImageTexture:
	var n := 96
	var img := Image.create(n,n,true,Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x+0.5)/n*2.0-1.0
			var v := (y+0.5)/n*2.0-1.0
			var along := (v+0.92)/1.84
			var half := 0.46*pow(sin(clampf(along,0.0,1.0)*PI),0.75)*(1.0-0.25*along)
			var edge := half-absf(u)
			var a := clampf(edge*n*0.5,0.0,1.0) if along > 0.0 and along < 1.0 else 0.0
			var rib := exp(-u*u*400.0)
			var vein := 0.5+0.5*sin((along*9.0-absf(u)*5.0)*PI)
			var shade := 1.0-0.28*rib-0.07*vein*clampf(absf(u)*4.0,0.0,1.0)
			var tone := lerpf(1.0,0.78,clampf(absf(u)/maxf(half,0.01),0.0,1.0)*0.5)
			var c := shade*tone
			img.set_pixel(x,y,Color(c,c*0.97,c*0.9,a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Gold glints off the crown: soft sparkles that fade in, flare and go out,
## sinking and drifting on the wind, big and small. The tell by day and night.
func _glints(height: float, radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Glints"
	p.amount = 34
	p.lifetime = 4.0
	p.randomness = 0.8
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(radius,1.5)*1.1
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0.35,-0.25,0.15)
	pm.damping_min = 0.3
	pm.damping_max = 0.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.angle_min = -25.0
	pm.angle_max = 25.0
	pm.scale_min = 0.5
	pm.scale_max = 2.4
	var tw := Curve.new()
	tw.add_point(Vector2(0.0,0.0))
	tw.add_point(Vector2(0.22,0.55))
	tw.add_point(Vector2(0.34,1.0))
	tw.add_point(Vector2(0.46,0.5))
	tw.add_point(Vector2(0.58,0.85))
	tw.add_point(Vector2(1.0,0.0))
	var tt := CurveTexture.new()
	tt.curve = tw
	pm.scale_curve = tt
	var fade := Gradient.new()
	fade.set_color(0,Color(1.0,0.85,0.4,0.0))
	fade.set_color(1,Color(1.0,0.78,0.3,0.0))
	fade.add_point(0.25,Color(1.0,0.9,0.5,1.0))
	fade.add_point(0.6,Color(1.0,0.86,0.45,0.8))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*0.9
	if _glint_mat == null:
		_glint_mat = StandardMaterial3D.new()
		_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glint_mat.vertex_color_use_as_albedo = true
		_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_glint_mat.albedo_texture = _star_texture()
		_glint_mat.albedo_color = Color(2.4,1.8,0.8)
		_glint_mat.disable_receive_shadows = true
	quad.material = _glint_mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-radius-6.0,-height,-radius-6.0),Vector3(radius*2.0+12.0,height*2.0+8.0,radius*2.0+12.0))
	return p

func _free(site: Dictionary) -> void:
	if site.has("node") and is_instance_valid(site.node): (site.node as Node).queue_free()
	site.erase("node")
	site.erase("fall")
	site.pivot = null
	site.lamp = null
	site.state = "away"

# --- The hit ----------------------------------------------------------------------

## The plane's spot, where it's going and its wings against the tree's cone;
## on a surge roll the way ahead too (SurgeSmash's look), so it goes first.
func _try_hit(site: Dictionary, delta: float) -> void:
	var plane = game.plane
	if not bool(game.hand_landing.flying()) or float(site.cool) > 0.0: return
	var t: Dictionary = site.tree
	var p: Vector3 = plane.position
	if Vector2(p.x-float(t.x),p.z-float(t.z)).length() > TEST: return
	var v: Vector3 = plane.velocity
	var smash: Variant = game.get("smash")
	var hot: bool = smash != null and bool(smash.hot)
	var half := WorldScale.span*0.5
	var pts: Array = [p,p+v*delta]
	var side := v.cross(Vector3.UP).normalized() if v.length() > 1.0 else Vector3.RIGHT
	for s: float in [-1.0,-0.5,0.5,1.0]: pts.append(p+side*half*s)
	if hot and v.length() > 1.0:
		var look := maxf(v.length()*0.1,6.0)
		var s2 := 1.5
		while s2 <= look:
			pts.append(p+v.normalized()*s2)
			s2 += 1.5
	var best := -1.0
	var at := p
	for q: Vector3 in pts:
		var deep := _depth(site,q,half*0.3 if hot else 0.0)
		if deep > best:
			best = deep
			at = q
	if best <= 0.0: return
	if hot: _fell(site,at)
	else: _shrug(site,at,best)

## How far under the cone's top `q` is (m; <= 0 outside), the cone widened `pad`.
func _depth(site: Dictionary, q: Vector3, pad: float) -> float:
	var t: Dictionary = site.tree
	var reach := float(t.reach)*GROW*WIDE+pad
	var d := Vector2(q.x-float(t.x),q.z-float(t.z)).length()
	if d >= reach: return -1.0
	var foot := float(t.foot)
	if q.y < foot-1.0: return -1.0
	var top := lerpf(foot+float(site.height),foot+float(t.bottom)*GROW,d/reach)
	return top-q.y

## Flown into on a surge roll: down it goes.
func _fell(site: Dictionary, at: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var plane = game.plane
	var v: Vector3 = plane.velocity
	var flat := Vector3(v.x,0.0,v.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3(-sin(float(plane.heading)),0.0,-cos(float(plane.heading)))
	falls += 1
	site.down = true
	site.way = flat
	var ts := Time.get_ticks_usec()
	game.book.open_up(key(str(site.id)))
	if FrameLog.on: FrameLog.add(&"g_save",(Time.get_ticks_usec()-ts)/1000.0)
	var smash: Variant = game.get("smash")
	if smash != null:
		smash.hub.pause(int(smash.HIT_STOP.x),smash.HIT_STOP.y)
		smash.vapour = 1.0
		smash.hits += 1
		if not bool(plane.rolling): plane.surge_roll(float(plane.roll_dir) if float(plane.roll_dir) != 0.0 else 1.0,smash.HIT_TURNS,smash.HIT_SPIN_S)
	game.feel_hit(0.03,11.0)
	var t: Dictionary = site.tree
	var foot := Vector3(float(t.x),float(t.foot),float(t.z))
	var crown := foot+Vector3.UP*float(site.height)*0.7
	game.sound.shot("wood-crack",1.0,0.8,at)
	game.sound.shot("leaf-burst",0.7,0.9,at)
	game.sound.shot("tree-creak",0.6,0.75,foot)
	game.debris.burst("wood",foot+Vector3.UP*clampf(at.y-foot.y,1.0,float(site.height)),(Vector3.UP*0.6+flat).normalized(),true)
	game.debris.burst("needles",crown,(Vector3.UP*0.35+flat).normalized(),true)
	_leaves(crown,flat,90,float(t.radius)*GROW*WIDE)
	_lay(site,flat,false)
	felled.emit(str(site.id))
	if FrameLog.on: FrameLog.add(&"g_fell",(Time.get_ticks_usec()-t0)/1000.0)

## Flown into without the roll: any tree's toll on the plane (TreeKnock's
## numbers), and it sways and stands.
func _shrug(site: Dictionary, at: Vector3, deep: float) -> void:
	var plane = game.plane
	var t: Dictionary = site.tree
	shrugs += 1
	site.cool = COOL
	var heft := clampf(deep/maxf(float(site.height)*TreeKnock.HEFT,0.5),0.0,1.0)
	var v: Vector3 = plane.velocity
	var flat := Vector3(v.x,0.0,v.z).normalized() if Vector3(v.x,0.0,v.z).length() > 0.1 else Vector3.FORWARD
	var off := Vector3(plane.position.x-float(t.x),0.0,plane.position.z-float(t.z))
	var across := off-flat*off.dot(flat)
	var away := across.normalized() if across.length() > 0.05 else flat.cross(Vector3.UP)
	var keep := lerpf(TreeKnock.KEEP.x,TreeKnock.KEEP.y,heft)
	var shove := (away*TreeKnock.JOLT.x+Vector3.UP*TreeKnock.JOLT.y)*lerpf(0.4,1.0,heft)
	var yaw := signf(flat.cross(away).y)*TreeKnock.YAW*heft
	plane.knock(keep,shove,yaw)
	if TreeKnock.LOSES_CHAIN: game.near.lose()
	game.feel_hit(0.012,4.0)
	site.sway_v = float(site.sway_v)+SWAY_KICK*lerpf(0.5,1.0,heft)*8.0
	site.sway_axis = Vector3.UP.cross(flat).normalized()
	var crown := Vector3(float(t.x),float(t.foot)+float(site.height)*0.75,float(t.z))
	game.debris.burst("needles",crown,(Vector3.UP*0.35+flat).normalized(),heft > 0.5)
	_leaves(crown,flat,30,float(t.radius)*GROW*WIDE)
	game.sound.shot("leaf-burst",0.5,0.9,crown)
	game.sound.shot("tree-creak",0.25,0.9,crown)

func _sway_step(site: Dictionary, delta: float) -> void:
	var s := float(site.sway)
	var sv := float(site.sway_v)
	if absf(s) < 0.0005 and absf(sv) < 0.0005: return
	var w := TAU*SWAY_HZ
	sv += (-w*w*s-2.0*SWAY_DAMP*w*sv)*delta
	s += sv*delta
	site.sway = s
	site.sway_v = sv
	var axis: Vector3 = site.get("sway_axis",Vector3.RIGHT)
	(site.pivot as Node3D).basis = Basis(axis,s)

# --- The fall ---------------------------------------------------------------------

## The way a tree loaded down lies: seeded by its spot.
func _seeded_way(site: Dictionary) -> Vector3:
	var a := float(absi(hash(str(site.id)))%6283)/1000.0
	return Vector3(sin(a),0.0,cos(a))

## Tree going over along `way` (flat): at once to its rest with `now`.
func _lay(site: Dictionary, way: Vector3, now: bool) -> void:
	var t: Dictionary = site.tree
	var height := float(site.height)
	var foot := Vector3(float(t.x),float(t.foot),float(t.z))
	var reach := height*0.6
	var h0 := float(game.field.height(foot.x,foot.z))
	var h1 := float(game.field.height(foot.x+way.x*reach,foot.z+way.z*reach))
	var slope := atan2(h1-h0,reach)
	var lift := atan2(float(t.radius)*GROW*WIDE*0.55,height*0.45)
	var rest := clampf(PI*0.5-slope-lift,0.9,1.9)
	var axis := Vector3.UP.cross(way).normalized()
	var fall := {"axis":axis,"angle":0.03,"spin":SNAP,"rest":rest,"k":1.5*9.8*FALL_G/height,"bounces":0,"done":false,"way":way}
	if now:
		fall.angle = rest
		fall.done = true
		(site.pivot as Node3D).basis = Basis(axis,rest)
		_settled(site,true)
		return
	site.fall = fall

func _fall_step(site: Dictionary, delta: float) -> void:
	var f: Dictionary = site.fall
	var pivot: Node3D = site.pivot
	var a := float(f.angle)
	var w := float(f.spin)+float(f.k)*sin(a)*delta
	a += w*delta
	if a >= float(f.rest):
		a = float(f.rest)
		var t: Dictionary = site.tree
		var crown := pivot.position+Vector3(f.way)*float(site.height)*0.65
		if int(f.bounces) == 0:
			var t0 := Time.get_ticks_usec()
			game.sound.shot("wood-thud",0.9,0.75,crown)
			game.sound.shot("tree-fall",0.7,0.85,crown)
			game.debris.burst("needles",crown,Vector3.UP,true)
			_leaves(crown,Vector3.UP,60,float(t.radius)*GROW*WIDE)
			game.feel_hit(0.008,2.0)
			_settled(site,false)
			if FrameLog.on: FrameLog.add(&"g_thud",(Time.get_ticks_usec()-t0)/1000.0)
		if int(f.bounces) >= BOUNCES or w < 0.4:
			site.erase("fall")
			pivot.basis = Basis(Vector3(f.axis),a)
			return
		f.bounces = int(f.bounces)+1
		w = -w*BOUNCE
	f.angle = a
	f.spin = w
	pivot.basis = Basis(Vector3(f.axis),a)

## Down: the glints out, the find's anchor handed over the stump.
func _settled(site: Dictionary, quiet: bool) -> void:
	if site.get("glints") != null and is_instance_valid(site.glints): (site.glints as GPUParticles3D).emitting = false
	if not quiet: _hand(site)

## The ring's anchor: over the stump (the table's `up` over it).
func _hand(site: Dictionary) -> void:
	var finds: Variant = game.get("finds")
	if finds == null: return
	var at: Vector2 = site.at
	var p := foot_of(str(site.id))
	if p == Vector3.INF: p = Vector3(at.x,float(game.field.height(at.x,at.y)),at.y)
	# Watched from beside the fall, the trunk lying across the view.
	var way: Vector3 = site.get("way",Vector3.ZERO)
	finds.anchor(key(str(site.id)),p,Vector3.UP.cross(way).normalized() if way != Vector3.ZERO else Vector3.ZERO)

## A burst of gold leaves at `at`, thrown toward `way`: lit leaf pieces that
## tumble and flutter down, carried a little by the air, thinning out by the
## end of their fall.
func _leaves(at: Vector3, way: Vector3, n: int, radius: float) -> void:
	var p := _leaf_burst(way,n,radius)
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

## The leaves' particles (not yet in the tree): `n` leaves thrown toward `way`.
func _leaf_burst(way: Vector3, n: int, radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = int(n*1.5)
	p.lifetime = 9.0
	p.randomness = 0.5
	p.local_coords = false
	p.fixed_fps = 0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = maxf(radius*0.8,1.0)
	pm.direction = (way+Vector3.UP*0.5).normalized()
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 9.0
	var air := Vector3.ZERO
	var wind: Variant = game.plane.get("wind")
	if wind != null: air = Vector3((wind as Vector3).x,0.0,(wind as Vector3).z)
	pm.gravity = Vector3(1.2,-5.5,0.7)+air*0.4
	pm.damping_min = 1.6
	pm.damping_max = 2.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 2.4
	pm.turbulence_noise_scale = 1.3
	pm.turbulence_influence_min = 0.1
	pm.turbulence_influence_max = 0.35
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var life := Curve.new()
	life.add_point(Vector2(0.0,1.0))
	life.add_point(Vector2(0.7,1.0))
	life.add_point(Vector2(1.0,0.0))
	var lt := CurveTexture.new()
	lt.curve = life
	pm.scale_curve = lt
	var tint := Gradient.new()
	tint.set_color(0,Color(1.0,0.8,0.22))
	tint.set_color(1,Color(0.85,0.42,0.06))
	tint.add_point(0.5,Color(1.0,0.62,0.12))
	var tt := GradientTexture1D.new()
	tt.gradient = tint
	pm.color_initial_ramp = tt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5,0.72)
	quad.material = _leaf_mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-40.0,-60.0,-40.0),Vector3(80.0,80.0,80.0))
	return p
