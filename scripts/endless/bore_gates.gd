extends RefCounted
## The partial walls the burrower brings down behind him in a sunk tunnel (spec-burrower-rocks.md,
## spec change 2): beside the full plugs (scripts/endless/bore_plug.gd), walls of the same rubble
## that close one part of the bore's section and leave the rest open. Kinds: a half (top, bottom,
## left, right) or two thirds closed so a third is open; never less than half. The player reads which
## part is open and flies into it.
##
## A gate is a BorePlugs Plug with a `kind`: it's planned in the plugs' plan (by the tunnel's seed,
## its own draws, clear of spurs, plugs and the other gates), laid, fired, dropped, smashed and
## sensed by the plug's code. What differs lives here: its shape is a cut across the section (a
## line; the closed side is where the section point's `cut_n` part is past `cut_c`), and the
## plug's polar outline round its "hole" (here r 0, a point on the cut line) is filled from it,
## so LandTunnels' native sight reads a gate as it reads a plug. AROUND (bore_plug.gd) is a
## multiple of 4, so a straight cut runs along two of its rays and the outline's edge is the cut's.
## `stretches`, `face` and `crossed` answer from the cut itself.
##
## Left and right are the section's own (`side`, as the plug's frame), not the plane's.

const BoreLine = preload("res://scripts/endless/bore_line.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The kinds: name, the way into the closed part (x across `side`, y up), the share of the section
## (along that way) closed.
const KINDS := [
	["top half",Vector2(0,1),0.5],["bottom half",Vector2(0,-1),0.5],
	["left half",Vector2(-1,0),0.5],["right half",Vector2(1,0),0.5],
	["top two thirds",Vector2(0,1),2.0/3.0],["bottom two thirds",Vector2(0,-1),2.0/3.0],
	["left two thirds",Vector2(-1,0),2.0/3.0],["right two thirds",Vector2(1,0),2.0/3.0],
]
## The open part is never narrower than this toy width (WorldScale `opening`), across the cut;
## the closed part never less than CLOSED_LEAST m (else it's no wall).
const TOY_GATE_OPEN := 7.0
const CLOSED_LEAST := 4.0
## How many a tunnel gets (the most), none this close to a spur (m), none this close to a plug
## or another gate (m).
const GATE_COUNT := 3
const GATE_ROOM := 40.0
const GATE_APART := 220.0
## The tell: its hold from him passing (s) and the drop (s): shorter than the plug's, so the
## wall is down and read a second before the plane comes up on it.
const GATE_HOLD := 0.3
const GATE_DROP := 0.45

static func kind_name(kind: int) -> String:
	return str(KINDS[kind][0])

## Gate `pl` (a BorePlugs Plug, `kind` >= 0, mid, along and side set) cut across `ring`: its cut
## (`cut_n` world, `cut_c` m from the middle), its outline's centre (`hole`, on the cut line,
## `r` 0), the open part's middle and width (`open_mid`, `open_w`), the outline (`outer`, AROUND
## points, `push` m into the rock on the closed side, 0 on the open).
static func shape(pl: RefCounted, ring: PackedVector3Array, around: int, push: float) -> void:
	var k2: Vector2 = KINDS[pl.kind][1]
	var share: float = KINDS[pl.kind][2]
	var n: Vector3 = pl.side*k2.x+Vector3.UP*k2.y
	var a := BoreLine.across(ring,pl.mid,n,pl.along)
	var b := BoreLine.across(ring,pl.mid,-n,pl.along)
	var c := a-share*(a+b)
	var need := WorldScale.opening(TOY_GATE_OPEN)
	if c+b < need: c = need-b
	c = minf(c,a-CLOSED_LEAST)
	pl.cut_n = n
	pl.cut_c = c
	pl.hole = pl.mid+n*c
	pl.r = 0.0
	pl.open_w = c+b
	pl.open_mid = pl.mid+n*((c-b)*0.5)
	pl.outer.resize(around)
	for k in around:
		var ang := TAU*float(k)/around
		var e: Vector3 = pl.side*cos(ang)+Vector3.UP*sin(ang)
		# On the cut line (a straight cut lies on two rays) is the closed part's edge.
		pl.outer[k] = BoreLine.across(ring,pl.hole,e,pl.along)+push if e.dot(n) > -1e-3 else 0.0

## How far `p` is past the cut into the closed part (m; negative in the open part).
static func into(pl: RefCounted, p: Vector3) -> float:
	return (p-pl.mid).dot(pl.cut_n)-float(pl.cut_c)

## `stretches` for gate `pl` at p's column (`lo`, `top` its wall's world y bounds), `grow` m wider.
static func stretches(pl: RefCounted, p: Vector3, grow: float, lo: float, top: float, list: Array) -> void:
	var n: Vector3 = pl.cut_n
	var c: float = float(pl.cut_c)-grow
	if absf(n.y) > 0.5:
		var at: float = pl.mid.y+c*signf(n.y)
		if n.y > 0.0: list.append(Vector2(at,top))
		else: list.append(Vector2(lo,at))
	elif (p-pl.mid).dot(n) > c:
		list.append(Vector2(lo,top))

## `crossed` for gate `pl` at the crossing point `at`: {room, half, name}, else {} (through the
## closed part: that's a crash, not a thread).
static func crossed(pl: RefCounted, at: Vector3, slack: float) -> Dictionary:
	var past := into(pl,at)
	if past > slack: return {}
	return {"room":-past,"half":float(pl.open_w)*0.5,"name":"gate %.0f" % pl.s}
