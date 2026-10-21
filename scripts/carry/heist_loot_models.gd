extends RefCounted
## The heist level's loot figures (studies/heist_level.gd `greed_loot_model`).
## `build(kind)` gives {node (foot at its origin, facing -z), height (m),
## grip (the hands' half span across it, m), radius (a ball round it on the
## ground: reach and the brood's haul reach, m)}, as studies/bag_study.gd
## `loot_model`. Drawn at their real size beside the wanderer (about 1 m),
## the heavier the bigger:
##   gem 0.5 kg    a sapphire cluster on a little gold stand, 0.42 m
##   chalice 1.5   a gold cup set with rubies, 0.46 m
##   coins 2       an open chest heaped over with gold coins, a few spilt, 0.5 m
##   idol 3        a seated jade figure under a gold crown, 0.64 m
##   bar 4         a stack of six gold ingots, 0.33 m, broad
##   urn 6         a painted amphora, 0.72 m
##   egg 8         the dragon egg, held in a three-clawed gold cup, 0.82 m
## Each is one ArrayMesh from lathed profiles and primitives, a few
## materials, and crevice grime baked into its vertex colours (darker
## underneath, low down and where parts meet).

static func build(kind: String) -> Dictionary:
	match kind:
		"coins": return _coins()
		"chalice": return _chalice()
		"gem": return _gem()
		"idol": return _idol()
		"egg": return _egg()
		"urn": return _urn()
		"bar": return _bar()
	return _gem()

const GOLD := Color(1.0,0.76,0.33)
const DARK_GOLD := Color(0.6,0.4,0.15)

# --- The coins ------------------------------------------------------------------------

## A small iron-banded chest, its lid thrown back, gold coins heaped over
## its rim and a few spilt on the ground in front. 0.5 m tall at the lid.
static func _coins() -> Dictionary:
	var wood := _Geo.new()
	var iron := _Geo.new()
	var gold := _Geo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var w := 0.5
	var h := 0.24
	var d := 0.34
	# The chest on four iron feet.
	wood.box(Vector3(w,h,d),Vector3(0.0,h*0.5+0.02,0.0),Vector3.ZERO,0.85)
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			iron.box(Vector3(0.06,0.03,0.06),Vector3(sx*(w*0.5-0.03),0.015,sz*(d*0.5-0.03)),Vector3.ZERO,0.6)
	# Iron bands round it and its rim.
	for bx: float in [-0.16,0.16]:
		iron.box(Vector3(0.035,h+0.01,d+0.012),Vector3(bx,h*0.5+0.02,0.0))
	iron.box(Vector3(w+0.012,0.03,d+0.012),Vector3(0.0,h+0.005,0.0))
	# A lock plate on the front.
	iron.box(Vector3(0.07,0.08,0.015),Vector3(0.0,h-0.03,-d*0.5-0.008))
	gold.box(Vector3(0.02,0.03,0.01),Vector3(0.0,h-0.04,-d*0.5-0.018))
	# The lid, thrown back on its hinge at the back top edge: a half barrel.
	var hinge := Vector3(0.0,h+0.02,d*0.5)
	var lid := Transform3D(Basis(Vector3.RIGHT,deg_to_rad(108.0)),hinge)
	wood.half_barrel(w,d*0.5,lid*Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,-d*0.5)),0.95)
	for bx: float in [-0.16,0.16]:
		iron.half_barrel(0.04,d*0.5+0.008,lid*Transform3D(Basis.IDENTITY,Vector3(bx,0.0,-d*0.5)),0.8)
	# The heap: a gold mound over the rim, coins strewn on it.
	var top := h+0.02
	gold.ball(1.0,Vector3(0.0,top,0.0),Vector3(w*0.5,0.13,d*0.5),12,Basis.IDENTITY,0.8)
	for i: int in 40:
		var u := rng.randf_range(-1.0,1.0)
		var v := rng.randf_range(-1.0,1.0)
		if u*u+v*v > 1.0: continue
		var y := top+0.13*sqrt(maxf(0.0,1.0-u*u-v*v))
		var at := Vector3(u*w*0.46,y,v*d*0.46)
		var tilt := Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-0.6,0.6)-u*0.5)
		_coin(gold,at,tilt,rng.randf_range(0.85,1.0))
	# Spilt over the front lip and onto the ground.
	var spill := [Vector3(-0.08,0.0,-0.25),Vector3(0.06,0.0,-0.29),Vector3(0.15,0.0,-0.22),Vector3(-0.17,0.0,-0.31),Vector3(0.0,0.0,-0.36),Vector3(0.24,0.0,-0.33)]
	for p: Vector3 in spill:
		_coin(gold,p+Vector3(0.0,0.006,0.0),Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-0.1,0.1)),0.75)
	# Two leant on the front, one on its edge.
	_coin(gold,Vector3(-0.1,0.05,-d*0.5-0.03),Basis(Vector3.RIGHT,-1.2),0.75)
	_coin(gold,Vector3(0.12,0.04,-d*0.5-0.02),Basis(Vector3.UP,0.3)*Basis(Vector3.RIGHT,-1.35),0.75)
	_coin(gold,Vector3(-0.05,0.042,-0.3),Basis(Vector3.FORWARD,PI*0.5),0.8)
	var mesh := ArrayMesh.new()
	wood.commit(mesh,_wood())
	iron.commit(mesh,_mat(Color(0.3,0.29,0.28),0.5,0.7))
	gold.commit(mesh,_gold(0.3))
	return _made(mesh,0.5,0.26,0.32)

