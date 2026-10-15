extends Node3D
## The Weeper's stone (scripts/enemies/weeper.gd, docs/design/roguelike/
## weeper-round1.md): a robed mourner carved from one block of the Olmec's
## weathered basalt (shaders/olmec_stone.gdshader, the material scripts/
## enemies/inhaler_head_look.gd `stone_material` makes), so it reads as the
## same old stone as the heads. No face to speak of: a worn oval in a deep
## hood. Menace from weight and restraint (AGENTS.md): no glow, no spikes.
##
## Built `height` m tall, its hem's foot at the origin, its front toward -Z.
## Parts, each a carved mass (`_lathe`: a turned profile with drapery folds
## cut round it, the folds' valleys darkened as crevices):
##   the robe (hem to shoulders), the hood and its face (the `head` pivot at
##   the neck), and each arm a sleeve from the shoulder (`arm_l`, `arm_r`)
##   with a bare forearm and a long hand from the elbow (`elbow_l`, `elbow_r`).
## It is never seen moving, so it has no clips: `pose(name, rng, mirror)`
## sets a key pose at once (POSES), a little varied each time, so every
## snap shows a new one. The poses climb from mourning (face in its hands)
## to reaching for him as it comes nearer.
##
## The dust (`dust()`): a little grit falling off its shoulders and arms and
## a puff at its hem where it now stands, the tell that it moved.
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")

## Proportions, shares of `height`: shoulders' height and half width, the
## neck, the upper arm and forearm, the hand.
const SHOULDER := 0.75
const SHOULDER_HALF := 0.165
const NECK := 0.8
const UPPER := 0.29
const FORE := 0.21
const HAND := 0.09
## The robe's turned profile: [height, radius] (shares of `height`), hem to
## neck; its depth front to back a share of its width (ROBE_DEEP).
const ROBE := [[0.0,0.215],[0.03,0.222],[0.16,0.2],[0.36,0.165],[0.52,0.145],[0.64,0.15],
	[0.72,0.165],[0.77,0.14],[0.81,0.08],[0.83,0.0]]
const ROBE_DEEP := 0.74
## Drapery: folds round, their depth (share of the radius) at the hem and
## at the shoulders, how they twist up the body (rad over the height).
const FOLDS := 7
const FOLD_HEM := 0.16
const FOLD_TOP := 0.035
const FOLD_TWIST := 0.5
## The hood round the head (from the neck pivot): its profile, set back
## HOOD_BACK, and the worn face in it.
const HOOD := [[-0.07,0.12],[-0.03,0.11],[0.02,0.112],[0.08,0.118],[0.14,0.102],[0.19,0.055],[0.212,0.0]]
## The mantle over the shoulders, the arms coming out under it: [height, radius].
const MANTLE := [[0.58,0.2],[0.63,0.212],[0.7,0.205],[0.755,0.17],[0.79,0.11],[0.81,0.0]]
const HOOD_BACK := -0.012
const FACE := Vector3(0.06,0.08,0.05)
const FACE_AT := Vector3(0.0,0.07,-0.052)
## The hood's front hollowed this share of its radius round the face.
const HOLLOW := 0.42
## The sleeve, down from the shoulder: [down, radius].
const SLEEVE := [[-0.02,0.06],[0.1,0.064],[0.22,0.078],[0.29,0.094],[0.3,0.0]]
## Radial segments: robe, hood, sleeve.
const SEGS := Vector3i(22,16,12)
## The stone: a shade lighter and cooler than the Olmec's (a mourner of
## the same quarry, stood out longer in the rain), the crevices' floor.
const STONE := Color("5d5f63")
const AO_FLOOR := 0.5
## Each snap's variation (rad) round the pose, per joint.
const VARY := 0.1

