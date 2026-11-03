#!/usr/bin/env python3
"""Pop!_OS Caelestia installer. Read-only discovery is separate from mutation.

The command-line entry point never installs into a test prefix. Tests call the
transaction functions with explicit temporary Paths instead of touching the host.
"""
import argparse
import contextlib
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
GIB = 1024 ** 3
COMMANDS = ('preflight', 'plan', 'install', 'packages', 'runtime', 'plugins', 'deploy', 'doctor', 'rollback', 'clean-cache')
SYSTEM_DESTINATIONS = {
    'session-desktop': Path('/usr/share/wayland-sessions/hyprland-caelestia.desktop'),
    'session-wrapper': Path('/usr/local/bin/caelestia-pop-os-session'),
    'pam': Path('/etc/pam.d/quickshell'),
}
BASE_PACKAGES = '''software-properties-common build-essential gcc-14 g++-14 cmake ninja-build git curl wget pkg-config patchelf unzip
libgl1-mesa-dev libdrm-dev libgbm-dev libwayland-dev wayland-protocols libxkbcommon-dev libunwind-dev
libpipewire-0.3-dev libspa-0.2-dev libaubio-dev libqalculate-dev libsensors-dev libasound2-dev libpulse-dev
libfftw3-dev libinih-dev libiniparser-dev autoconf automake libtool meson libffi-dev libexpat1-dev
libxml2-dev libcli11-dev libvulkan-dev libxcb1-dev libglib2.0-dev libpolkit-agent-1-dev
libpolkit-gobject-1-dev libjemalloc-dev libpam0g-dev libgtk-3-dev libgtk-4-dev libadwaita-1-dev
libgirepository-2.0-dev gobject-introspection python3-venv python3-dev pipx lua5.4 liblua5.4-dev
hyprland-plugin-deps hypridle hyprlock hyprpaper xdg-desktop-portal-hyprland xdg-desktop-portal-gtk network-manager dbus
foot fish fuzzel cliphist wl-clipboard grim slurp ffmpeg wf-recorder btop brightnessctl brightness-udev
ddcutil libxml2-utils pavucontrol playerctl policykit-1-gnome lm-sensors qalc
libjson-c-dev libjpeg-dev libpng-dev libgtk-layer-shell-dev scdoc flex bison libegl1-mesa-dev
ripgrep xwayland xdg-utils libnotify-bin pipewire-pulse wireplumber pciutils psmisc procps util-linux dbus-user-session xdg-user-dirs fonts-noto-color-emoji
libxcb-cursor0 libxcb-icccm4 libxcb-keysyms1 libxcb-shape0 libxcb-xinerama0 libxcb-randr0 libxcb-render-util0 libx11-xcb-dev'''.split()
VIETNAMESE_PACKAGES = ['fcitx5', 'fcitx5-unikey', 'fcitx5-config-qt', 'fcitx5-frontend-gtk3', 'fcitx5-frontend-gtk4', 'fcitx5-frontend-qt5', 'fcitx5-frontend-qt6']


class InstallError(RuntimeError):
    pass


class Paths:
    def __init__(self, home=None, system_root=None):
        custom = home is not None
        self.home = Path(home) if custom else Path.home()
        self.config = self.home / '.config' if custom else Path(os.environ.get('XDG_CONFIG_HOME', self.home / '.config'))
        self.data_root = self.home / '.local/share' if custom else Path(os.environ.get('XDG_DATA_HOME', self.home / '.local/share'))
        self.state_root = self.home / '.local/state' if custom else Path(os.environ.get('XDG_STATE_HOME', self.home / '.local/state'))
        self.cache_root = self.home / '.cache' if custom else Path(os.environ.get('XDG_CACHE_HOME', self.home / '.cache'))
        self.data = self.data_root / 'caelestia-pop-os'
        self.state = self.state_root / 'caelestia-pop-os'
        self.backups = self.state / 'backups'
        self.system_root = Path(system_root) if system_root is not None else None
        for path in (self.home, self.config, self.data, self.state, self.cache_root):
            if not path.is_absolute() or '\n' in str(path) or '\r' in str(path):
                raise InstallError('HOME and XDG paths must be absolute and contain no newlines.')

    def system(self, key):
        path = SYSTEM_DESTINATIONS[key]
        return self.system_root / path.relative_to('/') if self.system_root else path


def pins():
    try:
        value = json.loads((ROOT / 'pins.json').read_text())
        for key in ('hyprland', 'qt', 'wayland', 'python', 'sources', 'shell'):
            if key not in value:
                raise ValueError('missing ' + key)
        for source in [value['hyprland'], value['wayland'], *value['sources'].values()]:
            if not re.fullmatch(r'[0-9a-f]{40}', source['commit']):
                raise ValueError('source revision must be a full commit')
        return value
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise InstallError(f'Invalid or missing pins.json: {exc}') from exc


