import {readFileSync,writeFileSync} from 'node:fs';
import {openBrowser} from './capture_browser.mjs';
const saved=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('godot-bird-flight',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(saved.query);
const result=await evalJs(`(async()=>{
 const d=__dbg,originalBirds=d.built.mountain.birds,w=d.weather().wind;
 const {buildBirds}=await import('/birds.js');const heights=[];
 const b=buildBirds({heightAt:(x,z)=>{const y=d.built.mountain.world.heightAt(x,z);heights.push([x,z,y]);return y;},size:d.built.mountain.world.size,seed:d.built.mountain.world.seed,wind:w});
 b.birds.forEach((v,i)=>Object.assign(v,originalBirds.birds[i]));
 b.cols.splice(0,b.cols.length,...JSON.parse(JSON.stringify(originalBirds.cols)));heights.length=0;
 const mesh=b.group.children.find(o=>o.geometry?.attributes.aWing);
 if(!mesh)throw Error('Source bird mesh missing');
 const copy=()=>JSON.parse(JSON.stringify(b.birds));
 const output={birds:copy(),cols:b.cols,species:b.group.userData.species,positions:Array.from(mesh.geometry.attributes.position.array),wind:w.uWind.value,direction:w.uWindDir.value.toArray(),frames:[],heights};
 const original=Math.random;let seed=7311;
 Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;};
 try{for(let i=0;i<300;i++){b.update(i/30,1/30);if([0,29,149,299].includes(i))output.frames.push({step:i+1,birds:copy()});}}finally{Math.random=original;}
 return output;
})()`);
const candidates=saved.meshes.filter(m=>m.role==='birds');
const match=candidates.find(m=>m.attrs.position.array.length===result.positions.length&&m.attrs.position.array.every((v,i)=>Math.abs(v-result.positions[i])<1e-5));
if(!match)throw Error('Live flock geometry does not match imported bird mesh');
result.mesh=match.name;delete result.positions;
writeFileSync(new URL('../assets/zen_reference/bird-flight.json',import.meta.url),JSON.stringify(result));
console.log('Exported',result.birds.length,'bird states,',result.cols.length,'thermals, mesh',result.mesh,'wind',result.wind,result.direction,'species',result.species);
process.exit(0);
