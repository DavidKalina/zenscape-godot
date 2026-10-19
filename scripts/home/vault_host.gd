extends Node3D
## The home vault's banking (docs/design/home/spec-home.md), in the wreck
## cluster study with --home. The vault, its board and the deposit pad are
## pieces on the home isle (studies/wreck_cluster_home.gd `vault`, `pad`,
## world-view names `home/vault`, `home/deposit_pad`); this host finds them
## where they stand and banks into them:
##
## - the plane stopped on the pad (on its wheels, stood still, or parked
##   there after Exit) with treasures in its bag: they come out one by one,
##   the last loaded first, BEAT s apart, each lifted out of the bag, swung
##   across into the vault onto the next free spot on its floor, a chime as
##   it is set down, its value added to the tally;
## - carried by hand into the vault (his feet inside its walls), the
##   treasure leaves his hands the same way, onto the floor and the tally;
## - the brood's riders on the bag are worth nothing (their kg is not a
##   treasure); they ride on till something sheds them.
##
## The tally: the total and the count of each kind, kept in the ledger
## (scripts/ledger/ledger.gd `vault`, `bank`) so it lasts across runs, and
## shown on the board; a deposit flashes what it added (a rising label at
## the vault, a pulse of the board, a pop on the screen). Banked ones stand
## on the vault's floor (the last SHOW_MAX of them; a load rebuilds them
## from the ledger's list). A banked one is out of the cluster's deal till
## N, which stands a fresh one on its spot; the vault keeps its own.

## What each kind is worth: the one table.
const VALUES := {"idol":40,"urn":60,"egg":150,"chalice":30}
const NAMES := {"idol":"idol","urn":"urn","egg":"dragon egg","chalice":"chalice"}
## Seconds between treasures out of the bag; the swing's lift (its first
## part), its whole length, and the top of its arc over the straight line.
const BEAT := 0.9
const LIFT := 0.3
const SWING := 0.95
const ARC := 2.2
## The floor's spots for banked ones (vault-local x, z; on the slabs).
const SPOTS := [Vector2(-1.5,1.6),Vector2(-0.5,1.6),Vector2(0.5,1.6),Vector2(1.5,1.6),
	Vector2(-1.5,0.4),Vector2(-0.5,0.4),Vector2(0.5,0.4),Vector2(1.5,0.4)]
