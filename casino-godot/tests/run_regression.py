#!/usr/bin/env python3
"""Run the current Godot suite; runtime script errors fail even if Godot exits zero."""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4'))
parser.add_argument('--quick', action='store_true', help='Skip the six 48-hour runs')
parser.add_argument('--log', type=Path, default=Path('/tmp/v03-regression.log'))
args = parser.parse_args()
if not args.godot:
    parser.error('Pass --godot with the installed Godot binary path')
project = Path(__file__).resolve().parents[1]
command = [args.godot, '--headless', '--path', str(project), '--script', 'tests/run_tests.gd']
if args.quick:
    command += ['--', '--quick']
try:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, timeout=300, stdin=subprocess.DEVNULL)
except subprocess.TimeoutExpired as error:
    output = error.stdout or b''
    if isinstance(output, bytes):
        output = output.decode('utf-8', errors='replace')
    args.log.write_text(output, encoding='utf-8')
    print(f'Regression timed out; log: {args.log}', file=sys.stderr)
    sys.exit(1)
args.log.write_text(result.stdout, encoding='utf-8')
print(result.stdout, end='')
summary = re.search(r'V0\.3 REGRESSION: (\d+) checks, (\d+) failures', result.stdout)
failed = (result.returncode != 0 or not summary or int(summary[2]) != 0
          or re.search(r'SCRIPT ERROR:|ERROR:', result.stdout) is not None)
print(f'Log: {args.log}')
sys.exit(1 if failed else 0)
