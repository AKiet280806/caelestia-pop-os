#!/usr/bin/env python3
"""Small stdlib-only pin/receipt helper. Never executes a shell or installs packages."""
# SPDX-License-Identifier: GPL-3.0-or-later
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
PINS = json.loads((ROOT / "pins.json").read_text())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def fingerprint(stage: str) -> str:
    h = hashlib.sha256()
    paths = [ROOT / "pins.json", *sorted((ROOT / "installer").glob("runtime*.sh")),
             *sorted((ROOT / "scripts").glob("*.py")), ROOT / "scripts/build-plugins.sh"]
    if stage == "shell":
        paths += sorted(p for p in (ROOT / "shell").rglob("*") if p.is_file() and ".git" not in p.parts)
    if stage == "cli":
        paths += sorted((ROOT / "src/cli-overrides").glob("*"))
    if stage == "plugins":
        paths += sorted((ROOT / "src/native-window-actions").glob("*"))
    for path in paths:
        if path.is_file():
            h.update(str(path.relative_to(ROOT)).encode() + b"\0" + digest(path).encode())
    return h.hexdigest()


def validate() -> None:
    assert PINS["schema_version"] == 1, "Unsupported pins schema"
    for source in [PINS["wayland"], *PINS["sources"].values()]:
        assert re.fullmatch(r"[0-9a-f]{40}", source["commit"]), source
        assert source["url"].startswith("https://"), source
    for artifact in [PINS["sass"], *PINS["fonts"]]:
        assert artifact["url"].startswith("https://"), artifact
        assert re.fullmatch(r"[0-9a-f]{64}", artifact["sha256"]), artifact
    for font in PINS["fonts"]:
        assert re.fullmatch(r"[0-9a-f]{64}", font["license_sha256"]), font
        assert Path(font["filename"]).name == font["filename"], font


def main() -> int:
    action = sys.argv[1]
    if action == "validate":
        validate()
    elif action == "pin":
        value = PINS
        for part in sys.argv[2].split("."):
            value = value[int(part)] if isinstance(value, list) else value[part]
        print("\n".join(map(str, value)) if isinstance(value, list) else value)
    elif action == "constraints":
        for name, version in PINS["python_constraints"][sys.argv[2]].items():
            print(f"{name}=={version}")
    elif action == "receipt-save":
        stage, destination = sys.argv[2:4]
        products = {}
        for item in sys.argv[4:]:
            path = Path(item)
            for product in sorted(path.rglob("*")) if path.is_dir() else [path]:
                if product.is_file() and "__pycache__" not in product.parts and product.suffix != ".pyc":
                    products[str(product)] = digest(product)
        if not products:
            raise ValueError("A receipt must contain verified installed products")
        receipt = {"stage": stage, "inputs": fingerprint(stage), "products": products}
        temporary = Path(destination + ".tmp")
        temporary.write_text(json.dumps(receipt, indent=2) + "\n")
        os.replace(temporary, destination)
    elif action == "receipt-check":
        stage, source = sys.argv[2:4]
        try:
            receipt = json.loads(Path(source).read_text())
            return 0 if (receipt["stage"] == stage and receipt["inputs"] == fingerprint(stage)
                         and receipt["products"] and all(Path(p).is_file() and digest(Path(p)) == sha
                         for p, sha in receipt["products"].items())) else 1
        except (OSError, ValueError, KeyError):
            return 1
    else:
        raise ValueError(f"Unknown operation: {action}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
