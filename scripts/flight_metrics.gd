extends RefCounted
## The flight study's numbers (studies/flight_study.gd, tools/flight_bench.gd):
## plain data in, plain data out, so tests can feed it made-up runs. A run is
## the dictionary scripts/flight_run.gd records (and saves as JSON): the
## entry, the tokens and their reach, the room round each leg, the ticks
## (time, pose, speed and the input dict) and the events (a token first
## seen, taken or missed; a bump).
##
## A gap is the leg into a token: gap 0 runs from the entry to token 0, gap
## g from token g-1 to token g. The line is a smooth curve (centripetal
## Catmull-Rom) through the entry and the tokens, the way a tidy pilot would
## fly them; what the course needs is read off it, at cruise:
##   turn demand  = the line's yaw rate at CRUISE / TURN_RATE (peak, mean)
##   pitch demand = the line's pitch rate at CRUISE / PITCH_SPEED
## What the pilot did is read off the ticks:
##   flown turn / pitch = the heading's / pitch's rate / the same limits
##   reversals    = sign changes of the turn and pitch input past REVERSE_DEAD,
##                  per second
##   effort       = the input's travel (|d turn| + |d pitch|) per second, and
##                  the share of ticks with either past FULL
##   warning      = per token: when the plane must commit to it less when it
##                  first saw it (s). Committing is the turn and pitch the
##                  line asks of its gap, at full rate, plus ROLL_IN to bank:
##                  commit = reached - (turned / TURN_RATE + pitched /
##                  PITCH_SPEED + ROLL_IN). Seen in a forward cone with a
##                  clear line (scripts/flight_run.gd); never seen counts as
##                  seen on arrival, so its warning is minus the commit time.
##   room         = per gap: the line's least clearance to a solid less half
##                  the wingspan, capped by the token's reach (m)
## and each gap gets one demand score (a first guess, to be calibrated
## against the user's ratings; see `gap_demand`):
##   demand = W_TURN * max(turn, pitch) + W_WARN * hurry + W_ROOM * tight
##   hurry  = (1 - clamp(warning / WARN_EASY)) * clamp(commit / COMMIT_FULL)
##            0 with plenty of warning or nothing to swing for, 1 with a
##            full swing and no warning
##   tight  = 1 - clamp(room / ROOM_EASY)       0 wide open, 1 grazing
## The demand curve is each moment's gap demand over the run's time.
## Threading (the user's fun hypothesis: flying through things beats open
## air), read off the ticks and the station's solids (`threading`):
##   a tick threads when a solid lies within THREAD_SIDE m both to the left
##   and to the right (level rays square to the heading), or within
##   THREAD_UP m straight above (a roof, a lintel, a tie, a ring's top);
##   the floor 40 m down never counts, a hall's own floor (below) does not
##   either
##   threading_share = threading ticks / ticks
##   openings        = spells of threading (spells less than THREAD_JOIN s
##                     apart joined), so each ring, gate, slot or roofed
##                     stretch passed counts once; openings_per_s over the
##                     run's duration
## Flow (the user's: continuous movement beats straight-then-climb-then-
## straight steps), read off the flown direction (heading and pitch, not the
## stick, so stick noise that the plane doesn't follow doesn't count; see
## `flow`):
##   swing        = how fast the flight direction swings, deg/s: the
##                  heading's and pitch's change over the last FLOW_SMOOTH s,
##                  sqrt(yaw^2 + pitch^2)
##   still_share  = share of ticks swinging under FLOW_STILL deg/s (flying
##                  straight)
##   straights    = still spells of at least FLOW_STRAIGHT s; longest_straight
##                  the longest still spell (s)
##   swing_mean   = mean swing (deg/s); yaw_share = sideways share of the
##                  swing (sum |yaw| / (sum |yaw| + sum |pitch|))
##   swing_reversals_per_s = the jerkiness guard: sign changes of the yaw
##                  rate and of the pitch rate past FLOW_REVERSE deg/s, per
##                  s. A weave reverses about once a token; a wobbling pilot
##                  reverses far more, so a sloppy bot's low still share
##                  isn't flow. The station's own flow is its perfect
##                  reference run's.

