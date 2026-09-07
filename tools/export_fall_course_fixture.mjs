import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
const THREE=createRequire(new URL('../../zenscape/package.json',import.meta.url))('three');
const source=readFileSync(new URL('../../zenscape/waterfall.js',import.meta.url),'utf8');
const genome=readFileSync(new URL('../../zenscape/genome.js',import.meta.url),'utf8');
const trace=source.slice(source.indexOf('function traceCourse('),source.indexOf('// How wide is the water here?'));
const slope=source.slice(source.indexOf('const EPS ='),source.indexOf('// The line water would actually take:'));
const radius=genome.slice(genome.indexOf('export function poolRadiusAt('),genome.indexOf('// `size` is the plot',genome.indexOf('export function poolRadiusAt('))).replace('export function','function');
const smooth=source.slice(source.indexOf('function smoothstep('),source.indexOf('function fract('));
const evaluate=new Function('world','x','z','target',`${smooth}\n${radius}\n${slope}\n${trace}\nreturn traceCourse(world,x,z,target,world.pool.waterY);`);
const pool={x:0,z:0,waterY:0.38,radius:2.5,lobes:[{amp:0.08,k:3,ph:0.7}],stretch:1.15,stretchTheta:0.3};
const resampleCode=source.slice(source.indexOf('const DESCENT_W ='),source.indexOf('// ---------------------------------------------------------------------------',source.indexOf('const DESCENT_W =')));
const sample=new Function('pts','n',`${resampleCode}\nreturn resample(pts,n);`);
const roomCode=source.slice(source.indexOf('function waterlineHalfWidth(world,'),source.indexOf('// Resample a 3D polyline'));
const countCode=source.slice(source.indexOf('const RINGS_MIN ='),source.indexOf('function hash('));
const strandStart=source.indexOf('function buildStrand(');
const strandBody=source.slice(source.indexOf('  const { heightAt, pool: POOL } = world;',strandStart),source.indexOf('  // --- Geometry: a swept',strandStart));
const strand=new Function('THREE','world','startX','startZ','aim','lipHalf','depth','across','flow',`${smooth}\n${radius}\n${slope}\n${trace}\n${resampleCode}\n${roomCode}\n${countCode}\nconst force=false;\n${strandBody}\nreturn {centers:centers.map(v=>v.toArray()),axA:axA.map(v=>v.toArray()),axB:axB.map(v=>v.toArray()),halfW,thick,steep,aer,tau,rooms,ledges,impact:impact.toArray()};`);
const cases=[];
for(const [kind,x,z] of [['slope',6,4],['apron',7,-4],['pit',-8,8],['wall',6,1]]){
 const heightAt=kind==='slope'?(x,z)=>0.1+Math.sqrt(x*x+z*z)*0.6:kind==='apron'?(x,z)=>0.1+Math.sqrt(x*x+z*z)*0.07+Math.sin(x*1.7)*Math.cos(z*0.9)*0.02:kind==='wall'?(x,z)=>Math.max(0.1,4*Math.tanh((x-1)*3)):(x,z)=>2+0.1*((x+8)**2+(z-8)**2);
 const expected=evaluate({heightAt,pool},x,z,{x:0,z:0});
 const rings=[6,17,26].map(count=>({count,points:sample(expected.pts.map(p=>new THREE.Vector3(p.x,p.h,p.z)),count).map(p=>({x:p.x,z:p.z,h:p.y}))}));
 cases.push({kind,x,z,pool,target:{x:0,z:0},expected,rings,strand:strand(THREE,{heightAt,pool},x,z,{x:0,z:0},0.5,0.3,new THREE.Vector3(0,0,1),0.8)});
}
writeFileSync(new URL('../tests/fixtures/fall-course-source.json',import.meta.url),JSON.stringify({sourceSha256:createHash('sha256').update(trace+slope+radius+smooth+resampleCode+roomCode+countCode+strandBody).digest('hex'),cases},null,2)+'\n');
