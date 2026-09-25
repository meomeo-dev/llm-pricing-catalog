import sqlite3
import subprocess
import sys
import tomllib
import unittest

from catalog_harness import (ROOT, SCD2_DEFAULTS, SCHEMA_DIR, insert, open_catalog,
                             price_at)

EXPECTED_TABLES = {
    "organization", "region", "channel", "client", "label_namespace", "billing_unit",
    "meter", "source", "time_window",
    "model", "model_revision", "model_revision_modality", "model_revision_effort",
    "client_revision", "model_alias", "offering", "offering_revision", "offering_route",
    "plan", "plan_revision", "plan_revision_client", "plan_allowance",
    "unit_rate_series", "unit_rate", "pricing_rule", "pricing_rule_revision",
    "pricing_rule_scope_model", "pricing_rule_scope_meter",
    "price_series", "price_card", "price_rate", "price_evidence", "price_gap",
}


class AppendOnly(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def assert_aborted(self, statement: str, *params) -> None:
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute(statement, params)

    def test_history_rates_cannot_be_rewritten(self) -> None:
        self.assert_aborted("UPDATE price_rate SET amount = '5'"
                            " WHERE price_card_id = 101 AND meter_id = 'input'")

    def test_sources_are_frozen(self) -> None:
        self.assert_aborted("UPDATE source SET url = 'https://example.com'"
                            " WHERE source_id = 'anthropic-pricing@2026-09-24'")

    def test_nothing_can_be_deleted(self) -> None:
        for table in ("price_card", "price_rate", "source", "organization"):
            with self.subTest(table=table):
                self.assert_aborted(f"DELETE FROM {table}")

    def test_version_columns_are_frozen(self) -> None:
        self.assert_aborted("UPDATE price_card SET valid_to = '2026-12-01T00:00:00Z'"
                            " WHERE price_card_id = 101")

    def test_supersede_is_allowed_exactly_once(self) -> None:
        supersede = ("UPDATE price_card SET superseded_at = ?, supersede_reason = ?"
                     " WHERE price_card_id = 101")
        self.db.execute(supersede, ("2026-09-30T00:00:00Z", "correction"))
        self.assert_aborted(supersede, "2026-10-01T00:00:00Z", "restated")

    def test_type1_columns_can_be_overwritten(self) -> None:
        self.db.execute("UPDATE organization SET display_name = 'Anthropic PBC'"
                        " WHERE org_id = 'anthropic'")
        self.assert_aborted("UPDATE channel SET owner_org_id = 'openai'"
                            " WHERE channel_id = 'anthropic-api'")

    def test_client_reference_channel_change_is_versioned(self) -> None:
        self.db.execute(
            "UPDATE client_revision"
            " SET superseded_at = ?, supersede_reason = 'restated'"
            " WHERE client_revision_id = 101", ("2026-09-28T00:00:00Z",))
        restated = {**SCD2_DEFAULTS, "recorded_at": "2026-09-28T00:00:00Z"}
        insert(self.db, "client_revision", client_id="agy",
               reference_channel_id="gemini-api",
               **{**restated, "valid_from": "2026-01-01T00:00:00Z",
                  "valid_to": "2026-10-01T00:00:00Z"})
        insert(self.db, "client_revision", client_id="agy",
               reference_channel_id="openai-api",
               **{**restated, "valid_from": "2026-10-01T00:00:00Z"})
        self.assertEqual(self.db.execute("SELECT count(*) FROM v_scd2_overlap")
                         .fetchone()[0], 0)
        query = dict(client_id="agy", label="gemini-3.8-flash-high")
        before = price_at(self.db, **query, at="2026-09-24T12:00:00Z")
        after = price_at(self.db, **query, at="2026-10-02T00:00:00Z")
        self.assertEqual(before["rates"]["output"], "3.75")
        self.assertIsNone(after["card"])


class SchemaConventions(unittest.TestCase):
    def test_schema_loads_without_fixtures(self) -> None:
        db = open_catalog(with_fixtures=False)
        tables = {row[0] for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'")}
        self.assertEqual(tables, EXPECTED_TABLES)

    def test_every_table_declares_its_grain(self) -> None:
        metadata = tomllib.loads((SCHEMA_DIR / "tables.toml").read_text(encoding="utf-8"))
        self.assertEqual(set(metadata), EXPECTED_TABLES)
        missing = [table for table, entry in metadata.items()
                   if not entry.get("title") or not entry.get("grain")]
        self.assertEqual(missing, [])

    def test_append_only_triggers_match_ddl(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "gen_append_only.py"), "--check"],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