def run(argv, *, capture=False, check=True, env=None):
    try:
        result = subprocess.run([str(x) for x in argv], text=True, stdout=subprocess.PIPE if capture else None,
                                stderr=subprocess.PIPE if capture else None, env=env, check=False)
    except OSError as exc:
        raise InstallError(f'Cannot execute {argv[0]}: {exc}') from exc
    if check and result.returncode:
        # Keep diagnostics useful, but do not dump entire logs into public output.
        detail = ((result.stderr or '') + (result.stdout or ''))[-4000:] if capture else 'see command output'
        raise InstallError(f'{argv[0]} exited {result.returncode}: {detail.strip()}')
    return result


def discover(argv):
    try:
        result = run(argv, capture=True, check=False)
        return result.stdout.strip() if result.returncode == 0 else None
    except InstallError:
        return None


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=COMMANDS)
    parser.add_argument('--yes', action='store_true', help='consent to the selected mutating operation')
    parser.add_argument('--dry-run', action='store_true', help='print the plan without creating files or changing the host')
    parser.add_argument('--json', action='store_true', help='machine-readable discovery/plan output')
    parser.add_argument('--scale', type=float, default=1.0)
    parser.add_argument('--vietnamese', action='store_true')
    parser.add_argument('--with-hyprmod', action='store_true')
    parser.add_argument('--with-codex', action='store_true')
    parser.add_argument('--encoder', choices=('auto', 'libx264', 'h264_nvenc'), default='auto')
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--reserve-gib', type=int, default=8)
    parser.add_argument('--cache-dir', type=Path)
    parser.add_argument('--backup', default='latest')
    args = parser.parse_args(argv)
    if not math.isfinite(args.scale) or not 0.5 <= args.scale <= 4:
        parser.error('--scale must be finite and between 0.5 and 4')
    if args.jobs < 1 or args.reserve_gib < 0:
        parser.error('--jobs must be positive and --reserve-gib must be nonnegative')
    if args.cache_dir is not None and (not args.cache_dir.is_absolute() or args.cache_dir == Path('/') or '\n' in str(args.cache_dir)):
        parser.error('--cache-dir must be an absolute, non-root directory')
    return args


def os_release():
    return {key: value.strip('"\'') for line in Path('/etc/os-release').read_text().splitlines()
            if '=' in line and not line.startswith('#') for key, value in [line.split('=', 1)]}


def validate_platform(release, architecture):
    if release.get('ID') != 'pop' or release.get('VERSION_ID') != '24.04' or architecture not in ('x86_64', 'amd64'):
        raise InstallError('Supported target: Pop!_OS 24.04 amd64 only.')


def existing_parent(path):
    while not path.exists():
        if path.is_symlink():
            raise InstallError(f'Refusing dangling symlink: {path}')
        path = path.parent
    return path


def disk_requirements(root_device, cache_device, reserve):
    required = {root_device: (4 + reserve) * GIB}
    required[cache_device] = required.get(cache_device, 0) + 8 * GIB
    return required


def check_apt_simulation(output):
    removals = re.findall(r'^Remv\s+(\S+)', output, re.MULTILINE)
    if removals:
        raise InstallError('Apt proposes package removals; refusing transaction: ' + ', '.join(removals))
    # Also fail closed if apt summarizes removals without the expected detailed lines.
    for number in re.findall(r'(\d+) to remove', output):
        if int(number):
            raise InstallError('Apt proposes removals; refusing transaction.')


def packages(args):
    return [*BASE_PACKAGES, 'hyprland=' + pins()['hyprland']['deb_version'], *(VIETNAMESE_PACKAGES if args.vietnamese else [])]


def gpu_info():
    pci = discover(['lspci', '-nnk']) or 'lspci unavailable'
    nvidia_active = discover(['nvidia-smi', '--query-gpu=driver_version', '--format=csv,noheader'])
    modeset = Path('/sys/module/nvidia_drm/parameters/modeset')
    try:
        value = modeset.read_text().strip() if modeset.exists() else None
    except PermissionError:
        value = discover(['sudo', '-n', 'cat', str(modeset)])
    return {'pci': pci, 'nvidia_driver': nvidia_active, 'nvidia_modeset': value,
            'notice': 'If NVIDIA modesetting is unreadable, run sudo -v in your terminal and repeat preflight.'}


