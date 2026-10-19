extends Node3D
## The wanderer's loot bag (docs/design/bag/spec-bag.md): a tattered cloth
## sack worn on his back, filled with loot. It sits alongside the hand-carry
## (scripts/carry/carry_host.gd), on a study with the character study's
## `motor`, `body`, `figure` and a `loot` list ({id, kind, kg, spot, node,
## measures}, studies/bag_study.gd).
##
## - `walk_carry` (E, pad B; scripts/pad.gd) by a loot piece puts it in:
##   he dips to it, it hops over his shoulder into the bag's mouth, and the
##   sack swells (its belly's radius with the root of the kg) with a gulp;
## - its kg scale his walk, run, jump and turn on one continuous curve
##   (FEEL: free up to FREE_KG, the row's value at CAP, eased between), and
##   moves drop off past each of BARS (the motor's `wall_on`, `ledge_on`,
##   `sail_on`, `rope_on`); a barred move tried, he balks (the motor's
##   `refused`: a lurch and a shake of the head, as carry_host's);
## - past CAP it takes no more: the piece stays where it lies, and he
##   balks, a low "uh-uh" sounds and a line says so;
## - a readout on screen: the kg, the cap, a bar, the barred moves.
##
## All procedural (the sack's mesh, its sway, the dip, the balk), greybox.
const Weights = preload("res://scripts/carry/carry_weights.gd")
const CarryHost = preload("res://scripts/carry/carry_host.gd")

## The most the bag holds (kg).
const CAP := 24.0
## Up to this many kg he doesn't feel it.
const FREE_KG := 2.0
## At CAP, each pace times the empty one (eased in from FREE_KG, EASE the
## curve's power: over 1 the first kg cost little, the last the most).
const FEEL := {"walk":0.6,"run":0.45,"jump":0.4,"turn":0.55}
const EASE := 1.2
## The moves dropped past each weight (kg), in order.
const BARS := [["wall",5.0],["ledge",9.0],["sail",13.0],["rope",17.0]]

## Reach (m across from his feet to a piece's foot, times his size, past
## its radius; and up or down).
const REACH := 0.9
const REACH_UP := 0.8
## The putting in: its length (s), his paces meanwhile (times), the dip of
## his chest at its middle (degrees), the hop's height over the bag (m,
## times size).
const STOW_TIME := 0.45
const STOW_PACE := 0.15
const STOW_BEND := 32.0
const STOW_HOP := 0.6
## The sack: its belly's radius empty and its growth with the root of the
## kg (m, times size); empty it hangs flat (DEPTH_EMPTY of its round depth).
const SACK_R := 0.12
const SACK_R_KG := 0.045
const DEPTH_EMPTY := 0.35
## Where it rides: its middle this far behind the chest bone, past its
## depth, and this far up (m, times size; less its radius times DROOP).
const BACK_OUT := 0.17
const BACK_UP := 0.12
const DROOP := 0.45
## Its follow-through: a spring on its lag behind his moves (per s^2 and
## damping per s), the lag's most (m, times size) and its swing (degrees
## per m of lag).
const SWAY_K := 90.0
const SWAY_DAMP := 9.0
const SWAY_MAX := 0.12
const SWAY_TILT := 220.0
## The gulp: the swell's overshoot as a piece drops in, and its time (s).
const GULP := 0.18
const GULP_TIME := 0.35
## The refusal line's time (s).
const LINE_TIME := 1.6

const CLOTH := Color("a88b5e")
const PATCH := Color("7a6040")
const ROPE := Color("9a7b52")

var study: Node3D
## What's in it ({id, kind, kg, ...} from the study's `loot`), and their kg.
var items: Array = []
var kg := 0.0
## The barred moves now, and the refusals (drivers read them).
var barred: Array = []
var refusals := 0
var balks := 0
var balked := ""
## The piece being put in ({} none) and seconds into it.
var stowing := {}
var _stow_t := 0.0
var _stow_from := Transform3D.IDENTITY

