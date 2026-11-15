extends RefCounted
## The odd balloon out (scripts/endless/endless_balloons.gd; docs/design/
## balloons/handoff-reveal-balloon.md): fixed groups of balloons that hold a
## find. Each SITES entry is a group of four always at that place on seed 1
## (the finds' seed): three in one matched cloth and one in gold, bigger, and
## lit from inside after dark. Bouncing the plane off the gold one lets its
## find out: the finds table's relic row anchored at "balloon/<name>" gets
## its place then (Finds `anchor`), a ring standing off the balloon's far
## side, and the burner roars. The ring stays where it was let out (the
## anchor is read once): the group only wanders round its place, so the ring
## stays by it while the plane comes round.
##
## A group is put when the plane comes within SHOW m of its place (one
## balloon a frame) and taken past HIDE m. It does not drift off with the
## wind: each balloon wanders WANDER m round its own spot, so the group is
## where the logbook's hint says however long the flight. With its find
## already in the book the gold one wears the group's cloth like the rest.

const Finds = preload("res://scripts/endless/finds.gd")

## The places (seed 1, the wilderness): the group's middle (x, z), its turn
## (rad) and the find's row id in finds_table.gd.
const SITES: Array = [
	{"name":"meadow","at":Vector2(680.0,300.0),"turn":0.4,"id":"gold-balloon"},
	{"name":"south","at":Vector2(0.0,2000.0),"turn":2.1,"id":"south-balloon"},
	{"name":"coast","at":Vector2(2120.0,2120.0),"turn":-1.0,"id":"coast-balloon"},
]
## The group about its middle: (x, z) off it (m, turned by the site's turn),
## floor over the ground (m), own size. The first is the odd one.
const GROUP: Array[Vector4] = [
	Vector4(0.0,0.0,24.0,1.5),
	Vector4(-95.0,45.0,17.0,1.15),
	Vector4(80.0,70.0,36.0,1.2),
	Vector4(25.0,-105.0,52.0,1.15),
]
## Put within this of the plane (m), taken past HIDE.
const SHOW := 1900.0
const HIDE := 2600.0
## Each balloon's wander round its spot (m) and its period (s).
const WANDER := 26.0
const WANDER_PERIOD := 140.0
## The matched cloth the three wear (FESTIVAL tones, sRGB) and its pattern.
const PLAIN: Array = [Color("3363b4"),Color("efe4c8"),Color("2b4a7a")]
const PLAIN_PATTERN := 0.0
const PLAIN_WEAR := 0.4
## The gold one: its tones, pattern, wear, and the lantern held lit in it.
const GOLD: Array = [Color("f2b416"),Color("fff1c4"),Color("c8641a")]
const GOLD_PATTERN := 2.0
const GOLD_WEAR := 0.12
const GOLD_LIT := 1.0
## The ring: this far off the cloth (m), at the balloon's middle height and at
## least RING_CLEAR over the ground.
const RING_OFF := 24.0
const RING_CLEAR := 14.0
## The burner's roar when it lets the find out (s).
const RELEASE_BURN := 3.0

## Per site: {name, at, turn, id, book_id, anchor, members (Balloons), next
## (the next of GROUP to put), live, released}.
var sites: Array = []
## Bounces off any balloon, off gold ones, and finds let out (for drivers).
var bounces := 0
var gold_bounces := 0
var released := 0
## The last bounce: {balloon, before, after, into, at, ...} for drivers.
var last := {}

func setup(game: Node) -> void:
	if game.get("finds") == null or game.finds == null: return
	for s: Dictionary in SITES:
		var e := s.duplicate()
		e["book_id"] = Finds.book_id("wilderness",str(s.id))
		e["anchor"] = "balloon/"+str(s.name)
		e["members"] = []
		e["next"] = 0
		e["live"] = false
		e["released"] = false
		sites.append(e)

## Whether site `e`'s find is in the book already.
func found(e: Dictionary, game: Node) -> bool:
	return game.book != null and game.book.found.has(e.book_id)

