import {openBrowser} from './capture_browser.mjs';
import {readFileSync,writeFileSync} from 'node:fs';
const s=JSON.parse(readFileSync(new URL('../assets/zen_reference/scene.json',import.meta.url)));
const {open,evalJs}=await openBrowser('native-inversion',{flags:['--use-angle=metal','--ignore-gpu-blocklist']});
await open(s.query.replace('tod=0.35','tod=0.26').replace('mist:0.02','mist:0.45'));
const result=await evalJs(`(()=>{const d=__dbg;d.controls.autoRotate=false;d.renderer.setPixelRatio(1);d.renderer.setSize(1440,900);d.camera.aspect=1.6;d.camera.updateProjectionMatrix();d.film.start();let image;for(let i=0;i<30;i++)image=d.film.frame(1/30,{type:'image/png'});return {image,uniforms:Object.fromEntries(["uInv","uInvLine","uInvColor","uSunColor","uSkyColor"].map(k=>[k,d.weather().uniforms[k].value.toArray?.()??d.weather().uniforms[k].value]))};})()`);
writeFileSync(new URL('../docs/fidelity/inversion-source.png',import.meta.url),Buffer.from(result.image.split(',')[1],'base64'));writeFileSync(new URL('../assets/zen_reference/inversion-checks.json',import.meta.url),JSON.stringify(result.uniforms,null,2));console.log(JSON.stringify(result.uniforms));process.exit(0);
