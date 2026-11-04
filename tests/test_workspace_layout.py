"""Run the actual window-actions Lua against isolated compositor event fixtures."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class WorkspaceLayoutTests(unittest.TestCase):
    def test_workspace_policy_and_window_state(self):
        lua = shutil.which('lua5.4') or shutil.which('lua')
        self.assertIsNotNone(lua, 'lua5.4 is required')
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                [lua, str(ROOT / 'tests/workspace-layout.lua'),
                 str(ROOT / 'configs/hypr/caelestia-windows.lua')],
                env={**os.environ, 'HOME': directory, 'XDG_STATE_HOME': directory + '/state',
                     'XDG_RUNTIME_DIR': directory + '/runtime'},
                text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