var _base := {}
var _sack: Node3D
var _cloth: MeshInstance3D
var _knot: MeshInstance3D
var _straps: Array[MeshInstance3D] = []
var _cloth_mat: StandardMaterial3D
var _rope_mat: StandardMaterial3D
var _r := 0.0
var _r_to := 0.0
var _drawn := -1.0
var _gulp_t := -1.0
var _lag := Vector3.ZERO
var _lag_v := Vector3.ZERO
var _last_mid := Vector3.INF
var _balk_t := -1.0
var _balk_side := 1.0
var _prompt: Label3D
var _line: Label3D
var _line_t := -1.0
var _readout: Label
var _gulp_sound: AudioStreamPlayer
var _no_sound: AudioStreamPlayer
static var _no_take: AudioStreamWAV = null

func setup(host: Node3D) -> void:
	study = host
	name = "LootBag"
	process_priority = 100
	_cloth_mat = StandardMaterial3D.new()
	_cloth_mat.vertex_color_use_as_albedo = true
	_cloth_mat.vertex_color_is_srgb = true
	_cloth_mat.roughness = 1.0
	_cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.albedo_color = ROPE
	_rope_mat.roughness = 0.9
	_sack = Node3D.new()
	_sack.name = "Sack"
	_sack.top_level = true
	add_child(_sack)
	_cloth = MeshInstance3D.new()
	_cloth.name = "Cloth"
	_cloth.material_override = _cloth_mat
	_sack.add_child(_cloth)
	_knot = MeshInstance3D.new()
	_knot.name = "Tie"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 1.0
	torus.rings = 12
	torus.ring_segments = 6
	_knot.mesh = torus
	_knot.material_override = _rope_mat
	_sack.add_child(_knot)
	for i in 2:
		var strap := MeshInstance3D.new()
		strap.name = "Strap%d" % i
		strap.top_level = true
		var c := CylinderMesh.new()
		c.top_radius = 0.018
		c.bottom_radius = 0.018
		c.height = 1.0
		c.radial_segments = 5
		c.rings = 1
		strap.mesh = c
		strap.material_override = _rope_mat
		add_child(strap)
		_straps.append(strap)
	_prompt = _label(32,Color(1,1,1))
	_line = _label(40,Color(1.0,0.75,0.6))
	var layer := CanvasLayer.new()
	layer.name = "BagReadout"
	add_child(layer)
	_readout = Label.new()
	_readout.anchor_left = 1.0
	_readout.anchor_right = 1.0
	_readout.offset_left = -330.0
	_readout.offset_right = -16.0
	_readout.offset_top = 14.0
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_readout.add_theme_font_size_override(&"font_size",20)
	_readout.add_theme_constant_override(&"outline_size",6)
	_readout.add_theme_color_override(&"font_outline_color",Color(0,0,0,0.8))
	layer.add_child(_readout)
	_gulp_sound = AudioStreamPlayer.new()
	_gulp_sound.stream = CarryHost._thud_stream()
	_gulp_sound.volume_db = -6.0
	add_child(_gulp_sound)
	_no_sound = AudioStreamPlayer.new()
	_no_sound.stream = _no_stream()
	_no_sound.volume_db = -4.0
	add_child(_no_sound)
	var motor: Variant = study.get("motor")
	if motor != null: motor.refused.connect(_on_refused)
	_set_kg(0.0)
	_r = _r_to
	_show_readout()

