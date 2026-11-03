import unittest, json
from codex_usage import normalize_limits, error_state

class UsageTests(unittest.TestCase):
    def fixture(self):
        return {'rateLimits': {'limitId':'other','primary':{'usedPercent':99}}, 'rateLimitsByLimitId': {'codex': {'planType':'plus','primary':{'usedPercent':57,'windowDurationMins':300,'resetsAt':2000000000},'secondary':{'usedPercent':67,'windowDurationMins':10080,'resetsAt':2000100000},'access_token':'must-not-be-cached'}}}
    def test_codex_bucket_and_windows(self):
        d=normalize_limits(self.fixture(),1000)
        self.assertEqual(d['primary']['used_percent'],57)
        self.assertEqual(d['secondary']['window_minutes'],10080)
        self.assertEqual(d['plan_type'],'plus')
        self.assertNotIn('must-not-be-cached',json.dumps(d))
    def test_missing_secondary_is_unknown(self):
        d=normalize_limits({'rateLimits':{'primary':{'usedPercent':0}}},1000)
        self.assertIsNone(d['secondary'])
        self.assertEqual(d['primary']['used_percent'],0)
    def test_invalid_data_is_not_zero_usage(self):
        for value in [float('nan'),True,'57',None]:
            with self.assertRaises(ValueError):normalize_limits({'rateLimits':{'primary':{'usedPercent':value}}},1000)
        with self.assertRaises(ValueError):normalize_limits({},1000)
    def test_error_retains_last_good_timestamp_and_marks_stale(self):
        old=normalize_limits(self.fixture(),1000)
        d=error_state(old,1100,'offline')
        self.assertEqual(d['status'],'stale')
        self.assertEqual(d['updated_at'],1000)
        self.assertEqual(d['primary'],old['primary'])
        self.assertEqual(d['last_attempt'],1100)
        self.assertEqual(old['status'],'ok')
    def test_no_cached_data_does_not_fabricate_percentages(self):
        d=error_state(None,1100,'sign_in_required')
        self.assertEqual(d['status'],'sign_in_required')
        self.assertIsNone(d['primary'])
        self.assertIsNone(d['secondary'])

if __name__=='__main__':unittest.main()
