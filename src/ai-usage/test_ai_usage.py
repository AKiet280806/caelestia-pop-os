"""Contract and isolation tests; never use the host's provider credentials."""
import asyncio
import json
import os
from pathlib import Path
import signal
import sys
import tempfile
import unittest
from unittest.mock import AsyncMock, patch

import ai_usage as usage


class ContractTests(unittest.TestCase):
    def payload(self, provider='claude'):
        return [{'provider': provider, 'account': 'private@example.invalid',
                 'diagnostic': 'token-secret', 'usage': {
                     'primary': {'usedPercent': 42, 'windowMinutes': 300,
                                 'resetsAt': '2030-01-01T00:00:00Z'},
                     'secondary': {'usedPercent': 0, 'windowMinutes': 10080},
                     'identity': {'accountEmail': 'private@example.invalid'},
                     'details': [{'title': 'token-secret'}]},
                 'rateWindowLabels': {'primary': 'Session', 'secondary': 'Weekly'}}]

    def test_windows_and_dates_and_identity_scrubbing(self):
        state = usage.normalize_cli(self.payload(), 'claude', 1000)
        self.assertEqual(state['windows'][0], {
            'label': 'Session', 'used_percent': 42, 'window_minutes': 300,
            'resets_at': 1893456000})
        self.assertEqual(state['windows'][1]['used_percent'], 0)
        self.assertEqual(state['provider'], 'claude')
        self.assertEqual(state['status'], 'ok')
        self.assertNotIn('private', json.dumps(state))
        self.assertNotIn('token-secret', json.dumps(state))

    def test_extra_windows_and_over_quota(self):
        payload = self.payload()
        payload[0]['usage']['primary']['usedPercent'] = 150
        payload[0]['usage']['extraRateWindows'] = [
            {'title': 'private@example.invalid', 'window': {'usedPercent': 71}},
            {'title': 'Unknown', 'usageKnown': False, 'window': {'usedPercent': 100}}]
        state = usage.normalize_cli(payload, 'claude', 1000)
        self.assertEqual(state['windows'][0]['used_percent'], 100)
        self.assertEqual(state['windows'][-1]['used_percent'], 71)
        self.assertEqual(len(state['windows']), 3)
        self.assertNotIn('private', json.dumps(state))

    def test_unavailable_is_never_fabricated_zero(self):
        for value in [None, '42', True, float('nan'), float('inf'), -1]:
            payload = [{'provider': 'claude', 'usage': {'primary': {'usedPercent': value}}}]
            state = usage.normalize_cli(payload, 'claude', 1000)
            self.assertEqual(state['status'], 'unknown')
            self.assertEqual(state['windows'], [])
        payload = [{'provider': 'claude', 'usage': {'primary': {
            'usedPercent': 0, 'isSyntheticPlaceholder': True}}}]
        self.assertEqual(usage.normalize_cli(payload, 'claude', 1000)['windows'], [])

    def test_cost_and_credit_only_providers(self):
        payload = [{'provider': 'deepseek', 'usage': {'providerCost': {
            'used': 3.25, 'limit': 20, 'balance': 16.75, 'currencyCode': 'USD'}},
                    'credits': {'remaining': 9, 'balanceReadSucceeded': True}}]
        state = usage.normalize_cli(payload, 'deepseek', 1000)
        self.assertEqual(state['status'], 'ok')
        self.assertEqual(state['windows'], [])
        self.assertIn({'label': 'Balance', 'value': '16.75 USD'}, state['details'])
        self.assertIn({'label': 'Credits remaining', 'value': '9'}, state['details'])

    def test_unread_credit_balance_is_not_zero(self):
        payload = [{'provider': 'deepseek', 'credits': {
            'remaining': 0, 'balanceReadSucceeded': False}}]
        state = usage.normalize_cli(payload, 'deepseek', 1000)
        self.assertEqual(state['details'], [])
        self.assertEqual(state['status'], 'unknown')

    def test_error_and_wrong_or_multiple_accounts_cannot_be_mislabeled(self):
        for payload in [[{'provider': 'claude', 'error': {'message': '401 token-secret'}}],
                        self.payload('codex'), self.payload() + self.payload()]:
            state = usage.normalize_cli(payload, 'claude', 1000)
            self.assertEqual(state['windows'], [])
            self.assertNotEqual(state['status'], 'ok')
            self.assertNotIn('token-secret', json.dumps(state))

    def test_missing_oauth_credentials_is_sign_in_required(self):
        self.assertEqual(usage.classify_error({'message': 'OAuth credentials not found'}),
                         'sign_in_required')

    def test_codex_uses_existing_bucket_normalizer(self):
        state = usage.normalize_codex({'rateLimitsByLimitId': {'codex': {
            'primary': {'usedPercent': 37, 'windowDurationMins': 300},
            'secondary': {'usedPercent': 73, 'windowDurationMins': 10080},
            'access_token': 'token-secret'}}}, 1000)
        self.assertEqual([w['used_percent'] for w in state['windows']], [37, 73])
        self.assertNotIn('token-secret', json.dumps(state))

    def test_stale_requires_matching_provider_and_explicit_scope(self):
        old = usage.normalize_cli(self.payload(), 'claude', 1000)
        self.assertEqual(usage.error_state('claude', 1100, 'offline', old)['windows'], [])
        self.assertEqual(usage.error_state('codex', 1100, 'offline', old,
                                         scope='same', previous_scope='same')['windows'], [])
        self.assertEqual(usage.error_state('claude', 1100, 'offline', old,
                                         scope='new', previous_scope='old')['windows'], [])
        stale = usage.error_state('claude', 1100, 'offline', old,
                                  scope='same', previous_scope='same')
        self.assertEqual(stale['status'], 'stale')
        self.assertEqual(stale['updated_at'], 1000)

    def test_safe_source_selection_never_uses_auto_or_inference_probes(self):
        self.assertEqual(usage.source_for('claude'), 'oauth')
        self.assertEqual(usage.source_for('gemini'), 'api')
        self.assertEqual(usage.source_for('cursor'), 'web')
        self.assertEqual(usage.source_for('grok'), 'cli')
        for provider in ('doubao', 'azureopenai', 'azure-openai', 'pi', 'augment'):
            self.assertIsNone(usage.source_for(provider))
        self.assertEqual(len(usage.PROVIDERS), 13)
        self.assertNotIn('auto', {usage.source_for(p) for p in usage.PROVIDERS})


class SelectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config = Path(self.tmp.name) / 'config/ai-usage.json'
        self.state = Path(self.tmp.name) / 'cache/ai-usage.json'

    def test_switch_clears_previous_data_immediately(self):
        usage.write_state(self.state, usage.normalize_codex({
            'rateLimits': {'primary': {'usedPercent': 40}}}, 1000))
        usage.select_provider('claude', self.config, self.state)
        self.assertEqual(json.loads(self.config.read_text()), {'provider': 'claude'})
        state = json.loads(self.state.read_text())
        self.assertEqual(state['provider'], 'claude')
        self.assertEqual(state['windows'], [])
        self.assertIsNone(state['updated_at'])

    def test_invalid_provider_does_not_change_files(self):
        usage.select_provider('codex', self.config, self.state)
        before = self.config.read_bytes(), self.state.read_bytes()
        with self.assertRaises(ValueError):
            usage.select_provider('--all', self.config, self.state)
        self.assertEqual(before, (self.config.read_bytes(), self.state.read_bytes()))

    def test_out_of_order_fetch_and_aba_selection_do_not_publish(self):
        usage.select_provider('codex', self.config, self.state)
        provider, generation = usage.read_selection(self.config)
        usage.select_provider('claude', self.config, self.state)
        usage.select_provider('codex', self.config, self.state)
        old = usage.normalize_codex({'rateLimits': {'primary': {'usedPercent': 80}}}, 1000)
        self.assertFalse(usage.publish_selected(self.config, self.state, generation, old))
        self.assertEqual(json.loads(self.state.read_text())['windows'], [])

    def test_failed_service_signal_is_reported_and_clears_refreshing(self):
        with patch.object(usage, 'signal_service', return_value=False):
            rc = usage.main(['--select', 'claude', '--config', str(self.config),
                             '--state', str(self.state)])
        self.assertEqual(rc, 1)
        self.assertEqual(json.loads(self.config.read_text()), {'provider': 'claude'})
        state = json.loads(self.state.read_text())
        self.assertEqual(state['reason'], 'service_unavailable')
        self.assertFalse(state['refreshing'])
        with patch.object(usage, 'signal_service', return_value=False):
            self.assertEqual(usage.main(['--refresh', '--config', str(self.config),
                                         '--state', str(self.state)]), 1)

    def test_pinned_bundle_precedes_path_binary(self):
        bundled = Path(self.tmp.name) / 'caelestia-pop-os/codexbar-0.83.0/CodexBarCLI'
        bundled.parent.mkdir(parents=True)
        bundled.touch(mode=0o700)
        with patch.dict(os.environ, {'XDG_DATA_HOME': self.tmp.name}), \
                patch.object(usage.shutil, 'which', return_value='/unverified/codexbar'):
            self.assertEqual(usage.codexbar_binary(), str(bundled))
            self.assertEqual(usage.codexbar_binary('/explicit/cli'), '/explicit/cli')


