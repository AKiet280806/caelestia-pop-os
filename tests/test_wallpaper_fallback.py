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

    def test_primary_layer_requires_visible_background_on_each_monitor(self):
        visible = {'levels': {'0': [{'namespace': 'caelestia-background', 'alpha': 1}]}}
        hidden = {'levels': {'0': [{'namespace': 'caelestia-background', 'alpha': 0}]}}
        with patch.object(wallpaper, 'query_hyprland', return_value={'eDP-1': visible}):
            self.assertTrue(wallpaper.primary_visible())
        with patch.object(wallpaper, 'query_hyprland', return_value={'eDP-1': visible, 'DP-1': hidden}):
            self.assertFalse(wallpaper.primary_visible())
        with patch.object(wallpaper, 'query_hyprland', return_value=None):
            self.assertIsNone(wallpaper.primary_visible())

    def test_inactive_fullscreen_does_not_prevent_recovery(self):
        monitor = [{'activeWorkspace': {'name': '1'}, 'specialWorkspace': {'name': ''}}]
        windows = [{'mapped': True, 'fullscreen': 2, 'workspace': {'name': '2'}}]
        with patch.object(wallpaper, 'query_hyprland', side_effect=[monitor, windows]):
            self.assertFalse(wallpaper.covering_fullscreen())
        windows[0]['workspace']['name'] = '1'
        with patch.object(wallpaper, 'query_hyprland', side_effect=[monitor, windows]):
            self.assertTrue(wallpaper.covering_fullscreen())

    def test_stopping_fallback_terminates_only_owned_process(self):
        from unittest.mock import Mock
        process = Mock()
        process.poll.return_value = None
        wallpaper.stop_renderer(process)
        process.terminate.assert_called_once()
        process.wait.assert_called_once_with(timeout=3)
        process.kill.assert_not_called()

    def test_renderer_enters_standby_and_recovers_after_primary_disappears(self):
        from unittest.mock import Mock
        import signal
        import os
        clock, handlers = [0.0], {}
        first, second = Mock(), Mock()
        first.poll.return_value = second.poll.return_value = None

        def tick(_):
            clock[0] += 1
            if clock[0] >= 6:
                handlers[signal.SIGTERM](signal.SIGTERM, None)

        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(os.environ, {'XDG_RUNTIME_DIR': directory}), \
             patch.object(wallpaper.signal, 'signal', side_effect=lambda signum, fn: handlers.update({signum: fn})), \
             patch.object(wallpaper.time, 'monotonic', side_effect=lambda: clock[0]), \
             patch.object(wallpaper.time, 'sleep', side_effect=tick), \
             patch.object(wallpaper, 'primary_visible', side_effect=[False, True, True, True, None, False]), \
             patch.object(wallpaper, 'covering_fullscreen', return_value=False), \
             patch.object(wallpaper, 'selected_image', return_value='/tmp/wallpaper.jpg'), \
             patch.object(wallpaper, 'set_wallpaper', return_value=True), \
             patch.object(wallpaper, 'notify_ready') as notify, \
             patch.object(wallpaper.subprocess, 'Popen', side_effect=[first, second]) as spawn:
            self.assertEqual(wallpaper.main(), 0)
            self.assertEqual(spawn.call_count, 2)
            first.terminate.assert_called_once()
            second.terminate.assert_called_once()
            notify.assert_called_once()

    def test_healthy_primary_never_starts_an_overlay_renderer(self):
        import signal
        import os
        handlers = {}
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(os.environ, {'XDG_RUNTIME_DIR': directory}), \
             patch.object(wallpaper.signal, 'signal', side_effect=lambda signum, fn: handlers.update({signum: fn})), \
             patch.object(wallpaper.time, 'sleep', side_effect=lambda _: handlers[signal.SIGTERM](signal.SIGTERM, None)), \
             patch.object(wallpaper, 'primary_visible', return_value=True), \
             patch.object(wallpaper, 'selected_image', return_value='/tmp/wallpaper.jpg'), \
             patch.object(wallpaper, 'set_wallpaper') as update, \
             patch.object(wallpaper, 'notify_ready') as notify, \
             patch.object(wallpaper.subprocess, 'Popen') as spawn:
            self.assertEqual(wallpaper.main(), 0)
            spawn.assert_not_called()
            update.assert_not_called()
            notify.assert_called_once()
