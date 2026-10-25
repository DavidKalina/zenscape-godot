extends RefCounted
## The city kit's breaks: the
## Olmec city's pieces where his power is the wanderer's tool, cards
## maker_felled and
## colossus_drum. Part of the `city` family; the
## family's main file (scripts/city_kit.gd) registers them:
##   if id in CityBreaks.PIECES: return CityBreaks.piece(id, seed, weathered)
##
##   maker_felled   a free-standing drum column of the makers on a stepped
##                  plinth (scripts/city_breaks/felled_column.gd): his bulk
##                  or his landing's shockwave fells it, toward the side away
##                  from the hit, along its fall axis (the piece's +X or -X):
##                  across a gap a bridge, on the ground a line of drums that
##                  burst and roll.
##   colossus_drum  a court of loose slabs on hollow drums (scripts/
##                  city_breaks/drum_floor.gd): his shockwave runs out across
##                  it as a stagger of hopping slabs; a slab under the
##                  wanderer throws him, a jump timed to it launches him.
##
## Each piece is a Node3D, its foot on y 0 round the origin, its front toward
## +Z, with "Mesh" and "Body" as RuinKit's (the static part: plinth, court
## frame), and its live parts under it. They join the group BREAKABLE; the
## Olmec reaches them through a breaker hub (scripts/breaks/breakables.gd)
## set as his `breaker`. Built in the Olmec's weathered basalt (shaders/
## olmec_stone.gdshader by scripts/kit_isle/greybox/giant_stone.gd), with
## smooth rounded drums (painterly, not faceted) and cut faces pale.
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")

const PIECES := ["maker_felled","colossus_drum"]
const NAMES := {"maker_felled":"Felled column","colossus_drum":"Drum floor"}
const FAMILY := "city"
const BREAKABLE := &"breakable"

## The column (card: 5.5 m across, 2.2 m drums, 6 to 8 of them, a great
## round capital and a square abacus, on a stepped plinth). The giant's
## numbers are the card's; the wanderer's (the plinth's rises, the reach from
## the plinth's top onto a felled drum's crown) are his, from his size.
const DRUM_R := 2.75
const DRUM_H := 2.2
const DRUMS := 7
## The drums' barrel (share of the radius at the middle) and the joint's
## chamfer (m: two make the recessed band).
const BULGE := 0.025
const CHAMFER := 0.2
## The capital: the echinus's height and its flare at the top (m), the
## abacus (side, thickness).
const ECHINUS := Vector2(1.2,0.7)
const ABACUS := Vector2(7.0,1.1)
## The plinth's three steps' half sides (m, out from the drum).
const PLINTH := [4.4,3.8,3.2]
## The ragged foot of the bottom drum left on the plinth when it goes (m).
const STUB := 0.35

## The Olmec's stride in the city (his `step` knob: the colonnade's
## OLMEC_STEP), for the plinth's rises.
const OLMEC_STEP := 2.4

## The plinth's rise per step: a jump and a grab for the wanderer (under his
## grab top), and two treads a stride for the Olmec (his planner reads the
## ground a cell, 1.5 m, at a time: two of the 0.6 m treads in one, under
## his step), so it is his stair onto the felled crown too.
static func plinth_rise() -> float:
	return minf(RuinKit.GRAB_TOP*WorldScale.wanderer*0.7,OLMEC_STEP*0.48)

static func plinth_top() -> float:
	return plinth_rise()*PLINTH.size()

static func capital_h() -> float:
	return ECHINUS.x+ABACUS.y

static func column_h() -> float:
	return plinth_top()+DRUMS*DRUM_H+capital_h()

## Felled: where its base end lies (out from the middle along the fall, past
## the plinth), the drums' length lying, and the most a gap under it may be
## (a bearing BEARING m on either rim).
const BED_GAP := 0.15
const BEARING := 1.3
static func felled_from() -> float:
	return float(PLINTH[0])+BED_GAP

