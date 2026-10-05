#!/usr/bin/env python3
"""Fast headless startup guard. No third-party Python packages required."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'),
                        help='Godot executable (default: GODOT env var, or godot)')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    base = [args.godot, '--headless', '--path', str(project)]
    try:
        # A fresh checkout needs Godot's global class registry before loading scripts.
        commands = []
        if not (project / '.godot/global_script_class_cache.cfg').exists():
            commands.append(base + ['--editor', '--import', '--quit'])
        commands.append(base + ['--script', 'tests/startup_smoke.gd'])
        for command in commands:
            result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            # Godot can print script errors and still exit 0; inspect output as well.
            if result.returncode or re.search(r'(?:SCRIPT ERROR:|ERROR:|STARTUP FAIL:)', output):
                print(output.strip(), file=sys.stderr)
                return 1
        if 'STARTUP_SMOKE_OK' not in output:
            print('Startup failed: UI readiness was never confirmed.\n' + output, file=sys.stderr)
            return 1
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f'Startup failed: {error}', file=sys.stderr)
        return 1
    print('Startup smoke passed: scripts loaded, onboarding opened, main UI appeared.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
