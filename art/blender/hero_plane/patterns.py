"""The pattern maker: the hero plane's tintable patterns (the look's `pattern`,
scripts/endless/plane_look.gd; the catalogue scripts/endless/plane_patterns.gd).

A pattern is a mask in the atlas's UV: R the share of the pilot's colour A,
G of colour B, black where the paint shows. hero_surface.gdshader lays it
over the zones' paint and under the decal, on the painted parts only. It is
drawn with hero_plane_decal.py's `Decal` in the plane's own units (its
docstring has the regions and their frames), colour A or B in place of a
colour, and saved to assets/models/hero_plane/patterns/<id>.png with its
`.import`: an RGB PNG at a quarter of the atlas's size (1024 x 650, 10-40 KB;
drawn at the decal's size and averaged down, so its edges are smooth).

	python tools/blender.py run art/blender/hero_plane/patterns.py            # all
	python tools/blender.py run art/blender/hero_plane/patterns.py -- checker  # some

numpy alone, so a Python with numpy runs it too. A new pattern is a function
here that returns a Pattern, a line in PATTERNS, and a row in
plane_patterns.gd. See one on the plane with
`python tools/skin_sheet.py pattern:<id>` (tools/README.md).

The atlas has marks of its own under a pattern: a roundel on the upper
wing's top and the lower wing's underside (`roundels` leaves them showing
through), trimmed wing tips outboard of TIP_UP / TIP_LO, a band low on the
body's flank (about 92 to 112 degrees round from the top) and a number aft
of z = 0.1 above it.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hero_plane_decal import COWL_L, COWL_R, FRONT, ROOT, Decal, girth, inside, sst  # noqa: E402

OUT = "assets/models/hero_plane/patterns/"
A, B = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)
DOWN = 2                       # the mask is the decal's size over this

# The wings: (root, tip) along the half span. The chord is 0.3.
SPANS = {"up_top": (0.0, 0.7), "up_under": (0.0, 0.7), "lo_top": (0.08, 0.63), "lo_under": (0.08, 0.63)}
TOPS = ("up_top", "lo_top")
TIP_UP, TIP_LO = 0.574, 0.517  # where the atlas's own trimmed tips start
ROUNDELS = {"up_top": (0.46, 0.15), "lo_under": (0.42, 0.15)}
TAIL = (0.26, 0.135)           # the tailplane's half span and chord
FIN = (0.47, 0.76), (0.05, 0.3)


class Pattern(Decal):
	"""A Decal drawn in A and B, saved as a pattern's mask."""

	def wings(self, c, fn, on=tuple(SPANS)):
		"""fn(x, c, root, tip) -> coverage on each wing surface in `on`."""
		for name in on:
			f = self.frames(name)[0]
			self.lay(f, fn(f.a, f.b, *SPANS[name]), c)

	def body(self, c, fn):
		"""fn(z, phi) -> coverage; phi the angle round from the top centre
		line, 0 to pi at the keel, both sides alike."""
		f = self.frames("body")[0]
		self.lay(f, fn(f.a, np.abs(f.b) * math.pi / girth(f.a)), c)

	def cowl(self, c, fn):
		"""fn(phi, l) -> coverage; phi as the body's, l along the cowl's
		profile (FRONT the lip's rim, COWL_L the skirt)."""
		f = self.frames("cowl")[0]
		self.lay(f, fn(np.abs(f.a) / COWL_R, f.b), c)

	def roundels(self):
		"""The atlas's own roundels left showing: the pattern cut away over them."""
		for name, at in ROUNDELS.items():
			self.disc(name, None, at=at, r=0.1)

	def save(self, path):
		p = ROOT / path
		p.parent.mkdir(parents=True, exist_ok=True)
		m = np.clip(self.rgb, 0.0, 1.0)
		h, w = (m.shape[0] // DOWN) * DOWN, (m.shape[1] // DOWN) * DOWN
		m = m[:h, :w].reshape(h // DOWN, DOWN, w // DOWN, DOWN, 3).mean(axis=(1, 3))
		m[..., 2] = 0.0
		b = (m * 255.0 + 0.5).astype(np.uint8)
		h, w = b.shape[:2]
		raw = np.zeros((h, w * 3 + 1), dtype=np.uint8)
		raw[:, 1:] = b.reshape(h, -1)
		def chunk(tag, data):
			return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
		p.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw.tobytes(), 9)) + chunk(b"IEND", b""))
		imp = p.with_name(p.name + ".import")
		if not imp.exists():
			imp.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=true\nprocess/fix_alpha_border=false\ndetect_3d/compress_to=0\n')
		print(f"PATTERN {path} {w}x{h} {p.stat().st_size // 1024} KB")


