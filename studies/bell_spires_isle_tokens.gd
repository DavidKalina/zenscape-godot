extends Node3D
## The bell spires isle's on-foot tokens: a copy of the aqueduct isle's
## (studies/aqueduct_isle_tokens.gd; an extraction candidate) with this
## isle's spots. A few of the sky's foot tokens (scripts/glyph_pickup.gd,
## calm) set where each asks for a move, not laid in a trail; the readout
## and its climbing blip are the sky's (scripts/collectibles_hud.gd).
## Only the pilot on foot takes them. Nothing is saved.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const Hud = preload("res://scripts/collectibles_hud.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Art = preload("res://studies/bell_spires_isle_art.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")

const GLYPH := "wildflower"
const SIZE := 0.7
const JUMP := 6.0

var tokens: Array[Dictionary] = []
var taken: Array[String] = []
var hud: CanvasLayer
var _holders := {}
var _last := Vector3.INF

## Where each token stands and the move it asks for, from the isle's own
## layout (`isle` the study, for its belfry).
static func spots(isle: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var l: Dictionary = Art.layout()
	var fh: Dictionary = l.spires.fin_high
	var fl: Dictionary = l.spires.fin_low
	# 1. Up the chimney between the fin's stacks: wall kicks.
	var mid: Vector2 = (fh.c as Vector2).lerp(fl.c,0.5)
	var along: Vector2 = l.chock.along
	var c := mid-along*1.2
	out.append({"name":"chimney","at":Vector3(c.x,Art.TOP+5.5,c.y),"move":"Wall-kick up the chimney between the fin's two stacks"})
	# 2. Over the drift from the low stack to the south stack, at the top
	# of the jump between its second and third stones.
	var d2: Dictionary = Art.platform("drift_2")
	var d3: Dictionary = Art.platform("drift_3")
	if not d2.is_empty() and not d3.is_empty():
		out.append({"name":"drift","at":(d2.at as Vector3).lerp(d3.at,0.5)+Vector3.UP*1.2,"move":"Hop the floating stones from the low stack to the south stack"})
	# 3. The middle of the high bridge, to the needle.
	var high: Dictionary = Art.bridge("needle")
	if not high.is_empty():
		out.append({"name":"high_bridge","at":(high.a as Vector3).lerp(high.b,0.5)+Vector3.UP*0.2,"move":"Cross the high bridge to the needle"})
	# 4. The needle turret's broken head, up its spiral.
	var needle: Dictionary = l.spires.needle
	out.append({"name":"turret","at":Vector3(needle.c.x,float(needle.top)+18*RuinKit.RISER+0.9,needle.c.y),"move":"Climb the needle's turret stair to its broken head"})
	# 5. Over the last floating stone from the turret to the summit.
	var n4: Dictionary = Art.platform("needle_4")
	if not n4.is_empty():
		out.append({"name":"needle_stones","at":(n4.at as Vector3)+Vector3.UP*0.85,"move":"Jump the floating stones from the turret's head to the summit"})
	# 6. The belfry's wall head, the isle's highest standing: up the corbels.
	var bel: Node3D = isle.get("belfry") if isle != null else null
	if bel != null:
		out.append({"name":"belfry_head","at":bel.global_transform*Vector3(-1.95,Belfry.HEAD+0.85,-1.95),"move":"Climb the corbels inside the belfry onto its wall head"})
	# 7. The fin's high top, up its stair from the chockstone.
	out.append({"name":"fin_top","at":Vector3(fh.c.x,float(fh.top)+1.2,fh.c.y),"move":"Climb from the chockstone round the fin's high stack"})
	return out

func setup(isle: Node3D) -> void:
	name = "Tokens"
	tokens = spots(isle)
	for i in range(tokens.size()):
		var t: Dictionary = tokens[i]
		var holder := GlyphPickup.make(GLYPH,SIZE,float(i)*1.3,true)
		holder.name = "Token_%s" % t.name
		holder.position = t.at
		add_child(holder)
		holder.motes_on(true)
		_holders[t.name] = holder
	hud = Hud.new()
	add_child(hud)

func left() -> int:
	return tokens.size()-taken.size()

func glow_for(night: float) -> void:
	for holder: Node3D in _holders.values():
		if is_instance_valid(holder) and not holder.taking: holder.glow_for(night)

## The pilot's middle this frame (on foot): every token within his reach of
## the way he moved since the last is taken. INF (flying) forgets the last.
func touch(point: Vector3) -> void:
	if point == Vector3.INF:
		_last = Vector3.INF
		return
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= JUMP else point
	_last = point
	for t: Dictionary in tokens:
		if taken.has(t.name): continue
		var at: Vector3 = t.at
		var near := Geometry3D.get_closest_point_to_segment(at,from,point)
		if near.distance_to(at) < Lines.WALKER_REACH+SIZE*0.5: take(t.name)

func take(name: String) -> void:
	if taken.has(name) or not _holders.has(name): return
	taken.append(name)
	var holder: Node3D = _holders[name]
	if is_instance_valid(holder): holder.take(hash(name) & 0xffff)
	_holders.erase(name)
	if hud != null: hud.show_pickup(GLYPH,taken.size(),taken.size(),tokens.size())