## A frame: groups put and taken by the plane's distance, the live ones wandered.
func step(m: Node3D, game: Node) -> void:
	if sites.is_empty(): return
	var p: Vector3 = game.plane.position
	for e: Dictionary in sites:
		var at: Vector2 = e.at
		var d := Vector2(p.x-at.x,p.z-at.y).length()
		if not e.live and d < SHOW: e.live = true
		if e.live and d > HIDE:
			e.live = false
			for b: RefCounted in e.members:
				if b.live: b.leaving = true
			e.members = []
			e.next = 0
		if e.live and int(e.next) < GROUP.size(): _put_next(m,game,e)
		for i in (e.members as Array).size():
			var b: RefCounted = e.members[i]
			if b.live and not b.leaving: _wander(m,e,i,b)

## Where member `i` of site `e` stands now (x, z).
func _spot(m: Node3D, e: Dictionary, i: int) -> Vector2:
	var g := GROUP[i]
	var at: Vector2 = e.at
	var o := Vector2(g.x,g.y).rotated(float(e.turn))
	var t := float(m._clock)*TAU/WANDER_PERIOD
	var ph := float(i)*1.9+float(e.turn)
	return at+o+Vector2(sin(t+ph),sin(t*0.71+ph*1.3))*WANDER

func _wander(m: Node3D, e: Dictionary, i: int, b: RefCounted) -> void:
	var s := _spot(m,e,i)
	b.at.x = s.x
	b.at.z = s.y

func _put_next(m: Node3D, game: Node, e: Dictionary) -> void:
	var i := int(e.next)
	var b: RefCounted = m._free_balloon()
	if b == null: return
	var g := GROUP[i]
	var s := _spot(m,e,i)
	m._put(b,game,{"at":Vector3(s.x,0.0,s.y),"clear":g.z,"k":g.w,"kind":m.ODD,"fade":0.0,"festival":0.0})
	b.drift_k = 0.0
	var odd := i == 0 and not found(e,game)
	b.odd = odd
	b.site = sites.find(e)
	b.lit = GOLD_LIT if odd else 0.0
	var tones: Array = GOLD if odd else PLAIN
	for gi: GeometryInstance3D in [b.envelope,b.far]:
		gi.set_instance_shader_parameter(&"tone_a",tones[0])
		gi.set_instance_shader_parameter(&"tone_b",tones[1])
		gi.set_instance_shader_parameter(&"tone_c",tones[2])
		gi.set_instance_shader_parameter(&"pattern",GOLD_PATTERN if odd else PLAIN_PATTERN)
		gi.set_instance_shader_parameter(&"wear",GOLD_WEAR if odd else PLAIN_WEAR)
	(e.members as Array).append(b)
	e.next = i+1

## The plane bounced off `b` (BalloonBounce `push_off`'s `res`): a gold one
## not yet let go lets its find out.
func bounced(m: Node3D, game: Node, b: RefCounted, res: Dictionary) -> void:
	bounces += 1
	last = res.duplicate()
	last["odd"] = bool(b.odd)
	last["site"] = int(b.site)
	if not bool(b.odd) or int(b.site) < 0: return
	gold_bounces += 1
	var e: Dictionary = sites[int(b.site)]
	if bool(e.released) or found(e,game) or game.finds == null: return
	e.released = true
	released += 1
	# The far side of the balloon from the plane's way out, off the cloth.
	var c: Vector3 = b.at+b.jolt
	var out: Vector3 = res.out
	var o := Vector3(out.x,0.0,out.z)
	o = o.normalized() if o.length_squared() > 0.0001 else Vector3.FORWARD
	var n: Vector3 = res.push
	var side := Vector3(n.x,0.0,n.z)
	side -= o*side.dot(o)
	if side.length_squared() < 0.01: side = Vector3(-o.z,0.0,o.x)
	var way := -side.normalized()
	var at := c+way*(float(m.R)*float(b.scale)+RING_OFF)
	at.y = maxf(c.y,float(m._ground_at(game,at))+RING_CLEAR)
	game.finds.anchor(str(e.anchor),at)
	last["ring"] = at
	# The burner roars as it goes.
	b.burn_left = RELEASE_BURN
	b.burn_in = RELEASE_BURN+4.0
	if b.roar != null and not b.roar.playing:
		b.roar.play()
	print("balloons: the %s balloon let its find out at %s" % [e.name,at])
