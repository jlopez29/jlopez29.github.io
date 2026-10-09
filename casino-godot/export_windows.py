#!/usr/bin/env python3
"""Export Pit Boss as a standalone Windows 64-bit release executable."""
import argparse
import os
from pathlib import Path

from export_web import run_godot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"),
                        help="Godot binary with matching Windows export templates")
    args = parser.parse_args()
    project = Path(__file__).resolve().parent
    output = project.parent / "casino-windows" / "PitBoss.exe"
    output.parent.mkdir(parents=True, exist_ok=True)
    run_godot([args.godot, "--headless", "--path", str(project),
               "--editor", "--import", "--quit"])
    run_godot([args.godot, "--headless", "--path", str(project),
               "--export-release", "Windows Desktop", str(output)])
    print(f"Built Windows 64-bit release: {output}")


if __name__ == "__main__":
    main()