func _label(px: int, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = px
	l.pixel_size = 0.006
	l.outline_size = 8
	l.modulate = colour
	l.visible = false
	add_child(l)
	return l

# --- Filling it -------------------------------------------------------------------------

## The feel at `kg_in` kg: {walk, run, jump, turn} times the empty ones.
static func feel_of(kg_in: float) -> Dictionary:
	var f := pow(clampf((kg_in-FREE_KG)/(CAP-FREE_KG),0.0,1.0),EASE)
	var out := {}
	for k: String in FEEL: out[k] = lerpf(1.0,float(FEEL[k]),f)
	return out

## The moves barred at `kg_in` kg.
static func bars_of(kg_in: float) -> Array:
	var out: Array = []
	for b: Array in BARS:
		if kg_in >= float(b[1])-0.001: out.append(str(b[0]))
	return out

## The sack's belly radius at `kg_in` kg (m, times size).
static func radius_of(kg_in: float) -> float:
	return SACK_R+SACK_R_KG*sqrt(maxf(kg_in,0.0))

func fits(piece: Dictionary) -> bool:
	return kg+float(piece.kg) <= CAP+0.001

func _set_kg(k: float) -> void:
	kg = k
	barred = bars_of(kg)
	_r_to = radius_of(kg)
	_apply_feel(STOW_PACE if not stowing.is_empty() else 1.0)

## The bag's kg on the motor's kept feel; `pace` times the paces more.
func _apply_feel(pace: float) -> void:
	var m: Variant = study.get("motor")
	if m == null: return
	if _base.is_empty():
		_base = {"walk":m.walk,"run":m.run,"jumps":(m.jumps as Array).duplicate(),"turn":m.turn,"turn_run":m.turn_run,
			"wall_on":m.wall_on,"wallrun_on":m.wallrun_on,"ledge_on":m.ledge_on,"sail_on":m.sail_on,"rope_on":m.rope_on}
	var w := feel_of(kg)
	m.walk = float(_base.walk)*float(w.walk)*pace
	m.run = float(_base.run)*float(w.run)*pace
	var j: Array = []
	for h: float in _base.jumps: j.append(h*float(w.jump)*(1.0 if pace >= 1.0 else 0.0))
	m.jumps = j
	m.turn = float(_base.turn)*float(w.turn)
	m.turn_run = float(_base.turn_run)*float(w.turn)
	m.wall_on = bool(_base.wall_on) and not barred.has("wall")
	m.wallrun_on = bool(_base.wallrun_on) and not barred.has("wall")
	m.ledge_on = bool(_base.ledge_on) and not barred.has("ledge")
	m.sail_on = bool(_base.sail_on) and not barred.has("sail")
	m.rope_on = bool(_base.rope_on) and not barred.has("rope")

## Empties it: every piece back on its spot.
func empty() -> void:
	stowing = {}
	for p: Dictionary in items:
		var node: Node3D = p.node
		node.visible = true
		node.transform = Transform3D.IDENTITY
		(p.spot as Node3D).visible = true
	items.clear()
	_set_kg(0.0)

# --- Input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"walk_carry",false,true) or event.is_echo(): return
	if not _on_foot() or not stowing.is_empty(): return
	var p := in_reach()
	if p.is_empty(): return
	get_viewport().set_input_as_handled()
	take(p)

func _on_foot() -> bool:
	if study == null or not bool(study.get("walk_ready")): return false
	var editor := study.get_node_or_null("LayoutEdit")
	if editor != null and bool(editor.get("editing")): return false
	var motor: Variant = study.get("motor")
	return motor != null and motor.grounded

## The nearest loose piece in reach of his feet, or {}.
func in_reach() -> Dictionary:
	var motor: Variant = study.get("motor")
	var feet: Vector3 = motor.feet
	var s: float = motor.size
	var best := {}
	var near := INF
	for p: Dictionary in study.get("loot"):
		if items.has(p) or p == stowing: continue
		var at: Vector3 = (p.node as Node3D).global_position
		var across := Vector2(at.x-feet.x,at.z-feet.z).length()
		if across > REACH*s+float(p.measures.radius) or absf(at.y-feet.y) > REACH_UP*s: continue
		if across < near:
			near = across
			best = p
	return best

## Puts `p` in, or refuses it past the cap.
func take(p: Dictionary) -> void:
	if not fits(p):
		refusals += 1
		_balk("full")
		_no_sound.play()
		_say("Too full: %s kg won't go in (%s / %d kg)" % [_kg(float(p.kg)),_kg(kg),int(CAP)])
		return
	stowing = p
	_stow_t = 0.0
	_stow_from = (p.node as Node3D).global_transform
	_apply_feel(STOW_PACE)

func _say(text: String) -> void:
	_line.text = text
	_line.visible = true
	_line_t = 0.0

static func _kg(v: float) -> String:
	return ("%.1f" % v) if v != floorf(v) else ("%d" % int(v))

# --- Each frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if study == null: return
	var motor: Variant = study.get("motor")
	if motor == null: return
	_r = move_toward(_r,_r_to,delta*0.6)
	_place_sack(delta)
	_stow_step(delta)
	_balk_pose(delta)
	_show_prompt()
	_show_readout()
	if _line_t >= 0.0:
		_line_t += delta
		_line.global_position = motor.feet+Vector3.UP*2.3*float(motor.size)
		if _line_t > LINE_TIME:
			_line_t = -1.0
			_line.visible = false

## The sack on his back: hung behind his chest bone along his spine, lagging
## his moves on a spring; swollen to its kg, gulping as a piece drops in.
func _place_sack(delta: float) -> void:
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var fill := clampf(kg/CAP,0.0,1.0)
	var gulp := 1.0
	if _gulp_t >= 0.0:
		_gulp_t += delta
		var k := _gulp_t/GULP_TIME
		if k >= 1.0: _gulp_t = -1.0
		else: gulp = 1.0+GULP*sin(PI*k)*(1.0-k*0.5)
	var r := _r*s
	var depth := lerpf(DEPTH_EMPTY,1.0,sqrt(fill))
	if absf(_r-_drawn) > 0.004: _shape(_r,depth)
	var fwd := _forward()
	var chest := _bone_world("chest")
	var neck := _bone_world("neck")
	var hips := _bone_world("hips")
	if chest == Vector3.INF: chest = motor.feet+Vector3.UP*0.5*s
	var up := Vector3.UP
	if neck != Vector3.INF and hips != Vector3.INF and neck.distance_to(hips) > 0.01: up = (neck-hips).normalized()
	var back := -fwd
	back = (back-up*back.dot(up)).normalized()
	var mid := chest+back*(BACK_OUT*s+r*depth)+up*(BACK_UP*s-r*DROOP)
	# Its lag: the spring pulls it after where it should be.
	if _last_mid != Vector3.INF and delta > 0.0:
		var moved := mid-_last_mid
		if moved.length() < 1.0:
			_lag -= moved
			var acc := -_lag*SWAY_K-_lag_v*SWAY_DAMP
			_lag_v += acc*delta
			_lag += _lag_v*delta
			_lag = _lag.limit_length(SWAY_MAX*s)
		else:
			_lag = Vector3.ZERO
			_lag_v = Vector3.ZERO
	_last_mid = mid
	var side := up.cross(back).normalized()
	var basis := Basis(side,up,back)
	# Swung by its lag: the bottom trails.
	var tilt := Vector3(_lag.dot(back),0.0,-_lag.dot(side))*deg_to_rad(SWAY_TILT)/maxf(s,0.01)
	basis = basis*Basis(Vector3.RIGHT,clampf(tilt.x,-0.5,0.5))*Basis(Vector3.BACK,clampf(tilt.z,-0.5,0.5))
	_sack.global_transform = Transform3D(basis*Basis.from_scale(Vector3(gulp,1.0/sqrt(gulp),gulp)),mid+_lag*0.5)
	# The straps: from the neck over each shoulder.
	var mouth := _sack.global_transform*Vector3(0.0,r*1.1,-r*depth*0.4)
	var sides := ["upper_arm.L","upper_arm.R"]
	for i in 2:
		var to := _bone_world(sides[i])
		if to == Vector3.INF:
			_straps[i].visible = false
			continue
		to += up*0.04*s
		_straps[i].visible = true
		var d := to-mouth
		var l := d.length()
		if l < 0.001: continue
		var y := d/l
		var x := y.cross(fwd).normalized() if absf(y.dot(fwd)) < 0.95 else y.cross(Vector3.RIGHT).normalized()
		_straps[i].global_transform = Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l,s)),(mouth+to)*0.5)

