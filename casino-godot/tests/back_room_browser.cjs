const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/home/codespace/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader']});
 try {
  for(const size of [{width:1440,height:900},{width:390,height:844},{width:844,height:390}]){
   const context=await browser.newContext({viewport:size,hasTouch:size.width<1000,isMobile:size.width<1000});
   const page=await context.newPage();const errors=[];
   page.on('console',m=>{if(m.text().includes('SCRIPT ERROR:') || m.text().startsWith('ERROR:')) errors.push(m.text())});
   page.on('pageerror',e=>errors.push(e.message));
   await page.goto((process.env.PIT_BOSS_TEST_URL || 'http://127.0.0.1:8093')+'/casino-debug/game.html');
   await page.waitForFunction(()=>window.pitBossUI,{timeout:60000});
   async function tap(text){
    await page.waitForFunction(text=>pitBossUI.some(b=>b.text===text),text);
    await page.waitForTimeout(350);
    let b=await page.evaluate(text=>pitBossUI.find(b=>b.text===text),text);
    if(b.y+b.h>b.clip[1]+b.clip[3]){await page.mouse.move(size.width/2,size.height/2);await page.mouse.wheel(0,800);await page.waitForTimeout(1200);b=await page.evaluate(text=>pitBossUI.find(b=>b.text===text),text)}
    assert.ok(b&&!b.disabled,`Available ${text}`);
    await page.mouse.click(b.x+b.w/2,b.y+b.h/2);await page.waitForTimeout(1200);
   }
   await tap('Start casino');
   const entry=await page.evaluate(()=>({x:pitBossLayout.floor[0]+pitBossLayout.camera[0]+405*pitBossLayout.zoom,y:pitBossLayout.floor[1]+pitBossLayout.camera[1]+38*pitBossLayout.zoom}));
   console.log('ENTRY',size,entry);
   await page.mouse.click(entry.x,entry.y);
   await page.waitForFunction(()=>pitBossUI.some(b=>b.text==='Game lobby'),{timeout:10000});
   await page.waitForTimeout(800);
   await page.screenshot({path:`/tmp/back-room-browser-${size.width}-lobby.png`});
   await tap('Slots');
   await tap('SPIN');
   await page.waitForTimeout(2200);
   await page.screenshot({path:`/tmp/back-room-browser-${size.width}-slots.png`});
   await tap('Wallet recovery');
   await page.screenshot({path:`/tmp/back-room-browser-${size.width}-recovery.png`});
   await tap('Return to floor');
   assert.equal(await page.evaluate(()=>pitBossLayout.floor_visible),true,'Floor restored');
   assert.equal(errors.length,0,errors.join('\n'));
   console.log(`BROWSER ${size.width}x${size.height}: PASS lobby/slot/recovery/exit`);
   await context.close();
  }
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
