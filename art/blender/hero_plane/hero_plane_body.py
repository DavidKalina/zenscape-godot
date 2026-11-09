"""Build a body the shop sells, on the hero plane's pipeline.

    python3 tools/blender.py run art/blender/hero_plane/hero_plane_body.py -- --body=highwing [--fast]
    python3 tools/blender.py run art/blender/hero_plane/hero_plane_body.py -- --body=racer [--fast]

Imports hero_plane_build.py as a module, changes the shape constants and swaps
the builders a body changes (wings, struts, glazing, fittings, gear), then runs
its own build, paint and export. The HOLDS stay the hero's: span, chord, the
prop, the wheels, the skid, the tail and fin (the ribbon hangs off the rudder),
so the flight, the landing and the world's openings read any body the same.
The node names and the materials (hero, glass, wire) are the hero's, so
scripts/plane_figure.gd drives and repaints any body; the materials point at
the hero's shaders and at this body's own atlas.

Writes assets/models/<body>/<body>.glb, <body>_albedo.jpg, _normal.jpg,
_mask.png, _orm.png, hero.tres, wire.tres, glass.tres and the .import files.

  highwing  a cabin monoplane: one wing on the cabin roof, V struts to the
            lower longerons, glazed windscreen and side windows.
  racer     a barrel racer: a fat round body behind the radial, one low wing,
            a small bubble on a high headrest deck, spats over the wheels,
            landing and flying wires.
"""
import math
import sys
from pathlib import Path

from mathutils import Vector

import hero_plane_build as H

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BODY_ID = next((a.split("=", 1)[1] for a in ARGV if a.startswith("--body=")), "")
if BODY_ID not in ("highwing", "racer"):
	raise SystemExit("hero_plane_body.py: --body=highwing or --body=racer")

HERO_RES = "res://assets/models/hero_plane"
H.TEX = H.ROOT / "assets/models" / BODY_ID
H.OUT = H.TEX / (BODY_ID + ".glb")
H.RES = "res://assets/models/" + BODY_ID

# The hero's tail from the fin forward of the post: every body ends the same,
# so the tailplane, fin, skid and ribbon sit where they did.
TAIL_ROWS = (
	(0.530, 0.050, 0.104, -0.052),
	(0.620, 0.033, 0.080, -0.026),
	(0.690, 0.016, 0.066, -0.006),
	(0.725, 0.004, 0.058, 0.014),
)


# --- Shared pieces -------------------------------------------------------------

def wing_only(g, ail):
	"""The hero's upper wing and its ailerons alone, at UPPER_Y: one wing."""
	le_up = H.STAGGER - H.CHORD * 0.5
	for side in (-1.0, 1.0):
		xs = H.rib_x(H.SPAN * 0.5, H.RIBS_UP, 0.0)
		xs += [H.AIL[0] - 0.0005, H.AIL[0] + 0.0005, H.AIL[1] - 0.0005, H.AIL[1] + 0.0005]
		xs = sorted(set(round(x, 5) for x in xs))
		st = []
		for x in xs:
			s = H.wing_station(H.SPAN * 0.5, H.RIBS_UP, x * side, le_up, H.UPPER_Y, side)
			if H.AIL[0] < x < H.AIL[1]:
				s["hi"] = H.AIL_H
			st.append(s)
		fade = lambda p: 1.0 - 0.3 * max(0.0, 1.0 - abs(p[0]) / 0.17) ** 2
		H.panel(g, st, H.wing_uv("up_top", le_up), H.wing_uv("up_under", le_up), col=fade, cap_root=False)
		h = ail[side]
		xs = sorted(set([H.AIL[0] + 0.003] + [x for x in H.rib_x(H.SPAN * 0.5, H.RIBS_UP, 0.0) if H.AIL[0] + 0.004 < x < H.AIL[1] - 0.004] + [H.AIL[1] - 0.003]))
		st = []
		for x in xs:
			s = H.wing_station(H.SPAN * 0.5, H.RIBS_UP, x * side, le_up, H.UPPER_Y, side)
			s["lo"] = H.AIL_H + 0.004
			st.append(s)
		H.panel(h, st, H.wing_uv("up_top", le_up), H.wing_uv("up_under", le_up), cap_root="dark", cap_tip="dark", us=(0.0, 0.3, 0.6, 0.85, 1.0))
		for sgn in (1.0, -1.0):
			hx = (H.AIL[0] + 0.07) * side
			hz = le_up + H.CHORD * (H.AIL_H + 0.05)
			H.tube(h, [(hx, H.UPPER_Y, hz), (hx, H.UPPER_Y + 0.034 * sgn, hz - 0.012)], 0.0028, 5, "steel")


