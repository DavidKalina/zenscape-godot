#!/usr/bin/env python3
"""Build a RuinKit piece without re-exploring the kit.

  python tools/kit_piece.py new <id> --family <family> [--name "Display name"] [--file <stem>]
  python tools/kit_piece.py numbers          # the sizing numbers, read live from the code
  python tools/kit_piece.py recipe           # how a piece is built (tools/kit_piece_recipe.md)
  python tools/kit_piece.py yard <id> [--seed N --weathered W]   # shot.py / drive.py lines
  python tools/kit_piece.py check <id> [--shots] [--seed N --weathered W]

`new` writes scripts/ruin_kit_<stem>.gd (stem: the id) from a stub and
registers it with additive edits: a <STEM>_PIECES const, FAMILIES (new
family or appended), ALL_PIECES, NAMES and the `piece` dispatch line in
scripts/ruin_kit.gd, and a connector arm in scripts/ruin_kit_fit.gd. It
refuses to overwrite a file and skips any edit already made. `check` runs
the editor round trip, tests/test_ruin_kit.gd and three smokes, one line
each, and exits 1 on any failure. Headless, except `--shots` (one window).
"""
import argparse
import re
import subprocess
import sys
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "scripts" / "ruin_kit.gd"
FIT = ROOT / "scripts" / "ruin_kit_fit.gd"
RECIPE = ROOT / "tools" / "kit_piece_recipe.md"
YARD = "studies/kit_piece_yard.tscn"
PY = sys.executable
LOGS = ROOT / "scratch" / "kit_piece"
EXIT_LEAK = re.compile(r"at exit|leaked at exit|still in use at exit|Pages in use")

TEMPLATE = '''extends RefCounted
## {name} ({id}), of the ruin kit's {family} family (scripts/ruin_kit.gd: the
## same stone, wear and growth). Scaffolded by tools/kit_piece.py new: the
## stub block below stands in until the piece is built
## (tools/kit_piece_recipe.md; sizes from `python tools/kit_piece.py numbers`).
## Pieces by id (RuinKit {const}, `piece`), each the kit's: a Node3D, its
## foot on y 0 round the origin, front toward +Z, "Mesh" and "Body".

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build

## The pieces built by id here (RuinKit {const}).
const PIECES := ["{id}"]

## The stub block's half size (m): its top one set-off up (a jump catches
## it), deep enough to stand on and walk along.
const HALF := Vector3(1.6,RuinKit.SET_OFF*0.5,1.2)

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"{id}": return {fn}(seed_value,weathered)
	return null

## {name}: (stub) one worn block on the turf, walked on a clean box.
## Meta: "top" (its walked top, m).
static func {fn}(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"{label}")
	var pose := RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3(0.0,HALF.y,0.0)),0.2)
	b.solid(RuinKit._box(b,HALF,0.04),pose,RuinKit._stone(b,0.95),false,true)
	RuinKit._walk_box(b,Transform3D.IDENTITY,HALF.x,0.0,HALF.y*2.0,HALF.z,-HALF.z)
	b.tuft(Vector3(HALF.x+0.3,0.0,HALF.z*0.5),0.3)
	RuinKit._drift(b,Vector3(HALF.x+0.7,0.0,0.0),0.9,int(round(weathered*4.0)))
	var node := b.finish()
	node.set_meta("top",HALF.y*2.0)
	return node
'''

FIT_ARM = '''		"{id}":
			# Stub (tools/kit_piece.py new): something stands on its top.
			return [_c("top",Vector3(0.0,top_of.call(RuinKit.SET_OFF),0.0),Vector3.UP,"top","top")]
'''


def say(line):
    print(line, flush=True)


# --- new ------------------------------------------------------------------------

