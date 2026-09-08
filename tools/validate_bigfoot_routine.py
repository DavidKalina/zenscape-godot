"""Verify the routine export preserves every original animation sample exactly."""
from pathlib import Path
import json
import struct
ROOT = Path(__file__).resolve().parents[1]

def clips(path):
    raw = path.read_bytes()
    chunks = {}
    at = 12
    while at < len(raw):
        size, kind = struct.unpack_from('<II', raw, at)
        chunks[kind] = raw[at+8:at+8+size]
        at += 8+size
    doc = json.loads(chunks[0x4e4f534a])
    binary = chunks[0x004e4942]
    def accessor(index):
        item = doc['accessors'][index]
        view = doc['bufferViews'][item['bufferView']]
        size = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[item['type']]*4
        assert item['componentType']==5126
        offset = view.get('byteOffset',0)+item.get('byteOffset',0)
        stride = view.get('byteStride',size)
        return b''.join(binary[offset+i*stride:offset+i*stride+size] for i in range(item['count']))
    result = {}
    for animation in doc['animations']:
        channels = {}
        for channel in animation['channels']:
            sampler = animation['samplers'][channel['sampler']]
            target = channel['target']
            key = (doc['nodes'][target['node']]['name'],target['path'])
            channels[key] = (sampler.get('interpolation','LINEAR'),accessor(sampler['input']),accessor(sampler['output']))
        result[animation['name']] = channels
    return result

original = clips(ROOT/'assets/models/zenscape-bigfoot-interactions.glb')
routine = clips(ROOT/'assets/models/zenscape-bigfoot-routine.glb')
report = {name: channels==routine.get(name) for name,channels in original.items()}
(ROOT/'docs/fidelity-life/existing-clips-preserved.json').write_text(json.dumps(report,indent=2)+'\n')
assert all(report.values()), report
print('PASS: original animation samples preserved:', ', '.join(report))