const SkyPlane = preload("res://scripts/sky_plane.gd")

const CRUISE := SkyPlane.CRUISE_SPEED
const TURN_RATE := SkyPlane.TURN_RATE
const PITCH_SPEED := SkyPlane.PITCH_SPEED
## Seconds to bank into a turn before it bites (about two of the plane's
## EASE_ROLL_IN).
const ROLL_IN := 2.0*SkyPlane.EASE_ROLL_IN
## The line: sampled every STEP m; the entry's straight lead-in (m).
const STEP := 0.5
const LEAD_IN := 10.0
## Rates are smoothed over this long (s along the line, at cruise, and in
## the flown ticks), so a sampling kink does not read as a spike.
const SMOOTH := 0.2
## Input: a reversal counts past this much stick; "full" stick is past FULL.
const REVERSE_DEAD := 0.2
const FULL := 0.8
## The demand score's weights and its easy ends: warning (s) and room (m).
const W_TURN := 0.5
const W_WARN := 0.25
const W_ROOM := 0.25
const WARN_EASY := 1.5
const COMMIT_FULL := 1.0
const ROOM_EASY := 2.0
## The warning kept within this (s) so one long look does not swamp a mean.
const WARN_MOST := 10.0
## The demand curve's sample spacing (s).
const CURVE_STEP := 0.25
## A run's peak demand graded (a guess; the bots' band is the measured one).
const GRADES := [[0.35,"easy"],[0.55,"medium"],[0.75,"hard"],[INF,"very hard"]]
## Bot skills from least to most, and the band each one's clear gives.
const SKILLS := ["sloppy","decent","sharp","perfect"]
const BANDS := {"sloppy":"easy","decent":"medium","sharp":"hard","perfect":"expert"}
## A skill clears a station when this share of its runs take every token.
const CLEAR_SHARE := 0.6

## Threading: the rays' reach to the sides and up (m), and spells closer
## than THREAD_JOIN s count as one opening.
const THREAD_SIDE := 8.0
const THREAD_UP := 12.0
const THREAD_JOIN := 0.2

## Flow: the swing is measured over the last FLOW_SMOOTH s; under
## FLOW_STILL deg/s is flying straight, a still spell of FLOW_STRAIGHT s or
## more is a straight; a swing reversal counts past FLOW_REVERSE deg/s.
const FLOW_SMOOTH := 0.25
const FLOW_STILL := 6.0
const FLOW_STRAIGHT := 0.5
const FLOW_REVERSE := 10.0
## The flow numbers' keys (bench, backfill, report).
const FLOW_KEYS := ["still_share","straights","longest_straight","swing_mean","yaw_share","swing_reversals_per_s"]

## A Vector3 from a JSON array or a Vector3.
static func v3(x: Variant) -> Vector3:
	if x is Vector3: return x
	var a: Array = x
	return Vector3(float(a[0]),float(a[1]),float(a[2]))

static func arr(p: Vector3) -> Array:
	return [snappedf(p.x,0.001),snappedf(p.y,0.001),snappedf(p.z,0.001)]

## The plane's forward for a heading and pitch (scripts/sky_glide.gd).
static func forward(heading: float, pitch: float) -> Vector3:
	return Vector3(-sin(heading)*cos(pitch),sin(pitch),-cos(heading)*cos(pitch))

## The heading and pitch of a direction.
static func angles(d: Vector3) -> Vector2:
	return Vector2(atan2(-d.x,-d.z),atan2(d.y,Vector2(d.x,d.z).length()))

# --- The line -------------------------------------------------------------------------

