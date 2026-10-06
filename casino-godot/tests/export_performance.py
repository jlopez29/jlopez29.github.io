#!/usr/bin/env python3
"""Export an isolated release/debug fixture; never add test hooks to casino/."""
import argparse, pathlib, shutil, subprocess
p=argparse.ArgumentParser()
p.add_argument('--godot',required=True)
p.add_argument('--output',default='/tmp/neon-perf-web')
p.add_argument('--debug',action='store_true')
a=p.parse_args()
source=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
project=out/'project'
shutil.copytree(source,project,ignore=shutil.ignore_patterns('.godot'),dirs_exist_ok=True)
(project/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/performance_web.gd" id="1"]\n[node name="Performance" type="Control"]\nlayout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\nscript = ExtResource("1")\n')
preset=project/'export_presets.cfg'
preset.write_text(preset.read_text().replace('exclude_filter="tests/*"','exclude_filter=""'))
for args in [['--editor','--import','--quit'],['--export-debug' if a.debug else '--export-release','Web',str(out/'game.html')]]:
 r=subprocess.run([a.godot,'--headless','--path',str(project),*args],capture_output=True,text=True)
 (out/('import.log' if '--editor' in args else 'export.log')).write_text(r.stdout+r.stderr)
 if r.returncode or 'ERROR:' in r.stdout+r.stderr: raise SystemExit(r.stdout+r.stderr)
print(out/'game.html')
