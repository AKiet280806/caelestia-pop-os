"""Installer safety tests. No host packages, services or dotfiles are changed."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('caelestia_installer', ROOT / 'installer/install.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class SafetyTests(unittest.TestCase):
    def test_removals_blocked(self):
        with self.assertRaises(mod.InstallError):
            mod.check_apt_simulation('Remv cosmic-session [1.0]\nInst example [1]\n')
        mod.check_apt_simulation('Inst example [1]\nConf example [1]\n')

    def test_options(self):
        args = mod.parse_args(['install', '--yes', '--scale', '1.25', '--vietnamese', '--encoder', 'libx264'])
        self.assertEqual(args.scale, 1.25)
        self.assertTrue(args.vietnamese)
        with self.assertRaises(SystemExit):
            mod.parse_args(['deploy', '--scale', 'nan'])

    def test_usage_option_compatibility_alias(self):
        new = mod.parse_args(['install', '--with-ai-usage'])
        old = mod.parse_args(['install', '--with-codex'])
        self.assertEqual(vars(new), vars(old))

    def test_disk_shared_and_separate(self):
        self.assertEqual(mod.disk_requirements(1, 1, 8), {1: 20 * mod.GIB})
        self.assertEqual(mod.disk_requirements(1, 2, 8), {1: 12 * mod.GIB, 2: 8 * mod.GIB})

    def test_dry_run_creates_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp) / 'home'
            paths = mod.Paths(home=home)
            args = mod.parse_args(['deploy', '--dry-run'])
            mod.execute(args, paths=paths)
            self.assertFalse(home.exists())

    def test_full_dry_run_never_executes_a_command(self):
        with tempfile.TemporaryDirectory() as temp:
            paths = mod.Paths(home=Path(temp) / 'home')
            with patch.object(mod, 'run', side_effect=AssertionError('dry run spawned a command')):
                result = mod.execute(mod.parse_args(['install', '--dry-run', '--vietnamese', '--with-codex']), paths)
            self.assertTrue(result['dry_run'])
            self.assertFalse(paths.home.exists())

    def test_complete_optional_template_deploy_and_rollback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            paths = mod.Paths(home=root / 'home', system_root=root / 'system')
            staging = root / 'staging'
            staging.mkdir()
            args = mod.parse_args(['deploy', '--scale', '1.5', '--encoder', 'libx264', '--vietnamese', '--with-codex'])
            entries = mod.render_templates(args, paths, staging)
            backup = mod.deploy_transaction(entries, paths)
            config = json.loads((paths.config / 'caelestia/shell.json').read_text())
            self.assertEqual(config['general']['idle']['timeouts'], [])
            self.assertFalse(config['lock']['enableFprint'])
            self.assertIn('scale = 1.5', (paths.config / 'hypr/hyprland.lua').read_text())
            self.assertIn('CAELESTIA_CODEX_USAGE=1', (paths.config / 'caelestia-pop-os/profile.env').read_text())
            self.assertIn('Pop!_OS', paths.system('session-desktop').read_text())
            self.assertTrue((paths.data / 'wallpaper-fallback/wallpaper_fallback.py').is_file())
            self.assertTrue((paths.data / 'clipboard/shell.qml').is_file())
            self.assertTrue((paths.home / '.local/bin/caelestia-clipboard').is_file())
            self.assertIn('caelestia-clipboard', (paths.config / 'hypr/hyprland.lua').read_text())
            self.assertTrue((paths.config / 'systemd/user/caelestia-wallpaper.service').is_file())
            self.assertIn('Wants=caelestia-wallpaper.service', (paths.config / 'systemd/user/caelestia-shell.service').read_text())
            self.assertTrue((paths.data / 'ai-usage/ai_usage.py').is_file())
            unit = (paths.config / 'systemd/user/caelestia-codex-usage.service').read_text()
            self.assertIn('ai-usage/ai_usage.py', unit)
            mod.rollback_transaction(backup, mod.targets(paths), paths)
            self.assertFalse(paths.config.joinpath('hypr').exists())
            self.assertFalse(paths.system('pam').exists())

    def test_cache_cleanup_preserves_sources_and_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            paths = mod.Paths(home=Path(temp))
            args = mod.parse_args(['clean-cache'])
            cache = paths.cache_root / 'caelestia-pop-os'
            for name in ['sources', 'receipts', 'builds']:
                (cache / name).mkdir(parents=True)
            (cache / 'runtime.lock').touch()
            (cache / 'sources/keep').write_text('source')
            (cache / 'builds/object').write_text('object')
            mod.clean_cache(args, paths, dry_run=True)
            self.assertTrue((cache / 'builds/object').exists())
            mod.clean_cache(args, paths)
            self.assertTrue((cache / 'sources/keep').exists())
            self.assertFalse((cache / 'builds').exists())
            (cache / 'builds').symlink_to(cache / 'sources', target_is_directory=True)
            with self.assertRaises(mod.InstallError):
                mod.clean_cache(args, paths)

    def test_unsupported_platform(self):
        with self.assertRaises(mod.InstallError):
            mod.validate_platform({'ID': 'ubuntu', 'VERSION_ID': '24.04'}, 'x86_64')
        mod.validate_platform({'ID': 'pop', 'VERSION_ID': '24.04'}, 'x86_64')


class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.paths = mod.Paths(home=self.root / 'home', system_root=self.root / 'system')
        self.dest = self.paths.config / 'hypr'
        self.source = self.root / 'source'
        self.source.mkdir()
        (self.source / 'new.lua').write_text('new')
        self.entries = {'hypr': (self.dest, self.source)}

    def tearDown(self):
        self.tmp.cleanup()

    def test_backup_restore_and_user_edit_guard(self):
        self.dest.mkdir(parents=True)
        (self.dest / 'old.lua').write_text('original')
        backup = mod.deploy_transaction(self.entries, self.paths)
        self.assertEqual((self.dest / 'new.lua').read_text(), 'new')
        (self.dest / 'new.lua').write_text('user edit')
        with self.assertRaises(mod.InstallError):
            mod.rollback_transaction(backup, {'hypr': self.dest}, self.paths)
        self.assertEqual((self.dest / 'new.lua').read_text(), 'user edit')
        (self.dest / 'new.lua').write_text('new')
        mod.rollback_transaction(backup, {'hypr': self.dest}, self.paths)
        self.assertEqual((self.dest / 'old.lua').read_text(), 'original')

    def test_symlink_parent_refused(self):
        self.paths.home.mkdir(parents=True)
        external = self.root / 'external'
        external.mkdir()
        self.paths.config.symlink_to(external, target_is_directory=True)
        with self.assertRaises(mod.InstallError):
            mod.deploy_transaction(self.entries, self.paths)
        self.assertEqual(list(external.iterdir()), [])

    def test_hostile_manifest_refused(self):
        backup = mod.deploy_transaction(self.entries, self.paths)
        manifest = json.loads((backup / 'manifest.json').read_text())
        manifest['entries'][0]['key'] = 'unknown-hostile-destination'
        (backup / 'manifest.json').write_text(json.dumps(manifest))
        with self.assertRaises(mod.InstallError):
            mod.rollback_transaction(backup, {'hypr': self.dest}, self.paths)
        self.assertTrue((self.dest / 'new.lua').exists())

    def test_interrupted_journal_recovers_replaced_target(self):
        backup = mod.deploy_transaction(self.entries, self.paths)
        manifest = json.loads((backup / 'manifest.json').read_text())
        manifest['status'] = 'prepared'
        manifest['entries'][0]['applied'] = False
        (backup / 'manifest.json').write_text(json.dumps(manifest))
        mod.rollback_transaction(backup, {'hypr': self.dest}, self.paths)
        self.assertFalse(self.dest.exists())

    def test_symlink_in_target_refused(self):
        self.dest.mkdir(parents=True)
        (self.dest / 'link').symlink_to('/etc/passwd')
        with self.assertRaises(mod.InstallError):
            mod.deploy_transaction(self.entries, self.paths)


if __name__ == '__main__':
    unittest.main()