S = 0.0012                     # an edge's softness, toy units
SP = 0.006                     # and round the body, radians


def tip_bands():
	"""Each wing's tip in A, where the atlas trims it, and the line inside
	it in B; the tailplane's tips and the fin's top the same."""
	p = Pattern()
	for names, cut in ((("up_top", "up_under"), TIP_UP), (("lo_top", "lo_under"), TIP_LO)):
		p.wings(B, lambda x, c, root, tip: inside(x, cut - 0.036, cut - 0.012, S), on=names)
		p.wings(A, lambda x, c, root, tip: inside(x, cut, 9.0, S), on=names)
	p.band("tail", B, (0.168, 0.182))
	p.band("tail", A, (0.194, 9.0))
	p.rect("fin", B, (0.0, 9.0), (0.222, 0.234))
	p.rect("fin", A, (0.0, 9.0), (0.246, 9.0))
	p.roundels()
	return p


def cheat_line():
	"""The atlas's own line down the flank in A and its two pin lines in B,
	carried on aft over the tail to a point and forward round the cowl."""
	p = Pattern()
	Z = [-0.5, 0.0, 0.3, 0.72]
	def edges(z):
		top = np.interp(z, Z, [1.5, 1.58, 1.66, 1.7])
		wide = np.interp(z, Z, [0.34, 0.34, 0.3, 0.2])
		thin = 1.0 - sst(0.36, 0.71, z)
		mid = top + wide * 0.5
		return mid - wide * 0.5 * thin, mid + wide * 0.5 * thin, thin
	def line(z, phi):
		lo, hi, thin = edges(z)
		return inside(phi, lo - 0.004, hi + 0.004, SP) * sst(0.0, 0.03, thin)
	def pins(z, phi):
		lo, hi, thin = edges(z)
		gap = 0.022 * thin
		return (inside(phi, lo - gap - 0.05, lo - gap, SP) + inside(phi, hi + gap, hi + gap + 0.05, SP)) * sst(0.04, 0.12, thin)
	p.body(B, pins)
	p.body(A, line)
	skirt = lambda l: inside(l, FRONT + 0.015, 9.0, S)
	p.cowl(B, lambda phi, l: (inside(phi, 1.428, 1.478, SP) + inside(phi, 1.862, 1.912, SP)) * skirt(l))
	p.cowl(A, lambda phi, l: inside(phi, 1.496, 1.844, SP) * skirt(l))
	return p


def split():
	"""Two-tone: the body and cowl below the waist in A, the line rising to
	take the whole tail, a B line along it; the wings' and tail's undersides."""
	p = Pattern()
	def edge(z):
		return 1.50 - 1.50 * sst(0.34, 0.74, z)
	p.body(A, lambda z, phi: inside(phi, edge(z), 9.0, SP))
	p.body(B, lambda z, phi: inside(phi, edge(z) - 0.10, edge(z) - 0.045, SP) * inside(z, -9.0, 0.50, S))
	p.cowl(A, lambda phi, l: inside(phi, 1.50, 9.0, SP) * inside(l, FRONT, 9.0, S))
	p.cowl(B, lambda phi, l: inside(phi, 1.40, 1.455, SP) * inside(l, FRONT, 9.0, S))
	p.wings(A, lambda x, c, root, tip: np.ones_like(x), on=("up_under", "lo_under"))
	p.roundels()
	return p


def spine():
	"""Twin stripes nose to tail over the top: the cowl, the deck, across the
	upper wing's middle and the tailplane's, B lines outside them."""
	p = Pattern()
	for c, lo, hi in ((B, 0.062, 0.070), (A, 0.012, 0.052)):
		p.rect("body", c, (-9.0, 9.0), (lo, hi))
		p.rect("cowl", c, (lo, hi), (FRONT, 9.0))
		p.rect("up_top", c, (lo, hi), (-9.0, 9.0))
		p.rect("tail", c, (lo * 0.8, hi * 0.8), (-9.0, 9.0))
	return p