## A coin, its face up `turn`'s y.
static func _coin(g: _Geo, at: Vector3, turn: Basis, shade: float) -> void:
	var r := 0.042
	var t := 0.011
	g.lathe([Vector3(0.0,-t*0.5,0.7),Vector3(r,-t*0.5,0.8),Vector3(r,-t*0.5,0.8),Vector3(r,t*0.5,1.0),Vector3(r,t*0.5,1.0),Vector3(r*0.7,t*0.5,0.85),Vector3(r*0.7,t*0.5,0.85),Vector3(0.0,t*0.5,1.0)],8,Transform3D(turn,at),true,shade)

# --- The chalice ------------------------------------------------------------------------

## A gold chalice: a deep cup on a knotted stem and a wide stepped foot, a
## raised band round the cup set with red gems. 0.46 m tall.
static func _chalice() -> Dictionary:
	var gold := _Geo.new()
	var gem := _Geo.new()
	gold.lathe([
		Vector3(0.0,0.0,0.5),Vector3(0.13,0.0,0.6),Vector3(0.13,0.0,0.6),Vector3(0.13,0.018,0.8),Vector3(0.13,0.018,0.8),
		Vector3(0.1,0.03,0.9),Vector3(0.06,0.05,0.95),Vector3(0.032,0.09,0.9),Vector3(0.024,0.14,0.85),
		Vector3(0.05,0.165,1.0),Vector3(0.024,0.19,0.8),Vector3(0.026,0.22,0.8),
		Vector3(0.06,0.245,0.85),Vector3(0.11,0.28,0.95),Vector3(0.145,0.34,1.0),Vector3(0.155,0.4,1.0),
		Vector3(0.165,0.455,1.0),Vector3(0.165,0.455,1.0),Vector3(0.152,0.455,0.8),Vector3(0.152,0.455,0.8),
		Vector3(0.14,0.4,0.45),Vector3(0.12,0.33,0.3),Vector3(0.0,0.29,0.2)],18,Transform3D.IDENTITY,false)
	# The band round the cup.
	gold.lathe([Vector3(0.143,0.33,0.6),Vector3(0.162,0.335,0.9),Vector3(0.164,0.36,1.0),Vector3(0.155,0.37,0.7)],18,Transform3D.IDENTITY,false)
	for i: int in 6:
		var a := TAU*(float(i)+0.5)/6.0
		var out := Vector3(sin(a),0.0,-cos(a))
		var at := out*0.165+Vector3(0.0,0.35,0.0)
		# The lens's face (its y) turned out from the cup.
		var b := Basis(out.cross(Vector3.UP).normalized(),out,Vector3.UP)
		gem.lens(0.026,0.016,6,Transform3D(b,at))
	var mesh := ArrayMesh.new()
	gold.commit(mesh,_gold(0.25))
	gem.commit(mesh,_mat(Color(0.9,0.08,0.12),0.1,0.0,Color(0.9,0.1,0.1)*0.5))
	return _made(mesh,0.46,0.16,0.17)

# --- The gem --------------------------------------------------------------------------

## A sapphire cluster: one big six-sided crystal and two smaller ones, out
## of a rough dark rock set in a little gold stand. 0.42 m tall.
static func _gem() -> Dictionary:
	var stand := _Geo.new()
	var rock := _Geo.new()
	var gem := _Geo.new()
	stand.lathe([Vector3(0.0,0.0,0.5),Vector3(0.12,0.0,0.55),Vector3(0.12,0.0,0.55),Vector3(0.12,0.025,0.8),Vector3(0.12,0.025,0.8),Vector3(0.08,0.04,0.9),Vector3(0.06,0.07,0.85),Vector3(0.09,0.1,1.0),Vector3(0.09,0.1,1.0),Vector3(0.0,0.1,0.6)],12,Transform3D.IDENTITY,false)
	rock.ball(0.09,Vector3(0.0,0.12,0.0),Vector3(1.1,0.6,1.0),7,Basis.IDENTITY,0.8,true)
	# [radius, length, tilt about z, tilt about x, turn, x, z]
	var crystals := [[0.06,0.3,0.0,0.05,0.3,0.0,0.0],[0.035,0.17,0.55,-0.1,0.9,0.05,0.02],[0.03,0.14,-0.6,0.25,0.1,-0.045,-0.02]]
	for c: Array in crystals:
		var r: float = c[0]
		var l: float = c[1]
		var b := Basis(Vector3.UP,float(c[4]))*Basis(Vector3.FORWARD,float(c[2]))*Basis(Vector3.RIGHT,float(c[3]))
		gem.lathe([Vector3(0.0,-0.02,0.4),Vector3(r,0.02,0.7),Vector3(r*0.95,l*0.72,1.0),Vector3(0.0,l,1.1)],6,Transform3D(b,Vector3(float(c[5]),0.11,float(c[6]))),true)
	var mesh := ArrayMesh.new()
	stand.commit(mesh,_gold(0.3))
	rock.commit(mesh,_mat(Color(0.3,0.27,0.3),0.9,0.0))
	var m := _mat(Color(0.25,0.5,1.0),0.05,0.2,Color(0.15,0.35,1.0)*0.55)
	m.rim_enabled = true
	m.rim = 0.6
	gem.commit(mesh,m)
	return _made(mesh,0.42,0.12,0.14)

