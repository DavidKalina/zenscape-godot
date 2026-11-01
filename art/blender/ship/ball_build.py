"""Build the pirate ship's cannonball: polished dark iron, a trace of pitting and rust.

    python3 tools/blender.py run art/blender/ship/ball_build.py
    python3 tools/godot.py --headless --editor --import

Writes assets/models/pirate_ball.glb and, in assets/models/pirate_ship/, its
albedo, normal and material. Like the ship's, the glb carries a material name
only; pirate_ball.glb.import points it at ball.tres, which uses the ship's own
`surface` shader, so the sky's hemisphere fills its shade (the world has no
ambient light). Its size is a constant here: keep BALL_R on PirateShip's.

The textures are painted in numpy on the sphere itself (every field is read at
the texel's point in 3D, so nothing seams at the map's edge), in hard painted
shapes rather than fine noise: the ball is 100 px across at 30 m and 10 at 300.
The UV sphere's pinch sits under a sprue scar at each pole.
"""
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/pirate_ball.glb"
TEX = ROOT / "assets/models/pirate_ship"
RES = "res://assets/models/pirate_ship"

# --- The numbers --------------------------------------------------------------

BALL_R = 1.5          # m, PirateShip.BALL_R
SEGMENTS = 16         # round the equator
RINGS = 10            # pole to pole
TEX_W = 1024          # the map, 2:1
NORMAL_DIV = 2        # the normal map at 1/this
SEED = 41

PITS = 26             # how many
PIT_R = (0.03, 0.12)  # rad, the smallest and the largest
PIT_DEEP = 0.012      # m at the largest
SEAM_W = 0.03         # rad, half the ridge
SEAM_TALL = 0.035     # m
SCAR_R = 0.26         # rad, the sprue's scar at each pole
NORMAL_GAIN = 0.9     # over true height: pits read in the sun

# The paint, in sRGB. On metal this is the reflection's tint, so light for iron.
IRON = (0.72, 0.73, 0.76)
IRON_LOW = (0.66, 0.67, 0.70)
PIT = (0.55, 0.55, 0.58)
RUST = (0.62, 0.53, 0.47)
RUST_DEEP = (0.54, 0.44, 0.38)
WORN = (0.88, 0.89, 0.90)

# The material: over the shade, the fill from the sky and the lifted edge.
MATERIAL = {"normal_depth": 1.0, "roughness_value": 0.2, "metallic_value": 0.9, "fill": 2.5, "rim": 2.5}


# --- Painting -----------------------------------------------------------------

