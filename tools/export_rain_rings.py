"""Port water.js's analytical rain-ring normal without rescheduling droplets."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
source = (root.parent / 'zenscape' / 'water.js').read_text()
ring = re.search(r'      if \(uWet > 0.01 && uIce < 0.5\) \{([\s\S]*?)\n      \}', source)
assert ring, 'Source rain-ring block moved; inspect before regenerating.'
body = 'if (uWet > 0.01 && uIce < 0.5) {' + ring[1] + '\n}\n'
body = body.replace('(viewMatrix * vec4(zsGrad.x, 0.0, zsGrad.y, 0.0)).xyz', 'vec3(zsGrad.x, 0.0, zsGrad.y)')
for a, b in [('uWet','wet'),('uIce','ice'),('uTime','time'),('vIceP','world_p'),('vnHash','zs_noise_hash'),('uChop.w','0.8')]:
    body = body.replace(a, b)
(root / 'shaders/reference_rain_rings.gdshaderinc').write_text(
    '// Generated from water.js ringGLSL by tools/export_rain_rings.py.\n'
    '// Apply in world space before the view transform; rotation commutes with normalization.\n'
    'vec3 zs_rain_ring_normal(vec3 normal, vec3 world_p, float time, float wet, float ice) {\n'
    + body + '\nreturn normal;\n}\n')
