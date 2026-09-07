import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-fall-foam',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const result=await evalJs(`(()=>{const out=[],nodes=[];__dbg.scene.traverse(o=>{if(o.isMesh&&Number.isFinite(o.userData.baseY)&&Number.isFinite(o.userData.gate)){nodes.push(o);out.push({positions:Array.from(o.geometry.attributes.position.array),position:o.position.toArray(),rotation:[o.rotation.x,o.rotation.y,o.rotation.z],baseY:o.userData.baseY,gate:o.userData.gate});}});const water=__dbg.built.mountain.water;const frames=[];for(const [time,ice,growth] of [[1,0,1],[2,.5,.45],[3,1,1],[4,1,.1],[5,0,.35]]){water.setIce(ice);water.grow(growth);water.update(time);frames.push({time,ice,growth,transforms:nodes.map(o=>{o.updateMatrix();return {matrix:o.matrix.toArray(),visible:o.visible};})});}return {blobs:out,frames};})()`);
const blobs=result.blobs;
const used=new Set();
for(const b of blobs){const matches=saved.meshes.filter(m=>!used.has(m.name)&&m.attrs.position.array.length===b.positions.length&&m.attrs.position.array.every((v,i)=>Math.abs(v-b.positions[i])<1e-6));if(matches.length!==1)throw Error('Foam geometry match is ambiguous');b.mesh=matches[0].name;used.add(b.mesh);delete b.positions;}
writeFileSync(new URL('../assets/zen_reference/fall-foam.json',import.meta.url),JSON.stringify(result));
console.log('Exported source foam',blobs.map(b=>b.mesh));process.exit(0);