def face_out(g, start, centre):
	"""Turns each face since `start` to look away from centre(p) (an open shell
	the volume test in loft can't judge)."""
	for k in range(start, len(g.f)):
		f = g.f[k]
		a, b, c = (Vector(g.v[j]) for j in f[:3])
		n = (b - a).cross(c - a)
		mid = (a + b + c) / 3.0
		if n.dot(mid - Vector(centre(mid))) < 0.0:
			g.f[k] = tuple(reversed(f))
			g.uv[k] = tuple(reversed(g.uv[k]))


def tail_wires(w):
	"""The tailplane's bracing and the control cables, as on the hero."""
	for side in (-1.0, 1.0):
		H.wire(w, (0.004 * side, 0.215, 0.645), (0.13 * side, H.TAIL_Y + 0.008, 0.625), 0.0014)
		H.wire(w, (0.004 * side, 0.02, 0.63), (0.13 * side, H.TAIL_Y - 0.006, 0.625), 0.0014)
		H.wire(w, (0.04 * side, 0.055, 0.5), (0.05 * side, 0.05, H.FIN_HINGE - 0.012), 0.0013)
		H.wire(w, (0.024 * side, 0.098, 0.5), (0.03 * side, H.TAIL_Y + 0.05, H.TAIL_Z + H.TAIL_CHORD * H.ELEV_H - 0.006), 0.0013)
		H.wire(w, (0.024 * side, 0.0, 0.5), (0.03 * side, H.TAIL_Y - 0.05, H.TAIL_Z + H.TAIL_CHORD * H.ELEV_H - 0.006), 0.0013)
		H.wire(w, (0.05 * side, -0.142, -0.4), (H.WHEEL_X * side * 0.2, H.AXLE_Y + 0.006, H.WHEEL_Z), 0.0014)
		H.wire(w, (0.05 * side, -0.145, -0.17), (H.WHEEL_X * side * 0.2, H.AXLE_Y + 0.006, H.WHEEL_Z), 0.0014)


def skid_and_lamps(g):
	"""The tail skid (the strip's rest point), the oil scoop, the tip lamps."""
	sk = H.SKID_TIP
	H.tube(g, [(0.0, 0.0, 0.565), (0.0, -0.05, 0.60), (0.0, -0.1, 0.645), (sk[0], sk[1] + 0.012, sk[2])], [0.0085, 0.0075, 0.0066, 0.0062], 7, "dark", up=(1.0, 0.0, 0.0))
	H.tube(g, [(0.0, -0.105, 0.642), (0.0, sk[1] + 0.004, sk[2]), (0.0, sk[1] + 0.001, sk[2] + 0.018)], [0.0078, 0.0062, 0.0035], 7, "brass", up=(1.0, 0.0, 0.0))
	H.tube(g, [(0.0, 0.005, 0.62), (0.0, -0.075, 0.625)], 0.0042, 6, "dark", up=(1.0, 0.0, 0.0))
	s = H.sw("trim")
	rings = []
	for z, ww, dd in zip((-0.44, -0.40, -0.34, -0.27, -0.21), (0.03, 0.05, 0.056, 0.05, 0.01), (0.004, 0.02, 0.028, 0.02, 0.002)):
		yb = H.body_section(z)[2] + 0.006
		rings.append([(math.cos(k * math.tau / 10) * ww, yb - dd + math.sin(k * math.tau / 10) * dd, z) for k in range(10)])
	H.loft(g, rings, lambda i, k: s(i * 0.25, k / 10.0), True, True, True)
	for side, name in ((-1.0, "red"), (1.0, "green")):
		x = H.SPAN * 0.5 - 0.022
		z = H.STAGGER + 0.045
		H.tube(g, [(x * side, H.UPPER_Y + 0.003, z - 0.012), (x * side, H.UPPER_Y + 0.003, z + 0.012)], [0.0015, 0.004], 6, name)


def body_patch(g, z0, z1, t0, t1, out, swatch, nz=8, nt=8):
	"""A patch of the body's skin from z0 to z1, round from t0 to t1 (0 on top,
	+ the right), stood `out` off it: a window's glass or the dark behind it."""
	f = H.sw(swatch)
	rings = []
	for i in range(nz + 1):
		z = z0 + (z1 - z0) * i / nz
		hw, top, bot = H.body_section(z)
		mid = (top + bot) * 0.5
		ring = []
		for k in range(nt + 1):
			p = H.body_point(z, t0 + (t1 - t0) * k / nt)
			ax = Vector((0.0, mid, z))
			ring.append(tuple(ax + (p - ax) * (1.0 + out)))
		rings.append(ring)
	start = len(g.f)
	H.loft(g, rings, lambda i, k: f(i / nz, k / nt), False)
	def centre(p):
		hw, top, bot = H.body_section(p.z)
		return (0.0, (top + bot) * 0.5, p.z)
	face_out(g, start, centre)
	return rings


