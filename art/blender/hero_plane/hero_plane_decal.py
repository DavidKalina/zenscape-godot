"""The decal painter: a skin's marks over the hero plane's paint, in its atlas.

A skin's decal (ShopStock `decal`, docs/design/endless-flight/spec-skins.md
"The contract") is one RGBA PNG at half the atlas's size (2048 x 1300),
premultiplied, laid by hero_surface.gdshader over the livery on the painted
parts and under the atlas's wear and dirt. A lane's script draws it in the
plane's own units, region by region, and saves it:

	from hero_plane.hero_plane_decal import Decal
	d = Decal()
	d.stripe("body", "f2e8d2", z=(-0.42, 0.66), s=(0.06, 0.085))   # both sides
	d.band("wings_top", "c8352b", x=(0.52, 0.6))
	d.text("fin", "27", "f2e8d2", at=(0.6, 0.17), height=0.09)
	d.save("assets/models/hero_plane/skins/heritage/racer_decal.png")

run with `python tools/blender.py run <script>` (Blender's Python has numpy;
`--fast` is not needed, a decal takes a few seconds).

Regions (`on`) and their frames (a, b), in toy units (the plane is about 1.2
long; the nose is -z, +x starboard, +y up):
	body       (z, s): z along the fuselage, -0.5 the firewall to 0.72 the
	           tail; s round from the top centre line, + starboard, so a
	           side's middle is near s = +-0.2 and the keel +-0.42 (the
	           girth varies: `girth(z)` gives the half round at z).
	           mirror=True (default) takes s as |s|: both sides alike.
	up_top up_under lo_top lo_under
	           the wings (x, c): x out along the half span from the centre
	           (upper 0..0.7, lower 0.08..0.63), c back from the leading edge
	           (0..0.3, less past the tip's rake at x > 0.59 / 0.53).
	           Both halves of a wing share the atlas, so a wing's marks are
	           always mirrored left and right; a text reads right on the
	           starboard half and mirror-written on the port.
	wings_top wings_under wings   the two tops, the two unders, all four
	tail       the tailplane (x, c): x out 0..0.26, c back from TAIL_Z (0.56)
	           0..0.135; top and under share the atlas.
	fin        the fin and rudder (z, y), both sides (each its own atlas, so
	           text reads right on both): z 0.47 (root's leading edge) to
	           0.76 (rudder's trailing edge), y 0.05 (the deck) to 0.3 (the
	           top); the rudder is z > 0.685.
	cowl       (s, l): s round from the top in toy units (+ starboard,
	           mirror as the body; the cowl's half round is about 0.49), l
	           along its profile from the lip's inside: FRONT the lip's rim
	           (the face you see head on is before it), COWL_L the skirt at
	           the firewall.

What is painted shows only where the atlas's mask is paint (not on brass,
glass, steel, the prop or tyres, nor bared metal) and fades under its
chips and stains.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hero_plane_paint import FONT  # noqa: E402  (numpy alone)

ROOT = Path(__file__).resolve().parents[3]
BUILD = Path(__file__).resolve().parent / "hero_plane_build.py"


def _constants():
	"""The build's numbers (its HOLDS, shape and atlas sections), without Blender."""
	src = BUILD.read_text()
	start = src.index("# --- HOLDS")
	end = src.index("# --- Geometry")
	ns = {"np": np, "math": math, "Path": Path}
	exec(compile(src[start:end], str(BUILD), "exec"), ns)
	return ns


K = _constants()
SCALE = 2                    # the decal is the atlas at half size
DW, DH = K["AW"] // SCALE, K["AH"] // SCALE
_ARC = [0.0]
for _p, _q in zip(K["COWL"], K["COWL"][1:]):
	_ARC.append(_ARC[-1] + math.hypot(_q[0] - _p[0], _q[1] - _p[1]))
