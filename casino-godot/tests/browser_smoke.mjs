// Use the debug export: the bridge only reads state and control bounds.
import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({ headless: true,
  ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}),
  args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader'] });
try {
 for (const mobile of [false, true]) {
  const context = await browser.newContext({ viewport: mobile ? {width:390,height:798} : {width:1440,height:900}, hasTouch:mobile, isMobile:mobile });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type()==='error' && !m.text().includes('404')) errors.push(m.text()); });
  const state = () => page.evaluate(() => window.pitBossSnapshot);
  const target = prefix => page.evaluate(prefix => window.pitBossUI.find(b=>b.text.startsWith(prefix) && !b.disabled), prefix);
  async function swipe(x,y,dy) {
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
   for(let i=1;i<=10;i++) {await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y+dy*i/10}]}); await page.waitForTimeout(25);}
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await page.waitForTimeout(500);
  }
  async function button(prefix) {
   console.log(`${mobile ? "touch" : "desktop"}: ${prefix}`);
   await page.waitForFunction(prefix => window.pitBossUI.some(b=>b.text.startsWith(prefix) && !b.disabled), prefix, {timeout:30000});
   await page.waitForTimeout(150);
   for(let i=0;i<18;i++) {
    const b=await target(prefix); assert.ok(b,`Enabled button: ${prefix}`);
    const [x,y,w,h]=b.clip;
    if(b.y>=y && b.y+b.h<=y+h) {
     const clickX=(Math.max(b.x,x)+Math.min(b.x+b.w,x+w))/2;
     if(mobile) await page.touchscreen.tap(clickX,b.y+b.h/2); else await page.mouse.click(clickX,b.y+b.h/2);
     await page.waitForTimeout(200); return;
    }
    const down=b.y<y;
    if(mobile) await swipe(x+w/2,y+h*(down?.3:.7),h*(down?.4:-.4));
    else {await page.mouse.move(x+w/2,y+h/2);await page.mouse.wheel(0,down?-240:240);await page.waitForTimeout(200);}
   }
   throw Error(`Could not scroll to ${prefix}`);
  }
  async function pane(name) {
   if(!mobile)return;
   console.log(`touch pane: ${name}`);
   await page.waitForFunction(name=>window.pitBossUI.some(b=>b.text===name),name,{timeout:30000});
   const b=await page.evaluate(name=>window.pitBossUI.filter(b=>b.text===name).sort((a,b)=>b.y-a.y)[0],name);
   await page.touchscreen.tap(b.x+b.w/2,b.y+b.h/2);
   await page.waitForFunction(name=>window.pitBossLayout.pane===name.toLowerCase(),name,{timeout:30000});
  }
  try {
   await page.addInitScript(()=>{window.pitBossRequestFullState=true;});
   await page.goto(process.env.CASINO_TEST_URL || 'http://127.0.0.1:8093/casino-debug/game.html');
   await page.waitForFunction(()=>window.pitBossUI,null,{timeout:90000});
   await button('Start casino');
   await pane('Manage');
   if(mobile) {await page.keyboard.press('Space'); await page.waitForTimeout(1200);} else await button('Pause');
   await pane('Table'); await button('Move table');
   await page.waitForFunction(()=>window.pitBossLayout.building && window.pitBossLayout.floor_visible && !window.pitBossLayout.inspector_visible || window.pitBossLayout.building && !window.pitBossLayout.responsive_state.startsWith('mobile'));
   let layout=await page.evaluate(()=>window.pitBossLayout);
   assert.ok(layout.floor_visible,'Move exposes floor');
   const selection=layout.selected;
   if(mobile) {
    await page.setViewportSize({width:844,height:390});await page.waitForTimeout(1200);
    layout=await page.evaluate(()=>window.pitBossLayout);
    assert.ok(layout.floor_visible && !layout.inspector_visible,'Landscape move exposes targeting surface');
    assert.equal(layout.selected,selection,'Resize preserves selection');
    await page.setViewportSize({width:390,height:844});await page.waitForTimeout(1200);
   }
   await button('Cancel');
   await pane('Manage'); await button('+ Build games...');
   await button('Place machine -');
   await page.waitForFunction(()=>window.pitBossLayout.building && window.pitBossLayout.floor_visible);
   await button('Cancel');
   await pane('Manage'); await button('Walk the floor');
   await page.waitForFunction(()=>window.pitBossLayout.visitor);
   await pane('Floor');
   await page.screenshot({path:`/tmp/pit-boss-${mobile?'mobile':'desktop'}.png`});
   await pane('Manage'); await button('Manage casino');
   for(const action of ['Finance','Casino development','Staff & assignments','Incidents & decisions']) {
    await pane('Manage'); await button(action);
   }
   await pane('Manage');
   if(mobile) {await page.keyboard.press('Space');await page.waitForTimeout(700);await page.keyboard.press('Space');await page.waitForTimeout(700);} else {await button('4x');await button('Pause');await button('1x');await button('Pause');}
   if(!mobile) {await button('Save');const saved=await state();await button('Load');const loaded=await state();assert.equal(loaded.version,saved.version);assert.equal(loaded.cash,saved.cash);}
   assert.deepEqual(errors,[]);
   console.log(`${mobile?'Touch portrait/landscape':'Desktop'} passed: move/build/cancel, resize, walk/manage, pages, speed transitions${mobile?'':', save/load'}.`);
  } catch(e) {await page.screenshot({path:'/tmp/pit-boss-failure.png'});console.error(errors); console.error(JSON.stringify((await state()).tables));throw e;}
  finally {await context.close();}
 }
} finally {await browser.close();}
