extends "res://studies/aqueduct_isle_sky.gd"
## The sky round the bell spires isle: the aqueduct isle's (far isles,
## airships, CPU planes, open-air life, motes; every --no-... flag), its
## tokens for the plane this isle's own, each a line through the spires.
const Spires = preload("res://studies/bell_spires_isle_art.gd")

## The plane's tokens: [line id, category, kind, points (world)].
static func spire_tokens() -> Array:
	var l: Dictionary = Spires.layout()
	var out: Array = []
	# Under each long bridge at mid-span, a few metres under its deck.
	for name: String in ["low","gable","needle"]:
		var br: Dictionary = Spires.bridge(name)
		var mid: Vector3 = (br.a as Vector3).lerp(br.b,0.5)
		out.append(["bs:under_"+name,"air","thread",[mid+Vector3.DOWN*4.5]])
	# Knife edge (Q or E held) along the chimney between the fin's stacks.
	var fh: Dictionary = l.spires.fin_high
	var fl: Dictionary = l.spires.fin_low
	var mid: Vector2 = (fh.c as Vector2).lerp(fl.c,0.5)
	var along: Vector2 = l.chock.along
	var a := mid-along*3.0
	var b := mid+along*0.2
	out.append(["bs:chimney","air","knife",[Vector3(a.x,Spires.TOP+4.5,a.y),Vector3(b.x,Spires.TOP+4.5,b.y)]])
	# Low between the needle and the hero's rock.
	var needle: Dictionary = l.spires.needle
	var nm: Vector2 = (needle.c as Vector2).lerp(Spires.HERO,0.45)
	out.append(["bs:needle","air","thread",[Vector3(nm.x,float(needle.top)-9.0,nm.y)]])
	# Over the belfry's open head.
	out.append(["bs:belfry","air","thread",[Vector3(Spires.HERO.x,float(l.spires.hero.top)+Spires.Belfry.HEAD+4.5,Spires.HERO.y)]])
	# Under the isle's keel.
	out.append(["bs:keel","under","keel",[Vector3(Spires.HERO.x+6.0,Spires.TOP-26.0,Spires.HERO.y+8.0)]])
	return out

func _build_tokens() -> void:
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in spire_tokens():
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source("bell_spires",lines)