def smooth(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


LATTICE = np.random.default_rng(SEED).random((32, 32, 32), dtype=np.float32)


def noise(p, freq, shift):
	"""Value noise in 3D, 0-1; p is (h, w, 3)."""
	q = p * freq + shift
	i = np.floor(q).astype(np.int32)
	f = q - i
	f = f * f * (3.0 - 2.0 * f)
	out = 0.0
	for dx in (0, 1):
		wx = f[..., 0] if dx else 1.0 - f[..., 0]
		for dy in (0, 1):
			wy = f[..., 1] if dy else 1.0 - f[..., 1]
			for dz in (0, 1):
				wz = f[..., 2] if dz else 1.0 - f[..., 2]
				out = out + LATTICE[(i[..., 0] + dx) & 31, (i[..., 1] + dy) & 31, (i[..., 2] + dz) & 31] * wx * wy * wz
	return out


def fbm(p, freq, shift, octaves=3):
	out, amp, total = 0.0, 1.0, 0.0
	for o in range(octaves):
		out = out + noise(p, freq * 2.0 ** o, shift + o * 7.3) * amp
		total += amp
		amp *= 0.5
	return out / total


def unit(v):
	v = np.array(v, dtype=np.float32)
	return v / np.linalg.norm(v)


def band(p, axis, wide, wobble):
	"""1 on the great circle round `axis`, 0 past `wide` rad; `wobble` rad off true."""
	off = np.arcsin(np.clip(p @ unit(axis), -1.0, 1.0)) + wobble
	return 1.0 - smooth(wide * 0.5, wide, np.abs(off))


def paint(w):
	h = w // 2
	lon = (np.arange(w, dtype=np.float32) + 0.5) / w * math.tau
	lat = math.pi * 0.5 - (np.arange(h, dtype=np.float32) + 0.5) / h * math.pi
	lon, lat = np.meshgrid(lon, lat)
	p = np.stack((np.cos(lat) * np.cos(lon), np.cos(lat) * np.sin(lon), np.sin(lat)), axis=-1)

	rng = np.random.default_rng(SEED)
	height = (fbm(p, 2.2, 3.1) - 0.5) * 0.09       # lumps of an uneven casting
	pit = np.zeros((h, w), dtype=np.float32)
	lip = np.zeros((h, w), dtype=np.float32)
	for i in range(PITS):
		at = rng.normal(size=3)
		at = (at / np.linalg.norm(at)).astype(np.float32)
		r = PIT_R[0] + (PIT_R[1] - PIT_R[0]) * rng.random() ** 2.6
		d = np.arccos(np.clip(p @ at, -1.0, 1.0)) * (1.0 + 0.3 * (noise(p, 6.0, i * 0.37) - 0.5))
		bowl = 1.0 - smooth(r * 0.55, r, d)
		height -= bowl * PIT_DEEP * (r / PIT_R[1]) ** 0.6
		pit = np.maximum(pit, bowl)
		lip = np.maximum(lip, smooth(r * 0.92, r * 1.08, d) * (1.0 - smooth(r * 1.12, r * 1.38, d)))

	# The mould's halves meet at the equator; a second, smaller seam across it from
	# a two-part core. Both broken where they were filed off.
	wobble = (noise(p, 4.0, 11.0) - 0.5) * 0.05
	seam = band(p, (0.0, 0.0, 1.0), SEAM_W, wobble) * smooth(0.3, 0.42, noise(p, 3.0, 23.0))
	seam2 = band(p, (0.8, 0.5, 0.15), SEAM_W * 0.7, wobble) * smooth(0.46, 0.58, noise(p, 2.6, 31.0))
	ridge = np.maximum(seam, seam2 * 0.7)
	height += ridge * SEAM_TALL

	# Sprue scars, sawn flat at the poles, over the sphere's pinch.
	scar = 1.0 - smooth(SCAR_R * 0.85, SCAR_R, np.arccos(np.abs(p[..., 2])) * (1.0 + 0.2 * (noise(p, 5.0, 41.0) - 0.5)))
	scar_ring = (1.0 - smooth(SCAR_R * 0.72, SCAR_R * 0.82, np.arccos(np.abs(p[..., 2])))) * scar
	height = height * (1.0 - scar) - scar * 0.02

	# Where it has rolled: faint tracks round the ball, on what stands proud.
	tracks = np.maximum(band(p, (0.3, -0.9, 0.3), 0.13, 0.0), band(p, (-0.7, 0.2, 0.68), 0.1, 0.0))
	track_bits = smooth(0.5, 0.56, fbm(p, 5.0, 53.0))
	worn = np.maximum(tracks * track_bits * 0.45, np.maximum(ridge * 0.95, lip * 0.5 * smooth(0.5, 0.58, noise(p, 7.0, 61.0))))
	worn = np.maximum(worn, scar_ring * 0.6 * smooth(0.4, 0.5, noise(p, 9.0, 67.0))) * (1.0 - pit)

	# Rust: a trace, kept to the pits and the seam.
	bloom = fbm(p, 2.6, 71.0) + 0.16 * pit + 0.12 * smooth(0.0, 0.8, ridge) - 0.1 * tracks
	rust = smooth(0.66, 0.70, bloom)
	rust_deep = smooth(0.72, 0.76, bloom + 0.05 * (noise(p, 8.0, 79.0) - 0.5))

	shade = smooth(0.34, 0.56, fbm(p, 4.2, 83.0))     # two tones of iron
	col = np.array(IRON_LOW) + (np.array(IRON) - np.array(IRON_LOW)) * shade[..., None]

	def over(base, tone, mask):
		return base + (np.array(tone, dtype=np.float32) - base) * mask[..., None]

	col = over(col, RUST, rust * (1.0 - scar * 0.5))
	col = over(col, RUST_DEEP, rust_deep)
	col = over(col, PIT, smooth(0.3, 0.7, pit) * 0.88)
	col = over(col, WORN, worn)
	col = over(col, IRON_LOW, scar * (1.0 - scar_ring) * 0.5)
	return np.clip(col, 0.0, 1.0).astype(np.float32), height


def normal_map(height, div):
	if div > 1:
		h, w = height.shape
		height = height[:h - h % div, :w - w % div].reshape(h // div, div, w // div, div).mean(axis=(1, 3))
	h, w = height.shape
	lat = math.pi * 0.5 - (np.arange(h, dtype=np.float32) + 0.5) / h * math.pi
	across = np.maximum(np.cos(lat), 0.05)[:, None]
	du = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) / (2.0 * math.tau * BALL_R * across / w)
	dv = np.gradient(height, axis=0) / (math.pi * BALL_R / h)
	nx = -du * NORMAL_GAIN
	ny = dv * NORMAL_GAIN                               # row down is v up: the ship's way
	nz = np.ones_like(height)
	l = np.sqrt(nx * nx + ny * ny + nz * nz)
	return np.stack((nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5), axis=-1).astype(np.float32)


def save_tex(name, rgb):
	h, w = rgb.shape[:2]
	img = bpy.data.images.new(name, w, h, alpha=False)
	px = np.dstack((rgb, np.ones((h, w), dtype=np.float32)))[::-1]
	img.pixels.foreach_set(px.ravel())
	img.update()
	scene = bpy.context.scene
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "JPEG"
	scene.render.image_settings.color_mode = "RGB"
	scene.render.image_settings.quality = 90
	img.file_format = "JPEG"
	img.save_render(str(TEX / (name + ".jpg")))
	bpy.data.images.remove(img)


def write_material():
	lines = "\n".join(f"shader_parameter/{k} = {v}" for k, v in MATERIAL.items())
	(TEX / "ball.tres").write_text(
		'[gd_resource type="ShaderMaterial" format=3]\n\n'
		f'[ext_resource type="Shader" path="{RES}/ship_surface.gdshader" id="1"]\n'
		f'[ext_resource type="Texture2D" path="{RES}/ship_ball.jpg" id="2"]\n'
		f'[ext_resource type="Texture2D" path="{RES}/ship_ball_n.jpg" id="3"]\n\n'
		'[resource]\nshader = ExtResource("1")\n'
		'shader_parameter/albedo_tex = ExtResource("2")\n'
		'shader_parameter/normal_tex = ExtResource("3")\n' + lines + "\n")


# --- The mesh -----------------------------------------------------------------

def build_mesh():
	"""A UV sphere matching the maps: one seam, one vertex at each pole."""
	verts = [(0.0, 0.0, BALL_R)]
	for r in range(1, RINGS):
		lat = math.pi * 0.5 - math.pi * r / RINGS
		for s in range(SEGMENTS):
			a = math.tau * s / SEGMENTS
			verts.append((BALL_R * math.cos(lat) * math.cos(a), BALL_R * math.cos(lat) * math.sin(a), BALL_R * math.sin(lat)))
	verts.append((0.0, 0.0, -BALL_R))
	last = len(verts) - 1

	def at(r, s):
		return 1 + (r - 1) * SEGMENTS + s % SEGMENTS

	def uv(r, s):
		return (s / SEGMENTS, 1.0 - r / RINGS)

	faces, uvs = [], []
	for s in range(SEGMENTS):
		faces.append((0, at(1, s), at(1, s + 1)))
		uvs.append(((s + 0.5) / SEGMENTS, 1.0))
		uvs.extend((uv(1, s), uv(1, s + 1)))
		for r in range(1, RINGS - 1):
			faces.append((at(r, s), at(r + 1, s), at(r + 1, s + 1), at(r, s + 1)))
			uvs.extend((uv(r, s), uv(r + 1, s), uv(r + 1, s + 1), uv(r, s + 1)))
		faces.append((last, at(RINGS - 1, s + 1), at(RINGS - 1, s)))
		uvs.append(((s + 0.5) / SEGMENTS, 0.0))
		uvs.extend((uv(RINGS - 1, s + 1), uv(RINGS - 1, s)))

	mesh = bpy.data.meshes.new("Ball")
	mesh.from_pydata(verts, [], faces)
	mesh.update()
	layer = mesh.uv_layers.new(name="UV")
	for i, loop_uv in enumerate(uvs):
		layer.data[i].uv = loop_uv
	mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
	mesh.materials.append(bpy.data.materials.new("ball"))
	mesh.update()
	ob = bpy.data.objects.new("Ball", mesh)
	bpy.context.collection.objects.link(ob)
	return ob


def export():
	bpy.ops.export_scene.gltf(
		filepath=str(OUT), export_format="GLB", use_selection=False, export_apply=False,
		export_yup=True, export_materials="EXPORT", export_normals=True, export_tangents=False,
		export_animations=False, export_cameras=False, export_lights=False, export_morph=False, export_skins=False)


def prove():
	raw = OUT.read_bytes()
	jlen = struct.unpack_from("<I", raw, 12)[0]
	doc = json.loads(raw[20:20 + jlen].decode("utf8"))
	prim = doc["meshes"][0]["primitives"][0]
	tris = doc["accessors"][prim["indices"]]["count"] // 3
	pos = doc["accessors"][prim["attributes"]["POSITION"]]
	verts = pos["count"]
	wide = max(pos["max"][i] - pos["min"][i] for i in range(3))
	print(f"triangles (glb): {tris}, vertices {verts}, across {wide:.3f} m, material {doc['materials'][0]['name']}")
	if abs(wide - BALL_R * 2.0) > 0.01 or doc["materials"][0]["name"] != "ball":
		print("FAIL the ball's size or material")
		return 1
	return 0


def main():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.scene.new(type="NEW")
	TEX.mkdir(parents=True, exist_ok=True)
	albedo, height = paint(TEX_W)
	save_tex("ship_ball", albedo)
	save_tex("ship_ball_n", normal_map(height, NORMAL_DIV))
	write_material()
	build_mesh()
	export()
	sys.exit(prove())


main()
