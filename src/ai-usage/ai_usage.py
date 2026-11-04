#!/usr/bin/env python3
"""Selected-provider quota daemon. Never performs an inference request.

Codex uses the sibling read-only app-server client. Other providers use the
official CodexBar 0.83.0 CLI with an explicit source, never its auto fallback.
Only the numeric display contract below crosses the private CLI/cache boundary.
"""
import argparse
import asyncio
from contextlib import contextmanager
from datetime import datetime
import fcntl
import json
import math
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'codex-usage'))
from codex_usage import CodexClient, normalize_limits  # noqa: E402

CODEXBAR_VERSION = '0.83.0'
SERVICE = 'caelestia-codex-usage.service'
# Curated selection from the SHA-verified official v0.83.0 Linux CLI's
# `config providers --json`, with an empty temporary HOME. No auth material.
# Tuple fields: public display name, supported explicit source modes.
PROVIDERS = {
    'codex': ('Codex', ('api', 'auto', 'cli', 'oauth', 'web')),
    'openai': ('OpenAI API', ('api', 'auto')),
    'claude': ('Claude', ('api', 'auto', 'cli', 'oauth', 'web')),
    'antigravity': ('Antigravity', ('auto', 'cli', 'oauth')),
    'copilot': ('GitHub Copilot', ('api', 'auto')),
    'opencode': ('OpenCode', ('auto', 'web')),
    'zai': ('z.ai / GLM', ('api', 'auto')),
    'kimi': ('Kimi Code', ('api', 'auto', 'web')),
    'kilo': ('Kilo', ('api', 'auto', 'cli')),
    'deepseek': ('DeepSeek', ('api', 'auto', 'web')),
    'cursor': ('Cursor', ('auto', 'cli', 'web')),
    'gemini': ('Gemini', ('api', 'auto', 'web')),
    'grok': ('Grok', ('auto', 'cli', 'oauth', 'web')),
}
CATALOG = [{'id': key, 'name': value[0]} for key, value in PROVIDERS.items()]
MAX_OUTPUT = 2 * 1024 * 1024


def source_for(provider):
    # These API fetchers send an inference request to discover headers.
    if provider in ('doubao', 'azureopenai', 'azure-openai', 'codex'):
        return None
    preferred = {'claude': 'oauth', 'gemini': 'api', 'cursor': 'web', 'grok': 'cli'}
    modes = PROVIDERS.get(provider, ('', ()))[1]
    if provider in preferred:
        return preferred[provider] if preferred[provider] in modes else None
    # CLI-only sources are not assumed read-only. Web requires the user's own
    # CodexBar authentication; Linux's missing browser import stays unknown.
    return next((mode for mode in ('api', 'oauth', 'web') if mode in modes), None)


def number(value, minimum=0):
    try:
        return type(value) in (int, float) and math.isfinite(value) and value >= minimum
    except OverflowError:
        return False


def timestamp(value):
    if number(value, 1):
        return int(value)
    if isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
            if parsed.tzinfo is not None:
                result = int(parsed.timestamp())
                return result if result > 0 else None
        except (ValueError, OverflowError):
            pass
    return None


# Public provider quota labels only. Never persist arbitrary CLI text (which
# can contain account names, errors, diagnostics, cookies or API credentials).
WINDOW_LABELS = frozenset((
    'Session', 'Weekly', 'Monthly', 'Daily', 'Hourly', 'Yearly', 'Usage',
    'Credits', 'On-demand', 'Premium requests', 'Requests', 'Tokens', 'Sonnet',
    'Opus', 'Flash', 'Pro', 'Fast', 'Slow', 'Chat', 'Agent', 'API', 'Limit',
    'Standard', 'Premium', 'Extra usage', 'Included', 'Billing period',
    '5-hour', '7-day', '24-hour', 'Messages', 'All models', 'Auto', 'Balance'))


def window(value, label):
    if not isinstance(value, dict) or value.get('isSyntheticPlaceholder') is True:
        return None
    if not number(value.get('usedPercent')):
        return None
    duration = value.get('windowMinutes')
    return {'label': label, 'used_percent': min(value['usedPercent'], 100),
            'window_minutes': duration if type(duration) is int and duration > 0 else None,
            'resets_at': timestamp(value.get('resetsAt'))}


