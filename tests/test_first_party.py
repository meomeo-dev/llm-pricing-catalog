import unittest

from catalog_harness import open_catalog, price_at


class PointInTimeLookup(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def test_standard_price_carries_source(self) -> None:
        hit = price_at(self.db, channel_id="anthropic-api", label="claude-opus-5-5",
                       at="2026-09-24T12:00:00Z")
        self.assertEqual(hit["rates"], {
            "input": "4", "cache_write_5m": "5", "cache_write_1h": "8",
            "cache_read": "0.20", "output": "20"})
        first = hit["rows"][0]
        self.assertEqual(first["source_id"], "anthropic-pricing@2026-09-24")
        self.assertIn("$20 / MTok", first["source_excerpt"])

    def test_context_tier_reprices_whole_request_above_threshold(self) -> None:
        query = dict(channel_id="openai-api", label="gpt-6-sol",
                     at="2026-09-24T12:00:00Z")
        at_threshold = price_at(self.db, **query, input_tokens=272000)
        above = price_at(self.db, **query, input_tokens=272001)
        self.assertEqual(at_threshold["rates"]["input"], "2.00")
        self.assertEqual(above["rates"],
                         {"input": "4.00", "cache_read": "0.40",
                          "cache_write": "5.00", "output": "15.00"})

    def test_announced_future_price_takes_over_at_boundary(self) -> None:
        query = dict(channel_id="gemini-api", label="gemini-3.8-flash")
        before = price_at(self.db, **query, at="2026-12-31T23:59:59Z")
        after = price_at(self.db, **query, at="2027-01-01T00:00:00Z")
        self.assertEqual(before["rates"]["input"], "0.75")
        self.assertEqual(before["rows"][0]["is_promotional"], 1)
        self.assertEqual(after["rates"]["input"], "1.50")
        self.assertEqual(after["rows"][0]["date_basis"], "official_announced")

    def test_cancelled_increase_is_replayable_as_known_then(self) -> None:
        query = dict(channel_id="anthropic-api", label="claude-sonnet-5",
                     at="2026-09-15T00:00:00Z")
        now = price_at(self.db, **query)
        then = price_at(self.db, **query, known_at="2026-08-01T00:00:00Z")
        self.assertEqual(now["rates"], {"input": "2", "output": "10"})
        self.assertEqual(then["rates"], {"input": "3", "output": "15"})

    def test_client_label_resolves_through_alias_and_reference_channel(self) -> None:
        hit = price_at(self.db, client_id="agy", label="gemini-3.8-flash-high",
                       at="2026-09-24T12:00:00Z")
        self.assertEqual(hit["rows"][0]["model_id"], "gemini-3.8-flash")
        self.assertEqual(hit["rows"][0]["offering_id"], "gemini-api/gemini-3.8-flash")
        self.assertEqual(hit["rates"]["output"], "3.75")

    def test_time_window_selects_peak_card(self) -> None:
        query = dict(channel_id="deepseek-api", label="deepseek-v4-pro",
                     at="2026-09-24T02:00:00Z")
        peak = price_at(self.db, **query, window_id="deepseek-peak")
        off_peak = price_at(self.db, **query)
        self.assertEqual(peak["rates"]["input"], "1.32")
        self.assertEqual(off_peak["rates"]["input"], "0.66")

    def test_multi_vendor_client_falls_back_to_vendor_api(self) -> None:
        self.db.execute("INSERT INTO client VALUES ('opencode', 'OpenCode', NULL)")
        self.db.execute(
            "INSERT INTO client_revision (client_id, reference_channel_id, valid_from,"
            " date_basis, recorded_at, source_id) VALUES ('opencode', NULL,"
            " '2026-01-01T00:00:00Z', 'inferred', '2026-09-24T00:00:00Z',"
            " 'fixture-constructed')")
        for label, output in (("claude-opus-5-5", "20"), ("gpt-6-sol", "10.00")):
            with self.subTest(label=label):
                hit = price_at(self.db, client_id="opencode", label=label,
                               at="2026-09-24T12:00:00Z")
                self.assertEqual(hit["rates"]["output"], output)

    def test_unknown_label_returns_nothing_and_gap_explains(self) -> None:
        hit = price_at(self.db, client_id="agy", label="agy-model:1026",
                       at="2026-09-24T12:00:00Z")
        self.assertIsNone(hit["card"])
        reason = self.db.execute(
            "SELECT reason FROM price_gap"
            " WHERE namespace_id = 'client:agy' AND label = ?",
            ("agy-model:1026",)).fetchone()["reason"]
        self.assertEqual(reason, "legacy_label")

    def test_before_first_price_returns_nothing(self) -> None:
        hit = price_at(self.db, channel_id="anthropic-api", label="claude-opus-5-5",
                       at="2026-09-20T23:59:59Z")
        self.assertIsNone(hit["card"])


if __name__ == "__main__":
    unittest.main()