def frame_edges(g, rings, r, swatch):
	"""Tubes round a patch's edge: the window's frame."""
	edges = [rings[0], rings[-1], [ring[0] for ring in rings], [ring[-1] for ring in rings]]
	for e in edges:
		H.tube(g, e, r, 6, swatch)


# --- High wing -----------------------------------------------------------------

HW_BODY = (
	(-0.500, 0.118, 0.122, -0.122),
	(-0.420, 0.126, 0.134, -0.136),
	(-0.340, 0.129, 0.160, -0.144),
	(-0.240, 0.129, 0.236, -0.150),
	(-0.100, 0.128, 0.246, -0.150),
	(0.060, 0.120, 0.246, -0.140),
	(0.180, 0.104, 0.214, -0.124),
	(0.300, 0.088, 0.172, -0.102),
	(0.430, 0.068, 0.136, -0.078),
) + TAIL_ROWS
HW_WIN = (-0.21, 0.04)      # the side windows, z
HW_SCREEN = (-0.335, -0.235)


def hw_struts(g, w):
	le = H.STAGGER - H.CHORD * 0.5
	out = H.SPAN * 0.31
	for side in (-1.0, 1.0):
		foot = (0.112 * side, -0.092, -0.15)
		for ch in (0.18, 0.7):
			up = (out * side, H.UPPER_Y - 0.01, le + H.CHORD * ch)
			H.tube(g, [foot, up], 0.0095, 8, "dark", aft=2.0, thin=0.95)
			H.tube(g, [(up[0], up[1] - 0.003, up[2] - 0.016), (up[0], up[1] - 0.003, up[2] + 0.022)], 0.0058, 5, "steel")
			# A jury strut from the strut's middle up to the spar.
			m = Vector(foot).lerp(Vector(up), 0.55)
			H.tube(g, [m, (m.x - 0.02 * side, H.UPPER_Y - 0.008, m.z)], 0.0045, 6, "dark")
		H.tube(g, [(foot[0] - 0.008 * side, foot[1], foot[2] - 0.03), (foot[0] + 0.004 * side, foot[1], foot[2] + 0.03)], 0.009, 6, "steel")
	tail_wires(w)


def hw_glass(g, glass):
	"""The windscreen up to the wing, and two windows a side under it: glass
	stood off the skin, a dark well just under each, frames in the body's paint."""
	for out, geo, sw_name in ((0.006, g, "black"), (0.016, glass, "black")):
		rs = body_patch(geo, HW_SCREEN[0], HW_SCREEN[1], -0.95, 0.95, out, sw_name, 6, 10)
		if geo is glass:
			frame_edges(g, rs, 0.004, "body")
		for side in (-1.0, 1.0):
			for z0, z1 in ((HW_WIN[0], -0.09), (-0.075, HW_WIN[1])):
				t0, t1 = (0.5, 1.22) if side > 0 else (-1.22, -0.5)
				rs = body_patch(geo, z0, z1, t0, t1, out, sw_name, 6, 6)
				if geo is glass:
					frame_edges(g, rs, 0.0035, "body")


def hw_fittings(g):
	skid_and_lamps(g)
	# A step under the door, a grab handle, and a pitot under the right wing.
	H.tube(g, [(-0.124, -0.06, -0.06), (-0.15, -0.075, -0.055), (-0.15, -0.075, -0.015), (-0.124, -0.06, -0.01)], 0.0034, 5, "brass")
	le = H.STAGGER - H.CHORD * 0.5
	px = H.SPAN * 0.38
	H.tube(g, [(px, H.UPPER_Y - 0.01, le + H.CHORD * 0.2), (px, H.UPPER_Y - 0.045, le + H.CHORD * 0.15), (px, H.UPPER_Y - 0.045, le - 0.05)], [0.0028, 0.0028, 0.0034], 6, "brass")


# --- Racer ---------------------------------------------------------------------