# --- The idol ---------------------------------------------------------------------------

## A seated jade figure on a stepped gold plinth: a round head under a
## stepped gold crown, big ear lobes, arms folded over the belly, red gem
## eyes and a gold collar. Drawn 0.49 m, stood IDOL_SIZE of that.
const IDOL_SIZE := 1.3
static func _idol() -> Dictionary:
	var jade := _Geo.new()
	var gold := _Geo.new()
	var gem := _Geo.new()
	var k := IDOL_SIZE
	var up := Transform3D(Basis.from_scale(Vector3.ONE*k),Vector3.ZERO)
	gold.box(Vector3(0.28,0.05,0.24)*k,Vector3(0.0,0.025,0.0)*k,Vector3.ZERO,0.7)
	gold.box(Vector3(0.22,0.035,0.19)*k,Vector3(0.0,0.0675,0.0)*k,Vector3.ZERO,0.85)
	# Body, a pear wider at the seat; belly; legs crossed in front.
	jade.lathe([Vector3(0.0,0.085,0.4),Vector3(0.125,0.085,0.45),Vector3(0.12,0.13,0.7),Vector3(0.105,0.2,0.9),Vector3(0.08,0.25,0.9),Vector3(0.05,0.27,0.7),Vector3(0.0,0.275,0.6)],12,up,false)
	jade.ball(1.0,Vector3(0.0,0.17,-0.05)*k,Vector3(0.09,0.075,0.07)*k,10,Basis.IDENTITY,0.95)
	# The lap: crossed legs, a broad flattened roll in front, the feet up on it.
	jade.ball(1.0,Vector3(0.0,0.11,-0.065)*k,Vector3(0.15,0.045,0.075)*k,12,Basis.IDENTITY,0.75)
	for sx: float in [-1.0,1.0]:
		jade.ball(1.0,Vector3(sx*0.06,0.145,-0.1)*k,Vector3(0.035,0.02,0.025)*k,8,Basis(Vector3.UP,sx*0.5),0.9)
		# Arms: shoulder down to the elbow, the forearm in to the hands on the belly.
		jade.limb(Vector3(sx*0.095,0.25,0.0)*k,Vector3(sx*0.125,0.17,-0.04)*k,0.032*k,0.85)
		jade.limb(Vector3(sx*0.125,0.17,-0.04)*k,Vector3(sx*0.025,0.165,-0.11)*k,0.028*k,0.9)
		jade.ball(0.03*k,Vector3(sx*0.088,0.3,0.0)*k,Vector3(0.6,1.4,0.8),8,Basis.IDENTITY,0.8)
	jade.ball(0.032*k,Vector3(0.0,0.165,-0.115)*k,Vector3(1.2,0.8,0.9),8,Basis.IDENTITY,0.95)
	# Head and nose.
	jade.ball(0.09*k,Vector3(0.0,0.32,0.0)*k,Vector3(1.0,0.95,1.0),12,Basis.IDENTITY,1.0)
	jade.ball(0.018*k,Vector3(0.0,0.31,-0.085)*k,Vector3(0.8,1.0,0.8),6,Basis.IDENTITY,1.0)
	# Collar.
	gold.lathe([Vector3(0.05,0.255,0.7),Vector3(0.1,0.25,0.9),Vector3(0.1,0.265,1.0),Vector3(0.05,0.275,0.7)],12,up,false)
	# Crown: a band and a stepped point, a gem on its front.
	gold.lathe([Vector3(0.082,0.36,0.6),Vector3(0.09,0.365,0.8),Vector3(0.09,0.4,1.0),Vector3(0.07,0.4,1.0),Vector3(0.065,0.43,1.0),Vector3(0.045,0.43,1.0),Vector3(0.035,0.46,1.0),Vector3(0.0,0.49,1.0)],10,up,true)
	gem.lens(0.018*k,0.01*k,6,Transform3D(Basis(Vector3.RIGHT,-PI*0.5),Vector3(0.0,0.385,-0.09)*k))
	for sx: float in [-1.0,1.0]:
		gem.ball(0.016*k,Vector3(sx*0.033,0.33,-0.077)*k,Vector3.ONE,6,Basis.IDENTITY,1.0)
	var mesh := ArrayMesh.new()
	jade.commit(mesh,_mat(Color(0.3,0.66,0.48),0.35,0.0))
	gold.commit(mesh,_gold(0.3))
	gem.commit(mesh,_mat(Color(0.9,0.1,0.12),0.15,0.0,Color(0.9,0.12,0.1)*0.7))
	return _made(mesh,0.49*k,0.15*k,0.19*k)

# --- The dragon egg ---------------------------------------------------------------------

