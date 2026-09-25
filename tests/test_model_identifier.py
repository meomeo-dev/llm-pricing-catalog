import sys
import unittest

from catalog_harness import ROOT, SCD2_DEFAULTS, insert, open_catalog, price_at

sys.path.insert(0, str(ROOT / "scripts"))

import model_search

OPUS_OFFERING = "anthropic-api/claude-opus-5-5"
OPUS_RATES = {"input": "4", "cache_write_5m": "5", "cache_write_1h": "8",
              "cache_read": "0.20", "output": "20"}
RENAMED_AT = "2026-09-23T00:00:00Z"
BEFORE_RENAME, AFTER_RENAME = "2026-09-22T12:00:00Z", "2026-09-24T12:00:00Z"


def add_name(db, identifier: str, kind: str = "api_id", **overrides) -> None:
    insert(db, "model_identifier", **{
        **SCD2_DEFAULTS, "namespace_id": "channel:anthropic-api", "kind": kind,
        "identifier": identifier, "model_id": "claude-opus-5-5",
        "offering_id": OPUS_OFFERING, **overrides})


class Resolution(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()
        insert(self.db, "label_namespace", namespace_id="channel:anthropic-api",
               kind="channel", channel_id="anthropic-api")

    def test_channel_display_name_resolves_to_offering_price(self) -> None:
        add_name(self.db, "Claude Opus 5.5 (Console)", kind="display_name")
        hit = price_at(self.db, channel_id="anthropic-api",
                       label="Claude Opus 5.5 (Console)", at=AFTER_RENAME)
        self.assertEqual(hit["rates"], OPUS_RATES)

    def test_renamed_identifier_resolves_by_period(self) -> None:
        add_name(self.db, "opus-old-name", valid_to=RENAMED_AT)
        add_name(self.db, "opus-new-name", valid_from=RENAMED_AT)

        def rates(label: str, at: str) -> dict:
            return price_at(self.db, channel_id="anthropic-api", label=label, at=at)["rates"]

        self.assertEqual(rates("opus-old-name", BEFORE_RENAME), OPUS_RATES)
        self.assertEqual(rates("opus-old-name", AFTER_RENAME), {})
        self.assertEqual(rates("opus-new-name", BEFORE_RENAME), {})
        self.assertEqual(rates("opus-new-name", AFTER_RENAME), OPUS_RATES)

    def test_name_is_scoped_to_its_namespace(self) -> None:
        hit = price_at(self.db, label="anthropic/claude-sonnet-4.6", at=AFTER_RENAME)
        self.assertEqual(hit["rates"], {})


class Invariants(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()
        insert(self.db, "label_namespace", namespace_id="channel:anthropic-api",
               kind="channel", channel_id="anthropic-api")

    def rows(self, view: str) -> list:
        return [tuple(row) for row in self.db.execute(f"SELECT * FROM {view}")]

    def test_same_name_for_two_models_at_once_is_ambiguous(self) -> None:
        add_name(self.db, "opus", kind="api_id")
        add_name(self.db, "opus", kind="display_name", model_id="claude-sonnet-4-6",
                 offering_id=None)
        self.assertEqual([row[:2] for row in self.rows("v_identifier_ambiguous")],
                         [("channel:anthropic-api", "opus")])

    def test_reused_name_after_the_old_one_ends_is_not_ambiguous(self) -> None:
        add_name(self.db, "opus", valid_to=RENAMED_AT)
        add_name(self.db, "opus", kind="display_name", model_id="claude-sonnet-4-6",
                 offering_id=None, valid_from=RENAMED_AT)
        self.assertEqual(self.rows("v_identifier_ambiguous"), [])

    def test_offering_must_belong_to_namespace_channel(self) -> None:
        add_name(self.db, "sonnet-via-openrouter", model_id="claude-sonnet-4-6",
                 offering_id="openrouter/claude-sonnet-4-6")
        self.assertEqual([row[2] for row in self.rows("v_identifier_offering_mismatch")],
                         ["sonnet-via-openrouter"])


class Search(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def test_spelling_and_channel_prefix_are_matched_loosely(self) -> None:
        names = model_search.find_names(self.db, "claude-sonnet-4.6", AFTER_RENAME)
        levels = {(name["channel_id"], name["identifier"]): name["match_level"]
                  for name in names}
        self.assertEqual(levels[(None, "claude-sonnet-4-6")], 2)
        self.assertEqual(levels[("openrouter", "anthropic/claude-sonnet-4.6")], 3)

    def test_exact_channel_name_identifies_the_channel(self) -> None:
        names = model_search.find_names(self.db, "anthropic/claude-sonnet-4.6", AFTER_RENAME)
        self.assertEqual(model_search.sole_channel(names), "openrouter")

    def test_match_key_formula_is_the_same_everywhere(self) -> None:
        rows = self.db.execute(
            "SELECT identifier, identifier_key FROM model_identifier_lookup").fetchall()
        self.assertTrue(rows)
        for identifier, key in rows:
            self.assertEqual(key, model_search.identifier_key(identifier), identifier)


if __name__ == "__main__":
    unittest.main()
