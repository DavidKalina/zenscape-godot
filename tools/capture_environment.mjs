import { writeFileSync, mkdirSync } from 'node:fs';
import { openBrowser } from './capture_browser.mjs';
const filming = process.argv.includes('--film');
const {open, evalJs} = await openBrowser('native-cloud-parity', {flags:['--use-angle=metal','--enable-gpu-rasterization','--ignore-gpu-blocklist']});
await open('?seed=7&title=0&grow=1,1,1,1&daylen=0&hud=0&aurora=0&bow=0&tod=0.35&wx=shroud:0,cloud:0.7,mist:0.45,haze:0.15,wind:0.4&cam=32,1.5,1.8893,0,4,0');
const result = await evalJs(`(() => {
 const d=__dbg;
 d.controls.autoRotate=false;
 d.renderer.setPixelRatio(1); d.renderer.setSize(${filming ? 1280 : 1440},${filming ? 854 : 900});
 d.camera.aspect=${filming ? 1280 / 854 : 1440 / 900}; d.camera.updateProjectionMatrix();
 d.film.start(); d.weather().cloudDrift.set(0,0,0);
 let image;
 for(let i=0;i<50;i++) image=d.film.frame(0.02,{type:'image/png'});
 const uniforms={};
 for(const key of ['uSunDir','uSunColor','uSkyColor','uCloudY','uCloudH','uSummit','uOrog','uCondY','uCoverage','uStormy','uRays','uMist','uHaze','uGroundRange']) {
  const value=d.weather().uniforms[key]?.value; uniforms[key]=value?.toArray ? value.toArray():value;
 }
 return {uniforms,image, drift:d.weather().cloudDrift.toArray(), camera:d.camera.position.toArray()};
})()`);
writeFileSync(new URL('../docs/fidelity/source-clouds.png',import.meta.url),Buffer.from(result.image.split(',')[1],'base64'));
writeFileSync(new URL("../docs/fidelity/source-clouds.json",import.meta.url),JSON.stringify({uniforms:result.uniforms,drift:result.drift,camera:result.camera},null,2));
console.log(JSON.stringify(result.uniforms));
if (filming) {
 const directory='/private/tmp/zenscape-source-cloud-film';
 mkdirSync(directory,{recursive:true});
 for(let i=0;i<180;i++) {
  const frame=await evalJs('__dbg.film.frame(1/30,{type:"image/jpeg",quality:0.92})');
  writeFileSync(directory+'/'+String(i).padStart(4,'0')+'.jpg',Buffer.from(frame.split(',')[1],'base64'));
 }
 console.log('Recorded 180 source frames at '+directory);
 console.log('END '+JSON.stringify(await evalJs('({drift:__dbg.weather().cloudDrift.toArray(),state:__dbg.weather().state})')));
}
process.exit(0);