RC_BODY = (
	(-0.500, 0.134, 0.134, -0.134),
	(-0.430, 0.152, 0.154, -0.152),
	(-0.320, 0.166, 0.170, -0.166),
	(-0.170, 0.172, 0.180, -0.172),
	(-0.030, 0.166, 0.186, -0.166),
	(0.090, 0.150, 0.192, -0.150),
	(0.210, 0.126, 0.192, -0.128),
	(0.330, 0.098, 0.176, -0.100),
	(0.430, 0.072, 0.146, -0.078),
) + TAIL_ROWS
RC_BUBBLE = ((0.0, 0.034, 0.008), (0.03, 0.052, 0.038), (0.075, 0.062, 0.062), (0.13, 0.064, 0.072), (0.19, 0.06, 0.066), (0.245, 0.048, 0.044), (0.29, 0.026, 0.014))


def rc_glass(g, glass):
	"""A small bubble on the deck (z, half width, height over the deck)."""
	n = 16
	def base(z):
		return H.body_section(z)[1] - 0.026
	def point(i, k):
		z, hw, up = RC_BUBBLE[i]
		phi = -math.pi * 0.5 + math.pi * k / n
		s, c = math.sin(phi), math.cos(phi)
		r = (abs(s) ** 2.4 + abs(c) ** 2.4) ** (-1.0 / 2.4)
		b = base(z)
		top = H.body_section(z)[1] + up
		return Vector((s * r * hw, b + c * r * (top - b), z))
	rings = [[point(i, k) for k in range(n + 1)] for i in range(len(RC_BUBBLE))]
	f = H.sw("black")
	H.loft(glass, rings, lambda i, k: f(i, k), False, False, False)
	for i, r in ((0, 0.0045), (2, 0.004)):
		H.tube(g, [tuple(p + Vector((0, 0.001, 0))) for p in rings[i]], r, 6, "body")
	for k in (0, n):
		H.tube(g, [tuple(rings[i][k]) for i in range(len(RC_BUBBLE))], 0.0045, 6, "body")
	tub = [[(math.sin(-math.pi * 0.5 + math.pi * k / 8) * RC_BUBBLE[i][1] * 0.9, base(RC_BUBBLE[i][0]) + 0.004 + math.cos(-math.pi * 0.5 + math.pi * k / 8) * 0.018, RC_BUBBLE[i][0]) for k in range(9)] for i in range(len(RC_BUBBLE) - 1)]
	H.loft(g, tub, lambda i, k: f(i, k), False, False, False, 0.5)


def rc_struts(g, w):
	"""No struts: landing wires from the wing to the deck, flying wires down to
	the gear, and the hero's tail wires."""
	le = H.STAGGER - H.CHORD * 0.5
	for side in (-1.0, 1.0):
		x = H.SPAN * 0.3 * side
		for ch, dz in ((0.25, -0.005), (0.25, 0.005)):
			z = le + H.CHORD * ch + dz
			H.wire(w, (x, H.UPPER_Y + 0.012, z), (0.07 * side, H.body_section(-0.25)[1] - 0.004, -0.25 + dz))
			H.wire(w, (x, H.UPPER_Y - 0.01, z), (H.WHEEL_X * side * 0.85, H.AXLE_Y + 0.07, H.WHEEL_Z + dz))
	tail_wires(w)


def rc_fittings(g):
	skid_and_lamps(g)
	# A headrest fairing's stripe of brass: the fuel cap on the deck ahead of the bubble.
	top = H.body_section(-0.12)[1]
	H.tube(g, [(0.0, top - 0.004, -0.12), (0.0, top + 0.008, -0.12)], [0.022, 0.018], 12, "brass", up=(1.0, 0.0, 0.0))


HERO_GEAR = H.gear_geo


def rc_gear(side):
	"""The hero's leg, and a spat round the wheel's top half, open below so the
	tyre meets the ground (on the leg's node: it rides with the spring)."""
	g = HERO_GEAR(side)
	cx = H.WHEEL_X * side
	z0, z1 = H.WHEEL_Z - 0.115, H.WHEEL_Z + 0.17
	n, m = 14, 12
	rings = []
	for i in range(m + 1):
		t = i / m
		z = z0 + (z1 - z0) * t
		# A teardrop along the wind: full a third back, a long point behind.
		f = max(math.sin(math.pi * min(t / 0.36, 1.0) * 0.5) if t < 0.36 else math.cos(math.pi * 0.5 * (t - 0.36) / 0.64), 0.06)
		f = f ** 0.55
		hw, ht = 0.058 * f, 0.104 * f
		cy = H.AXLE_Y + 0.008
		ring = []
		for k in range(n + 1):
			phi = -2.15 + 4.3 * k / n
			ring.append((cx + math.sin(phi) * hw, cy + math.cos(phi) * ht, z))
		rings.append(ring)
	f = H.sw("trim")
	start = len(g.f)
	H.loft(g, rings, lambda i, k: f(i / m * 2.0, k / n), False)
	face_out(g, start, lambda p: (cx, H.AXLE_Y + 0.008, p.z))
	inner = [[(cx + (p[0] - cx) * 0.94, H.AXLE_Y + 0.008 + (p[1] - H.AXLE_Y - 0.008) * 0.94, p[2]) for p in r] for r in rings]
	start = len(g.f)
	H.loft(g, inner, lambda i, k: H.sw("black")(i, k), False, col=0.4)
	face_out(g, start, lambda p: (cx + (p.x - cx) * 2.0, H.AXLE_Y + 0.008 + (p.y - H.AXLE_Y - 0.008) * 2.0, p.z))
	return g


