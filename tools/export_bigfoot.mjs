// Export the original procedural model without a browser or renderer.
import { writeFileSync, mkdirSync } from 'node:fs';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
const source = resolve(process.argv[2] ?? '../zenscape');
const output = fileURLToPath(new URL('../assets/bigfoot/', import.meta.url));
const { buildBigfoot } = await import(pathToFileURL(source + '/bigfoot-model.js'));
const { peekTreeGeometry } = await import(pathToFileURL(source + '/bigfoot-tree.js'));
const THREE = await import(pathToFileURL(source + '/node_modules/three/build/three.module.js'));
const { GLTFExporter } = await import(pathToFileURL(source + '/node_modules/three/examples/jsm/exporters/GLTFExporter.js'));
globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(result => { this.result = result; this.onloadend?.(); }); }
  readAsDataURL(blob) { blob.arrayBuffer().then(result => { this.result = `data:${blob.type};base64,${Buffer.from(result).toString('base64')}`; this.onloadend?.(); }); }
};
mkdirSync(output, { recursive: true });
const actor = buildBigfoot('rangy');
actor.pose('idle');
let index = 0;
const names = {};
actor.root.traverse(node => { const original = node.name || 'Eye'; node.name = `n${index++}_${original.replace(/[^a-zA-Z0-9]+/g, '_')}`; names[node.name] = original; });
const exporter = new GLTFExporter();
const model = await exporter.parseAsync(actor.root, { binary: true, onlyVisible: false, trs: true });
writeFileSync(output + '/wanderer.glb', Buffer.from(model));
writeFileSync(output + '/rig.json', JSON.stringify({source:'bigfoot-model.js rangy', nodes:names}, null, 2));
const { bark, crown } = peekTreeGeometry();
const tree = new THREE.Group(); tree.name = 'OldTree';
const trunk = new THREE.Mesh(bark, new THREE.MeshStandardMaterial({ color: '#66513d', flatShading:true, roughness:1 })); trunk.name = 'Bark';
const canopy = new THREE.Mesh(crown, new THREE.MeshStandardMaterial({ color: '#35483a', flatShading:true, roughness:1 })); canopy.name = 'Crown';
tree.add(trunk, canopy);
const treeData = await exporter.parseAsync(tree, { binary:true, trs:true });
writeFileSync(output + '/old_tree.glb', Buffer.from(treeData));
console.log(JSON.stringify({ nodes:index, triangles:actor.triangles, modelBytes:model.byteLength, treeBytes:treeData.byteLength }));
const poses = [];
for (const kind of ['idle', 'look', 'walk', 'peek']) {
  for (const time of [0, 2.2, 5.8, 9.8, 12.4]) {
    actor.pose(kind, time, { cameraPosition: new THREE.Vector3(2, 3, 8), footHeights: {'-1': -0.08, '1': 0.05} });
    const transforms = {};
    actor.root.traverse(node => { transforms[node.name.split('_')[0].slice(1)] = node.matrix.elements.slice(); });
    poses.push({kind, time, transforms});
  }
}
writeFileSync(output + '/poses.json', JSON.stringify(poses));
