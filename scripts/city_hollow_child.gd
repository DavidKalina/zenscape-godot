extends Node3D
## The Hollow Child (card x5-hollow): an Olmec hollow "were-baby", a seated
## figure of
## white-slipped fired clay the size of a crouched wanderer, that drinks
## nearby light. "It is fed on the light of whoever sits with it. When it is
## full, it cries."
##
## The rule, on the real sight and beacon code:
##   - It carries a LightDrinker (scripts/enemies/light_drinker.gd) of
##     `reach` m. While it drinks, LightLevel reads every flame there as
##     drunk: the wanderer beside it reads as the ambient only to the
##     Olmec's sight, torch lit or not, and a cresset or lamp whose flame
##     stands there lights nothing and draws no Olmec (beacon.gd skips a
##     drunk flame).
##   - It fills from what it drinks, faster the more: the torch alone in
##     `torch_fill` s, a cresset (a SightLight of strength 1) in `flame_fill`
##     s, together faster. Nothing near, it leaks back to empty in `leak` s.
##   - Full, it draws a breath (`breath` s: a hiss, its eyes and mouth glow),
##     then cries: a rising clay-whistle wail, and all the light comes out of
##     it at once as a Beacon (`cry_radius` m of light at full strength, pull
##     `cry_pull`, drawing every Olmec within `cry_draw` m) for `cry` s. It
##     drinks nothing while it cries: whoever sits with it stands in the
##     brightest place on the layer.
##   - Spent, it goes cold and quiet for `spent` s (flames near it burn
##     normally), then drinks again from empty.
## What empties it: the cry (it pours everything out), or leaving it unfed
## (it leaks back to empty in `leak` s).
##
## The tell, readable from the high camera: every flame in its reach leans
## toward its mouth (the torch gutters too), motes of light stream from each
## flame into its mouth, the glow inside climbs the clay from its feet to its
## eyes, its head turns slowly to the nearest flame, and a low clay-whistle
## hum rises in pitch and loudness as it fills; the breath's hiss gives 2 s.
##
## Its states (`state`): "empty", "drinking", "breath", "cry", "spent".
## Signals: `state_changed(state)`, `cried`.
## `knobs` (KNOBS) before it enters the tree; a study passes
## `--hollow-knob=<k>=<v>`.

signal state_changed(state: String)
signal cried

