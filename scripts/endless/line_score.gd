class_name LineScore
extends RefCounted
## The line's score (endless flight, the near misses: scripts/endless/near_miss.gd),
## by degree of difficulty and the line's shape. Every number is in TUNE, read
## from scripts/endless/line_tune.json, which tools/line_report.py reads too: it
## re-scores a `--line-log` with the same steps, so keep the two in step.
##
## - Moment = base[kind] x band[band] x Close x Fast x Knife x Low x Under
##   (x hold for a held move, x farm_same for the same tree or patch again).
##   Each factor ramps from 1 (ordinary) to its cap:
##   Close: k (1 - clearance over the channel's reach) ^ close_pow to close_cap;
##   Fast: speed from level cruise to top (Boost's held speed) to fast_cap;
##   Knife: bank from knife_from to knife_to degrees to knife_cap;
##   Low: height over the land from low_from to low_to m to low_cap;
##   Under: under (a passage under a span or roof).
## - Run: moments of one kind and surface in a row, each within run_gap s of the
##   last (one closer than run_echo s to the last is the same pass, paid but not
##   counted). From run_min moments on it pays run_scale x n^run_pow x its moments'
##   average Fast on top of them.
## - Flourish: a moment of another kind or surface than the line's last run of
##   flourish_min_run or more (moments between, a stray pull-out, don't matter),
##   its factor product over flourish_margin x that run's average: the line's
##   multiplier steps up flourish_step (to line_cap), on everything in the line
##   since it began. One flourish a run.
## - Line: first moment to the chain's break: (moments + run bonuses) x multiplier.
## Units: the score's own (an easy line about 4-5, a hard one about 40); the game's
## points are points_per_unit times them.

const TUNE_PATH := "res://scripts/endless/line_tune.json"
const FACTORS := ["close","fast","knife","low","under"]
const TAGS := {"close":"CLOSE","fast":"FAST","knife":"KNIFE","low":"LOW","under":"UNDER"}

static var _tune := {}

## The tuning (line_tune.json), read once.
static func tune() -> Dictionary:
	if _tune.is_empty():
		var text := FileAccess.get_file_as_string(TUNE_PATH)
		var data: Variant = JSON.parse_string(text)
		if data is Dictionary: _tune = data
		else: push_error("line_score: can't read %s" % TUNE_PATH)
	return _tune

static func _ramp(x: float, from: float, to: float, cap: float) -> float:
	if is_equal_approx(from,to): return 1.0
	return 1.0+(cap-1.0)*clampf((x-from)/(to-from),0.0,1.0)

## A moment's factors from its raw values {k, speed, cruise, top, roll_deg,
## height, under}: {close, fast, knife, low, under, product}.
static func factors(r: Dictionary) -> Dictionary:
	var t := tune()
	var k := clampf(float(r.k),0.0,1.0)
	var f := {}
	f.close = 1.0+(float(t.close_cap)-1.0)*pow(k,float(t.close_pow))
	f.fast = _ramp(float(r.speed),float(r.cruise),float(r.top),float(t.fast_cap))
	var bank := minf(absf(float(r.roll_deg)),90.0)
	f.knife = _ramp(bank,float(t.knife_from),float(t.knife_to),float(t.knife_cap))
	f.low = _ramp(float(r.height),float(t.low_from),float(t.low_to),float(t.low_cap))
	f.under = float(t.under) if bool(r.under) else 1.0
	var p := 1.0
	for n: String in FACTORS: p *= float(f[n])
	f.product = p
	return f

## The moment's units: base x band x the factors x hold x farm.
static func moment_units(kind: String, band: String, f: Dictionary, hold: float, farm: float) -> float:
	var t := tune()
	var base: Dictionary = t.base
	return float(base.get(kind,base.default))*float((t.band as Dictionary).get(band,1.0))*float(f.product)*hold*farm

