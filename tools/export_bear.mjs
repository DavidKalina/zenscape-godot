// Capture the existing procedural bear as independently editable rigid parts.
// This exports one pose; Three.js gait/IK and behavior are not baked animations.
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
const source = resolve(process.argv[2] ?? '../zenscape');
const output = fileURLToPath(new URL('../art/blender/bear/', import.meta.url));
const { buildBears } = await import(pathToFileURL(source + '/bears.js'));
const THREE = await import(pathToFileURL(source + '/node_modules/three/build/three.module.js'));
const { GLTFExporter } = await import(pathToFileURL(source + '/node_modules/three/examples/jsm/exporters/GLTFExporter.js'));
globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(result => { this.result=result; this.onloadend?.(); }); }
  readAsDataURL(blob) { blob.arrayBuffer().then(result => { this.result=`data:${blob.type};base64,${Buffer.from(result).toString('base64')}`; this.onloadend?.(); }); }
};
const actor = buildBears({ heightAt:()=>0, count:1, scale:1.32, cruise:0, seed:9137 });
const b=actor.bear;
const normalize=new THREE.Matrix4().makeRotationY(-b.yaw)
  .multiply(new THREE.Matrix4().makeTranslation(-b.x,0,-b.z));
const root=new THREE.Group(); root.name='Original_Bear';
const categories=['Body','Head','Tail','UpperLeg','LowerLeg','Paw'];
const limbs=['Front_L','Front_R','Rear_L','Rear_R'];
actor.group.children.forEach((inst,part)=>{
  for(let i=0;i<inst.count;i++) {
    const mat=inst.material.clone();
    const tint=new THREE.Color(); inst.getColorAt(i,tint); mat.color.multiply(tint);
    const mesh=new THREE.Mesh(inst.geometry.clone(),mat);
    mesh.name=categories[part]+(inst.count>1?'_'+limbs[i]:'');
    const transform=new THREE.Matrix4(); inst.getMatrixAt(i,transform);
    transform.premultiply(normalize);
    transform.decompose(mesh.position,mesh.quaternion,mesh.scale);
    root.add(mesh);
  }
});
mkdirSync(output,{recursive:true});
const glb=await new GLTFExporter().parseAsync(root,{binary:true,trs:true});
writeFileSync(output+'/original-bear.glb',Buffer.from(glb));
console.log(JSON.stringify({output,parts:root.children.length,bytes:glb.byteLength}));
