import sqlite3
import unittest

from catalog_harness import SCD2_DEFAULTS, insert, open_catalog, price_at

INVARIANT_VIEWS = (
    "v_scd2_overlap", "v_context_tier_mismatch", "v_card_without_base_rate",
    "v_route_within_channel", "v_card_upstream_without_route",
    "v_derived_card_rule_mismatch", "v_relative_rate_in_fiat",
    "v_primary_evidence_mismatch", "v_router_outside_owner",
)
OPUS_SERIES = "anthropic-api/claude-opus-5-5/standard/global/USD"
OPUS_CARD = 101


class InvariantViews(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def view_rows(self, view: str) -> list:
        return [tuple(row) for row in self.db.execute(f"SELECT * FROM {view}")]

    def test_scenarios_satisfy_all_invariant_views(self) -> None:
        for view in INVARIANT_VIEWS:
            with self.subTest(view=view):
                self.assertEqual(self.view_rows(view), [])

    def test_every_invariant_view_is_listed(self) -> None:
        views = {row[0] for row in self.db.execute(
            "SELECT name FROM sqlite_master WHERE type = 'view'"
            " AND name LIKE 'v\\_%' ESCAPE '\\'")}
        self.assertEqual(views, set(INVARIANT_VIEWS))

    def test_overlapping_current_cards_are_reported(self) -> None:
        insert(self.db, "price_card", price_series_id=OPUS_SERIES,
               **{**SCD2_DEFAULTS, "valid_from": "2026-10-01T00:00:00Z"})
        rows = self.view_rows("v_scd2_overlap")
        self.assertEqual([row[:2] for row in rows], [("price_card", OPUS_SERIES)])

    def test_overlap_while_both_rows_were_believed_is_reported(self) -> None:
        insert(self.db, "price_card", price_card_id=902, price_series_id=OPUS_SERIES,
               **{**SCD2_DEFAULTS, "valid_from": "2026-09-21T00:00:00Z",
                  "recorded_at": "2026-09-20T00:00:00Z",
                  "superseded_at": "2026-09-30T00:00:00Z",
                  "supersede_reason": "correction"})
        insert(self.db, "price_rate", price_card_id=902, meter_id="input", amount="5")
        self.assertEqual([row[0] for row in self.view_rows("v_scd2_overlap")],
                         ["price_card"])
        with self.assertRaises(AssertionError):
            price_at(self.db, channel_id="anthropic-api", label="claude-opus-5-5",
                     at="2026-09-24T12:00:00Z", known_at="2026-09-27T00:00:00Z")

    def test_duplicate_open_gap_is_reported(self) -> None:
        insert(self.db, "price_gap", namespace_id="client:agy", label="agy-model:1026",
               reason="legacy_label", **SCD2_DEFAULTS)
        self.assertEqual([row[:2] for row in self.view_rows("v_scd2_overlap")],
                         [("price_gap", "client:agy|agy-model:1026")])

    def test_route_to_same_channel_is_reported(self) -> None:
        insert(self.db, "offering_route", offering_id="anthropic-api/claude-opus-5-5",
               upstream_offering_id="anthropic-api/claude-sonnet-5", routing="sole",
               **SCD2_DEFAULTS)
        self.assertEqual(len(self.view_rows("v_route_within_channel")), 1)

    def test_card_upstream_without_route_is_reported(self) -> None:
        series = ("kiro/claude-sonnet-5/standard/global/USD"
                  "/via:anthropic-api/claude-opus-5-5")
        insert(self.db, "price_series", price_series_id=series, channel_id="kiro",
               offering_id="kiro/claude-sonnet-5", price_unit_id="USD",
               upstream_offering_id="anthropic-api/claude-opus-5-5")
        insert(self.db, "price_card", price_card_id=901, price_series_id=series,
               **SCD2_DEFAULTS)
        insert(self.db, "price_rate", price_card_id=901, meter_id="input", amount="1")
        self.assertEqual([row[0] for row in
                          self.view_rows("v_card_upstream_without_route")], [901])

    def test_relative_multiplier_priced_in_fiat_is_reported(self) -> None:
        insert(self.db, "price_rate", price_card_id=OPUS_CARD,
               meter_id="relative_usage", amount="1")
        self.assertEqual(self.view_rows("v_relative_rate_in_fiat"),
                         [(OPUS_CARD, "relative_usage")])

    def test_primary_evidence_must_be_the_card_source(self) -> None:
        insert(self.db, "price_evidence", price_card_id=102,
               source_id="anthropic-pricing@2026-09-24", stance="primary")
        self.assertEqual(len(self.view_rows("v_primary_evidence_mismatch")), 1)

    def test_router_outside_its_owner_is_reported(self) -> None:
        insert(self.db, "offering", offering_id="openrouter/kiro-auto",
               channel_id="openrouter", model_id="kiro-auto")
        self.assertEqual(self.view_rows("v_router_outside_owner"),
                         [("openrouter/kiro-auto",)])


class DeclarativeConstraints(unittest.TestCase):
    def setUp(self) -> None:
        self.db = open_catalog()

    def assert_rejected(self, table: str, reason: str, **values) -> None:
        with self.assertRaisesRegex(sqlite3.IntegrityError, reason):
            insert(self.db, table, **values)

    def card(self, **overrides) -> dict:
        return {"price_series_id": OPUS_SERIES, **SCD2_DEFAULTS, **overrides}

    def test_timestamps_must_be_utc_iso(self) -> None:
        malformed = ("2026-9-1", "2026-09-01", "2026-09-01 00:00:00",
                     "2026-09-01T00:00Z")
        for bad in malformed:
            with self.subTest(valid_from=bad):
                self.assert_rejected("price_card", "CHECK", **self.card(valid_from=bad))

    def test_supersede_must_follow_recording(self) -> None:
        self.assert_rejected("price_card", "CHECK", **self.card(
            recorded_at="2026-09-24T00:00:00Z", superseded_at="2026-09-23T00:00:00Z",
            supersede_reason="correction"))

    def test_computed_card_requires_rule(self) -> None:
        self.assert_rejected("price_card", "CHECK",
                             **self.card(derivation="computed_from_rule"))

    def test_amount_must_be_plain_decimal(self) -> None:
        for bad in ("1,5", "$4", "-1", "4e2", "", "1.2.3", "4.", ".5"):
            with self.subTest(amount=bad):
                self.assert_rejected("price_rate", "CHECK", price_card_id=OPUS_CARD,
                                     meter_id="input", context_min_tokens=1, amount=bad)

    def test_offering_id_must_match_its_parts(self) -> None:
        self.assert_rejected("offering", "CHECK", offering_id="openai-api/whatever",
                             channel_id="anthropic-api", model_id="claude-opus-5-5",
                             variant="batch")

    def test_series_id_must_match_its_conditions(self) -> None:
        self.assert_rejected("price_series", "CHECK",
                             price_series_id=OPUS_SERIES + "-x",
                             channel_id="anthropic-api",
                             offering_id="anthropic-api/claude-opus-5-5",
                             service_tier="batch", price_unit_id="USD")

    def test_series_offering_must_belong_to_its_channel(self) -> None:
        self.assert_rejected("price_series", "FOREIGN KEY",
                             price_series_id=(
                                 "anthropic-api/claude-opus-5-5/batch/global/USD"),
                             channel_id="kiro", service_tier="batch",
                             offering_id="anthropic-api/claude-opus-5-5",
                             price_unit_id="USD")

    def test_plan_of_another_channel_is_rejected(self) -> None:
        self.assert_rejected(
            "price_series", "FOREIGN KEY",
            price_series_id=OPUS_SERIES + "/plan:kiro-pro", channel_id="anthropic-api",
            offering_id="anthropic-api/claude-opus-5-5", price_unit_id="USD",
            plan_id="kiro-pro")

    def test_region_must_be_in_dictionary(self) -> None:
        self.assert_rejected(
            "price_series", "FOREIGN KEY",
            price_series_id="anthropic-api/claude-opus-5-5/standard/mars/USD",
            channel_id="anthropic-api", offering_id="anthropic-api/claude-opus-5-5",
            region_id="mars", price_unit_id="USD")

    def test_source_publisher_must_be_an_organization(self) -> None:
        self.assert_rejected("source", "FOREIGN KEY", source_id="x", url="https://example.com",
                             publisher_org_id="nobody", kind="third_party",
                             retrieved_at="2026-09-24T00:00:00Z")

    def test_rule_scope_must_reference_a_model(self) -> None:
        self.assert_rejected("pricing_rule_scope_model", "FOREIGN KEY",
                             pricing_rule_revision_id=202,
                             model_id="no-such-model")

    def test_namespace_kind_must_match_its_member(self) -> None:
        self.assert_rejected("label_namespace", "CHECK", namespace_id="channel:agy",
                             kind="channel", client_id="agy")

    def test_unit_cannot_be_valued_in_itself(self) -> None:
        self.assert_rejected("unit_rate_series", "CHECK",
                             unit_rate_series_id="USD>USD/list/global",
                             unit_id="USD", value_unit_id="USD", rate_kind="list")

    def test_card_has_at_most_one_primary_evidence(self) -> None:
        insert(self.db, "source", source_id="anthropic-pricing@2026-09-25",
               url="https://platform.claude.com/docs/en/about-claude/pricing",
               publisher_org_id="anthropic", kind="official_pricing_page",
               retrieved_at="2026-09-25T00:00:00Z")
        self.assert_rejected("price_evidence", "UNIQUE", price_card_id=OPUS_CARD,
                             source_id="anthropic-pricing@2026-09-25", stance="primary")


if __name__ == "__main__":
    unittest.main()