class ProcessTests(unittest.IsolatedAsyncioTestCase):
    async def test_daemon_cancels_old_fetch_on_selection_and_terminates_cleanly(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            config, state = root / 'selection.json', root / 'usage.json'
            script = root / 'fake-cli'
            marker = root / 'started'
            script.write_text(
                '#!' + sys.executable + '\nimport json,sys,time\nfrom pathlib import Path\n'
                'provider=sys.argv[sys.argv.index("--provider")+1]\n'
                f'Path({str(marker)!r}).write_text(provider)\n'
                'if provider=="claude": time.sleep(10)\n'
                'print(json.dumps([{"provider":provider,"usage":{"primary":{"usedPercent":23}}}]))\n')
            script.chmod(0o700)
            usage.select_provider('claude', config, state)
            daemon = await asyncio.create_subprocess_exec(
                sys.executable, str(Path(usage.__file__)), '--config', str(config),
                '--state', str(state), '--codexbar', str(script),
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
            try:
                async with asyncio.timeout(5):
                    while not marker.exists():
                        await asyncio.sleep(0.01)
                usage.select_provider('gemini', config, state)
                os.kill(daemon.pid, signal.SIGUSR1)
                async with asyncio.timeout(5):
                    while True:
                        value = json.loads(state.read_text())
                        if value['provider'] == 'gemini' and value['status'] == 'ok':
                            break
                        await asyncio.sleep(0.01)
                self.assertEqual(value['windows'][0]['used_percent'], 23)
                os.kill(daemon.pid, signal.SIGTERM)
                stdout, stderr = await asyncio.wait_for(daemon.communicate(), 5)
                self.assertEqual(daemon.returncode, 0)
                self.assertEqual(stdout + stderr, b'')
            finally:
                if daemon.returncode is None:
                    daemon.kill()
                    await daemon.wait()

    async def test_timeout_terminates_only_owned_process_and_sanitizes_error(self):
        with tempfile.TemporaryDirectory() as folder:
            script = Path(folder) / 'fake-cli'
            script.write_text('#!/usr/bin/env python3\nimport time\nprint("token-secret", flush=True)\ntime.sleep(10)\n')
            script.chmod(0o700)
            with self.assertRaises(usage.FetchFailure) as error:
                await usage.run_command([str(script)], timeout=0.05)
            self.assertEqual(error.exception.reason, 'timeout')
            self.assertNotIn('token-secret', str(error.exception))

    async def test_failed_cli_discards_stdout_and_stderr(self):
        with tempfile.TemporaryDirectory() as folder:
            script = Path(folder) / 'fake-cli'
            script.write_text('#!/bin/sh\necho token-secret\necho private@example.invalid >&2\nexit 1\n')
            script.chmod(0o700)
            with self.assertRaises(usage.FetchFailure) as error:
                await usage.run_command([str(script)])
            self.assertNotIn('token-secret', str(error.exception))
            self.assertNotIn('private', str(error.exception))

    async def test_backend_fetches_exactly_selected_provider_with_safe_source(self):
        with patch.object(usage, 'run_command', new=AsyncMock(return_value=json.dumps(
                [{'provider': 'claude', 'usage': {'primary': {'usedPercent': 40}}}]
        ).encode())) as command:
            state = await usage.fetch_provider('claude', '/fake/codexbar')
        self.assertEqual(state['provider'], 'claude')
        argv = command.call_args.args[0]
        self.assertEqual(argv[argv.index('--provider') + 1], 'claude')
        self.assertEqual(argv[argv.index('--source') + 1], 'oauth')
        self.assertNotIn('--all-accounts', argv)

    async def test_unsupported_provider_never_starts_cli(self):
        with patch.object(usage, 'run_command', new=AsyncMock()) as command:
            state = await usage.fetch_provider('doubao', '/fake/codexbar')
        command.assert_not_called()
        self.assertEqual(state['reason'], 'unsupported_source')
        self.assertEqual(state['status'], 'unknown')


if __name__ == '__main__':
    unittest.main()