## The smooth line from the entry through the tokens, sampled every STEP m:
## [{"p": Vector3, "gap": int}], gap g ending at token g.
static func line(entry: Vector3, heading: float, tokens: Array, step := STEP) -> Array:
	var pts: Array[Vector3] = [entry-forward(heading,0.0)*LEAD_IN,entry]
	for t: Variant in tokens: pts.append(v3(t))
	var n := pts.size()
	if n < 3: return []
	pts.append(pts[n-1]+(pts[n-1]-pts[n-2]))
	var out := []
	for g in range(n-2):
		var a := pts[g]
		var b := pts[g+1]
		var c := pts[g+2]
		var d := pts[g+3]
		var count := maxi(2,ceili(b.distance_to(c)/step))
		for i in range(count):
			out.append({"p":_centripetal(a,b,c,d,float(i)/count),"gap":g})
	out.append({"p":pts[n-1],"gap":n-3})
	return out

## A centripetal Catmull-Rom point between `b` and `c`, `t` 0..1.
static func _centripetal(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var t0 := 0.0
	var t1 := t0+maxf(sqrt(a.distance_to(b)),0.001)
	var t2 := t1+maxf(sqrt(b.distance_to(c)),0.001)
	var t3 := t2+maxf(sqrt(c.distance_to(d)),0.001)
	var u := lerpf(t1,t2,t)
	var a1 := a*(t1-u)/(t1-t0)+b*(u-t0)/(t1-t0)
	var a2 := b*(t2-u)/(t2-t1)+c*(u-t1)/(t2-t1)
	var a3 := c*(t3-u)/(t3-t2)+d*(u-t2)/(t3-t2)
	var b1 := a1*(t2-u)/(t2-t0)+a2*(u-t0)/(t2-t0)
	var b2 := a2*(t3-u)/(t3-t1)+a3*(u-t1)/(t3-t1)
	return b1*(t2-u)/(t2-t1)+b2*(u-t1)/(t2-t1)

## What the line asks of each gap, flown at CRUISE: [{"length", "turn_peak",
## "turn_mean", "pitch_peak", "pitch_mean" (as shares of TURN_RATE and
## PITCH_SPEED), "turned", "pitched" (radians in all)}].
static func profile(samples: Array, gaps: int) -> Array:
	var out := []
	for g in range(gaps):
		out.append({"length":0.0,"turn_peak":0.0,"turn_mean":0.0,"pitch_peak":0.0,"pitch_mean":0.0,"turned":0.0,"pitched":0.0})
	var n := samples.size()
	if n < 3: return out
	var yaw := PackedFloat32Array()
	var pit := PackedFloat32Array()
	var ds := PackedFloat32Array()
	var prev := Vector2.INF
	for i in range(n-1):
		var d: Vector3 = (samples[i+1].p as Vector3)-(samples[i].p as Vector3)
		var ang := angles(d)
		var seg := maxf(d.length(),0.0001)
		ds.append(seg)
		if prev == Vector2.INF:
			yaw.append(0.0)
			pit.append(0.0)
		else:
			yaw.append(absf(angle_difference(prev.x,ang.x)))
			pit.append(absf(ang.y-prev.y))
		prev = ang
	# Rates at cruise, smoothed over SMOOTH s of flight.
	var window := maxi(1,roundi(SMOOTH*CRUISE/STEP))
	for i in range(n-1):
		var g := int(samples[i].gap)
		if g < 0 or g >= gaps: continue
		var turned := 0.0
		var pitched := 0.0
		var along := 0.0
		for k in range(maxi(0,i-window/2),mini(n-1,i+window/2+1)):
			turned += yaw[k]
			pitched += pit[k]
			along += ds[k]
		var yr := turned/along*CRUISE/TURN_RATE
		var pr := pitched/along*CRUISE/PITCH_SPEED
		var o: Dictionary = out[g]
		o.length += ds[i]
		o.turned += yaw[i]
		o.pitched += pit[i]
		o.turn_peak = maxf(o.turn_peak,yr)
		o.pitch_peak = maxf(o.pitch_peak,pr)
		o.turn_mean += yr*ds[i]
		o.pitch_mean += pr*ds[i]
	for o: Dictionary in out:
		if o.length > 0.0:
			o.turn_mean /= o.length
			o.pitch_mean /= o.length
	return out

## Seconds to commit to a gap: its turn and pitch at full rate, plus ROLL_IN
## if it turns at all.
static func commit_time(gap: Dictionary) -> float:
	var turned := float(gap.get("turned",0.0))
	var pitched := float(gap.get("pitched",0.0))
	var t := turned/TURN_RATE+pitched/PITCH_SPEED
	return t+(ROLL_IN if turned+pitched > 0.05 else 0.0)

## One gap's demand (see the header): `turn` and `pitch` as shares of the
## limits, `warning` and `commit` in seconds, `room` in metres.
static func gap_demand(turn: float, pitch: float, warning: float, room: float, commit := COMMIT_FULL) -> float:
	var hurry := (1.0-clampf(warning/WARN_EASY,0.0,1.0))*clampf(commit/COMMIT_FULL,0.0,1.0)
	var tight := 1.0-clampf(room/ROOM_EASY,0.0,1.0)
	return W_TURN*clampf(maxf(turn,pitch),0.0,1.5)+W_WARN*hurry+W_ROOM*tight

static func grade(demand: float) -> String:
	for g: Array in GRADES:
		if demand < float(g[0]): return g[1]
	return "very hard"

# --- A run ---------------------------------------------------------------------------

## Sign changes of `values` past REVERSE_DEAD.
static func reversals(values: Array) -> int:
	var last := 0.0
	var count := 0
	for v: Variant in values:
		var x := float(v)
		if absf(x) < REVERSE_DEAD: continue
		var s := signf(x)
		if last != 0.0 and s != last: count += 1
		last = s
	return count

## A rate (per second) of an angle series against the clock, smoothed over
## SMOOTH s, as absolute values; `wrap` for headings.
static func rates(t: Array, a: Array, wrap: bool) -> PackedFloat32Array:
	var n := t.size()
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(1,n):
		var dt := maxf(float(t[i])-float(t[i-1]),0.0001)
		var d := angle_difference(float(a[i-1]),float(a[i])) if wrap else float(a[i])-float(a[i-1])
		raw[i] = absf(d)/dt
	if n > 1: raw[0] = raw[1]
	var out := PackedFloat32Array()
	out.resize(n)
	var dt_mean := (float(t[n-1])-float(t[0]))/maxf(n-1,1) if n > 1 else 1.0/60.0
	var half := maxi(0,roundi(SMOOTH/maxf(dt_mean,0.0001)*0.5))
	for i in range(n):
		var s := 0.0
		var c := 0
		for k in range(maxi(0,i-half),mini(n,i+half+1)):
			s += raw[k]
			c += 1
		out[i] = s/maxf(c,1)
	return out

static func _peak_mean(values: PackedFloat32Array, scale: float) -> Vector2:
	if values.is_empty(): return Vector2.ZERO
	var peak := 0.0
	var sum := 0.0
	for v in values:
		peak = maxf(peak,v)
		sum += v
	return Vector2(peak,sum/values.size())/scale

## Every number for a run (see the header). `run` needs "entry", "tokens",
## "ticks", "events"; "rooms" (per gap) if known, else the token's reach.
## With the station's `solids` (FlightCourse `solids`), the threading numbers
## too.
static func summarise(run: Dictionary, solids := []) -> Dictionary:
	var entry: Dictionary = run.entry
	var tokens: Array = run.tokens
	var count := tokens.size()
	var reach := float(run.get("reach",1.7))
	var samples := line(v3(entry.position),float(entry.heading),tokens)
	var gaps := profile(samples,count)
	var rooms: Array = run.get("rooms",[])
	var tk: Dictionary = run.ticks
	var t: Array = tk.t
	var n := t.size()
	var duration := float(run.get("result",{}).get("duration",(float(t[n-1])-float(t[0])) if n > 1 else 0.0))
	var span := maxf(duration,0.0001)
	# What the pilot flew.
	var yaw := rates(t,tk.heading,true)
	var pit := rates(t,tk.pitch,false)
	var flown_turn := _peak_mean(yaw,TURN_RATE)
	var flown_pitch := _peak_mean(pit,PITCH_SPEED)
	var turns: Array = tk.in_turn
	var pitches: Array = tk.in_pitch
	var travel := 0.0
	var full := 0
	for i in range(n):
		if i > 0: travel += absf(float(turns[i])-float(turns[i-1]))+absf(float(pitches[i])-float(pitches[i-1]))
		if maxf(absf(float(turns[i])),absf(float(pitches[i]))) > FULL: full += 1
	var turn_rev := reversals(turns)
	var pitch_rev := reversals(pitches)
	# Tokens: seen, reached (taken or passed).
	var seen := []
	var reached := []
	var kinds := []
	seen.resize(count)
	reached.resize(count)
	kinds.resize(count)
	var bumps := 0
	for e: Dictionary in run.events:
		var i := int(e.get("token",-1))
		match str(e.kind):
			"seen":
				if i >= 0 and i < count and seen[i] == null: seen[i] = float(e.t)
			"hit","miss":
				if i >= 0 and i < count and reached[i] == null:
					reached[i] = float(e.t)
					kinds[i] = e.kind
			"bump": bumps += 1
	var collected := kinds.count("hit")
	# Per gap: the line's turn and pitch, the warning, the room, the demand.
	var out_gaps := []
	var start := float(t[0]) if n > 0 else 0.0
	var from := start
	var warnings := []
	for g in range(count):
		var p: Dictionary = gaps[g]
		var room := reach
		var clear := INF
		if g < rooms.size():
			room = float(rooms[g].room)
			clear = float(rooms[g].clearance)
		var commit := commit_time(p)
		var warning: Variant = null
		if reached[g] != null:
			var saw: float = seen[g] if seen[g] != null else float(reached[g])
			warning = clampf(float(reached[g])-commit-saw,-commit,WARN_MOST)
			warnings.append(warning)
		var demand := gap_demand(p.turn_peak,p.pitch_peak,float(warning) if warning != null else 0.0,room,commit)
		var to: float = reached[g] if reached[g] != null else from
		out_gaps.append({"token":g,"kind":kinds[g] if kinds[g] != null else "unreached","from":snappedf(from-start,0.001),"to":snappedf(to-start,0.001),
			"length":snappedf(p.length,0.01),"turn":snappedf(p.turn_peak,0.001),"turn_mean":snappedf(p.turn_mean,0.001),
			"pitch":snappedf(p.pitch_peak,0.001),"pitch_mean":snappedf(p.pitch_mean,0.001),"commit":snappedf(commit,0.001),
			"seen":(snappedf(float(seen[g])-start,0.001) if seen[g] != null else null),
			"warning":(snappedf(float(warning),0.001) if warning != null else null),
			"room":snappedf(room,0.001),"clearance":(snappedf(clear,0.001) if is_finite(clear) else null),"demand":snappedf(demand,0.001)})
		from = maxf(from,to)
	# The line's needs over the whole station, length-weighted.
	var need_turn := Vector2.ZERO
	var need_pitch := Vector2.ZERO
	var length := 0.0
	for p: Dictionary in gaps:
		need_turn.x = maxf(need_turn.x,p.turn_peak)
		need_pitch.x = maxf(need_pitch.x,p.pitch_peak)
		need_turn.y += p.turn_mean*p.length
		need_pitch.y += p.pitch_mean*p.length
		length += p.length
	if length > 0.0:
		need_turn.y /= length
		need_pitch.y /= length
	# Demand: its peak, its time-weighted mean over the reached gaps, and how
	# far the peak stands over the middle gap (a lone spike stands tall).
	var peak := 0.0
	var weighted := 0.0
	var timed := 0.0
	var demands := []
	for g: Dictionary in out_gaps:
		demands.append(float(g.demand))
		peak = maxf(peak,float(g.demand))
		var dt := float(g.to)-float(g.from)
		weighted += float(g.demand)*dt
		timed += dt
	demands.sort()
	var median: float = demands[demands.size()/2] if not demands.is_empty() else 0.0
	var least_room := INF
	for g: Dictionary in out_gaps: least_room = minf(least_room,float(g.room))
	var warn_min := INF
	var warn_sum := 0.0
	for w: Variant in warnings:
		warn_min = minf(warn_min,float(w))
		warn_sum += float(w)
	return {
		"duration":snappedf(duration,0.001),"collected":collected,"total":count,"cleared":count > 0 and collected == count,
		"bumps":bumps,
		"turn_need_peak":snappedf(need_turn.x,0.001),"turn_need_mean":snappedf(need_turn.y,0.001),
		"pitch_need_peak":snappedf(need_pitch.x,0.001),"pitch_need_mean":snappedf(need_pitch.y,0.001),
		"turn_flown_peak":snappedf(flown_turn.x,0.001),"turn_flown_mean":snappedf(flown_turn.y,0.001),
		"pitch_flown_peak":snappedf(flown_pitch.x,0.001),"pitch_flown_mean":snappedf(flown_pitch.y,0.001),
		"warning_min":(snappedf(warn_min,0.001) if is_finite(warn_min) else null),
		"warning_mean":(snappedf(warn_sum/warnings.size(),0.001) if not warnings.is_empty() else null),
		"reversals":turn_rev+pitch_rev,"turn_reversals":turn_rev,"pitch_reversals":pitch_rev,
		"reversals_per_s":snappedf((turn_rev+pitch_rev)/span,0.001),
		"effort":snappedf(travel/span,0.001),"full_share":snappedf(float(full)/maxf(n,1),0.001),
		"reach":snappedf(reach,0.001),"room_min":(snappedf(least_room,0.001) if is_finite(least_room) else null),
		"demand_peak":snappedf(peak,0.001),"demand_mean":snappedf(weighted/timed if timed > 0.0 else 0.0,0.001),
		"demand_spike":snappedf(peak-median,0.001),"grade":grade(peak),
		"gaps":out_gaps,"curve":curve(run,out_gaps,yaw,pit),
	}.merged(flow(tk,duration)).merged(threading(tk,solids,duration) if not solids.is_empty() else {})

## The demand curve: every CURVE_STEP s, [t, the gap's demand, flown turn
## share, flown pitch share, the stick held (the larger of turn and pitch)].
static func curve(run: Dictionary, gaps: Array, yaw: PackedFloat32Array, pit: PackedFloat32Array) -> Array:
	var tk: Dictionary = run.ticks
	var t: Array = tk.t
	var n := t.size()
	if n == 0: return []
	var start := float(t[0])
	var out := []
	var next := 0.0
	var g := 0
	for i in range(n):
		var at := float(t[i])-start
		if at+0.0001 < next: continue
		next += CURVE_STEP
		while g < gaps.size()-1 and at > float(gaps[g].to): g += 1
		var d: float = gaps[g].demand if not gaps.is_empty() else 0.0
		var stick := maxf(absf(float(tk.in_turn[i])),absf(float(tk.in_pitch[i])))
		out.append([snappedf(at,0.01),snappedf(d,0.001),snappedf(yaw[i]/TURN_RATE,0.001),snappedf(pit[i]/PITCH_SPEED,0.001),snappedf(stick,0.001)])
	return out

# --- Bands ---------------------------------------------------------------------------

## The band a station lands in, from each skill's share of clean clears
## ({"sloppy": 0.8, ...}): the least skill that clears it, or "broken" if
## none does (not even the perfect reference).
static func band(clears: Dictionary) -> String:
	for s: String in SKILLS:
		if float(clears.get(s,0.0)) >= CLEAR_SHARE: return BANDS[s]
	return "broken"

## How long it takes to reach `token` from the plane (s), less the time it
## needs to swing round to it: the live slack. Negative is too late.
static func slack(position: Vector3, heading: float, pitch: float, speed: float, token: Vector3) -> float:
	var d := token-position
	var want := angles(d)
	var turn := absf(angle_difference(heading,want.x))
	var climb := absf(want.y-pitch)
	return d.length()/maxf(speed,1.0)-(turn/TURN_RATE+climb/PITCH_SPEED+(ROLL_IN if turn > 0.05 else 0.0))

# --- Threading -----------------------------------------------------------------------

## Does a ray from `from` along unit `dir` meet solid `s` within `length` m?
## Exact for the course's boxes and upright cylinders.
static func ray_hits(s: Dictionary, from: Vector3, dir: Vector3, length: float) -> bool:
	var lo := 0.0
	var hi := length
	if s.kind == "box":
		var b: Basis = s.basis
		var inv := b.transposed()
		var o: Vector3 = inv*(from-(s.middle as Vector3))
		var d: Vector3 = inv*dir
		var half: Vector3 = (s.size as Vector3)*0.5
		for a in range(3):
			if absf(d[a]) < 1.0e-9:
				if absf(o[a]) > half[a]: return false
				continue
			var t0 := (-half[a]-o[a])/d[a]
			var t1 := (half[a]-o[a])/d[a]
			lo = maxf(lo,minf(t0,t1))
			hi = minf(hi,maxf(t0,t1))
			if lo > hi: return false
		return true
	var m: Vector3 = s.middle
	var r := float(s.radius)
	var half_h := float(s.height)*0.5
	# Up and down: the slab between its caps.
	if absf(dir.y) < 1.0e-9:
		if absf(from.y-m.y) > half_h: return false
	else:
		var t0 := (m.y-half_h-from.y)/dir.y
		var t1 := (m.y+half_h-from.y)/dir.y
		lo = maxf(lo,minf(t0,t1))
		hi = minf(hi,maxf(t0,t1))
		if lo > hi: return false
	# Across: the circle.
	var o := Vector2(from.x-m.x,from.z-m.z)
	var d := Vector2(dir.x,dir.z)
	var a := d.length_squared()
	if a < 1.0e-12: return o.length() <= r
	var bq := o.dot(d)
	var c := o.length_squared()-r*r
	var disc := bq*bq-a*c
	if disc < 0.0: return false
	var root := sqrt(disc)
	lo = maxf(lo,(-bq-root)/a)
	hi = minf(hi,(-bq+root)/a)
	return lo <= hi

## Is the plane at `p`, heading `heading`, threading (see the header)?
static func threading_at(solids: Array, p: Vector3, heading: float) -> bool:
	var ahead := forward(heading,0.0)
	var right := ahead.cross(Vector3.UP).normalized()
	var reach := maxf(THREAD_SIDE,THREAD_UP)
	var left_hit := false
	var right_hit := false
	for s: Dictionary in solids:
		# Far solids skipped: their bounding sphere out of reach.
		var bound := (s.size as Vector3).length()*0.5 if s.kind == "box" else Vector2(float(s.radius),float(s.height)*0.5).length()
		if p.distance_to(s.middle) > bound+reach: continue
		if ray_hits(s,p,Vector3.UP,THREAD_UP): return true
		if not left_hit and ray_hits(s,p,-right,THREAD_SIDE): left_hit = true
		if not right_hit and ray_hits(s,p,right,THREAD_SIDE): right_hit = true
		if left_hit and right_hit: return true
	return false

## A run's threading from its ticks (columns "t", "x", "y", "z", "heading")
## and the station's solids: {threading_share, openings, openings_per_s,
## threading_s}.
static func threading(ticks: Dictionary, solids: Array, duration := -1.0) -> Dictionary:
	var t: Array = ticks.get("t",[])
	var n := t.size()
	var inside := 0
	var openings := 0
	var last_in := -INF
	var span := 0.0
	for i in range(n):
		var p := Vector3(float(ticks.x[i]),float(ticks.y[i]),float(ticks.z[i]))
		if threading_at(solids,p,float(ticks.heading[i])):
			inside += 1
			var at := float(t[i])
			if at-last_in > THREAD_JOIN: openings += 1
			last_in = at
	if duration < 0.0: duration = (float(t[n-1])-float(t[0])) if n > 1 else 0.0
	var share := float(inside)/n if n > 0 else 0.0
	return {"threading_share":snappedf(share,0.001),"openings":openings,"openings_per_s":snappedf(openings/maxf(duration,0.0001),0.001),
		"threading_s":snappedf(share*duration,0.001)}

# --- Flow ----------------------------------------------------------------------------

## The flight direction's yaw and pitch rates (rad/s, signed) at each tick:
## the change over the last FLOW_SMOOTH s (less at the start; 0 on the
## first tick).
static func swing_rates(t: Array, heading: Array, pitch: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := t.size()
	var j := 0
	for i in range(n):
		var now := float(t[i])
		while j < i and float(t[j+1]) <= now-FLOW_SMOOTH+0.00001: j += 1
		var span := now-float(t[j])
		if span <= 0.0:
			out.append(Vector2.ZERO)
			continue
		out.append(Vector2(angle_difference(float(heading[j]),float(heading[i])),float(pitch[i])-float(pitch[j]))/span)
	return out

## A run's flow from its ticks (columns "t", "heading", "pitch"; see the
## header): {still_share, straights, longest_straight, swing_mean,
## yaw_share, swing_reversals_per_s}.
static func flow(ticks: Dictionary, duration := -1.0) -> Dictionary:
	var t: Array = ticks.get("t",[])
	var n := t.size()
	if n < 2: return {"still_share":0.0,"straights":0,"longest_straight":0.0,"swing_mean":0.0,"yaw_share":0.0,"swing_reversals_per_s":0.0}
	if duration < 0.0: duration = float(t[n-1])-float(t[0])
	var rates := swing_rates(t,ticks.heading,ticks.pitch)
	var still := 0
	var straights := 0
	var longest := 0.0
	var spell_from := -1.0
	var swing := 0.0
	var yaw := 0.0
	var pit := 0.0
	var signs := Vector2.ZERO
	var reversed := 0
	var dead := deg_to_rad(FLOW_REVERSE)
	for i in range(n+1):
		var calm := false
		if i < n:
			var r: Vector2 = rates[i]
			var deg := rad_to_deg(r.length())
			swing += deg
			yaw += absf(r.x)
			pit += absf(r.y)
			calm = deg < FLOW_STILL
			if calm: still += 1
			for a in range(2):
				if absf(r[a]) < dead: continue
				if signs[a] != 0.0 and signf(r[a]) != signs[a]: reversed += 1
				signs[a] = signf(r[a])
		# A still spell runs from its first calm tick to the first tick that
		# isn't (or the run's end).
		if calm and spell_from < 0.0: spell_from = float(t[i])
		elif not calm and spell_from >= 0.0:
			var length := (float(t[i]) if i < n else float(t[n-1]))-spell_from
			if length >= FLOW_STRAIGHT-0.00001: straights += 1
			longest = maxf(longest,length)
			spell_from = -1.0
	return {"still_share":snappedf(float(still)/n,0.001),"straights":straights,"longest_straight":snappedf(longest,0.001),
		"swing_mean":snappedf(swing/n,0.01),"yaw_share":snappedf(yaw/(yaw+pit) if yaw+pit > 0.0 else 0.0,0.001),
		"swing_reversals_per_s":snappedf(reversed/maxf(duration,0.0001),0.001)}