def state_for(provider, now, reason='loading'):
    return {'provider': provider, 'name': PROVIDERS.get(provider, (provider,))[0],
            'status': 'unknown', 'reason': reason, 'windows': [], 'details': [],
            'updated_at': None, 'last_attempt': now, 'refreshing': False,
            'providers': CATALOG}


def error_state(provider, now, reason, previous=None, *, scope=None, previous_scope=None):
    result = state_for(provider, now, reason)
    # Disk caches have no ownership proof. Errors cannot establish the current
    # account, so the daemon intentionally does not reuse disk data on failure.
    if (scope is not None and scope == previous_scope and previous
            and previous.get('provider') == provider and previous.get('updated_at')
            and reason not in ('sign_in_required', 'unsupported_source')):
        result.update(status='stale', windows=previous.get('windows', []),
                      details=previous.get('details', []), updated_at=previous['updated_at'])
    return result


def classify_error(error):
    # Classification only: exception text never reaches the cache or journal.
    if isinstance(error, dict):
        error = error.get('message', '')
    detail = str(error).lower()
    if any(part in detail for part in ('not logged', 'unauthorized', 'unauthenticated',
                                      'sign in', 'sign-in', 'log in', 'login required',
                                      'authentication', 'not authenticated', '401',
                                      'missing token', 'missing api key', 'no api key',
                                      'credential', 'oauth unavailable', 'oauth token',
                                      'token expired', 'not found in keychain')):
        return 'sign_in_required'
    if any(part in detail for part in ('not supported', 'unsupported', 'macos only',
                                      'only supported on macos', 'requires macos')):
        return 'unsupported_source'
    return 'offline'


def normalize_codex(payload, now):
    normalized = normalize_limits(payload, now)
    result = state_for('codex', now, None)
    for key, label in (('primary', 'Session'), ('secondary', 'Weekly')):
        if normalized.get(key) is not None:
            result['windows'].append(dict(normalized[key], label=label))
    result.update(status='ok', updated_at=now)
    return result


def normalize_cli(payload, provider, now):
    result = state_for(provider, now, 'usage_unavailable')
    # v0.83.0 emits an array. Refuse aggregate/multi-account responses rather
    # than silently attaching one account's values to another selection.
    if not isinstance(payload, list) or len(payload) != 1:
        return result
    item = payload[0]
    if not isinstance(item, dict) or item.get('provider') != provider:
        return result
    if item.get('error'):
        result['reason'] = classify_error(item['error'])
        return result
    snapshot = item.get('usage')
    snapshot = snapshot if isinstance(snapshot, dict) else {}
    labels = item.get('rateWindowLabels')
    labels = labels if isinstance(labels, dict) else {}
    for key, fallback in (('primary', 'Usage'), ('secondary', 'Additional limit'), ('tertiary', 'Additional limit')):
        label = labels.get(key)
        normalized = window(snapshot.get(key), label if isinstance(label, str) and label in WINDOW_LABELS else fallback)
        if normalized:
            result['windows'].append(normalized)
    extra = snapshot.get('extraRateWindows')
    for index, named in enumerate(extra[:32] if isinstance(extra, list) else []):
        if not isinstance(named, dict) or named.get('usageKnown') is False:
            continue
        # Named model/window titles are arbitrary provider text; use safe labels.
        normalized = window(named.get('window'), f'Additional limit {index + 1}')
        if normalized:
            result['windows'].append(normalized)

    def add_amount(label, value, unit=''):
        if number(value):
            result['details'].append({'label': label, 'value': f'{value:g}' + (f' {unit}' if unit else '')})

    cost = snapshot.get('providerCost')
    if isinstance(cost, dict):
        currency = cost.get('currencyCode')
        unit = currency if currency in ('USD', 'EUR', 'GBP', 'CNY', 'JPY', 'KRW', 'CAD', 'AUD', 'INR', 'credits') else ''
        if number(cost.get('used')) and (cost['used'] > 0 or number(cost.get('limit'), 0.000001)):
            add_amount('Spent', cost.get('used'), unit)
        if number(cost.get('limit'), 0.000001):
            add_amount('Budget', cost.get('limit'), unit)
        add_amount('Balance', cost.get('balance'), unit)
    credits = item.get('credits')
    if isinstance(credits, dict) and credits.get('balanceReadSucceeded', True) is True:
        add_amount('Credits remaining', credits.get('remaining'))
    if result['windows'] or result['details']:
        observed = timestamp(snapshot.get('updatedAt'))
        result.update(status='ok', reason=None, updated_at=min(observed, now) if observed else now)
    return result


