"""Extract the original cloud field; the native integration is maintained separately."""
from pathlib import Path
import re
import sys

project = Path(__file__).resolve().parent.parent
source = Path(sys.argv[1]) if len(sys.argv) > 1 else project.parent / 'zenscape'
text = (source / 'weather.js').read_text()
chunks = [re.search(r'const ' + name + r' = /\* glsl \*/ `([\s\S]*?)`;', text)[1]
          for name in ['NOISE_GLSL', 'CLOUD_GLSL', 'PHASE_GLSL']]
field = re.sub(r'uniform\s+\w+\s+\w+\s*;', '', '\n'.join(chunks))
for original, native in {
    'uCoverage': 'zs_cloud.x', 'uStormy': 'zs_cloud.y', 'uCloudY': 'zs_cloud.z',
    'uCloudH': 'zs_cloud.w', 'uCloudDrift': 'zs_cloud_drift',
    'uSummit': 'zs_summit.xyz', 'uOrog': 'zs_summit.w',
    'uWindDir': 'zs_wind_direction', 'uCondY': 'zs_condensation',
}.items():
    field = re.sub(r'\b' + original + r'\b', native, field)
(project / 'shaders/reference_cloud_field.gdshaderinc').write_text(
    '#ifndef ZS_CLOUD_FIELD\n#define ZS_CLOUD_FIELD\n'
    '#include "res://shaders/reference_globals.gdshaderinc"\n'
    '// Original weather.js cloud/noise/phase field.\n' + field + '\n#endif\n')