## The sack's cloth at belly radius `r` (times size; drawn at size 1, the
## sack node scaled) and `depth`: a bulging pouch, flat and creased when
## empty, taut when full, gathered at the neck under a tie, with darker
## patches sewn on (vertex colour).
func _shape(r: float, depth: float) -> void:
	_drawn = r
	var motor: Variant = study.get("motor")
	var s: float = motor.size if motor != null else 1.0
	var R := r*s
	var fill := clampf((r-SACK_R)/(radius_of(CAP)-SACK_R),0.0,1.0)
	var crease := lerpf(0.14,0.03,fill)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 16
	var cols := 24
	var grid: Array = []
	for j in range(rows+1):
		var row: Array = []
		var v := float(j)/rows
		for m in range(cols+1):
			var a := TAU*m/cols
			row.append(_sack_at(R,depth,a,v,crease))
		grid.append(row)
	for j in range(rows):
		for m in range(cols):
			var q: Array = [grid[j][m],grid[j][m+1],grid[j+1][m+1],grid[j+1][m]]
			var patch := (m in [4,5,6] and j in [4,5,6]) or (m in [16,17] and j in [8,9])
			var col := PATCH if patch else CLOTH.darkened(0.08*sin(m*1.7+j*0.9))
			for idx: int in [0,2,1,0,3,2]:
				var pv: Vector3 = q[idx]
				# Smooth: out from the belly's middle, the flat sides kept flat.
				st.set_color(col)
				st.set_normal(Vector3(pv.x,pv.y+R*0.2,pv.z/maxf(depth*depth,0.05)).normalized())
				st.add_vertex(pv)
	# The tuft above the tie: the cloth's frayed mouth.
	var top := Vector3(0.0,R*1.1,0.0)
	for m in range(cols):
		var a0 := TAU*m/cols
		var a1 := TAU*(m+1)/cols
		var w := 0.32*R
		var lift := R*(0.22+0.08*sin(m*2.3))
		var p0 := top+Vector3(cos(a0)*w*0.4,0.0,sin(a0)*w*0.4*depth)
		var p1 := top+Vector3(cos(a1)*w*0.4,0.0,sin(a1)*w*0.4*depth)
		var p2 := top+Vector3(cos((a0+a1)*0.5)*w,lift,sin((a0+a1)*0.5)*w*depth)
		for p: Vector3 in [p0,p1,p2]:
			st.set_color(CLOTH.darkened(0.15))
			st.set_normal((p-top).normalized())
			st.add_vertex(p)
	_cloth.mesh = st.commit()
	_knot.position = top+Vector3.DOWN*0.02*s
	_knot.scale = Vector3(0.11*R+0.02*s,0.05*s,0.11*R*depth+0.02*s)