## Key poses (degrees): body lean (+ back), head pitch (+ up) and roll,
## each shoulder [pitch (+ forward), splay (+ out)], each elbow (+ bent
## forward). Left and right as the figure's own; `mirror` swaps them.
const POSES := {
	# Far: weeping, its face in its hands.
	"mourn":{"lean":-10.0,"head":-42.0,"roll":0.0,"sh_l":[56.0,-24.0],"sh_r":[54.0,-22.0],"el_l":146.0,"el_r":144.0},
	# The hands coming down from the face, the head lifting.
	"lift":{"lean":-6.0,"head":-22.0,"roll":7.0,"sh_l":[26.0,-10.0],"sh_r":[44.0,-16.0],"el_l":84.0,"el_r":128.0},
	# It has seen him: head up and turned, one hand out low.
	"turn":{"lean":-9.0,"head":-4.0,"roll":9.0,"sh_l":[46.0,4.0],"sh_r":[8.0,4.0],"el_l":18.0,"el_r":34.0},
	# Near: both arms out for him, leaning in.
	"reach":{"lean":-14.0,"head":4.0,"roll":-5.0,"sh_l":[94.0,4.0],"sh_r":[84.0,0.0],"el_l":10.0,"el_r":20.0},
	# The blow: lunged, arms high and through.
	"seize":{"lean":-24.0,"head":-4.0,"roll":0.0,"sh_l":[122.0,8.0],"sh_r":[114.0,4.0],"el_l":8.0,"el_r":12.0},
}

var height := 2.4
var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var pose_name := ""
var _grit: CPUParticles3D
var _puff: CPUParticles3D

## Carved `h` m tall from the stone of `seed_value`.
func build(h: float, seed_value := 3) -> void:
	height = h
	var mat: Material = HeadLook.stone_material()
	var stone := Style.stone_of(seed_value).lerp(STONE,0.5) if Style.ruled() else STONE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"weeper"])
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	_mesh(body,_lathe(ROBE,SEGS.x,ROBE_DEEP,FOLDS,Vector2(FOLD_HEM,FOLD_TOP),rng.randf()*TAU,false),stone,Vector3.ZERO,mat,"Robe")
	_mesh(body,_lathe(MANTLE,SEGS.x,0.8,9,Vector2(0.12,0.05),rng.randf()*TAU,true),stone,Vector3.ZERO,mat,"Mantle")
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0,NECK*h,0.0)
	body.add_child(head)
	_mesh(head,_lathe(HOOD,SEGS.y,0.98,5,Vector2(0.05,0.02),rng.randf()*TAU,false,HOLLOW),stone,Vector3(0.0,0.0,HOOD_BACK*h),mat,"Hood")
	var face := SphereMesh.new()
	face.radius = 1.0
	face.height = 2.0
	face.radial_segments = 12
	face.rings = 8
	_mesh(head,_scaled(face,FACE*h),stone*0.92,FACE_AT*h,mat,"Face",0.62)
	arm_l = _arm(-1.0,stone,mat)
	arm_r = _arm(1.0,stone,mat)
	elbow_l = arm_l.get_node("Elbow")
	elbow_r = arm_r.get_node("Elbow")
	_dust_build()
	pose("mourn")

func _arm(side: float, stone: Color, mat: Material) -> Node3D:
	var h := height
	var shoulder := Node3D.new()
	shoulder.name = "ArmL" if side < 0.0 else "ArmR"
	shoulder.position = Vector3(side*SHOULDER_HALF*h,SHOULDER*h,0.0)
	body.add_child(shoulder)
	var sleeve := []
	for p: Array in SLEEVE: sleeve.append([-float(p[0]),p[1]])
	sleeve.reverse()
	_mesh(shoulder,_lathe(sleeve,SEGS.z,0.9,4,Vector2(0.12,0.04),side,true),stone,Vector3.ZERO,mat,"Sleeve")
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0.0,-UPPER*h,0.0)
	shoulder.add_child(elbow)
	var fore := CapsuleMesh.new()
	fore.radius = 0.04*h
	fore.height = FORE*h
	fore.radial_segments = 8
	fore.rings = 2
	_mesh(elbow,fore,stone,Vector3(0.0,-FORE*h*0.5,0.0),mat,"Forearm",0.85)
	# The hand: long and flat, fingers together, palm in.
	var hand := SphereMesh.new()
	hand.radius = 1.0
	hand.height = 2.0
	hand.radial_segments = 8
	hand.rings = 6
	_mesh(elbow,_scaled(hand,Vector3(0.026,HAND*0.5,0.05)*h),stone,Vector3(0.0,-(FORE+HAND*0.4)*h,-0.004*h),mat,"Hand",0.8)
	return shoulder