static func felled_length() -> float:
	return DRUMS*DRUM_H

static func span_most() -> float:
	return felled_length()-2.0*BEARING

## The drum floor (card: 4 x 4 x 1 slabs, a hand-wide seam).
const SLAB := 4.0
const SLAB_THICK := 1.0
const SEAM := 0.08

## The numbers against the wanderer's and the Olmec's (for the yard's
## printout and the handoff): each [name, value, against, ok].
static func fit(body_jump_gap: float, body_step: float) -> Array:
	var grab := RuinKit.GRAB_TOP*WorldScale.wanderer
	var chain := RuinKit.CHAIN_TOP*WorldScale.wanderer
	var crown := DRUM_R*2.0
	var stun := 4.0*1.5*WorldScale.wanderer
	return [
		["plinth rise (m) under his grab top",plinth_rise(),grab,plinth_rise() < grab],
		["plinth top to a felled crown (m), his grab",crown-plinth_top()-STUB,grab,crown-plinth_top()-STUB < grab],
		["felled crown (m) under the fall stun",crown,stun,crown < stun],
		["felled span (m) past the Olmec's jump gap",span_most(),body_jump_gap,span_most() > body_jump_gap],
		["plinth rise (m) a stride for the Olmec",plinth_rise(),body_step,plinth_rise() <= body_step],
		["drum floor hop (m) nothing to climb",0.7,chain,0.7 < chain],
	]

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"maker_felled":
			var c: Node3D = load("res://scripts/city_breaks/felled_column.gd").new()
			c.build(seed_value,weathered)
			return c
		"colossus_drum":
			var d: Node3D = load("res://scripts/city_breaks/drum_floor.gd").new()
			d.build(seed_value,weathered)
			return d
	return null

# --- The stone ---------------------------------------------------------------------------

## The makers' glyphs: cut, not lit (the city's light is torches and the
## Olmec's eyes): a faint warmth in the groove.
const RUNE_ENERGY := 0.05
const RUNE_GLOW := Color(0.9,0.62,0.36)
static var _runes: ShaderMaterial = null

## `m` as a mesh in the giant's stone and the makers' cut glyphs.
static func mesh_of(m: GiantStone.Mesher) -> ArrayMesh:
	GiantStone.warm()
	if _runes == null:
		_runes = ShaderMaterial.new()
		_runes.shader = HeadLook.STONE_SHADER
		_runes.set_shader_parameter("roughness_value",0.95)
		_runes.set_shader_parameter("runes",true)
		_runes.set_shader_parameter("rune_cut",0.9)
		_runes.set_shader_parameter("energy",RUNE_ENERGY)
		_runes.set_shader_parameter("glow",RUNE_GLOW)
		_runes.set_shader_parameter("pulse_amp",0.0)
		_runes.set_shader_parameter("halo",0.0)
		Style.dress(_runes)
	return m.mesh(CityStone.wear("break"),_runes)

