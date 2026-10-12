extends Node3D
## The plane's arc, round 1 (docs/design/plane-arc/round1.md; the direction:
## docs/game-direction.md "The plane", "The plane's parts", "Never
## wait-and-grab", "The pilot's kit"): the game starts with the plane
## broken, its six parts spread over region one, each found a different way
## (scripts/plane_arc/part_spots.gd), carried to the plane and fitted there;
## with all six fitted, it flies.
##
## - **Broken.** Until all six are fitted the parked plane stands
##   `set_missing` with the rest (scripts/plane_figure.gd: the damage where
##   each was, slumped on its folded gear without the wheel, dusty with
##   wear). Space (pad A) by it with nothing to fit plays a start that won't
##   catch (scripts/plane_arc/plane_cough.gd) and it stays put.
## - **Found.** Each part stands as its hovering piece (scripts/
##   plane_parts.gd, style "piece") and glints far off through the
##   telescope (`spot`, the one call into the telescope's glint hook). Only
##   the pilot on foot takes one (swimming counts; the plane passes
##   through): his middle within reach of it along the way he moved since
##   the last frame, as the rune tokens are taken (scripts/kit_isle/
##   kit_tokens.gd). Taking it stamps its objective in the ledger at once
##   ("<isle>/<part id>", type "part": scripts/ledger/ledger.gd
##   `carry_part`) and a pop says so.
## - **Carried.** It rides at the pilot's side, small and glowing, as the
##   lodestone does: no weight, every move still his. Several ride round
##   him from one side behind to the other. A fall, a stranding, a respawn
##   or Back to the plane loses none; they're saved carried.
## - **Fitted.** Space (pad A) by the parked plane, carrying any: each flies
##   from his side to its seat, one after another (FIT_EVERY s apart), and
##   seats with the figure's beat (`set_found` with seat: a warm glint, a
##   brass ring, a puff of dust, the paint a step cleaner; the gleam on the
##   last). Fitted is saved as he presses, before the beat plays out. With
##   all six fitted, Space by it climbs in and takes off as ever.
##
## The cowl is jammed up under the belfry's bell (PartSpots `cowl`): it
## can't be taken there. A slam (scripts/slam.gd: the arc joins
## its group) that reaches the bell (MotifBellSpires `bell_reach`, at
## a decent hit: Slam `decent`) swings the bell hard, and COWL_DELAY s later,
## as it swings, the cowl is knocked out: it tumbles down onto the belfry
## floor (PartSpots `cowl_floor`, COWL_FALL s, a bounce) and hovers there
## to be taken as ever. Reaching the belfry needs the plane for now
## (--plane-fixed) until the airship ferries come.
##
## The tail fin rides the rune serpent's back (the watcher's find:
## scripts/kit_isle/watcher.gd borrows it, `fin_holder`); the propeller hangs
## on a rope under the salvager's plane (scripts/snag_plane.gd) flying its
## loop down the Sundered gorge's west lip.
##
## Flags (the game's, after --):
##   --plane-fixed      starts repaired: the plane flies; the parts are laid
##                      and taken as ever (--fly, --fly-at=, --near-ring and
##                      --dragon-fly-test imply it)
##   --parts-carried    starts carrying every part not fitted (a dev start:
##                      nothing it takes or fits is saved)
##   --part-at=<id>     starts the pilot by that part: wheel, wingtip, fin
##                      (on the home ledge, the serpent coming), windscreen,
##                      propeller (on the gate tower's crown, a pass coming),
##                      cowl
## A script run (--script: the tests, the tools) starts repaired unless it
## asks for the arc with --plane-arc, so a test that flies from the parked
## plane still flies; so does the packaged self-check (--verify-desktop-build,
## scripts/desktop_build_check.gd), which boards and flies the parked plane.
##
## The host (studies/aqueduct_isle.gd) makes it in `_add_life`; the kit
## isle (studies/kit_isle.gd) calls `step_pilot` each foot step, `at_plane`
## from `board_parked`, `dress` on its plane figure, `hint` for its foot
## hint.
const PlaneParts = preload("res://scripts/plane_parts.gd")
const PartSpots = preload("res://scripts/plane_arc/part_spots.gd")
const PlaneCough = preload("res://scripts/plane_arc/plane_cough.gd")
const SnagPlane = preload("res://scripts/snag_plane.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
const Telescope = preload("res://scripts/telescope.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const MomentsHud = preload("res://scripts/moments_hud.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const Slam = preload("res://scripts/slam.gd")
const BellSpires = preload("res://scripts/kit_isle/motif_bell_spires.gd")

const IDS := PartSpots.IDS
## The names the pops use, and what each says as it's taken.
const NAMES := {"wheel":"The wheel","cowl":"The cowl","fin":"The tail fin","wingtip":"The wingtip","propeller":"The propeller","windscreen":"The windscreen"}
const TAKEN := {"wheel":"The wheel","cowl":"The cowl, worked loose from under the bell","fin":"The tail fin, off the old serpent's back",
	"wingtip":"The wingtip, up out of the tarn","propeller":"The propeller, torn off the salvager's rope","windscreen":"The windscreen, out of the drowned aisle"}
## A laid part's size (m across), and carried, its share of that.
const SIZE := 0.9
const CARRY := 0.38
## Carried: how far round him (m, at the walker's size), how high, the
## spread round from one side behind to the other (rad either side of
## straight behind), the bob, the follow's ease (s).
const CARRY_OUT := 0.62
const CARRY_UP := 0.85
const CARRY_SPREAD := 1.35
const CARRY_BOB := 0.04
const CARRY_EASE := 0.09
## The load on the salvager's rope is taken a little further off (the
## snag study's grab, studies/snag_study.gd).
const SNAG_REACH := 1.05
## A mover jumping further than this in a frame starts its sweep afresh.
const JUMP := 6.0
## Fitting: seconds between parts, and each one's flight from his side to
## its seat.
const FIT_EVERY := 0.95
const FLY_TO := 0.35
## The salvager's loop: one lap (s), where a fresh run starts in it (s), and
## with --part-at=propeller how long till the pass.
const SNAG_LAP := 30.0
const SNAG_START := 9.0
const SNAG_SOON := 7.0
## The jammed cowl (it takes a decent slam, Slam `decent`, to knock loose):
## seconds from the blast to its fall (the bell swinging into it), and the
## fall's seconds to the belfry floor.
const COWL_DELAY := 0.28
const COWL_FALL := 0.55

## "jammed" under the bell, "falling", "down" on the floor (or "" once
## taken or never laid).
var cowl := ""
var _cowl_t := 0.0
var _cowl_from := Vector3.ZERO

var host: Node3D
## The plane flies whatever is fitted (--plane-fixed and its kin).
var fixed := false
## What's taken and fitted is saved (off with --parts-carried).
var keep := true
## id -> "laid", "carried", "fitted".
var state := {}
## id -> the part's holder (laid or carried; none once fitted).
var holders := {}
## id -> the still part's spot (PartSpots `spot`).
var spots := {}
## The parts he carries, in the order taken.
var carried: Array[String] = []
## The ones waiting to fly to their seats, and those flying now
## ({id, holder, from, t}).
var fitting: Array[String] = []
var _flying: Array[Dictionary] = []
var _fit_left := 0.0
## The salvager's plane (scripts/snag_plane.gd) and its loop
## (PartSpots `snag`); the serpent and the fin's ring on it.
var snag: Node3D
var snag_spot := {}
var serpent: Node3D
var fin_ring := -1
var cough: Node3D
## The glints over parts under water (id -> node), and the scene's pops.
var _glints := {}
var _moments: CanvasLayer
var _last := Vector3.INF
var _clock := 0.0
var _part_at := ""
var _was_flying := false

func _init() -> void:
	name = "PlaneArc"
	# After the serpent (-101) and its rider (-100) move.
	process_priority = -60

## The arc on `scene` (the aqueduct isle, its sky and serpent up).
func setup(scene: Node3D) -> void:
	host = scene
	var args := LaunchArgs.user_args()
	var script_run := OS.get_cmdline_args().has("--script") or OS.get_cmdline_args().has("-s")
	fixed = args.has("--plane-fixed") or args.has("--fly") or args.has("--near-ring") or args.has("--verify-desktop-build") or (script_run and not args.has("--plane-arc"))
	for arg: String in args:
		if arg.begins_with("--fly-at=") or arg.begins_with("--dragon-fly-test"): fixed = true
		elif arg.begins_with("--part-at="): _part_at = arg.get_slice("=",1)
	var all_carried := args.has("--parts-carried")
	if all_carried: keep = false
	var book := Ledger.shared()
	for id: String in IDS:
		if book.is_fitted(id): state[id] = "fitted"
		elif all_carried or book.is_carried(id) or book.is_done(PartSpots.objective(id)): state[id] = "carried"
		else: state[id] = "laid"
	_moments = host.get("_moments")
	if _moments == null:
		_moments = MomentsHud.new()
		add_child(_moments)
	cough = PlaneCough.new()
	add_child(cough)
	var sky: Node3D = host.get("sky")
	serpent = sky.get("serpent") if sky != null else null
	if serpent != null and serpent.has_method("ring_frame"): fin_ring = PartSpots.fin_ring(serpent)
	for id: String in IDS:
		if state[id] == "carried":
			carried.append(id)
			holders[id] = _make(id,true)
		elif state[id] == "laid": _lay(id)
	_build_snag()
	if state.cowl == "laid" and holders.has("cowl"): cowl = "jammed"
	add_to_group(Slam.GROUP)
	_follow(0.0,true)
	var figure: Node3D = host.get("plane_figure")
	if figure != null: dress(figure)
	if _part_at != "": _start_by(_part_at)

# --- Laying ---------------------------------------------------------------------------

## A part's holder: the hovering piece, or carried, small at his side.
func _make(id: String, small: bool) -> Node3D:
	var holder: Node3D = PlaneParts.part(_figure_id(id),SIZE,"piece",float(IDS.find(id))*1.1)
	holder.name = "Part_"+id
	add_child(holder)
	if small: _shrink(holder)
	return holder

## The plane figure's id for a part (the same six).
static func _figure_id(id: String) -> String:
	return id

func _shrink(holder: Node3D) -> void:
	holder.scale = Vector3.ONE*CARRY
	var ring: Node3D = holder.get("_ring")
	if ring != null: ring.visible = false

## Part `id` laid where it's found, glinting.
func _lay(id: String) -> void:
	match PartSpots.KINDS[id]:
		"still":
			var s := PartSpots.spot(id,host)
			if s.is_empty():
				push_warning("plane arc: no spot for the %s (its isle's geometry isn't there)" % id)
				return
			spots[id] = s
			var holder := _make(id,false)
			holder.position = s.at
			holders[id] = holder
			if (s.glint as Vector3).distance_to(s.at) > 0.01:
				var glint := Node3D.new()
				glint.name = "Glint_"+id
				glint.position = s.glint
				add_child(glint)
				_glints[id] = glint
				spot(glint,PartSpots.objective(id))
			else: spot(holder,PartSpots.objective(id))
		"serpent":
			if serpent == null or fin_ring < 0: return
			var holder := _make(id,false)
			holder.set("turning",false)
			holders[id] = holder
			spot(holder,PartSpots.objective(id))
			place_fin()
		# The propeller is laid on the salvager's rope (`_build_snag`).

## The one call into the telescope's glint hook (a parallel branch renamed
## it Telescope.spottable): `node` glints until objective `id` is done.
static func spot(node: Node3D, id: String) -> void:
	Telescope.spottable(node,id)

## The fin on the serpent's back where it is now.
func place_fin() -> void:
	if state.get("fin","") != "laid" or not holders.has("fin") or serpent == null: return
	(holders.fin as Node3D).global_transform = PartSpots.on_serpent(serpent,fin_ring)

## The fin's holder while it rides the serpent (the watcher's find), or null.
func fin_holder() -> Node3D:
	return holders.get("fin") if state.get("fin","") == "laid" else null

## The salvager's plane on its loop, the propeller on its rope (none if
## taken before).
func _build_snag() -> void:
	snag_spot = PartSpots.snag()
	snag = SnagPlane.new()
	snag.setup(SNAG_LAP,SnagPlane.ROPE,float(snag_spot.dip),snag_spot.over,SNAG_START)
	snag.yaw = float(snag_spot.yaw)
	snag.load_maker = func() -> Node3D: return PlaneParts.part("propeller",SIZE,"piece",4.4)
	snag.respawns = false
	add_child(snag)
	if state.propeller == "laid":
		holders.propeller = snag.load_token
		spot(snag.load_token,PartSpots.objective("propeller"))
	else: snag.empty()

# --- Each frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	advance(delta)

## The parts' frame: the fin on the serpent, the carried following, the
## fitting beat.
func advance(delta: float) -> void:
	if host == null or delta <= 0.0: return
	_clock += delta
	# Flying, none is taken and the carried ride hidden in the plane.
	var flying := bool(host.get("flying"))
	if flying != _was_flying:
		_was_flying = flying
		for id: String in carried:
			if is_instance_valid(holders.get(id)): (holders[id] as Node3D).visible = not flying
	if flying: _last = Vector3.INF
	place_fin()
	_follow(delta)
	_fit_step(delta)
	_cowl_step(delta)
	_glow()

## A soft lantern after dark, as the tokens (scripts/kit_isle/kit_life.gd).
func _glow() -> void:
	var celestial: Variant = host.get("_celestial")
	if celestial == null: return
	var night := 1.0-smoothstep(0.1,0.5,float(celestial.state.get("zs_daylight",1.0)))
	for holder: Variant in holders.values():
		if is_instance_valid(holder) and (holder as Node).has_method("glow_for"): holder.glow_for(night)

## One foot step of the pilot (the kit isle's `tick`): parts within his
## reach taken, the carried at his side.
func step_pilot(delta: float) -> void:
	if bool(host.get("flying")): return
	place_fin()
	var scale := float(host.get("wanderer_scale")) if host.get("wanderer_scale") != null else 1.0
	var point: Vector3 = host.motor.feet+Vector3.UP*Lines.FOOT_Y*scale
	touch(point,scale)
	_follow(delta)

## His middle at `point` this frame: every laid part within his reach of
## the way he moved since the last is taken.
func touch(point: Vector3, scale := 1.0) -> void:
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= JUMP else point
	_last = point
	for id: String in IDS:
		if state[id] != "laid": continue
		# Jammed under the bell (or on its way down), out of reach.
		if id == "cowl" and cowl in ["jammed","falling"]: continue
		var at := Vector3.INF
		var reach := Lines.WALKER_REACH*scale+SIZE*0.5
		if id == "propeller":
			if snag == null or not snag.attached: continue
			at = snag.load_point()
			reach = maxf(reach,SNAG_REACH*scale)
		elif holders.has(id) and is_instance_valid(holders[id]): at = (holders[id] as Node3D).global_position
		if at == Vector3.INF: continue
		if Geometry3D.get_closest_point_to_segment(at,from,point).distance_to(at) < reach: take(id)

## Part `id` taken: stamped in the ledger at once, and it comes to his side.
func take(id: String) -> void:
	if state.get(id,"") != "laid": return
	state[id] = "carried"
	carried.append(id)
	if id == "cowl": cowl = ""
	if keep: Ledger.shared().carry_part(id,PartSpots.objective(id))
	var holder: Node3D = holders.get(id)
	if id == "propeller" and snag != null and snag.attached:
		var token: Node3D = snag.snatch()
		if token != null:
			var at := token.global_transform
			token.get_parent().remove_child(token)
			add_child(token)
			token.global_transform = at
			holder = token
	if holder == null or not is_instance_valid(holder): holder = _make(id,false)
	holders[id] = holder
	holder.remove_from_group(Telescope.GROUP)
	holder.set("turning",true)
	holder.global_basis = Basis.IDENTITY
	_shrink(holder)
	if _glints.has(id):
		(_glints[id] as Node).queue_free()
		_glints.erase(id)
	if _moments != null:
		_moments.pop("%s: it rides with you to the plane" % TAKEN[id],2.6)
		_moments.blip(2)

## A slam at `at` (scripts/slam.gd): reaching the bell over the
## jammed cowl, hard enough, it knocks the cowl loose (after COWL_DELAY).
func slam(at: Vector3, radius: float, strength: float) -> void:
	if cowl != "jammed" or strength < Slam.decent() or not is_instance_valid(holders.get("cowl")): return
	var holder: Node3D = holders.cowl
	if holder.global_position.distance_to(at) > BellSpires.bell_reach(radius): return
	cowl = "falling"
	_cowl_t = -COWL_DELAY
	_cowl_from = holder.position

## The cowl knocked loose: a beat as the bell swings into it, then down
## onto the belfry floor, tumbling, with a bounce; there it hovers as any
## laid part.
func _cowl_step(delta: float) -> void:
	if cowl != "falling": return
	var holder: Node3D = holders.get("cowl")
	if not is_instance_valid(holder):
		cowl = ""
		return
	_cowl_t += delta
	if _cowl_t < 0.0:
		# Shaken in the bell's mouth.
		holder.position = _cowl_from+Vector3(sin(_clock*53.0),0.0,cos(_clock*47.0))*0.03
		return
	var floor := PartSpots.cowl_floor()
	var u := clampf(_cowl_t/COWL_FALL,0.0,1.0)
	# Falling as a dropped thing (u squared), a little hop off the floor at
	# the end.
	var bounce := sin(clampf((u-0.8)/0.2,0.0,1.0)*PI)*0.18
	holder.position = _cowl_from.lerp(floor,minf(u*u/0.64,1.0))+Vector3.UP*bounce
	holder.rotation = Vector3(u*2.4,u*1.1,0.0)*(1.0-u)
	if u >= 1.0:
		cowl = "down"
		holder.position = floor
		holder.rotation = Vector3.ZERO
		spots["cowl"] = PartSpots.spot("cowl",host).merged({"at":floor,"glint":floor},true)
		if _moments != null: _moments.pop("The bell swings: the cowl drops to the belfry floor",2.2)

## The carried at his side: round him from one side behind to the other,
## easing after him (at once with `snap`, or after a long jump: a respawn).
func _follow(delta: float, snap := false) -> void:
	if carried.is_empty() or host == null or host.get("figure") == null: return
	var figure: Node3D = host.figure
	var scale := float(host.get("wanderer_scale")) if host.get("wanderer_scale") != null else 1.0
	var way := PilotMotor.forward(float(host.motor.facing))
	var ahead := Vector3(way.x,0.0,way.y)
	var right := Vector3(-way.y,0.0,way.x)
	var n := carried.size()
	for k in range(n):
		var holder: Node3D = holders.get(carried[k])
		if holder == null or not is_instance_valid(holder) or _flying_holder(holder): continue
		var a := -1.0 if n == 1 else lerpf(-CARRY_SPREAD,CARRY_SPREAD,float(k)/(n-1))
		var goal: Vector3 = figure.global_position+(right*sin(a)-ahead*cos(a))*CARRY_OUT*scale+Vector3.UP*(CARRY_UP+sin(_clock*1.6+k)*CARRY_BOB)*scale
		if snap or delta <= 0.0 or holder.global_position.distance_to(goal) > JUMP: holder.global_position = goal
		else: holder.global_position = holder.global_position.lerp(goal,1.0-exp(-delta/CARRY_EASE))

func _flying_holder(holder: Node3D) -> bool:
	for f: Dictionary in _flying:
		if f.holder == holder: return true
	return false

# --- At the plane ---------------------------------------------------------------------

## Whether the plane flies: fixed, or all six fitted.
func flies() -> bool:
	if fixed: return true
	for id: String in IDS:
		if state[id] != "fitted": return false
	return true

## The parts not fitted.
func missing() -> Array:
	return IDS.filter(func(id: String) -> bool: return state[id] != "fitted")

## The plane figure dressed as the arc has it: broken with what isn't
## fitted (none with the plane fixed).
func dress(figure: Node3D) -> void:
	if figure == null or not figure.has_method("set_missing"): return
	figure.set_missing([] if fixed else missing())

## Space (pad A) by the parked plane (the kit isle's `board_parked`): true
## if the arc takes it (fitting what he carries, or a start that won't
## catch), false to board and fly.
func at_plane() -> bool:
	if flies(): return false
	if not fitting.is_empty() or not _flying.is_empty(): return true
	if not carried.is_empty():
		fit_all()
		return true
	cough.play(host.get("plane_figure"))
	if _moments != null: _moments.pop("It coughs and dies: %d %s still missing" % [missing().size(),"part" if missing().size() == 1 else "parts"],2.4)
	return true

## Everything carried fitted (and saved) now; each flies to its seat in turn.
func fit_all() -> void:
	for id: String in carried:
		state[id] = "fitted"
		if keep: Ledger.shared().fit_part(id)
		fitting.append(id)
	carried.clear()
	_fit_left = 0.0

func _fit_step(delta: float) -> void:
	if not fitting.is_empty():
		_fit_left -= delta
		if _fit_left <= 0.0:
			_fit_left = FIT_EVERY
			var id: String = fitting.pop_front()
			var holder: Node3D = holders.get(id)
			if holder != null and is_instance_valid(holder):
				_flying.append({"id":id,"holder":holder,"from":holder.global_position,"t":0.0})
			else: _seat(id)
	for f: Dictionary in _flying.duplicate():
		f.t = float(f.t)+delta
		var holder: Node3D = f.holder
		var u := clampf(float(f.t)/FLY_TO,0.0,1.0)
		var to := _seat_point(str(f.id))
		if is_instance_valid(holder):
			holder.global_position = (f.from as Vector3).lerp(to,u*u)+Vector3.UP*sin(u*PI)*0.4
			holder.scale = Vector3.ONE*lerpf(CARRY,CARRY*0.4,u)
		if u >= 1.0:
			_flying.erase(f)
			if is_instance_valid(holder): holder.queue_free()
			holders.erase(f.id)
			_seat(str(f.id))

## Where part `id` seats on the parked plane (world).
func _seat_point(id: String) -> Vector3:
	var figure: Node3D = host.get("plane_figure")
	if figure == null: return host.motor.feet
	var seat: Dictionary = PlaneFigure.SEATS.get(id,{})
	return figure.global_transform*(seat.get("at",Vector3.ZERO) as Vector3)

## The part home on the figure: its seating beat; the last, a flourish.
func _seat(id: String) -> void:
	var figure: Node3D = host.get("plane_figure")
	if figure != null and figure.has_method("set_found"): figure.set_found(id,true)
	if _moments == null: return
	_moments.blip(2)
	if flies() and fitting.is_empty() and _flying.is_empty():
		_moments.pop("All six home: the plane will fly",2.8)
		_moments.flourish()
	else: _moments.pop("%s seats home" % NAMES[id],1.6)

## The foot hint's line for the plane, or "".
func hint() -> String:
	if flies() and carried.is_empty(): return ""
	var names := PackedStringArray()
	for id: String in carried: names.append(String(NAMES[id]).to_lower())
	if not carried.is_empty(): return "Carrying %s: Space (pad A) by your plane fits %s" % [", ".join(names),"it" if carried.size() == 1 else "them"]
	return "The plane is broken: %d of 6 parts fitted" % (6-missing().size())

## The board line by the parked plane.
func board_line() -> String:
	if flies(): return ""
	if not carried.is_empty(): return "Space (pad A)  fit what you carry"
	return "Space (pad A)  try the engine"

# --- --part-at ------------------------------------------------------------------------

## Starts the pilot by part `id` (its isle stood up at once if a motif's).
func _start_by(id: String) -> void:
	if not IDS.has(id):
		push_warning("plane arc: --part-at=%s isn't a part (%s)" % [id,", ".join(PackedStringArray(IDS))])
		return
	var isle_id: String = PartSpots.ISLES[id]
	if isle_id != "aqueduct_isle": _stand_up(isle_id)
	var at := Vector3.INF
	var face := Vector2(0.0,-1.0)
	match PartSpots.KINDS[id]:
		"still":
			var s: Dictionary = spots.get(id,PartSpots.spot(id,host))
			if s.is_empty(): return
			at = s.stand
			face = s.face
		"snag":
			at = snag_spot.stand
			face = snag_spot.face
			snag.clock = snag.lap-SNAG_SOON
		"serpent":
			var sky: Node3D = host.get("sky")
			var route: Node3D = sky.get("route") if sky != null else null
			if route != null and host.has_signal("isle_ready"):
				host.isle_ready.connect(func() -> void: route.start_at(route.spot("home")),CONNECT_ONE_SHOT)
			return
	host.set("_place",Vector4(at.x,at.y,at.z,rad_to_deg(atan2(face.x,-face.y))))

## Motif isle `id` stood up now (its art, turf, plants and life), so he
## stands on it from the first frame.
func _stand_up(id: String) -> void:
	var motifs: Node3D = host.get("motifs")
	if motifs == null: return
	for isle: Node3D in motifs.isles:
		if str(isle.motif.id()) != id: continue
		if not isle.is_up():
			isle.build_now()
			isle.work(-1)
