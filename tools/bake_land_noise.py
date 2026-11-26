"""Bake the land paint's noise lattices (shaders/endless_ground.gdshader).

The ground and its rock (shaders/endless_rock.gdshaderinc) read value noise
from these instead of hashing every lattice corner per pixel: one filtered
texture sample in place of eight (3D) or four (2D) hashes. Each texel is one
lattice corner's random value; the shaders sample at the smoothstepped
position, so the hardware's linear filter gives the same smooth value noise.

  assets/textures/land_noise_3d.png  128^3 cells, 8-bit, 16 x 8 slices of
                                     128 x 128 (imported as a Texture3D)
  assets/textures/land_noise_2d.png  256^2 cells, 8-bit

Deterministic (a fixed seed): rerun to rebuild, then a headless import.
  python tools/bake_land_noise.py
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures")
N3 = 128
COLS, ROWS = 16, 8
N2 = 256
SEED = 7311


def main() -> int:
	rng = np.random.default_rng(SEED)
	vol = rng.integers(0, 256, size=(N3, N3, N3), dtype=np.uint8)  # [z][y][x]
	sheet = np.zeros((ROWS * N3, COLS * N3), dtype=np.uint8)
	for z in range(N3):
		r, c = divmod(z, COLS)
		sheet[r * N3:(r + 1) * N3, c * N3:(c + 1) * N3] = vol[z]
	Image.fromarray(sheet, "L").save(os.path.join(OUT, "land_noise_3d.png"), optimize=True)
	flat = rng.integers(0, 256, size=(N2, N2), dtype=np.uint8)
	Image.fromarray(flat, "L").save(os.path.join(OUT, "land_noise_2d.png"), optimize=True)
	print("baked land_noise_3d.png (%d^3) and land_noise_2d.png (%d^2) in %s" % (N3, N2, OUT))
	return 0


if __name__ == "__main__":
	sys.exit(main())