def cmd_new(a):
    pid = a.id
    if not re.fullmatch(r"[a-z][a-z0-9_]*", pid):
        sys.exit(f"id '{pid}': lower_snake_case only")
    fam = a.family
    stem = a.file or pid
    const = stem.upper() + "_PIECES"
    name = a.name or pid.replace("_", " ").capitalize()
    fn = pid
    label = "".join(w.capitalize() for w in pid.split("_"))
    path = ROOT / "scripts" / f"ruin_kit_{stem}.gd"
    res = f"res://scripts/ruin_kit_{stem}.gd"
    kit = KIT.read_text()
    fit = FIT.read_text()
    done = []

    if path.exists():
        body = path.read_text()
        if f'"{pid}"' not in body:
            sys.exit(f"{path.relative_to(ROOT)} exists and doesn't build '{pid}': refusing to clobber (pass --file)")
        done.append(f"kept   {path.relative_to(ROOT)} (exists)")
    else:
        if re.search(rf'"{pid}"\s*:', kit):
            sys.exit(f"'{pid}' is already in RuinKit.NAMES but {path.relative_to(ROOT)} is missing: refusing")
        path.write_text(TEMPLATE.format(id=pid, name=name, family=fam, const=const, fn=fn, label=label))
        done.append(f"wrote  {path.relative_to(ROOT)}")

    # The family's piece list const, before FAMILIES.
    if re.search(rf"^const {const} :?=", kit, re.M):
        done.append(f"kept   {const}")
    else:
        kit = re.sub(r"^const FAMILIES :?=", f'## {name} ({res[6:]}).\nconst {const} := ["{pid}"]\nconst FAMILIES :=', kit, count=1, flags=re.M)
        done.append(f"added  {const}")
    # FAMILIES.
    m = re.search(r"^const FAMILIES :?= \{(.*)\}$", kit, re.M)
    fams = m.group(1)
    if re.search(rf"\b{const}\b", fams):
        done.append("kept   FAMILIES")
    else:
        fm = re.search(rf'"{re.escape(fam)}":([^,}}]+)', fams)
        if fm:
            fams = fams[:fm.end(1)] + "+" + const + fams[fm.end(1):]
        else:
            fams = fams + f',"{fam}":{const}'
        kit = kit[:m.start(1)] + fams + kit[m.end(1):]
        done.append(f"added  FAMILIES \"{fam}\"" + ("" if fm else " (new family)"))
    # ALL_PIECES.
    m = re.search(r"^const ALL_PIECES :?= (.*)$", kit, re.M)
    if re.search(rf"\b{const}\b", m.group(1)):
        done.append("kept   ALL_PIECES")
    else:
        kit = kit[:m.end(1)] + "+" + const + kit[m.end(1):]
        done.append("added  ALL_PIECES")
    # NAMES: the dict's closing brace.
    if re.search(rf'"{pid}":"', kit):
        done.append("kept   NAMES")
    else:
        start = kit.index("const NAMES :=")
        end = kit.index("}\n", start)
        kit = kit[:end] + f',"{pid}":"{name}"' + kit[end:]
        done.append("added  NAMES")
    # The dispatch line in `piece`.
    line = f'\tif id in {const}: return load("{res}").piece(id,seed_value,weathered)\n'
    if line in kit:
        done.append("kept   piece dispatch")
    else:
        start = kit.index("static func piece(id: String")
        ret = kit.index("\treturn null\n", start)
        kit = kit[:ret] + line + kit[ret:]
        done.append("added  piece dispatch")
    KIT.write_text(kit)

    # The connector stub arm.
    if re.search(rf'^\t\t"{pid}":', fit, re.M):
        done.append("kept   connectors arm")
    else:
        start = fit.index("static func connectors(")
        ret = fit.index("\treturn []\n", start)
        fit = fit[:ret] + FIT_ARM.format(id=pid) + fit[ret:]
        FIT.write_text(fit)
        done.append("added  connectors arm (ruin_kit_fit.gd)")
    for d in done:
        say(d)
    say(f"next: python tools/kit_piece.py check {pid}   (then build the piece in {path.relative_to(ROOT)})")


# --- numbers / recipe / yard ----------------------------------------------------------

def cmd_numbers(_a):
    r = subprocess.run([PY, "tools/godot.py", "-s", "tools/kit_piece_numbers.gd"], cwd=ROOT, capture_output=True, text=True)
    out = [ln[4:] if ln.startswith("NUM ") else ln for ln in r.stdout.splitlines() if ln.startswith(("NUM ", "== ")) and "godot exit" not in ln]
    print("\n".join(out))
    if r.returncode != 0 or not out:
        print(r.stdout[-2000:] + r.stderr[-2000:])
        sys.exit(1)


def cmd_recipe(_a):
    print(RECIPE.read_text())


def yard_flags(a):
    return f"--piece={a.id} --seed={a.seed} --weathered={a.weathered}"


def cmd_yard(a):
    f = yard_flags(a)
    print(f"""yard: {YARD}  (studies/kit_piece_yard.gd; the piece is node "Piece" at the origin, front +Z)
smoke:  python tools/smoke.py {YARD} -- {f}
stills: python tools/shot.py {YARD} --frame Piece --view three,front,left,top --sheet --out captures/shots/{a.id} -- --no-title {f}
walker: python tools/shot.py {YARD} --frame walker --view three -- --no-title {f}
drive:  cp tools/harness/examples/kit_piece_drive.gd scratch/{a.id}_drive.gd
        python tools/drive.py scratch/{a.id}_drive.gd -- --scene-args {f}
play:   python tools/godot.py --rendered {YARD} -- --no-title {f}""")


# --- check ------------------------------------------------------------------------

