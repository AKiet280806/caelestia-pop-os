#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Private cliphist bridge for the Caelestia clipboard popup."""
import argparse
import json
import re
import subprocess
import tempfile
from urllib.parse import urlsplit


def history():
    result = subprocess.run(['cliphist', 'list'], capture_output=True, timeout=8, check=True)
    rows = []
    for line in result.stdout.decode('utf-8', errors='replace').splitlines():
        ident, separator, content = line.partition('\t')
        if separator and re.fullmatch(r'[0-9]+', ident):
            rows.append((ident, content, line))
    return rows


def describe(ident, content):
    clean = ''.join(c if c.isprintable() else ' ' for c in content).strip()
    binary = clean.lower().startswith('[[ binary data')
    image = binary and re.search(r'\b(png|jpe?g|webp|gif|bmp|tiff?)\b', clean, re.I)
    kind = 'image' if image else 'file' if binary else 'text'
    title = clean
    detail = 'Text'
    if image:
        dimensions = re.search(r'\b([0-9]+)x([0-9]+)\b', clean)
        title = 'Image' + (' · ' + dimensions[0].replace('x', ' × ') if dimensions else '')
        detail = image[1].upper() + ' image'
    elif binary:
        title, detail = 'Copied file', 'Binary content'
    elif re.fullmatch(r'https?://\S+', clean, re.I):
        try:
            host = urlsplit(clean).hostname
            if host:
                kind, detail = 'link', host
        except ValueError:
            pass
    return {'id': ident, 'kind': kind, 'title': title[:220], 'preview': clean[:600], 'detail': detail[:120]}


def copy_entry(ident):
    if not re.fullmatch(r'[0-9]+', ident):
        raise ValueError('Invalid entry')
    row = next((row for row in history() if row[0] == ident), None)
    if row is None:
        raise ValueError('Entry no longer exists')
    # Decode completely before replacing the clipboard, so failed decoding leaves it intact.
    # Anonymous storage avoids both image-sized Python buffers and named private cache files.
    with tempfile.TemporaryFile() as decoded:
        subprocess.run(['cliphist', 'decode'], input=row[2].encode(), stdout=decoded,
                       stderr=subprocess.DEVNULL, timeout=12, check=True)
        if not decoded.tell():
            raise ValueError('Empty entry')
        decoded.seek(0)
        subprocess.run(['wl-copy'], stdin=decoded, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=8, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--list', action='store_true')
    action.add_argument('--copy', metavar='ID')
    args = parser.parse_args()
    try:
        if args.list:
            result = {'ok': True, 'items': [describe(ident, content) for ident, content, _ in history()]}
        else:
            copy_entry(args.copy)
            result = {'ok': True}
    except (OSError, ValueError, subprocess.SubprocessError):
        # Never emit raw process errors, decoded content, paths or clipboard payloads on failure.
        result = {'ok': False, 'items': [], 'error': 'Clipboard history is unavailable' if args.list else 'Could not copy this item'}
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
