import sys
import unittest
from datetime import datetime, timezone

from catalog_harness import PRICE_AT_DEFAULTS, ROOT, open_catalog, price_at

sys.path.insert(0, str(ROOT / "scripts"))

from query_price import lookup

OPUS_QUERY = {"channel_id": "anthropic-api", "label": "claude-opus-5-5"}
AT = "2026-09-24T12:00:00Z"
IN_EFFECT = """
SELECT meter_id, amount FROM price_history
 WHERE model_id = 'claude-opus-5-5' AND channel_id = 'anthropic-api'
   AND service_tier = 'standard' AND region_id = 'global' AND plan_id IS NULL
   AND valid_from <= :at AND (valid_to IS NULL OR :at < valid_to)
"""


class PriceViews(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def test_history_has_one_row_per_believed_rate(self) -> None:
        believed = self.db.execute(
            "SELECT count(*) FROM price_rate r JOIN price_card c USING (price_card_id)"
            " WHERE c.superseded_at IS NULL").fetchone()[0]
        rows = self.db.execute("SELECT count(*) FROM price_history").fetchone()[0]
        self.assertEqual(rows, believed)

    def test_history_at_a_point_matches_price_at(self) -> None:
        rates = dict(self.db.execute(IN_EFFECT, {"at": AT}).fetchall())
        self.assertEqual(rates, price_at(self.db, **OPUS_QUERY, at=AT)["rates"])

    def test_current_rows_are_in_effect_now(self) -> None:
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        for row in self.db.execute("SELECT valid_from, valid_to FROM price_current"):
            self.assertLessEqual(row["valid_from"], now)
            self.assertTrue(row["valid_to"] is None or now < row["valid_to"])


class QueryPrice(unittest.TestCase):
    def test_lookup_returns_card_with_units_and_source(self) -> None:
        parameters = {**PRICE_AT_DEFAULTS, **OPUS_QUERY, "at": AT}
        [card] = lookup(open_catalog(), parameters)
        self.assertEqual((card["model_id"], card["channel_id"]),
                         ("claude-opus-5-5", "anthropic-api"))
        self.assertTrue(card["source_url"].startswith("https://"))
        output = next(rate for rate in card["rates"] if rate["meter_id"] == "output")
        self.assertEqual((output["amount"], output["per_quantity"], output["quantity_unit"]),
                         ("20", 1000000, "token"))


if __name__ == "__main__":
    unittest.main()