## The dragon egg, the heist's prize: a tall ovoid of deep teal shell under
## rings of scales laid like shingles, ember light showing in the seams
## of the lower rings; held in a gold cup on a round foot, three claws up
## out of its lip. 0.82 m tall.
const EGG_R := 0.29
const EGG_LIFT := 0.06
const EGG_TALL := 0.76
## The ember shows up to this far up the egg (0 foot, 1 tip).
const EMBER_UP := 0.5
static func _egg() -> Dictionary:
	var shell := _Geo.new()
	var plates := _Geo.new()
	var ember := _Geo.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bronze := _Geo.new()
	var base := EGG_LIFT
	var tall := EGG_TALL
	# The ovoid: a lathe, fuller below; its lower part the ember (lit
	# from within), which shows in the seams between the scales there.
	var prof: Array = []
	var eprof: Array = []
	var steps := 16
	for i: int in steps+1:
		var t := float(i)/float(steps)
		var p := Vector3(EGG_R*_egg_r(t),base+tall*t,lerpf(0.6,1.0,t))
		if t <= EMBER_UP+0.001: eprof.append(p)
		if t >= EMBER_UP-0.001: prof.append(p)
	shell.lathe(prof,18,Transform3D.IDENTITY,false)
	ember.lathe(eprof,18,Transform3D.IDENTITY,false)
	# Scales: overlapping rings up it, offset half a step each ring, the
	# upper smaller, their lower edges lifted like shingles.
	var rows := 11
	for r: int in rows:
		var t := 0.06+0.9*float(r)/float(rows-1)
		var y := base+tall*t
		var rad := EGG_R*_egg_r(t)
		var n := maxi(5,int(round(rad*TAU/0.08)))
		var size := clampf(rad*TAU/float(n)*1.15,0.035,0.1)
		# The surface's slope here: the scale lies along it.
		var dr := (EGG_R*_egg_r(t+0.02)-EGG_R*_egg_r(t-0.02))/(tall*0.04)
		var slope := atan(dr)
		for i: int in n:
			var a := TAU*(float(i)+0.5*float(r % 2))/float(n)
			var out := Vector3(sin(a),0.0,cos(a))
			var b := Basis(Vector3.UP,a)*Basis(Vector3.RIGHT,slope-0.18)
			plates.scale_plate(size,size*1.5,0.016,Transform3D(b,out*(rad+0.004)+Vector3(0.0,y,0.0)),lerpf(0.7,1.0,t)*rng.randf_range(0.82,1.05))
	# Cracks: jagged seams of ember light up its sides, over the scales.
	for c: Array in [[-0.5,0.12,0.62],[0.55,0.1,0.5],[2.4,0.14,0.55]]:
		var path: Array = []
		var k := 9
		for j: int in k+1:
			var t := lerpf(float(c[1]),float(c[2]),float(j)/float(k))
			var a := float(c[0])+(0.09 if j % 2 == 0 else -0.09)*(1.0-float(j)/float(k)*0.5)
			var rad := EGG_R*_egg_r(t)+0.022
			path.append(Vector3(sin(a)*rad,base+tall*t,cos(a)*rad))
		ember.ribbon(path,0.024,0.006)
	# The cradle: a gold cup on a round foot holding its base, three
	# claws up out of its lip gripping the egg's sides.
	var lip_t := 0.13
	var lip := Vector2(EGG_R*_egg_r(lip_t)+0.02,base+tall*lip_t)
	bronze.lathe([Vector3(0.0,0.0,0.5),Vector3(0.21,0.0,0.55),Vector3(0.21,0.0,0.55),Vector3(0.21,0.022,0.75),Vector3(0.21,0.022,0.75),
		Vector3(0.15,0.04,0.85),Vector3(0.1,0.06,0.8),Vector3(0.11,base+0.02,0.85),Vector3(lip.x-0.01,lip.y-0.02,1.0),
		Vector3(lip.x+0.012,lip.y,1.0),Vector3(lip.x+0.012,lip.y,1.0),Vector3(lip.x-0.025,lip.y+0.005,0.6),Vector3(lip.x-0.025,lip.y+0.005,0.6),
		Vector3(0.05,base,0.3)],20,Transform3D.IDENTITY,false)
	bronze.torus(lip.x+0.005,0.018,Transform3D(Basis.IDENTITY,Vector3(0.0,lip.y,0.0)),20,6,1.0)
	var t1 := 0.33
	var top := Vector2(EGG_R*_egg_r(t1)+0.04,base+tall*t1)
	for i: int in 3:
		var a := TAU*float(i)/3.0+PI/3.0
		var out := Vector3(sin(a),0.0,cos(a))
		var side := out.cross(Vector3.UP)
		# A claw up the egg from the lip, its tip curling in over the egg.
		var d := top-lip
		var lean := atan2(d.x,d.y)
		var mid := (lip+top)*0.5
		bronze.capsule(0.036,d.length(),Transform3D(Basis(side,-lean),out*mid.x+Vector3.UP*mid.y),0.9)
		bronze.cone(0.036,0.13,Transform3D(Basis(side,0.6),out*(top.x-0.025)+Vector3.UP*(top.y+0.06)),1.0)
	var mesh := ArrayMesh.new()
	shell.commit(mesh,_mat(Color(0.06,0.2,0.24),0.45,0.1))
	var scale_m := _mat(Color(0.15,0.48,0.54),0.3,0.3,Color(0.05,0.2,0.22)*0.35)
	scale_m.rim_enabled = true
	scale_m.rim = 0.7
	scale_m.rim_tint = 0.3
	plates.commit(mesh,scale_m)
	ember.commit(mesh,_mat(Color(0.6,0.15,0.03),0.6,0.0,Color(1.0,0.32,0.04)*1.8))
	bronze.commit(mesh,_gold(0.35))
	var made := _made(mesh,base+tall,0.28,0.36)
	# A warm light from within, small and shadowless.
	var lamp := OmniLight3D.new()
	lamp.name = "Ember"
	lamp.light_color = Color(1.0,0.5,0.2)
	lamp.light_energy = 0.7
	lamp.omni_range = 1.3
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0,base+tall*0.3,-0.4)
	(made.node as Node3D).add_child(lamp)
	return made

