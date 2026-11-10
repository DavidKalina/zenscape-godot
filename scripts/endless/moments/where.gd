extends RefCounted
## The places a moment fits (scripts/endless/moments/moment.gd `where`): each
## builds a predicate `func(ctx, game) -> String`, "" when the place fits, else
## why not. Asked only when a moment's cue comes, never each frame.

const PlacedSites = preload("res://scripts/endless/placed_sites.gd")

## In world region `id` (the world profile's `at`).
static func region(id: String) -> Callable:
	return func(ctx: Dictionary, game: Node) -> String:
		var at: Vector3 = ctx.at
		var here := str(game.world.at(at.x,at.z).id) if game.get("world") != null else ""
		return "" if here == id else "region %s, not %s" % [here,id]

## Within `radius` m (flat) of placed site `handle`, where the layout put it.
static func near_site(handle: String, radius: float) -> Callable:
	return func(ctx: Dictionary, game: Node) -> String:
		var at: Vector3 = ctx.at
		var spot := site_spot(game,handle)
		if is_nan(spot.x): return "no site %s" % handle
		var d := Vector2(at.x,at.z).distance_to(Vector2(spot.x,spot.z))
		return "" if d <= radius else "%.0f m from %s" % [d,handle]

## Where placed site `handle` stands (its layout move kept), or NAN.
static func site_spot(game: Node, handle: String) -> Vector3:
	var placed: Variant = game.get("placed")
	if placed == null: return Vector3(NAN,NAN,NAN)
	for s: Dictionary in placed.sites:
		if str(s.handle) == handle: return PlacedSites.xform_of(s,game.field).origin
	return Vector3(NAN,NAN,NAN)

## The sun up between `low` and `high` degrees.
static func sun_between(low: float, high: float) -> Callable:
	return func(ctx: Dictionary, _game: Node) -> String:
		var sun: Vector3 = ctx.sun
		var e := rad_to_deg(asin(clampf(sun.normalized().y,-1.0,1.0)))
		return "" if e >= low and e <= high else "sun at %.0f deg, not %.0f-%.0f" % [e,low,high]

## The sun behind the plane: its way at most `spread` degrees off the way
## straight away from the sun (flat), so a bow round the shadow is ahead.
static func sun_behind(spread: float) -> Callable:
	return func(ctx: Dictionary, _game: Node) -> String:
		var sun: Vector3 = ctx.sun
		var away := Vector2(-sun.x,-sun.z)
		var fwd: Vector3 = ctx.forward
		if away.length() < 0.01: return ""
		var off := rad_to_deg(away.angle_to(Vector2(fwd.x,fwd.z)))
		return "" if absf(off) <= spread else "sun %.0f deg off behind" % absf(off)
