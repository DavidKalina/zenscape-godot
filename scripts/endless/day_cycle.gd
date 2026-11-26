extends RefCounted
## Endless flight's day cycle (docs/design/endless-flight/day-cycle-handoff.md):
## dawn, day, dusk and a short blue hour in about LENGTH seconds, then round
## again. It owns the sun's phase (scripts/shared/celestial.gd `phase`, a
## turn of the sun's ring, 0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset)
## as a time `t` seconds into the cycle.
##
## The pace: the ring is cut into PARTS by the ring's sun height (before the
## night floor), each given its seconds; the rate (seconds per turn of phase)
## is even inside a part and eased between parts (BLEND), so the sun never
## visibly changes pace, and the parts' seconds are held after the easing.
## Most of the clock goes to the day and the low sun: golden hour and
## sunrise linger, the turn under the horizon (the blue hour, with the
## celestial's night floor holding the sun just below it) is quick.

const Celestial = preload("res://scripts/shared/celestial.gd")

## Seconds for one full cycle (--day-length=S).
## (1200 with the high sun's part at 540 s; trimmed to 240 s on 2026-11-25,
## so the low sun's light comes about 4 minutes into a flight, not 9.)
const LENGTH := 900.0
## How deep the sun sinks (celestial `night_floor`): the deepest blue hour.
const FLOOR := 0.1
## The parts, in order round the ring from the blue hour's end: [name, the
## ring's sun height it ends at, rising (true) or setting, seconds at LENGTH].
## The blue hour runs from the afterglow's end (BLUE of ring height under
## the horizon, setting) round to the same height rising.
const BLUE := 0.10
const GOLDEN := 0.42
const PARTS := [
	["twilight", 0.0, true, 70.0],
	["sunrise", GOLDEN, true, 150.0],
	["day", GOLDEN, false, 240.0],
	["golden hour", 0.0, false, 210.0],
	["afterglow", -BLUE, false, 100.0],
	["blue hour", -BLUE, true, 130.0],
]
## The ease between parts' paces, as a share of the ring (each side).
const BLEND := 0.006
## The stops T and --day-at= go to: [name, ring sun height, rising] or a
## phase (noon, the blue hour's deepest).
const STOPS := [["dawn", -0.05, true], ["noon", 0.5], ["dusk", 0.15, false], ["blue", 0.0]]
## T's sweep: the time left to its stop shrinks by this rate (per second).
const SWEEP := 1.6
## The speeds `faster` and `slower` step through.
const SPEEDS := [1.0, 8.0, 30.0, 120.0]
const STEPS := 4096

## Seconds per cycle.
var length := LENGTH
## Seconds into the cycle (0 at the sun's midnight, phase 0).
var t := 0.0
## The clock runs (false: --hour=H, --day=0; T still sweeps to its stops).
var running := true
## Days gone round (each time `t` passes the sun's midnight): the wind's
## day temper (wind_field.gd) rolls per day.
var day := 0
## Held for now (the menu, a driver), whatever `running` says.
var held := false
## SPEEDS index.
var speed_step := 0
var _skip := -1.0

## The share of the cycle (0..1) at each of STEPS+1 phases (0..1).
static var _table := PackedFloat32Array()

func _init(seconds := LENGTH) -> void:
	length = maxf(seconds, 1.0)
	if _table.is_empty(): _table = build_table()

## The cycle's speed (1, 8, 30...).
func speed() -> float:
	return float(SPEEDS[speed_step])

func faster() -> void:
	speed_step = mini(speed_step + 1, SPEEDS.size() - 1)

func slower() -> void:
	speed_step = maxi(speed_step - 1, 0)

## Whether time moves this frame (running or sweeping to a stop).
func moving() -> bool:
	return not held and (running or _skip >= 0.0)

func advance(delta: float) -> void:
	if held: return
	var step := delta * speed() if running else 0.0
	if _skip >= 0.0:
		var gap := fposmod(_skip - t, length)
		var sweep := gap * (1.0 - exp(-delta * SWEEP))
		if gap - maxf(step, sweep) < length * 0.0004 or gap > length - length * 0.0004:
			if _skip < t: day += 1
			t = _skip
			_skip = -1.0
			return
		step = maxf(step, sweep)
	if t + step >= length: day += 1
	t = fposmod(t + step, length)

## The sun's phase now.
func phase() -> float:
	return phase_at(t / length)

## Put the clock on the phase `p` (no sweep).
func set_phase(p: float) -> void:
	t = share_of(p) * length
	_skip = -1.0

## Keep the clock on the look's phase while it stands still (a mood's hour,
## a region's), so the next sweep or start runs on from it.
func follow(p: float) -> void:
	if _skip < 0.0 and absf(wrapf(phase() - p, -0.5, 0.5)) > 1e-5: t = share_of(p) * length

## The next stop (STOPS) ahead in time, swept to.
func next_stop() -> void:
	var from := _skip if _skip >= 0.0 else t
	var best := INF
	for s: Array in STOPS:
		var gap := fposmod(share_of(stop_phase(s)) * length - from, length)
		if gap > length * 0.01 and gap < best:
			best = gap
	if best < INF: _skip = fposmod(from + best, length)

