extends Node3D
## A rune knight's tablet rune spilled by a riposte as the isle's own glyph
## token (docs/design/rune-knight/spec-rune-knight.md, "Runes that really
## spill"): the pickup the isles lay (scripts/glyph_pickup.gd, the kit
## tokens' glyph, size and calm look) pops out of the tablet, arcs out to
## a spot the knight picked (on the deck or the turf by him, clear of stone,
## never off a side or the rim), bounces once and settles, then is handed
## to the isle's tokens (scripts/kit_isle/kit_tokens.gd `lay`), which stand
## it and take it like the rest (reach, readout climb, chime, ledger).
##
## Top level in the isle; frees itself once the token is handed over.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const KitTokens = preload("res://scripts/kit_isle/kit_tokens.gd")

## The pop's arc: its time (s) and how high it peaks over the higher end
## (m); the bounce: its share of the way, time (s) and height (m).
const ARC_TIME := 0.62
const ARC_UP := 1.1
const BOUNCE_AT := 0.8
const BOUNCE_TIME := 0.3
const BOUNCE_UP := 0.32
## The pop's own spin while it flies (rad/s), slowing to the token's turn.
const FLY_SPIN := 14.0

## The isle's tokens it is laid into, and its name there.
var tokens: Node3D = null
var token_name := ""
## Where it pops from (the tablet), where it first strikes, where it rests
## (the token's middle, kit spot height over the ground).
var from := Vector3.ZERO
var rest := Vector3.ZERO
var holder: Node3D = null
var landed := false
var _t := 0.0
var _strike := Vector3.ZERO

## Spilled from `at` to rest at `rest_at`, laid as `name_` in `tokens_`.
func setup(tokens_: Node3D, name_: String, at: Vector3, rest_at: Vector3) -> void:
	name = "RuneSpillToken"
	tokens = tokens_
	token_name = name_
	from = at
	rest = rest_at
	_strike = from.lerp(rest,BOUNCE_AT)
	_strike.y = rest.y-0.2
	holder = GlyphPickup.make(KitTokens.GLYPH,KitTokens.SIZE,0.0,true)
	holder.scale = Vector3.ONE*0.4
	add_child(holder)
	holder.global_position = from
	holder.motes_on(true)

static func _arc(a: Vector3, b: Vector3, up: float, u: float) -> Vector3:
	var p := a.lerp(b,u)
	var top := maxf(a.y,b.y)+up
	# A parabola through a and b peaking near `top`.
	var h := top-lerpf(a.y,b.y,0.5)
	p.y += 4.0*h*u*(1.0-u)
	return p

func _process(delta: float) -> void:
	if landed or holder == null: return
	_t += delta
	var spin: Node3D = holder.spin()
	if _t < ARC_TIME:
		var u := _t/ARC_TIME
		holder.global_position = _arc(from,_strike,ARC_UP,u)
		holder.scale = Vector3.ONE*lerpf(0.4,1.0,minf(u*2.5,1.0))
		spin.rotation.y += FLY_SPIN*delta
		return
	var b := (_t-ARC_TIME)/BOUNCE_TIME
	if b < 1.0:
		holder.scale = Vector3.ONE
		holder.global_position = _arc(_strike,rest,BOUNCE_UP,b)
		spin.rotation.y += FLY_SPIN*(1.0-b)*0.5*delta
		return
	landed = true
	holder.global_position = rest
	var ok: bool = tokens != null and is_instance_valid(tokens) and tokens.call("lay",token_name,rest,holder)
	print("rune knight: his %s token comes to rest at (%.1f, %.1f, %.1f)%s" % [token_name,rest.x,rest.y,rest.z,"" if ok else " (not laid)"])
	if not ok and holder.get_parent() == self: holder.queue_free()
	queue_free()
