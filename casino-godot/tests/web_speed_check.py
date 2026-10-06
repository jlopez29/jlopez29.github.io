import asyncio,json,time
from pathlib import Path
from playwright.async_api import async_playwright
async def main():
 result={'runs':[],'errors':[]}
 async with async_playwright() as p:
  browser=await p.chromium.launch(headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=await browser.new_page(viewport={'width':1440,'height':900})
  page.on('pageerror',lambda e:result['errors'].append(str(e)))
  page.on('console',lambda m:result['errors'].append(m.text) if m.type=='error' else None)
  await page.add_init_script('window.neonHouseRequestFullState = true')
  await page.goto('http://127.0.0.1:8093/casino-debug/game.html')
  await page.wait_for_function('window.neonHouseUI && window.neonHouseUI.length',timeout=90000)
  for text in ['Start casino','Open casino']:
   b=await page.evaluate('(text)=>window.neonHouseUI.find(b=>b.text===text)',text)
   await page.mouse.click(b['x']+b['w']/2,b['y']+b['h']/2);await page.wait_for_timeout(750)
  await page.keyboard.press('F10');await page.wait_for_timeout(500)
  for speed in [100,1000]:
   await page.wait_for_function('(text)=>window.neonHouseUI.some(b=>b.text===text)',arg=f'{speed}x')
   b=await page.evaluate('(text)=>window.neonHouseUI.find(b=>b.text===text)',f'{speed}x')
   await page.mouse.click(b['x']+b['w']/2,b['y']+b['h']/2);await page.wait_for_timeout(750)
   await page.keyboard.press('F10');await page.wait_for_timeout(500)
   samples=[]
   for i in range(6):
    await page.wait_for_timeout(2000)
    s=await page.evaluate('window.neonHouseSnapshot')
    samples.append({'elapsed':s['elapsed'],'guests':len(s['guests']),'rounds':s['guest_rounds'],'cash':s['cash'],'broken':sum(t['broken'] for t in s['tables'])})
   passed=samples[-1]['elapsed']>samples[0]['elapsed'] and all(s['guests']<=3 for s in samples)
   print('SPEED',speed,'PASS' if passed else 'FAIL',json.dumps(samples),flush=True)
   result['runs'].append({'requested_speed':speed,'passed':passed,'samples':samples})
   await page.screenshot(path=f'/tmp/v03-speed-{speed}.png')
   await page.keyboard.press('F10');await page.wait_for_timeout(500)
  b=await page.evaluate('window.neonHouseUI.find(b=>b.text==="1x")')
  await page.mouse.click(b['x']+b['w']/2,b['y']+b['h']/2);await page.wait_for_timeout(500)
  await page.keyboard.press('F10');await page.wait_for_timeout(500)
  Path('/tmp/v03-speed-browser.json').write_text(json.dumps(result,indent=2))
  await browser.close()
  if result["errors"] or not all(r["passed"] for r in result["runs"]): raise SystemExit(1)
asyncio.run(main())
