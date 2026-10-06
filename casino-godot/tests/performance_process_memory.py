#!/usr/bin/env python3
"""Linux browser-process RSS/CPU sampling alongside a performance_browser.mjs soak."""
import argparse,json,pathlib,time,os
p=argparse.ArgumentParser();p.add_argument('--seconds',type=int,default=1800);p.add_argument('--output',default='/tmp/neon-process-memory.json');a=p.parse_args()
started=time.monotonic();samples=[];initial_roots=None
while time.monotonic()-started<=a.seconds:
 processes={}
 for directory in pathlib.Path('/proc').iterdir():
  if not directory.name.isdigit():continue
  try:
   command=(directory/'cmdline').read_bytes().replace(b'\0',b' ').decode(errors='replace')
   stat=(directory/'stat').read_text().rsplit(')',1)[1].split()
   processes[int(directory.name)]={'parent':int(stat[1]),'command':command,'rss_bytes':int(stat[21])*os.sysconf('SC_PAGE_SIZE'),'cpu_seconds':(int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK')}
  except (OSError,ValueError,IndexError):pass
 roots={pid for pid,info in processes.items() if info['command'].startswith('node casino-godot/tests/performance_browser.mjs')}
 if not roots:break
 if initial_roots is None:initial_roots={min(roots)}
 roots=roots & initial_roots
 if roots!=initial_roots:break
 descendants=set(roots)
 while True:
  expanded=descendants|{pid for pid,info in processes.items() if info['parent'] in descendants}
  if expanded==descendants:break
  descendants=expanded
 selected=[processes[pid] for pid in descendants if pid in processes]
 samples.append({'real_seconds':round(time.monotonic()-started,1),'rss_bytes':sum(x['rss_bytes'] for x in selected),'cpu_seconds':sum(x['cpu_seconds'] for x in selected),'processes':len(selected)})
 pathlib.Path(a.output).write_text(json.dumps(samples,indent=2))
 time.sleep(60)