## A point on the sack (radius R, `depth` of it front to back, local +z
## away from his back): round `a`, `v` of the way from its bottom (0) to
## its neck (1); the top half gathered in to the neck, creased by `crease`.
static func _sack_at(R: float, depth: float, a: float, v: float, crease: float) -> Vector3:
	var th := PI*minf(v,0.999)
	var rho := R*sin(th)
	if v > 0.45: rho *= lerpf(1.0,0.16,pow((v-0.45)/0.55,1.3))
	rho *= 1.0+crease*sin(a*5.0+v*7.0)*sin(PI*v)
	var y := R-R*cos(th)
	if v > 0.9: y += (v-0.9)*R*1.0
	# A little sag to the bottom: the load settles low and the cloth hangs.
	y -= R*0.12*sin(PI*v)*(1.0-v)
	return Vector3(cos(a)*rho,y-R,sin(a)*rho*depth)

## The putting in: he dips to it, it hops over his shoulder into the mouth.
func _stow_step(delta: float) -> void:
	if stowing.is_empty(): return
	_stow_t += delta
	var k := clampf(_stow_t/STOW_TIME,0.0,1.0)
	var node: Node3D = stowing.node
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var mouth := _sack.global_transform*Vector3(0.0,_r*s*1.1,0.0)
	var from := _stow_from.origin
	var arc := from.lerp(mouth,k)+Vector3.UP*STOW_HOP*s*sin(PI*k)
	node.global_transform = Transform3D(_stow_from.basis.scaled(Vector3.ONE*lerpf(1.0,0.35,k)),arc)
	var sk := _skeleton()
	if sk != null:
		var chest := sk.find_bone("chest")
		if chest >= 0: CarryHost._turn_bone(sk,chest,_forward().cross(Vector3.UP),-deg_to_rad(STOW_BEND)*sin(PI*k))
	if k >= 1.0:
		var p := stowing
		stowing = {}
		node.visible = false
		items.append(p)
		_gulp_t = 0.0
		_gulp_sound.pitch_scale = randf_range(1.1,1.3)
		_gulp_sound.play()
		_set_kg(kg+float(p.kg))

# --- Refusals ---------------------------------------------------------------------------

