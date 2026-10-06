import asyncio,json,time
from pathlib import Path
from playwright.async_api import async_playwright
report={'checks':[],'errors':[]}
def check(ok,name):
 report['checks'].append({'name':name,'passed':bool(ok)})
 print(('PASS ' if ok else 'FAIL ')+name,flush=True)
async def click_ui(page,text):
 for attempt in range(12):
  buttons=await page.evaluate('window.neonHouseUI || []')
  matches=[b for b in buttons if b['text']==text and not b['disabled']]
  for b in matches:
   x=b['x']+b['w']/2;y=b['y']+b['h']/2;c=b['clip']
   if c[0]<=x<c[0]+c[2] and c[1]<=y<c[1]+c[3]:
    await page.mouse.click(x,y);await page.wait_for_timeout(500);return True
  if matches:
   b=matches[0];c=b['clip'];await page.mouse.move(c[0]+c[2]/2,c[1]+c[3]/2)
   await page.mouse.wheel(0,300 if b['y']>c[1] else -300);await page.wait_for_timeout(300)
  else: await page.wait_for_timeout(300)
 raise RuntimeError('No clickable UI: '+text)
async def main():
 async with async_playwright() as p:
  browser=await p.chromium.launch(headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=await browser.new_page(viewport={'width':1440,'height':900})
  page.on('pageerror',lambda e:report['errors'].append(str(e)))
  page.on('console',lambda m:report['errors'].append(m.text) if m.type=='error' else None)
  await page.add_init_script('window.neonHouseRequestFullState = true')
  await page.goto('http://127.0.0.1:8093/casino-debug/game.html')
  await page.wait_for_function('window.neonHouseUI && window.neonHouseUI.length',timeout=90000)
  await click_ui(page,'Start casino')
  await click_ui(page,'Open casino')
  await click_ui(page,'4x')
  before=await page.evaluate('window.neonHouseSnapshot.elapsed')
  await page.wait_for_function('(before)=>window.neonHouseSnapshot.elapsed>before',arg=before,timeout=30000)
  after=await page.evaluate('window.neonHouseSnapshot.elapsed')
  check(after>before,'Debug 4x advances actual simulation')
  await page.keyboard.press('F10');await page.wait_for_timeout(500)
  await page.screenshot(path='/tmp/v03-dev-panel.png')
  # Panel layout: left = viewport width - 370 - 12, content x = left + 12.
  # Button row lies below title and feedback; screenshot retained for inspection.
  await page.keyboard.press('F10');await page.wait_for_timeout(500)
  await click_ui(page,'Pause')
  await page.wait_for_timeout(1500) # Observe a stable, paused authoritative snapshot.
  await click_ui(page,'Save')
  saved=await page.evaluate('window.neonHouseSnapshot')
  await click_ui(page,'Play')
  await page.wait_for_function('(at)=>window.neonHouseSnapshot.elapsed>at+3',arg=saved['elapsed'],timeout=30000)
  await click_ui(page,'Load')
  await click_ui(page,'Pause')
  await page.wait_for_timeout(1500)
  loaded=await page.evaluate('window.neonHouseSnapshot')
  check(loaded['elapsed']<=saved['elapsed']+3 and loaded['version']==saved['version'],'Browser current save/load')
  for action in ['Finance','Casino development','Staff & assignments','Incidents & decisions','+ Build games...']:
   await click_ui(page,action)
   check(True,'Desktop management navigation: '+action)
  await click_ui(page,'Finance')
  for width,height,label in [(1440,900,'desktop'),(800,900,'tablet'),(844,390,'landscape'),(390,844,'portrait'),(320,568,'portrait-min')]:
   await page.set_viewport_size({'width':width,'height':height});await page.wait_for_timeout(1000)
   await page.screenshot(path='/tmp/v03-web-'+label+'.png')
   check(await page.locator('canvas').is_visible(),'Debug canvas at '+label)
  release=await browser.new_page(viewport={'width':1440,'height':900})
  release.on('pageerror',lambda e:report['errors'].append('release '+str(e)))
  release.on('console',lambda m:report['errors'].append('release '+m.text) if m.type=='error' else None)
  await release.goto('http://127.0.0.1:8093/casino/game.html')
  await release.wait_for_timeout(25000)
  check(await release.locator('canvas').is_visible(),'Release web canvas starts')
  check(await release.evaluate('typeof window.neonHouseSnapshot === "undefined" && typeof window.neonHouseUI === "undefined"'),'Release has no debug telemetry')
  await release.mouse.click(720,413);await release.wait_for_timeout(1000)
  await release.keyboard.press('F10');await release.wait_for_timeout(500)
  await release.screenshot(path='/tmp/v03-release-f10.png')
  check(not report['errors'],'No browser runtime/console errors')
  Path('/tmp/v03-web-regression.json').write_text(json.dumps(report,indent=2))
  await browser.close()
  if report["errors"] or not all(c["passed"] for c in report["checks"]): raise SystemExit(1)
asyncio.run(main())
