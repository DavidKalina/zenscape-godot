extends Node3D
## Kit caches: a find hidden inside a breakable kit piece (docs/design/
## kit-breaks/kit-caches-handoff.md). Any piece a kit breakable (scripts/
## kit_isle/kit_breaks.gd) has adopted holds something when it carries meta
## "holds" (what it holds: a GlyphPickup glyph, "rune" for the rune token).
## No per-piece code: the meta is the whole tag, and a piece without it is
## as before.
##
## - **The glow.** The piece's own meshes get one shared overlay
##   (shaders/kit_cache_glow.gdshader: a soft edge glow breathing slowly, a
##   faint shimmer band climbing it, a few twinkling specks) and a few motes
##   drift up off it (MOTES). Semi-loud: it reads from walking distance in
##   daylight, never a beacon. The telescope glints it while it's hidden.
## - **Too weak.** A hit in reach the piece withstands (kit_breaks
##   `withstood`) flares the glow (FLARE, fading over FLARE_TIME) and puffs a
##   little dust off it: something's in there, not with that.
## - **Broken.** The glow goes with the piece; the find comes up out of the
##   piece's middle (scripts/buried_find.gd, bare, with `from`) and settles
##   hovering HOVER m over the ground on the side the hit came from, STEP_OUT
##   m past the piece's footprint, out of the rubble's way.
## - **Taken.** With `tokens` (an isle's scripts/kit_isle/kit_tokens.gd) a
##   cache whose name is one of its waiting tokens is laid there once up
##   (`lay`: the ledger, the readout, the telescope), and a cache whose
##   token was taken in an earlier run holds nothing. Without, the cache
##   takes it itself when `motor`'s middle comes within reach.
##
## Use: after `kit_breaks.adopt(root)`, `caches.watch(kit_breaks)` and
## `caches.adopt(root)`. A cache's name is its piece's meta "holds_name",
## else the piece's node name.
const BuriedFind = preload("res://scripts/buried_find.gd")
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const Telescope = preload("res://scripts/telescope.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Dust = preload("res://scripts/enemies/body_dust.gd")
const HudIcons = preload("res://scripts/hud_icons.gd")
const GLOW_SHADER = preload("res://shaders/kit_cache_glow.gdshader")

const META := "holds"
const NAME_META := "holds_name"
## What the motif editor's key steps through (GlyphPickup glyphs).
const HOLDS := ["rune"]
## The find's size (m across: kit_tokens' SIZE).
const SIZE := 0.7
## Its hover over the ground (m) and how far past the piece's footprint,
## toward the hit, it settles.
const HOVER := 0.95
const STEP_OUT := 0.7
## Once up, for SETTLE s (the rubble coming down) it rises at LIFT m/s to
## stay HOVER over what lies under it; then it is the isle's token.
const SETTLE := 1.6
const LIFT := 2.5
## A weak hit's flare (the shader's `flare`, 1 at the hit) and its fade (s).
const FLARE := 1.0
const FLARE_TIME := 0.9
## The motes off a cache: how many at once, s each, m/s up.
const MOTES := 9
const MOTE_LIFE := 2.8
const MOTE_RISE := Vector2(0.12,0.3)
const MOTE_SIZE := 0.085
## The glow and motes when the find has no HUD tint (a rune's is pale cyan).
const TINT := Color(0.62,0.86,0.94)

## {node, holds, name, box (its frame), flare, phase, meshes} per cache still hidden.
var caches: Array[Dictionary] = []
## Finds out: {name, find, dig, taken}.
var finds: Array[Dictionary] = []
## An isle's tokens (kit_tokens.gd), or null.
var tokens: Node = null
## Who takes a find when there are no tokens (a PilotMotor: its `feet`).
var motor: Object = null
## For checks: weak hits flared, caches broken open, finds taken.
var flares := 0
var opened := 0
var took := 0
static var _material: ShaderMaterial = null
static var _mote_mesh: QuadMesh = null

func _init() -> void:
	name = "KitCaches"
	top_level = true

## Hear `breaks`' breaks and the hits it withstands.
func watch(breaks: Node) -> void:
	if not breaks.broke.is_connected(_on_broke): breaks.broke.connect(_on_broke)
	if not breaks.withstood.is_connected(_on_withstood): breaks.withstood.connect(_on_withstood)

## Every adopted piece at or under `root` (a target of a watched kit
## breakable) with meta "holds" made a cache. Returns how many.
func adopt(root: Node, breaks: Node = null) -> int:
	var n := 0
	var all: Array[Node] = [root]
	all.append_array(root.find_children("*","Node3D",true,false))
	for node: Node in all:
		if not node is Node3D or not node.has_meta(META): continue
		if breaks != null and not _targeted(breaks,node):
			push_warning("kit caches: %s holds %s but doesn't break; left plain" % [node.name,node.get_meta(META)])
			continue
		if add(node as Node3D,str(node.get_meta(META))): n += 1
	return n

static func _targeted(breaks: Node, node: Node) -> bool:
	for t: Dictionary in breaks.targets:
		if t.node == node and t.alive: return true
	return false

## `node` holding `holds`: glowing, glinting, its find made when it breaks.
## False if there's nothing to hold (its token taken in an earlier run).
func add(node: Node3D, holds: String) -> bool:
	var cache_name := str(node.get_meta(NAME_META,node.name))
	if tokens != null and _token_named(cache_name) and not tokens.waiting(cache_name): return false
	var c := {"node":node,"holds":holds,"name":cache_name,"box":_box_of(node),"flare":0.0,"phase":randf(),"meshes":[]}
	dress(node,float(c.phase),c.meshes,false,tint_of(holds))
	_motes(node,c.box as AABB)
	Telescope.spottable(node,tokens.objective(cache_name) if tokens != null and _token_named(cache_name) else "")
	caches.append(c)
	return true

func _token_named(cache_name: String) -> bool:
	if tokens == null: return false
	for t: Dictionary in tokens.tokens:
		if t.name == cache_name: return true
	return false

## The glow's colour for a find of `holds`: its HUD tint, a touch lighter.
static func tint_of(holds: String) -> Color:
	var item: Dictionary = HudIcons.item(holds)
	return Color(item.tint).lightened(0.15) if item.has("tint") else TINT

## The glow laid over every mesh at or under `node` (the editor's marking
## too) in `tint`; `into` collects them. `off` takes it away.
static func dress(node: Node3D, phase := 0.0, into: Array = [], off := false, tint := TINT) -> void:
	var all: Array[Node] = [node]
	all.append_array(node.find_children("*","MeshInstance3D",true,false))
	for m: Node in all:
		if not m is MeshInstance3D: continue
		var mi := m as MeshInstance3D
		if off:
			if mi.material_overlay == material(): mi.material_overlay = null
			continue
		mi.material_overlay = material()
		mi.set_instance_shader_parameter("phase",phase)
		mi.set_instance_shader_parameter("flare",0.0)
		mi.set_instance_shader_parameter("tint",tint)
		into.append(mi)

## The one glow material every cache shares.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = GLOW_SHADER
		_material.set_shader_parameter("tint",TINT)
	return _material

static func _box_of(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for m: Node in node.find_children("*","MeshInstance3D",true,false):
		var mi := m as MeshInstance3D
		if mi.mesh == null: continue
		var b := (inv*mi.global_transform)*mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

## A few motes drifting up off the piece's box.
func _motes(node: Node3D, box: AABB) -> void:
	var p := CPUParticles3D.new()
	p.name = "CacheMotes"
	p.amount = MOTES
	p.lifetime = MOTE_LIFE
	p.preprocess = MOTE_LIFE
	p.position = box.get_center()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box.size*0.5*Vector3(0.9,0.85,0.9)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = MOTE_RISE.x
	p.initial_velocity_max = MOTE_RISE.y
	p.mesh = mote_mesh()
	var fade := Curve.new()
	fade.add_point(Vector2(0.0,0.0))
	fade.add_point(Vector2(0.25,1.0))
	fade.add_point(Vector2(1.0,0.0))
	p.scale_amount_curve = fade
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(p)

static func mote_mesh() -> QuadMesh:
	if _mote_mesh == null:
		_mote_mesh = QuadMesh.new()
		_mote_mesh.size = Vector2.ONE*MOTE_SIZE
		var gradient := Gradient.new()
		gradient.set_color(0,Color(1,1,1,1))
		gradient.set_color(1,Color(1,1,1,0))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5,0.5)
		tex.fill_to = Vector2(1.0,0.5)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.albedo_texture = tex
		mat.albedo_color = TINT.lightened(0.35)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mote_mesh.material = mat
	return _mote_mesh

func _index_of(node: Node) -> int:
	for i in range(caches.size()):
		if caches[i].node == node: return i
	return -1

# --- The breaks' cues -------------------------------------------------------------------

func _on_withstood(node: Node3D, at: Vector3, _strength: float, _source: StringName) -> void:
	var i := _index_of(node)
	if i < 0: return
	caches[i].flare = FLARE
	flares += 1
	Dust.puff(self,at,0.7)

func _on_broke(node: Node3D, at: Vector3) -> void:
	var i := _index_of(node)
	if i < 0: return
	var c: Dictionary = caches[i]
	caches.remove_at(i)
	node.remove_from_group(Telescope.GROUP)
	opened += 1
	var xf := node.global_transform
	var box: AABB = c.box
	var mid := xf*box.get_center()
	var foot := xf*Vector3(box.get_center().x,box.position.y,box.get_center().z)
	# Toward the hit, flat; past the footprint's edge that way.
	var way := Vector3(at.x-mid.x,0.0,at.z-mid.z)
	if way.length() < 0.05: way = xf.basis.z
	way = way.normalized()
	var local_way := (xf.basis.inverse()*way)
	var reach := absf(local_way.x)*box.size.x*0.5+absf(local_way.z)*box.size.z*0.5
	var ground := foot+way*(minf(reach,maxf(box.size.x,box.size.z)*0.5)+STEP_OUT)
	ground.y = _ground_y(ground,foot.y,node)
	var holder := GlyphPickup.make(str(c.holds),SIZE,randf()*TAU,true)
	holder.name = "Cache_%s" % c.name
	add_child(holder)
	holder.motes_on(true)
	var dig := BuriedFind.new()
	dig.bare = true
	dig.setup(holder,ground,"",HOVER)
	dig.from = mid
	add_child(dig)
	dig.reveal()
	finds.append({"name":c.name,"find":holder,"dig":dig,"taken":false,"laid":false})
	Dust.puff(self,mid,1.0)

## The ground's height under `p` (the stone being broken looked through),
## else `fallback`.
func _ground_y(p: Vector3, fallback: float, skip: Node3D) -> float:
	if not is_inside_tree(): return fallback
	var ex: Array[RID] = []
	for b: Node in skip.find_children("*","CollisionObject3D",true,false): ex.append((b as CollisionObject3D).get_rid())
	if skip is CollisionObject3D: ex.append((skip as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(p+Vector3.UP*3.0,p+Vector3.DOWN*6.0)
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else fallback

# --- The frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	for c: Dictionary in caches:
		if float(c.flare) <= 0.0: continue
		c.flare = maxf(float(c.flare)-delta/FLARE_TIME,0.0)
		var k := float(c.flare)
		for mi: Variant in c.meshes:
			if is_instance_valid(mi): (mi as MeshInstance3D).set_instance_shader_parameter("flare",k*k)
	for f: Dictionary in finds:
		if bool(f.taken): continue
		var dig: Node3D = f.dig
		if not is_instance_valid(dig) or not dig.takeable(): continue
		if not bool(f.laid) and float(f.get("settle",0.0)) < SETTLE:
			_over_rubble(f,delta)
			if tokens != null: continue
		if tokens != null and not bool(f.laid) and tokens.waiting(str(f.name)):
			# The isle's own token from here on: its ledger, readout, glint.
			f.laid = tokens.lay(str(f.name),(f.find as Node3D).global_position,f.find)
		if bool(f.laid):
			if (tokens.taken as Array).has(str(f.name)):
				f.taken = true
				took += 1
			continue
		_touch(f)

## The first SETTLE s it's up, the rubble still coming down: lifted (at
## LIFT m/s) to HOVER over whatever lies under it now.
func _over_rubble(f: Dictionary, delta: float) -> void:
	f.settle = float(f.get("settle",0.0))+delta
	var holder: Node3D = f.find
	if not is_instance_valid(holder) or not is_inside_tree(): return
	var p := holder.global_position
	var q := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.5,p+Vector3.DOWN*4.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return
	var want: float = (hit.position as Vector3).y+HOVER
	if want > p.y: holder.global_position.y = minf(want,p.y+LIFT*delta)

## Taken by `motor` (no tokens): his middle within reach of it.
func _touch(f: Dictionary) -> void:
	if motor == null or not is_instance_valid(motor): return
	var holder: Node3D = f.find
	if not is_instance_valid(holder): return
	var feet: Vector3 = motor.get("feet")
	if (feet+Vector3.UP*Lines.FOOT_Y).distance_to(holder.global_position) < Lines.WALKER_REACH+SIZE*0.5:
		f.taken = true
		took += 1
		holder.take(hash(str(f.name)) & 0xffff)
