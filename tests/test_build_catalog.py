import sqlite3
import sys
import unittest

from catalog_harness import ROOT, SCHEMA_DIR, price_at

sys.path.insert(0, str(ROOT / "scripts"))

from catalog_build import database, entries, keys
from catalog_build.expand import EntryError, expand

REFERENCE = """
[[organization]]
org_id = "anthropic"
display_name = "Anthropic"

[[organization]]
org_id = "fixture"
display_name = "构造数据"

[[channel]]
channel_id = "anthropic-api"
owner_org_id = "anthropic"
kind = "first_party_api"
display_name = "Claude API"

[[billing_unit]]
unit_id = "USD"
kind = "fiat"
description = "美元"

[[meter]]
meter_id = "input"
quantity_unit = "token"
per_quantity = 1000000
description = "输入"

[[meter]]
meter_id = "output"
quantity_unit = "token"
per_quantity = 1000000
description = "输出"

[[source]]
source_id = "page@2026-09-24"
url = "https://example.com/pricing"
publisher_org_id = "anthropic"
kind = "official_pricing_page"
retrieved_at = "2026-09-24T20:00:00Z"

[[model]]
model_id = "claude-x"
vendor_org_id = "anthropic"
display_name = "Claude X"

[[client]]
client_id = "claude-code"
display_name = "Claude Code"
"""

PRICES = """
[defaults]
valid_from = "2026-09-01T00:00:00Z"
date_basis = "first_observed"
recorded_at = "2026-09-24T20:00:00Z"
source_id = "page@2026-09-24"

[[offering]]
channel_id = "anthropic-api"
model_id = "claude-x"
channel_model_id = "claude-x"
availability = "available"
vendor_relationship = "first_party"

[[price_card]]
offering_id = "anthropic-api/claude-x"
context_tier_bound = "gt"
rates = { input = "3", output = "15" }
tiers = [{ min_tokens = 200000, rates = { input = "6", output = "22.50" } }]
excerpt = "Claude X | $3 / MTok | $15 / MTok"

[[model_identifier]]
client = "claude-code"
kind = "label"
identifier = "claude-x[1m]"
model_id = "claude-x"
implied_variant = "[1m]"
"""

CORRECTION = """
[defaults]
date_basis = "first_observed"
recorded_at = "2026-09-25T00:00:00Z"
source_id = "page@2026-09-24"

[[supersede]]
table = "price_card"
offering_id = "anthropic-api/claude-x"
valid_from = "2026-09-01T00:00:00Z"
recorded_at = "2026-09-24T20:00:00Z"
superseded_at = "2026-09-25T00:00:00Z"
reason = "correction"

[[price_card]]
offering_id = "anthropic-api/claude-x"
valid_from = "2026-09-01T00:00:00Z"
rates = { input = "3", output = "14" }
"""


def build(*documents: tuple[str, str]):
    connection = database.open_schema(SCHEMA_DIR)
    rows = [row for name, text in documents
            for entry in entries.parse(text, name) for row in expand(entry)]
    by_table, supersedes = database.collect(connection, rows)
    database.insert_all(connection, by_table)
    database.apply_supersedes(connection, supersedes)
    return connection, by_table, supersedes


class BuildFromToml(unittest.TestCase):
    def test_entries_expand_and_satisfy_invariants(self) -> None:
        connection, _, _ = build(("ref", REFERENCE), ("prices", PRICES))
        connection.row_factory = sqlite3.Row
        self.assertEqual(database.violations(connection), {})
        hit = price_at(connection, client_id="claude-code", channel_id="anthropic-api",
                       label="claude-x[1m]", at="2026-09-24T00:00:00Z",
                       input_tokens=250000)
        self.assertEqual(hit["rates"], {"input": "6", "output": "22.50"})
        self.assertEqual(hit["series"], "anthropic-api/claude-x/standard/global/USD")
        self.assertIn("$15 / MTok", hit["rows"][0]["source_excerpt"])

    def test_surrogate_key_is_stable_across_builds(self) -> None:
        first, _, _ = build(("ref", REFERENCE), ("prices", PRICES))
        second, _, _ = build(("prices", PRICES), ("ref", REFERENCE))
        query = "SELECT price_card_id FROM price_card"
        self.assertEqual(first.execute(query).fetchall(),
                         second.execute(query).fetchall())
        expected = keys.surrogate_id("price_card",
                                     "anthropic-api/claude-x/standard/global/USD",
                                     "2026-09-01T00:00:00Z", "2026-09-24T20:00:00Z")
        self.assertEqual(first.execute(query).fetchone()[0], expected)

    def test_correction_supersedes_and_replaces(self) -> None:
        connection, _, _ = build(("ref", REFERENCE), ("prices", PRICES),
                                 ("fix", CORRECTION))
        connection.row_factory = sqlite3.Row
        self.assertEqual(database.violations(connection), {})
        query = dict(channel_id="anthropic-api", label="claude-x",
                     at="2026-09-24T00:00:00Z")
        self.assertEqual(price_at(connection, **query)["rates"]["output"], "14")
        before_fix = price_at(connection, **query, known_at="2026-09-24T21:00:00Z")
        self.assertEqual(before_fix["rates"]["output"], "15")

    def test_amount_must_be_a_string(self) -> None:
        with self.assertRaises(EntryError):
            build(("ref", REFERENCE),
                  ("prices", PRICES.replace('input = "3"', "input = 3")))

    def test_conflicting_identity_declarations_fail(self) -> None:
        with self.assertRaises(database.BuildError):
            build(("ref", REFERENCE),
                  ("again", REFERENCE.replace('"Claude X"', '"Claude Y"')))


class AppendOnlyReplay(unittest.TestCase):
    def replay(self, old: tuple, new: tuple) -> None:
        connection, _, _ = build(*old)
        fresh = database.open_schema(SCHEMA_DIR)
        seeded = {t: database.stored_keys(fresh, t) for t in database.table_order(fresh)}
        _, by_table, supersedes = build(*new)
        database.replay(connection, by_table, supersedes, seeded)

    def test_adding_a_correction_is_accepted(self) -> None:
        base = (("ref", REFERENCE), ("prices", PRICES))
        self.replay(base, base + (("fix", CORRECTION),))

    def test_rewriting_a_history_rate_is_rejected(self) -> None:
        with self.assertRaises(database.BuildError):
            self.replay((("ref", REFERENCE), ("prices", PRICES)),
                        (("ref", REFERENCE),
                         ("prices", PRICES.replace('output = "15"', 'output = "16"'))))

    def test_dropping_an_entry_is_rejected(self) -> None:
        trimmed = PRICES[:PRICES.index("[[model_identifier]]")]
        with self.assertRaises(database.BuildError):
            self.replay((("ref", REFERENCE), ("prices", PRICES)),
                        (("ref", REFERENCE), ("prices", trimmed)))

    def test_type1_rename_is_accepted(self) -> None:
        renamed = REFERENCE.replace('display_name = "Claude Code"',
                                    'display_name = "Claude Code CLI"')
        self.replay((("ref", REFERENCE), ("prices", PRICES)),
                    (("ref", renamed), ("prices", PRICES)))


if __name__ == "__main__":
    unittest.main()
