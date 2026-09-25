import sys
import unittest

from catalog_harness import ROOT, SCD2_DEFAULTS, insert, open_catalog, price_at

sys.path.insert(0, str(ROOT / "scripts"))

import model_search

OPUS_OFFERING = "anthropic-api/claude-opus-5-5"
OPUS_RATES = {"input": "4", "cache_write_5m": "5", "cache_write_1h": "8",
              "cache_read": "0.20", "output": "20"}
OPUS_FAST_SERIES = "anthropic-api/claude-opus-5-5/fast/global/USD"
OPUS_FAST_RATES = {"input": "24", "output": "120"}
SONNET_OPENROUTER_ID = "anthropic/claude-sonnet-4.6"
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
        hit = price_at(self.db, label=SONNET_OPENROUTER_ID, at=AFTER_RENAME)
        self.assertEqual(hit["rates"], {})

    def add_fast_series(self) -> None:
        insert(self.db, "price_series", price_series_id=OPUS_FAST_SERIES,
               channel_id="anthropic-api", offering_id=OPUS_OFFERING,
               service_tier="fast", price_unit_id="USD")
        insert(self.db, "price_card", price_card_id=901, price_series_id=OPUS_FAST_SERIES,
               **SCD2_DEFAULTS)
        for meter, amount in OPUS_FAST_RATES.items():
            insert(self.db, "price_rate", price_card_id=901, meter_id=meter, amount=amount)

    def test_implied_service_tier_applies_only_when_tier_not_given(self) -> None:
        self.add_fast_series()
        add_name(self.db, "opus-fast", implied_service_tier="fast")

        def rates(label: str, tier: str | None) -> dict:
            return price_at(self.db, label=label, service_tier=tier, at=AFTER_RENAME)["rates"]

        self.assertEqual(rates("opus-fast", None), OPUS_FAST_RATES)
        self.assertEqual(rates("opus-fast", "standard"), OPUS_RATES)
        self.assertEqual(rates("claude-opus-5-5", None), OPUS_RATES)

    def test_same_name_for_two_models_across_first_party_apis_is_not_guessed(self) -> None:
        add_name(self.db, "shared-name")
        self.assertEqual(price_at(self.db, label="shared-name", at=AFTER_RENAME)["rates"],
                         OPUS_RATES)
        insert(self.db, "label_namespace", namespace_id="channel:openai-api",
               kind="channel", channel_id="openai-api")
        insert(self.db, "model_identifier", **{
            **SCD2_DEFAULTS, "namespace_id": "channel:openai-api", "kind": "api_id",
            "identifier": "shared-name", "model_id": "gpt-6-sol",
            "offering_id": "openai-api/gpt-6-sol"})
        self.assertEqual(price_at(self.db, label="shared-name", at=AFTER_RENAME)["rates"],
                         {})


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

    def resolve(self, term: str, channel_id: str | None = None) -> tuple[list, str]:
        names = model_search.find_names(self.db, term, AFTER_RENAME)
        return model_search.resolve_targets(names, term, channel_id, None)

    def add_channel_name(self, channel: str, identifier: str, model: str) -> None:
        insert(self.db, "label_namespace", namespace_id=f"channel:{channel}",
               kind="channel", channel_id=channel)
        insert(self.db, "model_identifier", **{
            **SCD2_DEFAULTS, "namespace_id": f"channel:{channel}", "kind": "api_id",
            "identifier": identifier, "model_id": model,
            "offering_id": f"{channel}/{model}"})

    def test_spelling_and_channel_prefix_are_matched_loosely(self) -> None:
        names = model_search.find_names(self.db, "claude-sonnet-4.6", AFTER_RENAME)
        levels = {(name["channel_id"], name["identifier"]): name["match_level"]
                  for name in names}
        self.assertEqual(levels[(None, "claude-sonnet-4-6")], 2)
        self.assertEqual(levels[("openrouter", SONNET_OPENROUTER_ID)], 3)

    def test_search_returns_every_match(self) -> None:
        expected = self.db.execute("SELECT count(*) FROM model_identifier_lookup"
                                   " WHERE instr(identifier_key, 'claude') > 0").fetchone()[0]
        names = model_search.find_names(self.db, "claude", AFTER_RENAME)
        self.assertEqual(len(names), expected)

    def test_channel_name_is_priced_in_its_channel(self) -> None:
        self.assertEqual(self.resolve(SONNET_OPENROUTER_ID)[0],
                         [{"label": SONNET_OPENROUTER_ID, "channel_id": "openrouter"}])

    def test_name_shared_by_channels_is_priced_in_each(self) -> None:
        self.add_channel_name("aws-bedrock", SONNET_OPENROUTER_ID, "claude-sonnet-4-6")
        self.assertEqual(self.resolve(SONNET_OPENROUTER_ID)[0], [
            {"label": SONNET_OPENROUTER_ID, "channel_id": "aws-bedrock"},
            {"label": SONNET_OPENROUTER_ID, "channel_id": "openrouter"}])

    def test_other_spelling_of_channel_name_uses_its_original_text(self) -> None:
        self.assertEqual(self.resolve(SONNET_OPENROUTER_ID.upper(), "openrouter")[0],
                         [{"label": SONNET_OPENROUTER_ID}])

    def test_other_spelling_of_model_name_uses_model_id(self) -> None:
        self.assertEqual(self.resolve("CLAUDE_SONNET_4_6")[0],
                         [{"label": "claude-sonnet-4-6"}])

    def test_name_without_prefix_is_only_a_candidate(self) -> None:
        self.assertEqual(self.resolve("sonnet-4.6"), ([], ""))

    def test_name_for_two_models_is_not_guessed(self) -> None:
        self.add_channel_name("anthropic-api", "shared-name", "claude-opus-5-5")
        self.add_channel_name("openai-api", "shared-name", "gpt-6-sol")
        targets, note = self.resolve("shared-name")
        self.assertEqual(targets, [])
        self.assertIn("claude-opus-5-5", note)
        self.assertIn("gpt-6-sol", note)

    def test_query_already_run_by_price_at_is_not_repeated(self) -> None:
        self.assertEqual(self.resolve("claude-opus-5-5", "kiro"), ([], ""))

    def test_match_key_formula_is_the_same_everywhere(self) -> None:
        rows = self.db.execute(
            "SELECT identifier, identifier_key FROM model_identifier_lookup").fetchall()
        self.assertTrue(rows)
        for identifier, key in rows:
            self.assertEqual(key, model_search.identifier_key(identifier), identifier)


if __name__ == "__main__":
    unittest.main()
