#!/usr/bin/env python3
"""Check local guide links, exported sources and rendered Lua without installing."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
errors = []
for document in [root / 'README.md', root / 'AGENTS.md', *sorted((root / 'docs').rglob('*.md'))]:
    for target in re.findall(r'\]\(([^)]+)\)', document.read_text()):
        if target.startswith(('http:', 'https:', '#', 'mailto:')):
            continue
        target = target.split('#', 1)[0]
        if target and not (document.parent / target).exists():
            errors.append(f'{document.relative_to(root)}: missing {target}')
for path in [*sorted((root / 'installer').glob('*.py')), *sorted((root / 'scripts').glob('*.py')),
             root / 'src/cli-overrides/record.py', root / 'src/codex-usage/codex_usage.py']:
    compile(path.read_bytes(), str(path), 'exec')
lua = shutil.which('luac5.4') or shutil.which('luac')
if not lua:
    errors.append('Install lua5.4 for Lua syntax verification')
else:
    with tempfile.TemporaryDirectory() as temporary:
        for original in (root / 'configs/hypr').glob('*.lua'):
            path = Path(temporary) / original.name
            path.write_text(original.read_text().replace('@SCALE@', '1.5'))
            subprocess.run([lua, '-p', str(path)], check=True)
if errors:
    raise SystemExit('\n'.join(errors))
print('Guide links, Python and rendered Lua syntax verified')