const ChildMesh = preload("res://scripts/city_hollow_child_mesh.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const CityFire = preload("res://scripts/city_fire.gd")
const Flame = preload("res://scripts/flame.gd")
const CLAY_SHADER := preload("res://shaders/hollow_child_clay.gdshader")

const KNOBS := {
	"reach":6.0,          # m it drinks within (at the wanderer's size 1)
	"torch_fill":25.0,    # s to fill on the torch alone
	"flame_fill":8.0,     # s to fill on a cresset's flame (strength 1)
	"leak":60.0,          # s to leak from full to empty, unfed
	"breath":2.0,         # s of the breath before the cry
	"cry":20.0,           # s it burns as a beacon
	"spent":60.0,         # s cold after
	"cry_radius":12.0,    # m its light reaches, crying
	"cry_pull":2.0,       # its beacon's pull against others
	"cry_draw":160.0,     # m off it draws an Olmec (the layer's scale)
	"lean":2.2,           # how hard flames lean to it (Flame.wind)
}
## The figure drawn this times its clay's metres, times the wanderer's size:
## a crouched wanderer's height (about 1.05 m).
const SCALE := 0.82
## Where it drinks from and the light pours out (its belly), and its mouth,
## in its own space (before SCALE).
const HEART := Vector3(0.0,0.55,0.05)
const MOUTH := Vector3(0.0,0.89,0.26)
## The head turns to a flame this fast (rad/s), at most this far (rad).
const HEAD_TURN := 0.35
const HEAD_MOST := 0.6
## Motes in flight at most.
const MOTES := 40

var knobs := KNOBS.duplicate()
var state := "empty"
var state_t := 0.0
## 0 empty .. 1 full.
var fill := 0.0
## What it drinks now (fill per s), and from how many flames.
var feeding := 0.0
var flames := 0
## Counted, for checks and the HUD.
var cries := 0
var drinker: LightDrinker
var beacon: Beacon

var _scale := 1.0
var _body: MeshInstance3D
var _head_pivot: Node3D
var _head: MeshInstance3D
var _mat: ShaderMaterial
var _head_mat: ShaderMaterial
var _inner: OmniLight3D
var _hum: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _wail: AudioStreamPlayer3D
var _clock := 0.0
var _yaw := 0.0
var _tilt := 0.0
## Flames it leans: Flame -> true (put back upright when it lets go).
var _leaned := {}
var _torch_gutter := false
var _motes: Array = []
var _mote_mat: StandardMaterial3D
var _mote_acc := {}
var _rng := RandomNumberGenerator.new()

static var _sounds := {}

## Its knobs from a study's flags (`--hollow-knob=<k>=<v>`, repeatable).
static func knobs_from(args: PackedStringArray) -> Dictionary:
	var k := {}
	for a: String in args:
		if a.begins_with("--hollow-knob="):
			var kv := a.trim_prefix("--hollow-knob=")
			k[kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	return k

func _ready() -> void:
	_rng.seed = hash(global_position)
	_scale = SCALE*Fires.size()
	var fig := Node3D.new()
	fig.name = "Figure"
	fig.scale = Vector3.ONE*_scale
	add_child(fig)
	var meshes := ChildMesh.meshes()
	_mat = ShaderMaterial.new()
	_mat.shader = CLAY_SHADER
	_mat.set_shader_parameter("eyes",1.02/ChildMesh.TALL)
	_head_mat = _mat.duplicate() as ShaderMaterial
	_head_mat.set_shader_parameter("obj_offset",ChildMesh.NECK)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = meshes[0]
	_body.material_override = _mat
	fig.add_child(_body)
	_head_pivot = Node3D.new()
	_head_pivot.name = "Neck"
	_head_pivot.position = ChildMesh.NECK
	fig.add_child(_head_pivot)
	_head = MeshInstance3D.new()
	_head.name = "Head"
	_head.mesh = meshes[1]
	_head.material_override = _head_mat
	_head_pivot.add_child(_head)
	_build_solid()
	drinker = LightDrinker.new()
	drinker.name = "Drinker"
	drinker.radius = float(knobs.reach)*Fires.size()
	drinker.position = HEART*_scale
	add_child(drinker)
	beacon = Beacon.new()
	beacon.name = "Cry"
	beacon.radius = float(knobs.cry_radius)
	beacon.strength = 1.0
	beacon.pull = float(knobs.cry_pull)
	beacon.draw = float(knobs.cry_draw)
	beacon.dwell = 8.0
	beacon.position = MOUTH*_scale
	add_child(beacon)
	beacon.lit = false
	# The light inside: dim and warm as it fills, the cry's blaze.
	_inner = OmniLight3D.new()
	_inner.name = "Inner"
	_inner.light_color = Color(1.0,0.58,0.28)
	_inner.light_energy = 0.0
	_inner.omni_range = 3.0
	_inner.omni_attenuation = 1.4
	_inner.shadow_enabled = false
	_inner.position = Vector3(0.0,0.75,0.45)*_scale
	_inner.visible = false
	add_child(_inner)
	_build_sounds()
	_build_motes()

## Its solid: the seated body and the head, plain shapes (a stone he
## stands by, or on).
func _build_solid() -> void:
	var b := StaticBody3D.new()
	b.name = "Solid"
	var c := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5*_scale
	cyl.height = 0.82*_scale
	c.shape = cyl
	c.position = Vector3(0.0,0.41*_scale,0.05*_scale)
	b.add_child(c)
	var h := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.3*_scale
	h.shape = sp
	h.position = Vector3(0.0,1.0*_scale,0.0)
	b.add_child(h)
	add_child(b)

# --- At play ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dt := clampf(delta,0.0,0.1)
	_clock += dt
	state_t += dt
	var feeds := _feeds()
	feeding = 0.0
	flames = feeds.size()
	for f: Dictionary in feeds: feeding += float(f.rate)
	match state:
		"empty","drinking":
			drinker.drinking = true
			if feeding > 0.0:
				fill = minf(fill+feeding*dt,1.0)
				if state != "drinking": _go("drinking")
			else:
				fill = maxf(fill-dt/float(knobs.leak),0.0)
				if fill <= 0.0 and state != "empty": _go("empty")
			if fill >= 1.0: _go("breath")
		"breath":
			drinker.drinking = true
			fill = 1.0
			if state_t >= float(knobs.breath): _cry()
		"cry":
			drinker.drinking = false
			if state_t >= float(knobs.cry):
				beacon.douse()
				fill = 0.0
				_go("spent")
		"spent":
			drinker.drinking = false
			fill = 0.0
			if state_t >= float(knobs.spent): _go("empty")
	_lean(feeds if drinker.drinking else [],dt)
	_turn_head(feeds,dt)
	_motes_step(feeds if drinker.drinking else [],dt)
	_show(dt)
	_sound(dt)

func _go(to: String) -> void:
	if to == state: return
	state = to
	state_t = 0.0
	if to == "breath" and _hiss != null: _hiss.play()
	state_changed.emit(to)

func _cry() -> void:
	cries += 1
	beacon.light()
	_go("cry")
	if _wail != null: _wail.play()
	cried.emit()

## The flames it drinks now: [{at (world), rate (fill per s), flame (a
## Flame to lean, or null), torch}].
func _feeds() -> Array:
	var out: Array = []
	if not drinker.drinking and state != "empty" and state != "drinking": return out
	var tree := get_tree()
	var share := 0.0
	# His torch, lit, in its reach.
	if Fires.torch_lit(tree):
		var tp := Fires.torch_point(tree)
		if tp != Vector3.INF:
			share = _reach_share(tp)
			if share > 0.0:
				var strength := LightLevel.torch_strength/LightLevel.TORCH if LightLevel.torch_strength > 0.0 else 1.0
				var u := Fires.look(tree)
				out.append({"at":tp,"rate":share*strength/float(knobs.torch_fill),"flame":u.get("flame") if u != null else null,"torch":true,"share":share})
	# Every lit sight light (a cresset, a lamp, another's beacon) whose flame
	# stands in its reach.
	for n in tree.get_nodes_in_group(SightLight.GROUP):
		var l := n as SightLight
		if l == null or l == beacon or not l.lit or l.strength <= 0.0 or not l.is_inside_tree(): continue
		share = _reach_share(l.global_position)
		if share <= 0.0: continue
		var fl: Variant = null
		var host := l.get_parent()
		if host != null:
			var fire: Variant = host.get("fire")
			if fire is CityFire: fl = (fire as CityFire).real
		out.append({"at":l.global_position,"rate":share*l.strength/float(knobs.flame_fill),"flame":fl,"torch":false,"share":share})
	return out

## How much of a flame at `p` it reaches (its drinker's falloff, as drinking).
func _reach_share(p: Vector3) -> float:
	var was := drinker.drinking
	drinker.drinking = true
	var s := drinker.drink_at(p)
	drinker.drinking = was
	return s

## Every flame it drinks leans to its mouth (in the flame's own frame), the
## torch guttering a little; the rest let go upright.
func _lean(feeds: Array, _dt: float) -> void:
	var mouth := to_global(MOUTH*_scale)
	var now := {}
	for f: Dictionary in feeds:
		var fl: Variant = f.flame
		if not (fl is Flame) or not is_instance_valid(fl): continue
		var flame := fl as Flame
		var to := mouth-flame.global_position
		var local := flame.global_transform.basis.inverse()*to
		var flat := Vector2(local.x,local.z)
		if flat.length() < 0.05: continue
		var k := float(f.share)*float(knobs.lean)
		flame.wind = flat.normalized()*k*(0.9+0.1*sin(_clock*7.0+float(flame.get_instance_id()%13)))
		if bool(f.torch):
			flame.burn = lerpf(1.0,0.72,float(f.share))
			_torch_gutter = true
		now[flame] = true
	for fl: Variant in _leaned.keys():
		if now.has(fl): continue
		if is_instance_valid(fl):
			(fl as Flame).wind = Vector2.ZERO
			if _torch_gutter and Fires.look(get_tree()) != null and Fires.look(get_tree()).get("flame") == fl:
				(fl as Flame).burn = 1.0
				_torch_gutter = false
	_leaned = now

## The head turns, very slowly, toward the nearest flame (drinking or not);
## at the breath it tips back, at the cry it lifts its face.
func _turn_head(feeds: Array, dt: float) -> void:
	var want_yaw := 0.0
	var best := INF
	var tree := get_tree()
	var cands: Array = []
	for f: Dictionary in feeds: cands.append(f.at)
	if cands.is_empty() and Fires.torch_lit(tree):
		var tp := Fires.torch_point(tree)
		if tp != Vector3.INF and tp.distance_to(global_position) < drinker.radius*2.5: cands.append(tp)
	for at: Vector3 in cands:
		var d := at.distance_to(global_position)
		if d < best:
			best = d
			var l := to_local(at)
			want_yaw = clampf(atan2(l.x,l.z),-HEAD_MOST,HEAD_MOST)
	_yaw = move_toward(_yaw,want_yaw,HEAD_TURN*dt)
	var want_tilt := 0.0
	if state == "breath": want_tilt = -0.18*clampf(state_t/float(knobs.breath),0.0,1.0)
	elif state == "cry": want_tilt = -0.32 if state_t < float(knobs.cry)-1.5 else 0.0
	_tilt = move_toward(_tilt,want_tilt,(1.2 if state == "cry" and state_t < 0.4 else 0.4)*dt)
	_head_pivot.rotation = Vector3(_tilt,_yaw,0.0)

## The clay's glow, the light inside, the breath's swell.
func _show(dt: float) -> void:
	var breath := clampf(state_t/float(knobs.breath),0.0,1.0) if state == "breath" else 0.0
	var blaze := 0.0
	if state == "cry":
		var c := float(knobs.cry)
		# It bursts out, holds, and fades over its last seconds.
		blaze = smoothstep(0.0,0.35,state_t)*(1.0-smoothstep(c-3.0,c,state_t))
	for m: ShaderMaterial in [_mat,_head_mat]:
		m.set_shader_parameter("fill",fill if state != "spent" else 0.0)
		m.set_shader_parameter("breath",breath)
		m.set_shader_parameter("blaze",blaze)
		m.set_shader_parameter("clock",_clock)
	# The inner light: never bright while it fills; the cry lights all round.
	var e := 0.0
	var r := 3.0
	if state in ["drinking","empty"]:
		e = fill*1.1
		r = 2.0+fill*2.5
	elif state == "breath":
		e = 1.1+breath*1.2
		r = 4.5+breath*1.5
	elif state == "cry":
		e = 1.1+blaze*9.0
		r = lerpf(4.5,float(knobs.cry_radius)*1.4,blaze)
	_inner.visible = e > 0.01
	_inner.light_energy = e*(0.9+0.1*sin(_clock*2.3))
	_inner.omni_range = r
	# The breath: the body swells a touch, then lets go with the cry.
	var swell := 1.0+0.035*breath
	if state == "cry": swell = 1.0+0.035*maxf(0.0,1.0-state_t/0.25)
	(_body.get_parent() as Node3D).scale = Vector3(_scale*(1.0+(swell-1.0)*0.6),_scale*swell,_scale*(1.0+(swell-1.0)*0.6))
	if dt <= 0.0: return

# --- Motes: the light pulled into its mouth -------------------------------------------------

func _build_motes() -> void:
	_mote_mat = StandardMaterial3D.new()
	_mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mote_mat.vertex_color_use_as_albedo = true
	_mote_mat.albedo_color = Color(1.0,0.62,0.3)
	_mote_mat.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(0.26,0.26)
	var img := Image.create(32,32,false,Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x-15.5,y-15.5).length()/15.5
			var a := clampf(1.0-d,0.0,1.0)
			img.set_pixel(x,y,Color(1,1,1,a*a))
	_mote_mat.albedo_texture = ImageTexture.create_from_image(img)
	q.material = _mote_mat
	for i in MOTES:
		var m := MeshInstance3D.new()
		m.name = "Mote%d" % i
		m.mesh = q
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.top_level = true
		m.visible = false
		add_child(m)
		_motes.append({"node":m,"t":-1.0,"from":Vector3.ZERO,"bend":Vector3.ZERO,"life":1.0})

## Motes stream from each flame it drinks into its mouth (more the more it
## drinks), curving up and in, shrinking as they go.
func _motes_step(feeds: Array, dt: float) -> void:
	var mouth := to_global(MOUTH*_scale)
	for f: Dictionary in feeds:
		var key := str(f.at.snapped(Vector3.ONE*0.5)) if not bool(f.torch) else "torch"
		var acc := float(_mote_acc.get(key,0.0))+dt*(10.0+14.0*float(f.share))
		while acc >= 1.0:
			acc -= 1.0
			for m: Dictionary in _motes:
				if float(m.t) >= 0.0: continue
				var from: Vector3 = f.at+Vector3(_rng.randf_range(-0.12,0.12),_rng.randf_range(0.0,0.25),_rng.randf_range(-0.12,0.12))
				m.t = 0.0
				m.from = from
				m.bend = (from+mouth)*0.5+Vector3(_rng.randf_range(-0.5,0.5),_rng.randf_range(0.4,1.1),_rng.randf_range(-0.5,0.5))
				m.life = clampf(from.distance_to(mouth)/4.0,0.5,1.4)
				(m.node as MeshInstance3D).visible = true
				break
		_mote_acc[key] = acc
	for m: Dictionary in _motes:
		if float(m.t) < 0.0: continue
		m.t = float(m.t)+dt/float(m.life)
		var node := m.node as MeshInstance3D
		if float(m.t) >= 1.0:
			m.t = -1.0
			node.visible = false
			continue
		var u := float(m.t)
		var e := u*u
		var a: Vector3 = (m.from as Vector3).lerp(m.bend,e)
		var b: Vector3 = (m.bend as Vector3).lerp(mouth,e)
		node.global_position = a.lerp(b,e)
		var s := lerpf(1.0,0.35,u)*(0.6+0.6*sin(u*PI))
		node.scale = Vector3.ONE*s

# --- Sound ----------------------------------------------------------------------------------

func _build_sounds() -> void:
	if _sounds.is_empty():
		_sounds["hum"] = _synth_hum()
		_sounds["hiss"] = _synth_hiss()
		_sounds["wail"] = _synth_wail()
	_hum = _player("Hum",_sounds.hum,8.0)
	_hum.volume_db = -60.0
	_hiss = _player("Hiss",_sounds.hiss,10.0)
	_wail = _player("Wail",_sounds.wail,40.0)
	_wail.max_distance = 200.0

func _player(n: String, stream: AudioStream, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.stream = stream
	p.unit_size = unit
	p.position = MOUTH*_scale
	add_child(p)
	return p

## The hum rises with the fill: pitch and loudness; quiet when spent.
func _sound(_dt: float) -> void:
	var on := state in ["drinking","breath"] or (state == "empty" and fill > 0.0)
	if on and not _hum.playing: _hum.play()
	elif not on and _hum.playing: _hum.stop()
	if on:
		_hum.pitch_scale = lerpf(0.55,1.35,fill)
		_hum.volume_db = lerpf(-30.0,-4.0,fill)+(4.0 if feeding > 0.0 else -6.0)

const RATE := 22050

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size()*2)
	for i in samples.size(): data.encode_s16(i*2,int(clampf(samples[i],-1.0,1.0)*32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

## A clay whistle's breathy tone, looped (2 s; whole cycles of its notes so
## the loop has no click): a low note, its fifth soft, a breath of noise,
## a slow tremble.
static func _synth_hum() -> AudioStreamWAV:
	var n := RATE*2
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var low := 0.0
	for i in n:
		var t := float(i)/RATE
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.08)
		var trem := 0.8+0.2*sin(TAU*1.5*t)
		s[i] = (sin(TAU*220.0*t)*0.55+sin(TAU*330.0*t)*0.12+sin(TAU*440.0*t)*0.06+low*0.25)*trem*0.5
	return _wav(s,true)

## The breath: a long hiss drawn in, rising.
static func _synth_hiss() -> AudioStreamWAV:
	var n := int(RATE*2.1)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var low := 0.0
	for i in n:
		var t := float(i)/RATE
		var k := t/2.1
		var white := rng.randf_range(-1.0,1.0)
		low = lerpf(low,white,0.3)
		var env := pow(k,1.6)*(1.0-smoothstep(0.93,1.0,k))
		s[i] = (white-low*0.6)*env*0.55
	return _wav(s)

## The cry: a clay-whistle wail sliding up and sobbing, long, loud.
static func _synth_wail() -> AudioStreamWAV:
	var dur := 4.5
	var n := int(RATE*dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var phase := 0.0
	var low := 0.0
	for i in n:
		var t := float(i)/RATE
		var k := t/dur
		var f := lerpf(260.0,760.0,smoothstep(0.0,0.18,k))-lerpf(0.0,180.0,smoothstep(0.6,1.0,k))
		f *= 1.0+0.025*sin(TAU*5.5*t)
		phase += f/RATE
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.15)
		var sob := 0.75+0.25*sin(TAU*1.6*t)
		var env := smoothstep(0.0,0.04,k)*(1.0-smoothstep(0.75,1.0,k))*sob
		var tone := sin(TAU*phase)*0.7+sin(TAU*phase*2.0)*0.12+sin(TAU*phase*3.0)*0.05
		s[i] = (tone+low*0.2)*env*0.85
	return _wav(s)

# --- For checks and the HUD -------------------------------------------------------------------

## Where the light pours from (world).
func mouth() -> Vector3:
	return to_global(MOUTH*_scale)

## Back to empty and cold, its cry out.
func reset() -> void:
	fill = 0.0
	if beacon != null: beacon.douse()
	_go("empty")

func describe() -> String:
	var left := ""
	match state:
		"breath": left = " (cries in %.1fs)" % maxf(float(knobs.breath)-state_t,0.0)
		"cry": left = " (%.0fs left)" % maxf(float(knobs.cry)-state_t,0.0)
		"spent": left = " (cold %.0fs more)" % maxf(float(knobs.spent)-state_t,0.0)
	return "hollow child %s%s · fill %.0f%% · drinking %d flame%s (%.3f/s) · cries %d" % [state,left,fill*100.0,flames,"" if flames == 1 else "s",feeding,cries]
