"""The bake maker: a skin's own atlas, the hero plane's paint run with other settings.

A skin's bake (ShopStock `bake`, docs/design/endless-flight/spec-skins.md
"The contract") swaps the atlas's albedo, mask and orm for its own (the normal
is shared, so the seams, rivets and ribs stay where the mesh has them). This
runs hero_plane_paint.py with a bake's settings and writes them:

	<out>_albedo.jpg   2048 x 1300 (half the atlas), JPEG 90, sRGB
	<out>_mask.png     2048 x 1300, RGBA, the livery's shares
	<out>_orm.jpg      2048 x 1300, JPEG 90, roughness / metal / lacquer
	and their .import files (albedo and orm lossy WebP in the build, the mask
	lossless; loaded only while the skin is worn or tried).

From a lane's script:

	from hero_plane.hero_plane_bake import bake
	bake("assets/models/hero_plane/skins/metal/bright", wear=0.2, dirt=0.3, bare=1.0)

or from the shell:

	python tools/blender.py run art/blender/hero_plane/hero_plane_bake.py -- \\
		assets/models/hero_plane/skins/metal/bright --wear 0.2 --dirt 0.3 --bare 1

Settings (hero_plane_paint.BAKE_DEFAULTS; the plane's own atlas is all at
their defaults):
	wear    1   chips to primer and bare metal: 0 factory fresh, 2 battered
	dirt    1   soot, oil, dust and streaks: 0 clean, 2 filthy
	bare    0   the livery's coat off the metal (body forward of the cloth, the
	            cowl), 0..1; the deck, cheat line and marks stay painted over it
	bare_c  -   the bared metal's colour, hex (aluminium when not given):
	            copper "b87333", gold "d4a64a"
	rust    0   rust in the chips on metal and runs back from them, and
	            gathered in the body's seams and round its rivets, 0..1
	rust_c  -   the corrosion's colour, hex (rust when not given): a
	            verdigris "4f9a7a" for copper
	cloth   doped   or "silver": the wings', tail's and rudder's cloth in
	            aluminium dope, which takes no livery colour; or "bare": the
	            cloth and the body aft skinned in the bared metal (bare_c),
	            so with bare 1 the whole airframe is metal but the scheme

Each bake takes about a minute (the whole atlas is painted at full size, the
albedo then halved). It prints `BAKE <out> <albedo KB> <mask KB> <orm KB>` and
the row's `bake` value.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import hero_plane_paint as paint  # noqa: E402  (numpy alone)

ROOT = Path(__file__).resolve().parents[3]
BUILD = Path(__file__).resolve().parent / "hero_plane_build.py"
IMPORT = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
	'compress/mode={mode}\ncompress/lossy_quality={q}\ncompress/normal_map=0\nmipmaps/generate=true\n'
	'process/fix_alpha_border=false\ndetect_3d/compress_to=0\n')
# Lossy WebP for the albedo and orm; the mask lossless, since lossy WebP drops
# the colour wherever alpha (the dark share) is 0, which is nearly everywhere.
IMPORTS = {"albedo": (1, 0.85), "mask": (0, 0.7), "orm": (1, 0.8)}


def _constants():
	"""The build's numbers (its HOLDS, shape and atlas sections), without Blender."""
	src = BUILD.read_text()
	start = src.index("# --- HOLDS")
	end = src.index("# --- Geometry")
	ns = {"np": np, "math": math, "Path": Path}
	exec(compile(src[start:end], str(BUILD), "exec"), ns)
	return ns


def _hex(h):
	h = h.lstrip("#")
	return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def _jpeg(path, rgb, data):
	import bpy
	scene = bpy.context.scene
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	h, w = rgb.shape[:2]
	img = bpy.data.images.new(path.stem, w, h, alpha=False)
	if data:
		img.colorspace_settings.name = "Non-Color"
	px = np.dstack((np.clip(rgb, 0.0, 1.0), np.ones((h, w), dtype=np.float32)))[::-1].astype(np.float32)
	img.pixels.foreach_set(px.ravel())
	img.update()
	settings = scene.render.image_settings
	settings.file_format = "JPEG"
	settings.color_mode = "RGB"
	settings.quality = 90
	img.file_format = "JPEG"
	img.save_render(str(path))
	bpy.data.images.remove(img)


def _png(path, rgba):
	h, w = rgba.shape[:2]
	b = (np.clip(rgba, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8)
	raw = np.zeros((h, w * 4 + 1), dtype=np.uint8)
	raw[:, 1:] = b.reshape(h, -1)
	def chunk(tag, data):
		return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
	path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw.tobytes(), 9)) + chunk(b"IEND", b""))


def bake(out, wear=1.0, dirt=1.0, bare=0.0, bare_c=None, rust=0.0, cloth="doped", rust_c=None):
	"""Paints the atlas with these settings and writes <out>_albedo.jpg,
	<out>_mask.png and <out>_orm.jpg (out relative to the repo root, no suffix).
	Returns the row's `bake` value."""
	if cloth not in ("doped", "silver", "bare"):
		raise ValueError("bake: cloth is doped, silver or bare, not %r" % cloth)
	out = ROOT / out if not Path(out).is_absolute() else Path(out)
	out.parent.mkdir(parents=True, exist_ok=True)
	maps = paint.paint_all(_constants(), 2, WEAR=float(wear), DIRT=float(dirt), BARE=float(bare),
		BARE_C=_hex(bare_c) if bare_c else None, RUST=float(rust), CLOTH=cloth,
		RUST_C=_hex(rust_c) if rust_c else None)
	files = {
		"albedo": out.with_name(out.name + "_albedo.jpg"),
		"mask": out.with_name(out.name + "_mask.png"),
		"orm": out.with_name(out.name + "_orm.jpg"),
	}
	_jpeg(files["albedo"], maps["albedo"], False)
	_png(files["mask"], maps["mask"])
	_jpeg(files["orm"], maps["orm"][..., :3], True)
	for k, f in files.items():
		mode, q = IMPORTS[k]
		Path(str(f) + ".import").write_text(IMPORT.format(mode=mode, q=q))
	res = {k: "res://" + str(f.relative_to(ROOT)) for k, f in files.items()}
	kb = " ".join("%d" % (f.stat().st_size // 1024) for f in files.values())
	print("BAKE %s %s KB (albedo mask orm)" % (out.relative_to(ROOT), kb))
	print("ROW \"bake\":{%s}" % ",".join('"%s":"%s"' % (k, v) for k, v in res.items()))
	return res


def _cli(argv):
	if not argv or argv[0].startswith("--"):
		print(__doc__)
		raise SystemExit(2)
	out, kw, i = argv[0], {}, 1
	while i < len(argv):
		key = argv[i].lstrip("-").replace("-", "_")
		if key not in ("wear", "dirt", "bare", "bare_c", "rust", "rust_c", "cloth") or i + 1 >= len(argv):
			print("hero_plane_bake: unknown or empty option %s" % argv[i])
			raise SystemExit(2)
		kw[key] = argv[i + 1]
		i += 2
	bake(out, **kw)


if __name__ == "__main__" and "--" in sys.argv:
	_cli(sys.argv[sys.argv.index("--") + 1:])
