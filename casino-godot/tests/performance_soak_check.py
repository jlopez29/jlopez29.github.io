#!/usr/bin/env python3
"""Validate retained browser samples; preserve rendering-host limitations in the report."""
import argparse, json, statistics
p=argparse.ArgumentParser()
p.add_argument('report');p.add_argument('--minutes',type=float,default=30)
a=p.parse_args(); runs=json.load(open(a.report)); failures=[]
for run in runs:
 s=run['samples']
 if run['errors']: failures.append('Browser/Godot errors')
 if not s or s[-1]['real_seconds'] < a.minutes*60: failures.append('Insufficient real-time soak duration')
 if len(s)>1 and not all(b['elapsed']>x['elapsed'] for x,b in zip(s,s[1:])): failures.append('Simulation stopped')
 if s and max(x['nodes'] for x in s)-min(x['nodes'] for x in s)>12: failures.append('Growing Godot node count')
 # Warmup excluded; growth of current workload/population is reported alongside memory.
 tail=s[len(s)//3:]
 if len(tail)>=6:
  first=statistics.median(x['browser']['JSHeapUsedSize'] for x in tail[:3]);last=statistics.median(x['browser']['JSHeapUsedSize'] for x in tail[-3:])
  if last>first*1.5+8_000_000: failures.append('Excessive post-warmup JS heap growth')
  first_frame=statistics.median(x['frame_mean_ms'] for x in tail[:3]);last_frame=statistics.median(x['frame_mean_ms'] for x in tail[-3:])
  if last_frame>first_frame*1.5: failures.append('Frame time degraded >50% after warmup')
 print(json.dumps({'scale':run['scale'],'speed':run['speed'],'samples':len(s),'failures':failures}))
raise SystemExit(bool(failures))
