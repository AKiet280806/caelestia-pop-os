#!/usr/bin/env python3
"""Publish Codex quota windows for the Caelestia sidebar using the official local RPC."""
import argparse
import asyncio
import json
import math
import os
from pathlib import Path
import shutil
import signal
import tempfile
import time


def normalize_window(value):
    if not isinstance(value, dict):
        return None
    used = value.get('usedPercent')
    if isinstance(used, bool) or not isinstance(used, (int, float)) or not math.isfinite(used) or not 0 <= used <= 100:
        return None
    duration = value.get('windowDurationMins')
    reset = value.get('resetsAt')
    return {
        'used_percent': used,
        'window_minutes': duration if type(duration) is int and duration > 0 else None,
        'resets_at': reset if type(reset) is int and reset > 0 else None,
    }


def normalize_limits(result, now):
    buckets = result.get('rateLimitsByLimitId') or {}
    bucket = buckets.get('codex') or result.get('rateLimits') or {}
    if bucket.get('limitId') not in (None, 'codex'):
        raise ValueError('Codex quota is unavailable')
    primary = normalize_window(bucket.get('primary'))
    secondary = normalize_window(bucket.get('secondary'))
    if primary is None and secondary is None:
        raise ValueError('Quota windows are unavailable')
    return {'status': 'ok', 'reason': None, 'primary': primary, 'secondary': secondary,
            'plan_type': bucket.get('planType'), 'updated_at': now, 'last_attempt': now,
            'refreshing': False}


def error_state(previous, now, reason):
    previous = previous or {}
    has_data = previous.get('updated_at') is not None
    return {'status': 'stale' if has_data else reason, 'reason': reason,
            'primary': previous.get('primary'), 'secondary': previous.get('secondary'),
            'plan_type': previous.get('plan_type'), 'updated_at': previous.get('updated_at'),
            'last_attempt': now, 'refreshing': False}


def write_state(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    f = tempfile.NamedTemporaryFile('w', dir=path.parent, delete=False)
    try:
        with f:
            json.dump(data, f, allow_nan=False)
            f.write('\n')
        os.replace(f.name, path)
    finally:
        Path(f.name).unlink(missing_ok=True)


class CodexClient:
    def __init__(self, binary):
        self.binary = binary
        self.process = None
        self.sequence = 0

    async def start(self):
        self.process = await asyncio.create_subprocess_exec(
            self.binary, 'app-server', '--listen', 'stdio://',
            stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL, start_new_session=True)
        await self.request('initialize', {'clientInfo': {
            'name': 'caelestia_usage_widget', 'title': 'Caelestia usage widget', 'version': '1.0.0'},
            'capabilities': {'experimentalApi': False}})
        await self.send({'method': 'initialized'})

    async def send(self, message):
        self.process.stdin.write((json.dumps(message) + '\n').encode())
        await self.process.stdin.drain()

    async def request(self, method, params=None):
        self.sequence += 1
        request_id = self.sequence
        message = {'id': request_id, 'method': method}
        if params is not None:
            message['params'] = params
        await self.send(message)
        deadline = asyncio.get_running_loop().time() + 30
        while True:
            remaining = deadline - asyncio.get_running_loop().time()
            if remaining <= 0:
                raise TimeoutError('RPC timed out')
            line = await asyncio.wait_for(self.process.stdout.readline(), remaining)
            if not line:
                raise ConnectionError('App-server disconnected')
            response = json.loads(line)
            if response.get('id') == request_id and ('result' in response or 'error' in response):
                if 'error' in response:
                    # Used only to classify failure; never copied into the cache or journal.
                    raise RuntimeError(response['error'].get('message', 'RPC failed'))
                return response['result']
            if 'id' in response and 'method' in response:
                await self.send({'id': response['id'], 'error': {
                    'code': -32601, 'message': 'Read-only quota client cannot handle this request'}})

    async def close(self):
        if not self.process:
            return
        if self.process.returncode is None:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), 4)
            except asyncio.TimeoutError:
                os.killpg(self.process.pid, signal.SIGKILL)
                await self.process.wait()
        self.process = None


async def run(args):
    binary = shutil.which('codex')
    if not binary:
        write_state(args.state, error_state(None, int(time.time()), 'client_missing'))
        return 1
    previous = None
    try:
        cached = json.loads(args.state.read_text())
        if cached.get('updated_at') and (cached.get('primary') or cached.get('secondary')):
            previous = error_state(cached, int(time.time()), 'loading')
    except (OSError, ValueError, TypeError):
        pass
    wake = asyncio.Event()
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for signum in (signal.SIGINT, signal.SIGTERM):
        loop.add_signal_handler(signum, lambda: (stop.set(), wake.set()))
    loop.add_signal_handler(signal.SIGUSR1, wake.set)
    client = None
    failures = 0
    try:
        while not stop.is_set():
            now = int(time.time())
            pending = dict(previous or error_state(None, now, 'loading'), refreshing=True)
            write_state(args.state, pending)
            try:
                if client is None:
                    client = CodexClient(binary)
                    await client.start()
                result = await client.request('account/rateLimits/read')
                previous = normalize_limits(result, int(time.time()))
                failures = 0
                write_state(args.state, previous)
            except (OSError, ValueError, RuntimeError, ConnectionError, asyncio.TimeoutError) as exc:
                failures += 1
                detail = str(exc).lower()
                reason = 'sign_in_required' if any(s in detail for s in ('not logged', 'unauthorized', 'authentication', '401')) else 'offline'
                write_state(args.state, error_state(previous, int(time.time()), reason))
                if client:
                    await client.close()
                    client = None
            if args.once:
                return 0 if failures == 0 else 1
            delay = min(args.interval * (2 ** min(failures, 3)), 300)
            try:
                await asyncio.wait_for(wake.wait(), delay)
            except asyncio.TimeoutError:
                pass
            wake.clear()
    finally:
        if client:
            await client.close()
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state', type=Path, default=Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'caelestia/codex-usage.json')
    parser.add_argument('--interval', type=int, default=60)
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()
    if args.interval < 30:
        parser.error('interval must be at least 30 seconds')
    return asyncio.run(run(args))


if __name__ == '__main__':
    raise SystemExit(main())