## The egg's radius (of its widest) at `t` up it, 0 foot to 1 tip.
static func _egg_r(t: float) -> float:
	t = clampf(t,0.0,1.0)
	# Fullest at about 0.4 up, a blunt foot, a narrower tip.
	var s := sin(PI*pow(t,0.85))
	return pow(maxf(s,0.0),0.8)*(1.0-0.18*t)

# --- The urn -----------------------------------------------------------------------------

## A painted amphora: a round belly on a short foot, a narrow neck under a
## flared lip, two loop handles shoulder to neck, a black band with a gold
## zigzag round the belly and a thin band under the neck. 0.72 m tall.
static func _urn() -> Dictionary:
	var clay := _Geo.new()
	var band := _Geo.new()
	var gold := _Geo.new()
	var prof := [
		Vector3(0.0,0.0,0.4),Vector3(0.11,0.0,0.5),Vector3(0.11,0.0,0.5),Vector3(0.115,0.03,0.7),Vector3(0.08,0.06,0.6),
		Vector3(0.1,0.1,0.65),Vector3(0.17,0.17,0.8),Vector3(0.21,0.26,0.95),Vector3(0.225,0.34,1.0),Vector3(0.215,0.42,1.0),
		Vector3(0.17,0.5,0.95),Vector3(0.1,0.56,0.85),Vector3(0.075,0.6,0.85),Vector3(0.075,0.66,0.9),Vector3(0.12,0.71,1.0),
		Vector3(0.12,0.72,1.0),Vector3(0.12,0.72,1.0),Vector3(0.095,0.72,0.6),Vector3(0.095,0.72,0.6),Vector3(0.065,0.68,0.25),Vector3(0.0,0.62,0.1)]
	clay.lathe(prof,20,Transform3D.IDENTITY,false)
	# The bands: painted on, a hair proud of the clay.
	band.lathe([Vector3(0.211,0.27,0.9),Vector3(0.227,0.3,1.0),Vector3(0.232,0.34,1.0),Vector3(0.224,0.38,1.0),Vector3(0.212,0.41,0.9)],20,Transform3D.IDENTITY,false)
	band.lathe([Vector3(0.105,0.555,0.9),Vector3(0.087,0.58,1.0),Vector3(0.079,0.6,0.9)],20,Transform3D.IDENTITY,false)
	for i: int in 14:
		var a := TAU*float(i)/14.0
		var out := Vector3(sin(a),0.0,cos(a))
		var lean := 0.55 if i % 2 == 0 else -0.55
		gold.box(Vector3(0.062,0.014,0.01),out*0.234+Vector3(0.0,0.34,0.0),Vector3.ZERO,1.0,Basis(Vector3.UP,a)*Basis(Vector3.BACK,lean))
	# Handles: half loops from the shoulder up to the neck.
	for sx: float in [-1.0,1.0]:
		clay.torus(0.085,0.02,Transform3D(Basis(Vector3.RIGHT,PI*0.5)*Basis.from_scale(Vector3(0.9,1.0,1.05)),Vector3(sx*0.115,0.6,0.0)),12,6,0.85,-sx*PI*0.5,PI)
	var mesh := ArrayMesh.new()
	clay.commit(mesh,_mat(Color(0.78,0.42,0.24),0.8,0.0))
	band.commit(mesh,_mat(Color(0.09,0.07,0.06),0.6,0.0))
	gold.commit(mesh,_gold(0.3))
	return _made(mesh,0.72,0.22,0.26)

# --- The bars ----------------------------------------------------------------------------

## A stack of six gold ingots, three, two across them, one on top, each
## a tapered block with a stamp on its top. 0.33 m tall, broad.
static func _bar() -> Dictionary:
	var gold := _Geo.new()
	var stamp := _Geo.new()
	var long := 0.4
	var wid := 0.17
	var tall := 0.11
	var gap := 0.022
	var layers := [[3,0.0],[2,PI*0.5],[1,0.0]]
	for li: int in layers.size():
		var n: int = layers[li][0]
		var turn := Basis(Vector3.UP,float(layers[li][1])+0.04*float(li))
		var y := float(li)*tall
		for i: int in n:
			var off := (float(i)-float(n-1)*0.5)*(wid+gap)
			var at := turn*Vector3(0.0,0.0,off)+Vector3(0.0,y,0.0)
			var shade := lerpf(0.7,1.0,float(li)/2.0)
			gold.ingot(Vector2(long,wid),Vector2(long-0.06,wid-0.04),tall,Transform3D(turn,at),shade)
			stamp.box(Vector3(0.1,0.004,0.05),at+Vector3(0.0,tall+0.001,0.0),Vector3.ZERO,shade,turn)
	var mesh := ArrayMesh.new()
	gold.commit(mesh,_gold(0.22))
	stamp.commit(mesh,_mat(DARK_GOLD,0.5,0.4))
	return _made(mesh,tall*3.0,0.24,0.3)