## Sets key pose `name` (POSES) at once, varied by `rng` (VARY a joint),
## left and right swapped if `mirror`.
func pose(name: String, rng: RandomNumberGenerator = null, mirror := false) -> void:
	var p: Dictionary = POSES.get(name,POSES.mourn)
	pose_name = name
	var v := func() -> float: return rng.randf_range(-VARY,VARY) if rng != null else 0.0
	var l := "r" if mirror else "l"
	var r := "l" if mirror else "r"
	body.rotation = Vector3(deg_to_rad(float(p.lean))+float(v.call())*0.4,0.0,float(v.call())*0.3)
	head.rotation = Vector3(deg_to_rad(float(p.head))+float(v.call()),float(v.call())*2.0,deg_to_rad(float(p.roll))*(-1.0 if mirror else 1.0)+float(v.call()))
	for side: Array in [[arm_l,elbow_l,"sh_"+l,"el_"+l,-1.0],[arm_r,elbow_r,"sh_"+r,"el_"+r,1.0]]:
		var sh: Array = p[side[2]]
		(side[0] as Node3D).rotation = Vector3(deg_to_rad(float(sh[0]))+float(v.call()),0.0,deg_to_rad(float(sh[1]))*float(side[4])+float(v.call())*0.5)
		(side[1] as Node3D).rotation = Vector3(deg_to_rad(float(p[side[3]]))+float(v.call()),0.0,0.0)

## Grit off its shoulders and arms, a puff at its hem.
func dust(strength := 1.0) -> void:
	_grit.amount = maxi(4,int(18.0*strength))
	_grit.restart()
	_puff.restart()

func _dust_build() -> void:
	var grain := QuadMesh.new()
	grain.size = Vector2.ONE*0.022*height
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.42,0.4,0.37,0.55)
	grain.material = mat
	_grit = CPUParticles3D.new()
	_grit.name = "Grit"
	_grit.mesh = grain
	_grit.one_shot = true
	_grit.emitting = false
	_grit.amount = 18
	_grit.lifetime = 1.3
	_grit.explosiveness = 0.75
	_grit.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_grit.emission_box_extents = Vector3(SHOULDER_HALF*1.3,0.06,0.1)*height
	_grit.position = Vector3(0.0,SHOULDER*height,0.0)
	_grit.direction = Vector3.DOWN
	_grit.spread = 12.0
	_grit.initial_velocity_min = 0.1
	_grit.initial_velocity_max = 0.4
	_grit.gravity = Vector3(0.0,-3.5,0.0)
	_grit.scale_amount_min = 0.5
	_grit.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0.85))
	fade.set_color(1,Color(1,1,1,0.0))
	_grit.color_ramp = fade
	_grit.local_coords = false
	add_child(_grit)
	_puff = CPUParticles3D.new()
	_puff.name = "Puff"
	var cloud := QuadMesh.new()
	cloud.size = Vector2.ONE*0.16*height
	var soft := mat.duplicate() as StandardMaterial3D
	soft.albedo_color = Color(0.58,0.55,0.5,0.22)
	cloud.material = soft
	_puff.mesh = cloud
	_puff.one_shot = true
	_puff.emitting = false
	_puff.amount = 8
	_puff.lifetime = 1.1
	_puff.explosiveness = 0.9
	_puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_puff.emission_ring_radius = 0.22*height
	_puff.emission_ring_inner_radius = 0.16*height
	_puff.emission_ring_height = 0.01
	_puff.emission_ring_axis = Vector3.UP
	_puff.position = Vector3(0.0,0.04,0.0)
	_puff.direction = Vector3.UP
	_puff.spread = 70.0
	_puff.initial_velocity_min = 0.15
	_puff.initial_velocity_max = 0.35
	_puff.gravity = Vector3(0.0,-0.2,0.0)
	_puff.damping_min = 0.4
	_puff.damping_max = 0.6
	_puff.scale_amount_min = 0.7
	_puff.scale_amount_max = 1.4
	_puff.color_ramp = fade
	_puff.local_coords = false
	add_child(_puff)

# --- Carving ------------------------------------------------------------------------