func _on_refused(what: String) -> void:
	if barred.is_empty(): return
	_balk(what)
	_say("Too heavy to %s (%s kg)" % [{"wall_kick":"wall-kick","ledge":"climb","sail":"sail","rope":"swing"}.get(what,what),_kg(kg)])

func _balk(what: String) -> void:
	balked = what
	balks += 1
	_balk_t = 0.0
	_balk_side = -_balk_side

## The balk on the figure after its clips: the chest lurched aside and back,
## the head shaken no; over carry_weights' BALK_TIME.
func _balk_pose(delta: float) -> void:
	if _balk_t < 0.0: return
	_balk_t += delta
	var k := _balk_t/Weights.BALK_TIME
	if k >= 1.0:
		_balk_t = -1.0
		return
	var sk := _skeleton()
	if sk == null: return
	var fwd := _forward()
	var lurch := sin(PI*minf(k*1.6,1.0))
	var chest := sk.find_bone("chest")
	if chest >= 0:
		CarryHost._turn_bone(sk,chest,fwd,deg_to_rad(Weights.BALK_LEAN)*0.6*lurch*_balk_side)
		CarryHost._turn_bone(sk,chest,fwd.cross(Vector3.UP),deg_to_rad(Weights.BALK_LEAN)*0.3*lurch)
	var head := sk.find_bone("head")
	if head >= 0:
		CarryHost._turn_bone(sk,head,Vector3.UP,sin(TAU*Weights.BALK_SHAKES*k)*(1.0-k)*deg_to_rad(Weights.BALK_HEAD))

## The low "uh-uh": two falling hums (made once).
static func _no_stream() -> AudioStreamWAV:
	if _no_take != null: return _no_take
	var rate := 22050
	var data := PackedByteArray()
	var n := int(rate*0.42)
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var note := 0 if t < 0.17 else (1 if t > 0.22 else -1)
		var v := 0.0
		if note >= 0:
			var t0 := t if note == 0 else t-0.22
			var len := 0.17 if note == 0 else 0.2
			var f := (210.0 if note == 0 else 165.0)*(1.0-0.08*t0/len)
			var env := sin(PI*clampf(t0/len,0.0,1.0))
			v = (sin(TAU*f*t0)+0.35*sin(TAU*2.0*f*t0))*env*0.4
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	_no_take = w
	return w

# --- On screen --------------------------------------------------------------------------

func _show_prompt() -> void:
	var motor: Variant = study.get("motor")
	var p := {} if not stowing.is_empty() or not motor.grounded else in_reach()
	if p.is_empty():
		_prompt.visible = false
		return
	var ok := fits(p)
	var m: Dictionary = p.measures
	_prompt.text = ("E  bag it  (%s kg)" % _kg(float(p.kg))) if ok else ("full  (%s kg won't fit)" % _kg(float(p.kg)))
	_prompt.modulate = Color(1,1,1) if ok else Color(1.0,0.6,0.5)
	_prompt.global_position = (p.node as Node3D).global_position+Vector3.UP*(float(m.height)+0.55)
	_prompt.visible = true

func _show_readout() -> void:
	var cells := 20
	var on := int(round(clampf(kg/CAP,0.0,1.0)*cells))
	var lines := PackedStringArray(["Bag  %s / %d kg" % [_kg(kg),int(CAP)],"[%s%s]" % ["#".repeat(on),"-".repeat(cells-on)]])
	var w := feel_of(kg)
	lines.append("pace %d%%  jump %d%%" % [int(round(float(w.run)*100.0)),int(round(float(w.jump)*100.0))])
	lines.append("no %s" % ", ".join(barred) if not barred.is_empty() else "every move")
	_readout.text = "\n".join(lines)

# --- The figure ---------------------------------------------------------------------------

func _forward() -> Vector3:
	var fig: Node3D = study.get("figure")
	if fig == null: return Vector3.FORWARD
	var f := -fig.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

func _skeleton() -> Skeleton3D:
	var body: Node = study.get("body")
	return null if body == null else body.get("_skeleton") as Skeleton3D

func _bone_world(bone_name: String) -> Vector3:
	var sk := _skeleton()
	if sk == null: return Vector3.INF
	var b := sk.find_bone(bone_name)
	return Vector3.INF if b < 0 else sk.global_transform*sk.get_bone_global_pose(b).origin