## The factors' tags worth showing (over tag_min), the biggest first, at most `most`.
static func tags(f: Dictionary, most := 2) -> Array:
	var t := tune()
	var names: Array = []
	for n: String in FACTORS:
		if float(f[n]) > float(t.tag_min): names.append(n)
	names.sort_custom(func(a: String, b: String) -> bool: return float(f[a]) > float(f[b]))
	var out: Array = []
	for n: String in names.slice(0,most): out.append(TAGS[n])
	return out

## A run's bonus (units).
static func run_bonus(n: int, sum_fast: float) -> float:
	var t := tune()
	if n < int(t.run_min): return 0.0
	return float(t.run_scale)*pow(float(n),float(t.run_pow))*sum_fast/float(n)

## One line under way.
class Line:
	var units := 0.0
	var mult := 1.0
	var count := 0
	## Runs in order: {kind, surface, n, sum_fast, sum_product, last_t}.
	var runs: Array[Dictionary] = []

	## Adds a moment {kind, surface, t, units, fast, product}; returns {run (its
	## index), run_n, flourish, step}.
	func add(m: Dictionary) -> Dictionary:
		var t: Dictionary = LineScore.tune()
		var kind := str(m.kind)
		var surface := str(m.surface)
		var tt := float(m.t)
		var flourish := false
		var step := 0.0
		var last: Dictionary = runs[-1] if not runs.is_empty() else {}
		var same := not last.is_empty() and str(last.kind) == kind and str(last.surface) == surface
		if same and tt-float(last.last_t) <= float(t.run_echo):
			# The same pass met twice (a trunk and its crown): one in the run.
			last.last_t = tt
		elif same and tt-float(last.last_t) <= float(t.run_gap):
			last.n = int(last.n)+1
			last.sum_fast = float(last.sum_fast)+float(m.fast)
			last.sum_product = float(last.sum_product)+float(m.product)
			last.last_t = tt
		else:
			# The line's last run of flourish_min_run or more, its flourish unspent.
			var ref := {}
			for i in range(runs.size()-1,-1,-1):
				if int(runs[i].n) >= int(t.flourish_min_run):
					ref = runs[i]
					break
			if not ref.is_empty() and not bool(ref.get("spent",false)) and (str(ref.kind) != kind or str(ref.surface) != surface):
				var avg := float(ref.sum_product)/float(ref.n)
				if float(m.product) > avg*float(t.flourish_margin):
					flourish = true
					ref.spent = true
					var was := mult
					mult = minf(mult+float(t.flourish_step),float(t.line_cap))
					step = mult-was
			runs.append({"kind":kind,"surface":surface,"n":1,"sum_fast":float(m.fast),"sum_product":float(m.product),"last_t":tt})
		units += float(m.units)
		count += 1
		return {"run":runs.size()-1,"run_n":int(runs[-1].n),"flourish":flourish,"step":step}

	## Moments and run bonuses, before the multiplier (units).
	func raw() -> float:
		var r := units
		for run: Dictionary in runs: r += LineScore.run_bonus(int(run.n),float(run.sum_fast))
		return r

	func total() -> float:
		return raw()*mult

	## The live run's label (TREES x7) when it is run_min or longer and `now` is
	## within run_gap of its last moment; "" otherwise.
	func run_label(now: float) -> String:
		if runs.is_empty(): return ""
		var t: Dictionary = LineScore.tune()
		var run: Dictionary = runs[-1]
		if int(run.n) < int(t.run_min) or now-float(run.last_t) > float(t.run_gap): return ""
		return "%s ×%d" % [_name(str(run.kind),str(run.surface)),int(run.n)]

	static func _name(kind: String, surface: String) -> String:
		if kind == "graze": return {"tree":"TREES","stone":"STONE","land":"LAND","water":"WAVES"}.get(surface,"GRAZES")
		if kind == "thread": return "ARCHES" if surface == "stone" else "THREADS"
		if kind == "pull-out": return "SKIPS" if surface == "water" else "PULL-OUTS"
		return kind.to_upper()
