"""Clipboard bridge contracts; no real history or system clipboard is accessed."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('clipboard', Path(__file__).parents[1] / 'src/clipboard/clipboard.py')
clipboard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(clipboard)


class ClipboardTests(unittest.TestCase):
    def test_list_ignores_malformed_ids_and_preserves_tabs(self):
        result = subprocess.CompletedProcess([], 0, b'12\tfirst\tsecond\n--help\tunsafe\nother\n', b'')
        with patch.object(clipboard.subprocess, 'run', return_value=result):
            self.assertEqual(clipboard.history(), [('12', 'first\tsecond', '12\tfirst\tsecond')])

    def test_types_and_image_metadata_without_decoding(self):
        self.assertEqual(clipboard.describe('1', 'https://example.com/path')['kind'], 'link')
        self.assertEqual(clipboard.describe('2', '[[ binary data 14 KiB png 800x600 ]]')['title'], 'Image · 800 × 600')
        self.assertEqual(clipboard.describe('3', '[[ binary data 14 KiB application/pdf ]]')['kind'], 'file')
        self.assertEqual(clipboard.describe('4', '<b>plain text</b>')['title'], '<b>plain text</b>')
        self.assertEqual(clipboard.describe('5', 'https://[invalid')['kind'], 'text')

    def test_invalid_or_missing_id_never_decodes_or_copies(self):
        with patch.object(clipboard, 'history', return_value=[]), patch.object(clipboard.subprocess, 'run') as run:
            for ident in ['--help', '../db', '1; echo unsafe', '123']:
                with self.assertRaises(ValueError): clipboard.copy_entry(ident)
            run.assert_not_called()

    def test_binary_payload_is_copied_exactly_through_anonymous_storage(self):
        payload = b'\x89PNG\r\n\x1a\n\x00\xff\xfe'
        seen = []
        def run(argv, **kwargs):
            seen.append(argv)
            if argv == ['cliphist', 'decode']:
                self.assertEqual(kwargs['input'], b'8\t[[ binary data png ]]')
                kwargs['stdout'].write(payload)
            elif argv == ['wl-copy']:
                self.assertEqual(kwargs['stdin'].read(), payload)
            return subprocess.CompletedProcess(argv, 0)
        with patch.object(clipboard, 'history', return_value=[('8', '', '8\t[[ binary data png ]]')]), patch.object(clipboard.subprocess, 'run', side_effect=run):
            clipboard.copy_entry('8')
        self.assertEqual(seen, [['cliphist', 'decode'], ['wl-copy']])

    def test_failed_or_empty_decode_does_not_replace_clipboard(self):
        for failed in [True, False]:
            calls = []
            def run(argv, **kwargs):
                calls.append(argv)
                if failed: raise subprocess.CalledProcessError(1, argv)
                return subprocess.CompletedProcess(argv, 0)
            with patch.object(clipboard, 'history', return_value=[('8', '', '8\tentry')]), patch.object(clipboard.subprocess, 'run', side_effect=run):
                with self.assertRaises((ValueError, subprocess.CalledProcessError)): clipboard.copy_entry('8')
            self.assertEqual(calls, [['cliphist', 'decode']])


if __name__ == '__main__': unittest.main()
