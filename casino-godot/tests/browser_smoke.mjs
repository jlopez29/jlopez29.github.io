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
  const state = () => page.evaluate(() => window.neonHouseSnapshot);
  const target = prefix => page.evaluate(prefix => window.neonHouseUI.find(b=>b.text.startsWith(prefix) && !b.disabled), prefix);
  async function swipe(x,y,dy) {
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x,y}]});
   for(let i=1;i<=10;i++) {await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y:y+dy*i/10}]}); await page.waitForTimeout(25);}
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await page.waitForTimeout(500);
  }
  async function button(prefix) {
   console.log(`${mobile ? "touch" : "desktop"}: ${prefix}`);
   await page.waitForFunction(prefix => window.neonHouseUI.some(b=>b.text.startsWith(prefix) && !b.disabled), prefix, {timeout:15000});
   await page.waitForTimeout(150);
   for(let i=0;i<18;i++) {
    const b=await target(prefix); assert.ok(b,`Enabled button: ${prefix}`);
    const [x,y,w,h]=b.clip;
    if(b.y>=y && b.y+b.h<=y+h) {
     if(mobile) await page.touchscreen.tap(b.x+b.w/2,b.y+b.h/2); else await page.mouse.click(b.x+b.w/2,b.y+b.h/2);
     await page.waitForTimeout(200); return;
    }
    const down=b.y<y;
    if(mobile) await swipe(x+w/2,y+h*(down?.3:.7),h*(down?.4:-.4));
    else {await page.mouse.move(x+w/2,y+h/2);await page.mouse.wheel(0,down?-240:240);await page.waitForTimeout(200);}
   }
   throw Error(`Could not scroll to ${prefix}`);
  }
  async function pane(name){if(mobile) await button(name);}
  try {
   await page.goto(process.env.CASINO_TEST_URL || 'http://127.0.0.1:8090/game.html');
   await page.waitForFunction(()=>window.neonHouseUI,null,{timeout:60000});
   await page.waitForTimeout(800);
   await button("Let's open the house");
   await pane('Table'); await button('Hire dealer'); await button('Hire dealer');
   await pane('Manage'); await button('Pause'); await button('Open casino');
   await button('Walk the floor');
   await pane('Table'); await button('Walk to this table');
   await page.waitForTimeout(2200);
   await pane('Table'); await button('Join craps table');
   assert.equal((await state()).joined,1);
   assert.equal((await state()).tables[0].shooter,0,'Empty table grants visitor first hand');
   await pane('Manage'); await button('1×'); await pane('Table');
   await button('Field +');
   assert.equal((await state()).tables[0].owner.field,25);
   const rolls=(await state()).tables[0].rolls;
   await button('SHOOT DICE');
   await page.waitForFunction(n=>window.neonHouseSnapshot.tables[0].rolls>n,rolls);
   assert.equal((await state()).tables[0].owner.field,0);
   await button('Pass dice to CPU'); await button('Hold betting');
   const held=(await state()).tables[0].rolls;
   await button('Join shooter rotation');
   assert.notEqual((await state()).tables[0].shooter,0,'Queue does not steal the hand');
   await button('Place'); await button('Place 6 +');
   assert.equal((await state()).tables[0].owner.six,30);
   await button('Hard'); await button('Hard 4 +');
   assert.equal((await state()).tables[0].owner.hard_4,25);
   await button('My bets'); await button('Hard 4 ·');
   assert.equal((await state()).tables[0].owner.hard_4,0);
   assert.equal((await state()).tables[0].rolls,held,'Hold leaves bets open while time advances');
   await button('Save'); const saved=await state();
   await page.waitForTimeout(2500); await page.reload();
   await page.waitForFunction(()=>window.neonHouseUI,null,{timeout:60000});
   await page.waitForTimeout(500); await button("Let's open the house"); await button('Load');
   const loaded=await state();
   assert.equal(loaded.joined,1); assert.equal(loaded.tables[0].owner.six,30);
   assert.equal(loaded.wallet,saved.wallet); assert.equal(loaded.tables[0].shooter,saved.tables[0].shooter);
   assert.equal(loaded.tables[0].betting_hold,true); assert.equal(loaded.tables[0].owner_queued,true);
   await pane('Table'); await button('Resume CPU');
   await page.waitForFunction(n=>window.neonHouseSnapshot.tables[0].rolls>n,held,{timeout:25000});
   await button('History');
   await page.screenshot({path:`/tmp/neon-house-${mobile?'mobile':'desktop'}.png`});
   if(mobile) {
    await page.setViewportSize({width:844,height:344});await page.waitForTimeout(600);
    await button('Place');await button('Place 8 +');
    assert.equal((await state()).tables[0].owner.eight,30);
    await page.screenshot({path:'/tmp/neon-house-landscape.png'});
    await page.setViewportSize({width:320,height:650});await page.waitForTimeout(600);
    await button('My bets');await button('Take down removable bets');
    assert.equal((await state()).tables[0].owner.eight,0);
    await pane('Floor');
   } else await button('Leave table / walk floor');
   assert.equal((await state()).joined,-1);
   assert.notEqual((await state()).tables[0].shooter,0);
   assert.deepEqual(errors,[]);
   console.log(`${mobile?'Touch portrait/landscape':'Desktop'} passed: staffing, walking, betting, handoff, CPU hold/resume, queue, removals, save/reload.`);
  } catch(e) {await page.screenshot({path:'/tmp/neon-house-failure.png'});console.error(errors); console.error(JSON.stringify((await state()).tables));throw e;}
  finally {await context.close();}
 }
} finally {await browser.close();}
