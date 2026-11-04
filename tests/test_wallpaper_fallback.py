import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('wallpaper_fallback', ROOT / 'src/wallpaper-fallback/wallpaper_fallback.py')
wallpaper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wallpaper)


class WallpaperFallbackTests(unittest.TestCase):
    def test_selected_image_and_fallback_without_changing_state(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            state, image, fallback = root/'path.txt', root/'image with spaces.jpg', root/'fallback.png'
            image.write_bytes(b'fixture'); fallback.write_bytes(b'fixture')
            state.write_text(str(image))
            self.assertEqual(wallpaper.selected_image(state, fallback), str(image))
            self.assertEqual(state.read_text(), str(image))
            image.unlink()
            self.assertEqual(wallpaper.selected_image(state, fallback), str(fallback))

    def test_ipc_uses_one_argv_argument_for_spaces_and_never_shell(self):
        with patch.object(wallpaper.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertTrue(wallpaper.set_wallpaper('/tmp/my wallpaper.jpg'))
            self.assertEqual(run.call_args.args[0], ['hyprctl','hyprpaper','wallpaper',', /tmp/my wallpaper.jpg, cover'])
            self.assertNotIn('shell', run.call_args.kwargs)
            self.assertFalse(wallpaper.set_wallpaper('/tmp/ambiguous,name.jpg'))
            self.assertEqual(run.call_count, 1)

    def test_failed_or_timed_out_ipc_is_retried_by_caller(self):
        with patch.object(wallpaper.subprocess, 'run', side_effect=subprocess.TimeoutExpired('hyprctl', 3)):
            self.assertFalse(wallpaper.set_wallpaper('/tmp/image.jpg'))
