#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Private cliphist bridge for the Caelestia clipboard popup."""
import argparse
import json
import hashlib
import io
import os
from pathlib import Path
import shutil
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
    binary = bool(re.match(r'^(?:\[\[\s*)?binary data\b', clean, re.I))
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


def preview_directory(session):
    if not re.fullmatch(r'[0-9]{10,17}-[0-9]{1,10}', session or ''):
        raise ValueError('Invalid preview session')
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    base = runtime / 'caelestia-clipboard'
    folder = base / session
    for path in (base, folder):
        if path.is_symlink():
            raise ValueError('Unsafe preview directory')
        path.mkdir(mode=0o700, exist_ok=True)
        if path.stat().st_uid != os.getuid():
            raise ValueError('Unsafe preview owner')
        path.chmod(0o700)
    return folder


def thumbnail(ident, session):
    from PIL import Image, ImageOps
    if not re.fullmatch(r'[0-9]+', ident):
        raise ValueError('Invalid entry')
    row = next((row for row in history() if row[0] == ident), None)
    if row is None or describe(row[0], row[1])['kind'] != 'image':
        raise ValueError('Image no longer exists')
    with tempfile.TemporaryFile() as decoded:
        subprocess.run(['cliphist', 'decode'], input=row[2].encode(), stdout=decoded,
                       stderr=subprocess.DEVNULL, timeout=12, check=True)
        decoded.seek(0)
        try:
            with Image.open(decoded) as image:
                if image.width * image.height > 50_000_000:
                    raise ValueError('Image too large to preview')
                image = ImageOps.exif_transpose(image)
                image.thumbnail((960, 720))
                image = image.convert('RGBA')
                output = io.BytesIO()
                image.save(output, format='PNG')
                payload = output.getvalue()
        except Image.DecompressionBombError as error:
            raise ValueError('Image too large to preview') from error
    folder = preview_directory(session)
    path = folder / (ident + '-' + hashlib.sha256(payload).hexdigest()[:16] + '.png')
    with tempfile.NamedTemporaryFile(dir=folder, delete=False) as temporary:
        temporary.write(payload)
        temporary_path = Path(temporary.name)
    try:
        temporary_path.replace(path)
    finally:
        temporary_path.unlink(missing_ok=True)
    return path.as_uri()


def cleanup(session):
    # Only this popup's validated, user-owned session directory may be removed.
    folder = preview_directory(session)
    shutil.rmtree(folder)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--list', action='store_true')
    action.add_argument('--copy', metavar='ID')
    action.add_argument('--thumbnail', metavar='ID')
    action.add_argument('--cleanup', action='store_true')
    parser.add_argument('--session')
    args = parser.parse_args()
    try:
        if args.list:
            result = {'ok': True, 'items': [describe(ident, content) for ident, content, _ in history()]}
        elif args.thumbnail:
            result = {'ok': True, 'id': args.thumbnail, 'url': thumbnail(args.thumbnail, args.session)}
        elif args.cleanup:
            cleanup(args.session)
            result = {'ok': True}
        else:
            copy_entry(args.copy)
            result = {'ok': True}
    except (OSError, ValueError, KeyError, ImportError, subprocess.SubprocessError):
        # Never emit raw process errors, decoded content, paths or clipboard payloads on failure.
        result = {'ok': False, 'items': [], 'error': 'Clipboard history is unavailable' if args.list else 'Preview unavailable' if args.thumbnail else 'Could not copy this item'}
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