def run(cmd, timeout=600):
    try:
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired as e:
        return 124, (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")


def tail(out, n=6):
    keep = [ln for ln in out.splitlines() if re.search(r"FAIL|ERROR|error|Error", ln) and "0 errors" not in ln]
    return "\n".join("     " + ln.strip()[:200] for ln in keep[:n])


def cmd_check(a):
    pid = a.id
    jobs = {
        "editor": [PY, "tools/drive.py", "tools/harness/kit_piece_editor.gd", "--log", str(LOGS / f"{pid}_editor.log"), "--", f"--id={pid}"],
        "test_ruin_kit": [PY, "tools/run_tests.py", "--tests", "test_ruin_kit.gd", "-j", "1"],
        "smoke motif_editor": [PY, "tools/smoke.py", "studies/motif_editor.tscn"],
        "smoke editor_aqueduct_gorge": [PY, "tools/smoke.py", "studies/motif_yard.tscn", "--", "--motif=editor_aqueduct_gorge"],
        "smoke bell_spires": [PY, "tools/smoke.py", "studies/motif_yard.tscn", "--", "--motif=bell_spires"],
        "smoke yard": [PY, "tools/smoke.py", YARD, "--"] + yard_flags(a).split(),
    }
    LOGS.mkdir(parents=True, exist_ok=True)
    # The import first (godot.py locks it), so the parallel runs don't race it.
    run([PY, "tools/godot.py", "-s", "tools/kit_piece_numbers.gd"], 600)
    results = {}

    def go(k, cmd):
        results[k] = run(cmd)

    threads = [threading.Thread(target=go, args=(k, c)) for k, c in jobs.items()]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    failed = 0
    code, out = results.pop("editor")
    for ln in out.splitlines():
        m = re.match(r"(OK|FAIL)\s+(.*)", ln)
        if m:
            label = m.group(2).split(":")[0]
            say(f"{'PASS' if m.group(1) == 'OK' else 'FAIL'} editor: {label}" + ("" if m.group(1) == "OK" else f"  ({m.group(2)[len(label) + 1:].strip()[:160]})"))
            failed += m.group(1) == "FAIL"
    log = LOGS / f"{pid}_editor.log"
    errors = [ln for ln in (log.read_text().splitlines() if log.exists() else []) if ln.startswith(("ERROR", "SCRIPT ERROR"))]
    if code != 0 and not failed and errors and all(EXIT_LEAK.search(ln) for ln in errors):
        # Every check passed and the only errors are the engine's at-exit
        # leak report (intermittent; drive.py doesn't drop "Pages in use").
        say(f"PASS editor: exit (at-exit leak lines only: {len(errors)}, log {log.relative_to(ROOT)})")
    elif code != 0 and not failed:
        failed += 1
        say(f"FAIL editor round trip (exit {code}; log {log.relative_to(ROOT)})\n{tail(log.read_text() if log.exists() else out)}")
    for k, (code, out) in results.items():
        ok = code == 0
        failed += not ok
        say(f"{'PASS' if ok else 'FAIL'} {k}" + ("" if ok else f" (exit {code})\n{tail(out)}"))
    if a.shots:
        f = yard_flags(a)
        code, out = run([PY, "tools/shot.py", YARD, "--frame", "Piece", "--view", "three,front,left,top", "--sheet",
                         "--out", f"captures/shots/{pid}", "--", "--no-title"] + f.split(), 400)
        sheets = re.findall(r"\S*sheet\S*\.png", out)
        failed += code != 0
        say(f"{'PASS' if code == 0 else 'FAIL'} shots: {sheets[-1] if sheets else 'captures/shots/' + pid + '_*.png'}" + ("" if code == 0 else f"\n{tail(out)}"))
    say(f"== check {pid}: {'all passed' if not failed else f'{failed} failed'}")
    sys.exit(1 if failed else 0)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new")
    n.add_argument("id")
    n.add_argument("--family", required=True)
    n.add_argument("--name")
    n.add_argument("--file", help="file stem: scripts/ruin_kit_<stem>.gd and its <STEM>_PIECES (default: the id)")
    sub.add_parser("numbers")
    sub.add_parser("recipe")
    for name in ("yard", "check"):
        s = sub.add_parser(name)
        s.add_argument("id")
        s.add_argument("--seed", type=int, default=3)
        s.add_argument("--weathered", type=float, default=0.4)
        if name == "check":
            s.add_argument("--shots", action="store_true", help="a rendered still sheet from the yard (one window)")
    a = p.parse_args()
    {"new": cmd_new, "numbers": cmd_numbers, "recipe": cmd_recipe, "yard": cmd_yard, "check": cmd_check}[a.cmd](a)


if __name__ == "__main__":
    main()