def preflight(args, paths):
    checks = []
    def record(name, ok, detail):
        checks.append({'name': name, 'ok': bool(ok), 'detail': detail})
    release = os_release()
    try:
        validate_platform(release, platform.machine())
        record('platform', True, 'Pop!_OS 24.04 amd64')
    except InstallError as exc:
        record('platform', False, str(exc))
    try:
        pin_data = pins()
        record('pins', True, 'Exact source revisions present; runtime validates downloaded artifacts and ABI.')
    except InstallError as exc:
        record('pins', False, str(exc))
        pin_data = None
    cache = args.cache_dir or paths.cache_root / 'caelestia-pop-os'
    try:
        locations = [Path('/'), paths.data, Path('/opt'), Path('/usr/local'), cache]
        observations = {}
        for location in locations:
            parent = existing_parent(location)
            dev = parent.stat().st_dev
            stat = os.statvfs(parent)
            observations[str(location)] = {'device': dev, 'available_gib': round(stat.f_bavail * stat.f_frsize / GIB, 2)}
        root_dev, cache_dev = observations['/']['device'], observations[str(cache)]['device']
        needs = disk_requirements(root_dev, cache_dev, args.reserve_gib)
        # Additional runtime mount points need their own conservative runtime budget.
        for location in (paths.data, Path('/opt'), Path('/usr/local')):
            dev = observations[str(location)]['device']
            if dev != root_dev:
                needs[dev] = max(needs.get(dev, 0), (4 + args.reserve_gib) * GIB)
        available = {}
        for item in observations.values():
            available[item['device']] = item['available_gib'] * GIB
        record('disk', all(available[dev] >= amount for dev, amount in needs.items()),
               {'locations': observations, 'required_gib_by_device': {str(dev): amount / GIB for dev, amount in needs.items()}})
    except OSError as exc:
        record('disk', False, str(exc))
    memory = next((int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemTotal:')), 0)
    record('memory', memory >= 4 * GIB, f'{memory / GIB:.1f} GiB total; at least 4 GiB required, two build jobs recommended')
    gpu = gpu_info()
    record('gpu', not gpu['nvidia_driver'] or gpu['nvidia_modeset'] in ('Y', '1'), gpu)
    candidate = discover(['apt-cache', 'policy', 'hyprland'])
    record('package-source', True, {'policy': candidate, 'notice': 'The package stage adds ppa:cppiber/hyprland, then requires and simulates the exact pinned package before installation.'})
    # Simulate what is currently available, without adding sources or refreshing apt.
    if pin_data and candidate and pin_data['hyprland']['deb_version'] in candidate:
        sim = run(['apt-get', '-s', '--no-install-recommends', 'install', *packages(args)], capture=True, check=False, env={**os.environ, 'LC_ALL': 'C'})
        try:
            if sim.returncode:
                raise InstallError((sim.stderr or sim.stdout).strip())
            check_apt_simulation(sim.stdout)
            record('apt-simulation', True, 'Current exact package transaction has no removals.')
        except InstallError as exc:
            record('apt-simulation', False, str(exc))
    else:
        sim = run(['apt-get', '-s', '--no-install-recommends', 'install', 'software-properties-common'], capture=True, check=False, env={**os.environ, 'LC_ALL': 'C'})
        try:
            if sim.returncode:
                raise InstallError((sim.stderr or sim.stdout).strip())
            check_apt_simulation(sim.stdout)
            record('apt-bootstrap-simulation', True, 'Source bootstrap has no removals; full transaction awaits pinned PPA metadata.')
        except InstallError as exc:
            record('apt-bootstrap-simulation', False, str(exc))
    return {'ok': all(item['ok'] for item in checks), 'checks': checks, 'cache': str(cache), 'fresh_machine_gpu_login_tested': False}


def assert_safe_path(path):
    path = Path(path)
    if not path.is_absolute() or '..' in path.parts:
        raise InstallError(f'Unsafe destination: {path}')
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise InstallError(f'Refusing symlink destination or ancestor: {parent}')
    if path.exists() and path.is_dir():
        for child in path.rglob('*'):
            if child.is_symlink():
                raise InstallError(f'Refusing symlink inside managed tree: {child}')
            if not child.is_file() and not child.is_dir():
                raise InstallError(f'Unsupported special file: {child}')


def digest(path):
    assert_safe_path(path)
    if not path.exists():
        return None
    hasher = hashlib.sha256()
    members = [path] if path.is_file() else [path, *sorted(path.rglob('*'))]
    for member in members:
        hasher.update(str(member.relative_to(path) if member != path else '.').encode())
        hasher.update(b'd' if member.is_dir() else b'f')
        hasher.update(str(member.stat().st_mode & 0o777).encode())
        if member.is_file():
            with member.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    hasher.update(chunk)
    return hasher.hexdigest()


def copy_object(source, destination):
    assert_safe_path(source)
    if source.is_dir():
        shutil.copytree(source, destination)
    else:
        shutil.copy2(source, destination)


def remove_managed(path):
    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink(missing_ok=True)


def atomic_json(path, value):
    assert_safe_path(path)
    temporary = path.with_name(path.name + '.tmp-' + uuid.uuid4().hex)
    with temporary.open('x') as stream:
        json.dump(value, stream, indent=2)
        stream.write('\n')
    temporary.chmod(0o600)
    os.replace(temporary, path)


def system_key(path, paths):
    return next((key for key in SYSTEM_DESTINATIONS if paths.system(key) == path), None)


def replace_object(source, destination, paths):
    """Stage beside the destination; preserve the old object until replace succeeds."""
    assert_safe_path(destination)
    if system_key(destination, paths) and paths.system_root is None:
        if source is None:
            run(['sudo', 'rm', '--', destination])
            return
        if not source.is_file():
            raise InstallError('Only fixed regular files can be installed at system destinations.')
        # install to a sibling then rename: no half-written session/PAM file.
        temporary = destination.with_name(destination.name + '.caelestia-' + uuid.uuid4().hex)
        run(['sudo', 'install', '-D', '-m', '755' if system_key(destination, paths) == 'session-wrapper' else '644', source, temporary])
        try:
            run(['sudo', 'mv', '-T', '--', temporary, destination])
        finally:
            run(['sudo', 'rm', '-f', '--', temporary], check=False)
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source is None:
        remove_managed(destination)
        return
    temporary = destination.with_name(destination.name + '.caelestia-new-' + uuid.uuid4().hex)
    old = destination.with_name(destination.name + '.caelestia-old-' + uuid.uuid4().hex)
    copy_object(source, temporary)
    moved = False
    try:
        if destination.exists():
            os.replace(destination, old)
            moved = True
        os.replace(temporary, destination)
    except BaseException:
        if moved and old.exists():
            os.replace(old, destination)
        raise
    finally:
        if temporary.exists():
            remove_managed(temporary)
    # The versioned backup was verified before this old staging copy is removed.
    if old.exists():
        remove_managed(old)


def deploy_transaction(entries, paths):
    """Backup every target before writing any target; journal each applied digest."""
    assert_safe_path(paths.backups)
    for target, source in entries.values():
        assert_safe_path(target)
        assert_safe_path(source)
    paths.backups.mkdir(parents=True, exist_ok=True)
    paths.state.chmod(0o700)
    backup = paths.backups / (datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:10])
    backup.mkdir(mode=0o700)
    (backup / 'files').mkdir(mode=0o700)
    manifest = {'schema_version': 1, 'status': 'prepared', 'entries': []}
    for index, (key, (target, source)) in enumerate(entries.items()):
        before = digest(target)
        original = backup / 'files' / str(index)
        if before is not None:
            copy_object(target, original)
            if digest(original) != before:
                raise InstallError(f'Backup verification failed for {key}; no deployment performed.')
        manifest['entries'].append({'key': key, 'before': before, 'after': digest(source), 'applied': False})
    atomic_json(backup / 'manifest.json', manifest)
    try:
        for item in manifest['entries']:
            target, source = entries[item['key']]
            # Detect concurrent user edits after the backup, before replacement.
            if digest(target) != item['before']:
                raise InstallError(f'Target changed during deployment: {item["key"]}')
            replace_object(source, target, paths)
            item['applied'] = True
            atomic_json(backup / 'manifest.json', manifest)
            if digest(target) != item['after']:
                raise InstallError(f'Deployment verification failed for {item["key"]}')
        manifest['status'] = 'deployed'
        atomic_json(backup / 'manifest.json', manifest)
    except BaseException:
        # Restore only completed writes whose contents still match our journal.
        rollback_transaction(backup, {key: item[0] for key, item in entries.items()}, paths)
        raise
    return backup


def load_manifest(backup, allowed, paths):
    assert_safe_path(paths.backups)
    assert_safe_path(backup)
    if backup.parent != paths.backups or not backup.is_dir():
        raise InstallError('Backup must be a direct child of the managed backup directory.')
    try:
        manifest = json.loads((backup / 'manifest.json').read_text())
        if manifest.get('schema_version') != 1 or not isinstance(manifest.get('entries'), list):
            raise ValueError('invalid manifest schema')
        seen = set()
        for index, item in enumerate(manifest['entries']):
            key = item['key']
            if key not in allowed or key in seen or type(item.get('applied')) is not bool:
                raise ValueError('unknown/duplicate target or invalid journal')
            seen.add(key)
            for field in ('before', 'after'):
                value = item[field]
                if value is not None and not re.fullmatch(r'[0-9a-f]{64}', value):
                    raise ValueError('invalid content digest')
            assert_safe_path(allowed[key])
            original = backup / 'files' / str(index)
            if item['before'] is not None and digest(original) != item['before']:
                raise ValueError('backup content does not match manifest')
            # A process can stop after replacement but before recording applied.
            # Recover that exact installed digest; reject unrelated edits below.
            if manifest.get('status') == 'prepared' and not item['applied']:
                current = digest(allowed[key])
                if current == item['after'] and current != item['before']:
                    item['applied'] = True
                elif current != item['before']:
                    raise ValueError('interrupted target has unrecognized contents')
        return manifest
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise InstallError(f'Invalid backup manifest: {exc}') from exc


def rollback_transaction(backup, allowed, paths, dry_run=False):
    manifest = load_manifest(backup, allowed, paths)
    if manifest.get('status') == 'rolled-back':
        raise InstallError('This backup has already been restored.')
    for item in manifest['entries']:
        if item['applied'] and digest(allowed[item['key']]) != item['after']:
            raise InstallError(f'Refusing to overwrite post-install edits: {item["key"]}')
    if dry_run:
        return {'backup': backup.name, 'restore': [item['key'] for item in manifest['entries'] if item['applied']]}
    for index in reversed(range(len(manifest['entries']))):
        item = manifest['entries'][index]
        if item['applied']:
            source = backup / 'files' / str(index) if item['before'] is not None else None
            replace_object(source, allowed[item['key']], paths)
            item['applied'] = False
            atomic_json(backup / 'manifest.json', manifest)
    manifest['status'] = 'rolled-back'
    atomic_json(backup / 'manifest.json', manifest)
    return {'backup': backup.name, 'status': 'rolled-back', 'packages_removed': False}


def targets(paths):
    result = {
        'hypr': paths.config / 'hypr',
        'shell': paths.config / 'quickshell/caelestia',
        'caelestia': paths.config / 'caelestia',
        'profile': paths.config / 'caelestia-pop-os',
        'portal': paths.config / 'xdg-desktop-portal/hyprland-portals.conf',
        'wallpaper': paths.data / 'wallpapers/wallpaper.png',
        'codex-backend': paths.data / 'codex-usage',
        'fcitx-profile': paths.config / 'fcitx5/profile',
        'fcitx-unikey': paths.config / 'fcitx5/conf/unikey.conf',
    }
    for name in ('start-caelestia-session', 'start-caelestia-services', 'start-fcitx-unikey', 'caelestia-open-browser', 'caelestia-open-files'):
        result['helper-' + name] = paths.home / '.local/bin' / name
    for name in ('caelestia-shell.service', 'caelestia-clipboard@.service', 'caelestia-codex-usage.service'):
        result['unit-' + name] = paths.config / 'systemd/user' / name
    result.update({key: paths.system(key) for key in SYSTEM_DESTINATIONS})
    return result


def resolved_encoder(requested):
    if requested != 'auto':
        return requested
    active = discover(['nvidia-smi', '--query-gpu=driver_version', '--format=csv,noheader'])
    encoders = discover(['ffmpeg', '-hide_banner', '-encoders']) or ''
    return 'h264_nvenc' if active and re.search(r'\bh264_nvenc\b', encoders) else 'libx264'


def profile_values(args, encoder):
    return {'scale': args.scale, 'vietnamese': args.vietnamese, 'hyprmod': args.with_hyprmod,
            'codex_usage': args.with_codex, 'encoder_requested': args.encoder, 'encoder': encoder,
            'jobs': args.jobs, 'reserve_gib': args.reserve_gib}


def render_templates(args, paths, staging):
    """Create deployment inputs only in caller-owned staging, never the live HOME."""
    allowed = targets(paths)
    entries = {}
    def add(key, source, executable=False):
        destination = staging / key
        copy_object(source, destination)
        if executable:
            destination.chmod(0o755)
        entries[key] = (allowed[key], destination)
        return destination
    def text(key, value, mode=0o644):
        destination = staging / key
        destination.write_text(value)
        destination.chmod(mode)
        entries[key] = (allowed[key], destination)
        return destination
    add('hypr', ROOT / 'configs/hypr')
    main = entries['hypr'][1] / 'hyprland.lua'
    main.write_text(main.read_text().replace('@SCALE@', str(args.scale)))
    add('shell', ROOT / 'shell')
    add('caelestia', ROOT / 'configs/caelestia')
    config_path = entries['caelestia'][1] / 'shell.json'
    config = json.loads(config_path.read_text())
    for timeout in config.get('general', {}).get('idle', {}).get('timeouts', []):
        timeout['enabled'] = False
    config.setdefault('lock', {})['enableFprint'] = False
    config.setdefault('paths', {})['wallpaperDir'] = str(paths.data / 'wallpapers')
    config_path.write_text(json.dumps(config, indent=2) + '\n')
    encoder = resolved_encoder(args.encoder)
    (entries['caelestia'][1] / 'cli.json').write_text(json.dumps({'record': {'backend': 'wf-recorder', 'encoder': encoder}}, indent=2) + '\n')
    profile = staging / 'profile'
    profile.mkdir()
    entries['profile'] = (allowed['profile'], profile)
    values = profile_values(args, encoder)
    (profile / 'profile.json').write_text(json.dumps(values, indent=2) + '\n')
    env = {'CAELESTIA_SCALE': str(args.scale), 'CAELESTIA_VIETNAMESE': str(int(args.vietnamese)),
           'CAELESTIA_CODEX_USAGE': str(int(args.with_codex)), 'CAELESTIA_HYPRMOD': str(int(args.with_hyprmod))}
    (profile / 'profile.env').write_text(''.join(f'export {key}={shlex.quote(value)}\n' for key, value in env.items()))
    add('portal', ROOT / 'configs/xdg-desktop-portal/hyprland-portals.conf')
    add('wallpaper', ROOT / 'assets/wallpaper.png')
    helpers = {'start-caelestia-session': 'start-caelestia-session', 'start-caelestia-services': 'start-caelestia-services',
               'start-fcitx-unikey': 'start-fcitx-unikey', 'caelestia-open-browser': 'open-browser', 'caelestia-open-files': 'open-files'}
    for target, source in helpers.items():
        if target == 'start-fcitx-unikey' and not args.vietnamese:
            continue
        add('helper-' + target, ROOT / 'scripts' / source, executable=True)
    codex_path = Path(shutil.which('codex') or '/usr/bin/codex').parent
    replacements = {'@HOME@': str(paths.home), '@DATA@': str(paths.data_root), '@CODEX_PATH@': str(codex_path)}
    for name in ('caelestia-shell.service', 'caelestia-clipboard@.service', 'caelestia-codex-usage.service'):
        if name == 'caelestia-codex-usage.service' and not args.with_codex:
            continue
        source = ROOT / 'configs/systemd/user' / name
        value = source.read_text()
        for marker, replacement in replacements.items():
            value = value.replace(marker, replacement.replace('%', '%%').replace('"', '\\"').replace('\\', '\\\\'))
        text('unit-' + name, value)
    if args.with_codex:
        add('codex-backend', ROOT / 'src/codex-usage')
    if args.vietnamese:
        add('fcitx-profile', ROOT / 'configs/fcitx5/profile')
        add('fcitx-unikey', ROOT / 'configs/fcitx5/conf/unikey.conf')
    add('session-desktop', ROOT / 'configs/sessions/caelestia.desktop')
    add('session-wrapper', ROOT / 'configs/sessions/caelestia-pop-os-session', executable=True)
    add('pam', ROOT / 'configs/pam/quickshell')
    return entries


def plan(args, paths):
    pin_data = pins()
    cache = args.cache_dir or paths.cache_root / 'caelestia-pop-os'
    return {'command': args.command, 'dry_run': args.dry_run,
            'platform': 'Pop!_OS 24.04 amd64', 'ppa': 'ppa:cppiber/hyprland', 'packages': packages(args),
            'hyprland': pin_data['hyprland'], 'qt_prefix': pin_data['qt']['prefix'], 'wayland_prefix': pin_data['wayland']['prefix'],
            'cache': str(cache), 'jobs': args.jobs, 'build_gib': 8, 'runtime_gib': 4, 'reserve_gib': args.reserve_gib,
            'options': profile_values(args, args.encoder), 'destinations': {key: str(value) for key, value in targets(paths).items()},
            'stages': ['packages', 'runtime', 'plugins', 'deploy'],
            'preserves': ['COSMIC', 'cosmic-greeter', 'System76 power and NVIDIA support', 'networking', 'PipeWire', 'keyring'],
            'no_session_restart': True, 'fresh_machine_gpu_login_tested': False}


def require_consent(args):
    if os.geteuid() == 0:
        raise InstallError('Run as your normal user; the installer invokes sudo only for fixed system operations.')
    if not args.yes:
        if not sys.stdin.isatty():
            raise InstallError('This operation requires --yes or an interactive terminal.')
        if input(f'Proceed with {args.command}? [y/N] ').strip().lower() not in ('y', 'yes'):
            raise InstallError('Operation cancelled.')


def apt_transaction(requested):
    env = {**os.environ, 'LC_ALL': 'C'}
    simulation = run(['apt-get', '-s', '--no-install-recommends', 'install', *requested], capture=True, env=env)
    check_apt_simulation(simulation.stdout)
    print(simulation.stdout)
    # apt itself re-solves; --no-remove fails closed if metadata/state changes.
    run(['sudo', 'apt-get', '--no-remove', '--no-install-recommends', 'install', '-y', *requested], env=env)


def package_stage(args):
    run(['sudo', '-v'])
    apt_transaction(['software-properties-common'])
    run(['sudo', 'add-apt-repository', '--no-update', '-y', 'ppa:cppiber/hyprland'])
    run(['sudo', 'apt-get', 'update'])
    expected = pins()['hyprland']['deb_version']
    policy = run(['apt-cache', 'policy', 'hyprland'], capture=True).stdout
    if expected not in policy:
        raise InstallError(f'Exact hyprland={expected} is unavailable after adding the declared PPA; refusing substitution.')
    apt_transaction(packages(args))


def runtime_env(args, paths):
    return {**os.environ, 'CAELESTIA_CACHE_DIR': str(args.cache_dir or paths.cache_root / 'caelestia-pop-os'),
            'CAELESTIA_JOBS': str(args.jobs)}


def runtime_stage(args, paths):
    run([ROOT / 'installer/runtime.sh', 'all'], env=runtime_env(args, paths))
    if args.with_hyprmod:
        run([ROOT / 'installer/runtime.sh', 'hyprmod'], env=runtime_env(args, paths))


def verify_deploy_requirements(paths):
    version = pins()['hyprland']['version']
    required = [Path('/usr/local/bin/qs'), Path('/usr/bin/start-hyprland'), paths.data / 'bin/caelestia',
                paths.data_root / f'hypr/plugins/native-minimize-{version}.so',
                paths.data_root / f'hypr/plugins/hyprbars-{version}.so']
    missing = [str(item) for item in required if not item.is_file()]
    if missing:
        raise InstallError('Build/install the runtime and exact ABI plugins before deploy. Missing: ' + ', '.join(missing))
    run(['python3', ROOT / 'scripts/runtime-metadata.py', 'validate'])
    run(['/usr/local/bin/qs', '--version'], capture=True)
    installed = discover(['dpkg-query', '-W', '-f=${Version}', 'hyprland'])
    if installed != pins()['hyprland']['deb_version']:
        raise InstallError('Installed Hyprland does not match pinned Debian ABI.')


def deploy_stage(args, paths):
    verify_deploy_requirements(paths)
    with tempfile.TemporaryDirectory(prefix='caelestia-deploy-') as temp:
        entries = render_templates(args, paths, Path(temp))
        backup = deploy_transaction(entries, paths)
    # The session callback starts these units explicitly. No enable symlinks or
    # running services are created while the user is still in COSMIC.
    run(['systemctl', '--user', 'daemon-reload'])
    print(f'Deployed. Backup: {backup.name}. Session activation is manual; save work and select Hyprland (Caelestia Pop!_OS) at cosmic-greeter.')
    return {'backup': backup.name, 'session_login_pending': True}


def doctor(args, paths):
    checks = []
    def check(name, ok, detail):
        checks.append({'name': name, 'ok': bool(ok), 'detail': detail})
    pin_data = pins()
    installed = discover(['dpkg-query', '-W', '-f=${Version}', 'hyprland'])
    check('hyprland-package', installed == pin_data['hyprland']['deb_version'], installed)
    header = Path(pin_data['hyprland']['header_file'])
    actual = hashlib.sha256(header.read_bytes()).hexdigest() if header.is_file() else None
    check('hyprland-headers', actual == pin_data['hyprland']['headers_sha256'], actual)
    for label, path in [('quickshell', Path('/usr/local/bin/qs')),
                        ('cli', paths.data / 'bin/caelestia'),
                        ('shell-source', paths.config / 'quickshell/caelestia/shell.qml'),
                        ('session-entry', paths.system('session-desktop')),
                        ('pam', paths.system('pam')),
                        ('hyprbars', paths.data_root / 'hypr/plugins/hyprbars-0.57.0.so'),
                        ('native-actions', paths.data_root / 'hypr/plugins/native-minimize-0.57.0.so')]:
        check(label, path.is_file(), str(path))
    qs = discover(['/usr/local/bin/qs', '--version'])
    check('quickshell-version', qs and '0.3.1' in qs, qs)
    profile = paths.config / 'caelestia-pop-os/profile.json'
    selected = json.loads(profile.read_text()) if profile.is_file() else {}
    if selected.get('codex_usage'):
        check('codex-cli', shutil.which('codex') is not None, 'Optional: install/sign in to Codex separately; no credentials are installed here.')
    in_session = bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')) and os.environ.get('XDG_CURRENT_DESKTOP') == 'Hyprland'
    pending = []
    if in_session:
        errors = discover(['hyprctl', 'configerrors'])
        check('hyprland-config', errors == '', errors)
        plugin_list = discover(['hyprctl', 'plugin', 'list']) or ''
        check('loaded-plugins', 'hyprbars' in plugin_list and 'native-minimize' in plugin_list, plugin_list)
        check('shell-service', discover(['systemctl', '--user', 'is-active', 'caelestia-shell.service']) == 'active', 'Active shell required in Hyprland.')
    else:
        pending.append('Hyprland login, loaded plugins, active shell and interactive GPU checks')
    return {'ok': all(c['ok'] for c in checks), 'checks': checks, 'pending': pending,
            'fresh_machine_gpu_login_tested': False}


def select_backup(args, paths):
    assert_safe_path(paths.backups)
    if args.backup == 'latest':
        candidates = sorted(p for p in paths.backups.glob('*') if p.is_dir() and not p.is_symlink())
        for candidate in reversed(candidates):
            try:
                if json.loads((candidate / 'manifest.json').read_text()).get('status') != 'rolled-back':
                    return candidate
            except (OSError, ValueError):
                continue
        raise InstallError('No unrestored backup found.')
    if Path(args.backup).name != args.backup or args.backup in ('.', '..'):
        raise InstallError('--backup must be a backup identifier, not a path.')
    return paths.backups / args.backup


def clean_cache(args, paths, dry_run=False):
    import fcntl
    cache = args.cache_dir or paths.cache_root / 'caelestia-pop-os'
    # Do not inspect/follow the build tree: build tools legitimately create
    # symlinks. rmtree removes those links without following their targets.
    for parent in (cache, *cache.parents):
        if parent.is_symlink():
            raise InstallError('Refusing a symlink cache or ancestor.')
    build = cache / 'builds'
    if build.is_symlink():
        raise InstallError('Refusing a symlink build directory.')
    if not cache.exists():
        return {'cache': str(cache), 'removed': [], 'dry_run': dry_run}
    if not (cache / 'runtime.lock').is_file() or not (cache / 'sources').is_dir() or not (cache / 'receipts').is_dir():
        raise InstallError('This is not a recognized installer cache; refusing cleanup.')
    result = {'cache': str(cache), 'removed': [str(build)] if build.exists() else [], 'dry_run': dry_run}
    if dry_run:
        return result
    with (cache / 'runtime.lock').open('r') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise InstallError('A runtime build is active; refusing cleanup.') from exc
        if build.exists():
            shutil.rmtree(build)
    return result


def execute(args, paths=None):
    paths = paths or Paths()
    if args.command == 'preflight':
        return preflight(args, paths)
    if args.command == 'plan':
        return plan(args, paths)
    if args.command == 'doctor':
        return doctor(args, paths)
    if args.command == 'rollback':
        backup = select_backup(args, paths)
        if not args.dry_run:
            require_consent(args)
        result = rollback_transaction(backup, targets(paths), paths, dry_run=args.dry_run)
        if not args.dry_run:
            run(['systemctl', '--user', 'daemon-reload'])
        return result
    if args.command == 'clean-cache':
        if not args.dry_run:
            require_consent(args)
        return clean_cache(args, paths, dry_run=args.dry_run)
    if args.dry_run:
        return plan(args, paths)
    require_consent(args)
    run(['sudo', '-v'])
    report = preflight(args, paths)
    if not report['ok']:
        raise InstallError('Preflight failed: ' + json.dumps([c for c in report['checks'] if not c['ok']]))
    if args.command in ('install', 'packages'):
        package_stage(args)
    if args.command in ('install', 'runtime'):
        # all includes native plugins, following their toolchain dependencies.
        runtime_stage(args, paths)
    if args.command == 'plugins':
        run([ROOT / 'scripts/build-plugins.sh'], env=runtime_env(args, paths))
    result = {'ok': True, 'command': args.command}
    if args.command in ('install', 'deploy'):
        result.update(deploy_stage(args, paths))
    return result


def main(argv=None):
    args = parse_args(argv)
    try:
        result = execute(args)
    except (InstallError, OSError, ValueError) as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}) if args.json else f'ERROR: {exc}', file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0 if result.get('ok', True) else 1


if __name__ == '__main__':
    raise SystemExit(main())
