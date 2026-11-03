#!/usr/bin/env python3
"""Install only this repository's two audited CLI overrides into its private venv.

Run with the target venv's interpreter. Original files are kept beside the
targets as .before-caelestia-pop-os files; repeated runs never replace backups.
"""
# SPDX-License-Identifier: GPL-3.0-or-later
from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path
import py_compile
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OVERRIDES = {
    "record.py": "subcommands/record.py",
    "cava.conf": "data/templates/cava.conf",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def atomic_copy(source: Path, target: Path) -> None:
    fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=target.parent)
    os.close(fd)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--venv", type=Path, required=True)
    parser.add_argument("--check", action="store_true", help="Read-only verification of installed overrides")
    args = parser.parse_args()
    venv = args.venv.resolve()
    if Path(sys.prefix).resolve() != venv or sys.prefix == sys.base_prefix:
        parser.error("Use the target private venv's bin/python to run this script.")
    if sys.version_info < (3, 13):
        parser.error("The pinned CLI requires Python >= 3.13.")
    distribution = importlib.metadata.distribution("caelestia")
    package = Path(distribution.locate_file("caelestia")).resolve()
    if not package.is_relative_to(venv) or not package.is_dir():
        parser.error("The caelestia package is outside the target private venv.")
    pins = json.loads((ROOT / "pins.json").read_text())
    direct_url = json.loads(distribution.read_text("direct_url.json") or "{}")
    if direct_url.get("vcs_info", {}).get("commit_id") != pins["sources"]["cli"]["commit"]:
        parser.error("Installed CLI provenance differs from the pinned git commit.")
    for name, relative in OVERRIDES.items():
        source = ROOT / "src/cli-overrides" / name
        target = package / relative
        if target.is_symlink() or not target.is_file():
            parser.error(f"Expected regular installed package file: {target}")
        if not target.resolve().is_relative_to(package):
            parser.error(f"Target escapes the installed package: {target}")
        if name.endswith(".py"):
            # Validate the entire replacement before touching its original.
            compile(source.read_bytes(), str(source), "exec")
        if args.check:
            if sha(source) != sha(target):
                parser.error(f"Override mismatch: {target}")
            continue
        backup = target.with_name(target.name + ".before-caelestia-pop-os")
        if not backup.exists():
            shutil.copy2(target, backup)
        atomic_copy(source, target)
        if name.endswith(".py"):
            py_compile.compile(str(target), doraise=True)
        if sha(source) != sha(target):
            raise RuntimeError(f"Failed to verify copied override: {target}")
        print(f"Verified {target}; original backup: {backup}")
    print("CLI override hashes verified" if args.check else "CLI overrides installed and compiled")


if __name__ == "__main__":
    main()