FRONT = _ARC[7]              # the cowl's lip rim, l
COWL_L = _ARC[-1]            # the profile's length, lip inside to skirt
COWL_R = 0.155
GROUPS = {
	"wings_top": ("up_top", "lo_top"),
	"wings_under": ("up_under", "lo_under"),
	"wings": ("up_top", "lo_top", "up_under", "lo_under"),
	"fin": ("fin_r", "fin_l"),
}
REGIONS = ("body", "up_top", "up_under", "lo_top", "lo_under", "tail", "fin_r", "fin_l", "cowl")


def girth(z):
	"""The body's half round (top centre to keel) at z, toy units."""
	B = K["BODY"]
	r = np.interp(z, [b[0] for b in B], [max(b[1], (b[2] - b[3]) * 0.5) for b in B])
	return r * math.pi


def colour(c):
	"""A colour as 'rrggbb', '#rrggbb' or (r, g, b) 0..1 (sRGB), to an array."""
	if isinstance(c, str):
		c = c.lstrip("#")
		return np.array([int(c[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)
	return np.array(c[:3], dtype=np.float32)


def sst(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def inside(x, lo, hi, soft):
	"""1 between lo and hi, edges `soft` wide."""
	return sst(lo - soft, lo + soft, x) * (1.0 - sst(hi - soft, hi + soft, x))


class Frame:
	"""One region's window in the decal and its pixels' (a, b) in toy units.
	`side` is +1 starboard / -1 port where the region tells them apart."""

	def __init__(self, name):
		x0, y0, w, h = K["REG"][name]
		c0, c1 = x0 // SCALE, -(-(x0 + w) // SCALE)
		r0, r1 = y0 // SCALE, -(-(y0 + h) // SCALE)
		self.name = name
		self.s = (slice(r0, r1), slice(c0, c1))
		yy, xx = np.mgrid[r0:r1, c0:c1].astype(np.float32)
		lx = (xx + 0.5) * SCALE - x0      # the atlas's px in the region
		ly = (yy + 0.5) * SCALE - y0
		D = K["D"]
		self.side = None
		if name == "body":
			self.a = (lx - 8.0) / 2190.0 - 0.5
			th = (ly - 8.0) / (h - 16.0) * math.tau
			phi = (th + math.pi) % math.tau - math.pi
			self.b = phi * girth(self.a) / math.pi
			self.side = np.where(phi >= 0.0, 1.0, -1.0)
			self.px = 2190.0 / SCALE
		elif name in ("up_top", "up_under", "lo_top", "lo_under"):
			self.a = (lx - 6.0) / D
			self.b = (ly - 10.0) / D
			self.px = D / SCALE
		elif name == "tail":
			self.a = (lx - 6.0) / D
			self.b = (ly - 6.0) / D
			self.px = D / SCALE
		elif name in ("fin_r", "fin_l"):
			col = (lx - 5.0) / D
			self.a = (0.77 - col) if name == "fin_r" else (col + 0.47)
			self.b = 0.312 - (ly - 8.0) / D
			self.side = np.full_like(self.a, 1.0 if name == "fin_r" else -1.0)
			self.px = D / SCALE
		elif name == "cowl":
			t = (lx - 6.0) / (w - 12.0) * math.tau
			phi = (t + math.pi) % math.tau - math.pi
			self.a = phi * COWL_R
			self.b = (ly - 6.0) / (h - 12.0) * COWL_L
			self.side = np.where(phi >= 0.0, 1.0, -1.0)
			self.px = (h - 12.0) / COWL_L / SCALE
		self.inside = (lx >= 0) & (lx < w) & (ly >= 0) & (ly < h)

	def ab(self, mirror):
		"""Its frame, the round coordinate taken unsigned when mirrored."""
		if self.name == "cowl":
			return (np.abs(self.a) if mirror else self.a), self.b
		if self.name == "body" and mirror:
			return self.a, np.abs(self.b)
		return self.a, self.b


class Decal:
	def __init__(self):
		self.rgb = np.zeros((DH, DW, 3), dtype=np.float32)    # premultiplied
		self.al = np.zeros((DH, DW), dtype=np.float32)
		self._frames = {}

	def frames(self, on):
		names = GROUPS.get(on, (on,))
		out = []
		for n in names:
			if n not in REGIONS:
				raise ValueError(f"decal: no region {n!r} (one of {REGIONS + tuple(GROUPS)})")
			if n not in self._frames:
				self._frames[n] = Frame(n)
			out.append(self._frames[n])
		return out

	def lay(self, f, t, c):
		"""Colour c over the decal by coverage t (0..1) in frame f."""
		t = np.clip(t, 0.0, 1.0) * f.inside
		c = colour(c)
		r, a = self.rgb[f.s], self.al[f.s]
		self.rgb[f.s] = r * (1.0 - t[..., None]) + c * t[..., None]
		self.al[f.s] = a * (1.0 - t) + t

	def erase(self, f, t):
		t = np.clip(t, 0.0, 1.0) * f.inside
		self.rgb[f.s] *= (1.0 - t)[..., None]
		self.al[f.s] *= 1.0 - t

	def _soft(self, f, soft):
		return soft if soft is not None else 1.2 / f.px

	# --- Shapes ------------------------------------------------------------
	# Each takes `on` (a region or group), a colour, its place in that frame's
	# (a, b) and `mirror` (the body and cowl: both sides alike, default).
	# `soft` is the edge's width in toy units (about a decal pixel else).

	def mask(self, on, c, fn, mirror=True):
		"""A free mask: fn(a, b, side) -> 0..1 arrays (side +1 starboard, -1
		port, None where the region has no sides)."""
		for f in self.frames(on):
			a, b = f.ab(mirror)
			self.lay(f, fn(a, b, f.side), c)

	def rect(self, on, c, a, b, mirror=True, soft=None):
		"""All between a=(a0, a1) and b=(b0, b1)."""
		for f in self.frames(on):
			fa, fb = f.ab(mirror)
			s = self._soft(f, soft)
			self.lay(f, inside(fa, a[0], a[1], s) * inside(fb, b[0], b[1], s), c)

	def stripe(self, on, c, z=None, s=None, x=None, mirror=True, soft=None):
		"""A stripe along: on the body z=(from, to) and s=(from, to) round;
		on a wing or the tail x=(from, to) out and s=(from, to) back from the
		leading edge (c); full length where a range is left out."""
		big = (-9.0, 9.0)
		if x is not None:
			self.rect(on, c, x, s or big, mirror, soft)
		else:
			self.rect(on, c, z or big, s or big, mirror, soft)

	def band(self, on, c, a, mirror=True, soft=None):
		"""A band across: all of b between a=(a0, a1) (on a wing, a span
		band; on the body, a ring round the fuselage)."""
		self.rect(on, c, a, (-9.0, 9.0), mirror, soft)

	def disc(self, on, c, at, r, ring=0.0, mirror=True, soft=None):
		"""A disc of radius r at at=(a, b); ring > 0 leaves its middle open
		(a roundel's ring that wide)."""
		for f in self.frames(on):
			fa, fb = f.ab(mirror)
			s = self._soft(f, soft)
			d = np.sqrt((fa - at[0]) ** 2 + (fb - at[1]) ** 2)
			t = 1.0 - sst(r - s, r + s, d)
			if ring > 0.0:
				t *= sst(r - ring - s, r - ring + s, d)
			self.lay(f, t, c)

	def checker(self, on, c, a, b, cell, mirror=True, soft=None):
		"""A checker of `cell` squares in a=(a0, a1), b=(b0, b1); the first
		square at (a0, b0) is painted."""
		for f in self.frames(on):
			fa, fb = f.ab(mirror)
			s = self._soft(f, soft)
			ia = np.floor((fa - a[0]) / cell)
			ib = np.floor((fb - b[0]) / cell)
			on_ = ((ia + ib) % 2.0 == 0.0).astype(np.float32)
			# Soften the squares' edges.
			ea = np.abs(((fa - a[0]) / cell + 0.5) % 1.0 - 0.5) * cell
			eb = np.abs(((fb - b[0]) / cell + 0.5) % 1.0 - 0.5) * cell
			edge = np.minimum(sst(0.0, 2.0 * s, ea), sst(0.0, 2.0 * s, eb))
			t = (on_ * edge + (1.0 - edge) * 0.5) * inside(fa, a[0], a[1], s) * inside(fb, b[0], b[1], s)
			self.lay(f, t, c)

	def scallop(self, on, c, a, b, n, depth, mirror=True, soft=None):
		"""A band from a[0] to a scalloped edge near a[1]: n round bites
		along b=(b0, b1), each reaching `depth` past a[1] (negative: back
		toward a[0]). On the body a=(z, z) and b the round, say a cowl's
		scallops trailing back down the sides."""
		for f in self.frames(on):
			fa, fb = f.ab(mirror)
			s = self._soft(f, soft)
			k = (fb - b[0]) / (b[1] - b[0]) * n
			bump = np.sqrt(np.clip(1.0 - ((k % 1.0) * 2.0 - 1.0) ** 2, 0.0, 1.0))
			edge = a[1] + depth * bump
			lo, hi = (a[0], edge) if a[1] >= a[0] else (edge, a[0])
			t = inside(fa, lo, hi, s) * inside(fb, b[0], b[1], s)
			self.lay(f, t, c)

	def text(self, on, s, c, at, height, flip=False, mirror=True, soft=None):
		"""Letters and numbers (hero_plane_paint's FONT: 0-9, A-Z bar J Q Z,
		- . and space) `height` tall, centred at at=(a, b), upright. On the
		body and fin they read nose-ward on the starboard side and aft on the
		port, as painted marks do; on the wings and tail, out along the span
		with their tops to the leading edge (`flip` turns them round)."""
		rows = []
		for r in range(7):
			line = []
			for ch in s.upper():
				line += [int(v) for v in FONT[ch].split()[r]] + [0]
			rows.append(line[:-1])
		bits = np.array(rows, dtype=np.float32)
		cell = height / 7.0
		wide = bits.shape[1] * cell
		for f in self.frames(on):
			fa, fb = f.ab(mirror)
			sd = self._soft(f, soft)
			if f.name in ("body", "fin_r", "fin_l"):
				# Across: along the fuselage, read from the side; up: to the top.
				u = -(fa - at[0]) * f.side
				v = (np.abs(fb) - abs(at[1])) if f.name == "body" else (at[1] - fb)
			else:
				u = fa - at[0]
				v = fb - at[1]
			if flip:
				u, v = -u, -v
			t = np.zeros_like(fa)
			if f.name == "body" and not mirror:
				t_side = (np.sign(fb) == math.copysign(1.0, at[1])).astype(np.float32)
			else:
				t_side = 1.0
			# Four looks a pixel: the letters' edges smooth.
			for ou, ov in ((-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)):
				iu = np.floor((u + ou * sd + wide * 0.5) / cell).astype(np.int64)
				iv = np.floor((v + ov * sd + height * 0.5) / cell).astype(np.int64)
				ok = (iu >= 0) & (iu < bits.shape[1]) & (iv >= 0) & (iv < 7)
				t += np.where(ok, bits[np.clip(iv, 0, 6), np.clip(iu, 0, bits.shape[1] - 1)], 0.0) * 0.25
			self.lay(f, t * t_side, c)

	# --- Out ---------------------------------------------------------------

	def save(self, path):
		"""Writes the decal (premultiplied RGBA PNG) and its import settings
		(lossless, mipmaps, sRGB), the path from the repo root."""
		p = ROOT / path
		p.parent.mkdir(parents=True, exist_ok=True)
		rgba = np.dstack((self.rgb, self.al))
		b = (np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
		h, w = b.shape[:2]
		raw = np.zeros((h, w * 4 + 1), dtype=np.uint8)
		raw[:, 1:] = b.reshape(h, -1)
		def chunk(tag, data):
			return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
		p.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw.tobytes(), 9)) + chunk(b"IEND", b""))
		imp = p.with_name(p.name + ".import")
		if not imp.exists():
			imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=false\ndetect_3d/compress_to=0\n')
		print(f"DECAL {path} {w}x{h} {p.stat().st_size // 1024} KB")