# --- Shared ------------------------------------------------------------------------------

static func _made(mesh: ArrayMesh, height: float, grip: float, radius: float) -> Dictionary:
	var fig := MeshInstance3D.new()
	fig.name = "Figure"
	fig.mesh = mesh
	var node := Node3D.new()
	node.add_child(fig)
	return {"node":node,"height":height,"grip":grip,"radius":radius}

static func _mat(albedo: Color, rough: float, metal: float, glow := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	if glow != Color.BLACK:
		m.emission_enabled = true
		m.emission = glow
	return m

## The chest's wood: warm, with a sheen at its edges so it reads in shade.
static func _wood() -> StandardMaterial3D:
	var m := _mat(Color(0.66,0.42,0.24),0.8,0.0,Color(0.66,0.42,0.24)*0.15)
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.6
	return m

## Gold that reads in shade too: half metal, a faint warm glow of its own
## and a sheen at its edges.
static func _gold(rough: float) -> StandardMaterial3D:
	var m := _mat(GOLD,rough,0.75,GOLD*0.32)
	m.rim_enabled = true
	m.rim = 0.5
	m.rim_tint = 0.8
	return m

## The triangles of one surface, gathered with their grime: each vertex's
## colour is its part's shade times crevice darkness (faces turned down
## darker, the piece's foot darker).
class _Geo:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()

	static func grime(p: Vector3, n: Vector3, shade: float) -> float:
		var under := lerpf(0.62,1.0,clampf(n.y*0.5+0.5,0.0,1.0))
		var foot := lerpf(0.68,1.0,clampf(p.y/0.06,0.0,1.0))
		return clampf(shade*under*foot,0.0,1.0)

	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, sa: float, sb: float, sc: float) -> void:
		var face := (b-a).cross(c-a)
		if face.length_squared() < 1e-14: return
		# Godot's front faces wind clockwise: flip one that winds the other way.
		if face.dot(na+nb+nc) > 0.0:
			var t := b
			b = c
			c = t
			var tn := nb
			nb = nc
			nc = tn
			var ts := sb
			sb = sc
			sc = ts
		verts.append(a)
		verts.append(b)
		verts.append(c)
		norms.append(na)
		norms.append(nb)
		norms.append(nc)
		var ga := grime(a,na,sa)
		var gb := grime(b,nb,sb)
		var gc := grime(c,nc,sc)
		cols.append(Color(ga,ga,ga))
		cols.append(Color(gb,gb,gb))
		cols.append(Color(gc,gc,gc))

	## A primitive's triangles under `xf`.
	func prim(m: PrimitiveMesh, xf: Transform3D, shade: float, flat := false) -> void:
		var arr := m.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		for i: int in range(0,idx.size(),3):
			var a := xf*v[idx[i]]
			var b := xf*v[idx[i+1]]
			var c := xf*v[idx[i+2]]
			var na := (nb*n[idx[i]]).normalized()
			var nbb := (nb*n[idx[i+1]]).normalized()
			var nc := (nb*n[idx[i+2]]).normalized()
			if flat:
				var f := (b-a).cross(c-a).normalized()
				if f.dot(na+nbb+nc) < 0.0: f = -f
				na = f
				nbb = f
				nc = f
			tri(a,b,c,na,nbb,nc,shade,shade,shade)

	func box(size: Vector3, at: Vector3, turn := Vector3.ZERO, shade := 1.0, basis := Basis.IDENTITY) -> void:
		var b := BoxMesh.new()
		b.size = size
		var bs := basis if basis != Basis.IDENTITY else Basis.from_euler(turn)
		prim(b,Transform3D(bs,at),shade)

	func ball(radius: float, at: Vector3, stretch := Vector3.ONE, sides := 10, turn := Basis.IDENTITY, shade := 1.0, flat := false) -> void:
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius*2.0
		s.radial_segments = sides
		s.rings = maxi(4,sides/2)
		prim(s,Transform3D(turn*Basis.from_scale(stretch),at),shade,flat)

	func capsule(radius: float, length: float, xf: Transform3D, shade := 1.0) -> void:
		var c := CapsuleMesh.new()
		c.radius = radius
		c.height = length+radius*2.0
		c.radial_segments = 8
		c.rings = 2
		prim(c,xf,shade)

	## A capsule from `a` to `b`, `radius` round.
	func limb(a: Vector3, b: Vector3, radius: float, shade := 1.0) -> void:
		var d := b-a
		var y := d.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		capsule(radius,d.length(),Transform3D(Basis(x,y,z),(a+b)*0.5),shade)

	func cone(radius: float, length: float, xf: Transform3D, shade := 1.0) -> void:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = radius
		c.height = length
		c.radial_segments = 6
		c.rings = 0
		prim(c,xf,shade)

	## A torus `radius` round its middle, `thick` through, its hole along
	## y; `arc` of it (radians) from `from`.
	func torus(radius: float, thick: float, xf: Transform3D, around := 16, sides := 6, shade := 1.0, from := 0.0, arc := TAU) -> void:
		var ring: Array = []
		for i: int in around+1:
			var a := from+arc*float(i)/float(around)
			var c := Vector3(cos(a),0.0,sin(a))
			var row: Array = []
			for j: int in sides+1:
				var b := TAU*float(j)/float(sides)
				var n := c*cos(b)+Vector3.UP*sin(b)
				row.append([c*radius+n*thick,n])
			ring.append(row)
		var nb := xf.basis.inverse().transposed()
		for i: int in around:
			for j: int in sides:
				var q := [ring[i][j],ring[i+1][j],ring[i+1][j+1],ring[i][j+1]]
				var p: Array = []
				var nn: Array = []
				for x: Array in q:
					p.append(xf*(x[0] as Vector3))
					nn.append((nb*(x[1] as Vector3)).normalized())
				tri(p[0],p[1],p[2],nn[0],nn[1],nn[2],shade,shade,shade)
				tri(p[0],p[2],p[3],nn[0],nn[2],nn[3],shade,shade,shade)

	## A surface of revolution round y: `profile` is Vector3(radius, y,
	## shade), foot to top; a point given twice makes a crease. `flat`
	## draws it faceted.
	func lathe(profile: Array, sides: int, xf: Transform3D, flat: bool, shade := 1.0) -> void:
		var n := profile.size()
		var seg_n: Array = []
		for i: int in n-1:
			var p0: Vector3 = profile[i]
			var p1: Vector3 = profile[i+1]
			var d := Vector2(p1.x-p0.x,p1.y-p0.y)
			seg_n.append(Vector2(d.y,-d.x).normalized() if d.length() > 1e-6 else Vector2.ZERO)
		var pt_n: Array = []
		for i: int in n:
			var s := Vector2.ZERO
			if i > 0: s += seg_n[i-1]
			if i < n-1: s += seg_n[i]
			pt_n.append(s.normalized())
		var nb := xf.basis.inverse().transposed()
		for i: int in n-1:
			var sn: Vector2 = seg_n[i]
			if sn == Vector2.ZERO: continue
			var p0: Vector3 = profile[i]
			var p1: Vector3 = profile[i+1]
			var n0: Vector2 = pt_n[i]
			var n1: Vector2 = pt_n[i+1]
			for k: int in sides:
				var a0 := TAU*float(k)/float(sides)
				var a1 := TAU*float(k+1)/float(sides)
				var c0 := Vector3(sin(a0),0.0,cos(a0))
				var c1 := Vector3(sin(a1),0.0,cos(a1))
				var v00 := xf*(c0*p0.x+Vector3.UP*p0.y)
				var v01 := xf*(c1*p0.x+Vector3.UP*p0.y)
				var v10 := xf*(c0*p1.x+Vector3.UP*p1.y)
				var v11 := xf*(c1*p1.x+Vector3.UP*p1.y)
				var m00 := (nb*(c0*n0.x+Vector3.UP*n0.y)).normalized()
				var m01 := (nb*(c1*n0.x+Vector3.UP*n0.y)).normalized()
				var m10 := (nb*(c0*n1.x+Vector3.UP*n1.y)).normalized()
				var m11 := (nb*(c1*n1.x+Vector3.UP*n1.y)).normalized()
				if flat:
					var cm := (c0+c1).normalized()
					var f := (nb*(cm*sn.x+Vector3.UP*sn.y)).normalized()
					m00 = f
					m01 = f
					m10 = f
					m11 = f
				var s0 := p0.z*shade
				var s1 := p1.z*shade
				if p0.x > 1e-6: tri(v00,v01,v11,m00,m01,m11,s0,s0,s1)
				if p1.x > 1e-6: tri(v00,v11,v10,m00,m11,m10,s0,s1,s1)

	## A gem's flat lens: two shallow cones back to back, `r` across, `t`
	## thick, its face along y.
	func lens(r: float, t: float, sides: int, xf: Transform3D) -> void:
		lathe([Vector3(0.0,-t*0.3,0.7),Vector3(r,0.0,1.0),Vector3(r*0.55,t*0.6,1.0),Vector3(0.0,t*0.7,1.0)],sides,xf,true)

	## A half barrel (a lid): `w` along x, a half round of `r` up over y,
	## the open flat side down.
	func half_barrel(w: float, r: float, xf: Transform3D, shade := 1.0) -> void:
		var prof := []
		var around := 8
		for i: int in around+1:
			var a := PI*float(i)/float(around)
			prof.append(Vector2(cos(a)*r,sin(a)*r))
		var nb := xf.basis.inverse().transposed()
		var hx := w*0.5
		for i: int in around:
			var p0: Vector2 = prof[i]
			var p1: Vector2 = prof[i+1]
			var n0 := (nb*Vector3(0.0,p0.y,p0.x).normalized()).normalized()
			var n1 := (nb*Vector3(0.0,p1.y,p1.x).normalized()).normalized()
			var a := xf*Vector3(-hx,p0.y,p0.x)
			var b := xf*Vector3(hx,p0.y,p0.x)
			var c := xf*Vector3(hx,p1.y,p1.x)
			var d := xf*Vector3(-hx,p1.y,p1.x)
			tri(a,b,c,n0,n0,n1,shade,shade,shade)
			tri(a,c,d,n0,n1,n1,shade,shade,shade)
			# The ends.
			for sx: float in [-1.0,1.0]:
				var en := (nb*Vector3(sx,0.0,0.0)).normalized()
				tri(xf*Vector3(sx*hx,0.0,0.0),xf*Vector3(sx*hx,p0.y,p0.x),xf*Vector3(sx*hx,p1.y,p1.x),en,en,en,shade,shade,shade)
		# The inside, dark.
		var dn := (nb*Vector3.DOWN).normalized()
		tri(xf*Vector3(-hx,0.0,-r),xf*Vector3(hx,0.0,-r),xf*Vector3(hx,0.0,r),dn,dn,dn,0.5,0.5,0.5)
		tri(xf*Vector3(-hx,0.0,-r),xf*Vector3(hx,0.0,r),xf*Vector3(-hx,0.0,r),dn,dn,dn,0.5,0.5,0.5)

	## A dragon scale: a rounded shingle `w` wide, `l` long, `t` proud,
	## in the xy plane, its outer face toward +z, its root up; domed, its
	## lower rim darker (the shadow of the overlap).
	func scale_plate(w: float, l: float, t: float, xf: Transform3D, shade := 1.0) -> void:
		var o := [Vector2(-0.42,0.35),Vector2(-0.5,0.0),Vector2(-0.4,-0.32),Vector2(0.0,-0.52),Vector2(0.4,-0.32),Vector2(0.5,0.0),Vector2(0.42,0.35)]
		var nb := xf.basis.inverse().transposed()
		var out := (nb*Vector3.BACK).normalized()
		var pts: Array = []
		var nrs: Array = []
		var shs: Array = []
		for q: Vector2 in o:
			pts.append(xf*Vector3(q.x*w,q.y*l,0.0))
			nrs.append((nb*(Vector3(q.x,q.y*0.6,0.0).normalized()*0.5+Vector3.BACK*0.85)).normalized())
			shs.append(shade*lerpf(0.55,0.95,clampf(q.y/0.35*0.5+0.5,0.0,1.0)))
		var rm := xf*Vector3(0.0,-l*0.02,t)
		var rt := xf*Vector3(0.0,l*0.35,t*0.6)
		for f: int in o.size()-1:
			tri(pts[f],pts[f+1],rm,nrs[f],nrs[f+1],out,shs[f],shs[f+1],shade)
		# The root, under the next row: up to its edge.
		var nl := (nb*Vector3(0.0,1.0,0.5)).normalized()
		tri(pts[0],rm,rt,nrs[0],out,nl,shs[0],shade,shade*0.8)
		tri(pts[o.size()-1],rt,rm,nrs[o.size()-1],nl,out,shs[o.size()-1],shade*0.8,shade)

	## A flat strip `width` wide along `path` (points on a surface round
	## y), facing out from the y axis, tapering to `tip` at its ends.
	func ribbon(path: Array, width: float, tip: float) -> void:
		var n := path.size()
		for i: int in n-1:
			var p0: Vector3 = path[i]
			var p1: Vector3 = path[i+1]
			var o0 := Vector3(p0.x,0.0,p0.z).normalized()
			var o1 := Vector3(p1.x,0.0,p1.z).normalized()
			var along := (p1-p0).normalized()
			var w0 := lerpf(tip,width,sin(PI*float(i)/float(n-1)))*0.5
			var w1 := lerpf(tip,width,sin(PI*float(i+1)/float(n-1)))*0.5
			var s0 := along.cross(o0).normalized()
			var s1 := along.cross(o1).normalized()
			tri(p0-s0*w0,p0+s0*w0,p1+s1*w1,o0,o0,o1,1.0,1.0,1.0)
			tri(p0-s0*w0,p1+s1*w1,p1-s1*w1,o0,o1,o1,1.0,1.0,1.0)

	## A gold ingot: a tapered block, `bottom` (x long, z wide) under `top`,
	## `tall`, its foot at `xf`'s origin; faceted.
	func ingot(bottom: Vector2, top: Vector2, tall: float, xf: Transform3D, shade := 1.0) -> void:
		var b := [Vector3(-bottom.x,0.0,-bottom.y)*0.5,Vector3(bottom.x,0.0,-bottom.y)*0.5,Vector3(bottom.x,0.0,bottom.y)*0.5,Vector3(-bottom.x,0.0,bottom.y)*0.5]
		var t := [Vector3(-top.x*0.5,tall,-top.y*0.5),Vector3(top.x*0.5,tall,-top.y*0.5),Vector3(top.x*0.5,tall,top.y*0.5),Vector3(-top.x*0.5,tall,top.y*0.5)]
		var nb := xf.basis.inverse().transposed()
		var quads := [[t[0],t[1],t[2],t[3]],[b[3],b[2],b[1],b[0]]]
		for i: int in 4:
			quads.append([b[i],b[(i+1)%4],t[(i+1)%4],t[i]])
		for q: Array in quads:
			var q0: Vector3 = q[0]
			var q1: Vector3 = q[1]
			var q2: Vector3 = q[2]
			var q3: Vector3 = q[3]
			var out := ((q0+q1+q2+q3)*0.25-Vector3(0.0,tall*0.5,0.0)).normalized()
			var nrm := (q1-q0).cross(q2-q0).normalized()
			if nrm.dot(out) < 0.0: nrm = -nrm
			var wn := (nb*nrm).normalized()
			tri(xf*q0,xf*q1,xf*q2,wn,wn,wn,shade,shade,shade)
			tri(xf*q0,xf*q2,xf*q3,wn,wn,wn,shade,shade,shade)

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if verts.is_empty(): return
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
