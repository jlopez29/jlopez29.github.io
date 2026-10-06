// Repeatable release fixture profile/soak. Node + Playwright, no production hooks.
import fs from 'node:fs';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.PERF_URL || 'http://127.0.0.1:8094/game.html';
const duration = Number(process.env.PERF_SECONDS || 30);
const scenarios = process.env.PERF_SCENARIOS ? JSON.parse(process.env.PERF_SCENARIOS) : process.env.PERF_SOAK ? [['medium',4]] : [['small',1],['small',4],['medium',1],['medium',4],['large',4]];
const browser = await chromium.launch({headless:true,args:['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const report = [];
try {
 for (const [scale,speed] of scenarios) {
  const page = await browser.newPage({viewport:{width:Number(process.env.PERF_WIDTH || 1440),height:Number(process.env.PERF_HEIGHT || 900)}});
  const errors=[]; page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error' && !m.text().includes('404')) errors.push(m.text());});
  await page.goto(`${base}?scale=${scale}&speed=${speed}`);
  await page.waitForFunction(()=>window.neonPerformance,null,{timeout:90000});
  const cdp=await page.context().newCDPSession(page);await cdp.send('Performance.enable');
  if(process.env.PERF_TRACE) {await cdp.send('Profiler.enable');await cdp.send('Profiler.start');}
  await page.evaluate(()=>{window.perfFrames=[];let last=performance.now();function frame(now){window.perfFrames.push(now-last);last=now;if(window.perfFrames.length>20000)window.perfFrames.shift();requestAnimationFrame(frame);}requestAnimationFrame(frame);});
  const samples=[];const started=Date.now();
  while ((Date.now()-started)/1000 < duration) {
   await page.waitForTimeout(Math.min(60000,duration*1000));
   const sample=await page.evaluate(()=>{const f=window.perfFrames.slice().sort((a,b)=>a-b);window.perfFrames=[];return {...window.neonPerformance,js_heap_estimate_bytes:performance.memory?.usedJSHeapSize,frame_mean_ms:f.reduce((a,b)=>a+b,0)/f.length,frame_p99_ms:f[Math.floor(f.length*.99)],frame_worst_ms:f.at(-1)};});
   const metrics=await cdp.send('Performance.getMetrics');sample.browser=Object.fromEntries(metrics.metrics.filter(m=>['TaskDuration','JSHeapUsedSize','Nodes','LayoutCount','RecalcStyleCount'].includes(m.name)).map(m=>[m.name,m.value]));
   sample.real_seconds=(Date.now()-started)/1000;samples.push(sample);console.log(JSON.stringify({scale,speed,...sample}));
   fs.writeFileSync(process.env.PERF_REPORT || '/tmp/neon-browser-performance.json',JSON.stringify([...report,{scale,speed,samples,errors}],null,2));
  }
  if(process.env.PERF_TRACE) {const {profile}=await cdp.send('Profiler.stop');fs.writeFileSync(`/tmp/neon-${scale}-${speed}.cpuprofile`,JSON.stringify(profile));}
  report.push({scale,speed,samples,errors});await page.close();
 }
} finally {await browser.close();}
fs.writeFileSync(process.env.PERF_REPORT || '/tmp/neon-browser-performance.json',JSON.stringify(report,null,2));
if(report.some(r=>r.errors.length)) process.exitCode=1;