def write_state(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = tempfile.NamedTemporaryFile('w', dir=path.parent, delete=False)
    try:
        with temporary:
            json.dump(data, temporary, allow_nan=False)
            temporary.write('\n')
        os.replace(temporary.name, path)
    finally:
        Path(temporary.name).unlink(missing_ok=True)


@contextmanager
def selection_lock(config):
    config.parent.mkdir(parents=True, exist_ok=True)
    with (config.parent / '.ai-usage.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def read_selection(config):
    try:
        # Include inode/mtime so A -> B -> A invalidates an in-flight A fetch.
        with config.open() as stream:
            stat = os.fstat(stream.fileno())
            data = json.load(stream)
        provider = data.get('provider') if isinstance(data, dict) else None
        generation = (stat.st_ino, stat.st_mtime_ns, stat.st_size)
        return (provider if provider in PROVIDERS else 'codex'), generation
    except (OSError, ValueError, TypeError):
        return 'codex', None


def select_provider(provider, config, state):
    if provider not in PROVIDERS:
        raise ValueError('Unknown provider')
    with selection_lock(config):
        write_state(config, {'provider': provider})
        write_state(state, state_for(provider, int(time.time())))


def publish_selected(config, state, generation, data):
    with selection_lock(config):
        provider, current_generation = read_selection(config)
        if current_generation != generation or data['provider'] != provider:
            return False
        write_state(state, data)
        return True


class FetchFailure(Exception):
    def __init__(self, reason):
        self.reason = reason
        super().__init__(reason)


async def terminate_owned(process):
    # Every spawned child starts a new session. Never kill by process name or
    # touch user-owned CodexBar/Codex sessions outside this exact process group.
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        await asyncio.wait_for(process.wait(), 2)
    except asyncio.TimeoutError:
        pass
    finally:
        # A helper can outlive an exited group leader and keep its pipes open.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        await process.wait()


async def run_command(argv, timeout=45):
    try:
        process = await asyncio.create_subprocess_exec(
            *argv, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
            stdin=asyncio.subprocess.DEVNULL, start_new_session=True)
    except OSError:
        raise FetchFailure('client_missing') from None

    async def read_output():
        chunks, size = [], 0
        while chunk := await process.stdout.read(65536):
            size += len(chunk)
            if size > MAX_OUTPUT:
                raise FetchFailure('invalid_response')
            chunks.append(chunk)
        return b''.join(chunks)

    try:
        output, _ = await asyncio.wait_for(asyncio.gather(read_output(), process.wait()), timeout)
        if process.returncode:
            reason = 'offline'
            try:
                payload = json.loads(output)
                if isinstance(payload, list) and len(payload) == 1 and isinstance(payload[0], dict):
                    reason = classify_error(payload[0].get('error', {}))
            except (ValueError, TypeError):
                pass
            raise FetchFailure(reason)
        return output
    except asyncio.TimeoutError:
        raise FetchFailure('timeout') from None
    finally:
        await terminate_owned(process)


def codexbar_binary(override=None):
    if override:
        return override
    data_home = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    bundled = data_home / f'caelestia-pop-os/codexbar-{CODEXBAR_VERSION}/CodexBarCLI'
    if bundled.is_file() and os.access(bundled, os.X_OK):
        return str(bundled)
    return shutil.which('codexbar') or shutil.which('CodexBarCLI')


async def fetch_provider(provider, binary=None):
    now = int(time.time())
    if provider == 'codex':
        executable = shutil.which('codex')
        if not executable:
            return error_state(provider, now, 'client_missing')
        client = CodexClient(executable)
        try:
            async with asyncio.timeout(45):
                await client.start()
                payload = await client.request('account/rateLimits/read')
            return normalize_codex(payload, int(time.time()))
        except asyncio.TimeoutError:
            return error_state(provider, int(time.time()), 'timeout')
        except (OSError, ValueError, TypeError, AttributeError, OverflowError, RuntimeError, ConnectionError) as error:
            return error_state(provider, int(time.time()), classify_error(error))
        finally:
            try:
                await client.close()
            except (ProcessLookupError, OSError):
                pass
    source = source_for(provider)
    if source is None:
        return error_state(provider, now, 'unsupported_source')
    binary = binary or codexbar_binary()
    if not binary:
        return error_state(provider, now, 'client_missing')
    try:
        output = await run_command([binary, 'usage', '--provider', provider, '--source', source,
                                    '--json', '--json-only', '--no-color'])
        return normalize_cli(json.loads(output), provider, int(time.time()))
    except FetchFailure as error:
        return error_state(provider, int(time.time()), error.reason)
    except (ValueError, TypeError, UnicodeError):
        return error_state(provider, int(time.time()), 'invalid_response')


def signal_service():
    try:
        result = subprocess.run(['systemctl', '--user', 'kill', '--signal=SIGUSR1',
                                 '--kill-whom=main', SERVICE], timeout=5, check=False,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def refresh_service(config, state):
    if signal_service():
        return 0
    provider, generation = read_selection(config)
    publish_selected(config, state, generation,
                     error_state(provider, int(time.time()), 'service_unavailable'))
    return 1


async def run(args):
    wake, stop = asyncio.Event(), asyncio.Event()
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signum, lambda: (stop.set(), wake.set()))
    loop.add_signal_handler(signal.SIGUSR1, wake.set)
    failures = 0
    previous_selection = None
    while not stop.is_set():
        wake.clear()
        provider, generation = read_selection(args.config)
        if (provider, generation) != previous_selection:
            failures = 0
            previous_selection = provider, generation
        pending = state_for(provider, int(time.time()))
        pending['refreshing'] = True
        publish_selected(args.config, args.state, generation, pending)
        fetching = asyncio.create_task(fetch_provider(provider, codexbar_binary(args.codexbar)))
        interrupt = asyncio.create_task(wake.wait())
        try:
            done, _ = await asyncio.wait((fetching, interrupt), return_when=asyncio.FIRST_COMPLETED)
            if interrupt in done:
                fetching.cancel()
                await asyncio.gather(fetching, return_exceptions=True)
                continue
            data = await fetching
        finally:
            interrupt.cancel()
            if not fetching.done():
                fetching.cancel()
            await asyncio.gather(fetching, interrupt, return_exceptions=True)
        if not publish_selected(args.config, args.state, generation, data):
            continue
        success = data['status'] == 'ok'
        failures = 0 if success else failures + 1
        if args.once:
            return 0 if success else 1
        delay = min(args.interval * (2 ** min(failures, 3)), 300)
        try:
            await asyncio.wait_for(wake.wait(), delay)
        except asyncio.TimeoutError:
            pass
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, default=Path(os.environ.get(
        'XDG_CONFIG_HOME', Path.home() / '.config')) / 'caelestia/ai-usage.json')
    parser.add_argument('--state', type=Path, default=Path(os.environ.get(
        'XDG_CACHE_HOME', Path.home() / '.cache')) / 'caelestia/ai-usage.json')
    parser.add_argument('--codexbar', help='Path to the pinned official CodexBarCLI')
    parser.add_argument('--interval', type=int, default=60)
    commands = parser.add_mutually_exclusive_group()
    commands.add_argument('--select', metavar='ID')
    commands.add_argument('--refresh', action='store_true')
    commands.add_argument('--once', action='store_true')
    commands.add_argument('--list', action='store_true')
    args = parser.parse_args(argv)
    if args.interval < 30:
        parser.error('interval must be at least 30 seconds')
    if args.list:
        print(json.dumps(CATALOG))
        return 0
    try:
        if args.select is not None:
            if args.select not in PROVIDERS:
                parser.error('unknown provider; use --list')
            select_provider(args.select, args.config, args.state)
            return refresh_service(args.config, args.state)
        if args.refresh:
            return refresh_service(args.config, args.state)
        return asyncio.run(run(args))
    except (OSError, ValueError):
        # No exception details: filesystem errors can contain private paths.
        print('AI usage state is unavailable', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