# --- The body's own atlas and materials ----------------------------------------

def write_materials(tex):
	res = H.RES
	maps = (("albedo_tex", f"{BODY_ID}_albedo.jpg", 2), ("normal_tex", f"{BODY_ID}_normal.jpg", 3), ("mask_tex", f"{BODY_ID}_mask.png", 4), ("orm_tex", f"{BODY_ID}_orm.png", 5))
	for name, shader, use in (("hero", "hero_surface", maps), ("wire", "hero_wire", maps[:1])):
		ext = [f'[ext_resource type="Shader" path="{HERO_RES}/{shader}.gdshader" id="1"]']
		lines = ['shader = ExtResource("1")']
		for key, file, i in use:
			ext.append(f'[ext_resource type="Texture2D" path="{res}/{file}" id="{i}"]')
			lines.append(f'shader_parameter/{key} = ExtResource("{i}")')
		(tex / f"{name}.tres").write_text('[gd_resource type="ShaderMaterial" format=3]\n\n' + "\n".join(ext) + "\n\n[resource]\n" + "\n".join(lines) + "\n")
	(tex / "glass.tres").write_text(f'[gd_resource type="ShaderMaterial" format=3]\n\n[ext_resource type="Shader" path="{HERO_RES}/hero_glass.gdshader" id="1"]\n\n[resource]\nshader = ExtResource("1")\n')
	subs = ",\n".join(f'"{n}": {{\n"use_external/enabled": true,\n"use_external/fallback_path": "{res}/{n}.tres",\n"use_external/path": "{res}/{n}.tres"\n}}' for n in ("hero", "glass", "wire"))
	glb = tex / (H.OUT.name + ".import")
	if not glb.exists():
		glb.write_text('[remap]\n\nimporter="scene"\n\n[params]\n\nmeshes/ensure_tangents=true\nmeshes/generate_lods=false\nmeshes/create_shadow_meshes=true\n_subresources={\n"materials": {\n' + subs + '\n}\n}\n')
	for file, normal in ((maps[0][1], 0), (maps[1][1], 1), (maps[2][1], 0), (maps[3][1], 0)):
		p = tex / (file + ".import")
		if not p.exists():
			mode = 0 if file.endswith(".png") else 2
			p.write_text(f'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode={mode}\ncompress/normal_map={normal}\nmipmaps/generate=true\nprocess/fix_alpha_border=false\ndetect_3d/compress_to=0\n')


def setup():
	H.build_wings = wing_only
	if BODY_ID == "highwing":
		H.BODY = HW_BODY
		H.UPPER_Y = 0.256
		H.STAGGER = -0.085
		H.build_struts = hw_struts
		H.build_canopy = hw_glass
		H.build_fittings = hw_fittings
	else:
		H.BODY = RC_BODY
		H.UPPER_Y = -0.088
		H.STAGGER = -0.045
		H.build_struts = rc_struts
		H.build_canopy = rc_glass
		H.build_fittings = rc_fittings
		H.gear_geo = rc_gear


def main():
	setup()
	fast = "--fast" in ARGV
	H.build()
	H.TEX.mkdir(parents=True, exist_ok=True)
	if "--no-paint" not in ARGV:
		maps = H.paint.paint_all(vars(H), 2 if fast else 1)
		H.save_tex(f"{BODY_ID}_albedo", maps["albedo"])
		H.save_tex(f"{BODY_ID}_normal", maps["normal"], True)
		H.save_png(f"{BODY_ID}_mask", maps["mask"])
		H.save_png(f"{BODY_ID}_orm", maps["orm"])
	write_materials(H.TEX)
	H.export()
	total = sum(H.STATS.values())
	for k, v in H.STATS.items():
		print(f"  {k:10s} {v:6d} tris")
	print(f"BODY {BODY_ID} {total} tris, {len(H.STATS)} nodes -> {H.OUT}")


main()