## A mesher in the giant's stone with smooth round forms (the drums, the
## echinus, the stub): GiantStone's Mesher, its tone, occlusion, moss and
## grain, and its runes.
class Mesher extends GiantStone.Mesher:
	## The moss on tops, a share of the giant's (a walked floor, a drum
	## standing in the open: less).
	var moss := 0.35

	func _init(colour := GiantStone.stone_colour()) -> void:
		super(colour)

	func _dress(p: Vector3, normal: Vector3) -> Array:
		var d: Array = super(p,normal)
		if moss < 1.0 and normal.y > GiantStone.MOSS_UP:
			var c: Color = d[0]
			var bare := Style.shade(stone,_centre,p,normal,1.0)
			var occ := c.a
			bare = bare*lerpf(GiantStone.AO_FLOOR,1.0,occ)*_tone
			bare.a = occ
			d[0] = bare.lerp(c,moss)
		return d

	func _vert(p: Vector3, nrm: Vector3) -> void:
		var d := _dress(p,nrm)
		v.append(p)
		n.append(nrm)
		col.append(d[0])
		uv.append(d[1])
		uv2.append(d[2])

	## A smooth lathe about `place`'s y: `profile` [Vector2(radius, y)] bottom
	## to top, `segments` round; normals averaged along the profile (a round
	## rim, not a facet); its ends capped flat if `caps` (tone `cap_tone`:
	## a cut face is pale), the top cap's rim jittered `ragged` m.
	func lathe(place: Transform3D, profile: Array, segments: int, caps := true, cap_tone := 1.0, ragged := 0.0, seed_value := 0) -> void:
		_centre = place.origin
		var lo: Vector2 = profile[0]
		_foot = (place*Vector3(0.0,lo.y,0.0)).y
		var norms: Array[Vector2] = []
		for i in profile.size():
			var acc := Vector2.ZERO
			for j: int in [i-1,i]:
				if j < 0 or j+1 >= profile.size(): continue
				var a: Vector2 = profile[j]
				var b: Vector2 = profile[j+1]
				var d := b-a
				acc += Vector2(d.y,-d.x).normalized()
			norms.append(acc.normalized() if acc.length() > 0.0 else Vector2(1.0,0.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var jag: Array[float] = []
		for k in segments: jag.append(rng.randf_range(-ragged,ragged))
		var ring := func(i: int, k: int) -> Array:
			var a := TAU*float(k%segments)/segments
			var pr: Vector2 = profile[i]
			var y := pr.y
			if ragged > 0.0 and i == profile.size()-1: y += jag[k%segments]
			var dir := Vector3(cos(a),0.0,sin(a))
			var nr: Vector2 = norms[i]
			return [place*(dir*pr.x+Vector3.UP*y),(place.basis*(dir*nr.x+Vector3.UP*nr.y)).normalized()]
		_tone = 1.0
		for k in segments:
			for i in profile.size()-1:
				var a: Array = ring.call(i,k)
				var b: Array = ring.call(i,k+1)
				var c: Array = ring.call(i+1,k+1)
				var d: Array = ring.call(i+1,k)
				for t: Array in [[a,b,d],[b,c,d]]:
					for q: Array in t: _vert(q[0],q[1])
		if not caps: return
		_tone = cap_tone
		var up := (place.basis*Vector3.UP).normalized()
		var top_i := profile.size()-1
		var top_c := place*Vector3(0.0,(profile[top_i] as Vector2).y+(ragged*0.6 if ragged > 0.0 else 0.0),0.0)
		var bot_c := place*Vector3(0.0,lo.y,0.0)
		for k in segments:
			var b0: Array = ring.call(0,k)
			var b1: Array = ring.call(0,k+1)
			for q: Vector3 in [bot_c,b1[0],b0[0]]: _vert(q,-up)
			var t0: Array = ring.call(top_i,k)
			var t1: Array = ring.call(top_i,k+1)
			if ragged > 0.0:
				var nrm: Vector3 = ((t0[0] as Vector3)-top_c).cross((t1[0] as Vector3)-top_c).normalized()
				if nrm.dot(up) < 0.0: nrm = -nrm
				nrm = (nrm+up).normalized()
				for q: Vector3 in [top_c,t0[0],t1[0]]: _vert(q,nrm)
			else:
				for q: Vector3 in [top_c,t0[0],t1[0]]: _vert(q,up)
		_tone = 1.0

	## A runes band round a lathe (radius `r` at its height), `count` facets
	## of glyphs from `y0`, lifted off the round so its chord stands clear.
	func rune_ring(place: Transform3D, r: float, y0: float, count: int, seed_value: float) -> void:
		var lift := r*(1.0-cos(PI/count))+0.03
		for k in count:
			var a0 := TAU*k/count
			var a1 := TAU*(k+1)/count
			var mid := (a0+a1)*0.5
			var out := Vector3(cos(mid),0.0,sin(mid))
			var p0 := Vector3(cos(a1),0.0,sin(a1))*r+out*lift+Vector3.UP*y0
			var p1 := Vector3(cos(a0),0.0,sin(a0))*r+out*lift+Vector3.UP*y0
			runes(place*p0,place*p1,(place.basis*Vector3.UP).normalized(),(place.basis*out).normalized(),seed_value+k*0.37)

## A drum's profile (radius, y) round its middle: chamfered rims (the joint's
## recessed band, two drums stacked), a little barrel bulge.
static func drum_profile(r: float, tall: float) -> Array:
	var h := tall*0.5
	var c := CHAMFER
	var out: Array = [Vector2(r-c,-h),Vector2(r-c*0.3,-h+c*0.45),Vector2(r,-h+c)]
	var rings := 5
	for j in range(1,rings):
		var y := lerpf(-h+c,h-c,float(j)/rings)
		var t := y/(h-c)
		out.append(Vector2(r*(1.0+BULGE*(1.0-t*t)),y))
	out.append_array([Vector2(r,h-c),Vector2(r-c*0.3,h-c*0.45),Vector2(r-c,h)])
	return out

## One drum's mesh round its middle, its axis y: weathered barrel, pale
## joint faces, a ring of glyphs over its lower joint.
static func drum_mesh(seed_value: int) -> ArrayMesh:
	var m := Mesher.new()
	m.lathe(Transform3D.IDENTITY,drum_profile(DRUM_R,DRUM_H),32,true,1.35)
	m.rune_ring(Transform3D.IDENTITY,DRUM_R*(1.0+BULGE*0.4),-DRUM_H*0.5+CHAMFER+0.05,24,float(seed_value%97))
	return mesh_of(m)

## The capital round its foot: the echinus flaring up to the abacus, the
## abacus square over it with its face frieze (glyphs), its foot pale.
static func capital_mesh(seed_value: int) -> ArrayMesh:
	var m := Mesher.new()
	var prof: Array = []
	for i in 7:
		var t := float(i)/6.0
		prof.append(Vector2(DRUM_R-CHAMFER*(1.0-t)*(1.0 if i == 0 else 0.0)+ECHINUS.y*(1.0-pow(1.0-t,2.0)),ECHINUS.x*t))
	m.lathe(Transform3D.IDENTITY,prof,32,true,1.35)
	var half := ABACUS.x*0.5
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,ECHINUS.x+ABACUS.y*0.5,0.0)),Vector3(ABACUS.x,ABACUS.y,ABACUS.x),0.22)
	var y := ECHINUS.x+0.15
	for s in 4:
		var b := Basis(Vector3.UP,s*PI*0.5)
		var out := b*Vector3(0.0,0.0,1.0)
		var along := b*Vector3(1.0,0.0,0.0)
		var face := out*(half+0.02)+Vector3.UP*y
		m.runes(face-along*(half-0.4),face+along*(half-0.4),Vector3.UP,out,float(seed_value+s))
	return mesh_of(m)

## The plinth (three chamfered steps) as stone, and the stub's ragged foot
## if `stub`.
static func plinth_mesh(with_stub: bool, seed_value: int) -> ArrayMesh:
	var m := Mesher.new()
	var rise := plinth_rise()
	for i in PLINTH.size():
		var half: float = PLINTH[i]
		m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,rise*(i+0.5),0.0)),Vector3(half*2.0,rise,half*2.0),0.16,0.0)
	if with_stub:
		var top := plinth_top()
		m.lathe(Transform3D(Basis.IDENTITY,Vector3(0.0,top,0.0)),[Vector2(DRUM_R-CHAMFER,0.0),Vector2(DRUM_R-CHAMFER*0.3,CHAMFER*0.45),Vector2(DRUM_R,STUB)],32,true,1.45,0.14,seed_value)
	return mesh_of(m)