## Straight to stop `name` (dawn, noon, dusk, blue), or false.
func go_to(name: String) -> bool:
	for s: Array in STOPS:
		if s[0] == name:
			set_phase(stop_phase(s))
			return true
	return false

static func stop_phase(s: Array) -> float:
	return float(s[1]) if s.size() == 2 else ring_phase(float(s[1]), bool(s[2]))

## The part of the day now (PARTS' names).
func part() -> String:
	return part_of(phase())

static func part_of(p: float) -> String:
	var bounds := part_phases()
	var u := fposmod(p - bounds[bounds.size() - 1], 1.0)
	for i in PARTS.size():
		if u < fposmod(bounds[i] - bounds[bounds.size() - 1], 1.0): return str(PARTS[i][0])
	return str(PARTS[PARTS.size() - 1][0])

## Seconds each part lasts at `seconds` a cycle, as eased: {name: s}.
static func part_seconds(seconds := LENGTH) -> Dictionary:
	var table := _table if not _table.is_empty() else build_table()
	var bounds := part_phases()
	var out := {}
	for i in PARTS.size():
		var a := _share(table, bounds[(i + PARTS.size() - 1) % PARTS.size()])
		var b := _share(table, bounds[i])
		out[PARTS[i][0]] = fposmod(b - a, 1.0) * seconds
	return out

# --- The ring ------------------------------------------------------------------------

## The sun ring's tilt, as celestial.setup makes it.
static func tilt() -> float:
	var elevation := asin(14.0 / Vector3(20, 14, 12).length())
	return PI / 2.0 - clampf(elevation + 0.32, 0.7, 1.08)

## The ring's sun height at phase p (before the night floor).
static func ring_height(p: float) -> float:
	return sin((p - 0.25) * TAU) * cos(tilt())

## The phase (0..1) where the ring's sun stands `height` high, rising or setting.
static func ring_phase(height: float, rising: bool) -> float:
	var a := asin(clampf(height / cos(tilt()), -1.0, 1.0))
	return fposmod(0.25 + (a if rising else PI - a) / TAU, 1.0)

## Each part's end phase.
static func part_phases() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: Array in PARTS: out.append(ring_phase(float(p[1]), bool(p[2])))
	return out

# --- The pace table ------------------------------------------------------------------

## The cycle's share at each phase step: each part's seconds spread evenly
## over its phases, eased between parts (three box passes, BLEND wide), then
## each part's weight trimmed until its eased seconds are its own.
static func build_table() -> PackedFloat32Array:
	var bounds := part_phases()
	var part_at := PackedInt32Array()
	part_at.resize(STEPS)
	for i in STEPS:
		var u := (float(i) + 0.5) / STEPS
		var rel := fposmod(u - bounds[bounds.size() - 1], 1.0)
		var k := PARTS.size() - 1
		for j in PARTS.size():
			if rel < fposmod(bounds[j] - bounds[bounds.size() - 1], 1.0):
				k = j
				break
		part_at[i] = k
	var want := PackedFloat32Array()
	var total := 0.0
	for p: Array in PARTS: total += float(p[3])
	for p: Array in PARTS: want.append(float(p[3]) / total)
	var weight := PackedFloat32Array(want)
	var w := PackedFloat32Array()
	w.resize(STEPS)
	var radius := maxi(1, int(BLEND * STEPS / 1.5))
	for _r in 8:
		# Each part's share spread over its steps.
		var counts := PackedInt32Array()
		counts.resize(PARTS.size())
		for i in STEPS: counts[part_at[i]] += 1
		for i in STEPS: w[i] = weight[part_at[i]] / maxf(float(counts[part_at[i]]), 1.0)
		for _p in 3: w = _box(w, radius)
		var got := PackedFloat32Array()
		got.resize(PARTS.size())
		for i in STEPS: got[part_at[i]] += w[i]
		for j in PARTS.size(): weight[j] *= want[j] / maxf(got[j], 1e-9)
	var table := PackedFloat32Array()
	table.resize(STEPS + 1)
	var sum := 0.0
	for i in STEPS: sum += w[i]
	var run := 0.0
	for i in STEPS:
		table[i] = run / sum
		run += w[i]
	table[STEPS] = 1.0
	return table

static func _box(w: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var n := w.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var acc := 0.0
	for k in range(-r, r + 1): acc += w[posmod(k, n)]
	for i in n:
		out[i] = acc / float(2 * r + 1)
		acc += w[posmod(i + r + 1, n)] - w[posmod(i - r, n)]
	return out

## The cycle's share (0..1) at phase p.
func share_of(p: float) -> float:
	return _share(_table, p)

static func _share(table: PackedFloat32Array, p: float) -> float:
	var x := fposmod(p, 1.0) * STEPS
	var i := mini(int(x), STEPS - 1)
	return lerpf(table[i], table[i + 1], x - float(i))

## The phase at share u (0..1) of the cycle.
func phase_at(u: float) -> float:
	u = fposmod(u, 1.0)
	var low := 0
	var high := STEPS
	while high - low > 1:
		var mid := (low + high) / 2
		if _table[mid] <= u: low = mid
		else: high = mid
	var span := _table[high] - _table[low]
	var f := 0.0 if span <= 0.0 else clampf((u - _table[low]) / span, 0.0, 1.0)
	return (float(low) + f) / STEPS
