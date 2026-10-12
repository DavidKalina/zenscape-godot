extends Node3D
## The air round the dragon's roost (docs/design/dragon-roost/round3.md),
## with --dragon-roost: what lives and moves round its mountain
## (scripts/kit_isle/motif_dragon_roost.gd) besides the sleeping dragon
## (scripts/dragon_roost.gd). The aqueduct isle makes it with the roost's
## dragon and shows it once the mountain stands.
##
## - His weather: a thin wreath of cloud circling the summit slowly
##   (WREATH: its own ring, apart from the sky's clouds, which keep off the
##   roost), and a faint cold haze hanging round the mountain's flanks.
## - A cold, dim air on and round the mountain: a light that takes warmth
##   away (a negative light, warm, so what it leaves is colder and dimmer).
## - Carrion birds wheeling over the ledge and the summit on thermals, dark,
##   gliding with wings raised, now and then a few slow beats.
## - A sky folk plane, crashed nose first into a crag under the ledge's
##   front, worn out and broken (scripts/plane_figure.gd `set_missing`,
##   `set_wear`): a warning to pilots who come too close.
const Roost = preload("res://scripts/kit_isle/motif_dragon_roost.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The wreath: puffs, its radius and height band round the summit's axis
## (m, world, over the shoulder), a puff's size, one turn (s).
const WREATH := 44
const WREATH_R := Vector2(40.0,62.0)
const WREATH_Y := Vector2(0.0,30.0)
const WREATH_SIZE := Vector2(16.0,30.0)
const WREATH_TURN := 260.0
const WREATH_TONE := Color(0.82,0.84,0.88,0.42)
## The haze: puffs round the flanks, their size, its tone.
const HAZE := 14
const HAZE_SIZE := Vector2(55.0,85.0)
const HAZE_TONE := Color(0.62,0.66,0.74,0.13)
## The cold: the light taking warmth away (its colour, energy, reach m).
const COLD := Color(1.0,0.82,0.6)
const COLD_ENERGY := 0.22
const COLD_REACH := 190.0
## Carrion birds: how many, their span (m), their circles' radius and
## height over the ledge (m), their pace (m/s).
const BIRDS := 9
const BIRD_SPAN := 2.6
const BIRD_R := Vector2(22.0,60.0)
const BIRD_Y := Vector2(18.0,70.0)
const BIRD_PACE := Vector2(7.0,10.0)
const BIRD_TONE := Color(0.07,0.06,0.06)

var _wreath: Node3D
var _haze: Node3D
var _birds: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
## The way toward the aqueduct isle (flat, world): the wreath dips on the
## far side, so from there it rings the summit over the dragon, not over
## his head.
var _toward := Vector2.ZERO
var _t := 0.0
var _rng := RandomNumberGenerator.new()
## The summit's axis at the shoulder and the ledge's middle (world).
var axis := Vector3.ZERO
var ledge := Vector3.ZERO
## The crashed plane (null until set up).
var wreck: Node3D

func setup() -> void:
	name = "RoostAir"
	_rng.seed = 73
	var t2 := Roost.own(Roost.TOWER_C)
	axis = Vector3(t2.x,Roost.TOP+Roost.SHOULDER_H*Roost.SPAN,t2.y)+Roost.AT
	var l2 := Roost.own(Roost.LEDGE_C)
	ledge = Vector3(l2.x,Roost.TOP+Roost.LEDGE_H*Roost.SPAN,l2.y)+Roost.AT
	_toward = Roost.V.normalized()
	_build_wreath()
	_build_haze()
	_build_cold()
	_build_birds()
	_build_wreck()

# --- His weather ---------------------------------------------------------------------

func _puff_material(tone: Color, fade: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = tone
	m.albedo_texture = _puff_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = fade
	m.roughness = 1.0
	# Lit through from behind as a cloud is (else a puff with the sun past
	# it reads as a dark smudge on the sky).
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.backlight_enabled = true
	m.backlight = Color(0.75,0.75,0.78)
	return m

func _build_wreath() -> void:
	_wreath = Node3D.new()
	_wreath.name = "Wreath"
	_wreath.position = axis
	add_child(_wreath)
	var mat := _puff_material(WREATH_TONE,10.0)
	for i in range(WREATH):
		var a := TAU*float(i)/WREATH+_rng.randf_range(-0.06,0.06)
		var r := _rng.randf_range(WREATH_R.x,WREATH_R.y)
		var quad := QuadMesh.new()
		var s := _rng.randf_range(WREATH_SIZE.x,WREATH_SIZE.y)
		quad.size = Vector2(s*1.6,s*0.8)
		quad.material = mat
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_wreath.add_child(puff)
		_puffs.append({"node":puff,"a":a,"r":r,"y":_rng.randf_range(-4.0,4.0)})

func _build_haze() -> void:
	_haze = Node3D.new()
	_haze.name = "Haze"
	_haze.position = axis
	add_child(_haze)
	var mat := _puff_material(HAZE_TONE,30.0)
	for i in range(HAZE):
		var a := TAU*float(i)/HAZE+_rng.randf_range(-0.2,0.2)
		var r := _rng.randf_range(70.0,110.0)
		var quad := QuadMesh.new()
		var s := _rng.randf_range(HAZE_SIZE.x,HAZE_SIZE.y)
		quad.size = Vector2(s*1.5,s*0.7)
		quad.material = mat
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.position = Vector3(cos(a)*r,_rng.randf_range(-70.0,-10.0),sin(a)*r)
		_haze.add_child(puff)

func _build_cold() -> void:
	var cold := OmniLight3D.new()
	cold.name = "Cold"
	cold.light_negative = true
	cold.light_color = COLD
	cold.light_energy = COLD_ENERGY
	cold.omni_range = COLD_REACH
	cold.omni_attenuation = 1.4
	cold.shadow_enabled = false
	cold.position = axis+Vector3(0.0,-25.0,0.0)
	add_child(cold)

static func _puff_texture() -> Texture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	tex.width = 64
	tex.height = 64
	var gr := Gradient.new()
	gr.set_color(0,Color(1,1,1,1))
	gr.set_color(1,Color(1,1,1,0))
	gr.add_point(0.45,Color(1,1,1,0.7))
	tex.gradient = gr
	return tex

## Each puff on round the ring; the ring tilted fixed in the world: lowest
## on the far side from the aqueduct isle, highest on the near.
func _wreath_frame() -> void:
	var turn := TAU*_t/WREATH_TURN
	for p: Dictionary in _puffs:
		var a := float(p.a)-turn
		var d := Vector2(cos(a),sin(a))
		var near := d.dot(_toward)
		var y := lerpf(WREATH_Y.x,WREATH_Y.y,0.5+0.5*near)+float(p.y)+1.5*sin(_t*0.07+float(p.a))
		(p.node as Node3D).position = Vector3(d.x*float(p.r),y,d.y*float(p.r))

# --- Carrion birds ----------------------------------------------------------------------

func _build_birds() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BIRD_TONE
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := _bird_body()
	var wing := _bird_wing()
	for i in range(BIRDS):
		var bird := Node3D.new()
		bird.name = "Carrion%d" % i
		add_child(bird)
		var b := MeshInstance3D.new()
		b.mesh = body
		b.material_override = mat
		bird.add_child(b)
		var wings: Array[Node3D] = []
		for side: float in [-1.0,1.0]:
			var w := MeshInstance3D.new()
			w.mesh = wing
			w.material_override = mat
			w.scale = Vector3(side,1.0,1.0)
			bird.add_child(w)
			wings.append(w)
		# Two thermals: over the ledge and over the summit.
		var over := ledge if i%3 != 0 else axis
		_birds.append({"node":bird,"wings":wings,"c":over+Vector3(_rng.randf_range(-15,15),_rng.randf_range(BIRD_Y.x,BIRD_Y.y),_rng.randf_range(-15,15)),
			"r":_rng.randf_range(BIRD_R.x,BIRD_R.y),"w":_rng.randf_range(BIRD_PACE.x,BIRD_PACE.y)/_rng.randf_range(BIRD_R.x,BIRD_R.y)*(1.0 if _rng.randf() < 0.7 else -1.0),
			"a":_rng.randf()*TAU,"flap":_rng.randf_range(2.0,9.0),"beat":0.0})

## Its body: a slim faceted spindle, the head forward (-z).
func _bird_body() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := BIRD_SPAN/2.6
	var nose := Vector3(0.0,0.02,-0.55)*s
	var tail := Vector3(0.0,0.0,0.55)*s
	var ring := [Vector3(0.0,0.1,0.0),Vector3(0.11,0.0,0.0),Vector3(0.0,-0.09,0.0),Vector3(-0.11,0.0,0.0)]
	for k in range(4):
		var a: Vector3 = ring[k]*s
		var b: Vector3 = ring[(k+1)%4]*s
		for tri: Array in [[nose,a,b],[tail,b,a]]:
			for v: Vector3 in tri: st.add_vertex(v)
	# A fanned tail.
	for v: Vector3 in [tail,Vector3(-0.16,0.0,0.85)*s,Vector3(0.16,0.0,0.85)*s]: st.add_vertex(v)
	st.generate_normals()
	return st.commit()

## A wing (the right; mirrored for the left): broad, its tip fingered.
func _bird_wing() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := BIRD_SPAN/2.6
	var pts := [Vector3(0.05,0.0,-0.18),Vector3(0.7,0.04,-0.2),Vector3(1.3,0.0,-0.08),Vector3(1.3,0.0,0.06),Vector3(1.15,0.0,0.12),
		Vector3(1.2,0.0,0.2),Vector3(0.95,0.0,0.22),Vector3(0.6,0.0,0.28),Vector3(0.05,0.0,0.2)]
	for k in range(1,pts.size()-1):
		for v: Vector3 in [pts[0],pts[k],pts[k+1]]: st.add_vertex(v*s)
	st.generate_normals()
	return st.commit()

func _process(delta: float) -> void:
	if not visible or delta <= 0.0: return
	_t += delta
	_wreath_frame()
	_haze.rotation.y = -TAU*_t/(WREATH_TURN*2.3)
	for bird: Dictionary in _birds:
		bird.a = float(bird.a)+float(bird.w)*delta
		var a := float(bird.a)
		var r := float(bird.r)
		var c: Vector3 = bird.c
		var at := c+Vector3(cos(a)*r,3.0*sin(a*0.5+r),sin(a)*r)
		var way := Vector3(-sin(a),0.0,cos(a))*signf(float(bird.w))
		var node: Node3D = bird.node
		var bank := 0.4*signf(float(bird.w))
		node.transform = Transform3D(Basis.looking_at(way,Vector3.UP)*Basis(Vector3.BACK,-bank),at)
		# Gliding with wings raised; now and then a few slow beats.
		bird.flap = float(bird.flap)-delta
		if float(bird.flap) <= 0.0:
			bird.beat = 3.0
			bird.flap = _rng.randf_range(6.0,14.0)
		var lift := 0.16
		if float(bird.beat) > 0.0:
			bird.beat = float(bird.beat)-delta*2.2
			lift += 0.45*sin(float(bird.beat)*TAU)
		var wings: Array[Node3D] = bird.wings
		wings[0].rotation.z = -lift
		wings[1].rotation.z = lift

# --- The crashed plane ----------------------------------------------------------------

## A worn, broken sky folk plane crashed nose first into the scorched
## turf at the mountain's foot, under the ledge's front (it fell from
## there): the first flat ground found there.
func _build_wreck() -> void:
	var spot := Vector3.INF
	for k in range(300):
		var a := deg_to_rad(lerpf(40.0,100.0,fposmod(float(k)*0.618,1.0)))
		var r := Roost.LEDGE_R+lerpf(18.0,40.0,float(k%12)/11.0)
		var q := Roost.LEDGE_C+Vector2(cos(a),sin(a))*r
		var p := Roost.own(q)
		var y := Roost.ground(p.x,p.y)
		var h := (y-Roost.TOP)/Roost.SPAN
		if h > 4.0: continue
		if absf(Roost.ground(p.x+3.0,p.y)-y) > 0.5 or absf(Roost.ground(p.x,p.y+3.0)-y) > 0.5: continue
		spot = Vector3(p.x,y,p.y)+Roost.AT
		break
	if spot == Vector3.INF: return
	var plane := PlaneFigure.new()
	plane.name = "CrashedPlane"
	add_child(plane)
	var toward := (ledge-spot)*Vector3(1.0,0.0,1.0)
	var heading := atan2(-toward.x,-toward.z)+0.6
	var s := WorldScale.plane
	plane.park(Transform3D(Basis.from_euler(Vector3(deg_to_rad(50.0),heading,deg_to_rad(22.0)))*Basis.from_scale(Vector3.ONE*s),spot+Vector3(0.0,0.3*s,0.0)))
	plane.set_missing(["propeller","wheel","wingtip","windscreen"])
	plane.set_wear(1.0)
	plane.show_pilot(false)
	wreck = plane