## A turned mass: `profile` [[y, r]] (shares of `height`, bottom to top),
## `segs` round, its depth front to back `deep` of its width, `folds`
## drapery folds cut round it (depth `fold.x` at the bottom to `fold.y` at
## the top, twisting FOLD_TWIST up it from `phase`); `open_top` leaves the
## top open (a sleeve's mouth is its bottom). The folds' valleys are
## crevices (COLOR's red, the occlusion `_dressed` reads).
func _lathe(profile: Array, segs: int, deep: float, folds: int, fold: Vector2, phase: float, sleeve: bool, hollow := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := height
	var y0: float = profile[0][0]
	var y1: float = profile[profile.size()-1][0]
	var rows: Array = []
	for i in range(profile.size()):
		var y: float = profile[i][0]
		var r: float = profile[i][1]
		var k := (y-y0)/maxf(y1-y0,0.001)
		var depth := lerpf(fold.x,fold.y,k)
		# A sleeve's folds deepest at its mouth (its bottom, here its start).
		var row: Array = []
		for j in range(segs+1):
			var a := TAU*float(j)/segs
			var f := 0.5+0.5*cos(float(folds)*a+phase+k*FOLD_TWIST)
			# Folds hang mostly at the sides and back; the front falls smoother.
			var front := 0.6+0.4*(1.0-maxf(0.0,-cos(a)))
			var rr := r*(1.0-depth*front*(1.0-f))
			# A hood's face hollow: the front pulled in round mid-height.
			var dent := 0.0
			if hollow > 0.0:
				dent = pow(maxf(0.0,cos(a)),2.0)*smoothstep(0.1,0.35,k)*(1.0-smoothstep(0.6,0.85,k))
				rr *= 1.0-hollow*dent
			var p := Vector3(sin(a)*rr,y*h,-cos(a)*rr*deep)*Vector3(h,1.0,h)
			var occ := lerpf(1.0,0.55+0.45*f,clampf(depth*front*5.0,0.0,1.0))*(1.0-0.75*dent)
			# The hem, the hood's rim and the sleeve's mouth in shadow.
			if i == 0 and not sleeve: occ *= 0.6
			if sleeve and i <= 1: occ *= 0.7
			row.append([p,occ])
		rows.append(row)
	for i in range(rows.size()-1):
		for j in range(segs):
			var q: Array = [rows[i][j],rows[i][j+1],rows[i+1][j+1],rows[i+1][j]]
			for t: Array in [[0,1,2],[0,2,3]]:
				for idx: int in t:
					st.set_color(Color(q[idx][1],q[idx][1],q[idx][1],1.0))
					st.add_vertex(q[idx][0])
	# A floor under the hem (it stands on a slab of its own robe).
	if not sleeve:
		var c := Vector3(0.0,y0*h,0.0)
		for j in range(segs):
			for p: Vector3 in [c,rows[0][j+1][0],rows[0][j][0]]:
				st.set_color(Color(0.4,0.4,0.4,1.0))
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()

## `mesh` (a unit primitive) scaled by `s`, its normals kept true.
func _scaled(mesh: PrimitiveMesh, s: Vector3) -> ArrayMesh:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(verts.size()):
		verts[i] = verts[i]*s
		normals[i] = (normals[i]/s).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return out

## `mesh` dressed in the stone (as HeadLook `_dressed` dresses the head:
## the kit's tone by facing, times the crevices' occlusion, alpha the
## occlusion; UV and UV2.x where the vertex rests, for the grain), at
## `offset` under `parent`. One block: no masonry cells across it.
func _mesh(parent: Node3D, mesh: Mesh, stone: Color, offset: Vector3, mat: Material, part: String, occ_all := 1.0) -> MeshInstance3D:
	var out := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ao: Variant = arrays[Mesh.ARRAY_COLOR]
		var colours := PackedColorArray()
		colours.resize(verts.size())
		var rest_a := PackedVector2Array()
		var rest_b := PackedVector2Array()
		rest_a.resize(verts.size())
		rest_b.resize(verts.size())
		# Where the part rests in the figure (its pivots' offsets summed).
		var root := offset
		var up: Node = parent
		while up != null and up != self:
			root += (up as Node3D).position
			up = up.get_parent()
		for i in range(verts.size()):
			var p := verts[i]+root
			var occ := occ_all
			if ao is PackedColorArray and (ao as PackedColorArray).size() == verts.size(): occ *= (ao as PackedColorArray)[i].r
			var c := Style.shade(stone,Vector3.ZERO,p,normals[i],1.0)*lerpf(AO_FLOOR,1.0,occ)
			c.a = occ
			colours[i] = c
			rest_a[i] = Vector2(p.x,p.y)
			rest_b[i] = Vector2(p.z,0.0)
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = rest_a
		arrays[Mesh.ARRAY_TEX_UV2] = rest_b
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var m := MeshInstance3D.new()
	m.name = part
	m.mesh = out
	m.position = offset
	m.material_override = mat
	parent.add_child(m)
	return m