def chevrons():
	"""Three chevrons on each half wing, top and under, pointing out to the
	tip, A B A; smaller on the tailplane."""
	p = Pattern()
	def chev(v0, w, k, mid):
		return lambda x, c, *_: inside(x - k * (mid - np.abs(c - mid)) / mid, v0, v0 + w, S)
	for i, c in enumerate((A, B, A)):
		p.wings(c, lambda x, cc, root, tip, i=i: chev(root * 0.5 + 0.06 + 0.085 * i, 0.05, 0.085, 0.15)(x, cc))
		p.mask("tail", c, lambda a, b, side, i=i: chev(0.045 + 0.05 * i, 0.03, 0.04, TAIL[1] * 0.5)(a, b))
	p.roundels()
	return p


def bands():
	"""Five bands, A B A B A, round the body behind the cockpit and across
	each wing inboard, top and under."""
	p = Pattern()
	for i in range(5):
		c = A if i % 2 == 0 else B
		p.band("body", c, (0.085 + 0.05 * i, 0.085 + 0.05 * (i + 1)))
		p.wings(c, lambda x, cc, root, tip, i=i: inside(x, root + 0.10 + 0.05 * i, root + 0.10 + 0.05 * (i + 1), S))
	p.roundels()
	return p


def checker():
	"""A checker in A and B: the fin and rudder, the cowl's skirt and the
	wings' tips."""
	p = Pattern()
	cell = COWL_R * math.pi / 10.0
	p.rect("fin", B, *FIN)
	p.checker("fin", A, FIN[0], FIN[1], 0.0415)
	p.rect("cowl", B, (0.0, 9.0), (FRONT + 0.015, 9.0))
	p.checker("cowl", A, (0.0, 9.0), (FRONT + 0.015, 9.0), cell)
	for name, cut in (("up_top", TIP_UP), ("lo_top", TIP_LO), ("up_under", TIP_UP), ("lo_under", TIP_LO)):
		p.rect(name, B, (cut, 9.0), (-9.0, 9.0))
		p.checker(name, A, (cut, 9.0), (0.0, 0.3), 0.3 / 7.0)
	return p


def scallops():
	"""Scallops back from the leading edges of the wings and tailplane and
	from the cowl onto the body, in A with a B line round them."""
	p = Pattern()
	def lobes(x, pitch):
		return np.sqrt(np.clip(1.0 - ((x / pitch) % 1.0 * 2.0 - 1.0) ** 2, 0.0, 1.0))
	for c, more in ((B, 0.014), (A, 0.0)):
		p.wings(c, lambda x, cc, root, tip: 1.0 - sst(-S, S, cc - (0.03 + more + 0.055 * lobes(x - root, 0.1 if root == 0.0 else 0.11))), on=TOPS)
		p.mask("tail", c, lambda a, b, side: 1.0 - sst(-S, S, b - (0.012 + more * 0.7 + 0.03 * lobes(a, 0.065))))
		p.body(c, lambda z, phi: 1.0 - sst(-S, S, z - (-0.475 + more + 0.07 * lobes(phi, math.pi / 4.0))))
		p.cowl(c, lambda phi, l: inside(l, FRONT, FRONT + 0.012 + more + 0.035 * lobes(phi, math.pi / 4.0), S))
	return p


def sunburst():
	"""Rays in A and B by turns from the middle of the upper wing out over
	its whole top, an A disc ringed in B at their heart; the lower wing's top
	and the tailplane the same."""
	p = Pattern()
	def rays(n, at):
		def fn(x, c, *_):
			ang = np.arctan2(c - at, x)
			r = np.hypot(x, c - at)
			# A ray's edge, in toy units across it, so it stays crisp far out.
			return np.clip(np.cos(ang * n) * r / (n * S * 1.5) + 0.5, 0.0, 1.0)
		return fn
	p.wings(B, lambda x, c, root, tip: np.ones_like(x), on=TOPS)
	p.wings(A, rays(14, 0.15), on=TOPS)
	p.disc("up_top", B, at=(0.0, 0.15), r=0.092)
	p.disc("up_top", A, at=(0.0, 0.15), r=0.074)
	p.rect("tail", B, (-9.0, 9.0), (-9.0, 9.0))
	p.mask("tail", A, lambda a, b, side: rays(10, TAIL[1] * 0.5)(a, b))
	return p


PATTERNS = {"tip_bands": tip_bands, "cheat_line": cheat_line, "split": split, "spine": spine, "chevrons": chevrons,
	"bands": bands, "checker": checker, "scallops": scallops, "sunburst": sunburst}

if __name__ == "__main__":
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	for name in args or list(PATTERNS):
		if name not in PATTERNS:
			sys.exit(f"patterns: no pattern {name!r} (one of {', '.join(PATTERNS)})")
		PATTERNS[name]().save(OUT + name + ".png")