const FLOOR_UP := 0.22
## How many banked ones stand on display (two layers); the oldest give way.
const SHOW_MAX := 16
const Ledger = preload("res://scripts/ledger/ledger.gd")
const Models = preload("res://scripts/carry/treasure_models.gd")
const Home = preload("res://studies/wreck_cluster_home.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const GenesisAudio = preload("res://scripts/genesis_audio.gd")

var study: Node3D = null
var vault: Node3D = null
var pad: Node3D = null
var _board: Label3D = null
var _slab: MeshInstance3D = null
## The banked total, the count of each kind, and deposits so far (drivers).
var total := 0
var counts := {"idol":0,"urn":0,"egg":0,"chalice":0}
var deposits := 0
var by_hand := 0
## Whether the plane stands on the pad now (drivers).
var on_pad := false
var _beat_t := 0.0
## Treasures on their way into the vault: {t, node, from, k, spot}.
var _moving: Array = []
## Display spot index -> the node standing there; the next one's number
## (counted over every banked one, the ledger's list's length).
var _at_spot := {}
var _next := 0
var _chime: AudioStreamPlayer = null
var _flash_t := 99.0
static var _chime_take: AudioStreamWAV = null

func setup(host: Node3D) -> void:
	study = host
	name = "Vault"
	process_priority = 110
	vault = _placed("home/vault")
	pad = _placed("home/deposit_pad")
	if vault != null:
		_board = vault.get_node_or_null("Board/Text")
		_slab = vault.get_node_or_null("Board/Slab")
	_chime = AudioStreamPlayer.new()
	_chime.name = "Chime"
	_chime.bus = GenesisAudio.BUS
	_chime.stream = _chime_stream()
	add_child(_chime)
	_from_ledger()
	_show_board()

## The tally and the display as the ledger keeps them.
func _from_ledger() -> void:
	var kept: Dictionary = Ledger.shared().vault
	total = int(kept.total)
	for kind: String in counts.keys(): counts[kind] = int((kept.counts as Dictionary).get(kind,0))
	var banked: Array = kept.banked
	_next = banked.size()
	if vault == null: return
	for n in range(maxi(0,_next-SHOW_MAX),_next):
		var node := Node3D.new()
		node.name = "Banked_%d" % n
		node.add_child(Models.build(str(banked[n])).node as Node3D)
		_stand(node,n%SHOW_MAX)

static func _placed(called: String) -> Node3D:
	var e: Dictionary = LayoutOverrides.entries.get(called,{})
	var n: Variant = e.get("node")
	return n if n != null and is_instance_valid(n) else null

func _carry() -> Variant:
	return study.get("carry") if study != null else null

func _process(delta: float) -> void:
	if study == null or vault == null or not bool(study.get("walk_ready")): return
	var carry: Variant = _carry()
	if carry == null: return
	_flash_t += delta
	_pulse()
	on_pad = _plane_on_pad()
	_beat_t += delta
	if on_pad and _beat_t >= BEAT and carry.sling != null:
		var t: Dictionary = carry.take_from_bag()
		if not t.is_empty():
			_beat_t = 0.0
			_start(t)
	_hand_in(carry)
	for m: Dictionary in _moving.duplicate(): _swing(m,delta)

## The plane at rest with its middle over the pad: stood still on its
## wheels with him in it, or parked there.
func _plane_on_pad() -> bool:
	if pad == null: return false
	var at := Vector3.INF
	if bool(study.get("flying")):
		var hl: Variant = study.get("hand_landing")
		if hl == null or not (hl.can_exit() or int(hl.phase) == 3): return false
		at = study.get("plane").position
	elif bool(study.get("parked")):
		at = study.get("parked_at")
	else: return false
	var local := pad.global_transform.affine_inverse()*at
	return absf(local.x) < Home.PAD_HALF.x+Home.PAD_SLACK and absf(local.z) < Home.PAD_HALF.y+Home.PAD_SLACK and absf(local.y) < 3.0

## Carried in through the door: out of his hands onto the floor.
func _hand_in(carry: Variant) -> void:
	if (carry.held as Dictionary).is_empty() or str(carry.phase) != "carry": return
	var motor: Variant = study.get("motor")
	if motor == null: return
	var local := vault.global_transform.affine_inverse()*(motor.feet as Vector3)
	if absf(local.x) > Home.INSIDE.x or absf(local.z) > Home.INSIDE.y or absf(local.y) > 1.5: return
	var t: Dictionary = carry.give_up()
	if t.is_empty(): return
	by_hand += 1
	_start(t)

## `t` on its way from where it is now to the next free spot.
func _start(t: Dictionary) -> void:
	t.banked = true
	var node: Node3D = t.node
	var from := node.global_transform
	var spot := _next%SHOW_MAX
	_next += 1
	_moving.append({"t":t,"node":node,"from":from,"k":0.0,"spot":spot})
	if OS.is_debug_build(): print("vault: %s on its way in (spot %d)" % [t.id,spot])

## `node` stood on display spot `i` (under Show), the one there before it
## gone.
func _stand(node: Node3D, i: int) -> void:
	var old: Variant = _at_spot.get(i)
	if old != null and is_instance_valid(old) and old != node: (old as Node).queue_free()
	_at_spot[i] = node
	var show := vault.get_node("Show")
	if node.get_parent() != show:
		if node.get_parent() != null: node.get_parent().remove_child(node)
		show.add_child(node)
	node.global_transform = _spot_xform(i)

## Spot `i` in the world: on the floor rows, a second layer past them.
func _spot_xform(i: int) -> Transform3D:
	var p: Vector2 = SPOTS[i%SPOTS.size()]
	var up := FLOOR_UP+0.9*float(i/SPOTS.size())
	var turn := Basis(Vector3.UP,PI+0.35*sin(float(i)*2.3))
	return vault.global_transform*Transform3D(turn,Vector3(p.x,up,p.y))

## One frame of a treasure's swing: up out of where it was, across in an
## arc, set down on its spot with a chime and the tally.
func _swing(m: Dictionary, delta: float) -> void:
	var t: Dictionary = m.t
	var node: Node3D = m.node
	if not is_instance_valid(node):
		_moving.erase(m)
		return
	m.k = float(m.k)+delta/SWING
	var k := clampf(float(m.k),0.0,1.0)
	var from: Transform3D = m.from
	var to := _spot_xform(int(m.spot))
	var lifted := from.origin+Vector3.UP*1.2
	var p: Vector3
	var lift_k := LIFT/SWING
	if k < lift_k:
		var e := _ease(k/lift_k)
		p = from.origin.lerp(lifted,e)
	else:
		var e := _ease((k-lift_k)/(1.0-lift_k))
		p = lifted.lerp(to.origin,e)+Vector3.UP*ARC*sin(e*PI)
	var b := from.basis.orthonormalized().slerp(to.basis.orthonormalized(),_ease(k))
	# A squash as it lands.
	var land := clampf((float(m.k)-0.92)/0.08,0.0,1.0)
	b = b.scaled(Vector3(1.0+0.12*sin(land*PI),1.0-0.18*sin(land*PI),1.0+0.12*sin(land*PI)))
	node.global_transform = Transform3D(b,p)
	if float(m.k) >= 1.0:
		_stand(node,int(m.spot))
		_moving.erase(m)
		_bank(t)

func _bank(t: Dictionary) -> void:
	var kind := str(t.kind)
	var worth := int(VALUES.get(kind,0))
	Ledger.shared().bank(kind,worth)
	total += worth
	counts[kind] = int(counts.get(kind,0))+1
	deposits += 1
	_chime.pitch_scale = 1.0+0.06*float(deposits%4)
	_chime.play()
	_show_board()
	_flash_t = 0.0
	_rise("+%d  %s" % [worth,NAMES.get(kind,kind)])
	var moments: Variant = study.get("_moments")
	if moments != null: moments.pop("Banked %s  +%d   ·   total %d" % [NAMES.get(kind,kind),worth,total],2.2)
	print("vault: banked %s +%d (total %d)" % [t.id,worth,total])

## The board's text: the total, then the count of each kind.
func _show_board() -> void:
	if _board == null: return
	var c := counts
	_board.text = "THE VAULT\n%d\n%s x%d    %s x%d\n%s x%d    %s x%d" % [total,
		NAMES.idol,int(c.idol),NAMES.urn,int(c.urn),NAMES.egg,int(c.egg),NAMES.chalice,int(c.chalice)]

## The board glows a moment after a deposit.
func _pulse() -> void:
	if _board == null: return
	var k := clampf(1.0-_flash_t/0.8,0.0,1.0)
	_board.modulate = Color("f2e6c4").lerp(Color(1.0,0.86,0.35),k)
	_board.scale = Vector3.ONE*(1.0+0.06*k)

## A label rising off the vault and fading.
func _rise(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 72
	l.pixel_size = 0.008
	l.outline_size = 12
	l.modulate = Color(1.0,0.88,0.4)
	add_child(l)
	var from := vault.global_transform*Vector3(0.0,3.4,0.0)
	l.global_position = from
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l,"global_position",from+Vector3.UP*2.2,1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l,"modulate:a",0.0,1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(l.queue_free)

static func _ease(t: float) -> float:
	t = clampf(t,0.0,1.0)
	return t*t*(3.0-2.0*t)

## A bright two-note chime (made once).
static func _chime_stream() -> AudioStreamWAV:
	if _chime_take != null: return _chime_take
	var rate := 22050
	var n := int(rate*0.7)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in range(n):
		var t := float(i)/rate
		var a := sin(TAU*880.0*t)*exp(-t*6.0)
		var b := sin(TAU*1320.0*t)*exp(-maxf(t-0.09,0.0)*5.0)*(1.0 if t > 0.09 else 0.0)
		var c := sin(TAU*2640.0*t)*exp(-t*14.0)*0.3
		var env := minf(t/0.003,1.0)
		var v := clampf((a*0.45+b*0.4+c)*env*0.8,-1.0,1.0)
		data.encode_s16(i*2,int(v*32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_chime_take = wav
	return wav
